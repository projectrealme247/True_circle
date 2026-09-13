# TrueCircle Trust Ranking Influence (v1)

**Scope:** Matching (inventory cat 5) + ranking (cat 6), plus inventored imports used for `TrustStage` / `inCircle` / badges.  
**Verified against source:** every claim checked in inventored match/rank code (not audit alone).  
**Code modified:** No.

**Surfaces (keep separate):**

| Surface | Entry | Trust role |
| --- | --- | --- |
| **Seeker browse / Active Mode Explore feed** | `MarketplaceListingPipeline` → `ListingMatchEngine.rank` → `evaluate` | TrustStage multipliers, pre-arrival upgrade, inCircle sort, optional pre-arrival student-track ×0.9 |
| **Landlord applicant dashboard** | `ApplicantDashboardPayloadBuilder` | `trust_tier` boost + tie-break |
| **Landlord applicant streams** | `ApplicantStreamPayloadBuilder` | Group by `trust_tier` (Sound → Grand → Just Landed) before within-tier score |
| **Landlord IP applicant scorer** | `FullRentalApplicantScorer` | Grand / corporate badge point adds |

`WeightedListingMatcher` and the pipeline itself contain **no** trust field reads; trust enters only via `ListingMatchEngine`.

---

## Seeker feed sort order (`ListingMatchEngine.rank`)

When soft weighted filters are **inactive**:

1. `inCircle == true` before `false`
2. Quality tier from **trust-scaled** `percentage` (≥50 → 2, ≥25 → 1, else 0)
3. Higher trust-scaled `score` first

When soft weighted filters **are** active: `preferenceScore` sorts first; then the same circle → tier → score rules.

**Score formula (`evaluate`):**

```
combinedTrustMult = (hostTrust.multiplier + seekerMult) / 2
finalScore = round(round(combinedTrustMult × compatibilityScore) × preArrivalListingMult)
percentage = (finalScore / maxScore) × 100
```

| Stage | Level | Multiplier |
| --- | --- | --- |
| Anonymous | 0 | **0.4** |
| Casual Browser | 1 | **0.7** |
| Social Verified | 2 | **0.9** |
| ID Verified | 3 | **1.0** |

Seeker multiplier: `TrustTierDesign.effectiveSeekerTrustMultiplier` — if `baseStage == casual` **and** `hasVerifiedPreArrivalDocs`, use **0.9** instead of 0.7; else `baseStage.multiplier`.

Host multiplier input: `ListingData.hostTrustStage(listing)` → **`host_trust_stage` int only** (default **1**). Does **not** read LinkedIn/verified badges for the score.

---

## Per-signal detail

### 1. `trust_tier` (Just Landed / Grand / Sound)

| | Seeker browse | Landlord applicants |
| --- | --- | --- |
| **Where** | Not read by `ListingMatchEngine` / pipeline | `ApplicantDashboardPayloadBuilder._dashboardSortScore`, sort comparator; `ApplicantStreamPayloadBuilder` tier blocks |
| **Impact** | None on feed order | Dashboard: `trustBoost = sortPriority × 5` inside composite score; streams: hard group Sound → Grand → Just Landed |
| **Weights** | — | `sortPriority`: Sound **3**, Grand **2**, Just Landed **1** → boost **15 / 10 / 5**. SL: `lifestyle×0.55 + compat×0.35 + trustBoost`. IP: `independent×0.50 + compat×0.40 + trustBoost`. If high-signal `overallMatchScore` present, that **replaces** the composite (no trustBoost). Tie-break: higher `sortPriority` |
| **Less-relevant above more-relevant?** | N/A (unused) | **YES** — tier boost / grouping can outrank lifestyle/compat |
| **Top-5 / Top-1?** | **NO** / **NO** | **YES** / **YES** |
| **Class** | **A** Display only (feed) | **C** Material ranking influence |

---

### 2. `TrustStage` (0–3)

