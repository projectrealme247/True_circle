# Marketplace Classification Audit — TrueCircle V1

**Audited at:** 2026-09-01T20:57:04.197053Z

## Verdict

**Success criteria met:** 0 INVALID listings.

| Status | Count |
|--------|------:|
| VALID | 85 |
| REVIEW | 5 |
| INVALID | 0 |
| **Total** | **90** |

## Source

- **Dataset:** SampleListingsDublin (local Dublin marketplace seed)
- **Counts:** 40 Shared Living (`Share`) · 50 Independent Places (`Rent`)
- **Paths:**
  - `lib/data/sample_listings_dublin.dart`
  - `lib/data/sample_listings_dublin_v2.dart`
  - `lib/data/sample_listings_dublin_legacy.dart`
  - `lib/data/sample_listings_dublin_expansion.dart`
  - `lib/data/dublin_listing_builder.dart`
- **Notes:** UAT workbook targets ~50 SL + ~50 IP; checked-in seed is 40 Share + 50 Rent. App home feed bootstraps from this seed via ListingsStorageService (not Firestore). Supabase public.listings was empty at last probe; remote schema drifts from local migrations. Firestore is not used.

## Methodology

Aligned with app tower classification in `ListingData.propertyType` / `MarketplaceSpace` / `MarketplaceListingPipeline`:

1. Canonical marketplace tower = `listing_type` → `type` → `marketplace_category` (`Share` = Shared Living, `Rent` = Independent Places).
2. Feed separation is tower equality only (`Share` vs `Rent`); bleed risk is wrong tower assignment or conflicting copy/fields.
3. Heuristics scan title, description, `room_type`, `bedrooms`, `property_category`, `share_room_kind` for entire-property vs room-share signals, plus studio/annex/self-contained edge cases.
4. **VALID** = clear fit; **REVIEW** = ambiguous edge; **INVALID** = clear wrong marketplace or missing/conflicting critical marketplace tower field.

## INVALID blockers

_None._

## REVIEW items (human judgment)

| listing_id | marketplace | title | review_reason |
|------------|-------------|-------|---------------|
| `dub-rent-08` | independent_places | Studio · Grand Canal Dock | Independent Places edge case: studio/annex/self-contained — confirm exclusive entire unit (VALID if exclusive). |
| `dub-rent-22` | independent_places | Studio · Dublin City Centre | Independent Places edge case: studio/annex/self-contained — confirm exclusive entire unit (VALID if exclusive). |
| `dub-rent-32` | independent_places | Studio · Raheny commuter | Independent Places edge case: studio/annex/self-contained — confirm exclusive entire unit (VALID if exclusive). |
| `dub-rent-37` | independent_places | Studio · Blanchardstown retail | Independent Places edge case: studio/annex/self-contained — confirm exclusive entire unit (VALID if exclusive). |
| `dub-rent-45` | independent_places | Studio · Walkinstown budget | Independent Places edge case: studio/annex/self-contained — confirm exclusive entire unit (VALID if exclusive). |

## Full listing table

