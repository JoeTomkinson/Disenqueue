# build.ps1 - Creates dist/Disenqueue/ ready to zip for distribution

$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$distDir = Join-Path $root "dist"
$addonDir = Join-Path $distDir "Disenqueue"

# Clean previous build
if (Test-Path $distDir) {
    Remove-Item $distDir -Recurse -Force
}

# Create output directory
New-Item -ItemType Directory -Path $addonDir -Force | Out-Null

# Copy addon files
Copy-Item (Join-Path $root "Disenqueue.toc") -Destination $addonDir
Copy-Item (Join-Path $root "Disenqueue.lua") -Destination $addonDir

# Copy asset directories
Copy-Item (Join-Path $root "icons") -Destination $addonDir -Recurse
Copy-Item (Join-Path $root "logos") -Destination $addonDir -Recurse

# Remove source art files that aren't needed in the addon
$exclude = @("*.png", "*.svg", "*.psd")
Get-ChildItem (Join-Path $addonDir "icons") -Include $exclude -Recurse | Remove-Item -Force
Get-ChildItem (Join-Path $addonDir "logos") -Include $exclude -Recurse | Remove-Item -Force

Write-Host "Build complete: dist/Disenqueue/" -ForegroundColor Green
Write-Host ""
Write-Host "Contents:"
Get-ChildItem $addonDir -Recurse | ForEach-Object {
    $rel = $_.FullName.Substring($addonDir.Length + 1)
    if ($_.PSIsContainer) { Write-Host "  $rel/" } else { Write-Host "  $rel" }
}
Write-Host ""
Write-Host "To distribute, zip the dist/ folder - it contains Disenqueue/ at the root."
