import 'package:flutter/material.dart';

/// Figtree type scale. Figtree ships as one variable font, so every style
/// sets the `wght` axis explicitly as well as [FontWeight].
abstract final class AppTypography {
  static const String family = 'Figtree';

  static TextStyle style(
    double size,
    double weight, {
    double? height,
    double letterSpacing = 0,
    bool tabular = false,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: _nearest(weight),
      fontVariations: [FontVariation('wght', weight)],
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
  }

  /// Re-weights an existing style (keeps the variable axis in sync).
  static TextStyle weight(TextStyle base, double weight) =>
      base.copyWith(fontWeight: _nearest(weight), fontVariations: [FontVariation('wght', weight)]);

  static FontWeight _nearest(double w) {
    final index = ((w - 100) / 100).round().clamp(0, 8);
    return FontWeight.values[index];
  }

  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: style(48, 800, height: 1.0, letterSpacing: -1.2, tabular: true).copyWith(color: primary),
      displayMedium: style(38, 800, height: 1.05, letterSpacing: -1.0, tabular: true).copyWith(color: primary),
      displaySmall: style(31, 800, height: 1.1, letterSpacing: -0.8, tabular: true).copyWith(color: primary),
      headlineLarge: style(30, 800, height: 1.12, letterSpacing: -0.8).copyWith(color: primary),
      headlineMedium: style(25, 760, height: 1.18, letterSpacing: -0.5).copyWith(color: primary),
      headlineSmall: style(21, 720, height: 1.22, letterSpacing: -0.3).copyWith(color: primary),
      titleLarge: style(19, 700, height: 1.25, letterSpacing: -0.2).copyWith(color: primary),
      titleMedium: style(17, 650, height: 1.3).copyWith(color: primary),
      titleSmall: style(15, 650, height: 1.3).copyWith(color: primary),
      bodyLarge: style(17, 450, height: 1.45).copyWith(color: primary),
      bodyMedium: style(15, 450, height: 1.45).copyWith(color: secondary),
      bodySmall: style(13.5, 480, height: 1.4).copyWith(color: secondary),
      labelLarge: style(16, 650, height: 1.2, letterSpacing: 0.1).copyWith(color: primary),
      labelMedium: style(13.5, 620, height: 1.2, letterSpacing: 0.1).copyWith(color: secondary),
      labelSmall: style(12, 680, height: 1.2, letterSpacing: 0.6).copyWith(color: secondary),
    );
  }
}
