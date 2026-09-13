# TRUECIRCLE UAT PHASE 6 — Deep-Link Marketplace Isolation Audit

**Audited at:** 2026-09-01T20:57:07.176016Z

**Locked decision (D1):** D1 — Shared Living and Independent Places strictly separated; no cross-marketplace feeds; no fallback; no marketplace bleed

**Prior audit:** `docs/uat/v1/deep_link_marketplace_isolation_audit.md` — verdict **FAIL**. Prior FAIL on `/listing/:id` with no session-vs-listing guard — re-verified unchanged; Phase 6 expands to full entry-source matrix.

## Executive Summary

| Metric | Count |
|--------|------:|
| Total Scenarios Tested | 11 |
| Passes | 1 |
| Failures | 6 |
| N/A channels | 4 |
| Marketplace Bleed Events | 6 |
| Routing Defects | 6 |
| Fallback Defects | 0 |
| Cross-marketplace rec/related bleeds | 0 |
| Detail-entry guard exists | NO |
| Silent session marketplace switch | NO |
| Production code modified | NO |

### Success criteria

| Criterion | Met |
|-----------|-----|
| `zero_bleed` | NO |
| `zero_cross_marketplace_recs` | YES |
| `zero_routing_defects` | NO |
| `zero_fallback` | YES |
| `detail_entry_guard_exists` | NO |

## Scenario matrix

| Entry Source | Entry URL/Route | Marketplace Expected | Marketplace Returned | Listing Marketplace | Related Listings Marketplace | Recommendation Marketplace | Back Navigation Behaviour | Cross-Marketplace Exposure (Y/N) | Fallback Behaviour Detected (Y/N) | Result (PASS/FAIL) |
|---|---|---|---|---|---|---|---|---|---|---|
| Direct listing URL | `/listing/dub-rent-01` | `shared_living` | `independent_places` | `independent_places` | N/A — no similar/related module on detail | N/A — no listing recommendation rail on detail | IconButton: canPop ? pop : go("/"); Home uses session active_marketplace_space (unchanged by detail) | **Y** | N | **FAIL** |
| Direct listing URL | `/listing/dub-share-01` | `independent_places` | `shared_living` | `shared_living` | N/A — no similar/related module on detail | N/A — no listing recommendation rail on detail | IconButton: canPop ? pop : go("/"); Home uses session active_marketplace_space (unchanged by detail) | **Y** | N | **FAIL** |
| Direct listing URL | `/listing/dub-share-01` | `shared_living` | `shared_living` | `shared_living` | N/A — no similar/related module on detail | N/A — no listing recommendation rail on detail | IconButton: canPop ? pop : go("/"); Home uses session active_marketplace_space (unchanged by detail) | **N** | N | **PASS** |
| Shared listing URL | `/listing/dub-rent-01` | `shared_living` | `independent_places` | `independent_places` | N/A — no similar/related module on detail | N/A — no listing recommendation rail on detail | IconButton: canPop ? pop : go("/"); Home uses session active_marketplace_space (unchanged by detail) | **Y** | N | **FAIL** |
| Shared listing URL | `/listing/dub-share-01` | `independent_places` | `shared_living` | `shared_living` | N/A — no similar/related module on detail | N/A — no listing recommendation rail on detail | IconButton: canPop ? pop : go("/"); Home uses session active_marketplace_space (unchanged by detail) | **Y** | N | **FAIL** |
| Email deep link | `N/A — channel does not emit /listing/:id` | `N/A` | `N/A` | `N/A` | N/A | N/A | N/A — no listing deep-link entry | **N** | N | **N/A** |
| SMS / WhatsApp deep link | `N/A — channel does not emit /listing/:id` | `N/A` | `N/A` | `N/A` | N/A | N/A | N/A — no listing deep-link entry | **N** | N | **N/A** |
| Push notification deep link | `N/A — channel does not emit /listing/:id` | `N/A` | `N/A` | `N/A` | N/A | N/A | N/A — no listing deep-link entry | **N** | N | **N/A** |
| Saved/Favourite listing deep link | `N/A — channel does not emit /listing/:id` | `N/A` | `N/A` | `N/A` | N/A | N/A | N/A — no listing deep-link entry | **N** | N | **N/A** |
| Browser history deep link | `/listing/dub-rent-01` | `shared_living` | `independent_places` | `independent_places` | N/A — no similar/related module on detail | N/A — no listing recommendation rail on detail | pop → prior route OR go("/") → Home uses session active_marketplace_space (session preserved; detail UI had followed listing) | **Y** | N | **FAIL** |
| Search engine indexed deep link | `/listing/dub-rent-01` | `shared_living` | `independent_places` | `independent_places` | N/A — no similar/related module on detail | N/A — no listing recommendation rail on detail | IconButton: canPop ? pop : go("/"); Home uses session active_marketplace_space (unchanged by detail) | **Y** | N | **FAIL** |

