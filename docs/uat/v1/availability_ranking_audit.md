# Availability Ranking Audit

**Verdict: PASS WITH WARNINGS**

Severity: Medium

Timing soft-score influences order (ablation/avg-rank evidence), but exceptions exist: possible_issue=16, unexplained=4, sep1_ok=true. Binary earn/no-earn timing points + flexible landlords limit fine-grained month ordering.

Audited at: `2026-09-01T20:56:50.988370Z`

Reference date for window bucketing: `2026-08-05`

Recommended action: Accept soft-preference design; optional follow-up to grade timing by proximity if product wants stricter Available-Now preference within the earning band.

Production matching/ranking code modified: **false**

## Timing mechanism (inventored code)

| Aspect | Value |
| --- | --- |
| Hard filter | `false` |
| Soft preference | `true` |
| Quality tier role | Ranking uses percentage quality tiers (50+/25+/<25) then score; timing contributes to score/percentage but is not its own sort key. |

ListingSearchFilters.passesMoveInWindow always returns true; TowerFilterPolicy documents move-in as Soft for both towers; ListingMatchEngine hard filters (rent/share/buy) do not exclude on timing.

MoveInTimingEngine.evaluate → TimingMatchQuality; earnsTimingScore for strong/good/flexible only; ListingMatchEngine adds weights.timing when timingMatch; weak quality earns 0 timing points (warning only).

ProfilePortalInheritanceService.seekerFeedDefaults does not set moveInWindow; WeightedListingMatcher move-in soft counter is unused on the production Explore path. Timing impact is solely via ListingMatchEngine score.

## Seed availability buckets

Listing count: 90

| Bucket | Count |
| --- | --- |
| Available Now / Aug | 20 |
| Sep | 21 |
| Oct | 20 |
| Nov | 16 |
| Dec | 13 |

DublinListingBuilder._availableFromForId cycles months Aug–Dec 2026 (8 + (n-1)%5); seed has no January unless raw override.

## Part 1 — Test seekers

5 Shared Living + 5 Independent Places from frozen UAT seekers covering immediate (Aug this_month), near-term (Sep next_month), and later/future move dates. IP frozen set max is 2026-11-01 (within_3_months at reference 2026-08-05); no IP flexible-horizon seeker exists in frozen fixture.

| Seeker | Marketplace | Move date | Window | Band | Role |
| --- | --- | --- | --- | --- | --- |
| `SL-STU-03` | shared_living | 2026-08-20 | `this_month` | immediate | Aug this_month — high budget student |
| `SL-EDGE-03` | shared_living | 2026-08-04 | `this_month` | immediate | Aug this_month — early August edge |
| `SL-STU-01` | shared_living | 2026-09-01 | `next_month` | near-term | Sep 1 next_month — primary Sep edge case |
| `SL-PRO-03` | shared_living | 2026-09-15 | `next_month` | near-term | Sep 15 next_month — professional |
| `SL-STU-04` | shared_living | 2027-01-10 | `flexible` | future | Jan 2027 flexible horizon |
| `IP-EDGE-06` | independent_places | 2026-08-05 | `this_month` | immediate | Aug this_month — budget-constrained IP |
| `IP-SIN-07` | independent_places | 2026-08-20 | `this_month` | immediate | Aug this_month — single professional |
| `IP-SIN-01` | independent_places | 2026-09-01 | `next_month` | near-term | Sep 1 next_month — primary Sep edge case |
| `IP-CPL-01` | independent_places | 2026-09-01 | `next_month` | near-term | Sep 1 next_month — couple |
| `IP-FAM-06` | independent_places | 2026-11-01 | `within_3_months` | later | Nov within_3_months — latest IP in frozen set |

## Part 2 — Availability analysis (top 10)

### `SL-STU-03`

Move date: **2026-08-20** → `this_month` (immediate). Ranked: 36.