| | Seeker browse | Landlord applicants |
| --- | --- | --- |
| **Where** | `ViewerProfile._resolveTrustStage`; host via `ListingData.hostTrustStage`; `ListingMatchEngine.evaluate` | Indirect: `ApplicantTrustTier.fromTrustProfile` if `trust_tier` string absent (`stage≥3`→Sound, `≥2`→Grand) |
| **Impact** | Scales every eligible listing’s score/percentage; can move quality tiers | Only when mapping into `trust_tier` for dashboard/stream |
| **Weights** | Host/seeker multipliers **0.4 / 0.7 / 0.9 / 1.0**; combined = average | Via tier sortPriority as above |
| **Less-relevant above more-relevant?** | **YES** — higher host (or seeker) stage can lift a lower-compatibility listing over a higher-compat, lower-trust one | Indirect YES via tier |
| **Top-5 / Top-1?** | **YES** / **YES** | Via `trust_tier` path |
| **Class** | **C** Material | **C** when used as tier fallback; else N/A |

**Example (seeker casual 0.7, max 100):**

| Listing | Compat | Host stage | Combined mult | Score |
| --- | --- | --- | --- | --- |
| A | 80 | ID (1.0) | 0.85 | **68** |
| B | 95 | Anonymous (0.4) | 0.55 | **52** |

A ranks above B despite lower compatibility → trust can reorder **top-1**.

---

### 3. `inCircle`

| | Seeker browse | Landlord applicants |
| --- | --- | --- |
| **Where** | `ViewerProfile.isInCircle` + `ListingMatchEngine.qualifiesForInCircle`; sort in `rank` | Not used in inventored applicant scorers |
| **Impact** | Boolean primary sort key (after weighted pref, before quality tier) | — |
| **Weights** | Network: host trust **≥** seeker trust **and** ≥1 shared circle marker. Badge: match **≥ 75%** (`inCircleMinMatchFraction = 0.75`) on **trust-scaled** percentage | — |
| **Less-relevant above more-relevant?** | **YES** — circle listing with lower score still sorts above non-circle | N/A |
| **Top-5 / Top-1?** | **YES** / **YES** | **NO** / **NO** |
| **Class** | **C** Material | **A** (not in applicant rank) |

**Example:** Circle listing score 60 vs non-circle score 95 → circle wins top-1.

---

### 4. Grand badge (`has_verified_grand_badge`)

| | Seeker browse | Landlord IP applicants |
| --- | --- | --- |
| **Where** | Not in match engine | `FullRentalApplicantScorer.scoreApplicantGroup` |
| **Impact** | None | `score += 10` if any co-applicant has flag |
| **Weights** | — | **+10** (vs rent-ratio block up to +40, lease +10, corporate +5) |
| **Less-relevant above more-relevant?** | N/A | **YES** within applicant list |
| **Top-5 / Top-1?** | **NO** / **NO** | **YES** / **YES** (applicant queue) |
| **Class** | **A** | **C** |

---

### 5. Corporate badge (`has_verified_corporate_email`)

| | Seeker browse | Landlord IP applicants |
| --- | --- | --- |
| **Where** | Not in match engine | `FullRentalApplicantScorer.scoreApplicantGroup` |
| **Impact** | None | `score += 5` |
| **Weights** | — | **+5** |
| **Less-relevant above more-relevant?** | N/A | **YES** (smaller than Grand) |
| **Top-5 / Top-1?** | **NO** / **NO** | **YES** / **YES** |
| **Class** | **A** | **C** |

Note: inventored seeker feed does **not** use corporate verification seal / employment_verified for ranking (display/passport elsewhere).

---

### 6. Pre-arrival documents

| Signal | Seeker browse | Landlord |
| --- | --- | --- |
| **`has_verified_pre_arrival_docs`** (or onboarding/employment/relocation letter verified) | `TrustTierDesign.effectiveSeekerTrustMultiplier`: casual → **0.9**; reasons copy via `hasPreArrivalTrustUpgrade` | Not in inventored dashboard/stream score formulas |
| **`isPreArrivalSeeker`** (`pre_arrival_contact_ready` && empty `verified_university_email`) | Hard exclude if listing `onCampusOnly`; score × **0.9** if listing `allStudents` (`_preArrivalScoreMultiplier`) | — |

| | |
| --- | --- |
| **Less-relevant above more-relevant?** | **YES** for doc upgrade (seeker mult 0.7→0.9 lifts all listings uniformly vs another seeker — between listings for one seeker, upgrade is constant so relative order unchanged **except** when interacting with host mult averages / percentage tier boundaries). Pre-arrival ×0.9 on `allStudents` listings can demote those vs open-track listings. |
| **Top-5 / Top-1?** | **YES** / **YES** (cross-listing via student-track ×0.9; tier boundaries; and vs other seekers only in landlord surfaces) |
| **Class** | **C** Material (seeker feed) | **A** on inventored landlord scorers |

