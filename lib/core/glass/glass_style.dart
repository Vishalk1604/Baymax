import 'dart:math' as math;
import 'dart:ui' show Color, lerpDouble;

import 'package:flutter/foundation.dart';

/// Optical and fallback parameters of a glass surface.
///
/// All distances are logical pixels; the renderer converts them to physical
/// pixels for the shader.
@immutable
class GlassStyle {
  const GlassStyle({
    this.bevel = 18,
    this.refraction = 12,
    this.dispersion = 0.25,
    this.blend = 20,
    this.lightAngle = -2.2,
    this.specular = 0.75,
    this.rimWidth = 2.0,
    this.sheen = 1.0,
    this.tint = const Color(0x14FFFFFF),
    this.saturation = 1.3,
    this.brightness = 1.03,
    this.rimShadow = 0.5,
    this.frost = 0,
    this.shadowColor = const Color(0x1A0B2530),
    this.shadowBlur = 24,
    this.shadowOffset = 8,
    this.fallbackTint = const Color(0xB8FFFFFF),
    this.fallbackBlur = 22,
    this.fallbackBorder = const Color(0x99FFFFFF),
  });

  /// Width of the curved rim, where the glass bends light.
  final double bevel;

  /// How far (px) the backdrop is displaced at the steepest part of the rim.
  final double refraction;

  /// Colour fringing at the rim, 0–1.
  final double dispersion;

  /// Fillet radius used when nearby shapes merge.
  final double blend;

  /// Direction towards the key light, radians (screen space, y down).
  final double lightAngle;

  /// Strength of the specular rim highlight, 0–1.
  final double specular;

  /// Width of the highlight band along the rim.
  final double rimWidth;

  /// Strength of the soft top sheen, 0–1.
  final double sheen;

  /// Colour mixed into the glass; alpha is the mix strength.
  final Color tint;

  /// Saturation of the refracted backdrop (1 = unchanged).
  final double saturation;

  /// Brightness multiplier of the refracted backdrop.
  final double brightness;

  /// Darkening inside the rim on the side away from the light, 0–1.
  final double rimShadow;

  /// Optional light blur under the glass for legibility (sigma, px).
  final double frost;

  /// Drop shadow under the glass.
  final Color shadowColor;
  final double shadowBlur;
  final double shadowOffset;

  /// Frosted fallback, used when the shader can't run or is turned off.
  final Color fallbackTint;
  final double fallbackBlur;
  final Color fallbackBorder;

  GlassStyle copyWith({
    double? bevel,
    double? refraction,
    double? dispersion,
    double? blend,
    double? lightAngle,
    double? specular,
    double? rimWidth,
    double? sheen,
    Color? tint,
    double? saturation,
    double? brightness,
    double? rimShadow,
    double? frost,
    Color? shadowColor,
    double? shadowBlur,
    double? shadowOffset,
    Color? fallbackTint,
    double? fallbackBlur,
    Color? fallbackBorder,
  }) {
    return GlassStyle(
      bevel: bevel ?? this.bevel,
      refraction: refraction ?? this.refraction,
      dispersion: dispersion ?? this.dispersion,
      blend: blend ?? this.blend,
      lightAngle: lightAngle ?? this.lightAngle,
      specular: specular ?? this.specular,
      rimWidth: rimWidth ?? this.rimWidth,
      sheen: sheen ?? this.sheen,
      tint: tint ?? this.tint,
      saturation: saturation ?? this.saturation,
      brightness: brightness ?? this.brightness,
      rimShadow: rimShadow ?? this.rimShadow,
      frost: frost ?? this.frost,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      shadowOffset: shadowOffset ?? this.shadowOffset,
      fallbackTint: fallbackTint ?? this.fallbackTint,
      fallbackBlur: fallbackBlur ?? this.fallbackBlur,
      fallbackBorder: fallbackBorder ?? this.fallbackBorder,
    );
  }

  static GlassStyle lerp(GlassStyle a, GlassStyle b, double t) {
    double l(double x, double y) => lerpDouble(x, y, t)!;
    return GlassStyle(
      bevel: l(a.bevel, b.bevel),
      refraction: l(a.refraction, b.refraction),
      dispersion: l(a.dispersion, b.dispersion),
      blend: l(a.blend, b.blend),
      lightAngle: l(a.lightAngle, b.lightAngle),
      specular: l(a.specular, b.specular),
      rimWidth: l(a.rimWidth, b.rimWidth),
      sheen: l(a.sheen, b.sheen),
      tint: Color.lerp(a.tint, b.tint, t)!,
      saturation: l(a.saturation, b.saturation),
      brightness: l(a.brightness, b.brightness),
      rimShadow: l(a.rimShadow, b.rimShadow),
      frost: l(a.frost, b.frost),
      shadowColor: Color.lerp(a.shadowColor, b.shadowColor, t)!,
      shadowBlur: l(a.shadowBlur, b.shadowBlur),
      shadowOffset: l(a.shadowOffset, b.shadowOffset),
      fallbackTint: Color.lerp(a.fallbackTint, b.fallbackTint, t)!,
      fallbackBlur: l(a.fallbackBlur, b.fallbackBlur),
      fallbackBorder: Color.lerp(a.fallbackBorder, b.fallbackBorder, t)!,
    );
  }

  /// Light coming from the upper left, like Apple's glass.
  static const double topLeftLight = -math.pi * 0.72;

  @override
  bool operator ==(Object other) =>
      other is GlassStyle &&
      other.bevel == bevel &&
      other.refraction == refraction &&
      other.dispersion == dispersion &&
      other.blend == blend &&
      other.lightAngle == lightAngle &&
      other.specular == specular &&
      other.rimWidth == rimWidth &&
      other.sheen == sheen &&
      other.tint == tint &&
      other.saturation == saturation &&
      other.brightness == brightness &&
      other.rimShadow == rimShadow &&
      other.frost == frost &&
      other.shadowColor == shadowColor &&
      other.shadowBlur == shadowBlur &&
      other.shadowOffset == shadowOffset &&
      other.fallbackTint == fallbackTint &&
      other.fallbackBlur == fallbackBlur &&
      other.fallbackBorder == fallbackBorder;

  @override
  int get hashCode => Object.hashAll([
        bevel, refraction, dispersion, blend, lightAngle, specular, rimWidth, sheen, tint, saturation,
        brightness, rimShadow, frost, shadowColor, shadowBlur, shadowOffset, fallbackTint, fallbackBlur,
        fallbackBorder,
      ]);
}
