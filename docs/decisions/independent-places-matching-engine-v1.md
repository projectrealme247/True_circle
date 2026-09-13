# TrueCircle Independent Places Matching Engine v1

Status: DOCUMENTED FROM IMPLEMENTATION  
Date: 2026-08-02  
Source of truth: `lib/utils/listing_match_engine.dart` (rent tower), `lib/utils/viewer_profile.dart`

## Purpose

Rank Independent Places (entire-home / rent) listings for a seeker by fit. Listings earn a compatibility score out of 100 from weighted signals, then a trust multiplier scales that score into a final ranking score. Pets and smoking conflicts apply a soft penalty only. The Independent Places hard filter does not exclude listings by occupant, gender, or student type.

---

## Scoring Model

Marketplace ranking uses six weighted buckets (Budget, Bedrooms / Layout, Location / Commute, Move-In Timing, Language, Lifestyle). Occupant Match and Furnished Listing Signal share the Lifestyle bucket. Pets and Smoking do not add positive points; they apply a soft penalty when mismatched. Persona selects the weight table. Max compatibility score before trust: **100**.

### Budget

- **Weight:** Student 30 · Working Professional 20 · Family 25 · Default 25  
- **Method:** Budget weight × fit fraction vs seeker budget max. Stretch at 110% of max (0.5); hard cap at 125% of max (0.2).  
- **Full / Partial / None:** ≤ max → full; ≤110% → 0.5; ≤125% → 0.2; above / missing → 0. Does not hard-exclude.

### Bedrooms / Layout

- **Weight:** Student 15 · Working Professional 15 · Family 30 · Default 20  
- **Method:** All-or-nothing when seeker preferred layout fits listing bed/layout rules.  
- **Full / Partial / None:** Fit → full weight; else 0. No partial credit.

### Location / Commute

- **Weight:** Student 20 · Working Professional 25 · Family 20 · Default 20  
- **Method:** Requires city alignment. No commute intent → 1.0 after city match. Commute over budget → 0.5; else 1.0.  
- **Full / Partial / None:** City + commute OK → full; city OK + over commute → 0.5; no city → 0.

### Move-In Timing

- **Weight:** Student 20 · Working Professional 15 · Family 10 · Default 15  
- **Method:** All-or-nothing when timing match earns score (Strong / Good / Flexible). Weak does not earn.  
- **Full / Partial / None:** Match → full; else 0. Does not hard-exclude.

### Language

- **Weight:** Student 10 · Working Professional 10 · Family 5 · Default 10  
- **Method:** Shared language between seeker and host (mother tongue / host language). Requires seeker mother tongue.  
- **Full / Partial / None:** Shared language → full; else 0. No partial Language credit.

### Occupant Match

- **Weight:** Half of Lifestyle (Lifestyle: Student 5 · Working Professional 15 · Family 10 · Default 10).  
- **Method:** One of two equal Lifestyle signals; occupant type alignment or search occupant exact.  
- **Full / Partial / None:** Match contributes 0.5 of Lifestyle fraction; unmatched contributes 0. Does not hard-exclude.

### Furnished Listing Signal

- **Weight:** Half of Lifestyle (same Lifestyle weights as Occupant Match).  
- **Method:** Listing furnishing text is non-empty, contains “furnished”, and does not contain “unfurnished”.

#### Current V1 Behaviour

- Listings marked as furnished receive the furnishing contribution.
- This is not currently a seeker-preference match.
- No seeker furnishing preference exists in Matching Engine v1.

### Pets

- **Weight:** None (soft penalty only, shared with Smoking).  
- **Method:** Listing explicitly disallows pets and seeker household has pets → mismatch.  
- Does not hard-exclude on Independent Places.

### Smoking

- **Weight:** None (soft penalty only, shared with Pets).  
- **Method:** Listing explicitly disallows smoking and seeker is smoking-ok → mismatch.  
- Does not hard-exclude on Independent Places.

---

## Persona Weight Sets

Selected from seeker occupant type text. Each set sums to **100**.

