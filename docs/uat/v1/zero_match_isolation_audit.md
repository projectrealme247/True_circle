# Zero-Match Isolation Audit — TrueCircle V1

**Audited at:** 2026-09-01T20:57:19.733311Z

## Verdict

**Overall: FAIL**

| Criterion | Result |
|-----------|--------|
| All ZERO_MATCH seekers return 0 | NO |
| Empty state correct | YES |
| Cross-marketplace listings | 0 |
| Marketplace bleed | 0 |
| Cross-marketplace fallback | ABSENT |
| Marketplace isolation preserved | YES |
| Seekers pass | 0/3 |
| Total matches returned | 6 |

## Per-seeker results

| seeker_id | marketplace | expected_result | matches_returned | empty_state_displayed | cross_marketplace_listings_shown | recommended_fallback_content | shared_living_results_count | independent_places_results_count | marketplace_correct | result |
|-----------|-------------|-----------------|------------------|------------------------|--------------------------------|-------------------------------|----------------------------|--------------------------------|---------------------|--------|
| `SL-EDGE-01` | shared_living | ZERO_MATCHES | 2 | NO | NO | NO | 2 | 0 | **YES** | **FAIL** |
| `IP-EDGE-04` | independent_places | ZERO_MATCHES | 3 | NO | NO | NO | 0 | 3 | **YES** | **FAIL** |
| `IP-EDGE-06` | independent_places | ZERO_MATCHES | 1 | NO | NO | NO | 0 | 1 | **YES** | **FAIL** |

### `SL-EDGE-01`

- **Scenario:** Edge · very low budget · D2/D4 private · zero/few matches
- **Active mode:** `explore`
- **Session marketplace:** `shared_living`
- **Tower token:** `Share`
- **Inherited hard filters:** budgetMax=350, occupant=Working Professionals, gender=null, food=null
- **Session prefs (not hard-filtered by Explore defaults):** locations=[Dublin 2, Dublin 4], room=private, property=null, parking=false, pets=false, transit=luas, move=2026-09-01
- **Pipeline:** corpus 90 → afterTower 40 → afterFilters 2 → ranked 2 (closestFallback=false)
- **empty_state_displayed:** NO (code_path_inferred)
- **cross_marketplace_listings_shown:** NO
- **recommended_fallback_content:** NO
- **marketplace_correct:** **YES**
- **result:** **FAIL**
- **fail_reason:** expected ZERO_MATCHES but matches_returned=2 (ids=dub-share-04,dub-share-11)
- **Bleed listing IDs:** _(none)_
- **returned_listing_ids** (2):
  - `dub-share-04`
  - `dub-share-11`

### `IP-EDGE-04`

- **Scenario:** Edge · extremely low budget · D2/D4 · zero matches
- **Active mode:** `explore`
- **Session marketplace:** `independent_places`
- **Tower token:** `Rent`
- **Inherited hard filters:** budgetMax=900, occupant=null, gender=null, food=null
- **Session prefs (not hard-filtered by Explore defaults):** locations=[Dublin 2, Dublin 4], room=null, property=apartment, parking=false, pets=false, transit=null, move=null
- **Pipeline:** corpus 90 → afterTower 50 → afterFilters 3 → ranked 3 (closestFallback=false)
- **empty_state_displayed:** NO (code_path_inferred)
- **cross_marketplace_listings_shown:** NO
- **recommended_fallback_content:** NO
- **marketplace_correct:** **YES**
- **result:** **FAIL**
- **fail_reason:** expected ZERO_MATCHES but matches_returned=3 (ids=dub-rent-27,dub-rent-45,dub-rent-14)
- **Bleed listing IDs:** _(none)_
- **returned_listing_ids** (3):
  - `dub-rent-27`
  - `dub-rent-45`
  - `dub-rent-14`

### `IP-EDGE-06`

- **Scenario:** Edge · zero match · studio + pets + parking + D4 + ultra low budget
- **Active mode:** `explore`
- **Session marketplace:** `independent_places`
- **Tower token:** `Rent`
- **Inherited hard filters:** budgetMax=800, occupant=null, gender=null, food=null
- **Session prefs (not hard-filtered by Explore defaults):** locations=[Dublin 4], room=null, property=studio, parking=true, pets=true, transit=dart, move=2026-08-05
- **Pipeline:** corpus 90 → afterTower 50 → afterFilters 1 → ranked 1 (closestFallback=false)
- **empty_state_displayed:** NO (code_path_inferred)
- **cross_marketplace_listings_shown:** NO
- **recommended_fallback_content:** NO
- **marketplace_correct:** **YES**
- **result:** **FAIL**
- **fail_reason:** expected ZERO_MATCHES but matches_returned=1 (ids=dub-rent-27)
- **Bleed listing IDs:** _(none)_
- **returned_listing_ids** (1):
  - `dub-rent-27`

## Blockers

- `SL-EDGE-01`: expected ZERO_MATCHES but matches_returned=2 (ids=dub-share-04,dub-share-11) (matches=2)
- `IP-EDGE-04`: expected ZERO_MATCHES but matches_returned=3 (ids=dub-rent-27,dub-rent-45,dub-rent-14) (matches=3)
- `IP-EDGE-06`: expected ZERO_MATCHES but matches_returned=1 (ids=dub-rent-27) (matches=1)

## Methodology

### Code paths invoked

- `MarketplaceSpace.fromSession (marketplace routing from seeker session)`
- `ProfileOnboardingRepository.snapshotFromSession + ProfilePortalInheritanceService.seekerFeedDefaults (Active Mode Explore inherited hard filters)`
- `MarketplaceListingPipeline.runWithFilters (tower equality → weighted hard exclusion → rank)`
- `ListingData.listingType (classify returned listings Share vs Rent)`

### Listing corpus

- **Dataset:** SampleListingsDublin (local Dublin marketplace seed)
- **Counts:** 40 Shared Living (`Share`) · 50 Independent Places (`Rent`) · total 90

### Empty-state assessment

- **Method:** code_path_inferred
- **Limitation:** Pipeline test asserts matches==0; empty_state_displayed=YES when matches_returned==0 AND HomeScreen empty-state widgets confirmed for ranked-empty / tower-empty paths. Not UI-instrumented (no widget pump of HomeScreen).

### Recommended-fallback assessment

- **Method:** codebase_search
- **Cross-marketplace listing injection found:** false
- **Notes:** Zero-match UI copy may mention "switch tabs" and the family shared-living unavailable state offers a Browse Independent Places CTA that changes the active tab — neither injects opposite-marketplace listing cards into the feed. Soft closest-match / filter relaxation stays within the same tower.

### Seeker dataset

- **Status:** reconstructed
- **Note:** Frozen UAT seeker JSON is not checked into the repo. ZERO_MATCHES edge seekers reconstructed from prior UAT chat artifact and mapped into session keys + Explore inherited filters (budget / SL soft profile fields). preferred_locations, parking, pets, property_type, and transit are session metadata for ranking context where wired; they are NOT additional hard exclusions in seekerFeedDefaults.

### Failure conditions checked

- Any cross-marketplace listings shown
- Any marketplace bleed
- Empty state not shown when match count = 0
- Fallback recommendations from the other marketplace
- Marketplace isolation broken
- Expected ZERO_MATCHES but matches_returned ≠ 0

Overall **PASS** only if all three ZERO_MATCH seekers PASS.

