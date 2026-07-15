# TrueCircle — Project State

**Last updated:** 2026-07-13  
**Branch:** `milestone/phase-1`  
**Canonical path:** `docs/project-state.md` (also referenced as `PROJECT_STATE.md` in agent rules)

This document is the **source of truth** for what is frozen, active, and pending. Read it before reasoning, auditing, or implementing. Do not revisit frozen areas unless explicitly requested.

---

## Current focus

**Landlord UX**

Primary surface: `lib/screens/landlord_dashboard_screen.dart`

In scope: host dashboard flows, applicant stream UX, landlord onboarding → publish path, listing management polish.

Out of scope unless explicitly requested: changes to frozen filters, timing, ranking, active mode, or area filter v2.

---

## Current phase

**Phase 1 — Add Listing baseline (Dublin market)**

- **Baseline tag:** `ref/add-listing-phase-1-baseline` (commit `06fe038`)
- **Baseline doc:** `plans/add-listing-phase-1-baseline.md`
- **Cursor rule:** `.cursor/rules/add-listing-baseline.mdc`

Local demo runs without Supabase deploy. Production wiring (remote feed sync, trigger settings) is deferred — see [Pending work](#pending-work).

---

## Key files (current work)

| Domain | File |
|--------|------|
| **Routing / Active Mode** | `lib/services/active_mode_service.dart` |
| **Timing** | `lib/utils/listing_match_engine.dart` |
| **Host / Landlord UX** | `lib/screens/landlord_dashboard_screen.dart` |

Related (read before touching frozen domains):

- Routing navigation: `lib/navigation/navigate_after_identity.dart`
- Filters: `lib/utils/tower_filter_policy.dart`
- Ranking: `lib/utils/weighted_listing_matcher.dart`
- Area Filter v2: `lib/widgets/area_macro_filter_sheet.dart`, `lib/utils/target_search_areas.dart`, `lib/config/market/dublin_macro_areas.dart`

---

## Identity model (frozen — Active Mode)

**One Account → Multiple Capabilities → Active Mode**

| Layer | Meaning | Source of truth |
|-------|---------|-----------------|
| **Account** | Single signed-in user (Supabase or demo session) | `UserSessionStore`, `AuthScreen.currentUserSession` |
| **Capabilities** | What the user *can* do (`canSeek`, `canHost`, `ownedListingCount`) | `ActiveModeService.capabilities` |
| **Active Mode** | Which shell is active right now (`explore` vs `hosting`) | `ActiveModeService.current` |

Rules:

- Onboarding **intent** (`OnboardingUserIntent`) is historical — use `ActiveModeService.capabilities` at runtime.
- Post-auth and cold-start routing go through `navigateAfterIdentity()` → `ActiveModeService.resolveLandingRouteAsync()`.
- Dual-capable users get a mode switch (`ActiveModeSwitch`) and optional stale-mode prompt (90-day threshold).
- Do **not** reintroduce separate seeker/landlord accounts or hard role silos without explicit revisit.

---

## Frozen areas

Changes limited to **defect fixes only** — no redesign or re-architecture.

| Domain | Key file(s) | Notes |
|--------|-------------|-------|
| **Filters** | `lib/utils/tower_filter_policy.dart` | Rent vs Share hard/soft filter split |
| **Timing** | `lib/utils/listing_match_engine.dart`, `lib/models/move_in_timing.dart` | Move-in window scoring and exclusion |
| **Ranking** | `lib/utils/listing_match_engine.dart`, `lib/utils/weighted_listing_matcher.dart` | Trust multiplier × compatibility |
| **Active Mode** | `lib/services/active_mode_service.dart` | Explore vs hosting shell + landing |
| **Area Filter v2** | `lib/widgets/area_macro_filter_sheet.dart`, `lib/utils/target_search_areas.dart`, `lib/config/market/dublin_macro_areas.dart` | Macro-area search and quick filters |

### Filters (detail)

- **Rent (Independent Places):** hard filters = area, budget, layout/bed/bath, dwelling type. Lifestyle/gender/food = ranking only.
- **Share (Shared Living):** hard filters include budget, room type, gender restriction, smoking/pets.

### Ranking (detail)

**Formula:** `Final Score = TrustMultiplier × CompatibilityScore`

| Stage | Multiplier |
|-------|------------|
| 0 Anonymous | 0.4× |
| 1 Casual | 0.7× |
| 2 Social | 0.9× |
| 3 ID Verified | 1.0× |

Also: `lib/services/trust_service.dart`

### Other frozen (unchanged)

- **Add listing Phase 1 baseline** — `lib/widgets/listing_creation/`, `lib/screens/add_listing_screen.dart`
- **Demo-first auth entry** — `lib/screens/auth_screen.dart` (`.cursor/rules/demo-auth-entry.mdc`)
- **Design tokens** — `lib/core/theme/app_theme.dart` (`.cursor/rules/truecircle-design-tokens.mdc`)

---

## Completed foundations

Trust foundation (phases 1–7) — **code-complete** per `.cursor/plans/truecircle_trust_foundation_00f31777.plan.md`:

- Profile gaps wired into `ViewerProfile`
- Trust multiplier in match engine
- Circle markers + feed ordering
- LinkedIn OAuth / social verification
- ID verification gates (publish / contact)
- Landlord preferences + mutual matching
- Tower weight tuning + shared lifestyle fields

Dublin revisit items — **code-complete** per `.cursor/plans/truecircle_todo_revisit_3f6911fb.plan.md`:

- Listings migration SQL, Supabase save + localStorage fallback
- `enrich-location` edge function + INSERT trigger
- Dublin seed infrastructure, listing detail surfaces
- Unified Irish tier tooltips, auth signup commute parity

4-track onboarding QA checklist: `plans/onboarding_4_track_qa_checklist.md`

---

## Pending work

**Final sprint — Supabase deploy & production** (deferrable while on localStorage demo)

| Item | Status |
|------|--------|
| `supabase db push` + deploy `enrich-location` | Pending |
| Postgres `app.settings` for trigger → edge function | Pending |
| Home feed: load/merge remote listings when authenticated | Pending |
| E2E smoke: publish → proximity_data → card + detail | Pending |

Prefer **production behavior** over demo when implementing these items.

---

## Active market

**Dublin** — `lib/config/market/dublin_market_config.dart`

Three marketplace towers: **Rent**, **Share**, **Buy/Sell** (Buy/Sell less mature than Rent/Share).

---

## Key file map

| Area | Files |
|------|-------|
| **Current focus — Host** | `lib/screens/landlord_dashboard_screen.dart`, `lib/widgets/landlord_dashboard/` |
| Routing / Active Mode | `lib/services/active_mode_service.dart`, `lib/navigation/navigate_after_identity.dart` |
| Timing / Ranking | `lib/utils/listing_match_engine.dart`, `lib/utils/weighted_listing_matcher.dart` |
| Filters / Area v2 | `lib/utils/tower_filter_policy.dart`, `lib/widgets/area_macro_filter_sheet.dart` |
| Entry / router | `lib/main.dart`, `lib/router/app_router.dart` |
| Auth | `lib/screens/auth_screen.dart`, `lib/services/demo_auth_service.dart` |
| Home / feed | `lib/screens/home_screen.dart`, `lib/utils/marketplace_listing_pipeline.dart` |
| Listing creation | `lib/screens/add_listing_screen.dart`, `lib/widgets/listing_creation/` |
| Listings storage | `lib/services/listings_storage_service.dart`, `lib/services/listings_supabase_service.dart` |
| Onboarding | `lib/services/profile_onboarding_repository.dart`, `lib/widgets/onboarding/` |
| Supabase | `supabase/migrations/`, `supabase/functions/enrich-location/` |

---

## Agent operating rules

1. New phase → recommend a new thread.
2. Read this file before reasoning.
3. Identify relevant files before broad repository scans.
4. Audit before implementing; smallest viable change.
5. Separate logic issues, UX issues, and technical debt in reviews.
6. Preserve architecture unless a clear defect exists.
7. For implementation: list impacted files → brief approach → implement.

Related cursor rules: `.cursor/rules/demo-auth-entry.mdc`, `.cursor/rules/add-listing-baseline.mdc`, `.cursor/rules/truecircle-design-tokens.mdc`

---

## How to update this document

When a phase completes or an area becomes frozen:

1. Move the section under **Frozen areas** or **Completed foundations**.
2. Update **Current phase** and **Pending work**.
3. Bump **Last updated** date.
4. Commit with prefix `docs:` when the user requests a commit.
