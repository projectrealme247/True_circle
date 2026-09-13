# Deep-Link Marketplace Isolation Audit — TrueCircle V1

**Audited at:** 2026-09-01T20:56:52.546180Z

## Verdict

**Overall: FAIL**

| Criterion | Result |
|-----------|--------|
| Cross-marketplace deep links blocked/redirected | NO |
| Detail-entry marketplace guard exists | NO |
| Silent session marketplace switch on detail | NO |
| Same-marketplace deep link allowed | YES |
| Scenarios PASS / FAIL | 1 / 7 |
| Production code modified | NO |

## Scenario matrix

| scenario_id | marketplace_context | listing_marketplace | behaviour | result |
|-------------|---------------------|---------------------|-----------|--------|
| `DL-01` | `shared_living` | `independent_places` | allowed | **FAIL** |
| `DL-02` | `independent_places` | `shared_living` | allowed | **FAIL** |
| `DL-03a` | `independent_places` | `shared_living` | allowed | **FAIL** |
| `DL-03b` | `shared_living` | `independent_places` | allowed | **FAIL** |
| `DL-04` | `shared_living` | `independent_places` | allowed | **FAIL** |
| `DL-05` | `shared_living` | `independent_places` | allowed | **FAIL** |
| `DL-06` | `shared_living` | `independent_places` | allowed | **FAIL** |
| `DL-07` | `shared_living` | `shared_living` | allowed | **PASS** |

### `DL-01` — SL seeker opens IP listing URL directly

- **marketplace_context:** `shared_living`
- **listing_marketplace:** `independent_places`
- **listing_id:** `dub-rent-01`
- **deep_link_path:** `/listing/dub-rent-01`
- **entry:** `direct_url`
- **coverage:** `harness_executed`
- **behaviour:** allowed
- **blocked / redirected / warning:** false / false / false
- **silent_marketplace_switch:** false
- **surfaces_opposite_marketplace_content:** true
- **ui_space_source:** `listing`
- **session_space_after:** `shared_living`
- **result:** **FAIL**
- **fail_reason:** Detail entry surfaces independent_places listing while session marketplace is shared_living; no guard on ListingDetailScreen / GoRouter /listing/:id

### `DL-02` — IP seeker opens SL listing URL directly

- **marketplace_context:** `independent_places`
- **listing_marketplace:** `shared_living`
- **listing_id:** `dub-share-01`
- **deep_link_path:** `/listing/dub-share-01`
- **entry:** `direct_url`
- **coverage:** `harness_executed`
- **behaviour:** allowed
- **blocked / redirected / warning:** false / false / false
- **silent_marketplace_switch:** false
- **surfaces_opposite_marketplace_content:** true
- **ui_space_source:** `listing`
- **session_space_after:** `independent_places`
- **result:** **FAIL**
- **fail_reason:** Detail entry surfaces shared_living listing while session marketplace is independent_places; no guard on ListingDetailScreen / GoRouter /listing/:id

### `DL-03a` — Shared link: copy SL URL, open in IP context

- **marketplace_context:** `independent_places`
- **listing_marketplace:** `shared_living`
- **listing_id:** `dub-share-01`
- **deep_link_path:** `/listing/dub-share-01`
- **entry:** `shared_link`
- **coverage:** `harness_executed`
- **behaviour:** allowed
- **blocked / redirected / warning:** false / false / false
- **silent_marketplace_switch:** false
- **surfaces_opposite_marketplace_content:** true
- **ui_space_source:** `listing`
- **session_space_after:** `independent_places`
- **result:** **FAIL**
- **fail_reason:** Detail entry surfaces shared_living listing while session marketplace is independent_places; no guard on ListingDetailScreen / GoRouter /listing/:id

### `DL-03b` — Shared link: copy IP URL, open in SL context

