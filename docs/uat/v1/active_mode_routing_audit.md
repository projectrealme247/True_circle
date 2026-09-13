# Active Mode Routing Audit — TrueCircle V1

**Audited at:** 2026-09-01T20:56:47.086796Z

## Verdict

**Overall: PASS**

| Criterion | Result |
|-----------|--------|
| 100% marketplace isolation | YES |
| Cross-marketplace listings | 0 |
| Marketplace bleed | 0 |
| Seekers pass | 2/2 |
| Total matches returned | 83 |

## Per-seeker results

| seeker_id | marketplace_requested | marketplace_returned | matches_returned | shared_living_count | independent_places_count | marketplace_correct |
|-----------|----------------------|---------------------|------------------|---------------------|--------------------------|--------------------|
| `SL-MARKET-01` | shared_living | shared_living | 39 | 39 | 0 | **YES** |
| `IP-MARKET-01` | independent_places | independent_places | 44 | 0 | 44 | **YES** |

### `SL-MARKET-01`

- **Scenario:** Marketplace Separation Validation — Shared Living Sentinel
- **Active mode:** `explore`
- **Session marketplace:** `shared_living`
- **Tower token:** `Share`
- **Pipeline:** corpus 90 → afterTower 40 → afterFilters 39 → ranked 39
- **marketplace_correct:** **YES**
- **Bleed listing IDs:** _(none)_
- **returned_listing_ids** (39):
  - `dub-share-19`
  - `dub-share-37`
  - `dub-share-40`
  - `dub-share-05`
  - `dub-share-06`
  - `dub-share-15`
  - `dub-share-32`
  - `dub-share-10`
  - `dub-share-31`
  - `dub-share-12`
  - `dub-share-26`
  - `dub-share-01`
  - `dub-share-39`
  - `dub-share-25`
  - `dub-share-02`
  - `dub-share-24`
  - `dub-share-34`
  - `dub-share-23`
  - `dub-share-29`
  - `dub-share-07`
  - `dub-share-16`
  - `dub-share-21`
  - `dub-share-13`
  - `dub-share-20`
  - `dub-share-18`
  - `dub-share-14`
  - `dub-share-28`
  - `dub-share-30`
  - `dub-share-11`
  - `dub-share-09`
  - `dub-share-33`
  - `dub-share-27`
  - `dub-share-35`
  - `dub-share-36`
  - `dub-share-04`
  - `dub-share-22`
  - `dub-share-08`
  - `dub-share-17`
  - `dub-share-38`

### `IP-MARKET-01`

- **Scenario:** Marketplace Separation Validation — Independent Places Sentinel
- **Active mode:** `explore`
- **Session marketplace:** `independent_places`
- **Tower token:** `Rent`
- **Pipeline:** corpus 90 → afterTower 50 → afterFilters 44 → ranked 44
- **marketplace_correct:** **YES**
- **Bleed listing IDs:** _(none)_
- **returned_listing_ids** (44):
  - `dub-rent-16`
  - `dub-rent-02`
  - `dub-rent-50`
  - `dub-rent-04`
  - `dub-rent-05`
  - `dub-rent-42`
  - `dub-rent-07`
  - `dub-rent-08`
  - `dub-rent-39`
  - `dub-rent-10`
  - `dub-rent-11`
  - `dub-rent-13`
  - `dub-rent-37`
  - `dub-rent-33`
  - `dub-rent-01`
  - `dub-rent-17`
  - `dub-rent-18`
  - `dub-rent-46`
  - `dub-rent-20`
  - `dub-rent-47`
  - `dub-rent-25`
  - `dub-rent-23`
  - `dub-rent-24`
  - `dub-rent-32`
  - `dub-rent-09`
  - `dub-rent-19`
  - `dub-rent-29`
  - `dub-rent-30`
  - `dub-rent-27`
  - `dub-rent-15`
  - `dub-rent-34`
  - `dub-rent-35`
  - `dub-rent-38`
  - `dub-rent-40`
  - `dub-rent-45`
  - `dub-rent-44`
  - `dub-rent-48`
  - `dub-rent-22`
  - `dub-rent-14`
  - `dub-rent-06`
  - `dub-rent-43`
  - `dub-rent-26`
  - `dub-rent-21`
  - `dub-rent-03`

## Methodology

### Code paths invoked

- `MarketplaceSpace.fromSession (marketplace routing from seeker session)`
- `MarketplaceSpace.towerPropertyType (Share vs Rent tower token)`
- `MarketplaceListingPipeline.runWithFilters (tower equality filter → weighted pool → ListingMatchEngine.rank)`
- `ListingData.listingType / MarketplaceSpace.fromTowerPropertyType (classify returned listings)`

### Listing corpus

- **Dataset:** SampleListingsDublin (local Dublin marketplace seed)
- **Counts:** 40 Shared Living (`Share`) · 50 Independent Places (`Rent`) · total 90
- **Paths:**
  - `lib/data/sample_listings_dublin.dart`
  - `lib/data/sample_listings_dublin_v2.dart`
  - `lib/data/sample_listings_dublin_legacy.dart`
  - `lib/data/sample_listings_dublin_expansion.dart`
  - `lib/data/dublin_listing_builder.dart`

### Marketplace determination

Canonical tower = ListingData.listingType (listing_type → type → marketplace_category). Share = shared_living; Rent = independent_places. Feed isolation is tower equality only in MarketplaceListingPipeline.run (afterTower).

### Seeker dataset

- **Status:** reconstructed
- **Note:** Frozen UAT seeker JSON is not checked into the repo. Sentinel preference fields reconstructed from prior UAT chat artifact (SL-MARKET-01 / IP-MARKET-01) and mapped into app session keys.

### Failure conditions checked

- Shared Living seeker receives any Independent Places listings
- Independent Places seeker receives any Shared Living listings
- Marketplace returned differs from marketplace requested

Overall **PASS** only if both sentinels pass with 0 cross-marketplace listings and 0 marketplace bleed.

