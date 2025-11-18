# Runs the Django backend and Flutter User App together.
# Usage: .\run_all.ps1 [-Release] [-Device <device>]

param(
    [switch]$Release,
    [ValidateSet('windows', 'chrome', 'edge', 'web-server', 'android')]
    [string]$Device = 'chrome'
)

$ErrorActionPreference = 'Stop'

# Determine project root relative to this script
$projectRoot = $PSScriptRoot
$backendPath = Join-Path $projectRoot 'backend'
$flutterPath = Join-Path $projectRoot 'apps\app_user'
$pythonExe = Join-Path $projectRoot '.venv\Scripts\python.exe'
if (!(Test-Path $pythonExe)) {
    $fallbackPythonExe = Join-Path $backendPath 'venv\Scripts\python.exe'
    if (Test-Path $fallbackPythonExe) {
        $pythonExe = $fallbackPythonExe
    }
}

if (!(Test-Path $pythonExe)) {
    Write-Error "Python virtualenv not found. Expected at $projectRoot\.venv or $backendPath\venv."
    Write-Host "Please create a virtual environment first:" -ForegroundColor Yellow
    Write-Host "  cd backend" -ForegroundColor Yellow
    Write-Host "  python -m venv venv" -ForegroundColor Yellow
    Write-Host "  .\venv\Scripts\activate" -ForegroundColor Yellow
    Write-Host "  pip install -r requirements.txt" -ForegroundColor Yellow
    exit 1
}

if (!(Test-Path (Join-Path $flutterPath 'pubspec.yaml'))) {
    Write-Error "Flutter project (pubspec.yaml) not found at $flutterPath."
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting Django Backend + User App" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Backend API: http://127.0.0.1:8000/api" -ForegroundColor Green
Write-Host "Device: $Device" -ForegroundColor Green
Write-Host "Mode: $(if ($Release) { 'Release' } else { 'Debug' })" -ForegroundColor Green
Write-Host ""

Write-Host "[1/2] Starting Django backend..." -ForegroundColor Cyan
Write-Host ""

# Start backend as a background job
$backendJob = Start-Job -ScriptBlock {
    param($pythonExe, $backendPath)
    Set-Location $backendPath
    & $pythonExe manage.py runserver 127.0.0.1:8000 2>&1 | ForEach-Object {
        "[Backend] $_"
    }
} -ArgumentList $pythonExe, $backendPath

Write-Host "Backend started (Job ID: $($backendJob.Id))" -ForegroundColor Green
Start-Sleep -Seconds 3

# Function to display backend logs
function Show-BackendLogs {
    $logs = Receive-Job -Job $backendJob -ErrorAction SilentlyContinue
    if ($logs) {
        foreach ($log in $logs) {
            Write-Host $log -ForegroundColor DarkGray
        }
    }
}

# Show initial backend logs
Show-BackendLogs
Write-Host ""

if ($Device -eq 'windows') {
    Write-Host "Ensuring no stale Flutter desktop processes..." -ForegroundColor Cyan
    Get-Process -Name 'app_user' -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $_.Kill()
            $_.WaitForExit()
        }
        catch {
            Write-Warning "Failed to terminate process $($_.Name): $_"
        }
    }

    $generatedPluginFile = Join-Path $flutterPath 'windows\flutter\generated_plugin_registrant.h'
    if (Test-Path $generatedPluginFile) {
        try {
            Remove-Item $generatedPluginFile -Force
        }
        catch {
            Write-Warning "Could not remove locked file $generatedPluginFile. Continuing..."
        }
    }
}

Write-Host "[2/2] Launching Flutter User App..." -ForegroundColor Cyan
Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor DarkGray
Write-Host "Flutter logs:" -ForegroundColor Cyan
Write-Host "Backend logs will appear with [Backend] prefix" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor DarkGray
Write-Host ""

Push-Location $flutterPath
try {
    $flutterArgs = @('run', '-d', $Device)
    if ($Release) {
        $flutterArgs += '--release'
    }
    
    # Run Flutter directly - this will show all Flutter output in the terminal
    # Backend logs will be shown periodically via a background timer
    $timer = New-Object System.Timers.Timer
    $timer.Interval = 2000  # Check every 2 seconds
    $timer.AutoReset = $true
    $action = {
        Show-BackendLogs
    }
    Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action $action | Out-Null
    $timer.Start()
    
    try {
        # Run Flutter - this blocks until Flutter exits
        flutter @flutterArgs
    }
    finally {
        # Stop the timer
        $timer.Stop()
        $timer.Dispose()
        # Show any remaining backend logs
        Show-BackendLogs
    }
}
catch {
    Write-Host "`nError: $_" -ForegroundColor Red
}
finally {
    Pop-Location
    Write-Host ""
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host "`nStopping Django backend..." -ForegroundColor Yellow
    
    # Stop backend job
    if ($backendJob) {
        Stop-Job -Job $backendJob -ErrorAction SilentlyContinue
        Show-BackendLogs
        Remove-Job -Job $backendJob -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "All processes stopped." -ForegroundColor Green

