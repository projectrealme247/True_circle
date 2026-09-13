# TrueCircle Trust Register & Truthfulness Inventory

**Repo:** `C:\Users\keepm\Desktop\Project Realme\True_circle`  
**Date:** 2026-08-07  
**Scope:** Authoritative inventory of trust badges, signals, scores, and community reputation mechanisms.  
**Method:** Re-verified against `lib/` and `supabase/`; prior art (`phase7_trust_implementation_verification_audit`, `trust_signal_audit`) used as leads only.  
**Production code modified:** **No.**  
**Location/proximity frozen files modified:** **No.**

**Companion JSON:** [`trust_register_and_truthfulness.json`](./trust_register_and_truthfulness.json)  
**D5 ranking/matching narrative:** see Phase 7 audit (this doc stands alone for the five inventory outputs below).

### Summary counts

| Metric | Count |
| --- | --- |
| Trust register items | **42** |
| Badge/signal truthfulness GREEN | **5** |
| Badge/signal truthfulness AMBER | **24** |
| Badge/signal truthfulness RED | **9** |
| N/A (demo seeds / not found) | **4** |
| Demo-mock implementations | **6** |
| Mock verification flows (compile/env flags) | **4** |
| Dormant / marketing-only / unused | **7** |

---

## Truthfulness rules (applied below)

| Rating | Meaning |
| --- | --- |
| **GREEN** | User-facing claim matches what verification actually proves. |
| **AMBER** | Partial truth: real check exists, but labels/tooltips overclaim, or strength is weak/heuristic. |
| **RED** | Materially false, trivially self-asserted, or claims unimplemented mechanisms (gov API, references, income multiples). |

---

# 1. Trust Register

Per-item inventory. Status: **active** / **partial** / **demo-mock** / **dormant** / **unused**.

