import 'package:flutter/material.dart';

/// Exact elevation, shadow and glass tokens from Section 6 of Universal UI Design System: Twilight Calm.
class AppShadows {
  // shadowSoft: color #1A1240 at 35% opacity, blur 24, offset (0, 8), spread 0.
  static const BoxShadow shadowSoft = BoxShadow(
    color: Color(0x591A1240),
    blurRadius: 24.0,
    offset: Offset(0, 8),
    spreadRadius: 0.0,
  );

  // shadowFloat: color #1A1240 at 45% opacity, blur 32, offset (0, 12), spread 0.
  static const BoxShadow shadowFloat = BoxShadow(
    color: Color(0x731A1240),
    blurRadius: 32.0,
    offset: Offset(0, 12),
    spreadRadius: 0.0,
  );

  // Glass specifications
  static const double glassBlurSigma = 20.0;
  static const Color glassFill = Color(0x1AFFFFFF); // #FFFFFF at 10%
  static const Color glassBorderColor = Color(0x2EFFFFFF); // #FFFFFF at 18%
  static const double glassBorderWidth = 1.0;

  // Semantic card shadows
  static List<BoxShadow> get card => const [shadowSoft];
  static const BoxShadow cardShadow = shadowSoft;
}
