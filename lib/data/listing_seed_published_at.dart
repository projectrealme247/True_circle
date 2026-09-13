/// Deterministic [published_at] stamps for marketplace seed listings only.
///
/// Cycles six freshness buckets so UI can validate Listing Freshness Phase 1
/// without touching display/calculation helpers.
abstract final class ListingSeedPublishedAt {
  /// Age offsets (days) → card labels: today, 3/7/14/30 days ago, 60+.
  static const ageDayBuckets = <int>[0, 3, 7, 14, 30, 75];

  /// ISO-8601 UTC noon on the calendar day [ageDayBuckets] ago for [id].
  static String forId(String id, {DateTime? now}) {
    final days = ageDayBuckets[_bucketIndex(id)];
    final anchor = now ?? DateTime.now();
    final localDay = DateTime(anchor.year, anchor.month, anchor.day)
        .subtract(Duration(days: days));
    return DateTime.utc(localDay.year, localDay.month, localDay.day, 12)
        .toIso8601String();
  }

  static int _bucketIndex(String id) {
    final digits =
        int.tryParse(RegExp(r'(\d+)$').firstMatch(id)?.group(1) ?? '');
    if (digits != null) return digits % ageDayBuckets.length;
    return id.hashCode.abs() % ageDayBuckets.length;
  }
}
