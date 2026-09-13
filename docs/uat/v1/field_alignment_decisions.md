# TrueCircle Field Alignment Decision Review

**Sources (allowed only):**  
`docs/uat/v1/schema_field_mapping_audit.md` (+ `.json` for exact lists),  
`docs/uat/v1/implementation_file_inventory.md` (scope confirmation).  
No wider repo search. No other UAT reports. No code changes. No product redesign.

**Scope:** All **11 seeker-only** and **11 listing-only** row groups from Parts 3–4 of the schema field mapping audit (22 orphan groups).  
Cross-cutting explanation-gate decisions from audit Part 7 are recorded where they must precede explanation fixes / seed updates / Phase 2 re-run — those are mostly *bidirectional* fields, not orphans.

**Decision codes:**  
- **A** Remain seeker-only  
- **B** Remain listing-only  
- **C** Have a counterpart added  
- **D** Be removed from matching  
- **E** Be removed from explanations (or gated so blank/vacuous claims cannot emit)

---

## Master orphan field table

| Field | Marketplace | Current Usage | Explanation Risk | Required Decision |
| --- | --- | --- | --- | --- |
| company / job_title / linkedin_* | Both | Display / trust completeness only (M NO, R NO, E NO) | None | **A** — profile/trust UI; no listing comparison |
| full_name / email | Both | Identity / completeness only (M NO, R NO, E NO) | None | **A** — identity; not a match signal |
| completenessPercent / needsOnboarding | Both | Gate meta: blocks ranking/explanations when onboarding needed (M YES, R YES, E YES) | Low | **A** — intentional seeker meta-gate; not a listing attribute |
| furnishing_preference | Independent Places | Passport/enum capture; no match-engine comparison (M NO, R NO, E NO). Listing `furnishing` exists as display-only | None | **A** — remain seeker-only for freeze; do **not** add matching/explanation wiring (not C) |
| bathroom_preference (IP path) | Independent Places | Stored on seeker; unused by IP scoring/explanations (M NO, R NO, E NO). SL path is bidirectional and separate | None (IP) | **A** — remain unused seeker-only on IP; do not add IP bath matching for freeze |
| gender_preference (IP path) | Independent Places | Explicitly stripped from Rent hard filters (M NO, R NO, E NO). SL gender is bidirectional | None (IP) | **A** — remain seeker-only / inert on Rent by design |
| accepted_district_recommendations | Both | Documented unused by ranking until wired (M NO*, R NO, E NO) | None | **A** — leave unwired for freeze; not required for explanation/seed/Phase 2 |
| pitch_narrative / bio / about_me / personal_introduction | Both | Application copy only (`ApplicantFieldKeys`) (M NO, R NO, E NO) | None | **A** — application narrative; no listing twin |
| affordability_multiplier / verificationTrack | Both | Applicant payload / trust UI (M NO, R NO, E NO for feed explanations) | None | **A** — applicant/trust envelope; not feed preference fields |
| dual_commute_priority | Both | Seeker-side commute weighting knob (not a listing field) | None | **A** — seeker ranking knob; counterpart would be wrong model |
| guarantor_status / has_hap_voucher / co_applicants / net_monthly_income | Independent Places | Landlord-side `FullRentalApplicantScorer` vs rent; not seeker feed preference explanations | None | **A** — applicant-scoring inputs; remain seeker/applicant-only |
| title / description / images / coverImageUrl / video | Both | Display / keyword blob (M NO, R NO, E NO) | None | **B** — content fields; no seeker preference twin |
| eircode / location_geom | Both | Create infrastructure; matching uses lat/lng/location/areas once resolved (required on create; M NO as eircode itself) | None | **B** — geo create/storage; seekers use areas/commute hubs |
| security_deposit | Independent Places | Display only (M NO, R NO, E NO) | None | **B** — listing commercial display |
| bathrooms (count string) | Independent Places | Display / layout_token only; IP seeker bath unused (M NO, R NO, E NO) | None | **B** — remain listing display; do not pair to IP `bathroom_preference` for freeze |
| current_occupants | Shared Living | Display only (M NO, R NO, E NO) | None | **B** — household display, not seeker preference |
| proximity_data / transit enrichment | Both | Derived enrichment; soft commute/ranking input (M NO, R YES, E NO) | None | **B** — listing-derived enrichment; not seeker-authored |
| hostName / host_verified_badge / host_linkedin_badge | Both | Host display / trust signals without seeker twin (M NO, R NO*, E NO for preference gens) | None | **B** — host identity/trust chrome |
| room_configuration / layout_token | Both | Derived search helpers (seeds/DB) | None | **B** — derived listing helpers; not seeker fields |
| rtb_status / rtb_registered | Independent Places | Deprecated; forbidden on write | None | **B** (+ ignore) — deprecated; do not revive |
| kitchen_usage_timing / kitchen_utility_* | Shared Living | Forbidden keys stripped on write | None | **B** (+ ignore) — forbidden; do not reintroduce |
| metadata overflow keys | Both | Storage envelope | None | **B** — storage only |

