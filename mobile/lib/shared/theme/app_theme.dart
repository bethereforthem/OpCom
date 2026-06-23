import 'package:flutter/material.dart';

class AppTheme {
  // WhatsApp dark mode palette
  static const Color bg         = Color(0xFF0D1418); // deep dark background
  static const Color surface    = Color(0xFF1F2C34); // panels, app bar, input bar
  static const Color surfaceAlt = Color(0xFF2A3942); // elevated: sheets, dialogs, selected rows
  static const Color border     = Color(0xFF2A3942);

  // Brand — WhatsApp teal-green
  static const Color primary     = Color(0xFF00A884);
  static const Color primaryDark = Color(0xFF008069);

  // Message bubbles
  static const Color sentBubble     = Color(0xFF005C4B); // sent messages (dark teal-green)
  static const Color receivedBubble = Color(0xFF1F2C34); // received messages

  // Read receipts — blue ticks when message is read
  static const Color readTick = Color(0xFF53BDEB);

  // Call-to-action — WhatsApp green (FAB, send button)
  static const Color cta        = Color(0xFF00A884);
  static const Color ctaPressed = Color(0xFF008069);

  // Semantic
  static const Color success = Color(0xFF00A884);
  static const Color warning = Color(0xFFF97316);
  static const Color danger  = Color(0xFFDC2626);

  // Text
  static const Color textMain = Color(0xFFE9EDEF);
  static const Color textSub  = Color(0xFF8696A0);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

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
        foregroundColor: Colors.white,
        disabledBackgroundColor: cta.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white60,
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
      foregroundColor: Colors.white,
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
