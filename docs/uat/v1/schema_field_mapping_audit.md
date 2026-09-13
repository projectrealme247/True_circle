# TrueCircle Schema Field Mapping Audit

Source scope: **only** paths listed in `docs/uat/v1/implementation_file_inventory.md`.  
Generated from inventoried `lib/` + `supabase/` implementation files. No redesign.

**Implementation fact (not a bug):** budget hard-cap uses `price <= round(budget × 1.25)` via `WeightedListingMatcher.budgetHardCapRatio = 1.25` (`lib/utils/weighted_listing_matcher.dart`).

---

## Part 1 — Field inventory

Legend for flags:
- **M** = used_in_matching (hard filter / compatibility gate)
- **R** = used_in_ranking (score / preference / sort)
- **E** = used_in_explanations (`independentPlacePreferenceExplanations`, `sharedLivingPreferenceExplanations`, and/or `_combinedReasons`)

Relationship types appear in Part 2.

### 1.1 Shared Living Seeker

| field_name | required_or_optional | M | R | E | notes / cites |
| --- | --- | --- | --- | --- | --- |
| preferred_property_type / preferred_arrangement / active_marketplace_space | required (matching readiness) | YES | YES | NO | Tower selection; `ProfileData.hasListingTypeSelected`, `MarketplaceSpace` |
| seeker_persona / occupant_type | required | YES | YES | YES | Family hard-blocks Share; occupant scoring; household explanations |
| budget_min | required (with max) | YES | YES | NO | Hard cap / stretch with max |
| budget_max | required | YES | YES | YES | Matching + score + “Within your budget” |
| move_in_window | required | YES | YES | YES | `MoveInTimingEngine`; timing score + availability copy |
| commute_profiles / commute_destination_hub_id / maximum_commute_budget_minutes | required (destination) | NO | YES | YES | Soft ranking + IP/SL commute explanation labels |
| detected_city | optional* | YES | YES | YES | Location match flags; *needed for ViewerProfile shell |
| target_search_areas | optional | YES | YES | YES | Area hard filters via `TargetSearchAreas` / weighted matcher |
| bathroom_preference | optional | YES | YES | YES | Token match; blank → compatible (see risks) |
| preferred_layout (room) | optional | YES | YES | YES | SL room token; blank → compatible (see risks) |
| gender_preference / group_composition / gender | optional | YES | YES | NO | Share hard gender filter + tokens; not in preference-explanation generators |
| food_preference | optional | YES | YES | YES | Diet/lifestyle score; SL lifestyle explanation path |
| mother_tongue / spoken_languages | optional | YES | YES | NO | Language score; `_combinedReasons` language lines (card reasons), not SL preference generator |
| smoking_ok | optional | YES | YES | NO | Share hard exclude vs listing no-smoking |
| household_has_pets / has_pets | optional | YES | YES | NO | Share hard exclude vs no-pets |
| drinking_ok | optional | YES | YES | NO | Soft lifestyle conflict with veg + drinking |
| schedule_type | optional | YES | YES | NO | Timing/lifestyle fraction |
| student_type | optional | YES | YES | YES | Student match flags / household copy |
| tenure_preference | optional | YES | YES | NO | Lease filter via `preferred_lease_months` path on filters |
| trust_stage / has_verified_pre_arrival_docs | optional | YES | YES | YES | Trust multiplier; pre-arrival reasons |
| pre_arrival_contact_ready / verified_university_email | optional | YES | YES | NO | Student-track hard conflict |
| earliest_move_in_date | optional (legacy) | YES | YES | YES | Migrated into timing windows |
| company / job_title / linkedin_* | optional | NO | NO | NO | Display / trust completeness |
| family_adults / family_children / children_ages / group_size | optional | YES | YES | NO | Family → Share exclusion |
| completenessPercent / needsOnboarding | derived | YES | YES | YES | Blocks ranking/explanations when onboarding needed |
| full_name / email | optional | NO | NO | NO | Identity / completeness only |

### 1.2 Shared Living Listing