\*Per audit Part 3–4 / Part 1 flags as cited above.

**Orphan groups reviewed: 22 (11 seeker-only + 11 listing-only).**  
**Primary orphan distribution:** A × 11, B × 11, C × 0, D × 0, E × 0 on orphan rows.

---

## 1. Shared Living field alignment table

Orphan rows that apply to Shared Living (Both or SL-only). Bidirectional SL fields that need *explanation policy* before Phase 2 are listed in §3 (not orphans).

| Field | Side | Current Usage | Explanation Risk | Decision |
| --- | --- | --- | --- | --- |
| company / job_title / linkedin_* | Seeker | Display/trust | None | **A** |
| full_name / email | Seeker | Identity | None | **A** |
| completenessPercent / needsOnboarding | Seeker | Matching/ranking/explanation gate | Low | **A** |
| accepted_district_recommendations | Seeker | Unwired | None | **A** |
| pitch / bio / about_me / personal_introduction | Seeker | Application copy | None | **A** |
| affordability_multiplier / verificationTrack | Seeker | Applicant/trust UI | None | **A** |
| dual_commute_priority | Seeker | Commute weight knob | None | **A** |
| title / description / images / video | Listing | Display/keywords | None | **B** |
| eircode / location_geom | Listing | Geo create infra | None | **B** |
| current_occupants | Listing | Display | None | **B** |
| proximity_data / transit | Listing | Enrichment → ranking | None | **B** |
| hostName / host badges | Listing | Host display/trust | None | **B** |
| room_configuration / layout_token | Listing | Derived helpers | None | **B** |
| kitchen_usage_timing / kitchen_utility_* | Listing | Forbidden | None | **B** (ignore) |
| metadata | Listing | Storage envelope | None | **B** |

**SL orphan freeze intent:** all above stay one-sided. No counterpart additions (C) for Shared Living orphans before seed / explanation / Phase 2 work.

---

## 2. Independent Places field alignment table

| Field | Side | Current Usage | Explanation Risk | Decision |
| --- | --- | --- | --- | --- |
| company / job_title / linkedin_* | Seeker | Display/trust | None | **A** |
| full_name / email | Seeker | Identity | None | **A** |
| completenessPercent / needsOnboarding | Seeker | Gate meta | Low | **A** |
| furnishing_preference | Seeker | Passport only; listing `furnishing` display-only, no match link | None | **A** (not C) |
| bathroom_preference (IP) | Seeker | Unused on IP path | None | **A** (not C) |
| gender_preference (IP) | Seeker | Stripped from Rent hard filters | None | **A** |
| accepted_district_recommendations | Seeker | Unwired | None | **A** |
| pitch / bio / about_me / personal_introduction | Seeker | Application copy | None | **A** |
| affordability_multiplier / verificationTrack | Seeker | Applicant/trust UI | None | **A** |
| dual_commute_priority | Seeker | Commute weight knob | None | **A** |
| guarantor / HAP / co_applicants / net_monthly_income | Seeker (applicant) | Landlord `FullRentalApplicantScorer` | None | **A** |
| title / description / images / video | Listing | Display/keywords | None | **B** |
| eircode / location_geom | Listing | Geo create infra | None | **B** |
| security_deposit | Listing | Display | None | **B** |
| bathrooms (count) | Listing | Display/layout_token | None | **B** (do not wire to IP bath pref) |
| proximity_data / transit | Listing | Enrichment → ranking | None | **B** |
| hostName / host badges | Listing | Host display/trust | None | **B** |
| room_configuration / layout_token | Listing | Derived helpers | None | **B** |
| rtb_status / rtb_registered | Listing | Deprecated / forbidden write | None | **B** (ignore) |
| metadata | Listing | Storage envelope | None | **B** |

