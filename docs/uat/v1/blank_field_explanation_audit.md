# Blank-Field Explanation Audit — TrueCircle V1

**Audited at:** 2026-09-01T20:56:50.921361Z

## Verdict

**Overall: PASS WITH WARNINGS**

| Metric | Value |
|--------|-------|
| Seekers tested | 11 |
| Invalid reference rows | 30 |
| Terminology violations | 0 |
| Blocker | 0 |
| High | 0 |
| Medium | 30 |

## Success criteria

| Criterion | Met? |
|-----------|------|
| explanations_only_reference_completed_inputs | true |
| no_fabricated_reasons | true |
| no_null_field_references | true |
| no_cross_marketplace_terminology | true |
| no_misleading_explanation_content | true |

## Product rule — listing facts vs preference matches

Preference-fit explanations ("Why this could work for you") must only claim a seeker preference match when the seeker explicitly provided that preference. Neutral listing facts may appear elsewhere on the detail page, but must not be framed as "matches your preference" when the field is blank / any / no_preference.

**Code observation:** Explanation generators gate preference-framed copy on explicit seeker prefs: SL room requires non-empty roomFromSeeker; bathroom requires non-empty/non-no_preference bath token; household uses occupantMatch/studentMatch only (not roommateTypeMatch alone); availability requires SeekerMoveInWindow.fromSession != null; lifestyle requires explicit food preference. Matching blank-compat (roomCompatible/bathroomCompatible/flexible timing) is unchanged. IP property-type/bedrooms already gated; commute on hasCommuteIntent.

**Classification guidance:** Preference-framed copy from a null/blank seeker field = blocker or high. Soft listing-only facts framed neutrally = out of scope for this card (not emitted by these APIs today).

## PART 1 — Selected partial seekers

| seeker_id | marketplace | blank_fields | synthetic |
|-----------|-------------|--------------|-----------|
| `SL-EDGE-05` | shared_living | room_preference, property_type_preference, transit_preference, commute_destination, bathroom_preference | NO |
| `SL-STU-10` | shared_living | property_type_preference, transit_preference, commute_destination, bathroom_preference | NO |
| `SL-PRO-08` | shared_living | property_type_preference, commute_destination, bathroom_preference, transit_preference_specific | NO |
| `SL-EDGE-05-BLANK-MOVE` | shared_living | room_preference, desired_move_date, transit_preference, commute_destination, bathroom_preference, property_type_preference | YES |
| `SL-EDGE-05-BLANK-HH` | shared_living | room_preference, household_preference, transit_preference, commute_destination, bathroom_preference | YES |
| `IP-EDGE-03` | independent_places | property_type_preference, bedroom_layout, room_preference, commute_destination, bathroom_preference | NO |
| `IP-EDGE-07` | independent_places | property_type_preference, bedroom_layout, commute_destination, bathroom_preference | NO |
| `IP-EDGE-05` | independent_places | transit_preference, commute_destination, bedroom_layout, bathroom_preference | NO |
| `IP-CPL-02` | independent_places | commute_destination, bedroom_layout, bathroom_preference | NO |
| `IP-EDGE-03-BLANK-MOVE` | independent_places | property_type_preference, bedroom_layout, desired_move_date, commute_destination, bathroom_preference | YES |
| `IP-EDGE-03-BLANK-HH` | independent_places | property_type_preference, bedroom_layout, household_preference, commute_destination, bathroom_preference | YES |

## Invalid references by type

| type | count |
|------|-------|
| `location_copy_vs_city_match` | 30 |

## Blockers

_None_

## High

_None_

## Medium

Count: 30 (location copy vs city-match soft warnings). See JSON for full rows.

## Marketplace terminology violations

_None_

## Per-seeker top listings + explanations

### `SL-EDGE-05`

- **Scenario:** Edge · broad criteria · many matches
- **Blank fields:** room_preference, property_type_preference, transit_preference, commute_destination, bathroom_preference
- **Matches returned:** 40 (showing top 5)
- **Invalid refs:** 0

#### `dub-share-29` — Master room · Ballyfermot Luas
- 💼 Professional household
- 📅 Available when you plan to move
- 💰 Within your budget

#### `dub-share-34` — Private room · Chapelizod Luas
- 💼 Professional household
- 📅 Available when you plan to move
- 💰 Within your budget

#### `dub-share-06` — Lime House · €800/person · multi-slot
- 💼 Professional household
- 📅 Available when you plan to move
- 💰 Within your budget

#### `dub-share-07` — Ensuite double · female · Two Oaks D16
- 💼 Professional household
- 📅 Available when you plan to move
- 💰 Within your budget

#### `dub-share-12` — Glass Bottle · sea view · Dublin 4
- 💼 Professional household
- 📅 Available when you plan to move
- 💰 Within your budget

### `SL-STU-10`

