import 'package:flutter/material.dart';

/// Premium Glassmorphism & Liquid UI Color System.
/// Matches Theme: Dark Purple, Soft Pink & Glossy Effects.
class AppColors {
  // Swarva Official Brand Colors (from App Icon & Splash Spec)
  static const Color swarvaBgDark = Color(0xFF121014); // #121014 Background dark
  static const Color swarvaCoral = Color(0xFFF2566B); // #F2566B Coral
  static const Color swarvaPeach = Color(0xFFFFB48A); // #FFB48A Peach
  static const Color swarvaPink = Color(0xFFE070A8); // #E070A8 Pink
  static const Color swarvaViolet = Color(0xFF9B4FD8); // #9B4FD8 Violet
  static const Color swarvaDeepPurple = Color(0xFF6A3FC8); // #6A3FC8 Deep purple
  static const Color swarvaOffWhite = Color(0xFFF3EEF6); // Clean off-white for Swarva text

  // Main Background & Canvas
  static const Color bgBase = Color(0xFF0B0A12); // Main Background #0B0A12
  static const Color backgroundLayer0 = bgBase;
  static const Color bgDeep = Color(0xFF0B0A12);
  static const Color canvasLight = Color(0xFFF7F5F8);

  // Surfaces & Glassmorphism Cards
  static const Color surface1 = Color(0xFF191724); // Card Background #191724
  static const Color surface2 = Color(0xFF232032); // Elevated Glass Surface
  static const Color surface3 = Color(0xFF2E2A42);
  static const Color surfaceGlow = Color(0xFF382F56);
  static const Color cardBg = surface1; // Card Background #191724

  // Brand, Purples & Pinks
  static const Color primary = Color(0xFF7955D9); // Deep Purple #7955D9
  static const Color primarySoft = Color(0xFFA78BFA); // Soft Purple #A78BFA
  static const Color pinkAccent = Color(0xFFE8A1D1); // Pink Accent #E8A1D1
  static const Color deepPurple = primary;
  static const Color softPurple = primarySoft;
  static const Color sunsetPink = Color(0xFFE8A1D1);
  static const Color sunsetCoral = Color(0xFFE8A1D1);
  static const Color sunsetViolet = Color(0xFF7955D9);
  static const Color accentTeal = Color(0xFF5EEAD4);

  // Glass Borders & Highlights
  static const Color cardBorder = Color(0x33A78BFA);
  static const Color glassBorder = Color(0x2EFFFFFF);
  static const Color glassBorderHighlight = Color(0x59E8A1D1);
  static const Color glassFill = Color(0x80191724);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF); // Primary Text #FFFFFF
  static const Color textSecondary = Color(0xFFAAA5B8); // Secondary Text #AAA5B8
  static const Color primaryText = textPrimary;
  static const Color secondaryText = textSecondary;
  static const Color textTertiary = Color(0xFF837D94);
  static const Color textMuted = Color(0xFF6E6880);
  static const Color textOnLight = Color(0xFF1E1B24);

  // Controls & Icons
  static const Color controlLight = Color(0xFFF0EBF8);
  static const Color controlLightIcon = Color(0xFF0B0A12);
  static const Color iconIdle = Color(0xFFAAA5B8);
  static const Color iconActive = Color(0xFFFFFFFF);
  static const Color iconDisabled = Color(0xFF555060);
  static const Color scrim = Color(0x800B0A12);

  // Status
  static const Color success = Color(0xFF7EE0B5);
  static const Color warning = Color(0xFFF5C97A);
  static const Color error = Color(0xFFFF8FA3);

  // Gradients
  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF140F26),
      Color(0xFF0B0A12),
      Color(0xFF0E0B18),
    ],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF7955D9),
      Color(0xFFE8A1D1),
    ],
  );

  static const LinearGradient heroCardOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0xCC0B0A12),
    ],
  );

  static const LinearGradient glassCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x5928233C),
      Color(0x40191724),
    ],
  );

  static const LinearGradient playerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF261D42),
      Color(0xFF191724),
      Color(0xFF0B0A12),
    ],
  );

  static const LinearGradient cardImageOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0xE60B0A12),
    ],
  );

  static const LinearGradient scrimGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0xB30B0A12),
    ],
  );
}
