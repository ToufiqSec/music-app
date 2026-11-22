import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/utils/numeric_utils.dart';

void main() {
  group('NumericUtils - safeInt', () {
    test('returns fallback for null', () {
      expect(safeInt(null), equals(0));
      expect(safeInt(null, fallback: 42), equals(42));
    });

    test('returns fallback for double.nan', () {
      expect(safeInt(double.nan), equals(0));
      expect(safeInt(double.nan, fallback: -1), equals(-1));
    });

    test('returns fallback for double.infinity and double.negativeInfinity', () {
      expect(safeInt(double.infinity), equals(0));
      expect(safeInt(double.infinity, fallback: 100), equals(100));
      expect(safeInt(double.negativeInfinity), equals(0));
      expect(safeInt(double.negativeInfinity, fallback: 99), equals(99));
    });

    test('correctly parses valid integer strings and numbers', () {
      expect(safeInt('12'), equals(12));
      expect(safeInt(3.9), equals(3));
      expect(safeInt(42), equals(42));
      expect(safeInt('  50  '), equals(50));
      expect(safeInt('3.14'), equals(3));
    });

    test('returns fallback for invalid strings or non-numeric objects', () {
      expect(safeInt('abc'), equals(0));
      expect(safeInt('', fallback: 5), equals(5));
      expect(safeInt(Object(), fallback: 7), equals(7));
    });
  });

  group('NumericUtils - safeDouble', () {
    test('returns fallback for null, nan, and infinities', () {
      expect(safeDouble(null), equals(0.0));
      expect(safeDouble(double.nan), equals(0.0));
      expect(safeDouble(double.infinity), equals(0.0));
      expect(safeDouble(double.negativeInfinity), equals(0.0));
    });

    test('parses finite double values and strings', () {
      expect(safeDouble(3.14), equals(3.14));
      expect(safeDouble('2.718'), equals(2.718));
      expect(safeDouble(10), equals(10.0));
    });
  });

  group('NumericUtils - safeDivide and safeProgress', () {
    test('safeDivide handles zero, negative, or invalid denominators', () {
      expect(safeDivide(10, 0), equals(0.0));
      expect(safeDivide(10, -5), equals(0.0));
      expect(safeDivide(null, 10), equals(0.0));
      expect(safeDivide(10, null), equals(0.0));
      expect(safeDivide(double.infinity, 10), equals(0.0));
      expect(safeDivide(10, double.infinity), equals(0.0));
      expect(safeDivide(10, 2), equals(5.0));
    });

    test('safeProgress clamps between 0.0 and 1.0', () {
      expect(safeProgress(50, 100), equals(0.5));
      // Progress above 1.0 clamped to 1.0
      expect(safeProgress(150, 100), equals(1.0));
      // Progress below 0.0 clamped to 0.0
      expect(safeProgress(-10, 100), equals(0.0));
      // Zero total or negative total returns 0.0
      expect(safeProgress(50, 0), equals(0.0));
      expect(safeProgress(50, -100), equals(0.0));
      // Nulls or non-finite returns 0.0
      expect(safeProgress(null, 100), equals(0.0));
      expect(safeProgress(50, double.infinity), equals(0.0));
    });
  });

  group('NumericUtils - safeDuration', () {
    test('handles zero and negative duration values', () {
      expect(safeDuration(0), equals(0));
      expect(safeDuration(-15), equals(0));
      expect(safeDuration(null), equals(0));
      expect(safeDuration(0, fallback: 30), equals(30));
      expect(safeDuration(-1, fallback: 60), equals(60));
      expect(safeDuration(null, fallback: 120), equals(120));
    });

    test('preserves valid positive duration values', () {
      expect(safeDuration(240), equals(240));
      expect(safeDuration(1), equals(1));
    });
  });
}