| Rank | Listing | Available from | Bucket | Score | Timing | Quality |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `dub-share-28` | 2026-09-03 | Sep | 78 | true | good |
| 2 | `dub-share-09` | 2026-11-01 | Nov | 78 | true | flexible |
| 3 | `dub-share-27` | 2026-08-22 | Available Now / Aug | 78 | true | good |
| 4 | `dub-share-20` | 2026-09-01 | Sep | 78 | true | good |
| 5 | `dub-share-33` | 2026-10-27 | Oct | 78 | false | weak |
| 6 | `dub-share-35` | 2026-11-17 | Nov | 73 | false | weak |
| 7 | `dub-share-22` | 2026-11-01 | Nov | 73 | false | weak |
| 8 | `dub-share-18` | 2026-10-01 | Oct | 72 | true | flexible |
| 9 | `dub-share-30` | 2026-09-25 | Sep | 72 | true | flexible |
| 10 | `dub-share-11` | 2026-08-07 | Available Now / Aug | 72 | true | strong |

Timing stats: match=22, miss=14, avg_rank_match=17.318181818181817, avg_rank_miss=20.357142857142858.
Ablation (clear move-in fields): top5_changed=true, top1_changed=true.

### `SL-EDGE-03`

Move date: **2026-08-04** → `this_month` (immediate). Ranked: 34.

| Rank | Listing | Available from | Bucket | Score | Timing | Quality |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `dub-share-02` | 2026-09-07 | Sep | 80 | true | good |
| 2 | `dub-share-23` | 2026-08-20 | Available Now / Aug | 80 | true | good |
| 3 | `dub-share-31` | 2026-10-05 | Oct | 80 | false | weak |
| 4 | `dub-share-06` | 2026-08-19 | Available Now / Aug | 75 | true | flexible |
| 5 | `dub-share-34` | 2026-11-06 | Nov | 75 | false | weak |
| 6 | `dub-share-01` | 2026-08-04 | Available Now / Aug | 75 | true | strong |
| 7 | `dub-share-15` | 2026-12-19 | Dec | 75 | true | flexible |
| 8 | `dub-share-19` | 2026-08-15 | Available Now / Aug | 73 | true | good |
| 9 | `dub-share-32` | 2026-10-16 | Oct | 72 | false | weak |
| 10 | `dub-share-39` | 2026-08-18 | Available Now / Aug | 72 | true | good |

Timing stats: match=20, miss=14, avg_rank_match=16.05, avg_rank_miss=19.571428571428573.
Ablation (clear move-in fields): top5_changed=true, top1_changed=true.

### `SL-STU-01`

Move date: **2026-09-01** → `next_month` (near-term). Ranked: 19.

| Rank | Listing | Available from | Bucket | Score | Timing | Quality |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `dub-share-20` | 2026-09-01 | Sep | 78 | true | good |
| 2 | `dub-share-28` | 2026-09-03 | Sep | 78 | true | good |
| 3 | `dub-share-33` | 2026-10-27 | Oct | 78 | true | flexible |
| 4 | `dub-share-04` | 2026-11-13 | Nov | 72 | false | weak |
| 5 | `dub-share-11` | 2026-08-07 | Available Now / Aug | 72 | true | good |
| 6 | `dub-share-18` | 2026-10-01 | Oct | 72 | true | flexible |
| 7 | `dub-share-30` | 2026-09-25 | Sep | 72 | true | good |
| 8 | `dub-share-36` | 2026-11-28 | Nov | 68 | false | weak |
| 9 | `dub-share-09` | 2026-11-01 | Nov | 71 | true | flexible |
| 10 | `dub-share-22` | 2026-11-01 | Nov | 71 | false | weak |

Timing stats: match=14, miss=5, avg_rank_match=9.642857142857142, avg_rank_miss=11.0.
Ablation (clear move-in fields): top5_changed=false, top1_changed=false.

### `SL-PRO-03`

Move date: **2026-09-15** → `next_month` (near-term). Ranked: 40.

