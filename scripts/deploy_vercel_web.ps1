# Deploy build\web to Vercel production using the Build Output API (reliable static hosting).

param(
  [switch]$Login
)

$root = Split-Path -Parent $PSScriptRoot
$webRoot = Join-Path $root 'build\web'
$indexPath = Join-Path $webRoot 'index.html'
$outputRoot = Join-Path $root '.vercel\output'
$staticRoot = Join-Path $outputRoot 'static'
$configPath = Join-Path $outputRoot 'config.json'
$vercelDir = Join-Path $root '.vercel'

$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')

$npx = Get-Command npx -ErrorAction SilentlyContinue
if (-not $npx) {
  $fallback = Join-Path ${env:ProgramFiles} 'nodejs\npx.cmd'
  if (Test-Path $fallback) {
    $npx = Get-Item $fallback
  } else {
    Write-Host 'Node.js/npx not found. Install LTS: winget install OpenJS.NodeJS.LTS' -ForegroundColor Red
    exit 1
  }
}

if (-not (Test-Path $indexPath)) {
  Write-Host 'Missing build\web\index.html. Run .\scripts\build_staging_web.ps1 first.' -ForegroundColor Red
  exit 1
}

$canvaskitDir = Join-Path $webRoot 'canvaskit'
if (Test-Path $canvaskitDir) {
  $canvaskitMb = [math]::Round(
    ((Get-ChildItem $canvaskitDir -Recurse -File | Measure-Object Length -Sum).Sum / 1MB),
    1
  )
  Write-Host "Note: local canvaskit/ is ${canvaskitMb}MB. Rebuild with .\scripts\build_staging_web.ps1 to use CDN." -ForegroundColor Yellow
}

Write-Host 'Packaging static output for Vercel...' -ForegroundColor Cyan
if (Test-Path $outputRoot) {
  Remove-Item $outputRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $staticRoot -Force | Out-Null

$excludeDirs = @('.vercel')
$excludeFiles = @('.env.local', '.env', '.vercelignore', 'vercel.json')

Get-ChildItem $webRoot -Force | ForEach-Object {
  if ($_.PSIsContainer) {
    if ($excludeDirs -contains $_.Name) { return }
    Copy-Item $_.FullName (Join-Path $staticRoot $_.Name) -Recurse -Force
    return
  }
  if ($excludeFiles -contains $_.Name) { return }
  Copy-Item $_.FullName (Join-Path $staticRoot $_.Name) -Force
}

@{
  version = 3
  routes  = @(
    @{ handle = 'filesystem' },
    @{ src = '/.*'; dest = '/index.html' }
  )
} | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath -Encoding UTF8

$staticCount = (Get-ChildItem $staticRoot -Recurse -File).Count
$staticMb = [math]::Round(
  ((Get-ChildItem $staticRoot -Recurse -File | Measure-Object Length -Sum).Sum / 1MB),
  2
)
Write-Host "Prepared $staticCount files ($staticMb MB) in .vercel/output/static" -ForegroundColor Green

Set-Location $root

if ($Login) {
  Write-Host 'Opening Vercel login...' -ForegroundColor Cyan
  & $npx vercel login
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if (-not (Test-Path (Join-Path $vercelDir 'project.json'))) {
  Write-Host ''
  Write-Host 'First-time link required. Answer:' -ForegroundColor Yellow
  Write-Host '  Link directory to project? Y' -ForegroundColor White
  Write-Host '  Project name: true-circle' -ForegroundColor White
  Write-Host '  Link repository? N' -ForegroundColor White
  Write-Host ''
  & $npx vercel link
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "Deploying prebuilt static site to Vercel (production)..." -ForegroundColor Cyan
& $npx vercel deploy --prebuilt --prod --archive=tgz
exit $LASTEXITCODE
