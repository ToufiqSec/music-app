import 'package:flutter/foundation.dart';

/// Robust numeric safety utilities to prevent 'Unsupported operation: Infinity or NaN toInt'.
/// Guarantees safe conversion, division, clamping, and error isolation.

/// Safely converts [value] (num, String, or Object) to an integer.
/// Returns [fallback] if value is null, non-numeric, NaN, Infinity, or -Infinity.
int safeInt(Object? value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) {
    if (value.isFinite) {
      return value.toInt();
    }
    debugPrint('[NumericUtils] safeInt received non-finite num: $value. Returning fallback: $fallback');
    return fallback;
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return fallback;
    final parsedInt = int.tryParse(trimmed);
    if (parsedInt != null) return parsedInt;
    final parsedNum = num.tryParse(trimmed);
    if (parsedNum != null && parsedNum.isFinite) {
      return parsedNum.toInt();
    }
  }
  return fallback;
}

/// Safely converts [value] to a finite double.
/// Returns [fallback] if value is null, non-numeric, NaN, Infinity, or -Infinity.
double safeDouble(Object? value, {double fallback = 0.0}) {
  if (value == null) return fallback;
  if (value is double) {
    if (value.isFinite) return value;
    return fallback;
  }
  if (value is num) {
    if (value.isFinite) return value.toDouble();
    return fallback;
  }
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null && parsed.isFinite) {
      return parsed;
    }
  }
  return fallback;
}

/// Safely performs division [numerator] / [denominator].
/// Returns [fallback] if either is null, non-finite, or if [denominator] <= 0.
double safeDivide(num? numerator, num? denominator, {double fallback = 0.0}) {
  if (numerator == null || denominator == null) return fallback;
  if (!numerator.isFinite || !denominator.isFinite || denominator <= 0) {
    return fallback;
  }
  final result = numerator / denominator;
  if (!result.isFinite) return fallback;
  return result;
}

/// Safely computes progress percentage clamped between 0.0 and 1.0.
double safeProgress(num? current, num? total) {
  if (current == null || total == null) return 0.0;
  if (!current.isFinite || !total.isFinite || total <= 0) return 0.0;
  final ratio = current / total;
  if (!ratio.isFinite) return 0.0;
  return ratio.clamp(0.0, 1.0);
}

/// Safely clamps a duration in seconds, treating <= 0 as unknown/fallback.
int safeDuration(int? durationSeconds, {int fallback = 0}) {
  if (durationSeconds == null || durationSeconds <= 0) {
    return fallback;
  }
  return durationSeconds;
}