- **Scenario:** Student · shared · medium budget · no transit preference · broad
- **Blank fields:** property_type_preference, transit_preference, commute_destination, bathroom_preference
- **Matches returned:** 16 (showing top 5)
- **Invalid refs:** 0

#### `dub-share-11` — Budget bed · Dundalk · all-in
- 🛏️ Shared room matches your preference
- 👩‍🎓 Student household
- 📅 Available when you plan to move

#### `dub-share-18` — Student-friendly · Cherrywood Luas
- 🛏️ Shared room matches your preference
- 👩‍🎓 Student household
- 📅 Available when you plan to move

#### `dub-share-30` — Bed in shared room · Finglas
- 🛏️ Shared room matches your preference
- 👩‍🎓 Student household
- 📅 Available when you plan to move

#### `dub-share-01` — Female only · shared bed · Cherrywood
- 🛏️ Shared room matches your preference
- 📅 Available when you plan to move

#### `dub-share-04` — All bills in · male · Dundalk DKIT
- 🛏️ Shared room matches your preference
- 👩‍🎓 Student household
- 💰 Within your budget

### `SL-PRO-08`

- **Scenario:** Professional · shared · medium budget · hybrid · no parking
- **Blank fields:** property_type_preference, commute_destination, bathroom_preference, transit_preference_specific
- **Matches returned:** 32 (showing top 5)
- **Invalid refs:** 0

#### `dub-share-01` — Female only · shared bed · Cherrywood
- 🛏️ Shared room matches your preference
- 💼 Professional household
- 📅 Available when you plan to move

#### `dub-share-05` — Bed space · female · Dublin 4 Luas
- 🛏️ Shared room matches your preference
- 💼 Professional household
- 📅 Available when you plan to move

#### `dub-share-06` — Lime House · €800/person · multi-slot
- 🛏️ Shared room matches your preference
- 💼 Professional household
- 📅 Available when you plan to move

#### `dub-share-15` — Immediate · male · Rathmines area
- 🛏️ Shared room matches your preference
- 💼 Professional household
- 📅 Available when you plan to move

#### `dub-share-02` — Male only · €700/person · Rialto
- 💼 Professional household
- 📅 Available when you plan to move
- 💰 Within your budget

### `SL-EDGE-05-BLANK-MOVE`

- **Scenario:** Synthetic · SL-EDGE-05 with desired_move_date stripped
- **Blank fields:** room_preference, desired_move_date, transit_preference, commute_destination, bathroom_preference, property_type_preference
- **Matches returned:** 40 (showing top 5)
- **Invalid refs:** 0

#### `dub-share-29` — Master room · Ballyfermot Luas
- 💼 Professional household
- 💰 Within your budget

#### `dub-share-19` — Ensuite · Rathmines · Luas commuter
- 💼 Professional household
- 💰 Within your budget

#### `dub-share-34` — Private room · Chapelizod Luas
- 💼 Professional household
- 💰 Within your budget

#### `dub-share-05` — Bed space · female · Dublin 4 Luas
- 💼 Professional household
- 💰 Within your budget

#### `dub-share-06` — Lime House · €800/person · multi-slot
- 💼 Professional household
- 💰 Within your budget

### `SL-EDGE-05-BLANK-HH`

- **Scenario:** Synthetic · SL-EDGE-05 with occupant_type omitted
- **Blank fields:** room_preference, household_preference, transit_preference, commute_destination, bathroom_preference
- **Matches returned:** 40 (showing top 5)
- **Invalid refs:** 0

#### `dub-share-02` — Male only · €700/person · Rialto
- 📅 Available when you plan to move
- 💰 Within your budget

#### `dub-share-06` — Lime House · €800/person · multi-slot
- 📅 Available when you plan to move
- 💰 Within your budget

#### `dub-share-07` — Ensuite double · female · Two Oaks D16
- 📅 Available when you plan to move
- 💰 Within your budget

#### `dub-share-15` — Immediate · male · Rathmines area
- 📅 Available when you plan to move
- 💰 Within your budget

#### `dub-share-16` — Co-living · Dublin 16 · gym access
- 📅 Available when you plan to move
- 💰 Within your budget

### `IP-EDGE-03`

- **Scenario:** Edge · premium budget · broad · many matches
- **Blank fields:** property_type_preference, bedroom_layout, room_preference, commute_destination, bathroom_preference
- **Matches returned:** 50 (showing top 5)
- **Invalid refs:** 5

#### `dub-rent-44` — 3 bed · Artane family
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-03` — 3 bed house · Dundrum D14
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-48` — 3 bed · Palmerstown house
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-15` — Family 3 bed · Dublin 16
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-19` — 2 bed · Blackrock DART
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

### `IP-EDGE-07`

- **Scenario:** Edge · broad any property · high budget · many matches
- **Blank fields:** property_type_preference, bedroom_layout, commute_destination, bathroom_preference
- **Matches returned:** 50 (showing top 5)
- **Invalid refs:** 5