| # | Name | Purpose | Audience | Display locations | Verification method | Evidence collected | Validation mechanism | Source of truth | Expiry | Revocation | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | TrustStage (0–3) | Progressive funnel stage; also score multiplier | Seeker + host | Profile trust section, home banner, listing host stamp | Upgrades via LinkedIn / uni OTP / Aadhaar / corporate / OB / JIT | Session `trust_stage`, listing `host_trust_stage` | Client `TrustService` stage writes | Session (primary); listing stamp at publish | None | None (overwrite only) | **active** |
| 2 | trust_tier Just Landed / Grand / Sound | Irish badge labels; landlord sort/group | Seeker (self + landlord view) | `TrustBadge`, landlord streams/dashboard, passport | Mapped from stage or set by corporate/OB/JIT | `user_trust_profiles.trust_tier` + session | Edge upsert (corp/OB); client map otherwise | DB for landlord; session for seeker UI | None | None | **active** |
| 3 | identity_trust_tier | Alternate stage string feeding TrustStage | Seeker | Indirect via stage | Set by `TrustService` upgrades | Session string (`Casual_Browser`, `Social_Verified`, `ID_Verified`, seeds) | Client write | Session | None | None | **active** |
| 4 | LinkedIn Verified | Stage 2 social proof / contact unlock | Seeker / host | Social verify screen, contact gates, host LinkedIn badge | LinkedIn OIDC `userinfo` via edge `linkedin-oauth`; company/title **manual** | `linkedin_verified`, `linkedin_sub/email/name/picture`, `linkedin_company`, `linkedin_title` | Edge token exchange; mock if `LINKEDIN_MOCK` or debug w/ empty client id | Session only (not on `user_trust_profiles`) | None | None | **partial** |
| 5 | University Verified (email OTP) | Track A light trust → Stage 3 | Student seekers | Uni verify screen, contact gate, passport row | 6-digit OTP to allowlisted `.ac.ie`/hosts via Resend | Masked `verified_university_email`; OTP row | Edge `university-email-otp`; hashed OTP; TTL/rate limits | `university_email_otps` (ephemeral) + session upgrade | OTP **10 min**; no trust revalidation | OTP deleted on success; **no** trust revoke | **active** |
| 6 | Employer / Corporate Verified | Grand + `employment_verified` | Working professionals | Corporate upload UI, landlord credentials, passport | PDF/image OCR heuristics (name + 2026 year + employer entity) | Seal + flags on profile | Edge `corporate-document-verify`; `CORPORATE_VERIFY_MOCK` | `user_trust_profiles` + session | None (year gate at verify only) | None | **active** (heuristic) |
| 7 | Open Banking / financial verified | Grand + liquidity signal | Professionals / families | OB verify screens, passport budget tier | AIS snapshot / mock via edge | Seal + `financial_verified` | Edge `open-banking-verify`; `OPEN_BANKING_MOCK` | DB + session seals | None | None | **partial** |
| 8 | Just Landed badge | Default casual / inbound label | All | Profile, cards, landlord UI | Default / stage &lt; 2 | Tier enum + tooltips | Display mapping only | Session/DB tier | N/A | N/A | **active** |
| 9 | Grand badge | “Verified intent” Irish tier | Seekers + landlords | TrustBadge, streams, passport | Stage 2 or corp/OB/JIT Grand write | `trust_tier=Grand` / stage 2 | Mixed real + path-only paths | Session + DB | None | None | **active** |
| 10 | Sound badge | Top Irish tier (“vouched & secured”) | Seekers + landlords | TrustBadge, streams, home banner copy | Stage 3 (uni light trust or Aadhaar ID) | Stage→Sound map | Stage upgrade only — **no** vouch system | Session + DB | None | None | **active** (label overclaims) |
| 11 | Verified Professional Host | Host ≥ social stage on listings | Listing viewers | Listing cards (`PolymorphicIdentity`) | `host_trust_stage ≥ 2` | Listing stamp fields | Stage int at publish | Listing map | None | None | **active** |
| 12 | Host verified badge | Stamp Stage 3 host as ID-level | Listing viewers / circle fallback | Listing fields → card/stage derivation | `host_verified_badge` true when stage==idVerified | Boolean on listing | Publish stamp | Listing | None | None | **active** |
| 13 | Host LinkedIn badge | Show host LI title@company | Listing viewers | Listing UI | Copied from host session at publish | `host_linkedin_badge` string | Session flags at stamp | Listing | None | None | **partial** |
| 14 | Enterprise Verified | Working-pro seeker enterprise signal | WP cohort seekers | Profile (`PolymorphicIdentity`) | LinkedIn **OR** employment letter **OR** non-empty `company` | Session flags / company text | Soft OR (client) | Session | None | None | **partial** / weak |
| 15 | In Your Circle | Relational affinity badge | Seekers | Card overlay, match banner/reasons | Shared lang/food/city + host≥seeker trust + match≥75% | Ephemeral on match result | `ViewerProfile.isInCircle` + `qualifiesForInCircle` | Derived | None | None | **active** |
| 16 | Circle markers | Affinity inputs for circle | Seeker↔host | Indirect | Self-declared mother tongue / food / city | Session + `host_circle_markers` | Equality checks | Session + listing | None | None | **active** |
| 17 | Invite code + onboarding letter (Track B) | Pre-arrival contact-ready path | Pre-arrival students | Pre-arrival screen, profile invite section | Local SharedPreferences codes + local letter path | Session flags; demo `DUBLIN-DEMO` | `InviteCodeService` local; letter = path set | Local store + session | Codes: max **5** redemptions; no time expiry | Local only | **demo-mock** |
| 18 | JIT employment letter | Quick Grand without server OCR | Professionals | JIT bottom sheet / profile | Local file path presence | `employment_letter_*` | Client path flag | Session | None | None | **partial** (client-only) |
| 19 | JIT family budget proof | Social stage for families | Arriving families | Family JIT flows | Local scan/upload path | `family_budget_proof_*` | Client path flag | Session | None | None | **partial** |
| 20 | Aadhaar + Passkey (India ID) | Stage 3 ID Verified | India market seekers | `verification_screen.dart` | Client QR/upload parse + passkey bind | `is_aadhaar_verified`, `passkey_public_key` | Client + `upgradeIdVerified` | Session | None | None | **partial** / market-gated |
| 21 | Contact / conversion gates | Gate messaging before contact | Seekers | Listing detail contact | `TrustService.canContact` by cohort | Stage + Track B readiness | Client gate | Session | None | None | **active** |
| 22 | Profile trust section + “listing boost” copy | Show stage + advertise multiplier | Signed-in users | `profile_trust_section.dart` | Display of stage | Session stage | Display | Session | N/A | N/A | **active** |
| 23 | Home trust tier banner | Surface current badge | Seekers | Home explore | ViewerProfile stage | Display | Display | Session | N/A | N/A | **active** |
| 24 | TrustBadge tooltips (requirements) | Explain badge requirements | All | `TrustBadge.tooltipFor` | Hardcoded strings | None enforced | **Not enforced** | Hardcoded | N/A | N/A | **active** (inaccurate) |
| 25 | TrustTierTooltips (marketing) | Softer Irish gloss | All | Profile / cards | Hardcoded | Marketing | Marketing | Hardcoded | N/A | N/A | **active** |
| 26 | Tenant verification credentials panel | GDPR-safe verification summary | Landlords | Landlord applicant UI | Trust tier + track flags | Denylisted sensitive fields | Display of flags | Trust profile / session | None | None | **active** |
| 27 | Contextual passport verification rows | Verified checklist rows | Seekers | Onboarding passport | Session seals & flags | Flags → labels | Display | Session | None | None | **partial** |
| 28 | Pre-arrival docs flag | Seeker mult upgrade + explanation | Pre-arrival seekers | Match reasons, multipliers | Boolean OR of letter flags | Session letter/doc flags | Boolean | Session | None | None | **active** |
| 29 | Pre-arrival student-track mult / exclude | ×0.9 or hard exclude on-campus | Pre-arrival students | Feed order / exclude | `pre_arrival_contact_ready` ∧ empty uni email | Derived | Matcher | Derived | None | None | **active** |
| 30 | Applicant dashboard trust boost | Rank applicants by tier | Landlords | Dashboard queue | `trust_tier` sortPriority×5 | Trust profiles | Payload builder | DB | None | None | **active** |
| 31 | Applicant stream tier grouping | Group Sound→Grand→Just Landed | Landlords | Stream views | Same tier | Trust profiles | Payload builder | DB | None | None | **active** |
| 32 | has_verified_grand_badge (+10) | Landlord IP applicant score | Landlords | Scorer only | Mapped from Grand/employment | Co-applicant maps | Scorer | Session sync maps | None | None | **active** |
| 33 | has_verified_corporate_email (+5) | Landlord IP applicant score | Landlords | Scorer only | `employment_verified` | Co-applicant maps | Scorer | Session sync | None | None | **active** |
| 34 | Match explanation trust reasons | “In your circle”, ID/Social, Grand weighting | Seekers | Cards / banners | Derived in `_combinedReasons` | Match result reasons | Derived | Match result | None | None | **active** |
| 35 | user_trust_profiles table | Authoritative tier for landlord UI | Backend | Landlord fetch | Corporate/OB upserts; seeds | Columns: tier, stage, seals, flags | Server upsert | Postgres | None | No revoke API | **active** |
| 36 | university_email_otps table | OTP store | Backend | Infra only | Edge write/read | Hashed OTP rows | TTL + attempts | Postgres (ephemeral) | 10 min | Delete on success/fail | **active** |
| 37 | Demo / seed trust profiles | Sound/Grand/Just Landed fixtures | Dev / demos | Landlord demos | SQL + Dart seeders | Seed rows | Seeded | Seed data | N/A | N/A | **demo-mock** |
| 38 | Profile completeness % | Profile fill indicator | Seekers | Completeness widgets | Heuristic key fill | Completeness % | Heuristic | Session | None | None | **active** UI; unused in match score |
| 39 | Community references / vouches | Claimed Sound requirement | — | Tooltips / landlord copy only | **Not implemented** | None | None | Marketing copy | — | — | **dormant** |
| 40 | Endorsements | Peer endorsement reputation | — | Not found | **Not implemented** | None | None | — | — | — | **unused** |
| 41 | Review-based trust | Reviews / ratings as trust | — | Not found (no trust review system) | **Not implemented** | None | None | — | — | — | **unused** |
| 42 | Phone verification | Phone trust badge | — | Not found | **Not implemented** | None | None | — | — | — | **unused** |

