import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'glass_runtime.dart';
import 'glass_style.dart';
import 'glass_theme.dart';

/// One rounded rectangle of a glass surface, in the widget's local space.
@immutable
class GlassShape {
  const GlassShape(this.rect, this.radius);

  final Rect rect;
  final double radius;

  static GlassShape lerp(GlassShape a, GlassShape b, double t) =>
      GlassShape(Rect.lerp(a.rect, b.rect, t)!, ui.lerpDouble(a.radius, b.radius, t)!);

  @override
  bool operator ==(Object other) => other is GlassShape && other.rect == rect && other.radius == radius;

  @override
  int get hashCode => Object.hash(rect, radius);
}

/// A surface of liquid glass: the content behind it is refracted through a
/// curved rim, picks up a specular edge light and is tinted.
///
/// By default the whole box is one rounded rectangle of [radius]. Pass up to
/// three [shapes] (local coordinates) to get shapes that melt into each other
/// when they come within [GlassStyle.blend] — used by the tab-bar droplet and
/// the touch bulge of [LiquidButton].
///
/// Falls back to frosted glass when the device can't run the shader, the user
/// turned the effect off, or [liquid] is false.
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    super.key,
    this.child,
    this.radius = 24,
    this.shapes,
    this.shapeBuilder,
    this.style,
    this.liquid = true,
    this.repaint,
  });

  final Widget? child;

  /// Extra animation that moves this glass without repainting it (e.g. a
  /// transform animated by an ancestor). Scrolling and route transitions are
  /// picked up automatically.
  final Listenable? repaint;
  final double radius;
  final List<GlassShape>? shapes;

  /// Computes the shapes from the laid-out size at paint time (takes
  /// precedence over [shapes]); use it for geometry that depends on size.
  final List<GlassShape> Function(Size size)? shapeBuilder;
  final GlassStyle? style;

  /// Set false to force the frosted rendering for this surface.
  final bool liquid;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  Listenable? _repaint;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repaint = _sources();
  }

  @override
  void didUpdateWidget(covariant LiquidGlass oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repaint != widget.repaint) _repaint = _sources();
  }

  Listenable? _sources() {
    final collected = _collectRepaintSources(context);
    final extra = widget.repaint;
    if (extra == null) return collected;
    if (collected == null) return extra;
    return Listenable.merge([collected, extra]);
  }

  /// The shader draws the glass at its global position, so anything that moves
  /// this widget without repainting it (scrolling, route transitions) must
  /// trigger a repaint in the same frame.
  static Listenable? _collectRepaintSources(BuildContext context) {
    final sources = <Listenable>[];
    final route = ModalRoute.of(context);
    if (route?.animation != null) sources.add(route!.animation!);
    if (route?.secondaryAnimation != null) sources.add(route!.secondaryAnimation!);
    var scrollContext = context;
    while (true) {
      final scrollable = Scrollable.maybeOf(scrollContext);
      if (scrollable == null) break;
      sources.add(scrollable.position);
      scrollContext = scrollable.context;
    }
    return sources.isEmpty ? null : Listenable.merge(sources);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? GlassTheme.of(context).surface;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final reduce = MediaQuery.highContrastOf(context);
    // Glass on glass (a button in a glass card, dialog or sheet) is drawn
    // directly: a backdrop filter nested in another one gets a different
    // coordinate space on Impeller, and refraction of the glass underneath
    // wouldn't be visible anyway.
    final nested = context.dependOnInheritedWidgetOfExactType<_GlassScope>() != null;
    final child = widget.child;
    return ValueListenableBuilder<bool>(
      valueListenable: GlassRuntime.liquid,
      builder: (context, liquidOn, child) => _LiquidGlassSurface(
        shapes: widget.shapes,
        shapeBuilder: widget.shapeBuilder,
        radius: widget.radius,
        style: style,
        liquid: liquidOn && widget.liquid && !reduce,
        nested: nested,
        devicePixelRatio: dpr,
        repaint: _repaint,
        child: child,
      ),
      child: child == null ? null : _GlassScope(child: child),
    );
  }
}

/// Marks everything painted inside a [LiquidGlass].
class _GlassScope extends InheritedWidget {
  const _GlassScope({required super.child});

  @override
  bool updateShouldNotify(_GlassScope oldWidget) => false;
}

class _LiquidGlassSurface extends SingleChildRenderObjectWidget {
  const _LiquidGlassSurface({
    required this.shapes,
    required this.shapeBuilder,
    required this.radius,
    required this.style,
    required this.liquid,
    required this.nested,
    required this.devicePixelRatio,
    required this.repaint,
    super.child,
  });

  final List<GlassShape>? shapes;
  final List<GlassShape> Function(Size size)? shapeBuilder;
  final double radius;
  final GlassStyle style;
  final bool liquid;
  final bool nested;
  final double devicePixelRatio;
  final Listenable? repaint;