| field_name | required_or_optional | M | R | E | notes / cites |
| --- | --- | --- | --- | --- | --- |
| listing_type / type / marketplace_category | required | YES | YES | YES | Tower = Share |
| price | required (create) | YES | YES | YES | Budget gate + score |
| location / latitude / longitude / eircode | eircode required on create | YES | YES | YES | Area + commute |
| room_type / share_room_kind / room_type_matching / bathroom_type / shared_rooms | room_type required on create | YES | YES | YES | SL room/bath tokens + explanations |
| household_dynamic / occupantType / preferred_tenant_occupant | household_dynamic required | YES | YES | YES | Occupant / household explanations |
| kitchen_culture / hostFoodPreference / foodPreference | kitchen_culture required | YES | YES | YES | Diet + lifestyle |
| languages_spoken | required on create | YES | YES | NO | Language overlap scoring |
| available_from | optional | YES | YES | YES | Timing |
| availability_flexibility | optional | YES | YES | YES | Timing windows |
| bachelorPreference / required_occupant / gender_preference / target_tenant_preference | optional | YES | YES | NO | Gender hard filter / tokens |
| smoking_allowed / smoking_policy / lifestyle_flags | optional | YES | YES | YES | Hard exclude + lifestyle explanation |
| pets_allowed / pets_policy | optional | YES | YES | NO | Hard exclude |
| drinking_allowed | optional | YES | YES | NO | Soft conflict |
| schedule_type | optional | YES | YES | NO | Lifestyle/timing |
| studentType | optional | YES | YES | YES | Student household copy |
| tenant_track_preference | optional | YES | YES | NO | Pre-arrival hard gate |
| hostMotherTongue / hostLanguage / hostCity / hostName | optional | YES | YES | NO | Language/location/circle |
| host_trust_stage | optional | NO | YES | YES | Trust multiplier + reasons |
| title / description / images | title/price required | NO | NO | NO | Display / keyword search |
| proximity_data | optional | NO | YES | NO | Commute enrichment input |
| current_occupants | optional | NO | NO | NO | Display |
| parking_* | optional | NO | YES | NO | Commute scoring parking flag |

### 1.3 Independent Places Seeker

| field_name | required_or_optional | M | R | E | notes / cites |
| --- | --- | --- | --- | --- | --- |
| preferred_property_type / arrangement / active_marketplace_space | required | YES | YES | NO | Tower = Rent |
| seeker_persona / occupant_type | required | NO | YES | YES | Soft ranking only on Rent (`_rentHardFilter` returns false) |
| budget_min / budget_max | required | YES | YES | YES | Cap 1.25×; budget explanations |
| move_in_window | required | YES | YES | YES | Timing soft + explanations |
| commute_* / maximum_commute_budget_minutes | required | NO | YES | YES | Location/commute score + labels |
| preferred_layout (beds) | optional | YES | YES | YES | `PreferredLayoutMatch` / bhkMatch |
| property_type_preference | optional | NO | NO | YES | Explanation-only (`_independentPlacePropertyTypeFits`) |
| furnishing_preference | optional | NO | NO | NO | Passport display; not in match engine |
| bathroom_preference | optional | NO | NO | NO | Enum shared; IP preference generator does not use bath tokens |
| tenure_preference | optional | YES | YES | NO | Lease months filter / metrics |
| food_preference | optional | YES | YES | NO | Soft score / `_combinedReasons` only |
| gender_preference | optional | NO | NO | NO | Explicitly never hard-filtered on Rent |
| smoking_ok / household_has_pets | optional | NO | YES | NO | Soft pet/smoking penalty on Rent |
| detected_city / target_search_areas | optional | YES | YES | YES | Area + location explanations |
| mother_tongue / spoken_languages | optional | YES | YES | NO | Language weight on Rent |
| student_type | optional | NO | YES | YES | Soft + household explanation |
| guarantor_status / income (applicant household) | optional | YES | YES | NO | Landlord-side `FullRentalApplicantScorer` |
| trust / pre-arrival docs | optional | YES | YES | YES | Trust + track conflict |

