# TrueCircle Implementation File Inventory

Inventory only — current implementation source files under `lib/`, `supabase/`, and seed-related fixtures. No audit, gap analysis, or contract inference.

Generated for matching / seeker / listing / ranking / explanation surfaces (Shared Living + Independent Places).

---

## 1. Shared Living Seeker schema/model

| File Path | Purpose | Confidence |
| --- | --- | --- |
| `lib/models/profile_onboarding_models.dart` | Shared `SeekerProfile` DTO + `ProfileOnboardingTrack` (includes `seekerSharedSpace`) | High |
| `lib/utils/viewer_profile.dart` | Shared matching-normalized `ViewerProfile` + seeker cohort enums; session → viewer projection | High |
| `lib/utils/profile_data.dart` | Session field accessors, matching-readiness checks, budget/commute/persona helpers | High |
| `lib/models/seeker_onboarding_enums.dart` | Seeker onboarding enums (persona, tenure, bathroom/room prefs, commute options, etc.) | High |
| `lib/models/move_in_timing.dart` | `SeekerMoveInWindow` + timing evaluation types used for seeker move-in intent | High |
| `lib/models/applicant_field_keys.dart` | Canonical seeker application / payload field keys | High |
| `lib/utils/shared_living_match_tokens.dart` | Shared Living canonical seeker/listing match tokens (bathroom, room, gender) | High |
| `lib/models/marketplace_space.dart` | Marketplace space enum (`sharedSpace` / Shared Living track tokens) | High |
| `lib/utils/commute_profile.dart` | Seeker commute profile entry/registry shapes from session | High |
| `lib/utils/contextual_passport_snapshot.dart` | Contextual passport projection of seeker fields by onboarding track | Medium |
| `lib/utils/applicant_household.dart` | Household / income shape used when scoring seekers against listings | Medium |
| `lib/models/shared_living_match_metrics.dart` | Shared Living seeker↔listing lifestyle metrics DTO (applicant queue) | Medium |
| `lib/models/shared_living_applicant_stream.dart` | Shared Living applicant stream row model (seeker-facing fields on host dashboard) | Medium |

---

## 2. Independent Places Seeker schema/model

| File Path | Purpose | Confidence |
| --- | --- | --- |
| `lib/models/profile_onboarding_models.dart` | Shared `SeekerProfile` DTO + `ProfileOnboardingTrack` (includes `seekerEntirePlace`) — same shared model as SL | High |
| `lib/utils/viewer_profile.dart` | Shared `ViewerProfile` matching model (budget, layout, areas, timing) — same shared model as SL | High |
| `lib/utils/profile_data.dart` | Session field accessors and matching-readiness — same shared helpers as SL | High |
| `lib/models/seeker_onboarding_enums.dart` | Seeker onboarding enums including entire-place preferences — shared with SL | High |
| `lib/models/move_in_timing.dart` | Seeker move-in window + Independent Place landlord flexibility enums | High |
| `lib/models/applicant_field_keys.dart` | Canonical seeker application field keys — shared with SL | High |
| `lib/utils/preferred_layout_match.dart` | Entire-place seeker `preferred_layout` → bed requirement model | High |
| `lib/models/marketplace_space.dart` | Marketplace space enum (`fullRental` / Independent Places track tokens) | High |
| `lib/utils/commute_profile.dart` | Seeker commute profile shapes — shared with SL | High |
| `lib/utils/contextual_passport_snapshot.dart` | Passport projection for entire-place seeker track | Medium |
| `lib/utils/applicant_household.dart` | Household / income shape for Independent Places applicant scoring | Medium |
| `lib/models/independent_places_match_metrics.dart` | Independent Places lease/budget/move-in metrics DTO | Medium |
| `lib/models/independent_places_applicant_stream.dart` | Independent Places applicant stream row model | Medium |
| `lib/utils/full_rental_applicant_scorer.dart` | Independent Places (Rent) applicant gate/score model against listing rent | Medium |

---

## 3. Shared Living Listing schema/model

