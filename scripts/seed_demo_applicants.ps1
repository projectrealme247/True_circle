# Seeds staging with synthetic Dublin demo applicants.
#
# DEFAULT (no flags): verifies in-app demo harness — no Supabase CLI required.
# -Database:          optional SQL seed via linked Supabase project (advanced).
# -InstallCli:        download Supabase CLI into .tools\

param(
  [switch]$InstallCli,
  [switch]$Database
)

$root = Split-Path -Parent $PSScriptRoot
$seedFile = Join-Path $root "supabase\seed\demo_applicants.sql"

function Read-EnvJson {
  param([string]$Path)
  if (-not (Test-Path $Path)) { return $null }
  try {
    return Get-Content $Path -Raw | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Get-ProjectRefFromEnv {
  $staging = Read-EnvJson (Join-Path $root "env.staging.json")
  $dev = Read-EnvJson (Join-Path $root "env.dev.json")
  $env = if ($staging) { $staging } elseif ($dev) { $dev } else { $null }
  if (-not $env) { return $null }
  $url = $env.SUPABASE_URL.ToString().Trim()
  if ($url -match 'https://([a-z0-9]+)\.supabase\.co') {
    return $Matches[1]
  }
  return $null
}

function Test-DemoHarnessReady {
  $staging = Read-EnvJson (Join-Path $root "env.staging.json")
  $dev = Read-EnvJson (Join-Path $root "env.dev.json")
  foreach ($cfg in @($staging, $dev)) {
    if ($null -eq $cfg) { continue }
    $mock = $cfg.DEMO_MOCK_HARNESS
    $auth = $cfg.DEMO_AUTH_BYPASS
    if ($mock -eq $true -or $mock -eq "true") { return $true }
    if ($auth -eq $true -or $auth -eq "true") { return $true }
  }
  return $false
}

function Resolve-SupabaseCli {
  $cmd = Get-Command supabase -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $localTools = Join-Path $root ".tools\supabase.exe"
  if (Test-Path $localTools) { return $localTools }
  return $null
}

function Install-SupabaseCliLocal {
  $toolsDir = Join-Path $root ".tools"
  $target = Join-Path $toolsDir "supabase.exe"
  if (Test-Path $target) { return $target }

  New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
  $releaseUrl = "https://github.com/supabase/cli/releases/latest/download/supabase_windows_amd64.tar.gz"
  $archive = Join-Path $env:TEMP "supabase_cli_windows_amd64.tar.gz"
  $extractDir = Join-Path $env:TEMP "supabase_cli_extract"

  Write-Host "Downloading Supabase CLI to $toolsDir ..." -ForegroundColor Cyan
  Invoke-WebRequest -Uri $releaseUrl -OutFile $archive -UseBasicParsing

  if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
  tar -xzf $archive -C $extractDir
  $exe = Get-ChildItem -Path $extractDir -Filter "supabase.exe" -Recurse | Select-Object -First 1
  if (-not $exe) { throw "Downloaded archive did not contain supabase.exe" }
  Copy-Item $exe.FullName $target -Force
  return $target
}

function Ensure-SupabaseConfigToml {
  $configPath = Join-Path $root "supabase\config.toml"
  if (Test-Path $configPath) { return $configPath }
  Write-Host "Creating supabase\config.toml ..." -ForegroundColor DarkYellow
  @"
project_id = ""

[api]
enabled = true
port = 54321

[db]
port = 54322
major_version = 15
"@ | Set-Content -Path $configPath -Encoding utf8
  return $configPath
}

# --- Default path: in-app demo (no CLI / no link) ---
if (-not $Database) {
  $demoReady = Test-DemoHarnessReady
  $projectRef = Get-ProjectRefFromEnv

  Write-Host ""
  Write-Host "TrueCircle demo applicant setup" -ForegroundColor Cyan
  Write-Host "================================" -ForegroundColor Cyan
  Write-Host ""

  if ($demoReady) {
    Write-Host "In-app demo harness is ENABLED (DEMO_MOCK_HARNESS / DEMO_AUTH_BYPASS)." -ForegroundColor Green
    Write-Host "9 synthetic applicants load when you use Enter as Demo Landlord." -ForegroundColor Green
    Write-Host "No database seed or Supabase CLI is required for the showcase." -ForegroundColor Green
  } else {
    Write-Host "Demo flags not found in env.staging.json or env.dev.json." -ForegroundColor Yellow
    Write-Host "Add to env.staging.json:" -ForegroundColor Yellow
    Write-Host '  "DEMO_AUTH_BYPASS": true,' -ForegroundColor White
    Write-Host '  "DEMO_MOCK_HARNESS": true' -ForegroundColor White
  }

  if ($projectRef) {
    Write-Host ""
    Write-Host "Supabase project ref (from env): $projectRef" -ForegroundColor DarkGray
  }

  Write-Host ""
  Write-Host "Next steps:" -ForegroundColor Cyan
  Write-Host "  .\scripts\run_dublin.ps1          # dev" -ForegroundColor White
  Write-Host "  .\scripts\build_staging_web.ps1     # staging build" -ForegroundColor White
  Write-Host ""
  Write-Host "Optional DB seed (advanced, requires login + link):" -ForegroundColor DarkYellow
  Write-Host "  .\scripts\seed_demo_applicants.ps1 -Database" -ForegroundColor White
  Write-Host ""

  if ($InstallCli) {
    try {
      $cli = Install-SupabaseCliLocal
      Write-Host "Supabase CLI installed at: $cli" -ForegroundColor Green
    } catch {
      Write-Host "CLI install failed: $($_.Exception.Message)" -ForegroundColor Red
    }
  }

  exit $(if ($demoReady) { 0 } else { 1 })
}

# --- Database path (optional) ---
if (-not (Test-Path $seedFile)) {
  Write-Host "Missing seed file: $seedFile" -ForegroundColor Red
  exit 1
}

$cliPath = Resolve-SupabaseCli
if (-not $cliPath -and $InstallCli) {
  try { $cliPath = Install-SupabaseCliLocal } catch {
    Write-Host "Could not install CLI: $($_.Exception.Message)" -ForegroundColor Red
  }
}
if (-not $cliPath) {
  Write-Host "Supabase CLI required for -Database. Run: .\scripts\seed_demo_applicants.ps1 -InstallCli" -ForegroundColor Red
  exit 1
}

$projectRef = Get-ProjectRefFromEnv
if (-not $projectRef) {
  Write-Host "Could not read project ref from env.staging.json or env.dev.json (SUPABASE_URL)." -ForegroundColor Red
  exit 1
}

Ensure-SupabaseConfigToml | Out-Null
Set-Location $root

Write-Host "Linking Supabase project: $projectRef" -ForegroundColor Cyan
& $cliPath link --project-ref $projectRef --yes 2>&1 | Out-Host
$linkExit = $LASTEXITCODE

if ($linkExit -ne 0) {
  Write-Host ""
  Write-Host "Link failed. You must authenticate first:" -ForegroundColor Red
  Write-Host "  $cliPath login" -ForegroundColor White
  Write-Host "  $cliPath link --project-ref $projectRef" -ForegroundColor White
  Write-Host ""
  Write-Host "For the staging DEMO you do NOT need -Database." -ForegroundColor Yellow
  Write-Host "Run without flags: .\scripts\seed_demo_applicants.ps1" -ForegroundColor Yellow
  exit 1
}

Write-Host "Running SQL seed ..." -ForegroundColor Cyan
& $cliPath db query --linked --file $seedFile
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
  Write-Host "SQL seed failed. Demo still works via in-app mock harness." -ForegroundColor Yellow
  exit $exitCode
}

Write-Host "Database seed completed." -ForegroundColor Green
