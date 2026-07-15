# TrueCircle helper scripts (PowerShell / batch)



| Script | Purpose |

|--------|---------|

| `run_dublin.ps1` | Dev: `flutter run -d chrome` with `env.dev.json` |

| `run_dublin.bat` | Same as above for cmd.exe |

| `build_staging_web.ps1` | Release web build with `env.staging.json` (CanvasKit default on Flutter 3.41+) |

| `serve_staging_web.ps1` | Serve `build\web` on http://localhost:8080 (no Python) |

| `deploy_vercel_web.ps1` | Package `build\web` as prebuilt static output and deploy to Vercel (`-Login` first time) |

| `seed_demo_applicants.ps1` | **Demo check** (default) or optional DB seed (`-Database`) |

| `trim_logo.ps1` | Crop logo assets |



## OpenStreetMap POI seeding (local catalog)



One-time **manual** seed for `lib/data/generated/dublin_poi_catalog.g.dart`. The app reads this file locally — no Overpass calls at runtime. Re-run **quarterly** (or when debug logs warn the catalog is >90 days old).



Uses the same batched Overpass query as live Phase 2 enrichment (`buildFullOverpassQuery`). Primary endpoint: `overpass.private.coffee` (commercial-friendly); fallback: `overpass-api.de`.



```powershell

# 1. Estimate request budget (~1 batched query per grid cell)

dart run tool/seed_dublin_pois.dart --estimate --region=dublin



# 2. Dry-run three standard Dublin pins (city centre, D15, Swords)

dart run tool/seed_dublin_pois.dart --dry-run-samples



# 3. Dry-run one custom cell

dart run tool/seed_dublin_pois.dart --dry-run --cell=53.412,-6.418



# 4. Full Dublin sweep (only after confirming estimate + dry-runs)

dart run tool/seed_dublin_pois.dart --full --region=dublin

```



No API key required. Transit stays on `DublinTransitNetwork`; live Overpass remains Phase 2 secondary enrichment.



Attribution: show **© OpenStreetMap contributors** wherever map/location data is displayed (listing creation amenities + profile footer).



Future cities: add a new entry to `tool/region_seed_config.dart`.



## Staging demo (recommended — no DB seed)



1. Copy `env.staging.json.example` → `env.staging.json` (or use existing `env.staging.json`)

2. Ensure `DEMO_AUTH_BYPASS` and `DEMO_MOCK_HARNESS` are `true`

3. Build: `.\scripts\build_staging_web.ps1`

4. Serve: `.\scripts\serve_staging_web.ps1`

5. Open http://localhost:8080 → **Enter as Demo Landlord**



Applicants are injected in-app; you do **not** need Supabase CLI or SQL seeding.



## Optional: seed Supabase database



Only needed if you want live RPC rows (not required for demo showcase):



```powershell

.\scripts\seed_demo_applicants.ps1 -InstallCli   # download CLI to .tools\

.\.tools\supabase.exe login

.\scripts\seed_demo_applicants.ps1 -Database

```


