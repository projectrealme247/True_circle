# Budget Boundary Audit — TrueCircle V1

**Audited at:** 2026-09-01T20:56:51.455547Z

## Verdict

**Overall vs user success criteria: FAIL**

Production matches strict `rent ≤ budget` contract: **false**

| Metric | Value |
|--------|-------|
| Total tests | 30 |
| PASS (strict) | 20 |
| FAIL (strict) | 10 |
| Shared Living | pass 10 / fail 5 (5 listings, 15 tests) |
| Independent Places | pass 10 / fail 5 (5 listings, 15 tests) |
| SL/IP consistent with each other | true |
| rent−1 INCLUDED under production | 10 |

## Exact production budget rule

```
INCLUDED iff ListingData.listingPriceAmount(listing) <= (budgetMax * WeightedListingMatcher.budgetHardCapRatio).round()
```

- **Ratio:** `1.25` (`WeightedListingMatcher.budgetHardCapRatio`)
- **Price field:** ListingData.listingPriceAmount — digits parsed from listing `price` string (monthly rent / room rent as stored)
- **Production vs contract:** MISMATCH — production uses 1.25× buffer
- **User contract:** INCLUDED iff rent <= budget (exact equality included; rent - 1 excluded; no multiplier)

### Code citations

- `lib/utils/weighted_listing_matcher.dart (budgetHardCapRatio=1.25, passesHardExclusion)`
- `lib/utils/listing_search_intent.dart (ListingSearchFilters._budgetHardCapRatio=1.25)`
- `lib/utils/filter_inventory_stats.dart (_listingWithinBudgetMax)`
- `lib/utils/marketplace_listing_pipeline.dart (runWithFilters → WeightedListingMatcher.fetchScoredListings)`
- `lib/services/profile_portal_inheritance_service.dart (seekerFeedDefaults.budgetMax ← roomBudget for SL, maxBudget for IP; both hydrate from session budget_max)`

## Success criteria checklist

| Criterion | Met? |
|-----------|------|
| Exact rent = budget → INCLUDED | true |
| budget = rent − 1 → EXCLUDED | false |
| budget = rent + 1 → INCLUDED | true |
| SL and IP consistent | true |
| All cells pass strict contract | false |

## Selected listings

### Shared Living

| listing_id | rent |
|------------|------|
| `dub-share-04` | 350 |
| `dub-share-05` | 650 |
| `dub-share-06` | 800 |
| `dub-share-10` | 920 |
| `dub-share-03` | 1336 |

### Independent Places

| listing_id | rent |
|------------|------|
| `dub-rent-27` | 900 |
| `dub-rent-42` | 1550 |
| `dub-rent-29` | 1950 |
| `dub-rent-09` | 2650 |
| `dub-rent-31` | 4200 |

## Blockers

### `HARD_CAP_1_25X_VS_STRICT_CONTRACT`

Production hard gate is amount <= round(budgetMax * 1.25). User success criteria assume strict rent <= budget (no multiplier). At budget = rent - 1, rent is still typically INCLUDED because rent <= round((rent - 1) * 1.25) for all realistic Dublin rents.

## Full results matrix