### Related passport labels (not separate registry IDs)

Displayed when flags set: “University Acceptance Verified”, “Employment Contract Verified”, Government ID / social identity labels, Verifiable vs Self-declared budget. These inherit truthfulness of underlying controls (often **AMBER**/overclaim).

---

# 2. Badge Truthfulness Report

| Badge / signal | Rating | Why |
| --- | --- | --- |
| Just Landed | **AMBER** | Fair as “new/casual”; tooltip requirements (arrival intent, funding token) **not enforced** |
| Grand | **AMBER** | Real paths exist (OIDC / OCR / AIS); tooltips overclaim “identity + paperwork successfully checked” for LinkedIn-only / JIT path |
| Sound | **RED** | Tooltip/marketing: Gov API match, income &gt;3.5× rent, community references — **none implemented**; uni OTP alone maps here |
| LinkedIn Verified | **AMBER** | OAuth proves LinkedIn account ownership; company/title self-entered — not employer verification |
| University Verified (mailbox) | **GREEN** *as control* | OTP proves allowlisted mailbox ownership |
| University “Acceptance Verified” label | **AMBER** / **RED** if sold as enrollment | Email ownership ≠ acceptance/enrollment; stage maps to Sound/ID |
| Employer / Corporate Verified | **AMBER** | Heuristic OCR + whitelist; forgeable; no revalidation |
| JIT employment letter “verified” | **RED** | Local path flag only — no server proof |
| Open Banking / financial verified | **AMBER** | Real edge path exists; mock-heavy in local env; seals OK (no raw money stored) |
| Verified Professional Host | **AMBER** | Reflects host stage ≥2; stage may be weakly earned |
| Host LinkedIn badge | **AMBER** | Stamped title@company may be self-typed after OAuth |
| Enterprise Verified | **RED** | Fires on non-empty `company` without LinkedIn/docs |
| In Your Circle | **AMBER** | Honest as affinity marker; **not** community vouch; still used in ranking/explanations |
| Invite-code “community vouch” | **RED** | Local POC + `DUBLIN-DEMO`; not network reputation |
| Pre-arrival / Grand trust weighting reason | **RED** | Match narrative overclaims verified Grand weighting for path-only docs |
| ID Verified (Aadhaar path) | **AMBER** | India upload/QR path exists; not Dublin primary; rigor depends on parse |
| TrustBadge requirements tooltips | **RED** | Hardcoded requirements do not match gates |
| TrustTierTooltips Sound/Grand gloss | **AMBER**/Sound **RED** | Marketing overstates verification strength |
| Contact gates | **GREEN** | Behavior matches stage/cohort rules (conversion, not badge claim) |
| Completeness % | **GREEN** | Accurately a fill indicator; not sold as verified identity |
| Community references / endorsements / reviews | **RED** (claimed) / N/A (absent) | Claimed in Sound copy; systems do not exist |
| Phone verified | N/A | Not found |
| Corporate zero-retention seal design | **GREEN** | Bytes purged; seal metadata only — claim matches design |
| OTP table infra | **GREEN** | Hashed OTP + TTL as designed |

