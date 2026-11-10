import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors (easily customizable for user's design)
  static const Color primary = Color(0xFF6C5CE7);
  static const Color secondary = Color(0xFFA29BFE);
  static const Color accent = Color(0xFF00CEC9);
  
  static const Color darkBackground = Color(0xFF0F0F1A);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF22223B);
  
  static const Color textPrimary = Color(0xFFF8F9FA);
  static const Color textSecondary = Color(0xFFA0A0B2);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkCard,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
      ),
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: darkSurface,
      ),
    );
  }
}