| File Path | Purpose | Confidence |
| --- | --- | --- |
| `lib/utils/listing_data.dart` | Canonical listing map accessors/normalization (Share + Rent); room-share detection | High |
| `lib/models/listing_creation_draft.dart` | Listing creation draft model with Shared Living fields (room type, household, kitchen, languages) | High |
| `lib/models/listing_creation_form_models.dart` | Listing creation enums/constants (smoking, household dynamic, kitchen culture, etc.) | High |
| `lib/models/listing_creation_field_keys.dart` | Canonical listing creation / payload keys | High |
| `lib/models/listing_creation_category.dart` | `sharedLiving` marketplace category + tower `Share` mapping | High |
| `lib/utils/shared_living_match_tokens.dart` | Listing-side Shared Living token extraction/normalization | High |
| `lib/data/dublin_listing_builder.dart` | Builder for Dublin seed listing maps (Share/Rent field coverage) | High |
| `lib/services/listing_creation_validation_service.dart` | Validation schema/rules for Shared Living vs Independent listing drafts | High |
| `lib/models/marketplace_space.dart` | Space ↔ listing tower property type (`Share`) | Medium |
| `lib/services/listing_creation_payload_builder.dart` | Draft → local listing map / Supabase row (shared fields branch) | Medium |

---

## 4. Independent Places Listing schema/model

| File Path | Purpose | Confidence |
| --- | --- | --- |
| `lib/utils/listing_data.dart` | Canonical listing map accessors/normalization — same shared listing model as SL | High |
| `lib/models/listing_creation_draft.dart` | Draft model with Independent Places fields (beds, parking, pets) — shared draft class | High |
| `lib/models/listing_creation_form_models.dart` | Listing enums including pets policy, parking, property subtype | High |
| `lib/models/listing_creation_field_keys.dart` | Canonical listing payload keys — shared with SL | High |
| `lib/models/listing_creation_category.dart` | `independentPlaces` category + tower `Rent` mapping | High |
| `lib/data/dublin_listing_builder.dart` | Dublin seed listing builder — same shared builder as SL | High |
| `lib/services/listing_creation_validation_service.dart` | Validation rules for Independent Places drafts | High |
| `lib/utils/preferred_layout_match.dart` | Listing beds/room comparison surface for entire-place fits | High |
| `lib/utils/student_track_preference.dart` | Listing `tenant_track_preference` / student track enum for Rent listings | High |
| `lib/models/marketplace_space.dart` | Space ↔ listing tower property type (`Rent`) | Medium |
| `lib/services/listing_creation_payload_builder.dart` | Draft → local/Supabase listing shape (independent fields branch) | Medium |

---

## 5. Matching engine

| File Path | Purpose | Confidence |
| --- | --- | --- |
| `lib/utils/listing_match_engine.dart` | Core `ListingMatchEngine`: hard filters, scoring, evaluate/rank, tower weights | High |
| `lib/utils/weighted_listing_matcher.dart` | `WeightedListingMatcher` + hard exclusion + soft preference scoring | High |
| `lib/utils/tower_filter_policy.dart` | Independent Places vs Shared Living hard/soft filter policy | High |
| `lib/utils/marketplace_listing_pipeline.dart` | Unified marketplace pipeline: parse → filter → rank | High |
| `lib/utils/preferred_layout_match.dart` | Preferred layout / bed-count compatibility matcher | High |
| `lib/utils/shared_space_compatibility_scorer.dart` | Shared Living cohort / lifestyle compatibility scoring | High |
| `lib/utils/shared_living_match_tokens.dart` | Token compatibility helpers used by match engine | High |
| `lib/models/move_in_timing.dart` | Timing match evaluation used by hard/soft timing gates | High |
| `lib/utils/listing_search_intent.dart` | Search intent / filter structures consumed by hard exclusion + pipeline | High |
| `lib/utils/viewer_profile.dart` | Viewer profile consumed by matchers | Medium |
| `lib/utils/city_area_match.dart` | Area/city matching helpers used in location filters | Medium |
| `lib/utils/student_track_preference.dart` | Student-track conflict gate used in matching | Medium |
| `lib/utils/full_rental_applicant_scorer.dart` | Landlord-side Independent Places applicant gates/scoring | Medium |
| `lib/utils/target_search_areas.dart` | Preferred-area resolution used in location hard filters | Medium |

---

## 6. Ranking logic

| File Path | Purpose | Confidence |
| --- | --- | --- |
| `lib/utils/listing_match_engine.dart` | `rank()` / quality tiers / score calculation / result ordering | High |
| `lib/utils/marketplace_listing_pipeline.dart` | Pipeline ranking stage producing `ScoredListing` ordered results | High |
| `lib/utils/weighted_listing_matcher.dart` | Preference score + sort descending after hard exclusion | High |
| `lib/utils/seeker_strong_match_counter.dart` | Counts strong matches from ranked results | Medium |
| `lib/utils/seeker_strong_match_aggregator.dart` | Cross-mode strong-match aggregation via pipeline ranked list | Medium |
| `lib/services/applicant_dashboard_payload_builder.dart` | Applicant dashboard sort score assembly | Medium |
| `lib/utils/district_recommendation_ranker.dart` | District recommendation ranking (onboarding areas; not listing feed rank) | Low |

