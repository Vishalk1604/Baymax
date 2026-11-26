import 'package:flutter/material.dart';

import '../glass/liquid_glass.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'aurora_background.dart';
import 'glass_nav_bar.dart';
import 'liquid_button.dart';

/// Standard screen: aurora background, a large title that scrolls away,
/// floating glass header controls and an optional floating bottom area.
///
/// When the large title scrolls off, a compact glass title capsule grows in
/// the header. It appears by changing its glass shape (not opacity), so the
/// glass keeps refracting while it animates.
class GlassPage extends StatefulWidget {
  const GlassPage({
    super.key,
    required this.title,
    required this.slivers,
    this.subtitle,
    this.actions = const [],
    this.showBack,
    this.onBack,
    this.bottom,
    this.inShell = false,
    this.controller,
    this.largeTitle = true,
    this.titleTrailing,
  });

  final String title;
  final String? subtitle;
  final List<Widget> slivers;

  /// Header actions, usually [LiquidIconButton]s.
  final List<Widget> actions;

  /// Defaults to "can this route pop".
  final bool? showBack;
  final VoidCallback? onBack;

  /// Floating content pinned to the bottom (e.g. the primary action).
  final Widget? bottom;

  /// True for tab screens: leaves room for the floating tab bar.
  final bool inShell;
  final ScrollController? controller;
  final bool largeTitle;

  /// Widget shown beside the large title (avatar, status chip…).
  final Widget? titleTrailing;

  @override
  State<GlassPage> createState() => _GlassPageState();
}

class _GlassPageState extends State<GlassPage> {
  late final ScrollController _controller = widget.controller ?? ScrollController();
  final ValueNotifier<double> _collapse = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _collapse.value = widget.largeTitle ? 0 : 1;
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    final t = widget.largeTitle ? ((_controller.offset - 24) / 40).clamp(0.0, 1.0) : 1.0;
    if ((t - _collapse.value).abs() > 0.001) _collapse.value = t;
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    if (widget.controller == null) _controller.dispose();
    _collapse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final top = media.padding.top;
    // Tab pages never show back (canPop can be briefly true while a pushed
    // screen is closing, and nothing rebuilds the tab afterwards).
    final canPop = widget.showBack ?? (!widget.inShell && Navigator.of(context).canPop());
    final bottomInset = widget.inShell
        ? glassNavBarInset(context)
        : (widget.bottom != null ? 120.0 + media.padding.bottom : 32.0 + media.padding.bottom);

    return Scaffold(
      backgroundColor: context.colors.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(child: AuroraBackground(scroll: _controller)),
          CustomScrollView(
            controller: _controller,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: top + 64)),
              if (widget.largeTitle)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, 4, Space.gutter, Space.lg),
                    child: ValueListenableBuilder<double>(
                      valueListenable: _collapse,
                      builder: (context, t, child) => Opacity(opacity: 1 - t, child: child),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(widget.title, style: context.text.headlineLarge),
                                ),
                                if (widget.subtitle != null) ...[
                                  const SizedBox(height: 4),
                                  Text(widget.subtitle!, style: context.text.bodyMedium),
                                ],
                              ],
                            ),
                          ),
                          if (widget.titleTrailing != null) ...[
                            const SizedBox(width: Space.sm),
                            widget.titleTrailing!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ...widget.slivers,
              SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
            ],
          ),
          // Scrolled content fades out under the status bar and header
          // instead of colliding with the clock and icons.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: top + 76,
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: _collapse,
                builder: (context, t, _) {
                  final bg = context.colors.background;
                  return Opacity(
                    opacity: t,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [bg, bg.withValues(alpha: 0.9), bg.withValues(alpha: 0)],
                          stops: [0, top / (top + 76), 1],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _Header(
              title: widget.title,
              collapse: _collapse,
              showBack: canPop,
              onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
              actions: widget.actions,
            ),
          ),
          if (widget.bottom != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomDock(child: widget.bottom!),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.collapse,
    required this.showBack,
    required this.onBack,
    required this.actions,
  });

  final String title;
  final ValueNotifier<double> collapse;
  final bool showBack;
  final VoidCallback onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, top + 8, 12, 0),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            if (showBack)
              LiquidIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: onBack, size: 48)
            else
              const SizedBox(width: 48),
            const SizedBox(width: 8),
            Expanded(
              child: ValueListenableBuilder<double>(
                valueListenable: collapse,
                builder: (context, t, _) {
                  if (t <= 0.01) return const SizedBox.shrink();
                  final eased = Curves.easeOutBack.transform(t);
                  return Center(
                    child: LiquidGlass(
                      style: context.glass.bar,
                      shapeBuilder: (size) {
                        final w = size.width * (0.35 + 0.65 * eased.clamp(0.0, 1.1));
                        final h = size.height * (0.6 + 0.4 * eased.clamp(0.0, 1.0));
                        return [
                          GlassShape(
                            Rect.fromCenter(center: size.center(Offset.zero), width: w.clamp(0, size.width), height: h),
                            h / 2,
                          ),
                        ];
                      },
                      child: SizedBox(
                        height: 44,
                        child: Center(
                          child: Opacity(
                            opacity: ((t - 0.4) / 0.6).clamp(0.0, 1.0),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleMedium,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            if (actions.isEmpty)
              const SizedBox(width: 48)
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    actions[i],
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Floating bottom area: a soft fade from the background so content
/// scrolling underneath doesn't fight the floating buttons.
class _BottomDock extends StatelessWidget {
  const _BottomDock({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bg = context.colors.background;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Mostly opaque behind the button so scrolled text doesn't show
            // through it; fades out above.
            colors: [bg.withValues(alpha: 0), bg.withValues(alpha: 0.94)],
            stops: const [0, 0.4],
          ),
        ),
      padding: EdgeInsets.fromLTRB(Space.gutter, 28, Space.gutter, bottom + 16),
      child: child,
    );
  }
}
