#Captures a screenshot or a video of the running Tracker app window using
#ffmpeg gdigrab (window capture by title). See docs/CAPTURING_MEDIA.md for the
#full agent procedure.
#
#The desktop window title is "Tracker" - set at runtime by lib/main.dart
#(setWindowTitle via the window_size plugin); windows/runner/main.cpp only
#holds the pre-Dart default "tracker". The window must be visible on screen -
#not minimized, not occluded by a fullscreen app.
#
#Usage:
#  pwsh ./capture-app-media.ps1 -Mode screenshot
#  pwsh ./capture-app-media.ps1 -Mode video -Seconds 10
#  pwsh ./capture-app-media.ps1 -Mode screenshot -RunApp
#  pwsh ./capture-app-media.ps1 -Mode video -Test tracker/integration_test/capture_workout_flow_test.dart
#  pwsh ./capture-app-media.ps1 -Mode video -Seconds 30 -Out path.mp4
#
#-Test runs `flutter test -d windows <file>` and records the window from the
#moment it appears until the test exits - that is how an agent records a
#scripted UI flow. Handshake: the script signals "capture finished" by
#creating tracker/build/captures/.capture-done; the test (see the template)
#keeps the window open until that file appears, so the capture never races
#the test exit. Video is captured to a Matroska intermediate (streaming
#clusters, safe to stop abruptly) and remuxed to MP4 afterwards.
#Requires -Version 7
[CmdletBinding()]
param(
    # screenshot = one PNG frame; video = MP4 recording.
    [Parameter(Mandatory)][ValidateSet('screenshot', 'video')][string]$Mode,

    # Output file. Default: tracker/build/captures/<mode>_<timestamp>.<ext>
    [string]$Out = '',

    # Exact desktop window title to capture.
    [string]$Title = 'Tracker',

    # Video length in seconds when no -Test is given.
    [int]$Seconds = 10,

    # Seconds to wait after the window appears before capturing (animations,
    # first-frame data loading).
    [int]$Settle = 3,

    # Integration test file (relative to repo root) to run while recording.
    [string]$Test = '',

    # Launch `flutter run -d windows` before capturing and close the app
    # afterwards. Without this, the app window must already be running.
    [switch]$RunApp,

    # Max seconds to wait for the window to appear (first Windows build can
    # take minutes).
    [int]$WindowTimeoutSec = 600
)
$ErrorActionPreference = 'Stop'

# Two concurrent instances race over the same app window (one latches onto the
# other's window, which then closes) - refuse to run in parallel.
$script:captureMutex = New-Object System.Threading.Mutex($false, 'Global\capture-app-media-tracker')
if (-not $script:captureMutex.WaitOne(0)) {
    throw 'Another capture-app-media.ps1 instance is already running - wait for it to finish.'
}

$repoRoot = $PSScriptRoot
$tracker = Join-Path $repoRoot 'tracker'
$captureDir = Join-Path $tracker 'build\captures'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null

# Handshake sentinel for -Test mode: created by this script when the capture
# is finished; the test keeps the app window open until it sees this file.
$doneFile = Join-Path $captureDir '.capture-done'
Remove-Item -LiteralPath $doneFile -Force -ErrorAction SilentlyContinue
function Signal-CaptureDone { New-Item -ItemType File -Force -Path $doneFile | Out-Null }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if (-not $Out) {
    $ext = if ($Mode -eq 'screenshot') { 'png' } else { 'mp4' }
    $Out = Join-Path $captureDir "$($Mode)_$stamp.$ext"
} elseif (-not [System.IO.Path]::IsPathRooted($Out)) {
    $Out = Join-Path (Get-Location) $Out
}
$Out = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)

$ffmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue)?.Source
if (-not $ffmpeg) { throw 'ffmpeg not found on PATH. Install it or add its bin dir to PATH.' }

function Find-AppWindow([string]$t) {
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -ceq $t } |
        Select-Object -First 1
}

function Wait-AppWindow {
    param([string]$t, [int]$timeoutSec, $watchedProc = $null)
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $deadline) {
        $win = Find-AppWindow $t
        if ($win) { return $win }
        if ($watchedProc -and $watchedProc.HasExited) { return $null }
        Start-Sleep -Milliseconds 500
    }
    return $null
}

# Launch flutter run -d windows in the background if requested.
$runProc = $null
if ($RunApp) {
    Write-Host "Launching 'flutter run -d windows' (first build can take minutes)..."
    $runProc = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', 'flutter run -d windows' `
        -WorkingDirectory $tracker -PassThru -WindowStyle Hidden
}

