import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlassTheme {
  // Deep obsidian luxury dark palette
  static const Color bgDark = Color(0xFF090D16);
  static const Color bgDarkSecondary = Color(0xFF0F172A);
  static const Color bgSurface = Color(0xFF1E293B);

  // Vibrant accent neon glows
  static const Color primaryNeon = Color(0xFF6366F1); // Indigo / Violet
  static const Color secondaryNeon = Color(0xFF8B5CF6); // Purple
  static const Color accentEmerald = Color(0xFF10B981); // Emerald Green
  static const Color accentCyan = Color(0xFF06B6D4); // Cyan Blue
  static const Color accentRose = Color(0xFFF43F5E); // Rose
  static const Color accentAmber = Color(0xFFF59E0B); // Amber / Gold

  // Glass card styling
  static const Color glassFill = Color(0x14FFFFFF); // 8% opacity white
  static const Color glassFillHover = Color(0x24FFFFFF); // 14% opacity white
  static const Color glassBorder = Color(0x33FFFFFF); // 20% opacity white
  static const Color glassBorderGlow = Color(0x666366F1); // Indigo glow border

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x1AFFFFFF), Color(0x08FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient backgroundMesh = RadialGradient(
    center: Alignment(-0.8, -0.6),
    radius: 1.2,
    colors: [
      Color(0x286366F1),
      Color(0x00000000),
    ],
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: primaryNeon,
      colorScheme: const ColorScheme.dark(
        primary: primaryNeon,
        secondary: secondaryNeon,
        surface: bgSurface,
        error: accentRose,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      useMaterial3: true,
    );
  }
}