### Student

| Bucket | Weight |
|---|---|
| Budget | 30 |
| Move-In Timing | 20 |
| Location / Commute | 20 |
| Bedrooms / Layout | 15 |
| Language | 10 |
| Lifestyle (Occupant + Furnished Listing Signal) | 5 |
| **Total** | **100** |

### Working Professional

| Bucket | Weight |
|---|---|
| Location / Commute | 25 |
| Budget | 20 |
| Move-In Timing | 15 |
| Bedrooms / Layout | 15 |
| Lifestyle (Occupant + Furnished Listing Signal) | 15 |
| Language | 10 |
| **Total** | **100** |

### Family

| Bucket | Weight |
|---|---|
| Bedrooms / Layout | 30 |
| Budget | 25 |
| Location / Commute | 20 |
| Move-In Timing | 10 |
| Lifestyle (Occupant + Furnished Listing Signal) | 10 |
| Language | 5 |
| **Total** | **100** |

### Default

| Bucket | Weight |
|---|---|
| Budget | 25 |
| Bedrooms / Layout | 20 |
| Location / Commute | 20 |
| Move-In Timing | 15 |
| Language | 10 |
| Lifestyle (Occupant + Furnished Listing Signal) | 10 |
| **Total** | **100** |

---

## Penalties

| Penalty | Amount | When |
|---|---|---|
| Pet / smoking soft penalty | −15 (once) | Pet and/or smoking mismatch; not stacked |
| Pre-arrival listing factor | × 0.9 | Pre-arrival seeker and listing track “all students” |

---

## Hard Exclusions

`_rentHardFilter` never excludes. Occupant, gender, and student type are ranking signals only for Independent Places.

Shared evaluate path may still exclude when:

1. Onboarding incomplete (missing city or budget max).
2. Student track conflict (pre-arrival seeker vs on-campus-only listing).

Not hard exclusions: budget overage, layout mismatch, language mismatch, weak timing, pet/smoking mismatch, bathroom preference, security deposit.

---

## Trust Multipliers

| Stage | Multiplier |
|---|---|
| Anonymous | 0.4 |
| Casual Browser | 0.7 |
| Social Verified | 0.9 |
| ID Verified | 1.0 |

Seeker Casual Browser with verified pre-arrival docs → effective seeker multiplier **0.9**. No seeker → seeker multiplier **1.0**.

```
Combined Trust Multiplier = (Host Trust Multiplier + Seeker Trust Multiplier) / 2
```

---

## Final Score Calculation

```
Lifestyle Fraction =
  (1 if Occupant Match else 0 + 1 if Furnished Listing Signal else 0) / 2

Compatibility Score =
  (Budget weight × budget fit fraction)
  + (Bedrooms / Layout weight if layout matches else 0)
  + (Location / Commute weight × location/commute fraction)
  + (Timing weight if timing matches else 0)
  + (Language weight if language matches else 0)
  + (Lifestyle weight × Lifestyle Fraction)
  − (15 if pet/smoking mismatch else 0)

Compatibility Score = round, clamp 0…100

Final Score = round(Combined Trust Multiplier × Compatibility Score)
Final Score = round(Final Score × Pre-arrival listing factor)
Match Percentage = (Final Score / 100) × 100, clamp 0…100
```

In Circle: network circle connection and match percentage ≥ 75%.

---

## Bathroom Preference (Independent Places)

**Status**

- Collected
- Persisted
- Hydrated

**Current Usage**

- Not used in Independent Places matching.

**Note**

Bathroom Preference is currently only consumed by Shared Living matching.

---

## Security Deposit

**Status**

- Collected on landlord side

**Current Usage**

- Not used in Independent Places matching.
- Not used in scoring.
- Not used in ranking.

**Note**

Reserved for future affordability scoring review.

---

## V2 Backlog

Potential future matching signals:

- Bathroom Preference
- Security Deposit Affordability
- Seeker Furnishing Preference

These are collected or partially available but are not part of Matching Engine v1 scoring.
