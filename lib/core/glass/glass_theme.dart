import 'package:flutter/material.dart';

import 'glass_style.dart';

/// The glass presets of the current theme. Read with `GlassTheme.of(context)`.
@immutable
class GlassTheme extends ThemeExtension<GlassTheme> {
  const GlassTheme({
    required this.surface,
    required this.bar,
    required this.control,
    required this.primary,
    required this.danger,
  });

  /// Cards, sheets and dialogs floating over content.
  final GlassStyle surface;

  /// Navigation bars and headers (thicker, livelier rim).
  final GlassStyle bar;

  /// Small controls: chips, icon buttons, segmented controls.
  final GlassStyle control;

  /// Tinted glass for the primary action.
  final GlassStyle primary;

  /// Tinted glass for destructive or emergency actions.
  final GlassStyle danger;

  static GlassTheme of(BuildContext context) =>
      Theme.of(context).extension<GlassTheme>() ?? GlassTheme.light(primary: const Color(0xFF0E7490));

  factory GlassTheme.light({required Color primary, Color danger = const Color(0xFFDC2626)}) {
    const base = GlassStyle(
      lightAngle: GlassStyle.topLeftLight,
      dispersion: 0.12,
      tint: Color(0x2EFFFFFF),
      saturation: 1.35,
      brightness: 1.05,
      shadowColor: Color(0x1F0B2530),
      fallbackTint: Color(0xC7F7FCFD),
      fallbackBorder: Color(0xCCFFFFFF),
    );
    return GlassTheme(
      surface: base,
      // Bars sit over scrolling content: enough tint and frost that labels stay
      // readable over anything, with the refraction and light at the rim.
      bar: base.copyWith(
        bevel: 22,
        refraction: 15,
        blend: 24,
        specular: 0.85,
        tint: const Color(0xA6F4FAFB),
        frost: 2.5,
        saturation: 1.5,
      ),
      control: base.copyWith(bevel: 12, refraction: 9, rimWidth: 1.6, shadowBlur: 14, shadowOffset: 4),
      primary: base.copyWith(
        tint: primary.withValues(alpha: 0.86),
        saturation: 1.15,
        brightness: 0.96,
        specular: 0.9,
        sheen: 0.7,
        shadowColor: primary.withValues(alpha: 0.30),
        fallbackTint: primary.withValues(alpha: 0.92),
        fallbackBorder: const Color(0x80FFFFFF),
      ),
      danger: base.copyWith(
        tint: danger.withValues(alpha: 0.88),
        saturation: 1.1,
        brightness: 0.96,
        specular: 0.9,
        sheen: 0.7,
        shadowColor: danger.withValues(alpha: 0.30),
        fallbackTint: danger.withValues(alpha: 0.92),
        fallbackBorder: const Color(0x80FFFFFF),
      ),
    );
  }

  factory GlassTheme.dark({required Color primary, Color danger = const Color(0xFFF87171)}) {
    const base = GlassStyle(
      lightAngle: GlassStyle.topLeftLight,
      dispersion: 0.12,
      tint: Color(0x3D0A1D24),
      saturation: 1.25,
      brightness: 0.95,
      specular: 0.6,
      rimShadow: 0.6,
      shadowColor: Color(0x66000000),
      fallbackTint: Color(0xD90B232B),
      fallbackBorder: Color(0x40FFFFFF),
    );
    return GlassTheme(
      surface: base,
      bar: base.copyWith(
        bevel: 22,
        refraction: 15,
        blend: 24,
        specular: 0.7,
        tint: const Color(0xB30B1E25),
        frost: 2.5,
        saturation: 1.4,
      ),
      control: base.copyWith(bevel: 12, refraction: 9, rimWidth: 1.6, shadowBlur: 14, shadowOffset: 4),
      primary: base.copyWith(
        tint: primary.withValues(alpha: 0.78),
        saturation: 1.1,
        brightness: 1.0,
        specular: 0.8,
        shadowColor: primary.withValues(alpha: 0.28),
        fallbackTint: primary.withValues(alpha: 0.92),
        fallbackBorder: const Color(0x66FFFFFF),
      ),
      danger: base.copyWith(
        tint: danger.withValues(alpha: 0.78),
        saturation: 1.1,
        brightness: 1.0,
        specular: 0.8,
        shadowColor: danger.withValues(alpha: 0.28),
        fallbackTint: danger.withValues(alpha: 0.92),
        fallbackBorder: const Color(0x66FFFFFF),
      ),
    );
  }

  @override
  GlassTheme copyWith({
    GlassStyle? surface,
    GlassStyle? bar,
    GlassStyle? control,
    GlassStyle? primary,
    GlassStyle? danger,
  }) =>
      GlassTheme(
        surface: surface ?? this.surface,
        bar: bar ?? this.bar,
        control: control ?? this.control,
        primary: primary ?? this.primary,
        danger: danger ?? this.danger,
      );

  @override
  GlassTheme lerp(covariant GlassTheme? other, double t) {
    if (other == null) return this;
    return GlassTheme(
      surface: GlassStyle.lerp(surface, other.surface, t),
      bar: GlassStyle.lerp(bar, other.bar, t),
      control: GlassStyle.lerp(control, other.control, t),
      primary: GlassStyle.lerp(primary, other.primary, t),
      danger: GlassStyle.lerp(danger, other.danger, t),
    );
  }
}
