# Run TrueCircle Dublin on Chrome with Supabase config from env.dev.json
# Setup: copy env.dev.json.example to env.dev.json and paste your real values.

$root = Split-Path -Parent $PSScriptRoot
$config = Join-Path $root "env.dev.json"

if (-not (Test-Path $config)) {
  Write-Host "Missing env.dev.json - copy env.dev.json.example and add your Supabase URL and anon key." -ForegroundColor Red
  exit 1
}

Set-Location $root
flutter run -d chrome --dart-define-from-file=env.dev.json
