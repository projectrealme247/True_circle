import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/utils/listing_data.dart';

/// Rent Data Integrity Audit — monthly EUR usability for matching.
///
/// Run: `flutter test test/rent_data_integrity_audit_test.dart`
///
/// Fields read (aligned with production):
/// - Primary: listing `price` string via [ListingData.price] / raw `item['price']`
/// - Matcher amount: [ListingData.listingPriceAmount] (strips non-digits)
/// - Display: [ListingData.priceDisplayLabel]
/// - Marketplace tower: [ListingData.listingType] (`Share` / `Rent`)
/// - No separate `rent_currency` / `rent_frequency` columns exist on seed listings;
///   frequency/currency are inferred from the `price` string.
void main() {
  test('rent data integrity audit dump', () {
    final items = SampleListingsDublin.items;
    final parsed = items.map(_parseListing).toList();

    // Peer stats from numeric monthly candidates (before outlier REVIEW).
    final slAmounts = parsed
        .where((r) =>
            r['marketplace'] == 'shared_living' &&
            r['_numeric_monthly'] != null)
        .map((r) => (r['_numeric_monthly'] as int).toDouble())
        .toList()
      ..sort();
    final ipAmounts = parsed
        .where((r) =>
            r['marketplace'] == 'independent_places' &&
            r['_numeric_monthly'] != null)
        .map((r) => (r['_numeric_monthly'] as int).toDouble())
        .toList()
      ..sort();

    final slFence = _outlierFence(slAmounts);
    final ipFence = _outlierFence(ipAmounts);

    final listings = <Map<String, dynamic>>[];
    for (final row in parsed) {
      final classified = _classify(
        row,
        fence: row['marketplace'] == 'shared_living' ? slFence : ipFence,
      );
      classified.remove('_numeric_monthly');
      classified.remove('_raw_price');
      classified.remove('_checks');
      listings.add(classified);
    }

    final summary = <String, int>{
      'VALID': 0,
      'REVIEW': 0,
      'INVALID': 0,
      'shared_living': 0,
      'independent_places': 0,
    };
    for (final r in listings) {
      summary[r['validation_status'] as String] =
          (summary[r['validation_status'] as String] ?? 0) + 1;
      summary[r['marketplace'] as String] =
          (summary[r['marketplace'] as String] ?? 0) + 1;
    }

    final marketplaceStats = {
      'shared_living': _marketplaceStats(
        listings.where((l) => l['marketplace'] == 'shared_living'),
      ),
      'independent_places': _marketplaceStats(
        listings.where((l) => l['marketplace'] == 'independent_places'),
      ),
    };

    final successCriteria = {
      'zero_invalid': summary['INVALID'] == 0,
      'all_rents_monthly_eur': listings.every((l) {
        if (l['validation_status'] == 'INVALID') return false;
        return l['rent_frequency'] == 'monthly' &&
            (l['rent_currency'] == 'EUR' || l['rent_currency'] == 'EUR_IMPLIED');
      }),
      'numeric_usable_by_matcher': listings
          .where((l) => l['validation_status'] != 'INVALID')
          .every((l) => l['matcher_amount'] != null && (l['matcher_amount'] as int) > 0),
      'no_weekly_or_annual_detected': listings.every(
        (l) =>
            l['rent_frequency'] != 'weekly' && l['rent_frequency'] != 'annual',
      ),
    };
    final successMet = successCriteria.values.every((v) => v == true);

    final payload = <String, dynamic>{
      'audit_version': '1.0',
      'audited_at': DateTime.now().toUtc().toIso8601String(),
      'source': {
        'name': 'SampleListingsDublin (local Dublin marketplace seed)',
        'paths': [
          'lib/data/sample_listings_dublin.dart',
          'lib/data/sample_listings_dublin_v2.dart',
          'lib/data/sample_listings_dublin_legacy.dart',
          'lib/data/sample_listings_dublin_expansion.dart',
          'lib/data/dublin_listing_builder.dart',
        ],
        'notes':
            'Same corpus as prior UAT audits. App feed bootstraps via '
            'ListingsStorageService. Seed stores `price` as e.g. `880/month` '
            '(no €); listing creation persists `€{digits}/month`.',
        'shared_living_count': summary['shared_living'],
        'independent_places_count': summary['independent_places'],
        'total': listings.length,
      },
      'fields_read': {
        'primary_rent_field': 'price',
        'parser': 'ListingData.listingPriceAmount — strips non-digits from price',
        'display': 'ListingData.price / priceDisplayLabel (appends /month if missing)',
        'marketplace': 'ListingData.listingType (Share→shared_living, Rent→independent_places)',
        'absent_columns': [
          'rent_currency',
          'rent_frequency',
          'monthly_rent',
          'currency',
        ],
        'code_citations': [
          'lib/utils/listing_data.dart (price, priceDisplayLabel, listingPriceAmount)',
          'lib/utils/weighted_listing_matcher.dart (uses listingPriceAmount)',
          'lib/utils/listing_search_intent.dart (budget filter via listingPriceAmount)',
          'lib/widgets/listing_creation/listing_creation_form.dart '
              '(persists €{digits}/month)',
        ],
      },
      'outlier_fences': {
        'shared_living': slFence.toJson(),
        'independent_places': ipFence.toJson(),
        'method':
            'IQR fence (Q1−1.5·IQR, Q3+1.5·IQR) plus marketplace Dublin sanity '
            'bounds; REVIEW if numeric monthly outside fence or absurd vs norms',
      },
      'summary': {
        'VALID': summary['VALID'],
        'REVIEW': summary['REVIEW'],
        'INVALID': summary['INVALID'],
        'total': listings.length,
        'success_criteria_met': successMet,
      },
      'success_criteria': successCriteria,
      'marketplace_stats': marketplaceStats,
      'listings': listings,
      'blockers': listings
          .where((l) => l['validation_status'] == 'INVALID')
          .map((l) => {
                'listing_id': l['listing_id'],
                'marketplace': l['marketplace'],
                'review_reason': l['review_reason'],
              })
          .toList(),
      'review_items': listings
          .where((l) => l['validation_status'] == 'REVIEW')
          .map((l) => {
                'listing_id': l['listing_id'],
                'marketplace': l['marketplace'],
                'rent_value': l['rent_value'],
                'review_reason': l['review_reason'],
              })
          .toList(),
    };

    final outDir = Directory('docs/uat/v1');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    File('docs/uat/v1/rent_data_integrity_audit.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    File('docs/uat/v1/rent_data_integrity_audit.md')
        .writeAsStringSync(_buildMarkdown(payload));

    // ignore: avoid_print
    print(
      'RENT_AUDIT VALID=${summary['VALID']} REVIEW=${summary['REVIEW']} '
      'INVALID=${summary['INVALID']} SL=${summary['shared_living']} '
      'IP=${summary['independent_places']} success=$successMet',
    );

    expect(listings.length, 90);
    expect(summary['shared_living'], 40);
    expect(summary['independent_places'], 50);
  });
}

Map<String, dynamic> _parseListing(Map<String, dynamic> item) {
  final id = ListingData.id(item);
  final tower = ListingData.listingType(item);
  final marketplace =
      tower == 'Share' ? 'shared_living' : 'independent_places';

  final rawPrice = item['price'];
  final rawPriceStr = rawPrice == null ? null : rawPrice.toString();
  final displayPrice = ListingData.price(item);
  final matcherAmount = ListingData.listingPriceAmount(item);

  final analysis = _analyzePrice(rawPriceStr);
  final checks = <String, bool>{
    'missing_rent': rawPrice == null ||
        (rawPriceStr != null && rawPriceStr.trim().isEmpty),
    'null_rent': rawPrice == null,
    'zero_rent': analysis.numericValue == 0 || matcherAmount == 0,
    'negative_rent': analysis.hasNegativeSign,
    'non_numeric': !analysis.hasDigits ||
        analysis.isPoaOrContact ||
        (rawPriceStr != null &&
            rawPriceStr.trim().isNotEmpty &&
            matcherAmount == null),
    'weekly_rent': analysis.frequency == 'weekly',
    'annual_rent': analysis.frequency == 'annual',
    'non_eur_currency':
        analysis.currency != null && analysis.currency != 'EUR',
    'currency_inconsistency': analysis.currencyInconsistent,
    'text_formatted_unusable': analysis.isPoaOrContact,
    'extreme_outlier_candidate': false, // filled in classify
  };

  return {
    'listing_id': id,
    'marketplace': marketplace,
    'rent_value': analysis.numericValue ?? matcherAmount,
    'rent_currency': analysis.currencyLabel,
    'rent_frequency': analysis.frequency,
    'price_raw': rawPriceStr ?? '',
    'price_display': displayPrice,
    'matcher_amount': matcherAmount,
    'checks_failed': <String>[],
    '_numeric_monthly': (analysis.frequency == 'monthly' ||
            analysis.frequency == 'monthly_implied') &&
            analysis.numericValue != null &&
            analysis.numericValue! > 0 &&
            !analysis.isPoaOrContact &&
            (analysis.currency == null || analysis.currency == 'EUR')
        ? analysis.numericValue
        : null,
    '_raw_price': rawPriceStr,
    '_checks': checks,
    '_analysis': analysis.toJson(),
  };
}

Map<String, dynamic> _classify(
  Map<String, dynamic> row, {
  required _OutlierFence fence,
}) {
  final checks = Map<String, bool>.from(row['_checks'] as Map);
  final analysis =
      _PriceAnalysis.fromJson(row['_analysis'] as Map<String, dynamic>);
  final reasons = <String>[];
  final failed = <String>[];

  void fail(String check, String reason) {
    checks[check] = true;
    failed.add(check);
    reasons.add(reason);
  }

  if (checks['null_rent'] == true) {
    fail('null_rent', 'Null rent value (price field is null).');
  } else if (checks['missing_rent'] == true) {
    fail('missing_rent', 'Missing/empty rent value.');
  }

  if (analysis.isPoaOrContact) {
    fail(
      'text_formatted_unusable',
      'Text-formatted / non-numeric rent (POA / contact-for-price style).',
    );
  }

  if (analysis.hasNegativeSign ||
      (analysis.numericValue != null && analysis.numericValue! < 0)) {
    fail('negative_rent', 'Negative rent value.');
  }

  if (analysis.numericValue == 0 || row['matcher_amount'] == 0) {
    fail(
      'zero_rent',
      'Zero rent — INVALID for matching safety (even if intentional free).',
    );
  }

  if (!analysis.hasDigits &&
      row['_raw_price'] != null &&
      (row['_raw_price'] as String).trim().isNotEmpty &&
      !analysis.isPoaOrContact) {
    fail('non_numeric', 'Non-numeric rent — no digits for matcher.');
  }

  if (row['matcher_amount'] == null &&
      row['_raw_price'] != null &&
      (row['_raw_price'] as String).trim().isNotEmpty &&
      !failed.contains('non_numeric') &&
      !failed.contains('text_formatted_unusable')) {
    fail(
      'non_numeric',
      'ListingData.listingPriceAmount returned null — unusable by matcher.',
    );
  }

  if (analysis.frequency == 'weekly') {
    fail(
      'weekly_rent',
      'Weekly rent detected — would break monthly matching '
      '(matcher strips digits only, ignores /week).',
    );
  }
  if (analysis.frequency == 'annual') {
    fail(
      'annual_rent',
      'Annual rent detected — would break monthly matching '
      '(matcher strips digits only, ignores /year).',
    );
  }

  if (analysis.currency != null && analysis.currency != 'EUR') {
    fail(
      'non_eur_currency',
      'Non-EUR currency (${analysis.currency}) — matching assumes EUR.',
    );
  }
  if (analysis.currencyInconsistent) {
    fail(
      'currency_inconsistency',
      'Currency markers inconsistent within price string.',
    );
  }

  String status;
  String reviewReason;

  if (failed.isNotEmpty) {
    status = 'INVALID';
    reviewReason = reasons.join(' ');
  } else {
    final amount = (row['_numeric_monthly'] as int?) ??
        (row['matcher_amount'] as int?);
    final outlierReasons = <String>[];

    if (amount != null) {
      if (amount < fence.sanityLow || amount > fence.sanityHigh) {
        outlierReasons.add(
          'Outside Dublin ${row['marketplace']} sanity band '
          '(${fence.sanityLow}–${fence.sanityHigh} EUR/mo): $amount.',
        );
      }
      if (fence.hasIqr &&
          (amount < fence.lowerFence || amount > fence.upperFence)) {
        outlierReasons.add(
          'IQR outlier vs peers (fence ${fence.lowerFence.round()}–'
          '${fence.upperFence.round()}; Q1=${fence.q1.round()} '
          'Q3=${fence.q3.round()}).',
        );
      }
      if (fence.hasSigma &&
          (amount < fence.mean - 3 * fence.stdev ||
              amount > fence.mean + 3 * fence.stdev)) {
        outlierReasons.add(
          '>3σ from peer mean (mean=${fence.mean.round()}, '
          'σ=${fence.stdev.round()}).',
        );
      }
    }

    if (analysis.frequency == 'unknown' && amount != null && amount > 0) {
      outlierReasons.add(
        'Frequency not explicit in price string; ListingData.price implies /month.',
      );
    }

    if (analysis.hasThousandsSeparator) {
      outlierReasons.add(
        'Text-formatted with thousands separators — still parses numerically.',
      );
    }

    if (outlierReasons.isNotEmpty) {
      checks['extreme_outlier_candidate'] = true;
      failed.add('extreme_outlier_candidate');
      status = 'REVIEW';
      reviewReason = outlierReasons.join(' ');
    } else {
      status = 'VALID';
      reviewReason = 'Positive numeric monthly EUR; usable by '
          'ListingData.listingPriceAmount / matcher.';
    }
  }

  // Normalize frequency label for output contract.
  final freqOut = switch (analysis.frequency) {
    'monthly' || 'monthly_implied' => 'monthly',
    final f => f,
  };
  final currencyOut = switch (analysis.currencyLabel) {
    'EUR_IMPLIED' => 'EUR',
    final c => c,
  };

  return {
    'listing_id': row['listing_id'],
    'marketplace': row['marketplace'],
    'rent_value': row['rent_value'],
    'rent_currency': currencyOut,
    'rent_frequency': freqOut,
    'validation_status': status,
    'review_reason': reviewReason,
    'price_raw': row['price_raw'],
    'price_display': row['price_display'],
    'matcher_amount': row['matcher_amount'],
    'checks_failed': failed,
    'currency_inferred': analysis.currencyLabel == 'EUR_IMPLIED',
    '_numeric_monthly': row['_numeric_monthly'],
    '_raw_price': row['_raw_price'],
    '_checks': checks,
  };
}

class _PriceAnalysis {
  _PriceAnalysis({
    required this.hasDigits,
    required this.hasNegativeSign,
    required this.isPoaOrContact,
    required this.hasThousandsSeparator,
    required this.numericValue,
    required this.frequency,
    required this.currency,
    required this.currencyLabel,
    required this.currencyInconsistent,
  });

  final bool hasDigits;
  final bool hasNegativeSign;
  final bool isPoaOrContact;
  final bool hasThousandsSeparator;
  final int? numericValue;
  final String frequency; // monthly | monthly_implied | weekly | annual | unknown | n/a
  final String? currency; // EUR | USD | GBP | INR | null
  final String currencyLabel; // EUR | EUR_IMPLIED | USD | ... | UNKNOWN
  final bool currencyInconsistent;

  Map<String, dynamic> toJson() => {
        'hasDigits': hasDigits,
        'hasNegativeSign': hasNegativeSign,
        'isPoaOrContact': isPoaOrContact,
        'hasThousandsSeparator': hasThousandsSeparator,
        'numericValue': numericValue,
        'frequency': frequency,
        'currency': currency,
        'currencyLabel': currencyLabel,
        'currencyInconsistent': currencyInconsistent,
      };

  factory _PriceAnalysis.fromJson(Map<String, dynamic> j) => _PriceAnalysis(
        hasDigits: j['hasDigits'] as bool,
        hasNegativeSign: j['hasNegativeSign'] as bool,
        isPoaOrContact: j['isPoaOrContact'] as bool,
        hasThousandsSeparator: j['hasThousandsSeparator'] as bool,
        numericValue: j['numericValue'] as int?,
        frequency: j['frequency'] as String,
        currency: j['currency'] as String?,
        currencyLabel: j['currencyLabel'] as String,
        currencyInconsistent: j['currencyInconsistent'] as bool,
      );
}

_PriceAnalysis _analyzePrice(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return _PriceAnalysis(
      hasDigits: false,
      hasNegativeSign: false,
      isPoaOrContact: false,
      hasThousandsSeparator: false,
      numericValue: null,
      frequency: 'n/a',
      currency: null,
      currencyLabel: 'UNKNOWN',
      currencyInconsistent: false,
    );
  }

  final s = raw.trim();
  final lower = s.toLowerCase();
  final isPoa = RegExp(
        r'\b(poa|p\.?o\.?a\.?|price\s*on\s*application)\b',
        caseSensitive: false,
      ).hasMatch(s) ||
      RegExp(
        r'contact\s*(for|us\s*for)?\s*(price|rent|details)',
        caseSensitive: false,
      ).hasMatch(s) ||
      lower == 'n/a' ||
      lower == 'na' ||
      lower == 'tbd' ||
      lower.contains('ask for price');

  final hasNegative = RegExp(r'-\s*\d').hasMatch(s) || s.trim().startsWith('-');
  final hasDigits = RegExp(r'\d').hasMatch(s);
  final hasThousands = RegExp(r'\d,\d{3}').hasMatch(s);

  final digits = s.replaceAll(RegExp(r'[^\d]'), '');
  final numeric = digits.isEmpty ? null : int.tryParse(digits);

  String frequency;
  if (RegExp(r'/\s*week|per\s*week|\bweekly\b|p/?w\b', caseSensitive: false)
      .hasMatch(s)) {
    frequency = 'weekly';
  } else if (RegExp(
    r'/\s*year|per\s*year|\bannual(ly)?\b|/\s*annum|p/?a\b',
    caseSensitive: false,
  ).hasMatch(s)) {
    frequency = 'annual';
  } else if (RegExp(
    r'/\s*month|per\s*month|\bmonthly\b|p/?m\b',
    caseSensitive: false,
  ).hasMatch(s)) {
    frequency = 'monthly';
  } else if (hasDigits) {
    // ListingData.price appends /month when slash missing.
    frequency = 'monthly_implied';
  } else {
    frequency = 'unknown';
  }

  final currencies = <String>{};
  if (s.contains('€') || RegExp(r'\bEUR\b', caseSensitive: false).hasMatch(s)) {
    currencies.add('EUR');
  }
  if (s.contains('\$') ||
      RegExp(r'\bUSD\b', caseSensitive: false).hasMatch(s)) {
    currencies.add('USD');
  }
  if (s.contains('£') ||
      RegExp(r'\bGBP\b', caseSensitive: false).hasMatch(s)) {
    currencies.add('GBP');
  }
  if (s.contains('₹') ||
      RegExp(r'\bINR\b', caseSensitive: false).hasMatch(s)) {
    currencies.add('INR');
  }

  String? currency;
  String currencyLabel;
  var inconsistent = false;
  if (currencies.length > 1) {
    inconsistent = true;
    currency = currencies.contains('EUR') ? 'MIXED' : currencies.first;
    currencyLabel = 'MIXED';
  } else if (currencies.length == 1) {
    currency = currencies.first;
    currencyLabel = currency!;
  } else if (hasDigits) {
    currency = null;
    currencyLabel = 'EUR_IMPLIED'; // Dublin market default
  } else {
    currency = null;
    currencyLabel = 'UNKNOWN';
  }

  return _PriceAnalysis(
    hasDigits: hasDigits,
    hasNegativeSign: hasNegative,
    isPoaOrContact: isPoa,
    hasThousandsSeparator: hasThousands,
    numericValue: numeric,
    frequency: frequency,
    currency: currency,
    currencyLabel: currencyLabel,
    currencyInconsistent: inconsistent,
  );
}

