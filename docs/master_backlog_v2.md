# TrueCircle Master Backlog v2

**Created:** 2026-09-13  
**Source:** Production readiness audit (`docs/production_readiness_audit.md`)  
**Note:** `docs/master_backlog.md` did not exist; this is the cleaned canonical backlog.

**Rules applied**
- Completed items removed (see audit § Completed)
- Duplicates merged
- Obsolete items moved to archive
- P0 limited to true multi-user launch blockers
- Location / proximity workflow remains frozen (do not reopen)
- Do not restore trust-tier ranking / JL–G–S / In Your Circle

---

## P0 — Launch blockers

| ID | Item | Why P0 | Remaining work |
|----|------|--------|----------------|
| P0-1 | Home feed remote listing sync | Seekers never see other users’ published listings | Fetch/merge `public.listings` when authenticated; keep local seed as demo fallback |
| P0-2 | Unify publish → remote + local | Dual paths: local storage vs Supabase write; feed ignores remote | Single publish path; ensure feed reads what publish writes |
| P0-3 | Server-backed applications + messaging | Conversations/apps are SharedPreferences-only | Persist applications + messages; cross-device sync |
| P0-4 | Deep-link marketplace guard on `/listing/:id` | Cross-tower detail leakage (UAT Critical) | Compare session marketplace to listing tower; block/redirect |
| P0-5 | Deploy migrations + enrich-location + trigger settings | Proximity enrichment won’t run in prod | `supabase db push`; deploy function; set `app.settings`; E2E smoke |
| P0-6 | Release hygiene | Empty `.gitignore`, empty staging env, mocks in env files | Restore `.gitignore`; fill staging/prod with mocks **off** |

---

## P1 — Launch quality / safety (before open publish)

| ID | Item | Remaining work |
|----|------|----------------|
| P1-1 | Host: Current Resident Verified | Define proof + UX + persistence |
| P1-2 | Host: Resident Owner Verified | Define proof + UX + persistence |
| P1-3 | Draft vs Published listing lifecycle | Status field, RLS, hide drafts from public feed |
| P1-4 | Publish gating | Gate publish on host verification + Stage 0 completeness |
| P1-5 | Align contact permission with product rule | Students: Offer Letter **OR** University; Pros/Families: LinkedIn **OR** Employment — tighten pre-arrival / light_trust / JIT path unlocks if product requires |
| P1-6 | Persist verifications to `user_trust_profiles` + expiry | Uni / LinkedIn / employment server upsert; revalidation |
| P1-7 | Disable / remove JIT path-only contact unlock | Require edge proof for letters |
| P1-8 | Invite vouch honesty | Server-backed invites **or** remove vouch language |
| P1-9 | E2E smoke | Auth → publish → proximity_data → card + detail → apply → message |
| P1-10 | Product: budget hard-cap contract | Keep intentional 1.25× and update UAT **or** enforce strict `rent ≤ budget` |
| P1-11 | Product: zero-match isolation | Redefine fixtures and/or harden filters after budget decision |

---

## P2 — Matching / ranking quality

| ID | Item | Notes |
|----|------|-------|
| P2-1 | Explanation duplication | Accept templates for v1 **or** add listing-specific tokens |
| P2-2 | Ranking listing-id tie-breaker | After score/quality; needs product approval |
| P2-3 | Pre-arrival × onCampusOnly hard exclude | Decide: student-track matching vs remove |
| P2-4 | Location copy vs city-match warnings | Medium UAT |
| P2-5 | Availability / timing soft ranking refinement | Optional calendar proximity |
| P2-6 | Check in frozen supply-demand field contract | Unblocks supply-demand audit |
| P2-7 | Check in frozen UAT seeker fixtures | Repeatable UAT |

---

## P3 — Product surfaces (preferred next after P0/P1)

| ID | Item | Notes |
|----|------|-------|
| P3-1 | Seeker cards polish | Location workflow frozen — cards only |
| P3-2 | Listing details view polish | Not proximity/location infra |
| P3-3 | Matching product iteration | Compatibility only; no trust boost |
| P3-4 | Recommendations (areas / listings) | Includes onboarding Recommended Areas engine |
| P3-5 | Landlord dashboard polish | Active focus; applicant stream UX |
| P3-6 | Landlord decision UAT (≥3 sessions) | Gate before Offer / Due Diligence |
| P3-7 | Docs refresh | Align `project-state.md` / README with trust simplification |

---

## P4 — Deferred / V2

| ID | Item |
|----|------|
| P4-1 | IP Bathroom Preference in Independent Places scoring |
| P4-2 | Security Deposit Affordability scoring |
| P4-3 | Seeker Furnishing Preference matching |
| P4-4 | IP Phase 2: reconsider budget/commute hard exclude when inventory healthy |
| P4-5 | Pets/smoking soft-warning UI |
| P4-6 | Family school-area recommendation logic |
| P4-7 | Offer Workflow (blocked until landlord UAT) |
| P4-8 | Tenancy Due Diligence (blocked until landlord UAT) |
| P4-9 | Real community references / endorsements / reviews |
| P4-10 | Trust expiry + admin revocation APIs (beyond P1-6 minimal) |
| P4-11 | Phone verification |
| P4-12 | Buy/Sell Dublin tower |
| P4-13 | Seed completeness (BER / lease / pets / occupants) |
| P4-14 | Rent parser week/year hardening |
| P4-15 | Guard push / saved / email listing deep links (when channels exist) |
| P4-16 | Leftover JL/G/S enum / TrustTierDesign cleanup |

---

## Archive — Obsolete (do not reopen)

| Former item | Reason |
|-------------|--------|
| TrustStage multipliers in seeker score | Removed; trust simplification complete |
| In Your Circle ranking / sort | Removed |
| Trust reasons in match explanations | Removed |
| Landlord trustBoost / JL–G–S stream grouping | Removed |
| Grand +10 / corporate email +5 applicant scorer | Removed |
| Profile “× listing boost” marketing | Removed |
| JL / Grand / Sound as primary seeker badges | Replaced by ✅ Verified User |
| Enterprise Verified seeker badge | Deprecated / forced off |
| Reopen location / proximity / Nominatim / Eircode / area infra | Frozen complete |
| Restore demo-first auth as production entry | Email-first in release; QA debug-only |

---

## Suggested execution order

1. **P0-6** release hygiene (fast, risk reduction)  
2. **P0-5** deploy + trigger settings  
3. **P0-1 + P0-2** feed sync + unified publish  
4. **P0-3** applications + messaging backend  
5. **P0-4** deep-link marketplace guard  
6. **P1-1…P1-4** host verification & publish controls  
7. **P1-5…P1-8** verification integrity  
8. **P1-10 / P1-11** product decisions on budget / zero-match  
9. Then P2–P3 product polish  

---

## Out of scope without explicit approval

- Any change to frozen location / area / proximity workflow  
- Reintroducing trust tiers, JL/G/S copy, or In Your Circle ranking  
- Using verification to boost match score, sort order, or recommendations  