**IP orphan freeze intent:** keep furnishing and IP bathroom preference as seeker-captured but match-inert; keep listing bathrooms/furnishing/security_deposit as display. Do not introduce new bidirectional matching for these before Phase 2.

---

## 3. Fields that must be aligned before explanation fixes

These are **not** orphan counterpart gaps. They are audit Part 5–7 / Phase 2 failure-mode fields that already have (or assert) seeker↔listing relationships. Policy must be decided **before** explanation engine fixes, seed updates that assert preference copy, and Phase 2 re-run.

| Field / signal | Marketplace | Issue (audit) | Required pre-fix decision |
| --- | --- | --- | --- |
| preferred_layout (room tokens) | Shared Living | Empty seeker → `roomCompatible` true → preference claim | **E** (gate): empty/`no_preference` = no preference explanation claim; matching may still treat empty as compatible |
| bathroom_preference | Shared Living | Empty/`no_preference` → `bathroomCompatible` true → bath claim | **E** (gate): same blank-compat policy for explanations |
| shareRoomMatch copy (listing room label) | Shared Living | Copy asserts seeker preference under vacuous compatibility | **E** (gate): tied to room blank policy |
| move_in_window (+ listing available_from / flexibility) | Both | Null seeker window + listing date → `flexible` earns score → “Available when you plan to move” | **E** (gate): require non-empty seeker `move_in_window` before availability preference copy |
| occupant_type / household (via `roommateTypeMatch`) | Shared Living | Household copy can fire without seeker occupant | **E** (gate): require `occupantMatch` or `studentMatch`, not `roommateTypeMatch` alone |
| food_preference / lifestyle_flags | Shared Living | Empty seeker food + listing flags → lifestyleCompatible → lifestyle copy | **E** (gate): require non-empty seeker food (or explicit lifestyle intent) |
| property_type_preference ↔ property_category/sub_type | Independent Places | Explanation-only asymmetry (M NO, R NO, E YES) | Document **remain explanation-only** (not C into scoring); safe if generators skip null/`no_preference` |
| Seed completeness (room / bath / move-in / occupant) | Both (fixtures) | Blank seeds amplify Phase 2 false preference claims | Seed policy: non-empty when asserting preference claims; blanks only to assert *absence* of claims after E gates |

**Also freeze (do not reopen for this remediation):** budget 1.25× hard-cap; keep language/food out of preference generators unless product reopens that copy.

**Orphan fields that do *not* block explanation fixes:** all 22 orphan groups in the master table (A/B remain). No C required on orphans before explanation work.

---

## 4. Fields that are safe to ignore

Safe to ignore for seed preference-claim remediation, explanation-engine blank-claim fixes, and Phase 2 re-run (no alignment action required):

**Seeker-only**
- company / job_title / linkedin_*
- full_name / email
- accepted_district_recommendations
- pitch_narrative / bio / about_me / personal_introduction
- affordability_multiplier / verificationTrack
- dual_commute_priority
- furnishing_preference (IP) — remain inert
- bathroom_preference (IP path) — remain inert
- gender_preference (IP path) — remain inert
- guarantor_status / has_hap_voucher / co_applicants / net_monthly_income

**Listing-only**
- title / description / images / coverImageUrl / video
- eircode / location_geom (as preference counterpart; keep create validation as-is)
- security_deposit
- bathrooms (IP count string)
- current_occupants
- proximity_data / transit enrichment (as seeker twin; ranking enrichment stays)
- hostName / host_verified_badge / host_linkedin_badge
- room_configuration / layout_token
- rtb_status / rtb_registered
- kitchen_usage_timing / kitchen_utility_*
- metadata overflow keys

**Meta note:** `completenessPercent` / `needsOnboarding` are not “ignore” for product correctness (they gate matching/explanations) but need **no field-alignment change** before explanation fixes — leave as seeker-only gates (**A**).

---

## 5. Recommended freeze-ready field model

Documentation of **current intended ownership** for freeze (not a redesign). Reflects audit mapping matrix + orphan Parts 3–4.

### Stay seeker-only (A)

