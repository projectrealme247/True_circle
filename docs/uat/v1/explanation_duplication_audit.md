# Explanation Duplication Audit — TrueCircle V1

**Audited at:** 2026-09-01T20:56:56.554673Z

## Verdict

**Overall: FAIL**

| Metric | Value |
|--------|-------|
| Seekers tested | 10 |
| Avg duplicate % | 66.2% |
| Avg near-duplicate % | 71.2% |
| Avg unique explanations | 3.2 |
| Seekers with identical ≥7/10 | 5 |
| Blocker findings | 5 |
| High findings | 4 |
| Medium findings | 4 |

## Near-duplicate definition

Two explanations are near-duplicates when not exact-equal after normalization, but Jaccard similarity of reason-type sets ≥ 0.8. Reason types are category keys (budget, bedrooms, availability, commute, location, property_type, household, room, bathroom, lifestyle) derived from known preference-explanation templates. Exact duplicates: identical after trim + whitespace collapse + emoji/symbol strip.

**Duplicate % formula:** `(total_listings_reviewed - unique_explanations) / total_listings_reviewed * 100`

### Thresholds

- **FAIL** if average `duplicate_percentage` > 70% OR ≥3 seekers with identical explanations on ≥7 listings
- **PASS WITH WARNINGS** if moderate templating (40–70%) but some unique variation
- **PASS** if mostly unique / healthy variation

## PART 1 — Test seekers

| seeker_id | marketplace | intended | observed volume | matches | scenario |
|-----------|-------------|----------|-----------------|---------|----------|
| `SL-DUP-MANY-01` | shared_living | many | many | 40 | Professional · high budget · broad Dublin · private room · ensuite |
| `SL-DUP-MED-02` | shared_living | medium | medium | 19 | Student · medium budget · southside · shared room |
| `SL-DUP-LIM-03` | shared_living | limited | limited | 7 | Professional · tight budget · narrow northside · private |
| `SL-DUP-MED-04` | shared_living | medium | many | 28 | Professional · mid budget · city core · any bathroom · veg |
| `SL-DUP-LIM-05` | shared_living | limited | medium | 9 | Student · low budget · single area · shared · no move date |
| `IP-DUP-MANY-01` | independent_places | many | many | 50 | Couple · premium budget · broad southside · any property |
| `IP-DUP-MED-02` | independent_places | medium | many | 40 | Professional · mid budget · apartment · 1+ bed · commute TCD |
| `IP-DUP-LIM-03` | independent_places | limited | many | 30 | Family · tight budget · house · 3+ bed · outer suburbs |
| `IP-DUP-MED-04` | independent_places | medium | many | 47 | Couple · upper-mid · house preferred · 2+ bed · IFSC commute |
| `IP-DUP-LIM-05` | independent_places | limited | many | 25 | Professional · low-mid · apartment · studio/1 · narrow area |

## PART 3 — Per seeker duplication

| seeker_id | total_listings_reviewed | unique_explanations | duplicate_explanations | duplicate_percentage |
|-----------|-------------------------|---------------------|------------------------|----------------------|
| `SL-DUP-MANY-01` | 10 | 1 | 9 | 90.0% |
| `SL-DUP-MED-02` | 10 | 5 | 5 | 50.0% |
| `SL-DUP-LIM-03` | 7 | 3 | 4 | 57.1% |
| `SL-DUP-MED-04` | 10 | 5 | 5 | 50.0% |
| `SL-DUP-LIM-05` | 9 | 5 | 4 | 44.4% |
| `IP-DUP-MANY-01` | 10 | 3 | 7 | 70.0% |
| `IP-DUP-MED-02` | 10 | 2 | 8 | 80.0% |
| `IP-DUP-LIM-03` | 10 | 2 | 8 | 80.0% |
| `IP-DUP-MED-04` | 10 | 3 | 7 | 70.0% |
| `IP-DUP-LIM-05` | 10 | 3 | 7 | 70.0% |

## PART 4 — Quality review findings

### Blocker

- `SL-DUP-MANY-01` — **identical_explanations_across_many_listings**: Exact same explanation on 10 of 10 reviewed listings (threshold ≥7).
- `IP-DUP-MANY-01` — **identical_explanations_across_many_listings**: Exact same explanation on 8 of 10 reviewed listings (threshold ≥7).
- `IP-DUP-MED-02` — **identical_explanations_across_many_listings**: Exact same explanation on 7 of 10 reviewed listings (threshold ≥7).
- `IP-DUP-LIM-03` — **identical_explanations_across_many_listings**: Exact same explanation on 7 of 10 reviewed listings (threshold ≥7).
- `IP-DUP-MED-04` — **identical_explanations_across_many_listings**: Exact same explanation on 7 of 10 reviewed listings (threshold ≥7).

