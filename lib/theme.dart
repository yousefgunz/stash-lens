import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette lifted from the Stash Lens web app (index.html :root).
class Pal {
  static const bg = Color(0xFF07080C);
  static const bg2 = Color(0xFF0E1016);
  static const bg3 = Color(0xFF151821);
  static const bg4 = Color(0xFF1D212C);
  static const ink = Color(0xFFF5F2ED);
  static const mute = Color(0xFFA3A4B0);
  static const dim = Color(0xFF666877);
  static const line = Color(0x17FFFFFF);
  static const a = Color(0xFFFF4757);
  static const a2 = Color(0xFFFFA94D);
  static const gold = Color(0xFFFFB14D);

  static const grad = LinearGradient(
    colors: [Color(0xFFFF3D5A), Color(0xFFFF7A3D), Color(0xFFFFB14D)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const resColors = <String, Color>{
    '8K': Color(0xFFFF2D6F),
    '6K': Color(0xFFFF3D4A),
    '4K': Color(0xFFFF5A3D),
    '1440p': Color(0xFFFF7A3D),
    '1080p': Color(0xFFFFB14D),
    '720p': Color(0xFF8EC5FF),
    '480p': Color(0xFF6C7AA8),
    'SD': Color(0xFF4A4F66),
  };
}

TextStyle heading(double size, {FontWeight w = FontWeight.w800, Color color = Pal.ink}) =>
    GoogleFonts.bricolageGrotesque(fontSize: size, fontWeight: w, color: color, height: 1.05, letterSpacing: -size * 0.03);

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final text = GoogleFonts.bricolageGrotesqueTextTheme(base.textTheme).apply(bodyColor: Pal.ink, displayColor: Pal.ink);
  return base.copyWith(
    scaffoldBackgroundColor: Pal.bg,
    colorScheme: const ColorScheme.dark(primary: Pal.a, secondary: Pal.a2, surface: Pal.bg2, onSurface: Pal.ink),
    textTheme: text,
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xF2090A0F),
      height: 66,
      indicatorColor: Pal.a.withOpacity(0.16),
      labelTextStyle: WidgetStatePropertyAll(GoogleFonts.bricolageGrotesque(fontSize: 11.5, fontWeight: FontWeight.w600)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Pal.bg3,
      hintStyle: const TextStyle(color: Pal.dim),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: Pal.a, width: 1.2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ),
    dividerColor: Pal.line,
    splashFactory: InkSparkle.splashFactory,
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Pal.bg2, surfaceTintColor: Colors.transparent),
    dialogTheme: DialogThemeData(backgroundColor: Pal.bg2, surfaceTintColor: Colors.transparent),
    popupMenuTheme: const PopupMenuThemeData(color: Pal.bg3, surfaceTintColor: Colors.transparent),
  );
}
