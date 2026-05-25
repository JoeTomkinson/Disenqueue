# build.ps1 - Creates dist/Disenqueue/ ready to zip for distribution
# Usage:
#   ./build.ps1                 # build only
#   ./build.ps1 -Bump patch    # 1.0.0 -> 1.0.1, then build
#   ./build.ps1 -Bump minor    # 1.0.0 -> 1.1.0, then build
#   ./build.ps1 -Bump major    # 1.0.0 -> 2.0.0, then build

param(
    [ValidateSet("major", "minor", "patch")]
    [string]$Bump
)

$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$tocFile = Join-Path $root "Disenqueue.toc"
$luaFile = Join-Path $root "Disenqueue.lua"

# --- Version bump ---
if ($Bump) {
    # Read current version from .toc
    $tocContent = Get-Content $tocFile -Raw
    if ($tocContent -match '## Version:\s*(\d+)\.(\d+)\.(\d+)') {
        $major = [int]$Matches[1]
        $minor = [int]$Matches[2]
        $patch = [int]$Matches[3]
    } else {
        throw "Could not parse version from Disenqueue.toc"
    }

    $old = "$major.$minor.$patch"

    switch ($Bump) {
        "major" { $major++; $minor = 0; $patch = 0 }
        "minor" { $minor++; $patch = 0 }
        "patch" { $patch++ }
    }

    $new = "$major.$minor.$patch"

    # Update .toc
    $tocContent = $tocContent -replace "## Version:\s*$([regex]::Escape($old))", "## Version: $new"
    Set-Content $tocFile $tocContent -NoNewline

    # Update .lua
    $luaContent = Get-Content $luaFile -Raw
    $luaContent = $luaContent -replace "local ADDON_VERSION\s*=\s*`"$([regex]::Escape($old))`"", "local ADDON_VERSION = `"$new`""
    Set-Content $luaFile $luaContent -NoNewline

    Write-Host "Version bumped: $old -> $new" -ForegroundColor Cyan
}

# --- Build ---
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
