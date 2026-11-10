import 'package:flutter/material.dart';

/// Exact motion, duration, and curve tokens from Section 8 of Universal UI Design System: Twilight Calm.
class AppMotion {
  // Durations
  static const Duration durationFast = Duration(milliseconds: 120);
  static const Duration durationBase = Duration(milliseconds: 200);
  static const Duration durationMedium = Duration(milliseconds: 320);
  static const Duration durationSlow = Duration(milliseconds: 480);
  static const Duration durationHero = Duration(milliseconds: 600);
  static const Duration durationAmbient = Duration(milliseconds: 8000);

  // Curves
  static const Curve curveStandard = Cubic(0.4, 0.0, 0.2, 1.0);
  static const Curve curveDecelerate = Cubic(0.0, 0.0, 0.2, 1.0);
  static const Curve curveAccelerate = Cubic(0.4, 0.0, 1.0, 1.0);
  static const Curve curveEmphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  // Soft spring description (mass 1, stiffness 180, damping 22 - no visible overshoot)
  static const SpringDescription springSoft = SpringDescription(
    mass: 1.0,
    stiffness: 180.0,
    damping: 22.0,
  );
}
