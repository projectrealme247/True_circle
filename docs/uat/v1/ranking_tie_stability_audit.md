# Ranking Tie Stability Audit

**Verdict: PASS WITH WARNINGS**

Severity: Medium

All 10 identical production-path runs were stable (top-1 and top-5 unchanged), but shuffled input pool changed top-5/top-1 order. Production SampleListingsDublin rebuild is currently fixed-order, so this is latent risk if a future feed/DB path supplies unstable input order (no listing-id final breaker).

Audited at: `2026-09-01T20:57:16.963922Z`

## Summary

| Metric | Value |
| --- | --- |
| Seekers audited | 10 |
| Runs per seeker | 10 |
| Aggregate stability % | 100.0 |
| Fully stable seekers | 10 |
| Seekers with order changes | 0 |
| Any top-1 changed | false |
| Any top-5 changed | false |
| Any tied pair swapped in top-5 | false |
| Shuffled input reordered | true |
| Dart List.sort stable | true |

## Part 1 — Test set selection

5 Shared Living + 5 Independent Places from frozen UAT seekers, chosen from ranking_tie_stability_justification per_seeker metrics to cover tie-heavy (high exact consecutive ties / top-5 ties), high-match (higher score_range.max), and medium-match bands.

| Seeker | Marketplace | Role | Exact ties | Top-5 ties | Score |
| --- | --- | --- | --- | --- | --- |
| `SL-EDGE-05` | shared_living | tie-heavy + high-match (28 exact ties, max score 76) | 33 | 4 | 40-81 |
| `SL-PRO-03` | shared_living | tie-heavy (25 exact ties, max score 76) | 31 | 4 | 40-81 |
| `SL-STU-03` | shared_living | medium ties (15), medium-high match band | 21 | 4 | 49-78 |
| `SL-STU-01` | shared_living | lower ties (3), medium-match band 41-70 | 6 | 4 | 46-78 |
| `SL-EDGE-11` | shared_living | moderate ties (9), higher floor medium-high match | 11 | 3 | 51-78 |
| `IP-EDGE-03` | independent_places | tie-heavy (42 exact ties, top-5 fully tied) | 45 | 5 | 30-70 |
| `IP-FAM-04` | independent_places | tie-heavy (41 exact ties, top-5 fully tied) | 44 | 5 | 30-70 |
| `IP-SIN-03` | independent_places | high-match (max 81) + heavy ties (37) | 44 | 5 | 50-85 |
| `IP-EDGE-01` | independent_places | high-match (max 90) + moderate ties (13) | 21 | 3 | 45-100 |
| `IP-CPL-01` | independent_places | medium-match (max 57) + medium-high ties (19) | 23 | 5 | 30-60 |

## Part 2 — Repeat execution

Each seeker: **10** identical runs via `MarketplaceListingPipeline.runWithFilters` → `WeightedListingMatcher.fetchScoredListings` → `ListingMatchEngine.rank`, rebuilding `SampleListingsDublin.items` each call (production-like seed path). Optional shuffled-input probe documents input-order dependency.

## Part 3 — Per seeker metrics

| Seeker | Runs | Identical | Different | Stability % | Tied pairs | Ties reordered |
| --- | --- | --- | --- | --- | --- | --- |
| `SL-EDGE-05` | 10 | 10 | 0 | 100.0 | 30 | 0 |
| `SL-PRO-03` | 10 | 10 | 0 | 100.0 | 31 | 0 |
| `SL-STU-03` | 10 | 10 | 0 | 100.0 | 26 | 0 |
| `SL-STU-01` | 10 | 10 | 0 | 100.0 | 6 | 0 |
| `SL-EDGE-11` | 10 | 10 | 0 | 100.0 | 11 | 0 |
| `IP-EDGE-03` | 10 | 10 | 0 | 100.0 | 45 | 0 |
| `IP-FAM-04` | 10 | 10 | 0 | 100.0 | 44 | 0 |
| `IP-SIN-03` | 10 | 10 | 0 | 100.0 | 43 | 0 |
| `IP-EDGE-01` | 10 | 10 | 0 | 100.0 | 21 | 0 |
| `IP-CPL-01` | 10 | 10 | 0 | 100.0 | 23 | 0 |

## Part 4 — Top-5 analysis

| Check | Result |
| --- | --- |
| Top result changed (identical runs) | false |
| Top-5 changed (identical runs) | false |
| Tied pair swapped in top-5 | false |
| Shuffled input changed top-1 | true |
| Shuffled input changed top-5 | true |

### Per-seeker top-5 / shuffle

#### `SL-EDGE-05`

- Baseline top-5: `dub-share-29, dub-share-32, dub-share-06, dub-share-07, dub-share-34` (scores 81, 80, 80, 80, 80)
- Tied listings switched: false
- Top result changed: false
- Top-5 order changed: false
- Tied pair swapped: false
- Shuffled probe order changed: true (top1=false, top5=true, ties_reordered=17)

#### `SL-PRO-03`