  @override
  RenderLiquidGlass createRenderObject(BuildContext context) => RenderLiquidGlass(
        shapes: shapes,
        shapeBuilder: shapeBuilder,
        radius: radius,
        style: style,
        liquid: liquid,
        nested: nested,
        devicePixelRatio: devicePixelRatio,
        repaint: repaint,
      );

  @override
  void updateRenderObject(BuildContext context, RenderLiquidGlass renderObject) {
    renderObject
      ..shapes = shapes
      ..shapeBuilder = shapeBuilder
      ..radius = radius
      ..style = style
      ..liquid = liquid
      ..nested = nested
      ..devicePixelRatio = devicePixelRatio
      ..repaint = repaint;
  }
}

class RenderLiquidGlass extends RenderProxyBox {
  RenderLiquidGlass({
    List<GlassShape>? shapes,
    List<GlassShape> Function(Size size)? shapeBuilder,
    required double radius,
    required GlassStyle style,
    required bool liquid,
    bool nested = false,
    required double devicePixelRatio,
    Listenable? repaint,
  })  : _shapes = shapes,
        _shapeBuilder = shapeBuilder,
        _radius = radius,
        _style = style,
        _liquid = liquid,
        _nested = nested,
        _dpr = devicePixelRatio,
        _repaint = repaint;

  List<GlassShape>? _shapes;
  set shapes(List<GlassShape>? value) {
    if (listEquals(_shapes, value)) return;
    _shapes = value;
    markNeedsPaint();
  }

  List<GlassShape> Function(Size size)? _shapeBuilder;
  set shapeBuilder(List<GlassShape> Function(Size size)? value) {
    if (identical(_shapeBuilder, value)) return;
    _shapeBuilder = value;
    markNeedsPaint();
  }

  double _radius;
  set radius(double value) {
    if (_radius == value) return;
    _radius = value;
    markNeedsPaint();
  }

  GlassStyle _style;
  set style(GlassStyle value) {
    if (_style == value) return;
    _style = value;
    markNeedsPaint();
  }

  bool _liquid;
  set liquid(bool value) {
    if (_liquid == value) return;
    _liquid = value;
    markNeedsPaint();
  }

  bool _nested;
  set nested(bool value) {
    if (_nested == value) return;
    _nested = value;
    markNeedsPaint();
  }

  double _dpr;
  set devicePixelRatio(double value) {
    if (_dpr == value) return;
    _dpr = value;
    markNeedsPaint();
  }

  Listenable? _repaint;
  set repaint(Listenable? value) {
    if (identical(_repaint, value)) return;
    if (attached) {
      _repaint?.removeListener(markNeedsPaint);
      value?.addListener(markNeedsPaint);
    }
    _repaint = value;
  }

  ui.FragmentShader? _shader;
  final _clipRectHandle = LayerHandle<ClipRectLayer>();
  final _clipPathHandle = LayerHandle<ClipPathLayer>();
  final _backdropHandle = LayerHandle<BackdropFilterLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clipRectHandle.layer = null;
    _clipPathHandle.layer = null;
    _backdropHandle.layer = null;
    _shader?.dispose();
    super.dispose();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  List<GlassShape> get _effectiveShapes {
    final shapes = _shapeBuilder?.call(size) ?? _shapes;
    if (shapes == null || shapes.isEmpty) return [GlassShape(Offset.zero & size, _radius)];
    return shapes.length > 3 ? shapes.sublist(0, 3) : shapes;
  }

  Path _shapePath(List<GlassShape> shapes, Offset offset) {
    final path = Path();
    for (final s in shapes) {
      path.addRRect(RRect.fromRectAndRadius(s.rect.shift(offset), Radius.circular(s.radius)));
    }
    return path;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    final shapes = _effectiveShapes;
    var bounds = shapes.first.rect;
    for (final s in shapes.skip(1)) {
      bounds = bounds.expandToInclude(s.rect);
    }
    bounds = bounds.inflate(_style.blend * 0.5 + 2);

    _paintShadow(context.canvas, offset, shapes, bounds);

    final program = GlassRuntime.program;
    if (_nested) {
      _clipRectHandle.layer = null;
      _clipPathHandle.layer = null;
      _backdropHandle.layer = null;
      _paintSolid(context, offset, shapes, bounds);
    } else if (_liquid && program != null) {
      _clipPathHandle.layer = null;
      _paintLiquid(context, offset, shapes, bounds, program);
    } else {
      _clipRectHandle.layer = null;
      _paintFrosted(context, offset, shapes, bounds);
    }
  }

