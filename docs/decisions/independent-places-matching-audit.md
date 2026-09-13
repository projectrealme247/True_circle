# Independent Places Matching Inputs Audit

Status: LOCKED
Date: 2026-07-29

## Scope
Independent Places only.

Excluded:
- Shared Living
- District Boost
- Ranking formulas
- Scoring
- Weights
- Schema changes

---

## Hard Constraints

1. Budget ↔ Rent
2. ~~Furnishing Preference ↔ Furnishing~~ → **Furnished Listing Signal** (implementation, 2026-08-02): listing marked furnished receives scoring contribution; not a seeker-preference match; no seeker furnishing preference in Matching Engine v1
3. Tenure Preference ↔ Lease Type
4. Destination + Transport Mode + Max Travel Time ↔ Listing Location

---

## Strong Signals

1. Move-In Timeline ↔ Available From

---

## Weak Signals

1. Property Type Preference ↔ Property Type
2. Persona ↔ Listing Facts

---

## Context Fields

1. Residential Status

Purpose:
- Verification/document logic only
- Not matching
- Not ranking

---

## Informational

1. Student Guarantor
2. BER Rating
3. Parking
4. Nearby Amenities
5. Host Name + Identity
6. Photos
7. Pets Policy
8. Bathrooms
9. Bedrooms
10. Availability Flexibility
11. Expected Utility Costs
12. Bathroom Preference (collected / persisted / hydrated — not used in Independent Places matching; Shared Living only)
13. Security Deposit (collected on landlord side — not used in matching, scoring, or ranking; reserved for future affordability review)

---

## Matching Engine v1 alignment (2026-08-02)

See `independent-places-matching-engine-v1.md`.

**Furnished Listing Signal (not “Furnishing Match”):** listings marked furnished receive the furnishing contribution; not a seeker-preference match.

**V2 backlog (not in v1 scoring):** Bathroom Preference, Security Deposit Affordability, Seeker Furnishing Preference.

---

## Explicitly Rejected

- Bedroom estimation formulas
- Family-size-to-bedroom rules
- Occupancy calculations
- Minimum lease term field
- Bills adjustments
- Shared Living concepts
- Pets matching until seeker-side pets exists
- New schema additions

---

## Reopen Criteria

This decision may only be reopened if:

1. A new matching field is added to the schema.
2. User testing reveals a matching failure.
3. Production data shows a measurable mismatch problem.

Otherwise this audit remains locked.