## Detailed Findings

### `P6-01a` — SL session opens IP listing URL directly

- **Entry Source:** Direct listing URL
- **Entry URL/Route:** `/listing/dub-rent-01`
- **Coverage:** `harness_executed` (channel: `active`)
- **Marketplace Expected:** `shared_living`
- **Marketplace Returned:** `independent_places`
- **Listing Marketplace:** `independent_places`
- **Related Listings Marketplace:** N/A — no similar/related module on detail
- **Recommendation Marketplace:** N/A — no listing recommendation rail on detail
- **Back Navigation Behaviour:** IconButton: canPop ? pop : go("/"); Home uses session active_marketplace_space (unchanged by detail)
- **Cross-Marketplace Exposure:** Y
- **Fallback Behaviour Detected:** N
- **Result:** **FAIL**
- **Evidence:** GoRoute `/listing/:id` → ListingDetailScreen(listingId); no session vs listing guard.
- **Fail reason:** Detail entry surfaces independent_places listing while session marketplace is shared_living; no guard on ListingDetailScreen / GoRouter /listing/:id
- **Listing id:** `dub-rent-01`
- **Session after entry:** `shared_living`
- **Silent marketplace switch:** false

### `P6-01b` — IP session opens SL listing URL directly

- **Entry Source:** Direct listing URL
- **Entry URL/Route:** `/listing/dub-share-01`
- **Coverage:** `harness_executed` (channel: `active`)
- **Marketplace Expected:** `independent_places`
- **Marketplace Returned:** `shared_living`
- **Listing Marketplace:** `shared_living`
- **Related Listings Marketplace:** N/A — no similar/related module on detail
- **Recommendation Marketplace:** N/A — no listing recommendation rail on detail
- **Back Navigation Behaviour:** IconButton: canPop ? pop : go("/"); Home uses session active_marketplace_space (unchanged by detail)
- **Cross-Marketplace Exposure:** Y
- **Fallback Behaviour Detected:** N
- **Result:** **FAIL**
- **Evidence:** Same unguarded sink as P6-01a (symmetric cross-marketplace).
- **Fail reason:** Detail entry surfaces shared_living listing while session marketplace is independent_places; no guard on ListingDetailScreen / GoRouter /listing/:id
- **Listing id:** `dub-share-01`
- **Session after entry:** `independent_places`
- **Silent marketplace switch:** false

### `P6-01c` — SL session opens SL listing URL (same marketplace control)

- **Entry Source:** Direct listing URL
- **Entry URL/Route:** `/listing/dub-share-01`
- **Coverage:** `harness_executed` (channel: `active`)
- **Marketplace Expected:** `shared_living`
- **Marketplace Returned:** `shared_living`
- **Listing Marketplace:** `shared_living`
- **Related Listings Marketplace:** N/A — no similar/related module on detail
- **Recommendation Marketplace:** N/A — no listing recommendation rail on detail
- **Back Navigation Behaviour:** IconButton: canPop ? pop : go("/"); Home uses session active_marketplace_space (unchanged by detail)
- **Cross-Marketplace Exposure:** N
- **Fallback Behaviour Detected:** N
- **Result:** **PASS**
- **Evidence:** Positive control — same-marketplace deep link must remain allowed.
- **Listing id:** `dub-share-01`
- **Session after entry:** `shared_living`
- **Silent marketplace switch:** false

### `P6-02a` — Shared IP URL opened in SL session

