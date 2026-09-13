/// Strict numeric clamps for UI-safe financial and scoring displays.
abstract final class NumericBounds {
  static const double minPercent = 0;
  static const double maxPercent = 100;
  static double clampPercent(num value) {
    final d = value.toDouble();
    if (d.isInfinite || d.isNaN) return minPercent;
    return d.clamp(minPercent, maxPercent);
  }

  static int clampPercentInt(num value) => clampPercent(value).round();

  static double clampNonNegative(num value) {
    final d = value.toDouble();
    if (d.isInfinite || d.isNaN) return 0;
    return d < 0 ? 0 : d;
  }

  static double clampCurrency(num value) => clampNonNegative(value);
  static int clampWalkMinutes(num value) => value.round().clamp(0, 120);
  static double clampScoreRatio(num numerator, num denominator) {
    if (denominator <= 0) return 0;
    final ratio = (numerator / denominator) * 100;
    if (ratio.isInfinite || ratio.isNaN) return 0;
    return clampPercent(ratio);
  }

  /// Rejects Infinity/NaN before any JSON or UI bind.
  static double finiteOrZero(num value) {
    final d = value.toDouble();
    if (d.isInfinite || d.isNaN) return 0;
    return d;
  }

  static double? finiteOrNull(num? value) {
    if (value == null) return null;
    final d = value.toDouble();
    if (d.isInfinite || d.isNaN) return null;
    return d;
  }
}
