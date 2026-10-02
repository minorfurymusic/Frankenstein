import 'package:flutter/material.dart';

import 'rlt_colors.dart';

/// Espaçamento em dp (`Tokens.dc.html`, "Espaçamento").
abstract final class RltSpace {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Raios em dp (`Tokens.dc.html`, "Raios").
abstract final class RltRadius {
  static const double chip = 8;
  static const double field = 8; // só nos cantos de cima: 8 8 0 0
  static const double icon = 12;
  static const double card = 16;
  static const double navigation = 20;
  static const double button = 24;
  static const double sheet = 28;
}

/// Área mínima de toque (`Tokens.dc.html`, "Toque e contraste").
const double kRltMinTouch = 48;

/// Família embutida no APK (`app/pubspec.yaml`, seção `fonts`).
const String kRltFontFamily = 'Figtree';

/// Tema do RLT montado a partir dos tokens. A escala tipográfica segue
/// `Tokens.dc.html` ("Tipografia — Figtree"); os pesos do design (420, 460,
/// 620…) caem no peso estático mais próximo dos cinco embutidos (400–800).
abstract final class RltTheme {
  static ThemeData light() => _build(Brightness.light, RltColors.light);
  static ThemeData dark() => _build(Brightness.dark, RltColors.dark);

  /// Números tabulares nos valores ("Uma família, números tabulares nos
  /// valores") — kcal, gramas, horários não "dançam" ao mudar.
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static TextTheme _textTheme(Color on, Color onVariant) {
    TextStyle s(double size, double height, FontWeight weight, [Color? color]) => TextStyle(
          fontFamily: kRltFontFamily,
          fontSize: size,
          height: height / size,
          fontWeight: weight,
          color: color ?? on,
          letterSpacing: 0,
        );
    return TextTheme(
      displaySmall: s(40, 48, FontWeight.w800), // Display · 40/48 · 750
      headlineMedium: s(28, 36, FontWeight.w700), // Título 1 · 28/36 · 720
      headlineSmall: s(24, 32, FontWeight.w700), // Título 2 · 24/32 · 700
      titleLarge: s(20, 28, FontWeight.w700), // Título 3 · 20/28 · 680
      titleMedium: s(18, 24, FontWeight.w700), // Título de cartão · 18/24 · 650
      titleSmall: s(16, 22, FontWeight.w600), // Título pequeno · 16/22 · 640
      bodyLarge: s(16, 24, FontWeight.w400), // Corpo grande · 16/24 · 420
      bodyMedium: s(14, 20, FontWeight.w400), // Corpo · 14/20 · 420
      bodySmall: s(12, 16, FontWeight.w500, onVariant), // Legenda · 12/16 · 460
      labelLarge: s(15, 20, FontWeight.w700), // texto de botão
      labelMedium: s(12, 16, FontWeight.w600), // Rótulo · 12/16 · 620
      labelSmall: s(11, 16, FontWeight.w700, onVariant), // sobretítulo em caixa alta
    );
  }

  static ThemeData _build(Brightness brightness, RltColors c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.secondary,
      onSecondary: c.onPrimary,
      secondaryContainer: c.secondaryContainer,
      onSecondaryContainer: c.onSecondaryContainer,
      tertiary: c.tertiary,
      onTertiary: c.onPrimary,
      tertiaryContainer: c.tertiaryContainer,
      onTertiaryContainer: c.onTertiaryContainer,
      error: c.error,
      onError: c.onError,
      errorContainer: c.errorContainer,
      onErrorContainer: c.onErrorContainer,
      surface: c.surface,
      onSurface: c.onSurface,
      onSurfaceVariant: c.onSurfaceVariant,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surfaceContainerLow,
      surfaceContainer: c.surfaceContainer,
      surfaceContainerHigh: c.surfaceContainerHigh,
      surfaceContainerHighest: c.surfaceContainerHighest,
      outline: c.outline,
      outlineVariant: c.outlineVariant,
      inverseSurface: c.inverseSurface,
      onInverseSurface: c.onInverseSurface,
      inversePrimary: brightness == Brightness.light ? RltColors.dark.primary : RltColors.light.primary,
      scrim: c.scrim,
      shadow: c.shadow,
    );
    final text = _textTheme(c.onSurface, c.onSurfaceVariant);
    const pill = StadiumBorder();
    const buttonMinSize = Size(kRltMinTouch, kRltMinTouch);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: kRltFontFamily,
      textTheme: text,
      scaffoldBackgroundColor: c.surface,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RltRadius.card),
          side: BorderSide(color: c.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: pill,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: pill,
          foregroundColor: c.primary,
          side: BorderSide(color: c.outline),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: pill,
          foregroundColor: c.primary,
          textStyle: text.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primaryContainer,
        foregroundColor: c.onPrimaryContainer,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RltRadius.card)),
        extendedTextStyle: text.labelLarge?.copyWith(fontSize: 16),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: c.secondaryContainer,
          selectedForegroundColor: c.onSecondaryContainer,
          side: BorderSide(color: c.outline),
          textStyle: text.labelLarge?.copyWith(fontSize: 14),
          minimumSize: const Size(kRltMinTouch, kRltMinTouch),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: buttonMinSize),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RltRadius.chip)),
        side: BorderSide(color: c.outline),
        backgroundColor: c.surface,
        selectedColor: c.secondaryContainer,
        labelStyle: text.labelLarge?.copyWith(fontSize: 14, color: c.onSurface),
        checkmarkColor: c.onSecondaryContainer,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceContainerHigh,
        labelStyle: text.labelMedium?.copyWith(color: c.onSurfaceVariant),
        floatingLabelStyle: text.labelMedium?.copyWith(color: c.primary),
        border: UnderlineInputBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(RltRadius.field)),
          borderSide: BorderSide(color: c.onSurfaceVariant),
        ),
        enabledBorder: UnderlineInputBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(RltRadius.field)),
          borderSide: BorderSide(color: c.onSurfaceVariant),
        ),
        focusedBorder: UnderlineInputBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(RltRadius.field)),
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(RltRadius.field)),
          borderSide: BorderSide(color: c.error, width: 2),
        ),
        errorStyle: text.bodySmall?.copyWith(color: c.error),
      ),
      dividerTheme: DividerThemeData(color: c.outlineVariant, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.secondaryContainer,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.onInverseSurface),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RltRadius.sheet)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(RltRadius.sheet)),
        ),
      ),
    );
  }
}
