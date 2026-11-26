import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../glass/glass_theme.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'tokens.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final text = AppTypography.textTheme(c.textPrimary, c.textSecondary);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.onPrimarySoft,
      secondary: c.accent,
      onSecondary: isDark ? c.onPrimary : Colors.white,
      secondaryContainer: c.accentSoft,
      onSecondaryContainer: c.textPrimary,
      tertiary: c.info,
      onTertiary: Colors.white,
      error: c.danger,
      onError: isDark ? c.onPrimary : Colors.white,
      errorContainer: c.dangerSoft,
      onErrorContainer: c.textPrimary,
      surface: c.surfaceRaised,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.surfaceRaised,
      surfaceContainerLow: c.surfaceRaised,
      surfaceContainer: c.surfaceMuted,
      surfaceContainerHigh: c.surfaceMuted,
      surfaceContainerHighest: c.surfaceMuted,
      outline: c.outlineStrong,
      outlineVariant: c.outline,
      shadow: c.shadow,
      scrim: c.scrim,
      inverseSurface: c.textPrimary,
      onInverseSurface: isDark ? c.background : Colors.white,
      inversePrimary: c.primarySoft,
    );

    OutlineInputBorder border(Color color, [double width = 1.2]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm + 2),
          borderSide: BorderSide(color: color, width: width),
        );

    const transitions = PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
    });

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.family,
      textTheme: text,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.transparent,
      pageTransitionsTheme: transitions,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      iconTheme: IconThemeData(color: c.textPrimary, size: 24),
      dividerTheme: DividerThemeData(color: c.outline, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: c.textPrimary,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: border(c.outline),
        enabledBorder: border(c.outline),
        focusedBorder: border(c.primary, 1.8),
        errorBorder: border(c.danger),
        focusedErrorBorder: border(c.danger, 1.8),
        labelStyle: text.bodyLarge!.copyWith(color: c.textSecondary),
        floatingLabelStyle: text.bodyMedium!.copyWith(color: c.primary),
        hintStyle: text.bodyLarge!.copyWith(color: c.textTertiary),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall!.copyWith(color: c.danger),
        prefixIconColor: c.textSecondary,
        suffixIconColor: c.textSecondary,
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionColor: c.primary.withValues(alpha: 0.25),
        selectionHandleColor: c.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? (isDark ? c.onPrimary : Colors.white) : c.surfaceRaised,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.outlineStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: c.outlineStrong, width: 1.6),
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : null),
        checkColor: WidgetStatePropertyAll(c.onPrimary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.primarySoft,
        circularTrackColor: c.primarySoft,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.textPrimary,
        contentTextStyle: text.bodyMedium!.copyWith(color: isDark ? c.background : Colors.white),
        actionTextColor: isDark ? c.primarySoft : const Color(0xFF7DE3F4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 108),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
        hourMinuteShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        dayPeriodShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        dialBackgroundColor: c.surfaceMuted,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.textPrimary, borderRadius: BorderRadius.circular(10)),
        textStyle: text.bodySmall!.copyWith(color: isDark ? c.background : Colors.white),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      extensions: [
        c,
        // Light mode tints with the deeper teal so white labels keep AA contrast.
        isDark
            ? GlassTheme.dark(primary: c.primary, danger: c.danger)
            : GlassTheme.light(primary: c.primaryStrong, danger: const Color(0xFFC81E1E)),
      ],
    );
  }
}

extension ThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
  TextTheme get text => Theme.of(this).textTheme;
  GlassTheme get glass => GlassTheme.of(this);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);
}
