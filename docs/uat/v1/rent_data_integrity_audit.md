# Rent Data Integrity Audit — TrueCircle V1

**Audited at:** 2026-09-01T20:57:10.956254Z

## Verdict

**Success criteria met:** YES — 0 INVALID; all rents monthly EUR and matcher-usable.

| Status | Count |
|--------|------:|
| VALID | 88 |
| REVIEW | 2 |
| INVALID | 0 |
| **Total** | **90** |

## Success criteria

| Criterion | Met? |
|-----------|------|
| `zero_invalid` | true |
| `all_rents_monthly_eur` | true |
| `numeric_usable_by_matcher` | true |
| `no_weekly_or_annual_detected` | true |

## Source

- **Dataset:** SampleListingsDublin (local Dublin marketplace seed)
- **Counts:** 40 Shared Living (`Share`) · 50 Independent Places (`Rent`)
- **Paths:**
  - `lib/data/sample_listings_dublin.dart`
  - `lib/data/sample_listings_dublin_v2.dart`
  - `lib/data/sample_listings_dublin_legacy.dart`
  - `lib/data/sample_listings_dublin_expansion.dart`
  - `lib/data/dublin_listing_builder.dart`
- **Notes:** Same corpus as prior UAT audits. App feed bootstraps via ListingsStorageService. Seed stores `price` as e.g. `880/month` (no €); listing creation persists `€{digits}/month`.

## How rent is parsed in code

Listings store rent in a single string field **`price`**. There are no separate `rent_currency` / `rent_frequency` columns on seed rows.

| Concern | Implementation |
|---------|----------------|
| Primary field | `price` |
| Matcher amount | ListingData.listingPriceAmount — strips non-digits from price |
| Display | ListingData.price / priceDisplayLabel (appends /month if missing) |
| Marketplace | ListingData.listingType (Share→shared_living, Rent→independent_places) |
| Absent columns | rent_currency, rent_frequency, monthly_rent, currency |

### Code citations

- `lib/utils/listing_data.dart (price, priceDisplayLabel, listingPriceAmount)`
- `lib/utils/weighted_listing_matcher.dart (uses listingPriceAmount)`
- `lib/utils/listing_search_intent.dart (budget filter via listingPriceAmount)`
- `lib/widgets/listing_creation/listing_creation_form.dart (persists €{digits}/month)`

**Important:** `listingPriceAmount` strips all non-digits and does **not** interpret `/week` or `/year`. A weekly string like `€700/week` would match as `700` monthly — hence weekly/annual formats are **INVALID** for integrity.

## Marketplace rent stats

_From VALID+REVIEW numeric monthly EUR (`matcher_amount`); INVALID excluded._

| Marketplace | Min | Max | Avg | Usable n | Invalid excluded |
|-------------|----:|----:|----:|---------:|-----------------:|
| shared_living | 350 | 1336 | 824.52 | 40 | 0 |
| independent_places | 900 | 4200 | 2059.0 | 50 | 0 |

## Classification rules

- **INVALID:** missing/null/empty/non-numeric/POA/contact-for-price; negative; zero; clear weekly/annual; non-EUR; unusable by `ListingData.listingPriceAmount`.
- **REVIEW:** extreme outliers vs marketplace peers (IQR / >3σ / Dublin sanity); ambiguous format that still parses; thousands separators.
- **VALID:** positive numeric monthly EUR (explicit or Dublin-implied), usable by matching engine.
- Seed prices omit `€` (e.g. `880/month`); creation form writes `€{digits}/month`. Missing symbol alone is **not** REVIEW when `/month` and digits are present (EUR implied for Dublin market).

## INVALID blockers

_None._

## REVIEW items

| listing_id | marketplace | rent_value | review_reason |
|------------|-------------|------------|---------------|
| `dub-rent-31` | independent_places | 4200 | IQR outlier vs peers (fence 275–3675; Q1=1550 Q3=2400). |
| `dub-rent-36` | independent_places | 3800 | IQR outlier vs peers (fence 275–3675; Q1=1550 Q3=2400). |

