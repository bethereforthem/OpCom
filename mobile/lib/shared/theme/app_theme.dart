import 'package:flutter/material.dart';

class AppTheme {
  // Surfaces
  static const Color bg         = Color(0xFF0F0E17); // near-black, warm-violet tinted
  static const Color surface    = Color(0xFF1E1B2E); // deep violet-charcoal: cards, app bar, inputs
  static const Color surfaceAlt = Color(0xFF272340); // elevated: sheets, dialogs, selected rows
  static const Color border     = Color(0xFF3D3856);

  // Brand — indigo. Used for brand chrome, links, selection/active-state
  // indicators, and sent-message bubbles. NOT used for action buttons.
  static const Color primary     = Color(0xFF4338CA);
  static const Color primaryDark = Color(0xFF3730A3);

  // Call-to-action — amber. Reserved for "do this now": buttons, the FAB,
  // the send button, in-progress indicators.
  static const Color cta        = Color(0xFFF59E0B);
  static const Color ctaPressed = Color(0xFFD97706);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF97316);
  static const Color danger  = Color(0xFFDC2626);

  // Text
  static const Color textMain = Color(0xFFF8F7FB);
  static const Color textSub  = Color(0xFFA8A3BD);

  // Brand gradient for logo/icon containers and avatars — richer than a
  // flat fill without introducing a third hue.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  // Soft amber glow used behind the "hero" icon on auth/incoming-call
  // screens — the one shared decorative touch tying those moments together.
  static List<BoxShadow> get heroGlow => [
    BoxShadow(color: cta.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: 4),
  ];

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: cta,
      surface: surface,
      error: danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textMain,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      hintStyle: const TextStyle(color: textSub),
      labelStyle: const TextStyle(color: textSub),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: cta,
        foregroundColor: Colors.black87,
        disabledBackgroundColor: cta.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.black54,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primary),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: cta,
      foregroundColor: Colors.black87,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? primary : null,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? primary : textSub,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: surfaceAlt,
      contentTextStyle: TextStyle(color: textMain),
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1),
    useMaterial3: true,
  );
}