### High

- `SL-DUP-MANY-01` — **templated_minimal_variation**: Only 1 exact unique explanation(s) and 1 reason-type signature(s) across 10 listings — templates do not differentiate listings.
- `IP-DUP-MED-02` — **templated_minimal_variation**: Only 2 exact unique explanation(s) and 1 reason-type signature(s) across 10 listings — templates do not differentiate listings.
- `IP-DUP-LIM-03` — **templated_minimal_variation**: Only 2 exact unique explanation(s) and 1 reason-type signature(s) across 10 listings — templates do not differentiate listings.
- `IP-DUP-LIM-05` — **high_exact_duplication_cluster**: Exact cluster of 5 / 10 with 70.0% duplicate rate.

### Medium

- `SL-DUP-MANY-01` — **all_explanations_identical**: All 10 reviewed listings share one identical explanation.
- `SL-DUP-MANY-01` — **fails_to_reflect_listing_differences**: 10 distinct listing areas and 9 price strings, but only 1 unique explanation text(s). Preference labels are category templates without listing-specific tokens (area name, rent amount, beds count in copy).
- `IP-DUP-MED-02` — **fails_to_reflect_listing_differences**: 9 distinct listing areas and 7 price strings, but only 2 unique explanation text(s). Preference labels are category templates without listing-specific tokens (area name, rent amount, beds count in copy).
- `IP-DUP-LIM-03` — **fails_to_reflect_listing_differences**: 8 distinct listing areas and 8 price strings, but only 2 unique explanation text(s). Preference labels are category templates without listing-specific tokens (area name, rent amount, beds count in copy).

## Example duplicate explanation pairs

- `SL-DUP-MANY-01`: `dub-share-23` ↔ `dub-share-02` (cluster 10)
  - 🛏️ Private room matches your preference | 🚿 Bathroom setup matches your preference | 💼 Professional household
- `SL-DUP-MED-02`: `dub-share-11` ↔ `dub-share-18` (cluster 4)
  - 🛏️ Shared room matches your preference | 🚿 Bathroom setup matches your preference | 👩‍🎓 Student household
- `SL-DUP-MED-02`: `dub-share-20` ↔ `dub-share-33` (cluster 3)
  - 🚿 Bathroom setup matches your preference | 👩‍🎓 Student household | 📅 Available when you plan to move
- `SL-DUP-LIM-03`: `dub-share-13` ↔ `dub-share-28` (cluster 3)
  - 🛏️ Private room matches your preference | 🚿 Bathroom setup matches your preference | 📅 Available when you plan to move
- `SL-DUP-LIM-03`: `dub-share-04` ↔ `dub-share-11` (cluster 2)
  - 🚿 Bathroom setup matches your preference | 📅 Available when you plan to move | 💰 Within your budget
- `SL-DUP-MED-04`: `dub-share-13` ↔ `dub-share-20` (cluster 4)
  - 🛏️ Private room matches your preference | 📅 Available when you plan to move | 💰 Within your budget
- `SL-DUP-MED-04`: `dub-share-01` ↔ `dub-share-05` (cluster 2)
  - 💼 Professional household | 💰 Within your budget
- `SL-DUP-LIM-05`: `dub-share-20` ↔ `dub-share-28` (cluster 3)
  - 👩‍🎓 Student household

## Worst seeker

`SL-DUP-MANY-01` — 90.0% duplicate (1 unique / 10 reviewed; max exact cluster 10)

## Per-seeker explanation samples

### `SL-DUP-MANY-01`

- **Scenario:** Professional · high budget · broad Dublin · private room · ensuite
- **Matches:** 40 (reviewed top 10)
- **Unique / dup%:** 1 / 90.0%

- `dub-share-23` (Stoneybatter, Dublin 7, 690/month): 🛏️ Private room matches your preference; 🚿 Bathroom setup matches your preference; 💼 Professional household
- `dub-share-02` (Rialto, Dublin 12, 700/month): 🛏️ Private room matches your preference; 🚿 Bathroom setup matches your preference; 💼 Professional household
- `dub-share-40` (Dalkey, Co. Dublin South, 980/month): 🛏️ Private room matches your preference; 🚿 Bathroom setup matches your preference; 💼 Professional household
- `dub-share-26` (Grand Canal Dock, Dublin 2, 950/month): 🛏️ Private room matches your preference; 🚿 Bathroom setup matches your preference; 💼 Professional household
- `dub-share-32` (Blanchardstown, Dublin 15, 870/month): 🛏️ Private room matches your preference; 🚿 Bathroom setup matches your preference; 💼 Professional household
- _… 5 more in JSON_

