# TrueCircle Production Readiness Audit

**Date:** 2026-09-13  
**Branch:** `milestone/phase-1`  
**Method:** Reconstruct backlog from docs/plans/rules (because `docs/master_backlog.md` was **missing**), then verify each item against `lib/`, `supabase/`, `test/`, and config.

**Canonical cleaned backlog:** [`docs/master_backlog_v2.md`](./master_backlog_v2.md)

---

## Source note

`docs/master_backlog.md` does not exist in HEAD or on disk. Inventory was reconstructed from:

- `docs/project-state.md`
- `.cursor/plans/truecircle_todo_revisit_3f6911fb.plan.md`
- `.cursor/plans/truecircle_trust_foundation_00f31777.plan.md`
- `.cursor/rules/trust-simplification-complete.mdc`
- `.cursor/rules/location-workflow-frozen.mdc`
- `docs/uat/v1/*` (trust, matching, marketplace, seed audits)
- `docs/decisions/independent-places-matching-*.md`
- `docs/onboarding-ui-baseline-v1.md`
- `docs/landlord-decision-usability-testing.md`
- `README.md`, `plans/*`

Item IDs (`BL-xxx`) are audit-assigned for traceability.

---

## Files Investigated

### Docs / plans / rules
- `docs/project-state.md`
- `docs/onboarding-ui-baseline-v1.md`
- `docs/landlord-decision-usability-testing.md`
- `docs/uat/v1/trust_register_and_truthfulness.md`
- `docs/uat/v1/phase7_trust_implementation_verification_audit.md`
- `docs/uat/v1/trust_ranking_influence.md`
- `docs/uat/v1/missing_data_listing_audit.md`
- `docs/uat/v1/rent_data_integrity_audit.md`
- `docs/uat/v1/blank_field_explanation_audit.md`
- `docs/uat/v1/explanation_duplication_audit.md`
- `docs/uat/v1/budget_boundary_audit.md`
- `docs/uat/v1/availability_ranking_audit.md`
- `docs/uat/v1/marketplace_classification_audit.md`
- `docs/uat/v1/zero_match_isolation_audit.md`
- `docs/uat/v1/deep_link_marketplace_isolation_audit.md`
- `docs/uat/v1/phase6_deep_link_marketplace_isolation_audit.md`
- `docs/uat/v1/active_mode_routing_audit.md`
- `docs/uat/v1/ranking_tie_stability_audit.md`
- `docs/uat/v1/supply_demand_contract_audit.md`
- `docs/uat/v1/schema_field_mapping_audit.md`
- `docs/decisions/independent-places-matching-pipeline.md`
- `.cursor/plans/truecircle_todo_revisit_3f6911fb.plan.md`
- `.cursor/plans/truecircle_trust_foundation_00f31777.plan.md`
- `.cursor/rules/trust-simplification-complete.mdc`
- `.cursor/rules/location-workflow-frozen.mdc`
- `.cursor/rules/demo-auth-entry.mdc`
- `plans/add-listing-phase-1-baseline.md`
- `plans/onboarding_4_track_qa_checklist.md`
- `README.md`

### Code / config (verification)
- `lib/utils/listing_match_engine.dart`
- `lib/utils/weighted_listing_matcher.dart`
- `lib/utils/full_rental_applicant_scorer.dart`
- `lib/utils/listing_data.dart`
- `lib/utils/marketplace_listing_pipeline.dart`
- `lib/utils/polymorphic_identity.dart`
- `lib/services/trust_service.dart`
- `lib/services/listings_supabase_service.dart`
- `lib/services/listings_storage_service.dart`
- `lib/services/application_conversation_service.dart`
- `lib/services/application_service.dart`
- `lib/services/applicant_stream_payload_builder.dart`
- `lib/services/applicant_dashboard_payload_builder.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/auth_screen.dart`
- `lib/router/app_router.dart`
- `lib/widgets/trust_badge.dart`
- `lib/widgets/listing_creation/listing_creation_form.dart`
- `lib/config/market/dublin_market_config.dart`
- `lib/config/app_env.dart`
- `lib/models/applicant_trust_tier.dart`
- `supabase/migrations/*` (9 files)
- `supabase/functions/enrich-location/`
- `env.dev.json`, `env.staging.json`, `.gitignore`
- `test/` (unit coverage present; no `integration_test/`)

---

# Completed

