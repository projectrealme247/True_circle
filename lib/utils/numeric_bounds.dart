/// Strict numeric clamps for UI-safe financial and scoring displays.
abstract final class NumericBounds {
  static const double minPercent = 0;
  static const double maxPercent = 100;
  static double clampPercent(num value) => value.toDouble().clamp(minPercent, maxPercent);
  static int clampPercentInt(num value) => clampPercent(value).round();
  static double clampNonNegative(num value) => value.toDouble() < 0 ? 0 : value.toDouble();
  static double clampCurrency(num value) => clampNonNegative(value);
  static int clampWalkMinutes(num value) => value.round().clamp(0, 120);
  static double clampScoreRatio(num numerator, num denominator) {
    if (denominator <= 0) return 0;
    return clampPercent((numerator / denominator) * 100);
  }
}