| listing_id | marketplace | rent | budget_test | expected_result | actual_result | hard_cap | result |
|------------|-------------|------|-------------|-----------------|---------------|----------|--------|
| `dub-share-04` | shared_living | 350 | 349 | EXCLUDED | INCLUDED | 436 | **FAIL** |
| `dub-share-04` | shared_living | 350 | 350 | INCLUDED | INCLUDED | 438 | **PASS** |
| `dub-share-04` | shared_living | 350 | 351 | INCLUDED | INCLUDED | 439 | **PASS** |
| `dub-share-05` | shared_living | 650 | 649 | EXCLUDED | INCLUDED | 811 | **FAIL** |
| `dub-share-05` | shared_living | 650 | 650 | INCLUDED | INCLUDED | 813 | **PASS** |
| `dub-share-05` | shared_living | 650 | 651 | INCLUDED | INCLUDED | 814 | **PASS** |
| `dub-share-06` | shared_living | 800 | 799 | EXCLUDED | INCLUDED | 999 | **FAIL** |
| `dub-share-06` | shared_living | 800 | 800 | INCLUDED | INCLUDED | 1000 | **PASS** |
| `dub-share-06` | shared_living | 800 | 801 | INCLUDED | INCLUDED | 1001 | **PASS** |
| `dub-share-10` | shared_living | 920 | 919 | EXCLUDED | INCLUDED | 1149 | **FAIL** |
| `dub-share-10` | shared_living | 920 | 920 | INCLUDED | INCLUDED | 1150 | **PASS** |
| `dub-share-10` | shared_living | 920 | 921 | INCLUDED | INCLUDED | 1151 | **PASS** |
| `dub-share-03` | shared_living | 1336 | 1335 | EXCLUDED | INCLUDED | 1669 | **FAIL** |
| `dub-share-03` | shared_living | 1336 | 1336 | INCLUDED | INCLUDED | 1670 | **PASS** |
| `dub-share-03` | shared_living | 1336 | 1337 | INCLUDED | INCLUDED | 1671 | **PASS** |
| `dub-rent-27` | independent_places | 900 | 899 | EXCLUDED | INCLUDED | 1124 | **FAIL** |
| `dub-rent-27` | independent_places | 900 | 900 | INCLUDED | INCLUDED | 1125 | **PASS** |
| `dub-rent-27` | independent_places | 900 | 901 | INCLUDED | INCLUDED | 1126 | **PASS** |
| `dub-rent-42` | independent_places | 1550 | 1549 | EXCLUDED | INCLUDED | 1936 | **FAIL** |
| `dub-rent-42` | independent_places | 1550 | 1550 | INCLUDED | INCLUDED | 1938 | **PASS** |
| `dub-rent-42` | independent_places | 1550 | 1551 | INCLUDED | INCLUDED | 1939 | **PASS** |
| `dub-rent-29` | independent_places | 1950 | 1949 | EXCLUDED | INCLUDED | 2436 | **FAIL** |
| `dub-rent-29` | independent_places | 1950 | 1950 | INCLUDED | INCLUDED | 2438 | **PASS** |
| `dub-rent-29` | independent_places | 1950 | 1951 | INCLUDED | INCLUDED | 2439 | **PASS** |
| `dub-rent-09` | independent_places | 2650 | 2649 | EXCLUDED | INCLUDED | 3311 | **FAIL** |
| `dub-rent-09` | independent_places | 2650 | 2650 | INCLUDED | INCLUDED | 3313 | **PASS** |
| `dub-rent-09` | independent_places | 2650 | 2651 | INCLUDED | INCLUDED | 3314 | **PASS** |
| `dub-rent-31` | independent_places | 4200 | 4199 | EXCLUDED | INCLUDED | 5249 | **FAIL** |
| `dub-rent-31` | independent_places | 4200 | 4200 | INCLUDED | INCLUDED | 5250 | **PASS** |
| `dub-rent-31` | independent_places | 4200 | 4201 | INCLUDED | INCLUDED | 5251 | **PASS** |

## Failing rows sample

| listing_id | marketplace | rent | budget_test | expected | actual | result |
|------------|-------------|------|-------------|----------|--------|--------|
| `dub-share-04` | shared_living | 350 | 349 | EXCLUDED | INCLUDED | **FAIL** |
| `dub-share-05` | shared_living | 650 | 649 | EXCLUDED | INCLUDED | **FAIL** |
| `dub-share-06` | shared_living | 800 | 799 | EXCLUDED | INCLUDED | **FAIL** |
| `dub-share-10` | shared_living | 920 | 919 | EXCLUDED | INCLUDED | **FAIL** |
| `dub-share-03` | shared_living | 1336 | 1335 | EXCLUDED | INCLUDED | **FAIL** |
| `dub-rent-27` | independent_places | 900 | 899 | EXCLUDED | INCLUDED | **FAIL** |
| `dub-rent-42` | independent_places | 1550 | 1549 | EXCLUDED | INCLUDED | **FAIL** |
| `dub-rent-29` | independent_places | 1950 | 1949 | EXCLUDED | INCLUDED | **FAIL** |
| `dub-rent-09` | independent_places | 2650 | 2649 | EXCLUDED | INCLUDED | **FAIL** |
| `dub-rent-31` | independent_places | 4200 | 4199 | EXCLUDED | INCLUDED | **FAIL** |

## Marketplace consistency

- SL pattern: `rent_minus_1:INC=5/EXC=0 | rent_equal:INC=5/EXC=0 | rent_plus_1:INC=5/EXC=0`
- IP pattern: `rent_minus_1:INC=5/EXC=0 | rent_equal:INC=5/EXC=0 | rent_plus_1:INC=5/EXC=0`
- Consistent: **true**

_Generated by `test/budget_boundary_audit_test.dart`. Audit only — no production budget logic changes._

