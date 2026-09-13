# TrueCircle Trust Signal Audit (v1)

**Scope constraint:** Sources limited to paths in `docs/uat/v1/implementation_file_inventory.md` only.  
**Code modified:** No.  
**Inventory paths missing on disk:** None.

---

## 1. Trust field inventory

| field_name | available_on | used_in_matching | used_in_ranking | used_in_explanations | used_in_UI_only | weight_or_influence_if_known | cites |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `trust_tier` (Just Landed / Grand / Sound) | seeker; landlord (demo session) | NO | YES (applicant dashboard / stream grouping) | NO | NO | Dashboard: `sortPriority * 5` trust boost; streams grouped Sound → Grand → Just Landed | `applicant_field_keys.dart`; `applicant_dashboard_payload_builder.dart`; `applicant_stream_payload_builder.dart`; seeds |
| `trust_stage` / `TrustStage` (0–3) | seeker; listing (host via `host_trust_stage`) | NO (not a hard exclude in inventored hard filters) | YES | YES (host ID / social labels via `_combinedReasons`) | NO | Multipliers: anonymous 0.4, casual 0.7, socialVerified 0.9, idVerified 1.0; final score = avg(host, seeker) × compatibility | `viewer_profile.dart`; `listing_match_engine.dart`; `listing_data.dart` |
| `identity_trust_tier` | seeker | NO | YES (indirect → `TrustStage`) | NO | NO | Maps `id_verified` / `social_verified` / `casual` → stage; seed values: `Corporate_Ready`, `Education_Verified`, `Casual_Browser` | `viewer_profile.dart`; demo/applicant seeds; `demo_applicants.sql` |
| `employment_verified` | seeker | NO | NO | NO | YES (passport / applicant rows / corporate-doc gate input) | Drives `corporateDocumentVerified` with track/seal; passport “Employment Contract Verified” | `user_trust_profiles.sql`; `applicant_*_payload_builder.dart`; `contextual_passport_snapshot.dart` |
| `financial_verified` | seeker | NO | NO | NO | YES | Open Banking AIS flag; passport “Verifiable budget tier” | `open_banking_trust_fields.sql`; applicant builders; passport |
| `verification_track` | seeker | NO | NO | NO | YES | e.g. `Corporate Track` / `Open Banking Track`; used with seal for corporate-doc verified | schema + stream builder |
| `corporate_verification_seal` | seeker | NO | NO | NO | YES | Non-empty seal + employment → `corporateDocumentVerified` | schema; stream builder; seeds |
| `open_banking_verification_seal` | seeker | NO | NO | NO | YES | Passport budget-tier verified label | `open_banking_trust_fields.sql`; passport |
| `open_banking_verified_at` | seeker (session) | NO | NO | NO | YES | Passport budget-tier verified label | `contextual_passport_snapshot.dart` |
| `profile_completeness_percent` / `completenessPercent` | seeker | NO | NO | NO | YES | Completeness % from profile keys; match scoring explicitly excludes profile-completeness | `applicant_field_keys.dart`; `viewer_profile.dart`; `listing_match_engine.dart` comment |
| `has_verified_pre_arrival_docs` (+ `onboarding_letter_verified`, `employment_contract_verified`, `relocation_letter_verified`) | seeker | NO | YES | YES | NO | Seeker trust multiplier via `TrustTierDesign.effectiveSeekerTrustMultiplier`; reason “Pre-arrival docs verified — Grand trust weighting” | `viewer_profile.dart`; `listing_match_engine.dart`; `ApplicantFieldKeys` |
| `isPreArrivalSeeker` (`pre_arrival_contact_ready` && empty `verified_university_email`) | seeker | YES (student-track hard conflict when listing `onCampusOnly`) | YES | NO | NO | Score × 0.9 when listing prefers `allStudents` | `viewer_profile.dart`; `listing_match_engine.dart` |
| `verified_university_email` / `university_email_verified` | seeker | NO (indirect via pre-arrival derivation) | NO | NO | YES (+ contact-gate copy) | Passport “University Acceptance Verified”; OTP table for Track A | passport; `university_email_otps.sql`; seeds; `listing_detail_screen.dart` |
| `linkedin_verified` / `linkedin_company` / `linkedin_title` | seeker | NO | NO | NO | YES | Contact-gate copy mentions LinkedIn; not read by inventored scorers | `viewer_profile.dart`; `listing_detail_screen.dart` |
| `host_linkedin_badge` | listing / landlord | YES (soft: circle / host stage derivation) | YES (if used as host stage fallback) | YES (if stage resolves to social) | NO | Non-null → `TrustStage.socialVerified` for circle/host stage | `viewer_profile.dart`; `listing_data.dart` |
| `host_verified_badge` | listing / landlord | YES (soft: circle / host stage) | YES (fallback) | YES (ID Verified reason) | NO | `true` → `TrustStage.idVerified` | `viewer_profile.dart`; `listing_data.dart` |
| `host_trust_stage` | listing / landlord | NO (hard filters) | YES | YES | NO | Primary host multiplier input | `listing_data.dart`; `listing_match_engine.dart`; Dublin seeds |
| `host_trust_multiplier` | listing / landlord | NO | NO (engine uses stage `.multiplier`) | NO | YES | Accessor + passport host multiplier helper | `listing_data.dart`; passport; Supabase listing map |
| `host_pre_arrival_badge` | listing / landlord | NO | NO | NO | YES | Accessor only; `ListingMatchResult.preArrivalBadge` never set true in inventored evaluate | `listing_data.dart`; match result field + UI widgets |
| `is_aadhaar_verified` / `aadhaarVerified` | seeker | NO | NO | NO | YES | Session → `ViewerProfile` only in inventored files | `viewer_profile.dart` |
| `passkey_public_key` / `passkeyBound` | seeker | NO | NO | NO | YES | Session → `ViewerProfile` only | `viewer_profile.dart` |
| `has_verified_grand_badge` | seeker (co-applicant map) | NO | YES (landlord IP applicant score) | NO | NO | +10 score points | `full_rental_applicant_scorer.dart` |
| `has_verified_corporate_email` | seeker (co-applicant map) | NO | YES (landlord IP applicant score) | NO | NO | +5 score points | `full_rental_applicant_scorer.dart` |
| In Your Circle (`inCircle`) | derived (seeker↔listing) | NO (not hard exclude) | YES | YES | NO | Requires network circle (trust ≥ host + shared markers) and match ≥ 75% | `listing_match_engine.dart`; `viewer_profile.dart` |
| Government ID (label via `TrustStage.idVerified`) | seeker / host (stage) | NO | YES (via stage multiplier) | YES (host “ID Verified”) | YES (passport ID label) | No separate inventored DB column named government_id | passport; match reasons; contact gate |
| `university_email_otps` (table) | seeker (verification infra) | NO | NO | NO | YES (backend OTP store) | Hashed OTP for .ie university email Track A | `university_email_otps.sql` |
| `user_trust_profiles` (table) | seeker | NO | YES (feeds applicant sort/group) | NO | YES | Authoritative trust tier flags for applicant UI | `user_trust_profiles.sql`; `applicant_management_supabase_service.dart` |
| `overall_match_score` / `verified_transit_duration_seconds` (high-signal) | seeker↔listing (applicant) | NO | YES (dashboard sort when present) | NO | YES (commute label) | When present, dashboard sort score = overall match % | `high_signal_match.dart`; applicant builders |
| `employment_letter_verified` | seeker | NO | NO | NO | YES | Passport employment row | `contextual_passport_snapshot.dart` |

