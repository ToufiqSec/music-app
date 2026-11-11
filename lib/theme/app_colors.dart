import 'package:flutter/material.dart';

/// Exact color tokens from Universal UI Design System: Twilight Calm.
class AppColors {
  // Backgrounds and surfaces (Dark mode: Warm charcoal-slate base #121218 to #1A1A22)
  static const Color bgBase = Color(0xFF121218);
  static const Color backgroundLayer0 = bgBase;
  static const Color bgDeep = Color(0xFF0D0D12);
  static const Color surface1 = Color(0xFF1E1E28);
  static const Color surface2 = Color(0xFF282836);
  static const Color surfaceGlow = Color(0xFF38384C);
  static const Color canvasLight = Color(0xFFF7F5F8);

  // Brand and accent
  static const Color primary = Color(0xFF8B6FE8);
  static const Color primarySoft = Color(0xFFA58CF2);
  static const Color sunsetPink = Color(0xFFE887B8);
  static const Color sunsetCoral = Color(0xFFF29BC0);
  static const Color sunsetViolet = Color(0xFF7A4FB8);

  // Text
  static const Color textPrimary = Color(0xFFF2EFF5);
  static const Color textSecondary = Color(0xFFA39CAD);
  static const Color textTertiary = Color(0xFF736C7E);
  static const Color textMuted = Color(0xFF6B6577);
  static const Color textOnLight = Color(0xFF1E1B24);

  // Controls
  static const Color controlLight = Color(0xFFE8E2FA);
  static const Color controlLightIcon = Color(0xFF1E1B24);
  static const Color iconIdle = Color(0xFFA39CAD);
  static const Color iconActive = Color(0xFFFFFFFF);
  static const Color scrim = Color(0x73121218); // 45% opacity of bgBase

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

  // Exact Gradients from Design System
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
      Color(0xFF1E1E28),
      Color(0xFF121218),
    ],
  );

  static const LinearGradient playerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.55, 1.0],
    colors: [
      Color(0xFF28243E),
      Color(0xFF1E1E28),
      Color(0xFF121218),
    ],
  );

  static const LinearGradient cardImageOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 1.0],
    colors: [
      Colors.transparent,
      Color(0xCC121218), // 80% opacity for text readability
    ],
  );

  static const LinearGradient scrimGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 1.0],
    colors: [
      Colors.transparent,
      Color(0xB3121218), // 70% opacity
    ],
  );
}