---

## 7. Match explanation generation

| File Path | Purpose | Confidence |
| --- | --- | --- |
| `lib/utils/listing_match_engine.dart` | `independentPlacePreferenceExplanations`, `sharedLivingPreferenceExplanations`, `_combinedReasons` | High |
| `lib/screens/listing_detail_screen.dart` | Invokes SL/IP preference explanation generators for detail view | Medium |
| `lib/widgets/listing_detail_page_layout.dart` | “Why this could work for you” UI section binding | Medium |
| `lib/widgets/listing_match_banner.dart` | Match reason line display widgets | Medium |
| `lib/widgets/property_card.dart` | Passes `match.reasons` into card UI | Low |

---

## 8. Seed data

| File Path | Purpose | Confidence |
| --- | --- | --- |
| `lib/data/sample_listings_dublin.dart` | Dublin seed entrypoint (delegates to v2) | High |
| `lib/data/sample_listings_dublin_v2.dart` | Dublin seed v2 composition (Rent + Share) | High |
| `lib/data/sample_listings_dublin_expansion.dart` | Programmatic Rent/Share expansion seed listings | High |
| `lib/data/sample_listings_dublin_legacy.dart` | Legacy Dublin seed rows enriched into v2 | High |
| `lib/data/dublin_listing_builder.dart` | Shared builder used by Dublin listing seeds | High |
| `lib/data/market_listings_seed.dart` | Market-aware seed selector (Dublin / India) | High |
| `lib/data/sample_listings_seed.dart` | Deprecated seed facade exporting market seeds | Medium |
| `lib/data/sample_listings_india.dart` | India market sample listings seed | Medium |
| `lib/data/mock_applicant_seeder.dart` | Synthetic SL + IP applicant stream seeds | High |
| `lib/data/dublin_mock_data.dart` | Ranelagh Shared Living listing + applicant harness seed | High |
| `lib/data/demo_applicant_supabase_seed.dart` | Demo applicant / trust profile seed maps | High |
| `lib/services/demo_auth_service.dart` | Demo seeker (+ landlord) session seed defaults | High |
| `supabase/seed/demo_applicants.sql` | SQL seed for demo applicants | High |

---

## 9. API contracts / DTOs

| File Path | Purpose | Confidence |
| --- | --- | --- |
| `lib/services/listing_creation_payload_builder.dart` | Draft → local listing map / Supabase insert row DTO mapping | High |
| `lib/services/listings_supabase_service.dart` | Listings table round-trip (`_toSupabaseRow` / `_fromSupabaseRow`) | High |
| `lib/services/listing_creation_supabase_service.dart` | Listing creation Supabase write/read contract | High |
| `lib/services/application_service.dart` | Local listing-application store DTO/apply contract | High |
| `lib/services/listing_applications_service.dart` | Listing applications service boundary | High |
| `lib/services/applicant_management_supabase_service.dart` | Applicant management Supabase reads/writes | High |
| `lib/services/applicant_dashboard_payload_builder.dart` | Raw rows → `ListingApplicantDashboard` DTO | High |
| `lib/services/applicant_stream_payload_builder.dart` | Raw rows → IP/SL applicant stream DTOs | High |
| `lib/services/applicant_payload_sanitizer.dart` | Application payload sanitization for session projection | High |
| `lib/models/listing_application.dart` | Listing application DTO | High |
| `lib/models/listing_applicant_record.dart` | Applicant record DTO | High |
| `lib/models/listing_applicant_dashboard.dart` | Applicant dashboard aggregate DTO | High |
| `lib/models/high_signal_match.dart` | High-signal match row DTO (`get_high_signal_matches`) | High |
| `lib/models/independent_places_applicant_stream.dart` | Independent Places stream DTO | High |
| `lib/models/shared_living_applicant_stream.dart` | Shared Living stream DTO | High |
| `lib/models/listing_creation_field_keys.dart` | Canonical API/payload field keys for listings | Medium |
| `lib/models/applicant_field_keys.dart` | Canonical API/payload field keys for seekers/applications | Medium |
| `lib/models/independent_places_match_metrics.dart` | IP match metrics DTO embedded in applicant payloads | Medium |
| `lib/models/shared_living_match_metrics.dart` | SL match metrics DTO embedded in applicant payloads | Medium |

---

## 10. Database schema