**User-facing primary tier scorecard:** Just Landed **AMBER**, Grand **AMBER**, Sound **RED** → **0 GREEN / 2 AMBER / 1 RED** for JL/Grand/Sound labels.

**Register truthfulness counts:** GREEN **5**, AMBER **24**, RED **9**, N/A **4**.

---

# 3. Verification Strength Matrix

| Lever | Implemented? | Visible? | Used for? | Strength | Status |
| --- | --- | --- | --- | --- | --- |
| LinkedIn OIDC | Yes (web + mock) | Yes | Stage 2; contact; host badge | **Moderate** account ownership; **weak** for employer/role | partial |
| University email OTP | Yes | Yes | Stage 3 light trust; contact | **Strong** mailbox; **weak** as gov/student-status ID | active |
| Corporate doc OCR | Yes | Yes | Grand + employment_verified | **Weak–moderate** heuristic | active |
| Open Banking AIS | Yes | Yes | Grand + financial_verified | **Moderate** when real; mock in `env.dev.json` | partial |
| JIT employment / family letters | Yes | Yes | Stage/Grand flags | **Weak** (path-only) | partial |
| Aadhaar + Passkey | Yes (India) | India path | Stage 3 | **Conditional** on parse rigor | partial |
| Invite codes | Local POC | Profile / pre-arrival | Track B contact | **Weak** / demo | demo-mock |
| In Your Circle | Yes | Yes | Display + **rank/explain** | Affinity only — not vouch | active |
| References / endorsements | No | Claimed in Sound copy | — | N/A | dormant |
| Review-based trust | No | No | — | N/A | unused |
| Completeness % | Yes | Yes | UI only | Not identity | active UI |
| TrustStage multipliers | Yes | “listing boost” | **Ranking** | Manipulable via weak upgrades | active |
| Phone | No | No | — | N/A | unused |

