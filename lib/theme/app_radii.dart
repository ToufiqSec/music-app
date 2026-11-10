import 'package:flutter/material.dart';

/// Exact corner radii tokens from Section 6 of Universal UI Design System: Twilight Calm.
class AppRadii {
  static const double small = 12.0;
  static const double medium = 16.0;
  static const double large = 24.0;
  static const double xlarge = 32.0;
  static const double full = 999.0;
  static const double pill = 999.0;

  static const double radiusSmall = small;
  static const double radiusMedium = medium;
  static const double radiusLarge = large;
  static const double radiusXL = xlarge;
  static const double radiusFull = full;

  static const Radius rSmall = Radius.circular(small);
  static const Radius rMedium = Radius.circular(medium);
  static const Radius rLarge = Radius.circular(large);
  static const Radius rXL = Radius.circular(xlarge);
  static const Radius rFull = Radius.circular(full);
  static const Radius rPill = Radius.circular(pill);

  static const BorderRadius borderSmall = BorderRadius.all(rSmall);
  static const BorderRadius borderMedium = BorderRadius.all(rMedium);
  static const BorderRadius borderLarge = BorderRadius.all(rLarge);
  static const BorderRadius borderXL = BorderRadius.all(rXL);
  static const BorderRadius borderFull = BorderRadius.all(rFull);
  static const BorderRadius borderPill = BorderRadius.all(rPill);
}