Uniform seeker-side upgrade alone does not reorder two listings for the **same** seeker (same seekerMult on both). Host variation still reorders. Student-track ×0.9 **does** reorder across listings.

---

### 7. Host verification (LinkedIn / verified / host badges)

| Field | Score (`evaluate`) | Circle (`isInCircle`) | Class (seeker feed) |
| --- | --- | --- | --- |
| `host_trust_stage` | **Yes** → TrustStage multiplier | **Yes** (primary) | **C** |
| `host_verified_badge` | **No** (`ListingData.hostTrustStage` ignores it) | Fallback → `idVerified` if stage not int | **A** for score; **B** fallback for circle |
| `host_linkedin_badge` | **No** | Fallback → `socialVerified` if stage not int | **A** for score; **B** fallback for circle |
| `host_pre_arrival_badge` | **No** | **No** | **A** |
| `host_trust_multiplier` | **No** (engine uses stage `.multiplier`) | **No** | **A** |

Dublin seeds set `host_trust_stage` 1/2/3 → badge fallbacks rarely affect production-like seed ranking; stage drives **C** influence.

---

## Classification summary

| Signal | Seeker browse (Active Mode Explore feed) | Landlord applicant ranking |
| --- | --- | --- |
| `trust_tier` | **A** Display only | **C** Material |
| `TrustStage` | **C** Material | **C** (tier fallback) / else via `trust_tier` |
| `inCircle` | **C** Material | **A** |
| Grand badge | **A** | **C** (IP scorer +10) |
| Corporate badge | **A** | **C** (IP scorer +5) |
| Pre-arrival documents | **C** Material | **A** (inventored scorers) |
| Host LinkedIn / verified badges | **A** score / **B** circle fallback | **A** |
| `host_trust_stage` | **C** Material | **A** (not applicant-side) |

---

## Active Mode seeker feed — what matters

Active Mode **Explore** uses the marketplace pipeline → `ListingMatchEngine.rank`. Signals that **materially** affect seeker feed order:

1. **Host `TrustStage`** (`host_trust_stage`) — score multiplier  
2. **Seeker `TrustStage`** (+ pre-arrival doc upgrade to 0.9 when casual) — score multiplier  
3. **`inCircle`** — sort priority (and 75% gate on trust-scaled %)  
4. **Pre-arrival seeker × listing student track** — ×0.9 / hard exclude  

Do **not** affect seeker feed ranking: `trust_tier` labels, grand/corporate badges, LinkedIn seeker fields, host LinkedIn/verified badges (when `host_trust_stage` is set), `host_pre_arrival_badge`.

**Can trust reorder top-5?** **YES**  
**Can trust reorder top-1?** **YES**  
(via host/seeker multipliers, quality-tier boundaries, and especially `inCircle`.)

When Active Mode soft lifestyle filters are on, weighted preference score can dominate before circle/trust score — trust still breaks ties and still scales the score key.

---

## Key file paths

| Path | Role |
| --- | --- |
| `lib/utils/marketplace_listing_pipeline.dart` | Feed entry; calls `ListingMatchEngine.rank` |
| `lib/utils/listing_match_engine.dart` | `evaluate` trust mult; `rank` circle/tier/score sort |
| `lib/utils/viewer_profile.dart` | `TrustStage` enum/multipliers; `isInCircle`; pre-arrival flags |
| `lib/theme/trust_tier_design.dart` | Pre-arrival seeker mult upgrade (0.9) |
| `lib/utils/listing_data.dart` | `hostTrustStage` (int only for score) |
| `lib/utils/weighted_listing_matcher.dart` | No trust |
| `lib/services/applicant_dashboard_payload_builder.dart` | `trust_tier` boost ×5 + tie-break |
| `lib/services/applicant_stream_payload_builder.dart` | Trust-tier grouping |
| `lib/utils/full_rental_applicant_scorer.dart` | Grand +10, corporate +5 |
| `lib/models/applicant_trust_tier.dart` | `sortPriority` 3/2/1 |

---

## Confirmation

**No application/source code was modified.** Only this doc and the companion JSON were written under `docs/uat/v1/`.