## Full listing table

| listing_id | marketplace | rent_value | rent_currency | rent_frequency | validation_status | review_reason |
|------------|-------------|------------|---------------|----------------|-------------------|---------------|
| `dub-share-01` | shared_living | 625 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-02` | shared_living | 700 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-03` | shared_living | 1336 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-04` | shared_living | 350 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-05` | shared_living | 650 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-06` | shared_living | 800 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-07` | shared_living | 1050 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-08` | shared_living | 1200 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-09` | shared_living | 780 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-10` | shared_living | 920 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-11` | shared_living | 380 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-12` | shared_living | 950 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-13` | shared_living | 600 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-14` | shared_living | 850 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-15` | shared_living | 720 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-16` | shared_living | 1100 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-17` | shared_living | 1150 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-18` | shared_living | 540 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-19` | shared_living | 880 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-20` | shared_living | 620 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-21` | shared_living | 1100 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-22` | shared_living | 750 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-23` | shared_living | 690 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-24` | shared_living | 980 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-25` | shared_living | 920 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-26` | shared_living | 950 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-27` | shared_living | 820 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-28` | shared_living | 580 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-29` | shared_living | 1050 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-30` | shared_living | 520 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-31` | shared_living | 780 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-32` | shared_living | 870 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-33` | shared_living | 600 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-34` | shared_living | 720 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-35` | shared_living | 840 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-36` | shared_living | 680 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-37` | shared_living | 910 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-38` | shared_living | 1150 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-39` | shared_living | 890 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-share-40` | shared_living | 980 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-01` | independent_places | 1850 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-02` | independent_places | 2100 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-03` | independent_places | 2800 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-04` | independent_places | 1650 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-05` | independent_places | 1400 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-06` | independent_places | 1200 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-07` | independent_places | 1950 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-08` | independent_places | 1750 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-09` | independent_places | 2650 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-10` | independent_places | 1550 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-11` | independent_places | 1700 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-12` | independent_places | 3200 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-13` | independent_places | 1250 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-14` | independent_places | 1100 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-15` | independent_places | 2400 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-16` | independent_places | 2200 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-17` | independent_places | 1600 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-18` | independent_places | 1350 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-19` | independent_places | 2400 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-20` | independent_places | 1900 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-21` | independent_places | 2950 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-22` | independent_places | 1650 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-23` | independent_places | 2100 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-24` | independent_places | 1750 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-25` | independent_places | 1800 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-26` | independent_places | 3100 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-28` | independent_places | 3400 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-29` | independent_places | 1950 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-30` | independent_places | 1400 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-27` | independent_places | 900 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-31` | independent_places | 4200 | EUR | monthly | **REVIEW** | IQR outlier vs peers (fence 275–3675; Q1=1550 Q3=2400). |
| `dub-rent-32` | independent_places | 1350 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-33` | independent_places | 1700 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-34` | independent_places | 1850 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-35` | independent_places | 2200 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-36` | independent_places | 3800 | EUR | monthly | **REVIEW** | IQR outlier vs peers (fence 275–3675; Q1=1550 Q3=2400). |
| `dub-rent-37` | independent_places | 1200 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-38` | independent_places | 1450 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-39` | independent_places | 2000 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-40` | independent_places | 2450 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-41` | independent_places | 3600 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-42` | independent_places | 1550 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-43` | independent_places | 2800 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-44` | independent_places | 2300 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-45` | independent_places | 1100 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-46` | independent_places | 1650 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-47` | independent_places | 1950 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-48` | independent_places | 2100 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-49` | independent_places | 3200 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |
| `dub-rent-50` | independent_places | 1500 | EUR | monthly | **VALID** | Positive numeric monthly EUR; usable by ListingData.listingPriceAmount / matcher. |