| ID | Item | Evidence |
|----|------|----------|
| BL-013–018 (D5 ranking) | Trust multipliers, `inCircle` sort, trust match reasons, landlord trustBoost / JL–G–S grouping, Grand/corporate scorer points, profile × listing boost | `listing_match_engine.dart`: `finalScore = compatibilityScore`; no `inCircle` / trust reasons; streams use single `ApplicantTrustTierBlock` by score; scorer income/lease only; `profile_trust_section.dart` removed |
| BL-009 / badge UX | Sole seeker badge ✅ Verified User | `trust_badge.dart` `label = '✅ Verified User'`; Enterprise badge forced off in `polymorphic_identity.dart` |
| — | Auth entry email-first in release | `auth_screen.dart` + `demo-auth-entry.mdc`; QA demo behind `kDebugMode` |
| — | Listings migration SQL + enrich-location **code** | 9 migrations present; `supabase/functions/enrich-location/` implemented |
| — | Supabase listing **write** path | `ListingsSupabaseService.tryInsertListing` / `tryUpdateListing` |
| — | Trust foundation Phases 1–7 (historical) | Plan marks completed; superseded by trust simplification |
| — | Dublin revisit code items 1–7 | Plan completed (migration, save, enrich fn SQL, seeds, detail, tooltips, auth parity) |
| — | Location / proximity workflow | Frozen complete per `location-workflow-frozen.mdc` |
| — | Active Mode tower isolation | `active_mode_routing_audit` PASS; pipeline tower-filters |
| — | Cross-marketplace zero-match injection | Not present |
| — | Blank-field explanation gates (core) | Preference APIs gate empty room/bath/move-in/etc. |
| — | Incomplete listing render resilience | Missing-data audit: sections hide safely |
| — | Seed rent integrity (monthly EUR) | 0 INVALID in rent audit |
| — | Marketplace classification INVALID=0 | Classification audit |
| — | Dublin Buy tower hidden at launch | `enabledTowers => ['Rent', 'Share']` |
| BL-020–022, badge honesty (UI) | JL/G/S / Enterprise seeker claims removed from product UI | Verified User only; host stamps suppressed on cards |

---

# Partially Complete

| ID | Item | Evidence | Remaining |
|----|------|----------|-----------|
| BL-001–002 | enrich-location + trigger | Function + SQL in repo; remote deploy / `app.settings` not verified | `db push`, deploy function, set Postgres settings, E2E prove `proximity_data` |
| BL-007–008 | Publish accountability | Wizard validation + accountability confirm; `published_at` stamp | No draft/published lifecycle; no host-verify publish gate |
| BL-007 contact gates | Student/pro contact permission | `TrustService.meetsContactVerification` exists | Broader than product rule (pre-arrival / light_trust / JIT letter unlock); tighten |
| BL-008 leftovers | TrustStage storage leftovers | Ranking cleaned; enum/DB `trust_tier` / mock seeds remain | Optional schema/UI cleanup |
| BL-011 messaging | Application conversations | Full UI; SharedPreferences local store | Server-backed apps + messages + realtime |
| BL-024 | Mocks off in production | Debug QA gated; `env.dev.json` still has mocks true; staging env empty | Release env with mocks off; restore `.gitignore` |
| BL-027 | LinkedIn honesty | OIDC present; free-text company/title | Copy audit; don’t claim employer verified |
| BL-040 | Availability ranking | Soft timing works binary | Optional calendar-proximity grading |
| BL-012 / BL-050 | Recommendations | Some district recommendation code exists | Onboarding “Recommended Areas” product surface still incomplete vs baseline intent |
| BL-061 | Buy/Sell | Code paths exist; Dublin disabled | Keep non-launch unless product reopens |
| BL-063 | Docs vs trust model | Code simplified; `project-state.md` / README still describe trust multipliers | Refresh docs |

---

# Open Critical Issues

| ID | Item | Evidence | Remaining work |
|----|------|----------|----------------|
| BL-003 | Home feed never loads remote listings | `home_screen._loadListingsFromStorage` → `ListingsStorageService.load()` only; Supabase service is write-only | Authenticated fetch + merge into home |
| BL-031 | Deep-link marketplace guard missing | `app_router.dart` `/listing/:id` → `ListingDetailScreen(listingId:)` with no session↔tower check | Guard/redirect before render |
| — | Applications + messaging local-only | `ApplicationConversationService` uses SharedPreferences `circlekey_application_conversations` | Persist to Supabase; sync across devices |
| — | Dual publish paths / feed gap | Local storage publish vs Supabase insert; feed won’t show remote-only publishes | Unify publish → remote + local; feed reads remote |

