# CircleKey

**Where trust meets home.**

CircleKey is a trust-weighted property marketplace for renting, sharing, and buying homes in India. Unlike flat listing sites, CircleKey ranks properties using a progressive trust funnel and cultural compatibility matching.

## Key Features

- **Three marketplace towers** -- Rent, Share (roommates/PG), and Buy/Sell, each with tower-specific scoring
- **Trust-as-multiplier ranking** -- `Final Score = TrustMultiplier x CompatibilityScore`. Verified listings always outrank unverified ones
- **3-stage progressive trust funnel** -- Stage 1 (cultural profile), Stage 2 (LinkedIn/social verification), Stage 3 (Aadhaar ID + passkey)
- **Cultural compatibility matching** -- Food preference, language, nativity, occupant type, gender, and lifestyle signals
- **Circle communities** -- Passive trust groups based on shared cultural markers and verification level
- **Schedule property viewings** -- Book an appointment to visit a listing directly from the app

## Tech Stack

| Layer | Technology |
|---|---|
| UI | Flutter 3.5+, Material 3, Google Fonts, GoRouter |
| Backend | Supabase (initialized, local-first until fully wired) |
| Local storage | localStorage (web) / SharedPreferences (mobile/desktop) |
| Location | Geolocator, Geocoding |
| Security | local_auth (biometrics) |

## Getting Started

```bash
flutter pub get
flutter run -d chrome
```

For mobile:

```bash
flutter run -d android
flutter run -d ios
```

## Architecture

```
lib/
  main.dart                     # App entry, Supabase init, CircleKeyApp
  router/app_router.dart        # GoRouter route definitions
  screens/                      # All app screens (home, auth, listing detail, etc.)
  services/                     # Trust, profile, and listings storage services
  utils/                        # Match engine, pipeline, viewer profile, listing data
  data/                         # Sample seed listings
  theme/                        # Typography, scroll behavior, marketplace theme
  widgets/                      # Reusable UI components
```

## Trust Multiplier Model

| Trust Stage | Multiplier | Meaning |
|---|---|---|
| Stage 0 (Anonymous) | 0.4x | Visible but buried |
| Stage 1 (Casual) | 0.7x | Basic profile exists |
| Stage 2 (Social) | 0.9x | LinkedIn/social verified |
| Stage 3 (ID Verified) | 1.0x | Full ranking power |