- Baseline top-5: `dub-share-19, dub-share-29, dub-share-31, dub-share-02, dub-share-07` (scores 81, 81, 80, 80, 80)
- Tied listings switched: false
- Top result changed: false
- Top-5 order changed: false
- Tied pair swapped: false
- Shuffled probe order changed: true (top1=false, top5=true, ties_reordered=15)

#### `SL-STU-03`

- Baseline top-5: `dub-share-33, dub-share-35, dub-share-28, dub-share-09, dub-share-22` (scores 78, 78, 78, 78, 78)
- Tied listings switched: false
- Top result changed: false
- Top-5 order changed: false
- Tied pair swapped: false
- Shuffled probe order changed: true (top1=true, top5=true, ties_reordered=13)

#### `SL-STU-01`

- Baseline top-5: `dub-share-20, dub-share-28, dub-share-33, dub-share-11, dub-share-18` (scores 78, 78, 78, 72, 72)
- Tied listings switched: false
- Top result changed: false
- Top-5 order changed: false
- Tied pair swapped: false
- Shuffled probe order changed: true (top1=false, top5=true, ties_reordered=2)

#### `SL-EDGE-11`

- Baseline top-5: `dub-share-20, dub-share-28, dub-share-33, dub-share-22, dub-share-04` (scores 78, 78, 78, 74, 72)
- Tied listings switched: false
- Top result changed: false
- Top-5 order changed: false
- Tied pair swapped: false
- Shuffled probe order changed: true (top1=false, top5=true, ties_reordered=4)

#### `IP-EDGE-03`

- Baseline top-5: `dub-rent-44, dub-rent-03, dub-rent-48, dub-rent-15, dub-rent-19` (scores 70, 70, 70, 70, 70)
- Tied listings switched: false
- Top result changed: false
- Top-5 order changed: false
- Tied pair swapped: false
- Shuffled probe order changed: true (top1=true, top5=true, ties_reordered=22)

#### `IP-FAM-04`

- Baseline top-5: `dub-rent-44, dub-rent-03, dub-rent-48, dub-rent-15, dub-rent-19` (scores 70, 70, 70, 70, 70)
- Tied listings switched: false
- Top result changed: false
- Top-5 order changed: false
- Tied pair swapped: false
- Shuffled probe order changed: true (top1=true, top5=true, ties_reordered=21)

#### `IP-SIN-03`

- Baseline top-5: `dub-rent-17, dub-rent-39, dub-rent-04, dub-rent-07, dub-rent-08` (scores 85, 85, 85, 85, 85)
- Tied listings switched: false
- Top result changed: false
- Top-5 order changed: false
- Tied pair swapped: false
- Shuffled probe order changed: true (top1=true, top5=true, ties_reordered=21)

#### `IP-EDGE-01`

- Baseline top-5: `dub-rent-32, dub-rent-37, dub-rent-08, dub-rent-13, dub-rent-17` (scores 100, 100, 90, 85, 85)
- Tied listings switched: false
- Top result changed: false
- Top-5 order changed: false
- Tied pair swapped: false
- Shuffled probe order changed: true (top1=true, top5=true, ties_reordered=8)

#### `IP-CPL-01`

- Baseline top-5: `dub-rent-11, dub-rent-13, dub-rent-17, dub-rent-18, dub-rent-22` (scores 60, 60, 60, 60, 60)
- Tied listings switched: false
- Top result changed: false
- Top-5 order changed: false
- Tied pair swapped: false
- Shuffled probe order changed: true (top1=true, top5=true, ties_reordered=11)

## Part 5 — Root cause

Order among full-key ties is determined by upstream listing pool order (stable sort). Identical SampleListingsDublin rebuilds yield identical order; shuffled input can reorder ties.

| File | Function | Note |
| --- | --- | --- |
| `lib/utils/listing_match_engine.dart` | `ListingMatchEngine.rank` | scored.sort comparator: preferenceScore → qualityTier → match.score; no listing-id breaker. Equal keys preserve relative order via Dart stable sort. |
| `lib/utils/weighted_listing_matcher.dart` | `WeightedListingMatcher.fetchScoredListings` | Sorts hard-pass pool by preference score only; equal preference scores keep filter-pass (input) order. |
| `lib/utils/marketplace_listing_pipeline.dart` | `MarketplaceListingPipeline.runWithFilters` | Builds weightedPool then calls ListingMatchEngine.rank; seed path starts from SampleListingsDublin.items construction order. |
| `lib/data/sample_listings_dublin_v2.dart` | `SampleListingsDublinV2.items` | Rebuilds unmodifiable list in fixed composition order each get; production demo path does not shuffle. |

- Identical-run instability: false
- Input-order dependency detected: true
- Missing listing-id final breaker: true
- Score collisions present: true
- Dart sort stable: true

## Part 6 — Risk

- **Verdict:** PASS WITH WARNINGS
- **Severity:** Medium

### Recommended action (decision only)

Decision: add a deterministic final tie-breaker (canonical listing id ascending) in ListingMatchEngine.rank after match.score, and mirror in WeightedListingMatcher preference sort if soft-score ties matter. Do not change production until explicitly approved. Priority driven by severity (Medium).

## Production code

No production matching/ranking code was modified. Test-only harness: `test/ranking_tie_stability_audit_test.dart`.
