import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Warm ink-black with ivory type and a single ember accent.
class Pal {
  static const bg = Color(0xFF0C0A0B);
  static const surface = Color(0xFF151112);
  static const raised = Color(0xFF1E181A);
  static const line = Color(0xFF2D2528);
  static const text = Color(0xFFF3EBDD);
  static const dim = Color(0xFF9C918A);
  static const ember = Color(0xFFFF6B3D);
  static const gold = Color(0xFFE8C77A);
}

TextStyle display(double size, {FontWeight weight = FontWeight.w600, Color color = Pal.text}) =>
    GoogleFonts.fraunces(fontSize: size, fontWeight: weight, color: color, height: 1.05, letterSpacing: -0.5);

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final body = GoogleFonts.manropeTextTheme(base.textTheme).apply(bodyColor: Pal.text, displayColor: Pal.text);
  return base.copyWith(
    scaffoldBackgroundColor: Pal.bg,
    colorScheme: const ColorScheme.dark(
      primary: Pal.ember,
      secondary: Pal.gold,
      surface: Pal.surface,
      onSurface: Pal.text,
    ),
    textTheme: body,
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Pal.surface,
      indicatorColor: Pal.ember.withOpacity(0.18),
      labelTextStyle: WidgetStatePropertyAll(GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Pal.raised,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Pal.ember, width: 1.4),
      ),
      labelStyle: const TextStyle(color: Pal.dim),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Pal.raised,
      side: const BorderSide(color: Pal.line),
      labelStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: Pal.text),
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
