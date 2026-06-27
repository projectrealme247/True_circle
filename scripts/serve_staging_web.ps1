# Serve build\web locally (no Python required).

param(
  [int]$Port = 8080
)

$root = Split-Path -Parent $PSScriptRoot
$webRoot = Join-Path $root 'build\web'

$indexPath = Join-Path $webRoot 'index.html'
if (-not (Test-Path $indexPath)) {
  Write-Host 'Missing build\web\index.html. Run .\scripts\build_staging_web.ps1 first.' -ForegroundColor Red
  exit 1
}

$mime = @{
  '.html'  = 'text/html; charset=utf-8'
  '.js'    = 'application/javascript; charset=utf-8'
  '.mjs'   = 'application/javascript; charset=utf-8'
  '.json'  = 'application/json; charset=utf-8'
  '.css'   = 'text/css; charset=utf-8'
  '.png'   = 'image/png'
  '.jpg'   = 'image/jpeg'
  '.jpeg'  = 'image/jpeg'
  '.gif'   = 'image/gif'
  '.svg'   = 'image/svg+xml'
  '.ico'   = 'image/x-icon'
  '.wasm'  = 'application/wasm'
  '.ttf'   = 'font/ttf'
  '.otf'   = 'font/otf'
  '.woff'  = 'font/woff'
  '.woff2' = 'font/woff2'
  '.bin'   = 'application/octet-stream'
}

function Start-HttpListener {
  param([int]$StartPort, [int]$MaxAttempts = 15)
  for ($p = $StartPort; $p -lt ($StartPort + $MaxAttempts); $p++) {
    $listener = New-Object System.Net.HttpListener
    $prefix = "http://localhost:$p/"
    $listener.Prefixes.Add($prefix)
    try {
      $listener.Start()
      return @{ Listener = $listener; Port = $p; Prefix = $prefix }
    } catch {
      $listener.Close()
    }
  }
  return $null
}

$requestedPort = $Port
$started = Start-HttpListener -StartPort $Port
if ($null -eq $started) {
  Write-Host "Could not bind ports $requestedPort-$($requestedPort + 14). Stop other local servers or pass -Port." -ForegroundColor Red
  exit 1
}

$listener = $started.Listener
$Port = $started.Port
$prefix = $started.Prefix
if ($Port -ne $requestedPort) {
  Write-Host "Port $requestedPort was busy; using http://localhost:$Port/ instead." -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'TrueCircle staging server' -ForegroundColor Cyan
Write-Host "  URL:    http://localhost:$Port/" -ForegroundColor Green
Write-Host "  Folder: $webRoot" -ForegroundColor DarkGray
Write-Host '  Stop:   Ctrl+C' -ForegroundColor DarkGray
Write-Host ''

try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    $rel = $request.Url.LocalPath.TrimStart('/')
    if ([string]::IsNullOrWhiteSpace($rel)) {
      $rel = 'index.html'
    }

    $filePath = Join-Path $webRoot ($rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path $filePath -PathType Leaf)) {
      $filePath = $indexPath
    }

    if (-not (Test-Path $filePath -PathType Leaf)) {
      $response.StatusCode = 404
      $notFound = [Text.Encoding]::UTF8.GetBytes('Not found')
      $response.OutputStream.Write($notFound, 0, $notFound.Length)
      $response.Close()
      continue
    }

    $ext = [IO.Path]::GetExtension($filePath).ToLowerInvariant()
    if ($mime.ContainsKey($ext)) {
      $response.ContentType = $mime[$ext]
    }

    $content = [IO.File]::ReadAllBytes($filePath)
    $response.ContentLength64 = $content.Length
    $response.OutputStream.Write($content, 0, $content.Length)
    $response.Close()
  }
} finally {
  $listener.Stop()
  $listener.Close()
}
