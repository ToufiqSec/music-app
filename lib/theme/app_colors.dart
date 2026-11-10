import 'package:flutter/material.dart';

/// Exact color tokens from Section 2 & 3 of Universal UI Design System: Twilight Calm.
class AppColors {
  // Backgrounds and surfaces
  static const Color bgBase = Color(0xFF2B2160);
  static const Color bgDeep = Color(0xFF231A52);
  static const Color surface1 = Color(0xFF3A2F7A);
  static const Color surface2 = Color(0xFF4A3D96);
  static const Color surfaceGlow = Color(0xFF5A4BB0);
  static const Color canvasLight = Color(0xFFEDE6FF);

  // Brand and accent
  static const Color primary = Color(0xFF8B6FE8);
  static const Color primarySoft = Color(0xFFA98BF2);
  static const Color sunsetPink = Color(0xFFF29BC0);
  static const Color sunsetRose = Color(0xFFE070A8);
  static const Color sunsetViolet = Color(0xFF7A4FB8);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCFC3F5);
  static const Color textTertiary = Color(0xFF9E92D6);
  static const Color textOnLight = Color(0xFF2B2160);

  // Controls
  static const Color controlLight = Color(0xFFE8E2FA);
  static const Color controlLightIcon = Color(0xFF2B2160);
  static const Color iconIdle = Color(0xFFA99DE0);
  static const Color iconActive = Color(0xFFFFFFFF);
  static const Color scrim = Color(0x731A1240); // #1A1240 at 45% opacity

  // Status
  static const Color success = Color(0xFF7EE0B5);
  static const Color warning = Color(0xFFF5C97A);
  static const Color error = Color(0xFFFF8FA3);

  // Illustration Mountain & Forest Palettes
  static const Color mountainFarthest = Color(0xFFE070A8);
  static const Color mountainLayer2 = Color(0xFFA8559E);
  static const Color mountainLayer3 = Color(0xFF7A4FB8);
  static const Color mountainLayer4 = Color(0xFF4A3D96);
  static const Color mountainNearest = Color(0xFF2B2160);
  static const Color forestForeground = Color(0xFF231A52);

  // Water Palettes
  static const Color waterTop = Color(0xFF8A6FD6);
  static const Color waterBottom = Color(0xFF6B55C4);

  // Exact Gradients from Section 2
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.45, 1.0],
    colors: [
      Color(0xFFF29BC0),
      Color(0xFFE070A8),
      Color(0xFF7A4FB8),
    ],
  );

  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 1.0],
    colors: [
      Color(0xFF3A2F7A),
      Color(0xFF231A52),
    ],
  );

  static const LinearGradient playerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.55, 1.0],
    colors: [
      Color(0xFF6B55C4),
      Color(0xFF8A6FD6),
      Color(0xFF4A3D96),
    ],
  );

  static const LinearGradient cardImageOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 1.0],
    colors: [
      Colors.transparent,
      Color(0xB31A1240), // #1A1240 at 70% opacity
    ],
  );
}