  /// Glass drawn without a backdrop read: tint, top sheen and a lit rim.
  void _paintSolid(PaintingContext context, Offset offset, List<GlassShape> shapes, Rect bounds) {
    final s = _style;
    final canvas = context.canvas;
    final path = _shapePath(shapes, offset);
    final area = bounds.shift(offset);
    canvas.drawPath(path, Paint()..color = s.fallbackTint);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.26 * s.sheen), Colors.white.withValues(alpha: 0)],
          stops: const [0, 0.6],
        ).createShader(area),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [s.fallbackBorder, s.fallbackBorder.withValues(alpha: s.fallbackBorder.a * 0.25)],
        ).createShader(area),
    );
    _paintChild(context, offset);
  }

  void _paintChild(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null) context.paintChild(child, offset);
  }

  void _paintShadow(Canvas canvas, Offset offset, List<GlassShape> shapes, Rect bounds) {
    if (_style.shadowColor.a == 0 || _style.shadowBlur <= 0) return;
    final glass = _shapePath(shapes, offset);
    final outside = bounds.shift(offset).inflate(_style.shadowBlur * 2 + _style.shadowOffset);
    canvas.save();
    // Only outside the glass: a shadow under clear glass would show through.
    canvas.clipPath(Path.combine(PathOperation.difference, Path()..addRect(outside), glass));
    canvas.drawPath(
      glass.shift(Offset(0, _style.shadowOffset)),
      Paint()
        ..color = _style.shadowColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _style.shadowBlur * 0.5),
    );
    canvas.restore();
  }

  void _paintLiquid(
    PaintingContext context,
    Offset offset,
    List<GlassShape> shapes,
    Rect bounds,
    ui.FragmentProgram program,
  ) {
    final shader = _shader ??= program.fragmentShader();
    final toGlobal = getTransformTo(null);
    final scale = toGlobal.getMaxScaleOnAxis() * _dpr;
    final s = _style;

    var i = 2; // floats 0–1 are the backdrop size, filled in by Flutter
    void f(double v) => shader.setFloat(i++, v);

    for (var k = 0; k < 3; k++) {
      final shape = shapes[k < shapes.length ? k : 0];
      final r = MatrixUtils.transformRect(toGlobal, shape.rect);
      f(r.left * _dpr);
      f(r.top * _dpr);
      f(r.width * _dpr);
      f(r.height * _dpr);
    }
    for (var k = 0; k < 3; k++) {
      f(shapes[k < shapes.length ? k : 0].radius * scale);
    }
    f(shapes.length.toDouble());
    f(s.bevel * scale);
    f(s.refraction * scale);
    f(s.dispersion);
    f(s.blend * scale);
    f(s.lightAngle);
    f(s.specular);
    f(s.rimWidth * scale);
    f(s.sheen);
    f(s.tint.r);
    f(s.tint.g);
    f(s.tint.b);
    f(s.tint.a);
    f(s.saturation);
    f(1.0); // edge anti-aliasing width, physical px
    f(s.brightness);
    f(s.rimShadow);
    // Frost is blurred inside the shader (radius ≈ 2.2 σ); composing a blur
    // filter would hand the shader a cropped, offset texture.
    f(s.frost * scale * 2.2);
    f(0);
    f(0);
    f(0);

    final filter = ui.ImageFilter.shader(shader);

    _clipRectHandle.layer = context.pushClipRect(
      needsCompositing,
      offset,
      bounds,
      (ctx, off) {
        final layer = _backdropHandle.layer ??= BackdropFilterLayer();
        layer.filter = filter;
        ctx.pushLayer(layer, _paintChild, off);
      },
      oldLayer: _clipRectHandle.layer,
    );
  }

  void _paintFrosted(PaintingContext context, Offset offset, List<GlassShape> shapes, Rect bounds) {
    final s = _style;
    final localPath = _shapePath(shapes, Offset.zero);
    _clipPathHandle.layer = context.pushClipPath(
      needsCompositing,
      offset,
      bounds,
      localPath,
      (ctx, off) {
        final layer = _backdropHandle.layer ??= BackdropFilterLayer();
        layer.filter = ui.ImageFilter.blur(sigmaX: s.fallbackBlur, sigmaY: s.fallbackBlur);
        ctx.pushLayer(layer, (c, o) {
          final canvas = c.canvas;
          final path = localPath.shift(o);
          final area = bounds.shift(o);
          canvas.drawPath(path, Paint()..color = s.fallbackTint);
          canvas.drawPath(
            path,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withValues(alpha: 0.22 * s.sheen), Colors.white.withValues(alpha: 0)],
                stops: const [0, 0.55],
              ).createShader(area),
          );
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [s.fallbackBorder, s.fallbackBorder.withValues(alpha: s.fallbackBorder.a * 0.25)],
              ).createShader(area),
          );
          _paintChild(c, o);
        }, off);
      },
      oldLayer: _clipPathHandle.layer,
    );
  }
}