### Not found in inventored sources

- Phone verification / phone trust badge  
- LinkedIn as a column on `user_trust_profiles` (only session fields + contact copy)  
- Dedicated “Sound / Grand / Just Landed” scoring inside seeker listing feed matcher (those labels are applicant-side / UI tier; feed uses numeric `TrustStage`)

---

## 2. Trust signals affecting ranking

| Signal | Where | Influence |
| --- | --- | --- |
| Host `trust_stage` / `TrustStage.multiplier` | `listing_match_engine.dart` evaluate | Averaged with seeker multiplier; scales compatibility score |
| Seeker `trust_stage` (+ pre-arrival upgrade via `TrustTierDesign`) | same | Seeker half of combined trust multiplier |
| `has_verified_pre_arrival_docs` | same | Affects effective seeker multiplier / Grand weighting path |
| `isPreArrivalSeeker` | `_preArrivalScoreMultiplier` | ×0.9 when listing student track is `allStudents` |
| `inCircle` | `rank()` sort | Circle listings sorted above non-circle before quality tier |
| Final match `score` (trust-scaled) | `rank()` | Within quality tiers, higher score ranks first |
| Applicant `trust_tier` | `applicant_dashboard_payload_builder.dart` | `trustBoost = sortPriority * 5` in `dashboardSortScore`; tie-break by trust tier |
| High-signal `overall_match_score` | dashboard builder | Replaces composite sort when present |
| Applicant stream trust blocks | `applicant_stream_payload_builder.dart` | Rows grouped Sound → Grand → Just Landed before within-tier score sort |
| `has_verified_grand_badge` | `full_rental_applicant_scorer.dart` | +10 |
| `has_verified_corporate_email` | same | +5 |
| `host_linkedin_badge` / `host_verified_badge` | via host stage fallback | Indirect ranking if `host_trust_stage` absent |