### 1.4 Independent Places Listing

| field_name | required_or_optional | M | R | E | notes / cites |
| --- | --- | --- | --- | --- | --- |
| listing_type / marketplace_category | required | YES | YES | YES | Tower = Rent |
| price | required | YES | YES | YES | Budget |
| beds_count / bedrooms / bhk | beds_count required on create | YES | YES | YES | Layout match |
| parking_available / parking_type / parking_features | parking_available required | NO | YES | NO | Commute scoring |
| location / lat/lng / eircode | eircode required | YES | YES | YES | Area + commute |
| property_category / property_sub_type | optional | NO | NO | YES | Property-type explanation |
| furnishing | optional | NO | NO | NO | Display / keyword |
| available_from / availability_flexibility | optional | YES | YES | YES | Timing |
| agreement_type / preferred_lease_months | optional | YES | YES | NO | Lease filter |
| occupantType / preferred_tenant_occupant | optional | NO | YES | YES | Soft lifestyle + household explanation |
| studentType | optional | NO | YES | YES | Soft |
| host food / languages | optional | YES | YES | NO | Soft scores |
| pets_policy / smoking | optional | NO | YES | NO | Soft pet/smoking penalty |
| tenant_track_preference | optional | YES | YES | NO | Pre-arrival gate |
| bathrooms | optional | NO | NO | NO | Display / layout_token only |
| security_deposit | optional | NO | NO | NO | Display |
| title / description | title required | NO | NO | NO | Display / keywords |
| host_trust_stage | optional | NO | YES | YES | Trust reasons |

---

## Part 2 — Seeker ↔ listing mapping matrix

Actual pairs from inventoried matching/explanation code.

| seeker_field | seeker_entity | listing_field | listing_entity | relationship_type | M | R | E | cites |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| budget_max (+budget_min) | SL Seeker / IP Seeker | price | SL Listing / IP Listing | direct_match | YES | YES | YES | `listing_match_engine.dart`, `weighted_listing_matcher.dart` |
| move_in_window (+earliest_move_in_date) | both Seekers | available_from + availability_flexibility | both Listings | derived_match | YES | YES | YES | `move_in_timing.dart`, `_MatchFlags` |
| schedule_type | both Seekers | schedule_type | both Listings | direct_match | YES | YES | NO | `_scheduleCompatible` |
| preferred_layout | IP Seeker | bedrooms / bhk / beds_count | IP Listing | derived_match | YES | YES | YES | `preferred_layout_match.dart`, `bhkMatch` |
| preferred_layout | SL Seeker | room_type_matching / share_room_kind / room_type / shared_rooms | SL Listing | derived_match | YES | YES | YES | `shared_living_match_tokens.dart` |
| bathroom_preference | SL Seeker | bathroom_type (+ shared_rooms) | SL Listing | derived_match | YES | YES | YES | `SharedLivingMatchTokens.bathroom*` |
| gender_preference / group_composition | SL Seeker | required_occupant / bachelorPreference / gender_preference | SL Listing | derived_match | YES | YES | NO | tokens + `TowerFilterPolicy.passesSharedLivingHardFilters` |
| food_preference | SL Seeker | hostFoodPreference / kitchen_culture / lifestyle_flags | SL Listing | derived_match | YES | YES | YES | diet score + lifestyle explanation |
| food_preference | IP Seeker | hostFoodPreference / lifestyle | IP Listing | derived_match | YES | YES | NO | score / `_combinedReasons` only |
| occupant_type | SL Seeker | occupantType / household_dynamic | SL Listing | direct_match | YES | YES | YES | `matchesOccupantType` |
| occupant_type | IP Seeker | occupantType | IP Listing | direct_match | NO | YES | YES | soft only on Rent |
| student_type | both Seekers | studentType | both Listings | direct_match | NO* | YES | YES | *not a hard filter |
| mother_tongue / spoken_languages | both Seekers | hostMotherTongue / hostLanguage / languages_spoken | both Listings | derived_match | YES | YES | NO | language score; card reasons |
| detected_city / target_search_areas | both Seekers | location / hostCity | both Listings | derived_match | YES | YES | YES | location + area filters |
| commute_* / max minutes | both Seekers | latitude/longitude (+ parking_available) | both Listings | derived_match | NO | YES | YES | commute scoring |
| smoking_ok | SL Seeker | smoking_allowed / lifestyle_flags(no_smoking) | SL Listing | direct_match | YES | YES | NO | hard exclude |
| smoking_ok | IP Seeker | smoking_allowed / lifestyle_flags | IP Listing | direct_match | NO | YES | NO | soft penalty |
| household_has_pets | SL Seeker | pets_allowed / lifestyle_flags(no_pets) | SL Listing | direct_match | YES | YES | NO | hard exclude |
| household_has_pets | IP Seeker | pets_* | IP Listing | direct_match | NO | YES | NO | soft penalty |
| property_type_preference | IP Seeker | property_category / property_sub_type | IP Listing | display_only† | NO | NO | YES | †explanation-only relationship |
| isPreArrivalSeeker | both Seekers | tenant_track_preference | both Listings | direct_match | YES | YES | NO | `_studentTrackConflict` |
| tenure_preference / preferred_lease_months | IP Seeker (also SL filters) | preferred_lease_months / agreement_type | IP Listing | direct_match | YES | YES | NO | weighted hard lease filter |
| trust_stage + docs | both Seekers | host_trust_stage | both Listings | derived_match | NO | YES | YES | trust multiplier / circle / reasons |
| circle markers (food/lang/city) | both Seekers | host circle fields | both Listings | derived_match | NO | YES | YES | in-circle ranking + reason |

