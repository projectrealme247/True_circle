---
name: TrueCircle Todo Revisit
overview: "Consolidated TrueCircle checklist: trust foundation and Dublin listing/profile UX are code-complete. Final sprint covers Supabase deploy and production wiring (deferrable while using localStorage)."
todos:
  - id: listings-migration
    content: "Add Supabase migration for public.listings columns: listing_type, parking_type, lifestyle_flags, languages_spoken, latitude, longitude, proximity_data"
    status: completed
  - id: supabase-listing-save
    content: Wire add_listing_screen save path to Supabase insert (keep localStorage fallback or sync both)
    status: completed
  - id: enrich-location
    content: Implement supabase/functions/enrich-location + INSERT trigger to populate proximity_data from Google Places
    status: completed
  - id: seed-infrastructure
    content: Add parking_type, languages_spoken, lifestyle_flags, proximity_data to Dublin sample listings for card demo
    status: completed
  - id: listing-detail-infra
    content: Surface parking, household culture, languages, and transit on listing_detail_screen.dart
    status: completed
  - id: unify-tier-tooltips
    content: Extract shared Irish tier tooltip copy; align listing_match_banner.dart with profile tooltips
    status: completed
  - id: auth-signup-parity
    content: "Optional: align auth_screen signup fields with profile_edit_screen (commute geocode, remove kitchen utility)"
    status: completed
  - id: final-sprint-supabase-deploy
    content: "Final sprint (deferrable on localStorage): supabase db push, functions deploy enrich-location --no-verify-jwt, optional GOOGLE_PLACES_API_KEY secret"
    status: pending
  - id: final-sprint-trigger-settings
    content: "Final sprint: Set app.settings.supabase_url + service_role_key in Postgres so INSERT trigger calls enrich-location"
    status: pending
  - id: final-sprint-home-sync
    content: "Final sprint: Load/merge remote listings from Supabase on home feed when authenticated"
    status: pending
  - id: final-sprint-qa
    content: "Final sprint: E2E smoke test — publish listing with lat/long → proximity_data → card + detail subtext"
    status: pending
isProject: false
---

# TrueCircle Todo Checklist — Revisit

## Completed (original foundation)

All items in [`.cursor/plans/truecircle_trust_foundation_00f31777.plan.md`](.cursor/plans/truecircle_trust_foundation_00f31777.plan.md) are marked **completed**:

| Phase | Scope |
|-------|--------|
| Phase 1 | Signup profile gaps (`occupant_type`, gender, budget) wired into `ViewerProfile` |
| Phase 2 | Trust multiplier model in match engine |
| Phase 3 | Circle markers + "In Your Circle" feed ordering |
| Phase 4 | LinkedIn OAuth / social verification |
| Phase 5 | ID verification gates (publish / contact) |
| Phase 6 | Landlord preference fields + mutual matching |
| Phase 7 | Tower weight tuning + shared lifestyle fields |

---

## Completed (revisit plan — code in repo)

| # | Item | Key files |
|---|------|-----------|
| 1 | Listings DB migration SQL | `supabase/migrations/20260601120000_listings_infrastructure.sql` |
| 2 | Supabase save + localStorage fallback | `listings_supabase_service.dart`, `add_listing_screen.dart` |
| 3 | `enrich-location` + INSERT trigger SQL | `supabase/functions/enrich-location/`, `20260601120001_...sql` |
| 4 | Dublin seed infrastructure | `sample_listings_dublin.dart` (seed v5) |
| 5 | Listing detail infrastructure | `listing_detail_screen.dart` |
| 6 | Unified Irish tier tooltips | `trust_tier_tooltips.dart` |
| 7 | Auth signup commute parity | `auth_screen.dart` |

**Local demo works without deploying Supabase.** Save tries remote insert when signed in; failures fall back to localStorage silently.

---

## Final sprint (pending — deploy & production)

Defer until you move off localStorage-only demo.

### 1. Supabase deploy
```bash
supabase db push
supabase functions deploy enrich-location --no-verify-jwt
supabase secrets set GOOGLE_PLACES_API_KEY=<your-key>   # optional
```

### 2. Trigger database settings
In Supabase SQL editor (required for auto `proximity_data` on INSERT):
```sql
ALTER DATABASE postgres SET app.settings.supabase_url = 'https://<project-ref>.supabase.co';
ALTER DATABASE postgres SET app.settings.service_role_key = '<service-role-key>';
```

### 3. Home feed remote sync
Wire home screen to fetch/merge `public.listings` when authenticated (save path exists; fetch does not yet).

### 4. E2E QA
- Sign in → add listing with geolocation → confirm `proximity_data` on row (after deploy)
- Card bottom subtext + detail infrastructure section
- Profile commute match on shared listings

```mermaid
flowchart TD
  done[Code complete] --> defer[Keep using localStorage]
  defer --> sprint[Final sprint]
  sprint --> deploy[supabase db push + function deploy]
  deploy --> trigger[DB trigger settings]
  trigger --> sync[Home feed remote sync]
  sync --> qa[E2E smoke test]
```

| Priority | Task | Status |
|----------|------|--------|
| Sprint | `supabase db push` + deploy `enrich-location` | **Pending** |
| Sprint | Postgres `app.settings` for trigger | **Pending** |
| Sprint | Home feed load from Supabase | **Pending** |
| Sprint | E2E smoke test | **Pending** |

---

## What to do now vs later

| Now (localStorage) | Final sprint |
|--------------------|--------------|
| Run app, test cards/detail/profile/signup | Deploy Supabase migrations + edge function |
| Use Dublin seed listings | Configure trigger DB settings |
| Add listings (local cache) | Remote listing fetch on home |
| Skip `supabase db push` | Full cloud persistence + auto transit enrichment |
