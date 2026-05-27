# unlink-addon.ps1 - Remove the symlink from WoW AddOns folder
# This does NOT delete your repo files, only the junction/symlink.

$addonsPath = "A:\Blizzard\World of Warcraft\_retail_\Interface\Addons"
$linkPath = Join-Path $addonsPath "Disenqueue"

if (-not (Test-Path $linkPath)) {
    Write-Host "Nothing to remove: $linkPath does not exist." -ForegroundColor Yellow
    exit 0
}

$item = Get-Item $linkPath -Force
if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
    Remove-Item $linkPath -Force
    Write-Host "Symlink removed: $linkPath" -ForegroundColor Green
} else {
    Write-Host "WARNING: $linkPath is not a symlink/junction. Skipping to avoid data loss." -ForegroundColor Red
    exit 1
}