**Mapping pair count (unique seeker↔listing relationships above): 28**

---

## Part 3 — Seeker-only fields

| field | entity | reason |
| --- | --- | --- |
| company / job_title / linkedin_* | both Seekers | Profile/trust display; not compared to listing attributes in match engine |
| full_name / email | both Seekers | Identity |
| completenessPercent / needsOnboarding | both Seekers | Gate meta-fields |
| furnishing_preference | IP Seeker | Captured in enums/passport; no listing comparison in `listing_match_engine.dart` |
| bathroom_preference | IP Seeker | Stored; IP preference explanations do not read bath tokens |
| gender_preference | IP Seeker | Explicitly stripped from Rent hard filters (`tower_filter_policy.dart`) |
| accepted_district_recommendations | both Seekers | Documented unused by ranking until wired (`viewer_profile.dart`) |
| pitch_narrative / bio / about_me / personal_introduction | both Seekers | `ApplicantFieldKeys` application copy only |
| affordability_multiplier / verificationTrack | both Seekers | Applicant payload / trust UI |
| dual_commute_priority | both Seekers | Seeker-side commute weighting knobs (not a listing field) |
| guarantor_status / has_hap_voucher / co_applicants / net_monthly_income | IP Seeker (applicant) | Landlord-side scoring inputs vs rent; not seeker feed explanations |

**Seeker-only count: 11 row groups (expanded unique field keys ≈ 22)**

---

## Part 4 — Listing-only fields

| field | entity | reason |
| --- | --- | --- |
| title / description / images / coverImageUrl / video | both Listings | Display / keyword blob; not preference counterparts |
| eircode / location_geom | both Listings | Geo infrastructure; seekers use areas/commute hubs |
| security_deposit | IP Listing | Display only |
| bathrooms (count string) | IP Listing | Display / layout_token; seeker bath pref unused on IP |
| current_occupants | SL Listing | Display |
| proximity_data / transit enrichment | both Listings | Derived enrichment for commute UI/scoring, not seeker-authored |
| hostName / host_verified_badge / host_linkedin_badge | both Listings | Host display / trust signals without seeker twin |
| room_configuration / layout_token | listing seeds/DB | Derived search helpers |
| rtb_status / rtb_registered | IP Listing (legacy/forbidden write) | Deprecated; forbidden on write |
| kitchen_usage_timing / kitchen_utility_* | forbidden | Explicitly stripped (`ListingCreationFieldKeys.forbiddenKeys`) |
| metadata overflow keys | both | Storage envelope |