- **marketplace_context:** `shared_living`
- **listing_marketplace:** `independent_places`
- **listing_id:** `dub-rent-01`
- **deep_link_path:** `/listing/dub-rent-01`
- **entry:** `shared_link`
- **coverage:** `harness_executed`
- **behaviour:** allowed
- **blocked / redirected / warning:** false / false / false
- **silent_marketplace_switch:** false
- **surfaces_opposite_marketplace_content:** true
- **ui_space_source:** `listing`
- **session_space_after:** `shared_living`
- **result:** **FAIL**
- **fail_reason:** Detail entry surfaces independent_places listing while session marketplace is shared_living; no guard on ListingDetailScreen / GoRouter /listing/:id

### `DL-04` — Browser Back / Forward / Refresh

- **marketplace_context:** `shared_living`
- **listing_marketplace:** `independent_places`
- **listing_id:** `dub-rent-01`
- **deep_link_path:** `/listing/dub-rent-01`
- **entry:** `browser_nav`
- **coverage:** `code_inferred_plus_harness`
- **behaviour:** allowed
- **blocked / redirected / warning:** false / false / false
- **silent_marketplace_switch:** false
- **surfaces_opposite_marketplace_content:** true
- **ui_space_source:** `listing`
- **session_space_after:** `shared_living`
- **result:** **FAIL**
- **fail_reason:** Detail entry surfaces independent_places listing while session marketplace is shared_living; no guard on ListingDetailScreen / GoRouter /listing/:id
- **browser_notes:**
  - **refresh_on_detail:** Re-runs ListingDetailScreen._resolveListing via getById; still no marketplace gate; UI space from listing
  - **back_to_home:** context.pop or context.go("/") → HomeScreen uses marketplaceContextNotifier.activeSpace from session (active_marketplace_space); session not mutated by detail
  - **forward_to_detail:** Same unguarded /listing/:id entry as direct URL
  - **path_url_strategy:** lib/main.dart usePathUrlStrategy() — bookmarkable paths

### `DL-05` — Bookmark entry to listing detail

- **marketplace_context:** `shared_living`
- **listing_marketplace:** `independent_places`
- **listing_id:** `dub-rent-01`
- **deep_link_path:** `/listing/dub-rent-01`
- **entry:** `bookmark`
- **coverage:** `harness_executed`
- **behaviour:** allowed
- **blocked / redirected / warning:** false / false / false
- **silent_marketplace_switch:** false
- **surfaces_opposite_marketplace_content:** true
- **ui_space_source:** `listing`
- **session_space_after:** `shared_living`
- **result:** **FAIL**
- **fail_reason:** Detail entry surfaces independent_places listing while session marketplace is shared_living; no guard on ListingDetailScreen / GoRouter /listing/:id

### `DL-06` — URL manipulation — marketplace param / listing type / listing-id

- **marketplace_context:** `shared_living`
- **listing_marketplace:** `independent_places`
- **listing_id:** `dub-rent-01`
- **deep_link_path:** `/listing/dub-rent-01`
- **entry:** `url_manipulation`
- **coverage:** `code_inferred_plus_harness`
- **behaviour:** allowed
- **blocked / redirected / warning:** false / false / false
- **silent_marketplace_switch:** false
- **surfaces_opposite_marketplace_content:** true
- **ui_space_source:** `listing`
- **session_space_after:** `shared_living`
- **result:** **FAIL**
- **fail_reason:** Detail entry surfaces independent_places listing while session marketplace is shared_living; no guard on ListingDetailScreen / GoRouter /listing/:id
- **manipulation_notes:**
  - **marketplace_query_param:** Not defined on /listing/:id; ?active_marketplace_space= / ?space= ignored by route builder (only path param id used)
  - **listing_type_in_url:** Not present; tower taken from stored listing fields after load
  - **direct_listing_id:** Any known id resolves via getById regardless of session tower — wrong marketplace can be surfaced by swapping id only

### `DL-07` — SL seeker opens SL listing URL (same marketplace)

