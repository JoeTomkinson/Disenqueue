# build.ps1 - Creates dist/ with release and PTR zips ready for CurseForge
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

$root = Split-Path $PSScriptRoot -Parent
$tocFile = Join-Path $root "Disenqueue.toc"
$coreFile = Join-Path $root "Core.lua"

# Interface versions
$INTERFACE_LIVE = "120005"
$INTERFACE_PTR  = "120007"

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

    # Update Core.lua version
    $luaContent = Get-Content $coreFile -Raw
    $luaContent = $luaContent -replace "ns\.ADDON_VERSION\s*=\s*`"$([regex]::Escape($old))`"", "ns.ADDON_VERSION = `"$new`""
    Set-Content $coreFile $luaContent -NoNewline

    Write-Host "Version bumped: $old -> $new" -ForegroundColor Cyan
}

# --- Build ---
$distDir = Join-Path $root "dist"

# Clean previous build
if (Test-Path $distDir) {
    Remove-Item $distDir -Recurse -Force
}

# Read version for zip naming
$tocContent = Get-Content $tocFile -Raw
if ($tocContent -match '## Version:\s*(\d+\.\d+\.\d+)') {
    $version = $Matches[1]
} else {
    $version = "unknown"
}

# Build function: creates addon folder, patches interface version, zips it
function Build-Variant {
    param([string]$InterfaceVersion, [string]$Suffix)

    $variantDir = Join-Path $distDir $Suffix
    $addonDir = Join-Path $variantDir "Disenqueue"

    New-Item -ItemType Directory -Path $addonDir -Force | Out-Null

    # Copy addon files
    Copy-Item (Join-Path $root "Disenqueue.toc") -Destination $addonDir
    Copy-Item (Join-Path $root "Core.lua") -Destination $addonDir
    Copy-Item (Join-Path $root "Theme.lua") -Destination $addonDir
    Copy-Item (Join-Path $root "SlotMap.lua") -Destination $addonDir
    Copy-Item (Join-Path $root "UI_Main.lua") -Destination $addonDir
    Copy-Item (Join-Path $root "UI_Locked.lua") -Destination $addonDir
    Copy-Item (Join-Path $root "UI_Export.lua") -Destination $addonDir
    Copy-Item (Join-Path $root "UI_Minimap.lua") -Destination $addonDir
    Copy-Item (Join-Path $root "Settings.lua") -Destination $addonDir
    Copy-Item (Join-Path $root "Bindings.xml") -Destination $addonDir

    # Copy asset directories
    Copy-Item (Join-Path $root "icons") -Destination $addonDir -Recurse
    Copy-Item (Join-Path $root "logos") -Destination $addonDir -Recurse
    $fontsDir = Join-Path $root "Fonts"
    if (Test-Path $fontsDir) {
        Copy-Item $fontsDir -Destination $addonDir -Recurse
    }

    # Remove source art files that aren't needed in the addon
    $exclude = @("*.png", "*.svg", "*.psd")
    Get-ChildItem (Join-Path $addonDir "icons") -Include $exclude -Recurse | Remove-Item -Force
    Get-ChildItem (Join-Path $addonDir "logos") -Include $exclude -Recurse | Remove-Item -Force

    # Patch Interface version in the .toc copy
    $tocPath = Join-Path $addonDir "Disenqueue.toc"
    $content = Get-Content $tocPath -Raw
    $content = $content -replace '## Interface:\s*\d+', "## Interface: $InterfaceVersion"
    Set-Content $tocPath $content -NoNewline

    # Create zip
    $zipName = "Disenqueue-$version-$Suffix.zip"
    $zipPath = Join-Path $distDir $zipName
    Compress-Archive -Path $addonDir -DestinationPath $zipPath -Force

    Write-Host "  $zipName (Interface: $InterfaceVersion)" -ForegroundColor White
}

Write-Host ""
Write-Host "Building Disenqueue v$version..." -ForegroundColor Cyan
Write-Host ""

# Build both variants
Write-Host "Zips:" -ForegroundColor Green
Build-Variant -InterfaceVersion $INTERFACE_LIVE -Suffix "release"
Build-Variant -InterfaceVersion $INTERFACE_PTR  -Suffix "ptr"

# Show contents of the release build
$releaseAddonDir = Join-Path $distDir "release\Disenqueue"
Write-Host ""
Write-Host "Contents:" -ForegroundColor Green
Get-ChildItem $releaseAddonDir -Recurse | ForEach-Object {
    $rel = $_.FullName.Substring($releaseAddonDir.Length + 1)
    if ($_.PSIsContainer) { Write-Host "  $rel/" } else { Write-Host "  $rel" }
}
Write-Host ""
Write-Host "Ready to upload to CurseForge:" -ForegroundColor Green
Write-Host "  dist/Disenqueue-$version-release.zip  -> The War Within (live)" -ForegroundColor White
Write-Host "  dist/Disenqueue-$version-ptr.zip      -> PTR/Beta" -ForegroundColor White