**Listing-only count: 11 row groups**

---

## Part 5 — Explanation input audit

Inputs read by preference generators and `_MatchFlags` / related helpers used for explanation decisions.

| field | source entity | counterpart exists | safe_for_explanations | reason |
| --- | --- | --- | --- | --- |
| budgetMax / price | Seeker / Listing | YES | YES | Requires `viewer.budgetMax != null` and `priceFit` |
| preferred_layout / bedrooms|bhk | IP Seeker / IP Listing | YES | YES | Empty layout → `matches:false` (`preferred_layout_match.dart`) |
| move_in_window / available_from / availability_flexibility | Seeker / Listing | YES | **NO** | Null seeker window + listing `available_from` → `TimingMatchQuality.flexible` earns score → “Available when you plan to move” (`move_in_timing.dart` + preference generators) |
| commute profiles / max minutes / listing coords | Seeker / Listing | YES | YES | Requires explicit commute intent checks before commute label |
| detected_city / location | Seeker / Listing | YES | YES | Requires non-empty city for `locationMatch` |
| property_type_preference / property_category|sub_type | IP Seeker / IP Listing | YES | YES | Skips null/`no_preference` |
| occupant_type / listing occupantType | Seeker / Listing | YES | PARTIAL | IP path requires non-empty both sides; SL path can fire via `roommateTypeMatch` without seeker occupant |
| student_type / studentType | Seeker / Listing | YES | YES | Both sides must be non-empty for `studentMatch` |
| preferred_layout (room) / listing room tokens | SL Seeker / SL Listing | YES | **NO** | `roomCompatible` returns true when seeker token empty → room preference claims |
| bathroom_preference / bathroom_type | SL Seeker / SL Listing | YES | **NO** | `bathroomCompatible` returns true for empty/`no_preference` → bath preference claims |
| food_preference / lifestyle_flags | SL Seeker / SL Listing | YES | **NO** | Empty seeker food can still yield `lifestyleCompatible` when listing has flags → lifestyle copy |
| shareRoomMatch label uses listing room only | SL Listing | YES | **NO** | Copy asserts seeker preference even when compatibility is vacuous |
| language / food in `_combinedReasons` | both | YES | YES | Card reasons; preference generators intentionally omit language/food for detail “Why this works” |
| trust / in-circle | both | YES | YES | Meta reasons |

**Explanation inputs counted: 14**  
**Unsafe (safe_for_explanations = NO): 5** (+1 PARTIAL household)

---

## Part 6 — Implementation risks

### 6.1 Explanations without true counterparts / blank-field preference claims (Phase 2 failure class)

Tied to inventoried code only:

1. **Room preference from empty seeker pref (SL)**  
   - `SharedLivingMatchTokens.roomCompatible`: empty seeker → `true` (`shared_living_match_tokens.dart`).  
   - `_MatchFlags.shareRoomMatch` uses that result (`listing_match_engine.dart`).  
   - `sharedLivingPreferenceExplanations` emits “Private/Shared room matches your preference” when `f.shareRoomMatch` without requiring non-empty seeker room token.

2. **Bathroom preference from empty/`no_preference` (SL)**  
   - Same pattern via `bathroomCompatible` + `f.shareBathroomMatch` → “Bathroom setup matches your preference”.

3. **Availability when seeker has no move-in window**  
   - `MoveInTimingEngine.evaluate`: if `seekerWindow == null` but listing has `available_from`, quality becomes `flexible` (earns timing score).  
   - Preference generators require `f.timingMatch && f.timingQuality.earnsTimingScore` → “Available when you plan to move”.

4. **Household via `roommateTypeMatch` without seeker occupant (SL)**  
   - `roommateTypeMatch` can be true from listing bachelor signals alone; explanations gate on `occupantMatch || roommateTypeMatch || studentMatch`.