### `SL-DUP-MED-02`

- **Scenario:** Student · medium budget · southside · shared room
- **Matches:** 19 (reviewed top 10)
- **Unique / dup%:** 5 / 50.0%

- `dub-share-01` (Cherrywood, Dublin 18, 625/month): 🛏️ Shared room matches your preference; 🚿 Bathroom setup matches your preference; 📅 Available when you plan to move
- `dub-share-11` (Dundalk, County Louth, 380/month): 🛏️ Shared room matches your preference; 🚿 Bathroom setup matches your preference; 👩‍🎓 Student household
- `dub-share-18` (Cherrywood, Dublin 18, 540/month): 🛏️ Shared room matches your preference; 🚿 Bathroom setup matches your preference; 👩‍🎓 Student household
- `dub-share-30` (Finglas, Dublin 11, 520/month): 🛏️ Shared room matches your preference; 🚿 Bathroom setup matches your preference; 👩‍🎓 Student household
- `dub-share-04` (Dundalk, County Louth, 350/month): 🛏️ Shared room matches your preference; 🚿 Bathroom setup matches your preference; 👩‍🎓 Student household
- _… 5 more in JSON_

### `SL-DUP-LIM-03`

- **Scenario:** Professional · tight budget · narrow northside · private
- **Matches:** 7 (reviewed top 7)
- **Unique / dup%:** 3 / 57.1%

- `dub-share-04` (Dundalk, County Louth, 350/month): 🚿 Bathroom setup matches your preference; 📅 Available when you plan to move; 💰 Within your budget
- `dub-share-11` (Dundalk, County Louth, 380/month): 🚿 Bathroom setup matches your preference; 📅 Available when you plan to move; 💰 Within your budget
- `dub-share-30` (Finglas, Dublin 11, 520/month): 🚿 Bathroom setup matches your preference; 📅 Available when you plan to move
- `dub-share-13` (Lucan, Dublin, 600/month): 🛏️ Private room matches your preference; 🚿 Bathroom setup matches your preference; 📅 Available when you plan to move
- `dub-share-28` (Terenure, Dublin 6W, 580/month): 🛏️ Private room matches your preference; 🚿 Bathroom setup matches your preference; 📅 Available when you plan to move
- _… 2 more in JSON_

### `SL-DUP-MED-04`

- **Scenario:** Professional · mid budget · city core · any bathroom · veg
- **Matches:** 28 (reviewed top 10)
- **Unique / dup%:** 5 / 50.0%

- `dub-share-01` (Cherrywood, Dublin 18, 625/month): 💼 Professional household; 💰 Within your budget
- `dub-share-05` (Cherrywood, Dublin 18, 650/month): 💼 Professional household; 💰 Within your budget
- `dub-share-02` (Rialto, Dublin 12, 700/month): 🛏️ Private room matches your preference; 💼 Professional household; 📅 Available when you plan to move
- `dub-share-34` (Chapelizod, Dublin 20, 720/month): 🛏️ Private room matches your preference; 💼 Professional household; 📅 Available when you plan to move
- `dub-share-13` (Lucan, Dublin, 600/month): 🛏️ Private room matches your preference; 📅 Available when you plan to move; 💰 Within your budget
- _… 5 more in JSON_

### `SL-DUP-LIM-05`

- **Scenario:** Student · low budget · single area · shared · no move date
- **Matches:** 9 (reviewed top 9)
- **Unique / dup%:** 5 / 44.4%

- `dub-share-04` (Dundalk, County Louth, 350/month): 🛏️ Shared room matches your preference; 👩‍🎓 Student household; 💰 Within your budget
- `dub-share-11` (Dundalk, County Louth, 380/month): 🛏️ Shared room matches your preference; 👩‍🎓 Student household; 💰 Within your budget
- `dub-share-18` (Cherrywood, Dublin 18, 540/month): 🛏️ Shared room matches your preference; 👩‍🎓 Student household
- `dub-share-30` (Finglas, Dublin 11, 520/month): 🛏️ Shared room matches your preference; 👩‍🎓 Student household
- `dub-share-01` (Cherrywood, Dublin 18, 625/month): 🛏️ Shared room matches your preference
- _… 4 more in JSON_

### `IP-DUP-MANY-01`

- **Scenario:** Couple · premium budget · broad southside · any property
- **Matches:** 50 (reviewed top 10)
- **Unique / dup%:** 3 / 70.0%

