import 'package:flutter/material.dart';

/// "Chubby pastel & neon glow" on a deep slate canvas (PDD §3): the dark
/// canvas lets colourful feedback pop without a bright screen.
abstract final class ES {
  // PDD core palette.
  static const coral = Color(0xFFFF6B6B);
  static const turquoise = Color(0xFF4ECDC4);
  static const canvas = Color(0xFF1A1A2E);

  // Supporting tones.
  static const canvasDeep = Color(0xFF12121F);
  static const card = Color(0xFF24243D);
  static const cardLine = Color(0xFF3A3A5E);
  static const sunshine = Color(0xFFFFD166);
  static const lilac = Color(0xFFB8A1FF);
  static const mint = Color(0xFF95E1A3);
  static const peach = Color(0xFFFF9F68);
  static const cream = Color(0xFFFFF6EC);
  static const muted = Color(0xFFA8A8C8);

  static const font = 'Andika';

  /// Minimum child touch target (PDD: 72 dp).
  static const kidTarget = 76.0;

  /// PDD: thick, rounded borders with a 24 px radius.
  static const radius = 24.0;

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: font,
      colorScheme: ColorScheme.fromSeed(
        seedColor: turquoise,
        brightness: Brightness.dark,
        surface: canvas,
        primary: turquoise,
        secondary: coral,
        tertiary: sunshine,
      ),
      scaffoldBackgroundColor: canvas,
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: cream, displayColor: cream),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: cream,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: font, fontSize: 22, fontWeight: FontWeight.w700, color: cream),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: turquoise,
          foregroundColor: canvasDeep,
          minimumSize: const Size(150, 56),
          textStyle: const TextStyle(fontFamily: font, fontSize: 18, fontWeight: FontWeight.w700),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cream,
          minimumSize: const Size(120, 52),
          side: const BorderSide(color: cardLine, width: 1.5),
          textStyle: const TextStyle(fontFamily: font, fontSize: 16, fontWeight: FontWeight.w700),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: turquoise,
          textStyle: const TextStyle(fontFamily: font, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: cardLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: cardLine, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: turquoise, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: turquoise,
        thumbColor: turquoise,
        inactiveTrackColor: cardLine,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? canvasDeep : muted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? turquoise : card),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: TextStyle(fontFamily: font, color: cream, fontSize: 15),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(color: cardLine, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: canvasDeep,
        indicatorColor: turquoise.withValues(alpha: 0.25),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontFamily: font, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