- **Entry Source:** Shared listing URL
- **Entry URL/Route:** `/listing/dub-rent-01`
- **Coverage:** `harness_executed` (channel: `active`)
- **Marketplace Expected:** `shared_living`
- **Marketplace Returned:** `independent_places`
- **Listing Marketplace:** `independent_places`
- **Related Listings Marketplace:** N/A — no similar/related module on detail
- **Recommendation Marketplace:** N/A — no listing recommendation rail on detail
- **Back Navigation Behaviour:** IconButton: canPop ? pop : go("/"); Home uses session active_marketplace_space (unchanged by detail)
- **Cross-Marketplace Exposure:** Y
- **Fallback Behaviour Detected:** N
- **Result:** **FAIL**
- **Evidence:** No dedicated share URL builder; shareable path is still `/listing/:id` (path URL strategy). Clipboard share UX not found.
- **Fail reason:** Detail entry surfaces independent_places listing while session marketplace is shared_living; no guard on ListingDetailScreen / GoRouter /listing/:id
- **Listing id:** `dub-rent-01`
- **Session after entry:** `shared_living`
- **Silent marketplace switch:** false

### `P6-02b` — Shared SL URL opened in IP session

- **Entry Source:** Shared listing URL
- **Entry URL/Route:** `/listing/dub-share-01`
- **Coverage:** `harness_executed` (channel: `active`)
- **Marketplace Expected:** `independent_places`
- **Marketplace Returned:** `shared_living`
- **Listing Marketplace:** `shared_living`
- **Related Listings Marketplace:** N/A — no similar/related module on detail
- **Recommendation Marketplace:** N/A — no listing recommendation rail on detail
- **Back Navigation Behaviour:** IconButton: canPop ? pop : go("/"); Home uses session active_marketplace_space (unchanged by detail)
- **Cross-Marketplace Exposure:** Y
- **Fallback Behaviour Detected:** N
- **Result:** **FAIL**
- **Evidence:** Same unguarded `/listing/:id` sink as P6-02a.
- **Fail reason:** Detail entry surfaces shared_living listing while session marketplace is independent_places; no guard on ListingDetailScreen / GoRouter /listing/:id
- **Listing id:** `dub-share-01`
- **Session after entry:** `independent_places`
- **Silent marketplace switch:** false

### `P6-03` — Transactional / marketing email listing deep link

- **Entry Source:** Email deep link
- **Entry URL/Route:** `N/A — channel does not emit /listing/:id`
- **Coverage:** `code_inferred` (channel: `absent_or_non_listing`)
- **Marketplace Expected:** `N/A`
- **Marketplace Returned:** `N/A`
- **Listing Marketplace:** `N/A`
- **Related Listings Marketplace:** N/A
- **Recommendation Marketplace:** N/A
- **Back Navigation Behaviour:** N/A — no listing deep-link entry
- **Cross-Marketplace Exposure:** N
- **Fallback Behaviour Detected:** N
- **Result:** **N/A**
- **Evidence:** ListingContactService.notifyHost logs host email in debug only; body says "Review applicants in your dashboard" — no `/listing/:id` seeker deep link. No firebase_messaging / transactional email deep-link router found.
- **Residual risk:** If future emails link to `/listing/:id` without a marketplace guard, bleed will match P6-01.

### `P6-04` — SMS or WhatsApp listing deep link into TrueCircle

- **Entry Source:** SMS / WhatsApp deep link
- **Entry URL/Route:** `N/A — channel does not emit /listing/:id`
- **Coverage:** `code_inferred` (channel: `absent_or_non_listing`)
- **Marketplace Expected:** `N/A`
- **Marketplace Returned:** `N/A`
- **Listing Marketplace:** `N/A`
- **Related Listings Marketplace:** N/A
- **Recommendation Marketplace:** N/A
- **Back Navigation Behaviour:** N/A — no listing deep-link entry
- **Cross-Marketplace Exposure:** N
- **Fallback Behaviour Detected:** N
- **Result:** **N/A**
- **Evidence:** ListingContactService.whatsAppHandoffUri builds wa.me contact handoff (host↔applicant viewing chat), not an in-app `/listing/:id` URL. No SMS deep-link handler found.
- **Residual risk:** WhatsApp handoff is off-platform contact only; does not currently enter marketplace feeds. Future TrueCircle SMS/WA listing links would hit the same unguarded sink.

### `P6-05` — Push notification routes to listing detail

- **Entry Source:** Push notification deep link
- **Entry URL/Route:** `N/A — channel does not emit /listing/:id`
- **Coverage:** `code_inferred` (channel: `absent_or_non_listing`)
- **Marketplace Expected:** `N/A`
- **Marketplace Returned:** `N/A`
- **Listing Marketplace:** `N/A`
- **Related Listings Marketplace:** N/A
- **Recommendation Marketplace:** N/A
- **Back Navigation Behaviour:** N/A — no listing deep-link entry
- **Cross-Marketplace Exposure:** N
- **Fallback Behaviour Detected:** N
- **Result:** **N/A**
- **Evidence:** No firebase_messaging / flutter_local_notifications / FCM payload router in pubspec or lib. No push → `/listing/:id` handler.
- **Residual risk:** When push is wired, payload must not open opposite-marketplace `/listing/:id` without a guard.

