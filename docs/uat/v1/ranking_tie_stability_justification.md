# Ranking Tie Stability Justification

**Classification: A — Tie Stability Audit Required**

Frequent ties among consecutive ranks (exact score sets 95.5%, full-key 95.5%; top-5 exact 95.5%, top-5 full-key 95.5%) with no listing-id/timestamp final breaker.

Audited at: `2026-09-01T20:57:14.637570Z`

## Key metrics

| Metric | Value |
| --- | --- |
| Seekers | 66 |
| Non-empty result sets | 66 |
| Exact score tie pairs (consecutive) | 1622 |
| Full-key tie pairs (comparator == 0) | 1621 |
| Near ties ±1 | 49 |
| Near ties ±2 | 63 |
| % result sets with exact ties | 95.5% |
| % result sets with full-key ties | 95.5% |
| % result sets with near ±1 | 31.8% |
| % result sets with near ±2 | 60.6% |
| Top-5 exact tie pairs | 263 |
| % sets with top-5 exact ties | 95.5% |
| % sets with top-5 full-key ties | 95.5% |

## Definitions

- **Exact score tie:** Consecutive ranks in full eligible ranked list with equal ListingMatchResult.score.
- **Full-key tie:** Consecutive ranks where ListingMatchEngine.rank comparator returns 0 (preferenceScore if soft filters, qualityTier, match.score).
- **Near ±1:** Consecutive ranks with |scoreA-scoreB|==1 (excludes exact).
- **Near ±2:** Consecutive ranks with |scoreA-scoreB|==2 (excludes exact).
- **Top 20:** Most frequent canonical listing-id pairs (idA|idB, idA<idB) that appear as consecutive exact-score ties across seekers; also top recurring tied score values.

## Tie-breakers

Primary sort keys in `ListingMatchEngine.rank`:
- preferenceScore (desc) when WeightedFilterCriteria has soft filters
- qualityTier from match.percentage (>=50, 25-49, <25)
- match.score (desc)

- Explicit final tie-breaker (listing id / timestamp): **none**
- Listing-id secondary key: `false`
- Dart List.sort is stable; equal comparator results preserve relative order from the weighted pool (itself sorted only by preferenceScore with no id key).
- WeightedListingMatcher.fetchScoredListings sorts by preference score only; equal preference scores keep filter-pass order.
- When scores differ: secondary keys are exercised.
- When all keys equal: No product-level deterministic breaker; residual upstream order only (stable sort of input pool order).

## Top 20 exact-tie listing-id pairs

| Pair | Occurrences |
| --- | --- |
| `dub-rent-27|dub-rent-30` | 26 |
| `dub-share-11|dub-share-18` | 21 |
| `dub-share-18|dub-share-30` | 21 |
| `dub-share-28|dub-share-33` | 21 |
| `dub-rent-15|dub-rent-19` | 19 |
| `dub-rent-23|dub-rent-24` | 19 |
| `dub-rent-29|dub-rent-30` | 19 |
| `dub-share-02|dub-share-23` | 17 |
| `dub-share-20|dub-share-28` | 15 |
| `dub-rent-17|dub-rent-18` | 14 |
| `dub-share-01|dub-share-15` | 14 |
| `dub-rent-07|dub-rent-08` | 13 |
| `dub-rent-11|dub-rent-13` | 13 |
| `dub-share-04|dub-share-11` | 13 |
| `dub-rent-02|dub-rent-16` | 12 |
| `dub-rent-04|dub-rent-05` | 12 |
| `dub-rent-22|dub-rent-23` | 12 |
| `dub-share-04|dub-share-36` | 12 |
| `dub-rent-01|dub-rent-17` | 11 |
| `dub-rent-01|dub-rent-18` | 11 |

## Top 20 exact-tie score values

| Score | Occurrences |
| --- | --- |
| 60 | 463 |
| 70 | 256 |
| 50 | 176 |
| 85 | 166 |
| 75 | 98 |
| 80 | 97 |
| 55 | 75 |
| 72 | 57 |
| 78 | 43 |
| 65 | 24 |
| 40 | 23 |
| 54 | 22 |
| 45 | 20 |
| 58 | 15 |
| 69 | 15 |
| 48 | 10 |
| 67 | 10 |
| 71 | 10 |
| 51 | 9 |
| 30 | 4 |

## Corpus

- Listings: `SampleListingsDublin` (40 Share / 50 Rent / total 90)
- Seekers: 66 reconstructed (34 SL / 32 IP); fixture `test/fixtures/uat_frozen_seekers_reconstructed.json`
- Frozen UAT seeker JSON is not inventored under lib/. Preference maps reconstructed from the same prior UAT chat artifact used by blank_field / active_mode / zero_match harnesses (66 seekers incl. SL-MARKET-01 / IP-MARKET-01). Ranking fields only; uat_validation_points omitted.

## Production code

No production matching/ranking code was modified. Test-only harness: `test/ranking_tie_stability_justification_test.dart`.