- `dub-rent-44` (Artane, Dublin 5, 2300/month): 💰 Good value for your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- `dub-rent-03` (Dundrum, Dublin 14, 2800/month): 💰 Good value for your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- `dub-rent-48` (Palmerstown, Dublin 20, 2100/month): 💰 Good value for your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- `dub-rent-15` (Dublin 16, 2400/month): 💰 Good value for your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- `dub-rent-19` (Blackrock, Dublin, 2400/month): 💰 Good value for your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- _… 5 more in JSON_

### `IP-DUP-MED-02`

- **Scenario:** Professional · mid budget · apartment · 1+ bed · commute TCD
- **Matches:** 40 (reviewed top 10)
- **Unique / dup%:** 2 / 80.0%

- `dub-rent-23` (Stoneybatter, Dublin 7, 2100/month): 💰 Within your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- `dub-rent-02` (Dublin 4, 2100/month): 💰 Within your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- `dub-rent-04` (Lucan, Dublin, 1650/month): 💰 Good value for your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- `dub-rent-07` (Dublin 16, 1950/month): 💰 Good value for your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- `dub-rent-16` (Dundrum, Dublin 14, 2200/month): 💰 Within your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- _… 5 more in JSON_

### `IP-DUP-LIM-03`

- **Scenario:** Family · tight budget · house · 3+ bed · outer suburbs
- **Matches:** 30 (reviewed top 10)
- **Unique / dup%:** 2 / 80.0%

- `dub-rent-05` (Rialto, Dublin 12, 1400/month): 💰 Good value for your budget; 📅 Available when you plan to move; 📍 Matches your preferred area
- `dub-rent-10` (Dundrum, Dublin 14, 1550/month): 💰 Within your budget; 📅 Available when you plan to move; 📍 Matches your preferred area
- `dub-rent-13` (Rialto, Dublin 12, 1250/month): 💰 Good value for your budget; 📅 Available when you plan to move; 📍 Matches your preferred area
- `dub-rent-17` (Cherrywood, Dublin 18, 1600/month): 💰 Within your budget; 📅 Available when you plan to move; 📍 Matches your preferred area
- `dub-rent-18` (Lucan, Dublin, 1350/month): 💰 Good value for your budget; 📅 Available when you plan to move; 📍 Matches your preferred area
- _… 5 more in JSON_

### `IP-DUP-MED-04`

- **Scenario:** Couple · upper-mid · house preferred · 2+ bed · IFSC commute
- **Matches:** 47 (reviewed top 10)
- **Unique / dup%:** 3 / 70.0%

- `dub-rent-03` (Dundrum, Dublin 14, 2800/month): 💰 Within your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- `dub-rent-44` (Artane, Dublin 5, 2300/month): 💰 Good value for your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- `dub-rent-48` (Palmerstown, Dublin 20, 2100/month): 💰 Good value for your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- `dub-rent-15` (Dublin 16, 2400/month): 💰 Good value for your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- `dub-rent-19` (Blackrock, Dublin, 2400/month): 💰 Good value for your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- _… 5 more in JSON_

### `IP-DUP-LIM-05`

- **Scenario:** Professional · low-mid · apartment · studio/1 · narrow area
- **Matches:** 25 (reviewed top 10)
- **Unique / dup%:** 3 / 70.0%

- `dub-rent-05` (Rialto, Dublin 12, 1400/month): 💰 Within your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- `dub-rent-13` (Rialto, Dublin 12, 1250/month): 💰 Good value for your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- `dub-rent-18` (Lucan, Dublin, 1350/month): 💰 Good value for your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- `dub-rent-50` (Smithfield, Dublin 7, 1500/month): 💰 Within your budget; 🛏️ Bedrooms match your needs; 📅 Available when you plan to move
- `dub-rent-04` (Lucan, Dublin, 1650/month): 🛏️ Bedrooms match your needs; 📅 Available when you plan to move; 📍 Matches your preferred area
- _… 5 more in JSON_

## Methodology

### Code paths
- `MarketplaceSpace.fromSession`
- `MarketplaceListingPipeline.runWithFilters (tower → rank)`
- `ListingMatchEngine.sharedLivingPreferenceExplanations`
- `ListingMatchEngine.independentPlacePreferenceExplanations`

### Corpus
- SampleListingsDublin: 90 listings (SL 40, IP 50)
- Top N per seeker: 10

### Limitations

- Preference explanations are category templates (max 3 lines); they intentionally omit listing-specific tokens such as rent figures or area names in the copy itself.
- Match-volume tiers are observed from pipeline ranked length; intended tiers may differ when seed supply is sparse for narrow prefs.
- Audit only — production matching/ranking/explanation logic unchanged.
- Location workflow files were not modified.

