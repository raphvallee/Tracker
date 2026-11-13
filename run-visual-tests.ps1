#Runs the visual screenshot sweep and lists every captured PNG.
#
#Usage:  pwsh ./run-visual-tests.ps1 [-NoClean]
#
#Renders every app page/dialog at 320x568, 800x600 and 1280x720 with real
#Inter text and Lucide/Material icon fonts, writing PNGs plus manifest.json
#to tracker/build/test_screenshots/ (gitignored). Exit code = flutter test
#exit code. Files suffixed _FAIL are auto-captures of a screen that threw a
#render exception.
#Requires -Version 7
[CmdletBinding()]
param(
    # Keep existing screenshots (deterministic names overwrite same states).
    [switch]$NoClean
)

$ErrorActionPreference = 'Stop'
$shots = Join-Path $PSScriptRoot 'tracker\build\test_screenshots'

if (-not $NoClean) {
    if (Test-Path -LiteralPath $shots) {
        Remove-Item -LiteralPath $shots -Recurse -Force -Confirm:$false
    }
}

Push-Location (Join-Path $PSScriptRoot 'tracker')
try {
    # One file per size (one Isar-backed case per process); run them one at a
    # time so each process can merge its entries into manifest.json.
    flutter test --concurrency=1 test/ui/visual_screenshots
    $code = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($code -ne 0) {
    Write-Host "flutter test FAILED (exit $code) — inspect the *_FAIL*.png captures next to the passing shots." -ForegroundColor Red
}

$pngs = @(Get-ChildItem -LiteralPath $shots -Filter *.png -ErrorAction SilentlyContinue | Sort-Object Name)
Write-Host ''
Write-Host "=== $($pngs.Count) screenshots in $shots ==="
$pngs | ForEach-Object { Write-Host $_.FullName }
Write-Host "Manifest: $(Join-Path $shots 'manifest.json')"

exit $code
