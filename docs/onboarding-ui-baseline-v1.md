# Onboarding UI Baseline v1

**Checkpoint:** `Onboarding_UI_Baseline_v1`  
**Purpose:** Freeze the current seeker onboarding experience before destination intelligence and area recommendations.

## Frozen step IA

### Step 1 — Basics
- Listing Type (Independent Place / Shared Living)
- Persona (Student / Working Professional / Family)
- Student → Irish Guarantor (asked on Destination when required)
- Family → Adults + Children (persona-driven household fields on Basics where applicable)
- Languages

### Step 2 — Preferences
- Monthly Budget
- Current Status (Already in Dublin / Moving to Dublin)

Preferred Areas are **not** on Preferences. Area chip UI is preserved as `SeekerPreferredAreasSelector` for later Destination use.

### Step 3 — Destination
- Primary Destination (persona-specific presets + custom)
- Transport Mode
- Maximum Travel Time (default **60** min)
- Move-In Timeline
- Partner Destination (optional; professional / family)
- Recommended Areas **placeholder only** (no engine)

### Public Passport
- Profile Completeness (not “match readiness”)
- Budget
- Who You Are
- Commute
- Trust (+ verification status / next-step hint when incomplete)

## Shell / layout locks
- Full-viewport shell; **no page scroll**; **no left-column scroll**
- Content band ~70%; columns ~52/48
- Passport height aligned to left column including Continue
- Shared seeker selection style: soft grey fill, soft grey border, semibold text

## 1. What is frozen
- Step 1–3 information architecture and section order above
- Preferences reduced to budget + Dublin status only
- Passport public structure and Profile Completeness labeling
- Selection-state visual language across Basics / Preferences / Destination
- Location / area / proximity **product infrastructure** remains under the existing location-workflow freeze (do not reopen without approval)
- Demo-first auth entry (Demo Landlord / Demo Seeker)

## 2. What may still change
- Copy/microcopy polish within existing sections
- Density/spacing tweaks that do **not** reintroduce left-column scroll or break passport alignment
- Persona-specific destination preset **presentation** (labels/order) if needed for clarity
- Family Primary Location Driver persistence (currently UI-local)
- Wiring `SeekerPreferredAreasSelector` into Destination once recommendations exist
- Non-onboarding surfaces (seeker cards, listing detail, matching UI) per product priority

## 3. Known future work
- **Destination recommendations** — replace Recommended Areas placeholder with real suggestions
- **Inventory-aware areas** — recommend areas using live/available inventory
- **Commute explanations** — why a listing/area fits travel time and mode
- **Family school-area logic** — Workplace / School / Both → real recommendation inputs
- **Save → refreshed matches flow** — after onboarding save, refresh match results from the new profile

## Key files (reference)
| Area | Path |
|------|------|
| Shell | `lib/widgets/onboarding/seeker/seeker_onboarding_shell.dart` |
| Basics | `lib/widgets/onboarding/seeker/seeker_onboarding_basics_screen.dart` |
| Preferences | `lib/widgets/onboarding/seeker/seeker_onboarding_preferences_screen.dart` |
| Destination | `lib/widgets/onboarding/seeker/seeker_onboarding_destination_screen.dart` |
| Areas (reusable, unmounted) | `lib/widgets/onboarding/seeker/seeker_preferred_areas_selector.dart` |
| Passport | `lib/widgets/onboarding/contextual_passport_card.dart` |
| Completeness UI | `lib/widgets/profile_completeness_indicator.dart` |
| Orchestration | `lib/screens/profile_edit_screen.dart` |

## Restore
```bash
git checkout Onboarding_UI_Baseline_v1
# or
git switch -c restore/onboarding-ui-baseline Onboarding_UI_Baseline_v1
```