class _OutlierFence {
  _OutlierFence({
    required this.q1,
    required this.q3,
    required this.iqr,
    required this.lowerFence,
    required this.upperFence,
    required this.mean,
    required this.stdev,
    required this.sanityLow,
    required this.sanityHigh,
    required this.n,
  });

  final double q1;
  final double q3;
  final double iqr;
  final double lowerFence;
  final double upperFence;
  final double mean;
  final double stdev;
  final int sanityLow;
  final int sanityHigh;
  final int n;

  bool get hasIqr => n >= 4 && iqr > 0;
  bool get hasSigma => n >= 4 && stdev > 0;

  Map<String, dynamic> toJson() => {
        'n': n,
        'q1': q1,
        'q3': q3,
        'iqr': iqr,
        'lower_fence': lowerFence,
        'upper_fence': upperFence,
        'mean': mean,
        'stdev': stdev,
        'sanity_low': sanityLow,
        'sanity_high': sanityHigh,
      };
}

_OutlierFence _outlierFence(List<double> sorted) {
  // Dublin norms (Daft-informed). Caller passes marketplace-specific lists;
  // median picks SL vs IP sanity band.
  final median = sorted.isEmpty ? 0.0 : _percentile(sorted, 0.5);
  final sanityLow = median < 1600 ? 200 : 600;
  final sanityHigh = median < 1600 ? 2200 : 6000;

  if (sorted.length < 4) {
    return _OutlierFence(
      q1: 0,
      q3: 0,
      iqr: 0,
      lowerFence: sanityLow.toDouble(),
      upperFence: sanityHigh.toDouble(),
      mean: sorted.isEmpty
          ? 0
          : sorted.reduce((a, b) => a + b) / sorted.length,
      stdev: 0,
      sanityLow: sanityLow,
      sanityHigh: sanityHigh,
      n: sorted.length,
    );
  }

  final q1 = _percentile(sorted, 0.25);
  final q3 = _percentile(sorted, 0.75);
  final iqr = q3 - q1;
  final mean = sorted.reduce((a, b) => a + b) / sorted.length;
  var variance = 0.0;
  for (final v in sorted) {
    variance += (v - mean) * (v - mean);
  }
  final stdev = math.sqrt(variance / sorted.length);

  return _OutlierFence(
    q1: q1,
    q3: q3,
    iqr: iqr,
    lowerFence: q1 - 1.5 * iqr,
    upperFence: q3 + 1.5 * iqr,
    mean: mean,
    stdev: stdev,
    sanityLow: sanityLow,
    sanityHigh: sanityHigh,
    n: sorted.length,
  );
}

