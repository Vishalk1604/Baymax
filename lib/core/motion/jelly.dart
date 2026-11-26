import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Squash-and-stretch press feedback driven by springs.
///
/// Pressing squashes the child (wider, shorter); releasing lets it spring back
/// past its rest size and wobble to a stop — the "jelly" feel. Responds on
/// pointer-down (no tap delay) and never changes layout size.
class JellyPress extends StatefulWidget {
  const JellyPress({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.intensity = 1.0,
    this.haptic = true,
    this.semanticLabel,
    this.isButton = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;

  /// Scales the squash amount (cards ≈ 0.5, buttons 1.0, small icons 1.4).
  final double intensity;
  final bool haptic;
  final String? semanticLabel;
  final bool isButton;

  @override
  State<JellyPress> createState() => _JellyPressState();
}

class _JellyPressState extends State<JellyPress> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this);

  bool get _active => widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _spring(double target, SpringDescription spring) {
    _c.animateWith(SpringSimulation(spring, _c.value, target, _c.velocity));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    Widget child = AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final v = reduce ? 0.0 : _c.value * widget.intensity;
        if (v == 0) return child!;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(1 - 0.022 * v, 1 - 0.045 * v, 1),
          child: child,
        );
      },
    );

    if (!_active) return widget.child;

    child = Listener(
      onPointerDown: (_) => _spring(1, Springs.snappy),
      onPointerUp: (_) => _spring(0, Springs.jelly),
      onPointerCancel: (_) => _spring(0, Springs.jelly),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                widget.onLongPress!();
              },
        child: child,
      ),
    );

    return Semantics(
      button: widget.isButton,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      onTap: widget.onTap,
      // With an explicit label, don't also read the visible text.
      excludeSemantics: widget.semanticLabel != null,
      child: child,
    );
  }
}