try {
    if ($Test) {
        # --- Integration-test-driven capture -------------------------------
        $testPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Test)
        if (-not (Test-Path -LiteralPath $testPath)) { throw "Test file not found: $testPath" }
        $logOut = Join-Path $captureDir "test_$stamp.out.log"
        $logErr = Join-Path $captureDir "test_$stamp.err.log"
        Write-Host "Running integration test: flutter test -d windows $Test"
        $testProc = Start-Process -FilePath 'cmd.exe' `
            -ArgumentList '/c', "flutter test -d windows `"$testPath`"" `
            -WorkingDirectory $tracker -PassThru `
            -RedirectStandardOutput $logOut -RedirectStandardError $logErr

        $win = Wait-AppWindow $Title $WindowTimeoutSec $testProc
        if (-not $win) {
            $tail = if (Test-Path $logErr) { (Get-Content $logErr -Tail 15) -join "`n" } else { '' }
            throw "Window '$Title' never appeared (test exited=$($testProc.HasExited)).`n$tail"
        }
        # Use the real window title for gdigrab (title matching is exact).
        $winTitle = $win.MainWindowTitle

        Start-Sleep -Seconds $Settle

        if ($Mode -eq 'screenshot') {
            & $ffmpeg -hide_banner -loglevel error -f gdigrab -i "title=$winTitle" `
                -frames:v 1 -update 1 -y $Out
            if ($LASTEXITCODE -ne 0) { throw "ffmpeg screenshot failed (exit $LASTEXITCODE)" }
            Signal-CaptureDone
            # Wait for the test to finish so its exit code is accurate.
            $exitDeadline = (Get-Date).AddSeconds(60)
            while (-not $testProc.HasExited -and (Get-Date) -lt $exitDeadline) {
                Start-Sleep -Milliseconds 500
            }
        } else {
            # Record to Matroska: it streams clusters as they encode, so an
            # abrupt stop (window closing / killed process) never loses the
            # recorded data - unlike MP4, which buffers until finalization.
            $raw = Join-Path $captureDir "video_${stamp}_raw.mkv"
            $ffLog = Join-Path $captureDir "ffmpeg_$stamp.err.log"
            $ffProc = Start-Process -FilePath $ffmpeg `
                -ArgumentList '-hide_banner', '-loglevel', 'verbose',
                    '-f', 'gdigrab', '-framerate', '30', "-i", "title=$winTitle",
                    '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2',
                    '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23',
                    '-g', '30', '-pix_fmt', 'yuv420p',
                    '-y', $raw -PassThru -WindowStyle Hidden `
                -RedirectStandardError $ffLog
            Write-Host "Recording up to $Seconds s (or until the test exits)..."
            $deadline = (Get-Date).AddSeconds($Seconds)
            while (-not $ffProc.HasExited -and -not $testProc.HasExited -and (Get-Date) -lt $deadline) {
                Start-Sleep -Milliseconds 500
            }
            Signal-CaptureDone   # let the test finish and close its window
            $exitDeadline = (Get-Date).AddSeconds(30)
            while (-not $testProc.HasExited -and (Get-Date) -lt $exitDeadline) {
                Start-Sleep -Milliseconds 500
            }
            # Give ffmpeg a moment to notice the window closing, then stop it.
            $graceEnd = (Get-Date).AddSeconds(10)
            while (-not $ffProc.HasExited -and (Get-Date) -lt $graceEnd) {
                Start-Sleep -Milliseconds 500
            }
            if (-not $ffProc.HasExited) { Stop-Process -Id $ffProc.Id -Force }
            Start-Sleep -Milliseconds 500
            & $ffmpeg -hide_banner -loglevel error -err_detect ignore_err `
                -i $raw -c copy -movflags +faststart -y $Out
            if ($LASTEXITCODE -ne 0) {
                $ffTail = if (Test-Path $ffLog) { (Get-Content $ffLog -Tail 10) -join "`n" } else { '' }
                throw "ffmpeg remux failed (exit $LASTEXITCODE). ffmpeg log: $ffLog`n$ffTail"
            }
            Remove-Item -LiteralPath $raw -ErrorAction SilentlyContinue
        }

        $exit = $testProc.ExitCode
        $okTail = if ($exit -eq 0) { 'test PASSED' } else {
            "test FAILED (exit $exit) - log: $logOut / $logErr"
        }
        Write-Host "Capture saved: $Out ($okTail)"
        if ($exit -ne 0) { exit $exit }
    } else {
        # --- Window-already-running capture ---------------------------------
        $win = Wait-AppWindow $Title ([Math]::Max($WindowTimeoutSec, 15)) $runProc
        if (-not $win) { throw "No window titled '$Title' found. Start the app (flutter run -d windows) or pass -RunApp." }
        $winTitle = $win.MainWindowTitle
        Write-Host "Window found (PID $($win.Id), title '$winTitle'). Settling ${Settle}s..."
        Start-Sleep -Seconds $Settle

        if ($Mode -eq 'screenshot') {
            & $ffmpeg -hide_banner -loglevel error -f gdigrab -i "title=$winTitle" `
                -frames:v 1 -update 1 -y $Out
            if ($LASTEXITCODE -ne 0) { throw "ffmpeg screenshot failed (exit $LASTEXITCODE)" }
        } else {
            & $ffmpeg -hide_banner -loglevel error -f gdigrab -framerate 30 `
                -i "title=$winTitle" -t $Seconds `
                -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" `
                -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p -movflags +faststart -y $Out
            if ($LASTEXITCODE -ne 0) { throw "ffmpeg recording failed (exit $LASTEXITCODE)" }
        }
        Write-Host "Capture saved: $Out"
    }
} finally {
    $script:captureMutex.ReleaseMutex() | Out-Null
    if ($runProc -and -not $runProc.HasExited) {
        # Close the app window; flutter run exits when the app does.
        $win = Find-AppWindow $Title
        if ($win) {
            $win.CloseMainWindow() | Out-Null
            Start-Sleep -Seconds 3
            if (Find-AppWindow $Title) { Stop-Process -Id $win.Id -Force -ErrorAction SilentlyContinue }
        }
        if (-not $runProc.HasExited) { Stop-Process -Id $runProc.Id -Force -ErrorAction SilentlyContinue }
    }
}

if (Test-Path -LiteralPath $Out) {
    $item = Get-Item -LiteralPath $Out
    Write-Host ("{0} ({1:N0} KB)" -f $item.FullName, ($item.Length / 1KB))
} else {
    throw "Expected output file was not created: $Out"
}