| Rank | Listing | Available from | Bucket | Score | Timing | Quality |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `dub-share-29` | 2026-09-14 | Sep | 81 | true | good |
| 2 | `dub-share-32` | 2026-10-16 | Oct | 80 | true | flexible |
| 3 | `dub-share-07` | 2026-09-22 | Sep | 80 | true | good |
| 4 | `dub-share-08` | 2026-10-25 | Oct | 80 | true | flexible |
| 5 | `dub-share-34` | 2026-11-06 | Nov | 80 | false | weak |
| 6 | `dub-share-12` | 2026-09-10 | Sep | 80 | true | flexible |
| 7 | `dub-share-16` | 2026-08-22 | Available Now / Aug | 80 | true | good |
| 8 | `dub-share-17` | 2026-09-25 | Sep | 80 | true | good |
| 9 | `dub-share-21` | 2026-10-01 | Oct | 80 | true | good |
| 10 | `dub-share-24` | 2026-12-01 | Dec | 80 | false | weak |

Timing stats: match=29, miss=11, avg_rank_match=18.724137931034484, avg_rank_miss=25.181818181818183.
Ablation (clear move-in fields): top5_changed=true, top1_changed=false.

### `SL-STU-04`

Move date: **2027-01-10** → `flexible` (future). Ranked: 16.

| Rank | Listing | Available from | Bucket | Score | Timing | Quality |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `dub-share-04` | 2026-11-13 | Nov | 78 | true | flexible |
| 2 | `dub-share-11` | 2026-08-07 | Available Now / Aug | 78 | true | flexible |
| 3 | `dub-share-18` | 2026-10-01 | Oct | 78 | true | flexible |
| 4 | `dub-share-30` | 2026-09-25 | Sep | 78 | true | flexible |
| 5 | `dub-share-28` | 2026-09-03 | Sep | 72 | true | flexible |
| 6 | `dub-share-33` | 2026-10-27 | Oct | 72 | true | flexible |
| 7 | `dub-share-20` | 2026-09-01 | Sep | 68 | true | flexible |
| 8 | `dub-share-36` | 2026-11-28 | Nov | 71 | true | flexible |
| 9 | `dub-share-22` | 2026-11-01 | Nov | 64 | true | flexible |
| 10 | `dub-share-01` | 2026-08-04 | Available Now / Aug | 74 | true | flexible |

Timing stats: match=16, miss=0, avg_rank_match=8.5, avg_rank_miss=null.
Ablation (clear move-in fields): top5_changed=false, top1_changed=false.

### `IP-EDGE-06`

Move date: **2026-08-05** → `this_month` (immediate). Ranked: 1.

| Rank | Listing | Available from | Bucket | Score | Timing | Quality |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `dub-rent-27` | 2026-08-12 | Available Now / Aug | 54 | true | good |

Timing stats: match=1, miss=0, avg_rank_match=1.0, avg_rank_miss=null.
Ablation (clear move-in fields): top5_changed=false, top1_changed=false.

### `IP-SIN-07`

Move date: **2026-08-20** → `this_month` (immediate). Ranked: 35.

| Rank | Listing | Available from | Bucket | Score | Timing | Quality |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `dub-rent-24` | 2026-10-01 | Oct | 85 | true | flexible |
| 2 | `dub-rent-17` | 2026-09-25 | Sep | 85 | true | flexible |
| 3 | `dub-rent-08` | 2026-10-25 | Oct | 85 | false | weak |
| 4 | `dub-rent-11` | 2026-08-07 | Available Now / Aug | 85 | true | strong |
| 5 | `dub-rent-13` | 2026-10-13 | Oct | 85 | false | weak |
| 6 | `dub-rent-32` | 2026-08-20 | Available Now / Aug | 85 | true | good |
| 7 | `dub-rent-46` | 2026-10-02 | Oct | 85 | false | weak |
| 8 | `dub-rent-18` | 2026-10-01 | Oct | 85 | true | flexible |
| 9 | `dub-rent-37` | 2026-10-18 | Oct | 85 | false | weak |
| 10 | `dub-rent-33` | 2026-09-02 | Sep | 85 | true | good |

