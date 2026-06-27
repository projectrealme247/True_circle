Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root "assets\images\logo.png"
$out = Join-Path $root "assets\images\logo.png"

$bmp = [System.Drawing.Bitmap]::FromFile($path)
$minX = $bmp.Width
$minY = $bmp.Height
$maxX = 0
$maxY = 0

for ($y = 0; $y -lt $bmp.Height; $y++) {
  for ($x = 0; $x -lt $bmp.Width; $x++) {
    $pixel = $bmp.GetPixel($x, $y)
    if ($pixel.A -gt 16 -and ($pixel.R -lt 250 -or $pixel.G -lt 250 -or $pixel.B -lt 250)) {
      if ($x -lt $minX) { $minX = $x }
      if ($y -lt $minY) { $minY = $y }
      if ($x -gt $maxX) { $maxX = $x }
      if ($y -gt $maxY) { $maxY = $y }
    }
  }
}

$pad = 20
$minX = [Math]::Max(0, $minX - $pad)
$minY = [Math]::Max(0, $minY - $pad)
$maxX = [Math]::Min($bmp.Width - 1, $maxX + $pad)
$maxY = [Math]::Min($bmp.Height - 1, $maxY + $pad)
$w = $maxX - $minX + 1
$h = $maxY - $minY + 1

$cropped = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($cropped)
$g.Clear([System.Drawing.Color]::White)
$src = New-Object System.Drawing.Rectangle $minX, $minY, $w, $h
$dest = New-Object System.Drawing.Rectangle 0, 0, $w, $h
$g.DrawImage($bmp, $dest, $src, [System.Drawing.GraphicsUnit]::Pixel)
$backup = Join-Path $root "assets\images\logo_original.png"
if (-not (Test-Path $backup)) {
  Copy-Item $path $backup
}
$trimmed = Join-Path $root "assets\images\logo_trimmed.png"
$cropped.Save($trimmed, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$cropped.Dispose()
$bmp.Dispose()
Move-Item -Path $trimmed -Destination $out -Force
Write-Host "Trimmed logo to ${w}x${h} -> $out"
