import 'package:flutter/material.dart';

/// Semantic colours. Components use these roles, never raw hex values.
///
/// Light-theme text pairs meet WCAG AA on [surface] (primary 15:1,
/// secondary 6:1); status colours meet 4.5:1 as text on [surface].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceRaised,
    required this.outline,
    required this.outlineStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.primaryStrong,
    required this.primarySoft,
    required this.onPrimary,
    required this.onPrimarySoft,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.aurora,
    required this.shadow,
    required this.scrim,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceRaised;
  final Color outline;
  final Color outlineStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color primary;
  final Color primaryStrong;
  final Color primarySoft;
  final Color onPrimary;
  final Color onPrimarySoft;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;

  /// Colours of the slow-moving background blobs.
  final List<Color> aurora;
  final Color shadow;
  final Color scrim;

  static const light = AppColors(
    background: Color(0xFFEEF6F8),
    surface: Color(0xF2FFFFFF),
    surfaceMuted: Color(0xFFEFF5F7),
    surfaceRaised: Color(0xFFFFFFFF),
    outline: Color(0xFFDCE8EC),
    outlineStrong: Color(0xFFC1D3D9),
    textPrimary: Color(0xFF0B2530),
    textSecondary: Color(0xFF4A6470),
    textTertiary: Color(0xFF6E8791),
    primary: Color(0xFF0E7490),
    primaryStrong: Color(0xFF155E75),
    primarySoft: Color(0xFFDDF3F7),
    onPrimary: Color(0xFFFFFFFF),
    onPrimarySoft: Color(0xFF0B5566),
    accent: Color(0xFF047857),
    accentSoft: Color(0xFFD9F4E8),
    success: Color(0xFF047857),
    successSoft: Color(0xFFDDF5EA),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFFDF0DC),
    danger: Color(0xFFDC2626),
    dangerSoft: Color(0xFFFDE5E5),
    info: Color(0xFF2563EB),
    infoSoft: Color(0xFFE1EAFE),
    aurora: [Color(0xFF67E8F9), Color(0xFF6EE7B7), Color(0xFF93C5FD), Color(0xFFFDD7AA)],
    shadow: Color(0x1F0B2530),
    scrim: Color(0x730B2530),
  );

  static const dark = AppColors(
    background: Color(0xFF04141A),
    surface: Color(0xF00B232B),
    surfaceMuted: Color(0xFF102C35),
    surfaceRaised: Color(0xFF12313B),
    outline: Color(0xFF1E3D47),
    outlineStrong: Color(0xFF2B525E),
    textPrimary: Color(0xFFE6F6F9),
    textSecondary: Color(0xFF9FBCC6),
    textTertiary: Color(0xFF7A97A1),
    primary: Color(0xFF22D3EE),
    primaryStrong: Color(0xFF67E8F9),
    primarySoft: Color(0xFF0E3A45),
    onPrimary: Color(0xFF03181E),
    onPrimarySoft: Color(0xFFA5F3FC),
    accent: Color(0xFF34D399),
    accentSoft: Color(0xFF0F3B2E),
    success: Color(0xFF34D399),
    successSoft: Color(0xFF0F3B2E),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF3A2B0A),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF3F1517),
    info: Color(0xFF60A5FA),
    infoSoft: Color(0xFF11264A),
    aurora: [Color(0xFF0E7490), Color(0xFF047857), Color(0xFF1D4ED8), Color(0xFF155E75)],
    shadow: Color(0x80000000),
    scrim: Color(0x99000000),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      outline: l(outline, other.outline),
      outlineStrong: l(outlineStrong, other.outlineStrong),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      primary: l(primary, other.primary),
      primaryStrong: l(primaryStrong, other.primaryStrong),
      primarySoft: l(primarySoft, other.primarySoft),
      onPrimary: l(onPrimary, other.onPrimary),
      onPrimarySoft: l(onPrimarySoft, other.onPrimarySoft),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      info: l(info, other.info),
      infoSoft: l(infoSoft, other.infoSoft),
      aurora: [for (var i = 0; i < aurora.length; i++) l(aurora[i], other.aurora[i % other.aurora.length])],
      shadow: l(shadow, other.shadow),
      scrim: l(scrim, other.scrim),
    );
  }
}
