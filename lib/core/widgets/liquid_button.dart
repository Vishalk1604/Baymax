import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../glass/glass_style.dart';
import '../glass/liquid_glass.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/tokens.dart';

enum LiquidButtonVariant { primary, secondary, danger }

enum LiquidButtonSize { small, medium, large }

/// A liquid-glass button.
///
/// Pressing squashes the glass body; a droplet of glass grows under the
/// finger, bulges out of the nearest edge and follows the finger while it
/// moves. Body and droplet are merged by the shader's smooth minimum, so they
/// flow together. Releasing springs everything back with a wobble.
class LiquidButton extends StatefulWidget {
  const LiquidButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = LiquidButtonVariant.primary,
    this.size = LiquidButtonSize.large,
    this.loading = false,
    this.expand = true,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final LiquidButtonVariant variant;
  final LiquidButtonSize size;
  final bool loading;

  /// Fill the available width (otherwise hug the content).
  final bool expand;
  final String? semanticLabel;

  @override
  State<LiquidButton> createState() => _LiquidButtonState();
}

class _LiquidButtonState extends State<LiquidButton> with TickerProviderStateMixin {
  late final AnimationController _squash = AnimationController.unbounded(vsync: this);
  late final AnimationController _drop = AnimationController.unbounded(vsync: this);
  final ValueNotifier<Offset?> _touch = ValueNotifier(null);

  bool get _enabled => widget.onPressed != null && !widget.loading;

  double get _height => switch (widget.size) {
        LiquidButtonSize.small => 40,
        LiquidButtonSize.medium => 48,
        LiquidButtonSize.large => 58,
      };

  void _spring(AnimationController c, double target, SpringDescription spring) {
    c.animateWith(SpringSimulation(spring, c.value, target, c.velocity));
  }

  void _down(PointerDownEvent e) {
    if (!_enabled) return;
    _touch.value = e.localPosition;
    _spring(_squash, 1, Springs.snappy);
    _spring(_drop, 1, Springs.droplet);
  }

  void _move(PointerMoveEvent e) {
    if (!_enabled || _touch.value == null) return;
    _touch.value = e.localPosition;
  }

  void _up() {
    _spring(_squash, 0, Springs.jelly);
    _spring(_drop, 0, Springs.snappy);
  }

  @override
  void dispose() {
    _squash.dispose();
    _drop.dispose();
    _touch.dispose();
    super.dispose();
  }

  GlassStyle _style(BuildContext context) {
    final g = context.glass;
    final c = context.colors;
    if (!_enabled && !widget.loading) {
      return g.control.copyWith(
        tint: c.outlineStrong.withValues(alpha: 0.55),
        fallbackTint: c.outlineStrong.withValues(alpha: 0.85),
        shadowColor: Colors.transparent,
      );
    }
    return switch (widget.variant) {
      LiquidButtonVariant.primary => g.primary,
      LiquidButtonVariant.danger => g.danger,
      LiquidButtonVariant.secondary => g.control.copyWith(
          tint: c.surfaceRaised.withValues(alpha: context.isDark ? 0.18 : 0.55),
          fallbackTint: c.surfaceRaised.withValues(alpha: 0.9),
        ),
    };
  }