### `P6-06` — Saved or favourite listing re-opens detail

- **Entry Source:** Saved/Favourite listing deep link
- **Entry URL/Route:** `N/A — channel does not emit /listing/:id`
- **Coverage:** `code_inferred` (channel: `absent_or_non_listing`)
- **Marketplace Expected:** `N/A`
- **Marketplace Returned:** `N/A`
- **Listing Marketplace:** `N/A`
- **Related Listings Marketplace:** N/A
- **Recommendation Marketplace:** N/A
- **Back Navigation Behaviour:** N/A — no listing deep-link entry
- **Cross-Marketplace Exposure:** N
- **Fallback Behaviour Detected:** N
- **Result:** **N/A**
- **Evidence:** No saved-listings / favourites store for marketplace listings. DiscoverScreen.onFavorite is a stub on people cards (no navigation). No favourite → `/listing/:id` path.
- **Residual risk:** Future saved-listing deep links must compare listing tower to session active_marketplace_space before render.

### `P6-07` — Back/forward/refresh or history entry to cross-marketplace listing

- **Entry Source:** Browser history deep link
- **Entry URL/Route:** `/listing/dub-rent-01`
- **Coverage:** `code_inferred_plus_harness` (channel: `active`)
- **Marketplace Expected:** `shared_living`
- **Marketplace Returned:** `independent_places`
- **Listing Marketplace:** `independent_places`
- **Related Listings Marketplace:** N/A — no similar/related module on detail
- **Recommendation Marketplace:** N/A — no listing recommendation rail on detail
- **Back Navigation Behaviour:** pop → prior route OR go("/") → Home uses session active_marketplace_space (session preserved; detail UI had followed listing)
- **Cross-Marketplace Exposure:** Y
- **Fallback Behaviour Detected:** N
- **Result:** **FAIL**
- **Evidence:** usePathUrlStrategy() makes `/listing/:id` history-addressable. Refresh re-runs getById with no marketplace gate. Back to `/` restores HomeScreen session activeSpace (not mutated by detail). Forward re-enters unguarded detail.
- **Fail reason:** Detail entry surfaces independent_places listing while session marketplace is shared_living; no guard on ListingDetailScreen / GoRouter /listing/:id
- **Listing id:** `dub-rent-01`
- **Session after entry:** `shared_living`
- **Silent marketplace switch:** false

### `P6-08` — Indexed /listing/:id cold open (SPA SEO residual)

- **Entry Source:** Search engine indexed deep link
- **Entry URL/Route:** `/listing/dub-rent-01`
- **Coverage:** `code_inferred_plus_harness` (channel: `active`)
- **Marketplace Expected:** `shared_living`
- **Marketplace Returned:** `independent_places`
- **Listing Marketplace:** `independent_places`
- **Related Listings Marketplace:** N/A — no similar/related module on detail
- **Recommendation Marketplace:** N/A — no listing recommendation rail on detail
- **Back Navigation Behaviour:** IconButton: canPop ? pop : go("/"); Home uses session active_marketplace_space (unchanged by detail)
- **Cross-Marketplace Exposure:** Y
- **Fallback Behaviour Detected:** N
- **Result:** **FAIL**
- **Evidence:** No per-listing SEO landing routes or sitemap. web/index.html has generic meta description only. Path URLs remain crawlable in principle; any indexed `/listing/:id` cold-opens the same unguarded detail builder.
- **Fail reason:** Detail entry surfaces independent_places listing while session marketplace is shared_living; no guard on ListingDetailScreen / GoRouter /listing/:id
- **Listing id:** `dub-rent-01`
- **Session after entry:** `shared_living`
- **Silent marketplace switch:** false

## High-risk inspection

