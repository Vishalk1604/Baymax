import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Soft colour field behind every screen — it gives liquid glass something to
/// refract. It doesn't animate on a loop (that would redraw the screen every
/// frame and drain the battery); it drifts with [scroll] for gentle parallax.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, this.scroll, this.emphasis = 1.0});

  final ScrollController? scroll;

  /// 0–1.4: how saturated the blobs are (onboarding uses more).
  final double emphasis;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _AuroraPainter(
          base: c.background,
          colors: c.aurora,
          dark: context.isDark,
          scroll: scroll,
          emphasis: emphasis,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.base,
    required this.colors,
    required this.dark,
    required this.emphasis,
    this.scroll,
  }) : super(repaint: scroll);

  final Color base;
  final List<Color> colors;
  final bool dark;
  final double emphasis;
  final ScrollController? scroll;

  // (x, y, radius) as fractions of width; parallax speed per blob.
  static const _blobs = [
    (0.10, 0.06, 0.95, 0.10),
    (0.95, 0.28, 0.85, 0.18),
    (0.18, 0.62, 0.90, 0.26),
    (0.88, 0.92, 0.80, 0.34),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    double offset = 0;
    final s = scroll;
    if (s != null && s.hasClients && s.positions.length == 1) offset = s.offset.clamp(-200.0, 6000.0);

    final alpha = (dark ? 0.42 : 0.55) * emphasis;
    for (var i = 0; i < _blobs.length; i++) {
      final (x, y, r, speed) = _blobs[i];
      final color = colors[i % colors.length];
      final center = Offset(size.width * x, size.height * y - offset * speed);
      final radius = size.width * r;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: alpha.clamp(0.0, 1.0)), color.withValues(alpha: 0)],
            stops: const [0.0, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // A calm wash at the very top keeps status-bar icons legible.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 140),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [base.withValues(alpha: 0.75), base.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, 140)),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.base != base || old.dark != dark || old.emphasis != emphasis || old.scroll != scroll || old.colors != colors;
}