### Segment view

| Segment | Primary path | Strength | Gap |
| --- | --- | --- | --- |
| Students | Track A uni OTP → Sound/Stage 3; Track B invite+letter | Email ownership moderate | Overstates ID/Sound; Track B local |
| Working professionals | LinkedIn → Stage 2; corp/OB/JIT → Grand | OIDC moderate; OCR weak–moderate | Self-declared title; Enterprise bypass |
| Relocating professionals | WP + pre-arrival flags | Same | Pre-arrival inflates score/explanations |
| Families | JIT budget proof; OB optional | Weak | No strong identity |
| Hosts | Stage stamped on listings | Host stage drives seeker rank | Same weak upgrade paths |

### One-liners (critical paths)

- **LinkedIn:** OIDC proves LinkedIn account ownership; company/title are self-declared — not employer verification.  
- **University:** Strong mailbox ownership via allowlisted OTP; no enrollment/gov ID; no revalidation; incorrectly maps to Sound/ID.  
- **Employer:** Corporate OCR heuristics (name + 2026 year + entity whitelist) with zero-retention seal; JIT letter is local-flag only; no revalidation.

### Mock / demo verification flows

| Flag / artifact | Default in `env.dev.json` (verified) | Effect |
| --- | --- | --- |
| `LINKEDIN_MOCK` | **true** | Fake LinkedIn profile; still upgrades trust |
| `UNI_OTP_MOCK` | false | When true: local OTP without Resend |
| `CORPORATE_VERIFY_MOCK` | **true** | Fabricates matching offer-letter text |
| `OPEN_BANKING_MOCK` | **true** | Mock AIS path |
| `DUBLIN-DEMO` invite | seeded in `InviteCodeService` | Anyone can redeem Track B locally |
| SQL/Dart trust seeds | `demo_applicants.sql` etc. | Landlord demo tiers |

---

# 4. Community Trust Inventory

| Mechanism | Exists in code? | Active? | What it actually is | Truthfulness |
| --- | --- | --- | --- | --- |
| **In Your Circle** | Yes | Yes | Shared self-declared markers + trust stage floor + match ≥75%; used in sort + explanations | **AMBER** — affinity, not vouch |
| **Circle markers** | Yes | Yes | Mother tongue / veg / city equality | **AMBER** — self-declared |
| **Invite codes (“vouch for someone”)** | Yes (local) | POC | SharedPreferences; Stage 3 generate; demo code | **RED** as community reputation |
| **Sound “community vouched” copy** | Yes (UI strings) | Display only | No vouch backend | **RED** |
| **Community references** | No | — | Claimed in `TrustBadge.tooltipFor(Sound)` only | **dormant** / fiction |
| **Endorsements** | No | — | Not found in `lib/` / `supabase/` | **unused** |
| **Peer reputation score** | No | — | Not found | **unused** |
| **Review / rating trust** | No | — | No review-based trust system | **unused** |
| **Participation-based trust** | Completeness % only | UI | Fill %; explicitly excluded from match score | **GREEN** as fill indicator; not community trust |
| **Landlord “Vouched & Secured” KPI copy** | Yes | Display | Marketing synonym for Sound | **RED** vs actual gates |

