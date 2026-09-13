# Missing-Data Listing Audit — TrueCircle V1

**Audited at:** 2026-09-01T20:57:05.370253Z

## Verdict

**PASS WITH WARNINGS** — Resilient rendering; 0 high + 4 medium findings (sparse sections / missing explanations / corpus gaps)

**Success criteria met:** YES

| Criterion | Met? |
|-----------|------|
| `incomplete_listings_render` | true |
| `no_broken_detail_pages` | true |
| `no_broken_cards` | true |
| `no_empty_ui_components` | true |
| `match_explanations_remain_valid` | true |
| `no_runtime_errors` | true |

## Source

- **Dataset:** SampleListingsDublin (ListingsStorageService seed)
- **Counts:** 40 Shared Living (`Share`) · 50 Independent Places (`Rent`)
- **Paths:**
  - `lib/data/sample_listings_dublin.dart`
  - `lib/data/sample_listings_dublin_v2.dart`
  - `lib/data/sample_listings_dublin_legacy.dart`
  - `lib/data/sample_listings_dublin_expansion.dart`
  - `lib/data/dublin_listing_builder.dart`

## PART 1 — Completeness scoring

Score = present usable fields / relevant field set. Presence is judged via the same helpers the product uses (`ListingPropertyHighlights`, `ListingData`, `SharedLivingMatchTokens`, `TenurePreference.fromListing`).

### Shared Living field checklist (20)

| Field ID | Label | Surfaces |
|----------|-------|----------|
| `room_type` | Room type | Room Snapshot, card chips, ListingMatchEngine share room |
| `bathroom` | Bathroom | Room Snapshot, ListingMatchEngine share bathroom |
| `rent` | Rent / price | Room Snapshot, cards, ranking budget |
| `availability` | Availability / move-in | Room Snapshot, card chips, timing match |
| `household_type` | Household type | Household Snapshot, card chips, occupant match |
| `occupants` | Current occupants | Household Snapshot |
| `culture_languages` | Culture · languages | Household Culture (hide-if-empty) |
| `culture_kitchen` | Culture · kitchen / food | Household Culture (hide-if-empty) |
| `culture_pets_smoking` | Culture · pets / smoking | Household Culture lifestyle flags |
| `property_type` | Property type | Property Details |
| `furnishing` | Furnishing | Property Details |
| `parking` | Parking | Property Details (incl. explicit No Parking) |
| `bike` | Bike storage | Property Details / activeHighlights |
| `ber` | BER | Property Details |
| `transit` | Transit / proximity | Transit & Commute, card commute chip |
| `title` | Title | Detail hero, cards |
| `location` | Location / area | Detail subtitle, cards, location match |
| `photos` | Photos | ListingPhotoGallery / PropertyCard cover |
| `description` | Description | Detail DESCRIPTION (placeholder if empty) |
| `host` | Host | HOSTED BY / card trust line |

### Independent Places field checklist (16)

| Field ID | Label | Surfaces |
|----------|-------|----------|
| `bedrooms` | Bedrooms | Property Highlights, card chips, bed match |
| `bathrooms` | Bathrooms | Property Highlights |
| `property_type` | Property type | Property Highlights |
| `furnishing` | Furnishing | Property Highlights |
| `availability` | Availability | Property Highlights, card chips |
| `parking` | Parking | Property Highlights |
| `pets` | Pets policy | Property Highlights |
| `lease` | Lease / tenure | Property Highlights (agreement_type) |
| `ber` | BER | Property Highlights |
| `transit` | Transit / proximity | Transit & Commute, card commute chip |
| `rent` | Rent / price | Cards, ranking budget (not in highlight grid) |
| `title` | Title | Detail hero, cards |
| `location` | Location / area | Detail subtitle, cards |
| `photos` | Photos | ListingPhotoGallery / PropertyCard cover |
| `description` | Description | Detail DESCRIPTION (placeholder if empty) |
| `host` | Host | HOSTED BY / card trust line |

### Extremes

| Marketplace | Most complete | Least complete |
|-------------|----------------|----------------|
| Shared Living | `dub-share-01` score **0.8** (16/20) | `dub-share-13` score **0.6** (12/20) |
| Independent Places | `dub-rent-21` score **0.8125** (13/16) | `dub-rent-02` score **0.6875** (11/16) |

#### Shared Living — most complete

```
listing_id: dub-share-01
marketplace: shared_living
completeness_score: 0.8
missing_fields: property_type, furnishing, bike, ber
available_fields: room_type, bathroom, rent, availability, household_type, occupants, culture_languages, culture_kitchen, culture_pets_smoking, parking, transit, title, location, photos, description, host
```

#### Shared Living — least complete

```
listing_id: dub-share-13
marketplace: shared_living
completeness_score: 0.6
missing_fields: household_type, occupants, property_type, furnishing, parking, bike, ber, transit
available_fields: room_type, bathroom, rent, availability, culture_languages, culture_kitchen, culture_pets_smoking, title, location, photos, description, host
```

#### Independent Places — most complete

```
listing_id: dub-rent-21
marketplace: independent_places
completeness_score: 0.8125
missing_fields: pets, lease, ber
available_fields: bedrooms, bathrooms, property_type, furnishing, availability, parking, transit, rent, title, location, photos, description, host
```