double _percentile(List<double> sorted, double p) {
  if (sorted.isEmpty) return 0;
  if (sorted.length == 1) return sorted.first;
  final idx = (sorted.length - 1) * p;
  final lo = idx.floor();
  final hi = idx.ceil();
  if (lo == hi) return sorted[lo];
  final w = idx - lo;
  return sorted[lo] * (1 - w) + sorted[hi] * w;
}

Map<String, dynamic> _marketplaceStats(Iterable<Map<String, dynamic>> rows) {
  final usable = rows
      .where((r) =>
          r['validation_status'] == 'VALID' ||
          r['validation_status'] == 'REVIEW')
      .map((r) => r['matcher_amount'] as int?)
      .whereType<int>()
      .where((v) => v > 0)
      .toList()
    ..sort();

  final invalidExcluded = rows
      .where((r) => r['validation_status'] == 'INVALID')
      .length;

  if (usable.isEmpty) {
    return {
      'count_usable': 0,
      'invalid_excluded_from_stats': invalidExcluded,
      'min_rent': null,
      'max_rent': null,
      'avg_rent': null,
      'note': 'No VALID/REVIEW numeric monthly EUR values',
    };
  }

  final sum = usable.fold<int>(0, (a, b) => a + b);
  return {
    'count_usable': usable.length,
    'invalid_excluded_from_stats': invalidExcluded,
    'min_rent': usable.first,
    'max_rent': usable.last,
    'avg_rent': double.parse((sum / usable.length).toStringAsFixed(2)),
    'note':
        'Computed from VALID+REVIEW numeric monthly EUR (matcher_amount); '
        'INVALID excluded',
  };
}