  Color _foreground(BuildContext context) {
    final c = context.colors;
    if (!_enabled && !widget.loading) return c.textTertiary;
    return switch (widget.variant) {
      LiquidButtonVariant.primary => c.onPrimary,
      LiquidButtonVariant.danger => context.isDark ? c.onPrimary : Colors.white,
      LiquidButtonVariant.secondary => c.textPrimary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final h = _height;
    final fg = _foreground(context);
    final textStyle = AppTypography.weight(
      (widget.size == LiquidButtonSize.small ? context.text.labelMedium! : context.text.labelLarge!),
      680,
    ).copyWith(color: fg);

    final content = AnimatedSwitcher(
      duration: Motion.fast,
      child: widget.loading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: widget.size == LiquidButtonSize.small ? 18 : 21, color: fg),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(widget.label, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );

    final reduce = MediaQuery.disableAnimationsOf(context);
    final style = _style(context);

    Widget button = AnimatedBuilder(
      animation: Listenable.merge([_squash, _drop, _touch]),
      builder: (context, _) {
        final s = reduce ? 0.0 : _squash.value;
        final d = reduce ? 0.0 : _drop.value.clamp(0.0, 1.3);
        final touch = _touch.value;
        return LiquidGlass(
          style: style,
          shapeBuilder: (size) {
            final w = size.width;
            final center = size.center(Offset.zero);
            final bw = w * (1 + 0.025 * s);
            final bh = h * (1 - 0.07 * s);
            final shapes = [GlassShape(Rect.fromCenter(center: center, width: bw, height: bh), bh / 2)];
            if (touch != null && d > 0.02) {
              final r = h * 0.34 * d;
              final x = touch.dx.clamp(r, math.max(r, w - r)).toDouble();
              final up = touch.dy < center.dy;
              // Sit on the nearest long edge, poking ~60% of the radius outside.
              final y = up ? center.dy - bh / 2 + r * 0.4 : center.dy + bh / 2 - r * 0.4;
              shapes.add(GlassShape(Rect.fromCircle(center: Offset(x, y), radius: r), r));
            }
            return shapes;
          },
          child: Center(
            widthFactor: 1,
            child: Transform.scale(
              scale: 1 - 0.035 * s,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: content),
            ),
          ),
        );
      },
    );

    button = SizedBox(
      width: widget.expand ? double.infinity : null,
      height: h,
      child: widget.expand ? button : ConstrainedBox(constraints: BoxConstraints(minWidth: h * 2), child: button),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel ?? widget.label,
      onTap: _enabled ? widget.onPressed : null,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _enabled
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onPressed!();
                }
              : null,
          child: button,
        ),
      ),
    );
  }
}

/// Round liquid-glass icon button (header actions, floating actions).
class LiquidIconButton extends StatefulWidget {
  const LiquidIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 48,
    this.primary = false,
    this.iconSize,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  final bool primary;
  final double? iconSize;

  /// Shows a small dot (e.g. something needs attention).
  final bool badge;

  @override
  State<LiquidIconButton> createState() => _LiquidIconButtonState();
}

class _LiquidIconButtonState extends State<LiquidIconButton> with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController.unbounded(vsync: this);

  void _spring(double target, SpringDescription spring) =>
      _press.animateWith(SpringSimulation(spring, _press.value, target, _press.velocity));

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final g = context.glass;
    final size = widget.size;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final style = widget.primary ? g.primary : g.control;
    final fg = widget.primary ? c.onPrimary : c.textPrimary;

    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        enabled: widget.onPressed != null,
        onTap: widget.onPressed,
        excludeSemantics: true,
        child: Listener(
          onPointerDown: (_) => widget.onPressed == null ? null : _spring(1, Springs.snappy),
          onPointerUp: (_) => _spring(0, Springs.jelly),
          onPointerCancel: (_) => _spring(0, Springs.jelly),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    widget.onPressed!();
                  },
            child: SizedBox.square(
              dimension: size,
              child: AnimatedBuilder(
                animation: _press,
                builder: (context, _) {
                  final p = reduce ? 0.0 : _press.value;
                  // Squash into a slightly wide, short lozenge, then wobble back.
                  final w = size * (1 + 0.06 * p);
                  final h = size * (1 - 0.10 * p);
                  final rect = Rect.fromCenter(center: Offset(size / 2, size / 2), width: w, height: h);
                  return LiquidGlass(
                    style: style,
                    shapes: [GlassShape(rect, math.min(w, h) / 2)],
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(widget.icon, size: widget.iconSize ?? size * 0.46, color: fg),
                        if (widget.badge)
                          Positioned(
                            top: size * 0.22,
                            right: size * 0.22,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: c.danger,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