| listing_id | title | marketplace | listing_type | property_type | room_type | rent | status | review_reason |
|------------|-------|-------------|--------------|---------------|----------|------|--------|---------------|
| `dub-share-01` | Female only · shared bed · Cherrywood | shared_living | Share | — | Bed in shared room | 625/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-02` | Male only · €700/person · Rialto | shared_living | Share | — | Private room | 700/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-03` | Ensuite · Dundrum · UCD bus | shared_living | Share | — | Ensuite | 1336/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-04` | All bills in · male · Dundalk DKIT | shared_living | Share | — | Bed in shared room | 350/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-05` | Bed space · female · Dublin 4 Luas | shared_living | Share | — | Bed in shared room | 650/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-06` | Lime House · €800/person · multi-slot | shared_living | Share | — | Bed in shared room | 800/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-07` | Ensuite double · female · Two Oaks D16 | shared_living | Share | — | Ensuite | 1050/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-08` | Ensuite for 2 · Lucan · WFH desk | shared_living | Share | — | Ensuite | 1200/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-09` | Private room · veg kitchen · Rialto | shared_living | Share | — | Private room | 780/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-10` | Professional house · Sandyford | shared_living | Share | — | Private room | 920/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-11` | Budget bed · Dundalk · all-in | shared_living | Share | — | Bed in shared room | 380/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-12` | Glass Bottle · sea view · Dublin 4 | shared_living | Share | — | Private room | 950/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-13` | Family-friendly spare room · Lucan | shared_living | Share | — | Private room | 600/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-14` | Twin room · UCD commute · Dundrum | shared_living | Share | — | Bed in shared room | 850/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-15` | Immediate · male · Rathmines area | shared_living | Share | — | Bed in shared room | 720/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-16` | Co-living · Dublin 16 · gym access | shared_living | Share | — | Ensuite | 1100/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-17` | Tech corridor · Grand Canal Dock | shared_living | Share | — | Private room | 1150/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-18` | Student-friendly · Cherrywood Luas | shared_living | Share | — | Bed in shared room | 540/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-19` | Ensuite · Rathmines · Luas commuter | shared_living | Share | — | Ensuite | 880/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-20` | Twin share · Drumcondra DART | shared_living | Share | — | Twin share | 620/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-21` | Master room · Phibsborough bus links | shared_living | Share | — | Master room | 1100/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-22` | Female only · Clontarf DART | shared_living | Share | — | Private room | 750/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-23` | Male only · Stoneybatter Luas | shared_living | Share | — | Private room | 690/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-24` | Portobello room · multi-modal transit | shared_living | Share | — | Ensuite | 980/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-25` | Sound host · Sandyford Luas · professionals | shared_living | Share | — | Private room | 920/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-26` | Private room · Grand Canal Dock | shared_living | Share | — | Private room | 950/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-27` | Ensuite · Raheny DART | shared_living | Share | — | Ensuite | 820/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-28` | Twin share · Terenure | shared_living | Share | — | Twin share | 580/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-29` | Master room · Ballyfermot Luas | shared_living | Share | — | Master room | 1050/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-30` | Bed in shared room · Finglas | shared_living | Share | — | Bed in shared room | 520/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-31` | Private room · Howth coastal | shared_living | Share | — | Private room | 780/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-32` | Ensuite · Blanchardstown multi-modal | shared_living | Share | — | Ensuite | 870/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-33` | Twin share · Coolock students | shared_living | Share | — | Twin share | 600/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-34` | Private room · Chapelizod Luas | shared_living | Share | — | Private room | 720/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-35` | Ensuite · Tallaght Luas | shared_living | Share | — | Ensuite | 840/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-36` | Bed space · Temple Bar bus | shared_living | Share | — | Bed in shared room | 680/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-37` | Private room · Sandymount DART | shared_living | Share | — | Private room | 910/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-38` | Master room · Rathfarnham family | shared_living | Share | — | Master room | 1150/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-39` | Ensuite · Malahide DART | shared_living | Share | — | Ensuite | 890/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-share-40` | Private room · Dalkey village | shared_living | Share | — | Private room | 980/month | **VALID** | Clear Shared Living / room-share listing. |
| `dub-rent-01` | 2 bed apartment · Cherrywood · Luas | independent_places | Rent | apartment | — | 1850/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-02` | 1 bed · Dublin 4 · sea proximity | independent_places | Rent | apartment | — | 2100/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-03` | 3 bed house · Dundrum D14 | independent_places | Rent | house | — | 2800/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-04` | 2 bed · Lucan · commuter belt | independent_places | Rent | apartment | — | 1650/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-05` | 1 bed flat · Rialto D12 | independent_places | Rent | apartment | — | 1400/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-06` | 2 bed · Dundalk · near DKIT | independent_places | Rent | apartment | — | 1200/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-07` | Modern 2 bed · Dublin 16 | independent_places | Rent | apartment | — | 1950/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-08` | Studio · Grand Canal Dock | independent_places | Rent | apartment | — | 1750/month | **REVIEW** | Independent Places edge case: studio/annex/self-contained — confirm exclusive entire unit (VALID if exclusive). |
| `dub-rent-09` | 3 bed semi-D · Cherrywood | independent_places | Rent | apartment | — | 2650/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-10` | 1 bed · Dundrum shopping district | independent_places | Rent | apartment | — | 1550/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-11` | 2 bed cottage · Lucan | independent_places | Rent | house | — | 1700/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-12` | Luxury 2 bed · Glass Bottle | independent_places | Rent | apartment | — | 3200/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-13` | Affordable 1 bed · Rialto | independent_places | Rent | apartment | — | 1250/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-14` | 2 bed · Dundalk town centre | independent_places | Rent | apartment | — | 1100/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-15` | Family 3 bed · Dublin 16 | independent_places | Rent | apartment | — | 2400/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-16` | 2 bed apartment · Dundrum Luas | independent_places | Rent | apartment | — | 2200/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-17` | 1 bed · Cherrywood · new build | independent_places | Rent | apartment | — | 1600/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-18` | Budget 1 bed · Lucan village | independent_places | Rent | apartment | — | 1350/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-19` | 2 bed · Blackrock DART | independent_places | Rent | apartment | — | 2400/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-20` | 1 bed · Portobello canal | independent_places | Rent | apartment | — | 1900/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-21` | 3 bed house · Clontarf | independent_places | Rent | house | — | 2950/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-22` | Studio · Dublin City Centre | independent_places | Rent | apartment | — | 1650/month | **REVIEW** | Independent Places edge case: studio/annex/self-contained — confirm exclusive entire unit (VALID if exclusive). |
| `dub-rent-23` | 2 bed · Stoneybatter Luas | independent_places | Rent | apartment | — | 2100/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-24` | 1 bed · Drumcondra DART | independent_places | Rent | apartment | — | 1750/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-25` | 2 bed · Phibsborough bus corridor | independent_places | Rent | apartment | — | 1800/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-26` | 3 bed · Ranelagh Luas | independent_places | Rent | apartment | — | 3100/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-28` | 2 bed · remote commuter (test low match) | independent_places | Rent | apartment | — | 3400/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-29` | 1 bed · Rathmines student-friendly | independent_places | Rent | apartment | — | 1950/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-30` | 1 bed · Rathmines · Luas · student top pick | independent_places | Rent | apartment | — | 1400/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-27` | Budget 1 bed · Rialto bus | independent_places | Rent | apartment | — | 900/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-31` | 4 bed · Docklands family home | independent_places | Rent | apartment | — | 4200/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-32` | Studio · Raheny commuter | independent_places | Rent | apartment | — | 1350/month | **REVIEW** | Independent Places edge case: studio/annex/self-contained — confirm exclusive entire unit (VALID if exclusive). |
| `dub-rent-33` | 1 bed · Terenure quiet | independent_places | Rent | apartment | — | 1700/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-34` | 2 bed · Ballyfermot Luas | independent_places | Rent | apartment | — | 1850/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-35` | 3 bed · Finglas house | independent_places | Rent | house | — | 2200/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-36` | 4 bed · Howth sea view | independent_places | Rent | apartment | — | 3800/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-37` | Studio · Blanchardstown retail | independent_places | Rent | apartment | — | 1200/month | **REVIEW** | Independent Places edge case: studio/annex/self-contained — confirm exclusive entire unit (VALID if exclusive). |
| `dub-rent-38` | 1 bed · Coolock student pad | independent_places | Rent | apartment | — | 1450/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-39` | 2 bed · Chapelizod riverside | independent_places | Rent | apartment | — | 2000/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-40` | 3 bed · Tallaght family | independent_places | Rent | apartment | — | 2450/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-41` | 4 bed · Dún Laoghaire seafront | independent_places | Rent | house | — | 3600/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-42` | 1 bed · Swords airport corridor | independent_places | Rent | apartment | — | 1550/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-43` | 2 bed · Ballsbridge DART | independent_places | Rent | apartment | — | 2800/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-44` | 3 bed · Artane family | independent_places | Rent | apartment | — | 2300/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-45` | Studio · Walkinstown budget | independent_places | Rent | apartment | — | 1100/month | **REVIEW** | Independent Places edge case: studio/annex/self-contained — confirm exclusive entire unit (VALID if exclusive). |
| `dub-rent-46` | 1 bed · Sandyford business park | independent_places | Rent | apartment | — | 1650/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-47` | 2 bed · Citywest Luas | independent_places | Rent | house | — | 1950/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-48` | 3 bed · Palmerstown house | independent_places | Rent | house | — | 2100/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-49` | 4 bed · Knocklyon family | independent_places | Rent | apartment | — | 3200/month | **VALID** | Clear Independent Places / entire-property listing. |
| `dub-rent-50` | 1 bed · Smithfield Luas | independent_places | Rent | apartment | — | 1500/month | **VALID** | Clear Independent Places / entire-property listing. |

## Data-access limitations

- Frozen UAT seeker dataset / exact 50+50 listing inventory is **not checked in**.
- This audit uses the **in-repo Dublin seed** (40 SL + 50 IP) that bootstraps localStorage.
- Live `public.listings` in Supabase was probed separately if credentials allowed; seed remains the authoritative demo/UAT feed inventory.
- Firestore is not used by this project.

