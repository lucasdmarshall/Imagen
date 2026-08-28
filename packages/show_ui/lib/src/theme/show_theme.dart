import 'package:flutter/material.dart';

import '../motion/show_motion.dart';
import '../tokens/show_colors.dart';
import '../tokens/show_spacing.dart';
import '../tokens/show_typography.dart';

/// Builds the SHOW [ThemeData] — a borderless, cardless, boxless, matte,
/// Swiss-style theme shared by both the Client and Admin apps.
///
/// Design guarantees baked in here:
/// - No gradients anywhere (flat fills only).
/// - Cards/dialogs are flat with zero elevation (no drop shadows).
/// - Inputs are underline-only (no boxed borders).
/// - Controls are tall (>= 56dp) for the 40+ audience.
class ShowTheme {
  ShowTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final bg = isLight ? ShowColors.cream : ShowColors.darkBg;
    final surface = isLight ? ShowColors.creamRaised : ShowColors.darkRaised;
    final onSurface = isLight ? ShowColors.ink : ShowColors.darkInk;
    final onSurfaceMuted = isLight ? ShowColors.inkMuted : ShowColors.darkInkMuted;
    final hairline = isLight ? ShowColors.hairline : ShowColors.darkHairline;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: ShowColors.accent,
      onPrimary: ShowColors.cream,
      secondary: ShowColors.accent,
      onSecondary: ShowColors.cream,
      surface: surface,
      onSurface: onSurface,
      error: ShowColors.danger,
      onError: ShowColors.cream,
    );

    final baseText = ShowTypography(onSurface, onSurfaceMuted);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: hairline,
      textTheme: baseText.textTheme,

      // Smooth fade-through navigation on every platform (incl. web).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ShowPageTransitions(),
          TargetPlatform.iOS: ShowPageTransitions(),
          TargetPlatform.macOS: ShowPageTransitions(),
          TargetPlatform.windows: ShowPageTransitions(),
          TargetPlatform.linux: ShowPageTransitions(),
          TargetPlatform.fuchsia: ShowPageTransitions(),
        },
      ),

      // Borderless app bar: flat, no shadow, no surface tint.
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: ShowType.h3.copyWith(color: onSurface),
      ),

      // Cardless: if a Card is ever used, it is flat with no border/shadow.
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: hairline,
        thickness: ShowSizing.hairline,
        space: ShowSpacing.lg,
      ),

      // Underline-only inputs — no boxed borders.
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: ShowSpacing.md),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: ShowColors.accent, width: 2),
        ),
        labelStyle: ShowType.label.copyWith(color: onSurfaceMuted),
        hintStyle: ShowType.body.copyWith(color: ShowColors.inkFaint),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ShowColors.accent,
          foregroundColor: ShowColors.cream,
          elevation: 0,
          minimumSize: const Size.fromHeight(ShowSizing.controlHeight),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          textStyle: ShowType.button,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ShowColors.accent,
          minimumSize: const Size(0, ShowSizing.minTouch),
          textStyle: ShowType.button,
        ),
      ),

      // Flat bottom sheets & dialogs (no elevation gimmicks).
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      listTileTheme: ListTileThemeData(
        minVerticalPadding: ShowSpacing.md,
        iconColor: onSurfaceMuted,
        textColor: onSurface,
      ),

      splashFactory: InkRipple.splashFactory,
    );
  }
}

/// Assembles a Material [TextTheme] from SHOW type tokens for the given colors.
class ShowTypography {
  ShowTypography(this.onSurface, this.onSurfaceMuted);

  final Color onSurface;
  final Color onSurfaceMuted;

  TextTheme get textTheme => TextTheme(
        displayLarge: ShowType.display.copyWith(color: onSurface),
        headlineLarge: ShowType.h1.copyWith(color: onSurface),
        headlineMedium: ShowType.h2.copyWith(color: onSurface),
        headlineSmall: ShowType.h3.copyWith(color: onSurface),
        bodyLarge: ShowType.bodyLarge.copyWith(color: onSurface),
        bodyMedium: ShowType.body.copyWith(color: onSurface),
        bodySmall: ShowType.caption.copyWith(color: onSurfaceMuted),
        labelLarge: ShowType.button.copyWith(color: onSurface),
        labelMedium: ShowType.label.copyWith(color: onSurfaceMuted),
      );
}
