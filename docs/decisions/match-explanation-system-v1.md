# Match Explanation System v1

Status: SPECIFICATION (from audited implementation)  
Date: 2026-08-02  
Source: `lib/utils/listing_match_engine.dart`  
Scope: Shared Living (share tower) and Independent Places (rent tower) only  

This document maps **matching signals that affect score** and proposes **user-facing explanations**. It does not expose weights or change scoring.

---

## Principles

1. Explain fit in plain language — never show points, percentages of buckets, or weight tables.
2. Group explanations into **Positive**, **Neutral**, and **Soft Warnings**.
3. Cap visible reasons (current engine shows up to 4).
4. Hard exclusions remove the listing; they are not soft explanations.
5. Trust and circle badges are contextual, not fit-score signals.

---

# 1. Shared Living

## Scoring signals (affect rank)

| Signal | Internal Logic | User Explanation |
|---|---|---|
| Language | Seeker mother tongue / spoken languages overlap host mother tongue or host language | Speaks a language you share |
| Food / kitchen | Food tokens match, search food exact, or lifestyle/kitchen compatibility | Food preference fits this home |
| Occupant / roommate type | Seeker occupant type aligns with listing occupant / roommate type (or search occupant exact) | Fits your household type |
| Budget | Rent vs seeker budget max (full / stretch / hard-cap fractions) | Within your budget *(or soft warning if slightly over)* |
| Lifestyle compatibility | Diet/kitchen lifestyle flags and preferences compatible | Lifestyle looks compatible |
| Quiet hours | Listing prefers quiet hours and seeker’s schedule aligns (day/flexible) | Quiet hours suit your routine |
| Daily schedule | Seeker and listing schedules compatible (or either flexible) | Daily rhythm fits |
| Bathroom type | Canonical bathroom preference compatible with listing bathroom | Bathroom type matches what you want |
| Room type | Canonical room layout (private/shared) compatible with listing | Room type matches what you want |
| Move-in timing | Move-in windows / availability earn timing score (strong/good/flexible) | Available when you need to move |

## Hard exclusions (not soft explanations)

| Signal | Internal Logic | User Explanation |
|---|---|---|
| Pets conflict | Listing disallows pets and seeker has pets | *(Listing hidden — not shown as a soft reason)* |
| Smoking conflict | Listing disallows smoking and seeker is smoking-ok | *(Listing hidden — not shown as a soft reason)* |

## Positive Reasons

| Signal | Internal Logic | User Explanation |
|---|---|---|
| Language | `languageMatch` | Speaks a language you share |
| Food | `foodMatch` (when not already covered by search exact) | Food preference fits this home |
| Occupant / roommate | `roommateTypeMatch` / occupant alignment | Fits your household type |
| Budget exact / in range | `budgetExactFit` / `priceFit` | Perfect budget fit / Within your budget |
| Lifestyle | `lifestyleCompatible` | Lifestyle looks compatible |
| Room type available | Listing has a room type string (`roomTypeMatch`) | Room type looks right |
| Location | City / host city aligns (`locationMatch`) | In an area that matches your city |
| Timing (earning quality) | Strong / Good / Flexible timing match | Strong timing match / Good timing match / Flexible timing match |
| Commute within budget | Commute penalty zero with commute intent | Commute fits your travel budget |
| Search exact (food/city/occupant) | Structured search exact hit | Matches your search: {label} |
| In your circle | Network + high match % | In your circle |
| Host ID verified | Host trust stage ID verified | ID verified host |
| Host socially verified | Host trust stage social verified | Socially verified host |
| Pre-arrival docs | Casual seeker with verified pre-arrival docs | Pre-arrival documents verified |

## Neutral Reasons

| Signal | Internal Logic | User Explanation |
|---|---|---|
| Related to search | Search relaxed / related results | Related to your search |
| Bathroom compatible | Compatible including “no preference” | Bathroom setup works for you |
| Room layout compatible | Compatible including empty preference | Room setup works for you |
| Quiet hours / schedule | Contributes to lifestyle fraction when present | Daily routine looks workable |

*(Neutral = supportive context when shown; may omit if positive reasons fill the cap.)*

## Soft Warnings

