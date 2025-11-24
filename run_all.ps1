<#
.SYNOPSIS
    Runs the Django backend and Flutter frontend together.

.DESCRIPTION
    This script starts the Django backend server and Flutter user app.
    If you get an execution policy error, run:
        powershell -ExecutionPolicy Bypass -File .\run_all.ps1 -Device chrome
    Or set execution policy once:
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

.PARAMETER Release
    Run Flutter app in release mode.

.PARAMETER Device
    Target device: windows, chrome, edge, web-server, or android (default: windows)

.EXAMPLE
    .\run_all.ps1 -Device chrome
    .\run_all.ps1 -Release -Device windows
#>

param(
    [switch]$Release,
    [ValidateSet('windows', 'chrome', 'edge', 'web-server', 'android')]
    [string]$Device = 'windows'
)

$ErrorActionPreference = 'Stop'

# ---------------- PATH / PROJECT SETUP ----------------

$projectRoot = $PSScriptRoot
$backendPath = Join-Path $projectRoot 'backend'
$flutterPath = Join-Path $projectRoot 'apps\app_user'
$pythonExe  = Join-Path $projectRoot 'venv\Scripts\python.exe'

if (!(Test-Path $pythonExe)) {
    $fallbackPythonExe = Join-Path $backendPath 'venv\Scripts\python.exe'
    if (Test-Path $fallbackPythonExe) {
        $pythonExe = $fallbackPythonExe
    }
}

$pythonArgs = @()
if (!(Test-Path $pythonExe)) {
    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher) {
        Write-Host "Virtual environment not found. Using system Python (py launcher)." -ForegroundColor Yellow
        Write-Host "For best results, create a virtual environment:" -ForegroundColor Yellow
        Write-Host "  cd backend" -ForegroundColor Yellow
        Write-Host "  py -m venv venv" -ForegroundColor Yellow
        Write-Host "  .\venv\Scripts\activate" -ForegroundColor Yellow
        Write-Host "  pip install -r requirements.txt" -ForegroundColor Yellow
        Write-Host ""
        $pythonExe = "py"
        $pythonArgs = @("-3")
    } else {
        Write-Error "Python virtualenv not found. Expected at $projectRoot\venv or $backendPath\venv."
        exit 1
    }
}

if (!(Test-Path (Join-Path $flutterPath 'pubspec.yaml'))) {
    Write-Error "Flutter project (pubspec.yaml) not found at $flutterPath."
    exit 1
}

# ---------------- SMALL HELPERS ----------------

function Invoke-ProcessSync {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$WorkingDirectory
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = $FilePath
    $psi.Arguments = [string]::Join(' ', $Arguments)
    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }
    $psi.UseShellExecute        = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.CreateNoWindow         = $false

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()

    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    return [pscustomobject]@{
        ExitCode = $proc.ExitCode
        StdOut   = $stdout
        StdErr   = $stderr
        Process  = $proc
    }
}

function Start-ProcessBackground {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$WorkingDirectory
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = $FilePath
    $psi.Arguments = [string]::Join(' ', $Arguments)
    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }
    $psi.UseShellExecute        = $false
    $psi.RedirectStandardOutput = $false
    $psi.RedirectStandardError  = $false
    $psi.CreateNoWindow         = $false

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()

    return $proc
}

function Test-PortInUse {
    param([int]$Port)

    try {
        $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
        $listener.Start()
        $listener.Stop()
        return $false
    } catch {
        return $true
    }
}

# ---------------- HEADER OUTPUT ----------------

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting Django Backend + User App" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Device: $Device" -ForegroundColor Green
Write-Host "Mode: $(if ($Release) { 'Release' } else { 'Debug' })" -ForegroundColor Green

$useConsoleEmail = $env:USE_CONSOLE_EMAIL
if ($useConsoleEmail -eq 'true') {
    Write-Host "Email: Console backend (OTPs in terminal)" -ForegroundColor Green
    [Environment]::SetEnvironmentVariable('USE_CONSOLE_EMAIL', 'true', 'Process')
} else {
    Write-Host "Email: SMTP backend (Gmail - smtp.gmail.com:587)" -ForegroundColor Green
    [Environment]::SetEnvironmentVariable('USE_CONSOLE_EMAIL', 'false', 'Process')
}
Write-Host ""

# ---------------- 1. MIGRATIONS ----------------

Write-Host "[1/2] Starting Django backend..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Creating migrations (if needed)..." -ForegroundColor Cyan

Push-Location $backendPath
try {
    $makemigrationsArgs = $pythonArgs + @('manage.py', 'makemigrations')
    $result = Invoke-ProcessSync -FilePath $pythonExe -Arguments $makemigrationsArgs -WorkingDirectory $backendPath

    if ($result.ExitCode -eq 0) {
        Write-Host "Migrations created/checked." -ForegroundColor Green
        if ($result.StdOut.Trim()) {
            Write-Host $result.StdOut -ForegroundColor Gray
        }
    } else {
        Write-Warning "makemigrations had issues (exit code: $($result.ExitCode))"
        if ($result.StdErr.Trim()) {
            Write-Host $result.StdErr -ForegroundColor Yellow
        }
        Write-Warning "Continuing anyway..."
    }
}
finally {
    Pop-Location
}