String _buildMarkdown(Map<String, dynamic> payload) {
  final source = payload['source'] as Map<String, dynamic>;
  final summary = payload['summary'] as Map<String, dynamic>;
  final fields = payload['fields_read'] as Map<String, dynamic>;
  final stats = payload['marketplace_stats'] as Map<String, dynamic>;
  final criteria = payload['success_criteria'] as Map<String, dynamic>;
  final listings =
      (payload['listings'] as List).cast<Map<String, dynamic>>();
  final invalid =
      listings.where((l) => l['validation_status'] == 'INVALID').toList();
  final review =
      listings.where((l) => l['validation_status'] == 'REVIEW').toList();
  final buf = StringBuffer();

  buf.writeln('# Rent Data Integrity Audit — TrueCircle V1');
  buf.writeln();
  buf.writeln('**Audited at:** ${payload['audited_at']}');
  buf.writeln();
  buf.writeln('## Verdict');
  buf.writeln();
  final ok = summary['success_criteria_met'] == true;
  buf.writeln(
    ok
        ? '**Success criteria met:** YES — 0 INVALID; all rents monthly EUR and matcher-usable.'
        : '**Success criteria met:** NO — see blockers / failed criteria.',
  );
  buf.writeln();
  buf.writeln('| Status | Count |');
  buf.writeln('|--------|------:|');
  buf.writeln('| VALID | ${summary['VALID']} |');
  buf.writeln('| REVIEW | ${summary['REVIEW']} |');
  buf.writeln('| INVALID | ${summary['INVALID']} |');
  buf.writeln('| **Total** | **${summary['total']}** |');
  buf.writeln();

  buf.writeln('## Success criteria');
  buf.writeln();
  buf.writeln('| Criterion | Met? |');
  buf.writeln('|-----------|------|');
  for (final e in criteria.entries) {
    buf.writeln('| `${e.key}` | ${e.value} |');
  }
  buf.writeln();

  buf.writeln('## Source');
  buf.writeln();
  buf.writeln('- **Dataset:** ${source['name']}');
  buf.writeln(
    '- **Counts:** ${source['shared_living_count']} Shared Living (`Share`) · '
    '${source['independent_places_count']} Independent Places (`Rent`)',
  );
  buf.writeln('- **Paths:**');
  for (final p in source['paths'] as List) {
    buf.writeln('  - `$p`');
  }
  buf.writeln('- **Notes:** ${source['notes']}');
  buf.writeln();

  buf.writeln('## How rent is parsed in code');
  buf.writeln();
  buf.writeln(
    'Listings store rent in a single string field **`price`**. There are no '
    'separate `rent_currency` / `rent_frequency` columns on seed rows.',
  );
  buf.writeln();
  buf.writeln('| Concern | Implementation |');
  buf.writeln('|---------|----------------|');
  buf.writeln(
    '| Primary field | `${fields['primary_rent_field']}` |',
  );
  buf.writeln('| Matcher amount | ${fields['parser']} |');
  buf.writeln('| Display | ${fields['display']} |');
  buf.writeln('| Marketplace | ${fields['marketplace']} |');
  buf.writeln(
    '| Absent columns | ${(fields['absent_columns'] as List).join(', ')} |',
  );
  buf.writeln();
  buf.writeln('### Code citations');
  buf.writeln();
  for (final c in fields['code_citations'] as List) {
    buf.writeln('- `$c`');
  }
  buf.writeln();
  buf.writeln(
    '**Important:** `listingPriceAmount` strips all non-digits and does **not** '
    'interpret `/week` or `/year`. A weekly string like `€700/week` would match '
    'as `700` monthly — hence weekly/annual formats are **INVALID** for integrity.',
  );
  buf.writeln();

  buf.writeln('## Marketplace rent stats');
  buf.writeln();
  buf.writeln(
    '_From VALID+REVIEW numeric monthly EUR (`matcher_amount`); INVALID excluded._',
  );
  buf.writeln();
  buf.writeln('| Marketplace | Min | Max | Avg | Usable n | Invalid excluded |');
  buf.writeln('|-------------|----:|----:|----:|---------:|-----------------:|');
  for (final key in ['shared_living', 'independent_places']) {
    final s = stats[key] as Map<String, dynamic>;
    buf.writeln(
      '| $key | ${s['min_rent'] ?? '—'} | ${s['max_rent'] ?? '—'} | '
      '${s['avg_rent'] ?? '—'} | ${s['count_usable']} | '
      '${s['invalid_excluded_from_stats']} |',
    );
  }
  buf.writeln();

  buf.writeln('## Classification rules');
  buf.writeln();
  buf.writeln(
    '- **INVALID:** missing/null/empty/non-numeric/POA/contact-for-price; '
    'negative; zero; clear weekly/annual; non-EUR; unusable by '
    '`ListingData.listingPriceAmount`.',
  );
  buf.writeln(
    '- **REVIEW:** extreme outliers vs marketplace peers (IQR / >3σ / Dublin '
    'sanity); ambiguous format that still parses; thousands separators.',
  );
  buf.writeln(
    '- **VALID:** positive numeric monthly EUR (explicit or Dublin-implied), '
    'usable by matching engine.',
  );
  buf.writeln(
    '- Seed prices omit `€` (e.g. `880/month`); creation form writes '
    '`€{digits}/month`. Missing symbol alone is **not** REVIEW when `/month` '
    'and digits are present (EUR implied for Dublin market).',
  );
  buf.writeln();

  buf.writeln('## INVALID blockers');
  buf.writeln();
  if (invalid.isEmpty) {
    buf.writeln('_None._');
  } else {
    buf.writeln('| listing_id | marketplace | rent_value | reason |');
    buf.writeln('|------------|-------------|------------|--------|');
    for (final l in invalid) {
      buf.writeln(
        '| `${l['listing_id']}` | ${l['marketplace']} | '
        '${l['rent_value'] ?? '—'} | ${_mdCell(l['review_reason'])} |',
      );
    }
  }
  buf.writeln();

  buf.writeln('## REVIEW items');
  buf.writeln();
  if (review.isEmpty) {
    buf.writeln('_None._');
  } else {
    buf.writeln('| listing_id | marketplace | rent_value | review_reason |');
    buf.writeln('|------------|-------------|------------|---------------|');
    for (final l in review) {
      buf.writeln(
        '| `${l['listing_id']}` | ${l['marketplace']} | '
        '${l['rent_value']} | ${_mdCell(l['review_reason'])} |',
      );
    }
  }
  buf.writeln();

  buf.writeln('## Full listing table');
  buf.writeln();
  buf.writeln(
    '| listing_id | marketplace | rent_value | rent_currency | '
    'rent_frequency | validation_status | review_reason |',
  );
  buf.writeln(
    '|------------|-------------|------------|---------------|'
    '----------------|-------------------|---------------|',
  );
  for (final l in listings) {
    buf.writeln(
      '| `${l['listing_id']}` | ${l['marketplace']} | '
      '${l['rent_value'] ?? '—'} | ${l['rent_currency']} | '
      '${l['rent_frequency']} | **${l['validation_status']}** | '
      '${_mdCell(l['review_reason'])} |',
    );
  }
  buf.writeln();
  return buf.toString();
}

String _mdCell(dynamic v) {
  if (v == null) return '—';
  return v.toString().replaceAll('|', '\\|').replaceAll('\n', ' ');
}
