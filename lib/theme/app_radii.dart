import 'package:flutter/material.dart';

/// Exact corner radii tokens from Section 6 of Universal UI Design System: Twilight Calm.
class AppRadii {
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  static const double radiusXL = 32.0;
  static const double radiusFull = 999.0;

  static const Radius rSmall = Radius.circular(radiusSmall);
  static const Radius rMedium = Radius.circular(radiusMedium);
  static const Radius rLarge = Radius.circular(radiusLarge);
  static const Radius rXL = Radius.circular(radiusXL);
  static const Radius rFull = Radius.circular(radiusFull);

  static const BorderRadius borderSmall = BorderRadius.all(rSmall);
  static const BorderRadius borderMedium = BorderRadius.all(rMedium);
  static const BorderRadius borderLarge = BorderRadius.all(rLarge);
  static const BorderRadius borderXL = BorderRadius.all(rXL);
  static const BorderRadius borderFull = BorderRadius.all(rFull);
}