| File Path | Purpose | Confidence |
| --- | --- | --- |
| `supabase/migrations/20260601120000_listings_infrastructure.sql` | Creates `public.listings` core table + indexes/RLS | High |
| `supabase/migrations/20260623140000_listing_creation_phase_c.sql` | Adds marketplace category, eircode/geom, beds, kitchen culture, etc. | High |
| `supabase/migrations/20260622120000_listing_applications_replacement.sql` | Creates `listing_applications` + `replacement_workflows` | High |
| `supabase/migrations/20260623150000_applicant_management_phase_c.sql` | Applicant status matrix / RLS for applications | High |
| `supabase/migrations/20260609120000_tenant_track_preference.sql` | `student_track_preference` enum + listings column | High |
| `supabase/migrations/20260611120000_user_trust_profiles.sql` | `user_trust_profiles` table used by applicant matching UI | High |
| `supabase/migrations/20260601120001_listings_enrich_location_trigger.sql` | Location enrichment trigger on listings | Medium |
| `supabase/migrations/20260611130000_open_banking_trust_fields.sql` | Open-banking trust fields (trust profiles; indirect to match) | Medium |
| `supabase/seed/demo_applicants.sql` | Demo applicant SQL seed against application/trust tables | Medium |
| `supabase/migrations/20260529120000_university_email_otps.sql` | University email OTP table (verification; indirect) | Low |

---

## 11. Field mappings

Files that **contain** seeker↔listing (or draft↔DB) mapping logic. Mapping contents not documented here.

| File Path | Purpose | Confidence |
| --- | --- | --- |
| `lib/utils/listing_match_engine.dart` | Compares viewer/session fields to listing fields for filters, scores, reasons | High |
| `lib/utils/weighted_listing_matcher.dart` | Maps search/session criteria onto listing attributes for hard/soft match | High |
| `lib/utils/preferred_layout_match.dart` | Maps seeker `preferred_layout` to listing beds/room type | High |
| `lib/utils/shared_living_match_tokens.dart` | Maps seeker bathroom/room prefs to listing bathroom/room tokens | High |
| `lib/models/move_in_timing.dart` | Maps seeker move-in window to listing availability/flexibility | High |
| `lib/utils/viewer_profile.dart` | Maps session keys into normalized viewer match fields | High |
| `lib/utils/tower_filter_policy.dart` | Maps tower-specific seeker/search filters to listing eligibility | High |
| `lib/utils/shared_space_compatibility_scorer.dart` | Maps seeker lifestyle/cohort signals to Shared Living listing fields | High |
| `lib/services/listing_creation_payload_builder.dart` | Maps draft fields to local listing + Supabase columns | High |
| `lib/services/listings_supabase_service.dart` | Maps app listing maps ↔ `public.listings` columns | High |
| `lib/services/applicant_dashboard_payload_builder.dart` | Maps application/trust/listing rows into match metric fields | High |
| `lib/services/applicant_stream_payload_builder.dart` | Maps seeker application payload fields against listing for stream rows | High |
| `lib/utils/listing_data.dart` | Listing field accessors used throughout mapping comparisons | Medium |
| `lib/services/profile_onboarding_repository.dart` | Maps onboarding tracks / session keys across seeker/host modes | Medium |
| `lib/models/marketplace_space.dart` | Maps session/listing type tokens to Independent Places vs Shared Living | Medium |
| `lib/utils/full_rental_applicant_scorer.dart` | Maps household income/commute to Independent Places listing rent | Medium |

---

## 12. Explanation inputs

Generator files (and direct field-read helpers they use) that determine which fields are read when building match explanations.

| File Path | Purpose | Confidence |
| --- | --- | --- |
| `lib/utils/listing_match_engine.dart` | Preference explanation generators + `_MatchFlags.build` field reads | High |
| `lib/utils/shared_living_match_tokens.dart` | Room/bathroom field reads used inside SL explanation generation | Medium |
| `lib/utils/preferred_layout_match.dart` | Bed/layout field reads used for IP bedroom explanation flags | Medium |
| `lib/utils/listing_data.dart` | Listing field accessors read during explanation flag construction | Medium |
| `lib/utils/viewer_profile.dart` | Viewer fields read during explanation generation | Medium |
| `lib/utils/profile_data.dart` | Session commute/budget helpers read for commute/area explanation labels | Medium |
| `lib/screens/listing_detail_screen.dart` | Selects SL vs IP explanation generator and supplies listing/viewer inputs | Medium |

---

## Notes

- Shared models appear under both SL and IP categories where one file defines both tracks.
- `docs/uat/` markdown/JSON audits were not used as schema sources.
- Location/proximity infrastructure files were not expanded beyond where they feed matching field reads.
