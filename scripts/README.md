# TrueCircle helper scripts (PowerShell / batch)

| Script | Purpose |
|--------|---------|
| `run_dublin.ps1` | Dev: `flutter run -d chrome` with `env.dev.json` |
| `run_dublin.bat` | Same as above for cmd.exe |
| `build_staging_web.ps1` | Release web build with `env.staging.json` (CanvasKit default on Flutter 3.41+) |
| `serve_staging_web.ps1` | Serve `build\web` on http://localhost:8080 (no Python) |
| `seed_demo_applicants.ps1` | **Demo check** (default) or optional DB seed (`-Database`) |
| `trim_logo.ps1` | Crop logo assets |

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