---

# Open High Priority Issues

| ID | Item | Status note |
|----|------|-------------|
| BL-005–006 | Current Resident Verified / Resident Owner Verified | Not started (preferred next product work) |
| BL-007–008 | Draft vs Published + publish gating | Not started as lifecycle |
| BL-004 | E2E smoke publish → proximity → card/detail | No `integration_test/`; pending ops |
| BL-023 | Persist uni/LinkedIn to `user_trust_profiles` + expiry | No client writes found |
| BL-026 | JIT path-only letter → contact unlock | Still sets `employment_letter_verified` |
| BL-034 | Zero-match isolation FAIL | Soft prefs + 1.25× budget still return edge matches |
| BL-035 | Explanation duplication FAIL | Templated preference reasons |
| BL-036 | Budget 1.25× vs strict UAT | Intentional in field alignment; UAT FAIL until product resolves |
| BL-025 | Invite “vouch” / local invite store | Server invites or remove vouch language |
| — | Empty `env.staging.json` (0 bytes) | Staging web build blocked |
| — | Empty `.gitignore` (0 bytes) | Secret-commit risk |

---

# Technical Debt

| ID | Item |
|----|------|
| BL-039 | Ranking tie-breaker (listing id ascending) not implemented |
| BL-037 | Location copy vs city-match soft warnings |
| BL-038 | Further explanation E-gates / seed Phase 2 |
| BL-041 | Frozen V1 supply-demand field contract not checked in |
| BL-042 | Seed gaps: BER / lease / pets / occupants |
| BL-043–044 | Review luxury rent outliers + studio exclusive-unit confirmation |
| BL-045 | `listingPriceAmount` digit-strip week/year misparse risk |
| BL-064 | Frozen UAT seeker JSON not in repo |
| BL-030 | Phone verification unused |
| — | Leftover JL/G/S enum labels / `TrustTierDesign` strings |
| — | Stale UAT trust audits (Aug 2026) vs trust simplification |
| — | Listings RLS `SELECT USING (true)` — no draft visibility control |

---

# Obsolete Items

| ID | Item | Why obsolete |
|----|------|--------------|
| Trust foundation “add TrustMultiplier / In Your Circle ranking” | Superseded by trust simplification — **do not restore** |
| Rewrite JL/Grand/Sound marketing as primary badges | Product UI moved to Verified User only |
| Enterprise Verified seeker badge | Forced off |
| Buy/Sell Dublin launch polish | Tower disabled; not a launch blocker |
| Location / proximity infrastructure reopen | Explicitly frozen complete |
| Community vouch as claim | Claims removed; real reputation is optional future product, not launch |

---

# Duplicates To Remove

| Keep | Drop / merge |
|------|----------------|
| BL-001–004 final sprint (project-state + todo plan) | Same four items repeated in both docs |
| BL-013–018 D5 removals | Repeated across trust_register, phase7, trust_ranking_influence |
| BL-020–027 badge honesty | Repeated across trust_register + phase7 “next wave” |
| BL-031–032 deep-link guard | deep_link audit + phase6 audit |
| BL-005–008 host verify / publish | trust-simplification “prefer next” overlaps Stage 0 publish completeness in IP pipeline |
| BL-012 / BL-050–056 recommendations | location-frozen “recommendations” + onboarding baseline future work |
| BL-046–048 IP V2 matching | Repeated in three independent-places decision docs |

---

# Product Decisions Still Required

1. **Budget hard cap:** Keep intentional `1.25×` and update UAT contracts, or enforce strict `rent ≤ budget`?
2. **Zero-match definition:** Soft preference + budget flex vs hard isolation fixtures?
3. **Pre-arrival × onCampusOnly hard exclude:** Keep as student-track matching, or remove as trust-adjacent (D5-4)?
4. **Student contact unlock:** Align code to “Offer Letter OR University only,” or keep pre-arrival / light_trust / JIT paths?
5. **Explanation duplication:** Accept templated reasons for v1, or require listing-specific tokens?
6. **Ranking id tie-breaker:** Approve adding listing-id ascending breaker?
7. **Host verification scope:** What proofs unlock Current Resident vs Resident Owner, and what gates publish?
8. **Landlord Offer / Due Diligence:** Confirm blocked until ≥3 decision UAT sessions?
9. **IP Phase 2:** When inventory median ≥15, reconsider budget/commute hard exclusion?

