import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../glass/liquid_glass.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'liquid_button.dart';

/// Shows [child] in a liquid-glass bottom sheet.
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    backgroundColor: Colors.transparent,
    barrierColor: context.colors.scrim,
    builder: (context) => _GlassSheetFrame(child: builder(context)),
  );
}

class _GlassSheetFrame extends StatelessWidget {
  const _GlassSheetFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final style = context.glass.surface.copyWith(
      // Sheets hold forms and text: a denser tint keeps them readable while
      // the rim still refracts.
      tint: c.surfaceRaised.withValues(alpha: context.isDark ? 0.82 : 0.78),
      frost: 6,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8 + insets),
      child: LiquidGlass(
        radius: Radii.xl,
        style: style,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: c.outlineStrong, borderRadius: BorderRadius.circular(3)),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a glass dialog that rises and settles with a slight overshoot.
Future<T?> showGlassDialog<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Close',
    barrierColor: context.colors.scrim,
    transitionDuration: Motion.slow,
    pageBuilder: (context, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: builder(context)),
        ),
      ),
    ),
    // Scale + rise rather than fade: a fade would render the dialog through an
    // offscreen layer and the glass would have nothing to refract.
    transitionBuilder: (context, animation, _, child) {
      final t = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
      return AnimatedBuilder(
        animation: t,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - t.value) * 40),
          child: Transform.scale(scale: 0.86 + 0.14 * t.value, child: child),
        ),
      );
    },
  );
}

/// The standard dialog body.
class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.iconColor,
    this.content,
    this.actions = const [],
  });

  final String title;
  final String? message;
  final IconData? icon;
  final Color? iconColor;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.glass.surface.copyWith(
      tint: c.surfaceRaised.withValues(alpha: context.isDark ? 0.84 : 0.8),
      frost: 6,
    );
    return Material(
      type: MaterialType.transparency,
      child: LiquidGlass(
        radius: Radii.lg,
        style: style,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null) ...[
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (iconColor ?? c.primary).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor ?? c.primary, size: 28),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(title, textAlign: TextAlign.center, style: context.text.titleLarge),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!, textAlign: TextAlign.center, style: context.text.bodyMedium),
              ],
              if (content != null) ...[const SizedBox(height: 16), content!],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 22),
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  actions[i],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for confirmation. Resolves to true only when the user confirms.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  if (destructive) HapticFeedback.mediumImpact();
  final result = await showGlassDialog<bool>(
    context,
    builder: (context) => GlassDialog(
      title: title,
      message: message,
      icon: icon ?? (destructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded),
      iconColor: destructive ? context.colors.danger : null,
      actions: [
        LiquidButton(
          label: confirmLabel,
          variant: destructive ? LiquidButtonVariant.danger : LiquidButtonVariant.primary,
          size: LiquidButtonSize.medium,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        LiquidButton(
          label: cancelLabel,
          variant: LiquidButtonVariant.secondary,
          size: LiquidButtonSize.medium,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    ),
  );
  return result ?? false;
}

enum ToastKind { info, success, warning, error }

/// Brief status message in a glass capsule that drops in from the top.
abstract final class AppToast {
  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(BuildContext context, String message, {ToastKind kind = ToastKind.info}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _timer?.cancel();
    _current?.remove();
    if (kind == ToastKind.error || kind == ToastKind.warning) HapticFeedback.mediumImpact();

    final key = GlobalKey<_ToastState>();
    late final OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _Toast(key: key, message: message, kind: kind));
    _current = entry;
    overlay.insert(entry);
    SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
    _timer = Timer(const Duration(milliseconds: 2800), () async {
      await key.currentState?.dismiss();
      if (_current == entry) {
        entry.remove();
        _current = null;
      }
    });
  }
}

class _Toast extends StatefulWidget {
  const _Toast({super.key, required this.message, required this.kind});
  final String message;
  final ToastKind kind;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.slow)..forward();

  Future<void> dismiss() async {
    if (mounted) await _c.reverse();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, color) = switch (widget.kind) {
      ToastKind.success => (Icons.check_circle_rounded, c.success),
      ToastKind.warning => (Icons.warning_amber_rounded, c.warning),
      ToastKind.error => (Icons.error_rounded, c.danger),
      ToastKind.info => (Icons.info_rounded, c.primary),
    };
    final top = MediaQuery.paddingOf(context).top;
    final style = context.glass.bar.copyWith(tint: c.surfaceRaised.withValues(alpha: context.isDark ? 0.75 : 0.7));
    return Positioned(
      top: top + 10,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeOutBack.transform(_c.value);
          return Transform.translate(offset: Offset(0, -90 * (1 - t)), child: child);
        },
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: LiquidGlass(
              radius: 26,
              style: style,
              repaint: _c,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 20, 13),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(width: 10),
                    Flexible(child: Text(widget.message, style: context.text.titleSmall)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
