# Build TrueCircle web for staging with demo harness flags.

$root = Split-Path -Parent $PSScriptRoot
$config = Join-Path $root "env.staging.json"
$configExample = Join-Path $root "env.staging.json.example"

if (-not (Test-Path $config)) {
  Write-Host "Missing env.staging.json." -ForegroundColor Red
  Write-Host "Copy env.staging.json.example to env.staging.json and fill in real staging keys." -ForegroundColor Yellow
  if (Test-Path $configExample) {
    Write-Host "Example found at: $configExample" -ForegroundColor DarkYellow
  }
  exit 1
}

Set-Location $root
Write-Host "Building staging web for Vercel (CDN CanvasKit, smaller upload)..." -ForegroundColor Cyan
flutter build web --release --web-resources-cdn --dart-define-from-file=env.staging.json --tree-shake-icons
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$vercelConfig = Join-Path $root "vercel.json"
if (Test-Path $vercelConfig) {
  Copy-Item $vercelConfig (Join-Path $root "build\web\vercel.json") -Force
}

$vercelIgnore = Join-Path $root "scripts\vercel_web.vercelignore"
if (Test-Path $vercelIgnore) {
  Copy-Item $vercelIgnore (Join-Path $root "build\web\.vercelignore") -Force
}

Write-Host ""
Write-Host "Build complete. Serve locally:" -ForegroundColor Green
Write-Host "  .\scripts\serve_staging_web.ps1" -ForegroundColor White
Write-Host "  # then open http://localhost:8080" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Or build + serve in one step:" -ForegroundColor Cyan
Write-Host "  .\scripts\build_staging_web.ps1; .\scripts\serve_staging_web.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Optional SkWasm build (faster on supported browsers):" -ForegroundColor DarkYellow
Write-Host "  flutter build web --release --wasm --dart-define-from-file=env.staging.json" -ForegroundColor White
