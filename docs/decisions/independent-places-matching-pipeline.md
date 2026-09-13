# Independent Places Matching Pipeline

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

## Summary

Independent Places operates under a startup marketplace philosophy:

**"Rank, don't exclude."**

Low inventory is a greater risk than imperfect matches.

---

## Stage 0: Completeness Gate

Required for publication:

- Rent
- Location / Coordinates
- Furnishing Status
- Lease Type
- Available From OR Available Now

Missing required data:

- Listing not published
- Landlord prompted to complete listing

---

## Stage 1: Candidate Pool

All published listings enter.

Hard Exclusions:

1. Incomplete listing data

**Implementation note (Matching Engine v1, 2026-08-02):**  
Furnishing is **not** a hard exclusion. Live scoring uses a **Furnished Listing Signal** (listing marked furnished receives lifestyle contribution). This is not a seeker-preference match; no seeker furnishing preference exists in Matching Engine v1. See `independent-places-matching-engine-v1.md`.

---

## Stage 2: Compatibility Flags

Flag but do not exclude:

- Over budget
- Longer commute than requested
- Tenure mismatch
- Property type mismatch

No thresholds are locked at this stage.

---

## Stage 3: Ranking

Ranking may consider:

- Budget fit
- Commute fit
- Move-in timing
- Persona fit
- Tenure alignment
- Property type alignment

Ranking design is a separate decision.

---

## Stage 4: Explanation Layer

Required in V1.

Examples:

- ✓ Within budget
- ✓ Furnished (Furnished Listing Signal — listing is furnished)
- ✓ Available when needed
- ⚠ Above stated budget
- ⚠ Longer commute than requested
- ⚠ Different lease type

---

## Locked Startup Principle

### Phase 1
Rank, don't exclude.

Hard Exclusions:

- Incomplete listing data

Furnished Listing Signal is ranking-only (not an exclusion). Everything else remains visible and explainable.

### Matching Engine v1 alignment (2026-08-02)

- **Bathroom Preference:** Collected, persisted, hydrated — not used in Independent Places matching (Shared Living only).
- **Security Deposit:** Collected on landlord side — not used in matching, scoring, or ranking; reserved for future affordability review.
- **Furnished Listing Signal:** Replaces prior “Furnishing Match / preference” wording; see `independent-places-matching-engine-v1.md`.
- **V2 backlog (not in v1 scoring):** Bathroom Preference, Security Deposit Affordability, Seeker Furnishing Preference.

### Phase 2 Review Trigger

Median listings per active seeker ≥ 15

At that point Budget and Commute exclusion policies may be reconsidered.

---

## Reopen Criteria

Only reopen if:

1. New schema fields are added.
2. Marketplace inventory materially changes.
3. Production data shows severe matching quality issues.

Do not reopen during ranking discussions.

Treat this document as the source of truth for all future Independent Places ranking work.
