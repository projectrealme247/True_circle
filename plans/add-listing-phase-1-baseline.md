# Add Listing — Phase 1 Baseline Reference

**Created:** 2026-07-02  
**Git tag:** `ref/add-listing-phase-1-baseline`  
**Commit:** `06fe038` — `feat: redesign listing creation with map pin location and premium UI`  
**Branch:** `milestone/phase-1`

Use this document and tag to restore or compare against the listing-creation work as it stood at Phase 1 kickoff.

## How to return to this point

```powershell
# Checkout the exact code state
git fetch --tags
git checkout ref/add-listing-phase-1-baseline

# Or create a recovery branch from the tag
git checkout -b recovery/add-listing-baseline ref/add-listing-phase-1-baseline
```

## Architecture

### Entry screen
- `lib/screens/add_listing_screen.dart` — thin shell; delegates to `ListingCreationForm`
- Prefill from profile via `ProfilePortalInheritanceService` when landlord track

### 3-step wizard
- `lib/widgets/listing_creation/listing_creation_form.dart`
- **Step 1 — Property:** tenure, listing type, property type, furnishing, beds/baths, rent
- **Step 2 — Location:** map pin-drop, GPS, optional Eircode, privacy checkbox, proximity
- **Step 3 — Listing:** household profile / room config (shared), media, title, description, optional enhancements

### Step order (Step 3 differs by type)
- **Entire place:** media → title → description → optional enhancements
- **Shared room:** household profile → room configuration → media → title → description → optional enhancements

### Progress / navigation
- `lib/widgets/gamified_form_wizard.dart` — spread-out clickable step links for completed steps

## Location (Step 2) — pin-drop solution

**Problem solved:** Forward Eircode/address geocoding was unreliable (wrong city, "The Ward DED 1986" noise).

**Approach:** User-confirmed coordinates are the source of truth.

| Component | Role |
|-----------|------|
| `lib/widgets/listing_creation/location_pin_field.dart` | `flutter_map` OSM map; tap-to-pin; search-to-centre; green "Pin placed" confirmation |
| `lib/services/nominatim_forward_web.dart` | `searchAddress` (pan map), `reverseGeocode` (coords → label), `_isNoisyPart` filters DED cruft |
| `lib/services/overpass_amenities_service.dart` | Proximity from pin coords; 1s retry on failure |
| `FastLocationService` | "Use current location" GPS path |

**UX flow:**
1. Search address → map centres + pin placed → green confirmation badge
2. Or tap map to drop pin
3. Or "Use current location"
4. Reverse geocode shows cleaned address below map
5. Optional Eircode field (text only, stored, not used for geocoding)
6. "I don't want to display the exact address" checkbox
7. Neighborhood proximity auto-populated from Overpass; manual override via "Edit Proximity"

**Dependencies:** `flutter_map: ^7.0.2`, `latlong2: ^0.9.1`

## Design system (listing form)

`lib/widgets/listing_creation/listing_creation_primitives.dart`

- Calm premium aesthetic: white surfaces, grey borders, no coral/pink selection fills
- Selected choice tiles: `#6B7280` border + subtle 3D elevation (`listingChoiceSelectedShadow`)
- Shared helper: `listingChoiceBoxDecoration(selected: …)`
- Custom `_DurationUnitDropdown` — opens downward (same pattern as BER field)
- `ListingDateInputField` — stateless `InputDecorator` (no setState-during-build)
- Room config: expandable accordion panels (one expanded at a time)
- Photo tips: collapsed by default with expand/collapse

## Key services (location / proximity)

```
lib/services/nominatim_forward.dart (+ _web, _stub)
lib/services/nominatim_reverse.dart (+ _web, _stub)
lib/services/overpass_amenities_web.dart
lib/services/eircode_lookup_service.dart
lib/services/neighborhood_amenities_service.dart
lib/models/neighborhood_amenity_tag.dart
lib/models/irish_address_suggestion.dart
```

## Proximity categories (Overpass)

Schools, grocery, bus, Luas, DART, pubs, cafes, restaurants, gyms, parks, pharmacies, ATMs, business parks, attractions — radii defined in `overpass_amenities_web.dart`.

## Related rules

- `.cursor/rules/demo-auth-entry.mdc` — demo landlord/seeker must remain primary auth entry
- `.cursor/rules/add-listing-baseline.mdc` — do not regress listing creation without explicit request

## Verification checklist

- [ ] Property step: choice tiles show grey border + elevation when selected
- [ ] Location: search "9 hollywoodrath park" → pin + green confirmation → proximity populates
- [ ] Location: "Use current location" places pin and resolves amenities
- [ ] Address label does not show "The Ward DED 1986"
- [ ] Step links clickable for completed steps
- [ ] Entire place vs shared room show correct Step 3 field order

## What this baseline intentionally removed / avoided

- Eircode-to-coordinates as primary geocoding path for listing location
- Nominatim forward geocoding as final coordinate source
- Heavy black selection borders on property choice tiles