---

# Production Blockers

True launch blockers (multi-user Dublin Rent/Share):

1. **Home feed does not sync remote listings** — marketplace is localStorage/seed only for seekers.
2. **Applications + messaging are device-local** — hosts/seekers cannot communicate across devices.
3. **Publish path split** — remote inserts are not reflected in the home feed.
4. **Deep-link `/listing/:id` has no marketplace tower guard** — cross-tower detail leakage risk (UAT Critical).
5. **Ops: migrations + enrich-location not confirmed deployed** with trigger `app.settings`.
6. **Release hygiene:** empty `.gitignore`, empty staging env, mocks must be off in production builds.
7. **Host verification + draft/publish gating** — preferred product gate before open publish (if launch policy requires verified hosts).

Non-blockers for a closed demo: seed quality polish, IP V2 matching fields, Buy/Sell, Offer workflow, landlord UAT (gate for *next* landlord milestone, not necessarily seeker browse demo).

---

## Per-item status index (reconstructed backlog)

| ID | Title | Status |
|----|-------|--------|
| BL-001 | Supabase migrate + deploy enrich-location | PARTIAL |
| BL-002 | Postgres app.settings for trigger | OPEN |
| BL-003 | Home feed remote listing sync | OPEN |
| BL-004 | E2E smoke publish → proximity → UI | OPEN |
| BL-005 | Current Resident Verified | OPEN |
| BL-006 | Resident Owner Verified | OPEN |
| BL-007 | Draft vs Published listings | OPEN |
| BL-008 | Publish gating | PARTIAL |
| BL-009 | Seeker cards polish | PARTIAL / ongoing |
| BL-010 | Listing details product work | PARTIAL / ongoing |
| BL-011 | Matching product work | PARTIAL / ongoing |
| BL-012 | Recommendations product work | PARTIAL |
| BL-013–018 | D5 trust ranking removals | COMPLETED |
| BL-019 | Pre-arrival onCampusOnly exclude | OPEN (decision) |
| BL-020–022 | Badge honesty UI | COMPLETED / OBSOLETE |
| BL-023 | Persist trust to user_trust_profiles | OPEN |
| BL-024 | Disable mocks in production | PARTIAL |
| BL-025 | Server invites / remove vouch | OPEN |
| BL-026 | JIT letter server validation | OPEN |
| BL-027 | LinkedIn employer claim clarity | PARTIAL |
| BL-028 | Real community reputation | OBSOLETE (claims) / deferred product |
| BL-029 | Trust expiry + revocation APIs | OPEN |
| BL-030 | Phone verification | OBSOLETE / dormant |
| BL-031 | Marketplace guard on `/listing/:id` | OPEN |
| BL-032 | Marketplace in URL / getById filter | OPEN |
| BL-033 | Guard future push/saved/email links | OPEN (when wired) |
| BL-034 | Zero-match isolation | OPEN |
| BL-035 | Explanation duplication | OPEN |
| BL-036 | Budget 1.25× contract | OPEN (decision) / intentional code |
| BL-037 | Location copy vs city match | OPEN |
| BL-038 | Explanation E-gates pre-work | PARTIAL |
| BL-039 | Ranking listing-id tie-breaker | OPEN |
| BL-040 | Availability ranking refinement | PARTIAL |
| BL-041 | Frozen supply-demand contract doc | OPEN |
| BL-042 | Seed completeness gaps | OPEN |
| BL-043 | Review outlier rents | OPEN (review) |
| BL-044 | Confirm studio exclusive units | OPEN (review) |
| BL-045 | Rent parser frequency hardening | OPEN |
| BL-046–048 | IP V2 matching fields | OPEN (deferred V2) |
| BL-049 | IP Phase 2 hard-exclude review | CANNOT VERIFY |
| BL-050–056 | Onboarding recommendation futures | OPEN / deferred |
| BL-057 | Landlord decision UAT sessions | OPEN |
| BL-058–059 | Offer / Due Diligence workflows | OPEN (blocked on UAT) |
| BL-060 | Landlord dashboard polish | PARTIAL / active |
| BL-061 | Buy/Sell maturity | PARTIAL / non-launch Dublin |
| BL-062 | Pets/smoking soft warning UI | OPEN (deferred) |
| BL-063 | Docs trust-model drift | OPEN |
| BL-064 | Check in UAT seeker fixtures | OPEN |