#### Independent Places — least complete

```
listing_id: dub-rent-02
marketplace: independent_places
completeness_score: 0.6875
missing_fields: parking, pets, lease, ber, transit
available_fields: bedrooms, bathrooms, property_type, furnishing, availability, rent, title, location, photos, description, host
```

### Corpus completeness summary

- **shared_living:** n=40 min=0.6 max=0.8 avg=0.7288
  - Most missing: property_type(40), bike(40), ber(40), parking(39), occupants(35), furnishing(13), culture_kitchen(6), transit(3)
- **independent_places:** n=50 min=0.6875 max=0.8125 avg=0.7375
  - Most missing: pets(50), lease(50), ber(50), parking(48), transit(7), bathrooms(5)

Full per-listing table: `docs/uat/v1/missing_data_listing_audit.json` → `listings[]`.

## PART 2 — Detail page resilience (least complete)

### Shared Living least-complete `dub-share-13` (score 0.6)

| Section | Status | Reason |
|---------|--------|--------|
| card_rendering | **PASS** | 2 chip(s), no blank labels |
| detail_page_story | **PASS** | Story builders gate sections on isNotEmpty; description uses placeholder "No description provided." when empty; host uses "Your host" fallback. |
| match_explanations | **PASS** | 1 explanation(s), no throw |
| room_snapshot | **PASS** | 3 cells, no blank labels |
| household_snapshot | **PASS** | Empty → HOUSEHOLD SNAPSHOT hidden |
| household_culture | **PASS** | 3 cells, no blank labels |
| property_details | **PASS** | Empty → PROPERTY DETAILS hidden |
| transit_commute | **PASS** | Null/empty MultiCommuteDisplayModel → ListingDetailCommuteSection returns SizedBox.shrink() |
| ranking | **PASS** | ListingMatchEngine.rank completed; ranked=1 requiresOnboarding=false |

### Independent Places least-complete `dub-rent-02` (score 0.6875)

| Section | Status | Reason |
|---------|--------|--------|
| card_rendering | **PASS** | 2 chip(s), no blank labels |
| detail_page_story | **PASS** | IP story gates highlights + preference on isNotEmpty; commute shrinks when empty |
| match_explanations | **PASS** | 3 explanation(s), no throw |
| property_highlights | **PASS** | 5 fact cells, no blank labels |
| property_details | **PASS** | 5 fact cells, no blank labels |
| transit_commute | **PASS** | 1 commute row(s) |
| ranking | **PASS** | ListingMatchEngine.rank completed; ranked=1 |

## PART 3 — Empty data handling

| Concern | Finding |
|---------|---------|
| Blank sections | Avoided for highlight grids — listing_detail_page_layout wraps ROOM SNAPSHOT / HOUSEHOLD SNAPSHOT / CULTURE / PROPERTY DETAILS / PROPERTY HIGHLIGHTS / preference insight in `if (cells.isNotEmpty)`. |
| Empty chips | PropertyCard._CardMatchChips returns SizedBox.shrink() when no chip labels resolve; chips only appended when labels non-null/non-empty. |
| Broken layouts | Fixed-height chip row still reserved on cards (chipsHeight) even when shrink — layout gap only, not broken. Detail page Column collapses hidden sections. |
| Placeholder text | Description: "No description provided." Host: "Your host". Title ListingData fallback: "Untitled listing". Card location can fallback toward Dublin area copy. |
| Missing explanations | Preference insight card omitted when explanation list empty — expected for sparse listings / hard-filter failures. |
| Rendering errors | Helpers return empty lists rather than throwing on missing fields. Legacy ListingPropertyHighlights.gridCells fills 4 platform fallbacks. |

**Evidence:**
- `lib/widgets/listing_detail_page_layout.dart`
- `lib/widgets/listing_detail_commute_section.dart`
- `lib/widgets/property_card.dart`
- `lib/utils/listing_property_highlights.dart`
- `lib/utils/listing_match_engine.dart`

Synthetic `{}` maps: status **PASS** — Fully empty maps produce empty section cell lists (hidden) or legacy 4-cell platform fallbacks — no blank labels

## PART 4 — UAT impact

**Overall:** PASS WITH WARNINGS

### Blocker findings

_None._
### High severity findings

_None._
### Medium severity findings

- **shared_living** `—` / completeness_corpus: 40/40 Share listings missing BER — Property Details omits BER cell (section still hides empty slots correctly)
- **independent_places** `—` / completeness_corpus: 50/50 Rent listings missing agreement_type/lease — Property Highlights omits lease cell
- **independent_places** `—` / completeness_corpus: 50/50 Rent listings missing pets policy — Highlights omits pets cell
- **shared_living** `—` / completeness_corpus: 35/40 Share listings missing current_occupants — Household Snapshot may show cohort only or hide

## Success criteria

| Criterion | Result |
|-----------|--------|
| Incomplete listings still render correctly | true |
| No broken detail pages | true |
| No broken cards | true |
| No empty UI components (blank labels) | true |
| Match explanations remain valid | true |
| No runtime errors | true |

---

_Generated by `test/missing_data_listing_audit_test.dart`. Audit only — no production UI changes._