5. **Lifestyle compatible with empty seeker food (SL)**  
   - `_lifestyleOk` can return true with empty viewer food when listing lifestyle flags present; generator emits lifestyle line when `lifestyleCompatible && !foodMatch && lifestyleFlags.isNotEmpty`.

### 6.2 Matching but absent from preference explanations

| signal | matching/ranking | preference explanations |
| --- | --- | --- |
| gender tokens | YES (Share hard) | NO |
| language overlap | YES (score) | NO (by design in preference generators) |
| food exact match | YES | NO in preference generators (SL uses lifestyle path instead) |
| smoking / pets hard exclude | YES | NO |
| student track conflict | YES (exclude) | NO (early return empty) |
| furnishing_preference | NO match | N/A |
| property_type_preference | NO score | YES (explanation-only asymmetry) |

### 6.3 Mandatory fields that cannot influence matching

| field | entity | note |
| --- | --- | --- |
| eircode | Listing create (both) | Required for create validation; matching uses lat/lng/location/areas once resolved |
| languages_spoken | SL Listing create | Required on create; influences language score, not hard eligibility |
| parking_available | IP Listing create | Required; soft commute only, not hard filter |
| title | Listing create | Required display; keywords only |

Seeker matching-readiness essentials (`ProfileData.isMatchingReady`): listing type, persona, budget, destination, move-in — all *can* influence matching/ranking except that Rent does not hard-filter persona/occupant.

### 6.4 Orphaned / weakly wired fields

- `furnishing_preference` (IP seeker) — no match-engine use  
- `bathroom_preference` on IP seeker path — unused by IP explanations/scoring  
- `accepted_district_recommendations` — unused by ranking  
- Forbidden kitchen utility keys — stripped on write  
- `rtb_*` — deprecated / forbidden write  

### 6.5 Budget 1.25×

Documented intentional: `WeightedListingMatcher.budgetHardCapRatio = 1.25` and share/rent stretch ratios in `listing_match_engine.dart`. Do not treat as a defect.

---

## Part 7 — Recommended decisions (no redesign)

Before updating seed data, fixing explanations, or re-running Phase 2:

1. **Decide blank-compat policy for SL room/bath:** treat empty seeker tokens as “no claim” in *explanations* (even if matching still treats empty as compatible).  
2. **Decide timing explanation gate:** require non-empty seeker `move_in_window` before emitting availability preference copy.  
3. **Decide household explanation gate:** require `occupantMatch` or `studentMatch` (not `roommateTypeMatch` alone) for preference copy.  
4. **Decide lifestyle explanation gate:** require non-empty seeker `food_preference` (or explicit lifestyle intent) before lifestyle preference copy.  
5. **Decide whether `property_type_preference` should remain explanation-only** or stay as-is (document asymmetry).  
6. **Decide seed completeness for Phase 2 fixtures:** ensure demo/seed seekers used in explanation UAT set non-empty room/bath/move-in/occupant when testing preference claims — or keep blanks only to assert *absence* of preference claims after fixes.  
7. **Do not change budget 1.25× hard-cap** as part of explanation/seed remediation.  
8. **Keep language/food out of preference generators** unless product explicitly reopens that copy (current generators document intentional omission).

---

## Inventory read confirmation

- Allowlist source: `docs/uat/v1/implementation_file_inventory.md`  
- Unique inventory paths checked: **75** — **0 missing**  
- Primary evidence files read for this audit: models/enums/field keys, `viewer_profile.dart`, `profile_data.dart`, `listing_data.dart`, `listing_match_engine.dart`, `weighted_listing_matcher.dart`, `tower_filter_policy.dart`, `shared_living_match_tokens.dart`, `preferred_layout_match.dart`, `move_in_timing.dart`, listing draft/payload/validation, `dublin_listing_builder.dart`, commute/marketplace/student-track helpers, migrations for listing columns, demo seed defaults.  
- Remaining inventory paths were existence-verified; content used only where listed above as schema/match/explanation sources. No non-inventory docs were used as schema sources.