- **marketplace_context:** `shared_living`
- **listing_marketplace:** `shared_living`
- **listing_id:** `dub-share-01`
- **deep_link_path:** `/listing/dub-share-01`
- **entry:** `direct_url`
- **coverage:** `harness_executed`
- **behaviour:** allowed
- **blocked / redirected / warning:** false / false / false
- **silent_marketplace_switch:** false
- **surfaces_opposite_marketplace_content:** false
- **ui_space_source:** `listing`
- **session_space_after:** `shared_living`
- **result:** **PASS**

## Guards on detail entry

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

### Files cited

- `lib/router/app_router.dart`
- `lib/router/app_routes.dart`
- `lib/screens/listing_detail_screen.dart`
- `lib/widgets/listing_detail_page_layout.dart`
- `lib/models/marketplace_space.dart`
- `lib/services/marketplace_context_notifier.dart`
- `lib/services/listings_storage_service.dart`
- `lib/utils/listing_data.dart`
- `lib/screens/home_screen.dart`
- `lib/main.dart`

## Key findings

1. **No marketplace guard on `/listing/:id`.** `app_router.dart` builds `ListingDetailScreen(listingId: id)` only. `GoRouter.redirect` handles auth/role aliases, not listing tower vs session space.
2. **Detail UI follows the listing, not the session.** `_listingSpace` uses `ListingData.propertyType` → `MarketplaceSpace.fromTowerPropertyType`, so an SL seeker who opens an IP URL sees Independent Places layout, apply scoring, and preference explanations.
3. **Session marketplace is not silently switched.** `setActiveSpace` is not called on detail entry; returning to `/` keeps the prior `active_marketplace_space`. Isolation still fails because opposite-marketplace *content* is shown.
4. **URL has no marketplace dimension.** Path is `/listing/:id` only (`usePathUrlStrategy`). Swapping the id is enough to surface the other marketplace; marketplace query params are ignored.
5. **Feed isolation is unrelated and remains intact** (prior Active Mode / zero-match audits). This failure is **navigation / deep-link entry**.

## Root cause (FAIL)

Listing detail is treated as a global resource keyed only by listing id. There is no compare of `marketplaceContextNotifier.activeSpace` / session `active_marketplace_space` against the resolved listing tower before rendering. Cross-marketplace deep links, shared links, bookmarks, and URL id swaps are therefore **allowed**.

## Methodology

- **Browser automation:** unavailable — static + harness only
- **Code paths:**
  - appRouter GoRoute path=/listing/:id → ListingDetailScreen(listingId) (lib/router/app_router.dart) — no marketplace path/query param; GoRouter.redirect has no listing-tower check
  - ListingDetailScreen._resolveListing: GoRouter.state.extra map OR ListingsStorageService.getById(id) — no active_marketplace_space gate
  - ListingDetailScreen._listingSpace = MarketplaceSpace.fromTowerPropertyType(ListingData.propertyType(listing)) — UI/explanations follow listing
  - ListingDetailPageLayout(space: _listingSpace) — SL vs IP layout from listing
  - MarketplaceContextNotifier.setActiveSpace not called on detail entry — session active_marketplace_space unchanged (no silent switch)
  - Home feed isolation remains tower-filtered; this audit is detail entry only
- **Executed (harness):**
  - MarketplaceSpace.fromSession / fromStorageToken (session context)
  - MarketplaceSpace.fromTowerPropertyType + ListingData.propertyType (listing marketplace)
  - Simulated deep-link entry gate mirroring ListingDetailScreen + app_router behaviour
  - Corpus id resolution via SampleListingsDublin
- **Code-inferred (not browser-automated):**
  - GoRouter browser back/forward/refresh (path URL strategy)
  - Bookmark cold open of /listing/:id
  - Clipboard shared-link UX (no dedicated share URL builder found)
  - HomeScreen return after context.pop / context.go("/")

## Failure conditions checked

- SL context can surface IP listings (or vice versa)
- Silent marketplace switch
- Wrong marketplace content
- Navigation bypasses separation

## Success criteria

Separation intact for deep links, direct URLs, bookmarks, browser nav, refresh — **not met** while detail entry remains unguarded.