**Verdict:** TrueCircle’s only live “community” mechanism is **affinity** (InCircle + markers + local invite POC). There is **no** reference, endorsement, or review reputation system. Sound/Grand marketing language implies community reputation that does not exist.

---

# 5. Engineering Actions Required

### P0 — Badge honesty & verification integrity (this inventory’s focus)

1. **Rewrite Sound/Grand/Just Landed tooltips and marketing copy** to match real gates; remove gov API / income ×3.5 / community references claims (`trust_badge.dart`, `trust_tier_tooltips.dart`, home/landlord “Vouched & Secured” strings).  
2. **Stop mapping university OTP → Sound / ID Verified**; introduce accurate label (e.g. “College email verified”) and keep Sound for true high-assurance path when built.  
3. **Harden Enterprise Verified** — require LinkedIn OAuth and/or corporate seal; never unlock on non-empty `company` alone (`polymorphic_identity.dart`).  
4. **Persist uni/LinkedIn outcomes to `user_trust_profiles`**; add expiry/revalidation; eliminate client-only trust desync vs landlord DB.  
5. **Disable mock verification in production builds** — `LINKEDIN_MOCK`, `CORPORATE_VERIFY_MOCK`, `OPEN_BANKING_MOCK`, `UNI_OTP_MOCK`, `DUBLIN-DEMO`; replace local invite store with server-backed invites or remove “vouch” wording.  
6. **Downgrade or server-validate JIT letters** — path-only must not set Grand / `*_verified` without edge proof.  
7. **Clarify LinkedIn UX** — never imply employer/role verified from free-text company/title; optional Positions API later.

### P0 — D5 ranking/matching (cross-ref Phase 7; still confirmed in code)

8. Remove TrustStage multipliers from `ListingMatchEngine.evaluate` (and pre-arrival seeker mult upgrades used for score).  
9. Remove `inCircle` from `ListingMatchEngine.rank` sort keys; keep display-only badge.  
10. Strip trust reasons from `ListingMatchEngine._combinedReasons`.  
11. Remove `trustBoost` / trust-tier ordering from applicant dashboard/stream builders.  
12. Remove Grand/corporate badge point adds from `FullRentalApplicantScorer`.  
13. Remove profile “× listing boost” copy once multipliers gone.

### P1 — Community product (if desired later)

14. Either **build** real references/endorsements/reviews **or** permanently remove vouch language.  
15. Add trust expiry + admin/user revocation APIs (currently none).

---

## Demo / mock / dormant rollup

| Category | Items |
| --- | --- |
| **Demo-mock** | Invite codes + `DUBLIN-DEMO`; demo/seed trust profiles; local invite “vouch” UX; (env) fabricated LI/corp/OB paths when mocks on |
| **Mock verification flows** | `LINKEDIN_MOCK`, `UNI_OTP_MOCK`, `CORPORATE_VERIFY_MOCK`, `OPEN_BANKING_MOCK` |
| **Dormant / unused** | Community references; endorsements; review-based trust; reputation score; phone verification; Sound tooltip requirements; (largely unused) `host_pre_arrival_badge` match-result path |

---

## Confirmation

- Re-verified critical claims in `lib/` (`trust_service.dart`, `trust_badge.dart`, `polymorphic_identity.dart`, `viewer_profile.dart`, `listing_match_engine.dart`, OAuth/OTP/JIT services) and `supabase/` (migrations + edge functions).  
- Distinguished real edge flows from `*_MOCK` flags and seed fixtures.  
- **No production application code was modified.** Only this document and companion JSON under `docs/uat/v1/` were written.
