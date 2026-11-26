import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/tokens.dart';
import 'liquid_button.dart';

/// Circular progress with an animated sweep.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 88,
    this.stroke = 9,
    this.color,
    this.trackColor,
    this.child,
  });

  final double progress;
  final double size;
  final double stroke;
  final Color? color;
  final Color? trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress.clamp(0.0, 1.0)),
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 900),
      curve: Motion.emphasized,
      builder: (context, p, child) => CustomPaint(
        painter: _RingPainter(p, stroke, color ?? c.primary, trackColor ?? c.primarySoft),
        child: SizedBox.square(dimension: size, child: Center(child: child)),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.p, this.stroke, this.color, this.track);
  final double p;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(rect, 0, math.pi * 2, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track);
    if (p <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * p,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: [color.withValues(alpha: 0.75), color],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.p != p || old.color != color || old.track != track;
}

/// Smooth trend line with a soft fill and an end dot.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.color, this.height = 36, this.strokeWidth = 2.4});

  final List<double> values;
  final Color? color;
  final double height;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? context.colors.primary;
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 900),
        curve: Motion.emphasized,
        builder: (context, t, _) => CustomPaint(
          size: Size.infinite,
          painter: _SparkPainter(values, tone, strokeWidth, t),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color, this.width, this.t);
  final List<double> values;
  final Color color;
  final double width;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      if (values.length == 1) {
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), 3.5, Paint()..color = color);
      }
      return;
    }
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    if (hi - lo < 1e-6) {
      lo -= 1;
      hi += 1;
    }
    final pad = width + 3;
    final pts = [
      for (var i = 0; i < values.length; i++)
        Offset(
          pad + (size.width - pad * 2) * i / (values.length - 1),
          pad + (size.height - pad * 2) * (1 - (values[i] - lo) / (hi - lo)),
        ),
    ];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i > 0 ? pts[i - 1] : pts[i];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
      line.cubicTo(
        p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6,
        p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6,
        p2.dx, p2.dy,
      );
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * t, size.height));
    final fill = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
    if (t >= 0.98) {
      canvas.drawCircle(pts.last, width * 2.6, Paint()..color = color.withValues(alpha: 0.2));
      canvas.drawCircle(pts.last, width * 1.4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t || old.values != values || old.color != color;
}

/// A number that animates to its new value, with tabular figures so digits
/// don't jitter.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({super.key, required this.value, this.decimals = 0, this.style, this.suffix = ''});

  final double value;
  final int decimals;
  final TextStyle? style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 700),
      curve: Motion.emphasized,
      builder: (context, v, _) => Text(
        '${v.toStringAsFixed(decimals)}$suffix',
        style: (style ?? context.text.displaySmall)!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}

/// Friendly empty state: icon, title, message and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? context.colors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.06)]),
            ),
            child: Icon(icon, size: 38, color: color),
          ),
          const SizedBox(height: Space.md),
          Text(title, textAlign: TextAlign.center, style: context.text.titleLarge),
          const SizedBox(height: Space.xs),
          Text(message, textAlign: TextAlign.center, style: context.text.bodyMedium),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Space.lg),
            LiquidButton(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
              size: LiquidButtonSize.medium,
            ),
          ],
        ],
      ),
    );
  }
}

/// Shimmering placeholder block while content loads.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 10});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3 * _c.value, 0),
              end: Alignment(-0.5 + 3 * _c.value, 0),
              colors: [c.surfaceMuted, c.outline.withValues(alpha: 0.9), c.surfaceMuted],
            ),
          ),
        ),
      ),
    );
  }
}

/// Baymax mark: a soft teal squircle with a pulse line.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Baymax',
      image: true,
      child: CustomPaint(size: Size.square(size), painter: _BrandPainter(context.colors.primary, context.colors.accent)),
    );
  }
}