| # | Surface | Status | Cross-marketplace rec/related | Impact |
|---|---------|--------|-------------------------------|--------|
| 1 | Similar Listings modules | `not_present` | N | No bleed vector from this surface today. |
| 2 | Recommendation modules | `not_on_listing_detail` | N | No cross-marketplace listing recs on detail entry. |
| 3 | Recently Viewed | `not_present` | N | No bleed vector. |
| 4 | Saved Listings | `not_present` | N | No bleed vector today; residual if wired to unguarded detail. |
| 5 | Search Re-entry | `tower_scoped_on_home` | N | Feed/search isolation intact (D1). Does not mitigate unguarded deep-link detail entry. |
| 6 | SEO Landing Pages | `no_dedicated_seo_landings` | N | Residual: indexed deep links hit same FAIL as direct URL (P6-08). |
| 7 | Email Notifications | `debug_host_notify_only` | N | No current email listing deep-link bleed. |
| 8 | Push Notification Routing | `not_present` | N | No current push bleed; residual when implemented. |
| 9 | User Profile Listing Galleries | `count_only_no_gallery_nav` | N | No seeker profile gallery bleed vector. |
| 10 | Internal Deep-Link Handlers | `unguarded_listing_route` | N | PRIMARY DEFECT — any entry source that resolves to `/listing/:id` can surface opposite marketplace content. |

### 1. Similar Listings modules

- **Coverage:** `code_inferred`
- **Evidence:** No similar/related listings widget or query on ListingDetailScreen / ListingDetailPageLayout.
- **Isolation impact:** No bleed vector from this surface today.

### 2. Recommendation modules

- **Coverage:** `code_inferred`
- **Evidence:** District recommendation ranker/explainer used in seeker onboarding areas, not as a listing-detail recommendation rail. Landlord recommendation chips are applicant-queue triage, not seeker listing recs.
- **Isolation impact:** No cross-marketplace listing recs on detail entry.

### 3. Recently Viewed

- **Coverage:** `code_inferred`
- **Evidence:** No recently-viewed / view-history store or UI for listings.
- **Isolation impact:** No bleed vector.

### 4. Saved Listings

- **Coverage:** `code_inferred`
- **Evidence:** No favourites store for listings; DiscoverScreen favorite stub does not navigate.
- **Isolation impact:** No bleed vector today; residual if wired to unguarded detail.

### 5. Search Re-entry

- **Coverage:** `code_inferred`
- **Evidence:** HomeScreen `_towerListings` filters `ListingData.listingType == _selectedPropertyType` from activeSpace. Search suggestions use _towerListings only.
- **Isolation impact:** Feed/search isolation intact (D1). Does not mitigate unguarded deep-link detail entry.

### 6. SEO Landing Pages

- **Coverage:** `code_inferred`
- **Evidence:** Generic web/index.html meta; no sitemap/per-listing SEO routes. Path `/listing/:id` remains cold-openable if indexed.
- **Isolation impact:** Residual: indexed deep links hit same FAIL as direct URL (P6-08).

### 7. Email Notifications

- **Coverage:** `code_inferred`
- **Evidence:** ListingContactService.notifyHost — no seeker listing deep link URL.
- **Isolation impact:** No current email listing deep-link bleed.

### 8. Push Notification Routing

- **Coverage:** `code_inferred`
- **Evidence:** No FCM / local-notification deep-link router in dependencies.
- **Isolation impact:** No current push bleed; residual when implemented.

### 9. User Profile Listing Galleries

- **Coverage:** `code_inferred`
- **Evidence:** UserProfileScreen loads owned listing count via ListingsStorageService.ownedByCurrentUser; no gallery navigation to `/listing/:id` found.
- **Isolation impact:** No seeker profile gallery bleed vector.

### 10. Internal Deep-Link Handlers

- **Coverage:** `harness_executed_plus_code_inferred`
- **Evidence:** Sole listing deep-link handler: GoRoute path=/listing/:id builds ListingDetailScreen(listingId) with no marketplace compare. redirect handles auth/role aliases only. getById is id-only. Home in-app push passes extra map (already tower-filtered feed). pubspec includes app_links but no AppLinks / uriLinkStream usage in lib/.
- **Isolation impact:** PRIMARY DEFECT — any entry source that resolves to `/listing/:id` can surface opposite marketplace content.

## Defects

### `P6-DEF-01` — No marketplace guard on `/listing/:id` detail entry

- **Severity:** Critical
- **Reproduction Path:** Set session active_marketplace_space=shared_space; open /listing/<independent_places_id> (direct, shared, history, or SEO).
- **Expected:** Block, redirect to matching marketplace, or refuse to render opposite marketplace listing while session is SL (and vice versa).
- **Actual:** Listing loads via getById; UI space derived from listing (_listingSpace); opposite marketplace content shown; session not switched.
- **Marketplace Impact:** D1 navigation bypass — SL seeker can view full IP listing detail (and vice versa) including layout, apply scoring, preference explanations.
- **Related scenarios:** `P6-01a`, `P6-01b`, `P6-02a`, `P6-02b`, `P6-07`, `P6-08`