| Signal | Internal Logic | User Explanation |
|---|---|---|
| Budget soft over | Price above stretch start and at or below hard cap | Slightly over your max budget |
| Weak timing | Timing quality weak | Weak timing match |
| Commute over budget | Commute over-budget flag | Commute may exceed your budget |

---

# 2. Independent Places

## Scoring signals (affect rank)

| Signal | Internal Logic | User Explanation |
|---|---|---|
| Budget | Rent vs seeker budget max (full / stretch / hard-cap fractions) | Within your budget |
| Bedrooms / layout | Preferred layout fits listing bed count / layout | Bedrooms fit what you need |
| Location / city | Seeker city aligns with listing location or host city (or search city exact) | Matches your city |
| Commute | After city match: full credit if no commute intent or within budget; half credit if over budget | Commute fits your travel budget *(or soft warning if over)* |
| Move-in timing | Timing match earns score | Available when you need to move |
| Language | Shared language with host | Speaks a language you share |
| Occupant match | Seeker occupant type aligns (or search occupant exact) — drives lifestyle fraction alone | Fits your household type |
| Pets / smoking mismatch | Soft penalty when listing forbids pets/smoking against seeker flags | *(No positive reason; may surface as soft warning in future UI — currently score-only)* |

## Hard exclusions

Independent Places rent hard filter does not exclude by occupant/gender/student. Shared evaluate path may still exclude incomplete onboarding or student-track conflict.

## Positive Reasons

| Signal | Internal Logic | User Explanation |
|---|---|---|
| Budget in range | `priceFit` | Within your budget |
| Bedrooms / layout | `bhkMatch` | Bedrooms fit what you need |
| Occupant | `occupantMatch` (when not search-exact) | Fits your household type |
| Location | `locationMatch` (when not search-exact) | Matches your city |
| Timing (earning quality) | Strong / Good / Flexible | Strong timing match / Good timing match / Flexible timing match |
| Commute within budget | `commuteWithinBudget` | Commute fits your travel budget |
| Food (if set) | `foodMatch` | Food preference fits this home |
| Student background | `studentMatch` | Student background fits |
| Search exact | Food / city / occupant search hit | Matches your search: {label} |
| In your circle | Network + high match % | In your circle |
| Host ID / social verified | Host trust stage | ID verified host / Socially verified host |
| Pre-arrival docs | Verified pre-arrival upgrade | Pre-arrival documents verified |

## Neutral Reasons

| Signal | Internal Logic | User Explanation |
|---|---|---|
| Related to search | Relaxed / related search | Related to your search |

## Soft Warnings

| Signal | Internal Logic | User Explanation |
|---|---|---|
| Commute over budget | `commuteOverBudget` | Commute may exceed your budget |
| Weak timing | Timing quality weak | Weak timing match |

*(Budget stretch for Independent Places affects score fraction; Share currently surfaces “Slightly over your max budget” — IP does not currently emit that soft-warning string.)*

---

# 3. Match Explanation System v1 — presentation rules

## Tone

- Positive: clear confirmation of fit  
- Neutral: helpful context without claiming a strong match  
- Soft warning: caution without hiding the listing  

## Ordering (recommended)

1. Soft warnings (so seekers see caveats first when present)  
2. Positive fit reasons  
3. Trust / circle / search context  
4. Neutral fillers only if slots remain  

## Cap

Show at most **4** explanations (matches current engine).

## Do not show

- Weight values or bucket names  
- Raw field keys (`food_preference`, `lifestyle_flags`, …)  
- Internal tokens (`private_ensuite`, `non_veg_allowed`, …)  
- Score arithmetic  

## Marketplace split

| Marketplace | Explanation set |
|---|---|
| Shared Living | Section 1 |
| Independent Places | Section 2 |

Do not mix Share-only signals (bathroom, room layout lifestyle, diet kitchen) into Independent Places explanations unless those signals later join IP scoring.

---

# 4. Signals intentionally not explained as IP ranking advantages

| Field | Note |
|---|---|
| Bathroom preference | Collected for seekers; Shared Living matching only |
| Security deposit | Landlord-collected; not in matching/scoring/ranking |
| Furnished listing | No longer a ranking advantage after removal from IP lifestyle fraction |

---

# 5. Out of scope for v1

- Redesigning scoring weights  
- New signals  
- Implementing a new reason builder (this document specifies copy and grouping only)  
- Buy-tower explanations (not Independent Places / Shared Living)