Timing stats: match=19, miss=16, avg_rank_match=18.36842105263158, avg_rank_miss=17.5625.
Ablation (clear move-in fields): top5_changed=true, top1_changed=false.

### `IP-SIN-01`

Move date: **2026-09-01** → `next_month` (near-term). Ranked: 22.

| Rank | Listing | Available from | Bucket | Score | Timing | Quality |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `dub-rent-13` | 2026-10-13 | Oct | 85 | true | good |
| 2 | `dub-rent-18` | 2026-10-01 | Oct | 85 | true | flexible |
| 3 | `dub-rent-37` | 2026-10-18 | Oct | 85 | true | flexible |
| 4 | `dub-rent-05` | 2026-12-16 | Dec | 70 | false | weak |
| 5 | `dub-rent-32` | 2026-08-20 | Available Now / Aug | 70 | true | good |
| 6 | `dub-rent-45` | 2026-09-22 | Sep | 70 | true | good |
| 7 | `dub-rent-06` | 2026-08-19 | Available Now / Aug | 60 | true | flexible |
| 8 | `dub-rent-14` | 2026-11-16 | Nov | 60 | false | weak |
| 9 | `dub-rent-38` | 2026-10-29 | Oct | 60 | true | flexible |
| 10 | `dub-rent-50` | 2026-12-12 | Dec | 60 | false | weak |

Timing stats: match=16, miss=6, avg_rank_match=11.0625, avg_rank_miss=12.666666666666666.
Ablation (clear move-in fields): top5_changed=true, top1_changed=true.

### `IP-CPL-01`

Move date: **2026-09-01** → `next_month` (near-term). Ranked: 33.

| Rank | Listing | Available from | Bucket | Score | Timing | Quality |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `dub-rent-04` | 2026-11-13 | Nov | 60 | false | weak |
| 2 | `dub-rent-11` | 2026-08-07 | Available Now / Aug | 60 | true | good |
| 3 | `dub-rent-13` | 2026-10-13 | Oct | 60 | true | good |
| 4 | `dub-rent-17` | 2026-09-25 | Sep | 60 | true | good |
| 5 | `dub-rent-18` | 2026-10-01 | Oct | 60 | true | flexible |
| 6 | `dub-rent-33` | 2026-09-02 | Sep | 60 | true | good |
| 7 | `dub-rent-37` | 2026-10-18 | Oct | 60 | true | flexible |
| 8 | `dub-rent-38` | 2026-10-29 | Oct | 60 | true | flexible |
| 9 | `dub-rent-45` | 2026-09-22 | Sep | 60 | true | good |
| 10 | `dub-rent-46` | 2026-10-02 | Oct | 60 | true | good |

Timing stats: match=25, miss=8, avg_rank_match=16.8, avg_rank_miss=17.625.
Ablation (clear move-in fields): top5_changed=true, top1_changed=false.

### `IP-FAM-06`

Move date: **2026-11-01** → `within_3_months` (later). Ranked: 49.

| Rank | Listing | Available from | Bucket | Score | Timing | Quality |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `dub-rent-44` | 2026-09-08 | Sep | 70 | true | good |
| 2 | `dub-rent-03` | 2026-10-10 | Oct | 70 | true | flexible |
| 3 | `dub-rent-34` | 2026-09-15 | Sep | 70 | true | good |
| 4 | `dub-rent-15` | 2026-12-19 | Dec | 70 | true | flexible |
| 5 | `dub-rent-19` | 2026-09-15 | Sep | 70 | true | good |
| 6 | `dub-rent-21` | 2026-11-15 | Nov | 70 | true | good |
| 7 | `dub-rent-26` | 2026-12-01 | Dec | 70 | true | flexible |
| 8 | `dub-rent-35` | 2026-09-28 | Sep | 70 | true | good |
| 9 | `dub-rent-49` | 2026-11-11 | Nov | 70 | true | good |
| 10 | `dub-rent-40` | 2026-11-19 | Nov | 70 | true | flexible |