class _BrandPainter extends CustomPainter {
  _BrandPainter(this.a, this.b);
  final Color a;
  final Color b;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.3));
    canvas.drawRRect(
      rr.shift(Offset(0, size.height * 0.06)),
      Paint()
        ..color = a.withValues(alpha: 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.08),
    );
    canvas.drawRRect(
      rr,
      Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, b]).createShader(rect),
    );
    // Gloss
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.08, size.height * 0.06, size.width * 0.84, size.height * 0.42),
          Radius.circular(size.width * 0.24)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0)],
        ).createShader(rect),
    );
    // Pulse line
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.16, h * 0.56)
      ..lineTo(w * 0.36, h * 0.56)
      ..lineTo(w * 0.45, h * 0.34)
      ..lineTo(w * 0.56, h * 0.74)
      ..lineTo(w * 0.64, h * 0.50)
      ..lineTo(w * 0.84, h * 0.50);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.075
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_BrandPainter old) => old.a != a || old.b != b;
}

/// Circle with the person's initials.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 48});
  final String name;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.primary, c.accent]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: AppTypography.style(size * 0.38, 760).copyWith(color: Colors.white),
        semanticsLabel: name,
      ),
    );
  }
}

enum OrbMood { idle, active, success, alert }

/// An organic, breathing blob. Idle it breathes slowly; active (measuring or
/// thinking) it wobbles faster and sends out ripples.
class LiquidOrb extends StatefulWidget {
  const LiquidOrb({super.key, this.mood = OrbMood.idle, this.size = 200, this.child});

  final OrbMood mood;
  final double size;
  final Widget? child;

  @override
  State<LiquidOrb> createState() => _LiquidOrbState();
}

class _LiquidOrbState extends State<LiquidOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 12));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _t.stop();
    } else if (!_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (inner, outer) = switch (widget.mood) {
      OrbMood.success => (c.success, c.accent),
      OrbMood.alert => (c.danger, c.warning),
      _ => (c.primary, c.accent),
    };
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) => CustomPaint(
          painter: _OrbPainter(
            t: _t.value,
            active: widget.mood == OrbMood.active,
            inner: inner,
            outer: outer,
            dark: context.isDark,
          ),
          child: child,
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.t, required this.active, required this.inner, required this.outer, required this.dark});

  final double t;
  final bool active;
  final Color inner;
  final Color outer;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.width * 0.33;
    final phase = t * math.pi * 2;
    final speed = active ? 4.0 : 1.0;
    final amp = active ? 0.06 : 0.025;

    // Ripples while active.
    if (active) {
      for (var k = 0; k < 3; k++) {
        final p = ((t * 6) + k / 3) % 1.0;
        canvas.drawCircle(
          center,
          base * (1.05 + p * 0.55),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = inner.withValues(alpha: (1 - p) * 0.35),
        );
      }
    }

    final path = Path();
    const steps = 96;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * math.pi * 2;
      final breathe = 1 + 0.03 * math.sin(phase * speed);
      final r = base *
          breathe *
          (1 +
              amp * math.sin(2 * a + phase * 2 * speed) +
              amp * 0.7 * math.sin(3 * a - phase * 3 * speed) +
              amp * 0.4 * math.sin(5 * a + phase * 5));
      final pt = center + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();

    final bounds = Rect.fromCircle(center: center, radius: base * 1.2);
    canvas.drawPath(
      path.shift(const Offset(0, 10)),
      Paint()
        ..color = inner.withValues(alpha: dark ? 0.45 : 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, base * 0.28),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.0,
          colors: [Color.lerp(inner, Colors.white, 0.45)!, inner, Color.lerp(outer, Colors.black, 0.15)!],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(bounds),
    );
    // Specular highlight.
    canvas.drawOval(
      Rect.fromCenter(center: center + Offset(-base * 0.32, -base * 0.42), width: base * 0.9, height: base * 0.42),
      Paint()
        ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0)])
            .createShader(Rect.fromCenter(
                center: center + Offset(-base * 0.32, -base * 0.42), width: base * 0.9, height: base * 0.42)),
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.t != t || old.active != active || old.inner != inner || old.outer != outer || old.dark != dark;
}