**Not ranking (inventored feed matchers):** `weighted_listing_matcher.dart`, `tower_filter_policy.dart`, `marketplace_listing_pipeline.dart`, `shared_space_compatibility_scorer.dart` — no trust field hits.

---

## 3. Trust signals affecting explanations

Trust copy appears in **`_combinedReasons`** (`listing_match_engine.dart`), which feeds `ListingMatchResult.reasons` (card/banner path):

| Reason | Trigger |
| --- | --- |
| In your circle | `inCircle` |
| Pre-arrival docs verified — Grand trust weighting | `hasPreArrivalTrustUpgrade` |
| ID Verified | host `TrustStage.idVerified` |
| Socially verified | host `TrustStage.socialVerified` |

**Preference explanation APIs do not emit trust reasons:**  
`independentPlacePreferenceExplanations` and `sharedLivingPreferenceExplanations` cover budget/beds/timing/commute/household/room only (no trust fields). Detail “why this works” path therefore does not explain trust from those generators.

Passport UI labels (display explanations, not match reasons): Employment Contract Verified, University Acceptance Verified, Government ID / social identity labels, Verifiable vs Self-declared budget.

---

## 4. Trust signals that are display-only

Count of inventored signals with matching=NO, ranking=NO, explanations=NO (UI / infra only): **14**

1. `employment_verified`  
2. `financial_verified`  
3. `verification_track`  
4. `corporate_verification_seal`  
5. `open_banking_verification_seal`  
6. `open_banking_verified_at`  
7. `profile_completeness_percent`  
8. `verified_university_email` / `university_email_verified` (UI + contact gate; not score)  
9. `linkedin_verified` / company / title  
10. `host_trust_multiplier` (engine uses stage multiplier)  
11. `host_pre_arrival_badge` / unused `preArrivalBadge` on match result  
12. `aadhaarVerified`  
13. `passkeyBound`  
14. `university_email_otps` table / `employment_letter_verified` passport alias  

Contact gates on `listing_detail_screen.dart` (LinkedIn / university email / ID / social verification) gate **contact**, not inventored listing rank score.

---

## 5. UAT scenarios missing because of trust signals

Inferred only from inventored **seed** vs **matcher** presence:

| Gap | Product behavior in inventored code | Seed coverage |
| --- | --- | --- |
| Pre-arrival seeker ranking / hard conflict | `isPreArrivalSeeker` → ×0.9 and `onCampusOnly` conflict | Demo seeker defaults lack `pre_arrival_contact_ready` / verified-pre-arrival docs |
| Pre-arrival “Grand trust weighting” explanation | `_combinedReasons` + seeker multiplier upgrade | Not set on demo seeker session |
| LinkedIn / Aadhaar / passkey seeker paths | Session fields on `ViewerProfile`; LinkedIn contact copy | Not present in `demo_auth_service` / applicant seeds |
| `has_verified_grand_badge` / `has_verified_corporate_email` | +10 / +5 in `FullRentalApplicantScorer` | Not present in `mock_applicant_seeder` / `dublin_mock_data` / SQL seed |
| Host badge fallbacks (`host_linkedin_badge`, `host_verified_badge`, `host_pre_arrival_badge`) | Stage/circle derivation + UI | Dublin seeds set `host_trust_stage` only |
| Open Banking seal display path | Passport checks `open_banking_verification_seal` | Mock Sound user has `financial_verified` + track string; seal often absent |
| Seeker feed TrustStage upgrade beyond Just Landed | Feed multiplier uses seeker stage | Demo seeker fixed `trust_stage: 1` / Just Landed — no Sound/ID seeker browse scenario |
| Applicant tier matrix (Sound/Grand/Just Landed) | Landlord streams/dashboard | Covered by mock/Dublin applicant seeds — **present** |
| Host trust stage variation on listings | Feed host multiplier | Covered by Dublin listing seeds `hostTrustStage` 1/2/3 — **present** |

---

## Methodology notes

- YES/NO for matching / ranking / explanations / UI determined only from inventored matching, ranking, explanation, and UI-binding files on the allowlist.  
- Non-inventored imports (e.g. `TrustTierDesign`, `ApplicantTrustTier`, `TrustService`) were not opened; influence described only where inventored callers show inputs/outputs.  
- “Matching” = hard eligibility / exclude gates in inventored matchers; trust multipliers counted under ranking unless they also hard-exclude (pre-arrival student-track conflict).