- Identity & profile chrome: `full_name`, `email`, `company`, `job_title`, `linkedin_*`
- Application narrative: `pitch_narrative` / `bio` / `about_me` / `personal_introduction`
- Applicant/trust envelope: `affordability_multiplier`, `verificationTrack`
- Onboarding/ranking meta: `completenessPercent`, `needsOnboarding`
- Unwired: `accepted_district_recommendations`
- Commute knob: `dual_commute_priority`
- IP-only inert prefs: `furnishing_preference`, IP `bathroom_preference`, IP `gender_preference`
- IP applicant scoring inputs: `guarantor_status`, `has_hap_voucher`, `co_applicants`, `net_monthly_income`

### Stay listing-only (B)

- Content: `title`, `description`, `images`, `coverImageUrl`, `video`
- Geo create: `eircode`, `location_geom`
- Display: `security_deposit`, IP `bathrooms`, `current_occupants`, `hostName`, host badges
- Derived: `proximity_data` / transit enrichment, `room_configuration` / `layout_token`, `metadata`
- Deprecated/forbidden: `rtb_*`, `kitchen_utility_*` / `kitchen_usage_timing`

### Bidirectional (paired; keep for freeze)

From audit Part 2 — retain as shared match/rank/explain surfaces (subject to **E** gates in §3 where unsafe):

| Pair family | SL | IP |
| --- | --- | --- |
| Budget ↔ price | Yes | Yes |
| Move-in window ↔ available_from / flexibility | Yes | Yes |
| Schedule | Yes | Yes |
| Layout (room vs beds) | Yes (room tokens) | Yes (beds/bhk) |
| Bathroom | Yes | No (IP seeker bath inert) |
| Gender / group composition | Yes (hard) | No (stripped on Rent) |
| Food / kitchen / lifestyle | Yes (incl. explain path) | Soft score / card reasons only |
| Occupant / household | Yes (hard + explain) | Soft + explain |
| Student type | Soft + explain | Soft + explain |
| Language | Score (not pref gens) | Score (not pref gens) |
| City / areas ↔ location | Yes | Yes |
| Commute ↔ coords (+ parking soft) | Rank + explain | Rank + explain |
| Smoking / pets | Hard exclude | Soft penalty |
| Pre-arrival ↔ tenant_track | Hard | Hard |
| Tenure / lease | Filters path | Hard lease filter |
| Trust / circle | Rank + explain | Rank + explain |
| Property type pref ↔ category/sub_type | — | Explanation-only (document asymmetry) |

### Explicit non-goals for this freeze

- **C:** Do not add new seeker↔listing counterparts for orphan fields.
- **D:** Do not remove orphan or paired fields from matching as part of explanation remediation (blank-compat stays matching-compatible where already true; explanations get **E** gates).
- Do not change budget `1.25×` hard-cap.
- Do not add language/food into preference generators unless product reopens that copy.

---

## Decision rationale (orphan groups)

### Seeker-only → A

All 11 seeker-only groups lack a *matching* listing twin by design (identity, meta gates, application copy, IP inert prefs, applicant scorer inputs, or seeker-only knobs). Adding counterparts (**C**) would be redesign. None participate in the unsafe preference-generator paths as orphan fields; IP bath/furnishing/gender are already unused on Rent. **D/E** do not apply to freeze remediation for these orphans.

### Listing-only → B

All 11 listing-only groups are display, geo infrastructure, derived enrichment, host chrome, deprecated/forbidden, or storage. Seekers already express location/commute via areas and hubs, not eircode. **C** is out of scope. Ranking use of `proximity_data` stays listing-derived (**B**).

### Cross-cutting E (paired fields only)

Explanation Risk **High/Critical** in the product sense attaches to Part 6 Phase 2 failure modes on *paired* SL room/bath/timing/household/lifestyle signals — addressed in §3 as **E** gates, not by changing orphan ownership.

---

## Pre-work checklist (seed / explanations / Phase 2)

1. Lock orphan ownership: **A×11 / B×11 / C×0** (this document).  
2. Decide and implement **E** gates for §3 paired fields (room, bath, timing, household, lifestyle).  
3. Document IP `property_type_preference` as explanation-only.  
4. Update seed/demo seekers used for preference UAT per seed policy in §3.  
5. Re-run Phase 2 after (2)–(4).  
6. Do not touch budget 1.25× or orphan schema for this remediation.

---

## Inventory confirmation

- Allowlist: `docs/uat/v1/implementation_file_inventory.md`  
- Field facts: `docs/uat/v1/schema_field_mapping_audit.md` / `.json` Parts 3–7  
- Code: not modified. Implementation files not re-searched beyond audit cites already recorded.