#### `dub-rent-44` — 3 bed · Artane family
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-03` — 3 bed house · Dundrum D14
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-48` — 3 bed · Palmerstown house
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-15` — Family 3 bed · Dublin 16
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-19` — 2 bed · Blackrock DART
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

### `IP-EDGE-05`

- **Scenario:** Edge · parking above all else · medium budget suburbs
- **Blank fields:** transit_preference, commute_destination, bedroom_layout, bathroom_preference
- **Matches returned:** 39 (showing top 5)
- **Invalid refs:** 5

#### `dub-rent-17` — 1 bed · Cherrywood · new build
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-46` — 1 bed · Sandyford business park
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-37` — Studio · Blanchardstown retail
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-32` — Studio · Raheny commuter
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-24` — 1 bed · Drumcondra DART
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

### `IP-CPL-02`

- **Scenario:** Couple · premium budget · city/southside
- **Blank fields:** commute_destination, bedroom_layout, bathroom_preference
- **Matches returned:** 50 (showing top 5)
- **Invalid refs:** 5

#### `dub-rent-34` — 2 bed · Ballyfermot Luas
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-03` — 3 bed house · Dundrum D14
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-48` — 3 bed · Palmerstown house
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-15` — Family 3 bed · Dublin 16
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-44` — 3 bed · Artane family
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

### `IP-EDGE-03-BLANK-MOVE`

- **Scenario:** Synthetic · IP-EDGE-03 with desired_move_date stripped
- **Blank fields:** property_type_preference, bedroom_layout, desired_move_date, commute_destination, bathroom_preference
- **Matches returned:** 50 (showing top 5)
- **Invalid refs:** 5

#### `dub-rent-44` — 3 bed · Artane family
- 💰 Good value for your budget
- 📍 Matches your preferred area
- 👨‍👩‍👧‍👦 Suitable for your household

#### `dub-rent-03` — 3 bed house · Dundrum D14
- 💰 Good value for your budget
- 📍 Matches your preferred area
- 👨‍👩‍👧‍👦 Suitable for your household

#### `dub-rent-49` — 4 bed · Knocklyon family
- 💰 Good value for your budget
- 📍 Matches your preferred area
- 👨‍👩‍👧‍👦 Suitable for your household

#### `dub-rent-48` — 3 bed · Palmerstown house
- 💰 Good value for your budget
- 📍 Matches your preferred area
- 👨‍👩‍👧‍👦 Suitable for your household

#### `dub-rent-15` — Family 3 bed · Dublin 16
- 💰 Good value for your budget
- 📍 Matches your preferred area
- 👨‍👩‍👧‍👦 Suitable for your household

### `IP-EDGE-03-BLANK-HH`

- **Scenario:** Synthetic · IP-EDGE-03 with occupant_type omitted
- **Blank fields:** property_type_preference, bedroom_layout, household_preference, commute_destination, bathroom_preference
- **Matches returned:** 50 (showing top 5)
- **Invalid refs:** 5

#### `dub-rent-17` — 1 bed · Cherrywood · new build
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-02` — 1 bed · Dublin 4 · sea proximity
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-03` — 3 bed house · Dundrum D14
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-07` — Modern 2 bed · Dublin 16
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

#### `dub-rent-08` — Studio · Grand Canal Dock
- 💰 Good value for your budget
- 📅 Available when you plan to move
- 📍 Matches your preferred area

## Methodology

### Code paths
- `MarketplaceSpace.fromSession`
- `MarketplaceListingPipeline.runWithFilters (tower → rank)`
- `ListingMatchEngine.sharedLivingPreferenceExplanations`
- `ListingMatchEngine.independentPlacePreferenceExplanations`
- `listing_detail_screen._preferenceFitLabels (wrapper)`

### Seeker dataset

Frozen UAT seeker JSON is not checked into the repo. Partial seekers reconstructed from prior UAT chat artifact (66 seekers with uat_validation_points). Blank-move / blank-household variants are synthetic derivatives of UAT rows to cover dimensions absent from the frozen set (all 66 had desired_move_date; all had occupation_type).

### Session key mapping

- **room_preference (SL):** preferred_layout = private_room | shared_room (roomFromSeeker). Omitted when any/blank.
- **property_type (IP):** property_type_preference session key (PropertyTypePreference.fromSession). any → no_preference.
- **move_date:** desired_move_date → earliest_move_in_date (MoveInTimingMigration → move_in_window).
- **commute_blank:** commute_destination_unknown=true; no commute profiles; no maximum_commute_budget_minutes.
- **bathroom_blank:** bathroom_preference omitted

### Limitations

- Frozen UAT JSON not in repo; reconstructed from prior chat artifact.
- No UAT seeker lacked `desired_move_date` or `occupation_type`; BLANK-MOVE / BLANK-HH variants are synthetic.
- Lifestyle high findings assume food="No Preference" is not a positive lifestyle preference (UAT reconstruction default).
- Audit only — production explanation logic unchanged.