### `P6-DEF-02` — Listing detail treated as global id-keyed resource

- **Severity:** High
- **Reproduction Path:** Swap only the listing id in `/listing/:id` while keeping session space.
- **Expected:** URL or resolve path carries marketplace dimension, or resolve filters by tower vs session.
- **Actual:** Path has id only; marketplace query params ignored; getById has no tower filter.
- **Marketplace Impact:** Trivial URL manipulation surfaces the other marketplace.
- **Related scenarios:** `P6-01a`, `P6-01b`, `P6-02a`, `P6-02b`, `P6-07`, `P6-08`

### `P6-DEF-03` — Internal deep-link handler lacks session-vs-listing compare

- **Severity:** High
- **Reproduction Path:** Sole listing deep-link handler: GoRoute path=/listing/:id builds ListingDetailScreen(listingId) with no marketplace compare. redirect handles auth/role aliases only. getById is id-only. Home in-app push passes extra map (already tower-filtered feed). pubspec includes app_links but no AppLinks / uriLinkStream usage in lib/.
- **Expected:** GoRouter redirect or ListingDetailScreen gate compares marketplaceContextNotifier.activeSpace to listing tower.
- **Actual:** No compare; builder only passes listingId.
- **Marketplace Impact:** All future channels (email/push/saved) that target `/listing/:id` inherit the bleed until a guard is added.
- **Related scenarios:** `P6-03`, `P6-04`, `P6-05`, `P6-06`

## Guards checklist

| Guard | Present |
|-------|---------|
| `router_redirect_compares_listing_vs_session` | NO |
| `listing_detail_blocks_cross_marketplace` | NO |
| `listing_detail_redirects_cross_marketplace` | NO |
| `listing_detail_warns_cross_marketplace` | NO |
| `getById_filters_by_tower` | NO |
| `url_carries_marketplace_query_param` | NO |
| `detail_derives_ui_space_from_listing` | YES |
| `detail_calls_setActiveSpace` | NO |
| `home_feed_tower_filtered` | YES |
| `search_suggestions_tower_scoped` | YES |

## Methodology

- **Browser automation:** unavailable — static code-path analysis + Dart harness
- **Harness-executed:**
  - MarketplaceSpace session vs listing tower compare (simulated detail gate)
  - SampleListingsDublin id resolution (SL/IP probes)
  - Corpus listing marketplace classification via ListingData.propertyType
- **Code-inferred:**
  - GoRouter redirect / `/listing/:id` builder (app_router.dart)
  - ListingDetailScreen._resolveListing / _listingSpace
  - ListingsStorageService.getById (id-only)
  - HomeScreen tower filter + back navigation session preservation
  - ListingContactService email/WhatsApp (no listing deep links)
  - Absence of push / saved-listings / similar / recently-viewed modules
  - web/index.html SEO meta + path URL strategy crawl residual
- **Files cited:**
  - `lib/router/app_router.dart`
  - `lib/router/app_routes.dart`
  - `lib/screens/listing_detail_screen.dart`
  - `lib/widgets/listing_detail_page_layout.dart`
  - `lib/models/marketplace_space.dart`
  - `lib/services/marketplace_context_notifier.dart`
  - `lib/services/listings_storage_service.dart`
  - `lib/services/listing_contact_service.dart`
  - `lib/utils/listing_data.dart`
  - `lib/screens/home_screen.dart`
  - `lib/screens/discover_screen.dart`
  - `lib/screens/user_profile_screen.dart`
  - `lib/screens/space_gateway_screen.dart`
  - `lib/main.dart`
  - `web/index.html`
  - `pubspec.yaml`

## Final Assessment

**FAIL**

PASS criteria: 0 bleed, 0 cross-marketplace recs, 0 routing defects, 0 fallback — **not met**.

### Phase 6 close recommendation

Can Phase 6 close and move to OA-07 Trust Layer Separation Impact Analysis? **NO**

Cannot close Phase 6: unguarded `/listing/:id` allows cross-marketplace detail content (D1 navigation bypass). Fix detail-entry marketplace guard before OA-07 Trust Layer Separation Impact Analysis.