Timing stats: match=45, miss=4, avg_rank_match=24.377777777777776, avg_rank_miss=32.0.
Ablation (clear move-in fields): top5_changed=false, top1_changed=false.

## Part 3 — Order validation

| Classification | Count |
| --- | --- |
| Justified by stronger score | 205 |
| Unexplained ordering | 4 |
| Possible ranking issue | 16 |

Inversion = later availability bucket ranked above earlier bucket (top-15 region, capped 25/seeker). Classification uses timing_match flags + score delta; binary timing points mean same-quality buckets are not further ordered by calendar proximity.

### Sample non-justified inversions

- `SL-STU-03`: `dub-share-09` (Nov, score 78, timing=true) above `dub-share-33` (Oct, score 78, timing=false) → **possible_ranking_issue**
- `SL-STU-03`: `dub-share-09` (Nov, score 78, timing=true) above `dub-share-13` (Oct, score 60, timing=false) → **possible_ranking_issue**
- `SL-EDGE-03`: `dub-share-34` (Nov, score 75, timing=false) above `dub-share-01` (Available Now / Aug, score 75, timing=true) → **possible_ranking_issue**
- `SL-STU-01`: `dub-share-04` (Nov, score 72, timing=false) above `dub-share-18` (Oct, score 72, timing=true) → **possible_ranking_issue**
- `SL-STU-01`: `dub-share-04` (Nov, score 72, timing=false) above `dub-share-30` (Sep, score 72, timing=true) → **possible_ranking_issue**
- `SL-STU-01`: `dub-share-04` (Nov, score 72, timing=false) above `dub-share-02` (Sep, score 74, timing=true) → **possible_ranking_issue**
- `SL-STU-01`: `dub-share-04` (Nov, score 72, timing=false) above `dub-share-11` (Available Now / Aug, score 72, timing=true) → **possible_ranking_issue**
- `SL-STU-01`: `dub-share-18` (Oct, score 72, timing=true) above `dub-share-02` (Sep, score 74, timing=true) → **unexplained_ordering**

## Part 4 — Edge case (move date 2026-09-01)

Sep-1 (next_month) seekers: timing soft-score behaves as coded (earn points for overlap/gap≤30/flexible; no calendar sort within earning set).

### `SL-STU-01`

Window: `next_month`. Follows logic: **true**.

Best-of-bucket: timing-earning buckets average better rank (3.0) than weak (9.0).

| Bucket | Best rank | Listing | Score | Timing quality |
| --- | --- | --- | --- | --- |
| Available Now / Aug | 5 | `dub-share-11` | 72 | good |
| Sep | 1 | `dub-share-20` | 78 | good |
| Oct | 3 | `dub-share-33` | 78 | flexible |
| Nov | 4 | `dub-share-04` | 72 | weak |
| Dec | 14 | `dub-share-05` | 67 | weak |

### `IP-SIN-01`

Window: `next_month`. Follows logic: **true**.

Best-of-bucket: timing-earning buckets average better rank (4.0) than weak (6.0).

| Bucket | Best rank | Listing | Score | Timing quality |
| --- | --- | --- | --- | --- |
| Available Now / Aug | 5 | `dub-rent-32` | 70 | good |
| Sep | 6 | `dub-rent-45` | 70 | good |
| Oct | 1 | `dub-rent-13` | 85 | good |
| Nov | 8 | `dub-rent-14` | 60 | weak |
| Dec | 4 | `dub-rent-05` | 70 | weak |

## Part 5 — Availability impact

| Metric | Value |
| --- | --- |
| Seekers with timing match+miss | 8 |
| Timing-match better avg rank | 7 |
| Ablation top-5 changed | 6 |
| Ablation top-1 changed | 3 |
| Influences ordering | true |
| Appears ignored | false |

## Part 6 — Result

- Classification: **PASS WITH WARNINGS**
- Severity: **Medium**
- Timing soft-score influences order (ablation/avg-rank evidence), but exceptions exist: possible_issue=16, unexplained=4, sep1_ok=true. Binary earn/no-earn timing points + flexible landlords limit fine-grained month ordering.