Write-Host "Applying migrations..." -ForegroundColor Cyan
Push-Location $backendPath
try {
    $migrateArgs = $pythonArgs + @('manage.py', 'migrate', '--noinput')
    $result = Invoke-ProcessSync -FilePath $pythonExe -Arguments $migrateArgs -WorkingDirectory $backendPath

    if ($result.ExitCode -eq 0) {
        Write-Host "Migrations applied successfully." -ForegroundColor Green
    } else {
        Write-Host $result.StdErr -ForegroundColor Red
        Write-Error "Migration failed with exit code $($result.ExitCode). Cannot continue."
        exit 1
    }
}
finally {
    Pop-Location
}

Write-Host ""

# ---------------- 2. DJANGO CHECK ----------------

Write-Host "Checking Django configuration..." -ForegroundColor Cyan
Push-Location $backendPath
try {
    $checkArgs = $pythonArgs + @('manage.py', 'check')
    $result = Invoke-ProcessSync -FilePath $pythonExe -Arguments $checkArgs -WorkingDirectory $backendPath

    if ($result.ExitCode -ne 0) {
        Write-Host $result.StdErr -ForegroundColor Red
        Write-Error "Django configuration check failed. Fix the above errors and rerun."
        exit 1
    } else {
        Write-Host "Django configuration is valid." -ForegroundColor Green
    }
}
finally {
    Pop-Location
}

Write-Host ""

# ---------------- 3. PORT CHECK / CLEANUP ----------------

Write-Host "Checking for existing server on port 8000..." -ForegroundColor Cyan

function Get-Port8000Pids {
    $pids = @()

    try {
        $conns = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
        if ($conns) {
            $pids += $conns | Select-Object -ExpandProperty OwningProcess -Unique
        }
    } catch { }

    try {
        $netstatOutput = netstat -ano | Select-String ":8000.*LISTENING"
        if ($netstatOutput) {
            $netstatOutput | ForEach-Object {
                if ($_ -match '\s+(\d+)\s*$') {
                    $pids += [int]$matches[1]
                }
            }
        }
    } catch { }

    return ($pids | Select-Object -Unique | Where-Object { $_ -gt 0 })
}

$existing = Get-Port8000Pids
if ($existing.Count -gt 0) {
    Write-Host "Found existing process(es) on port 8000. Attempting to stop them..." -ForegroundColor Yellow
    foreach ($pid in $existing) {
        try {
            $p = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if ($p) {
                Write-Host "  Stopping PID $pid ($($p.ProcessName))" -ForegroundColor Yellow
                $p.Kill()
                $p.WaitForExit()
            }
        } catch {
            Write-Warning "Could not stop PID $pid automatically."
        }
    }
    Start-Sleep -Seconds 3
} else {
    Write-Host "Port 8000 is free." -ForegroundColor Green
}

# Determine a backend port
$backendPort = $null
$portsToTry = @(8000, 8001, 8002)

foreach ($p in $portsToTry) {
    if (-not (Test-PortInUse -Port $p)) {
        $backendPort = $p
        break
    }
}

if (-not $backendPort) {
    Write-Error "No free backend port found among: $($portsToTry -join ', ')."
    exit 1
}

Write-Host "Backend API will use: http://127.0.0.1:$backendPort/api" -ForegroundColor Green
Write-Host ""

# ---------------- 4. START DAPHNE (BACKGROUND) ----------------

Write-Host "Starting Django server with Daphne (ASGI) on port $backendPort..." -ForegroundColor Cyan

Push-Location $backendPath
$daphneArgs = @('-m', 'daphne', 'core.asgi:application', '--bind', '0.0.0.0', '--port', "$backendPort")
$backendProcess = Start-ProcessBackground -FilePath $pythonExe -Arguments $daphneArgs -WorkingDirectory $backendPath
Pop-Location

Start-Sleep -Seconds 3

if ($backendProcess -and -not $backendProcess.HasExited) {
    Write-Host "Backend started successfully. Server: http://127.0.0.1:$backendPort" -ForegroundColor Green
    Write-Host "WebSocket endpoint: ws://127.0.0.1:$backendPort/ws/chat/<chat_id>/" -ForegroundColor Green
} else {
    Write-Error "Daphne server failed to start. Check your Django/ASGI setup."
    exit 1
}

# ---------------- 5. START FLUTTER APP ----------------

Write-Host ""
Write-Host "[2/2] Launching Flutter User App..." -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor DarkGray
Write-Host "Backend is running at: http://127.0.0.1:$backendPort" -ForegroundColor Green
Write-Host "Flutter output will appear below." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop Flutter; backend will be cleaned up." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor DarkGray
Write-Host ""

Push-Location $flutterPath
try {
    $flutterArgs = @('run', '-d', $Device)
    if ($Release) {
        $flutterArgs += '--release'
    }

    flutter @flutterArgs
}
catch {
    Write-Host "`nError while running Flutter:" -ForegroundColor Red
    Write-Host $_.ToString() -ForegroundColor Red
}
finally {
    Pop-Location
    Write-Host ""
    Write-Host "Cleaning up..." -ForegroundColor Yellow

    if ($backendProcess -and -not $backendProcess.HasExited) {
        try {
            $backendProcess.Kill()
            $backendProcess.WaitForExit()
        } catch { }
    }

    Write-Host "All processes stopped." -ForegroundColor Green
}
