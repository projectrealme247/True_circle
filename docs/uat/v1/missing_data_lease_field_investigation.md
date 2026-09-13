# Lease field investigation (Missing-Data Listing Audit)

Read-only. Finding: "lease missing on all Independent Places listings."

## Verdict

**VALID** — not an audit wrong-key bug. Canonical IP lease key is `agreement_type`; all 50 Rent seeds lack it (and every other lease-related key).

## 1. Field the audit searched for

| Layer | Value |
|-------|--------|
| Checklist field ID | `lease` |
| Presence check | `TenurePreference.fromListing(item) != null` |
| Actual map key read | `agreement_type` (`TenurePreference.listingKey`) |

Sources: `test/missing_data_listing_audit_test.dart` (`_ipFieldDefs`, `_ipPresence`), `docs/uat/v1/missing_data_listing_audit.md`.

## 2. Lease-related keys in IP schema

| Key | Role |
|-----|------|
| `agreement_type` | Canonical listing tenure (Temporary / Long-Term) — form, highlights, serializer |
| `sublet_duration_value` / `sublet_duration_unit` | Duration when temporary (highlights + form payload) |
| `temporary_duration_value` / `temporary_duration_unit` | Shared-room slot alias of sublet duration |
| `preferred_lease_months` | Seeker preference; also read by matcher/search on **listings** |
| `tenure_preference` / `lease_preference` / `lease_duration` | Seeker/session, not listing create payload |

## 3. Counts (SampleListingsDublin Rent = 50)

All listed keys: **0/50** populated. `TenurePreference.fromListing`: **0/50**.

## 4. Wrong field name?

**NO** — checklist id `lease` maps correctly to `agreement_type`.

## 5. Classification

**VALID finding** (seed gap). Optional related note: matcher hard-filter uses `preferred_lease_months` on listings while create/highlights use `agreement_type` + `sublet_duration_*` — separate schema inconsistency, not the cause of this audit miss (both families empty in seed).
