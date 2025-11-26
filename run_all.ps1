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
    
.NOTES
    Email Configuration:
    - By default, uses SMTP backend (Gmail - smtp.gmail.com:587)
    - To use console backend (see OTPs in terminal), set environment variable:
        $env:USE_CONSOLE_EMAIL = 'true'
        .\run_all.ps1
    
    Flutter Hot Reload:
    - While Flutter app is running, press 'r' for hot reload (quick refresh)
    - Press 'R' (capital) for hot restart (full restart)
    - Press 'q' to quit the Flutter app
#>

param(
    [switch]$Release,
    [ValidateSet('windows', 'chrome', 'edge', 'web-server', 'android')]
    [string]$Device = 'windows'
)

$ErrorActionPreference = 'Stop'

# Determine project root relative to this script
# $PSScriptRoot is set when script is executed directly (e.g., .\run_all.ps1)
# If not set, try to get it from $MyInvocation
if ($PSScriptRoot) {
    $projectRoot = $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
    # Fallback: get script directory from invocation
    $scriptPath = $MyInvocation.MyCommand.Path
    $projectRoot = Split-Path -Parent $scriptPath
} else {
    # Last resort: assume script is run from project root
    # This handles cases where script is dot-sourced or run in unusual ways
    $projectRoot = (Get-Location).Path
    Write-Warning "Could not determine script location automatically. Using current directory: $projectRoot"
    Write-Warning "If paths are incorrect, ensure you run the script from the project root directory."
}

# Ensure we have an absolute path
try {
    if (Test-Path $projectRoot) {
        $projectRoot = (Resolve-Path $projectRoot).Path
    } else {
        # Convert to absolute path if relative
        $projectRoot = [System.IO.Path]::GetFullPath($projectRoot)
    }
} catch {
    # If all else fails, use the path as-is
    Write-Warning "Could not resolve absolute path for: $projectRoot. Using as-is."
}

$backendPath = Join-Path $projectRoot 'backend'
$flutterPath = Join-Path $projectRoot 'apps\app_user'
$pythonExe = Join-Path $projectRoot '.venv\Scripts\python.exe'

if (!(Test-Path $pythonExe)) {
    $fallbackPythonExe = Join-Path $backendPath 'venv\Scripts\python.exe'
    if (Test-Path $fallbackPythonExe) {
        $pythonExe = $fallbackPythonExe
    }
}

# If venv python not found, try to use system python (py launcher)
if (!(Test-Path $pythonExe)) {
    # Try to find py launcher
    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher) {
        Write-Host "Virtual environment not found. Using system Python (py launcher)." -ForegroundColor Yellow
        Write-Host "For best results, create a virtual environment:" -ForegroundColor Yellow
        Write-Host "  cd backend" -ForegroundColor Yellow
        Write-Host "  py -m venv venv" -ForegroundColor Yellow
        Write-Host "  .\venv\Scripts\activate" -ForegroundColor Yellow
        Write-Host "  pip install -r requirements.txt" -ForegroundColor Yellow
        Write-Host ""
        
        # Use py launcher with -3 flag to ensure Python 3
        $pythonExe = "py"
        $pythonArgs = @("-3")
    } else {
    Write-Error "Python virtualenv not found. Expected at $projectRoot\.venv or $backendPath\venv."
    Write-Host "Please create a virtual environment first:" -ForegroundColor Yellow
    Write-Host "  cd backend" -ForegroundColor Yellow
        Write-Host "  py -m venv venv" -ForegroundColor Yellow
    Write-Host "  .\venv\Scripts\activate" -ForegroundColor Yellow
    Write-Host "  pip install -r requirements.txt" -ForegroundColor Yellow
    exit 1
    }
} else {
    $pythonArgs = @()
}

# Validate paths exist with helpful error messages

if (!(Test-Path $backendPath)) {
    Write-Error "Backend directory not found at: $backendPath`nProject root: $projectRoot`nPlease ensure you're running the script from the project root directory."
    Write-Host "Current working directory: $(Get-Location)" -ForegroundColor Yellow
    exit 1
}

if (!(Test-Path $flutterPath)) {
    Write-Error "Flutter app directory not found at: $flutterPath`nProject root: $projectRoot`nPlease ensure you're running the script from the project root directory."
    Write-Host "Current working directory: $(Get-Location)" -ForegroundColor Yellow
    exit 1
}

if (!(Test-Path (Join-Path $flutterPath 'pubspec.yaml'))) {
    Write-Error "Flutter project (pubspec.yaml) not found at: $flutterPath`nProject root: $projectRoot`nPlease ensure the Flutter app is located at apps\app_user"
    Write-Host "Current working directory: $(Get-Location)" -ForegroundColor Yellow
    exit 1
}

Write-Host "Starting Django Backend + Flutter App..." -ForegroundColor Cyan
# Email configuration - check environment variable
$useConsoleEmail = $env:USE_CONSOLE_EMAIL
if ($useConsoleEmail -eq 'true') {
    [Environment]::SetEnvironmentVariable('USE_CONSOLE_EMAIL', 'true', 'Process')
} else {
    [Environment]::SetEnvironmentVariable('USE_CONSOLE_EMAIL', 'false', 'Process')
}

# Create logs directory in project root if it doesn't exist
$logsDir = Join-Path $projectRoot 'logs'
if (!(Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

# Run database migrations first
Push-Location $backendPath
try {
    $makemigrationsArgs = $pythonArgs + @('manage.py', 'makemigrations')
    $makemigrationsProcess = Start-Process -FilePath $pythonExe `
        -ArgumentList $makemigrationsArgs `
        -WorkingDirectory $backendPath `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput (Join-Path $logsDir "django_makemigrations.txt") `
        -RedirectStandardError (Join-Path $logsDir "django_makemigrations_err.txt")

    if ($makemigrationsProcess.ExitCode -eq 0) {
        $makemigrationsOutputFile = Join-Path $logsDir "django_makemigrations.txt"
        if (Test-Path $makemigrationsOutputFile) {
            $output = Get-Content $makemigrationsOutputFile -Raw
            if ($output -and $output.Trim()) {
                Write-Host $output -ForegroundColor Gray
            }
        }
    } else {
        Write-Warning "makemigrations had issues (exit code: $($makemigrationsProcess.ExitCode))"
        $makemigrationsErrorFile = Join-Path $logsDir "django_makemigrations_err.txt"
        if (Test-Path $makemigrationsErrorFile) {
            $errorOutput = Get-Content $makemigrationsErrorFile -Raw
            if ($errorOutput) {
                Write-Host $errorOutput -ForegroundColor Yellow
            }
        }
        Write-Warning "Continuing anyway..."
    }
}
finally {
    Pop-Location
}

Push-Location $backendPath
try {
    $migrateArgs = $pythonArgs + @('manage.py', 'migrate', '--noinput')
    $migrateProcess = Start-Process -FilePath $pythonExe `
        -ArgumentList $migrateArgs `
        -WorkingDirectory $backendPath `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput (Join-Path $logsDir "django_migrate.txt") `
        -RedirectStandardError (Join-Path $logsDir "django_migrate_err.txt")

    if ($migrateProcess.ExitCode -ne 0) {
        Write-Error "Migration failed with exit code $($migrateProcess.ExitCode):"
        $migrateErrorFile = Join-Path $logsDir "django_migrate_err.txt"
        if (Test-Path $migrateErrorFile) {
            $errorOutput = Get-Content $migrateErrorFile -Raw
            if ($errorOutput) {
                Write-Host $errorOutput -ForegroundColor Red
            }
        }
        Write-Error "Cannot continue without migrations. Please fix the errors above."
        exit 1
    }
}
finally {
    Pop-Location
}

# Test if Django can start (check for syntax errors)
Push-Location $backendPath
try {
    $checkArgs = $pythonArgs + @('manage.py', 'check')
    $checkProcess = Start-Process -FilePath $pythonExe `
        -ArgumentList $checkArgs `
    -WorkingDirectory $backendPath `
    -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput (Join-Path $logsDir "django_check.txt") `
        -RedirectStandardError (Join-Path $logsDir "django_check_err.txt")

    if ($checkProcess.ExitCode -ne 0) {
        Write-Error "Django configuration check failed:"
        $checkErrorFile = Join-Path $logsDir "django_check_err.txt"
        if (Test-Path $checkErrorFile) {
            $errorOutput = Get-Content $checkErrorFile -Raw
            if ($errorOutput) {
                Write-Host $errorOutput -ForegroundColor Red
            }
        }
        Write-Error "Please fix the errors above before starting the server."
        exit 1
    }
}
finally {
    Pop-Location
}

# Check if port 8000 is already in use and stop any existing server

# Function to find all processes using port 8000
function Find-Port8000Processes {
    $processes = @()
    
    # Method 1: Check for processes using port 8000 via Get-NetTCPConnection
    try {
        $portConnections = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
        if ($portConnections) {
            $processes += $portConnections | Select-Object -ExpandProperty OwningProcess -Unique
        }
    } catch {
        # If Get-NetTCPConnection fails, continue with other methods
    }
    
    # Method 2: Check for Python processes that might be running Django/Daphne
    try {
        $allPython = Get-Process -Name python,pythonw -ErrorAction SilentlyContinue
        foreach ($proc in $allPython) {
            try {
                $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue).CommandLine
                if ($cmdLine) {
                    if ($cmdLine -like "*daphne*" -or 
                        $cmdLine -like "*manage.py*runserver*" -or 
                        $cmdLine -like "*core.asgi*" -or
                        $cmdLine -like "*8000*") {
                        $processes += $proc.Id
                    }
                }
            } catch {
                # If we can't get command line, check if it's a Python process (might be our server)
                # Only add if we don't already have it from port check
                if ($processes -notcontains $proc.Id) {
                    # Be conservative - don't kill Python processes without confirmation
                }
            }
        }
    } catch {
        # If process check fails, continue
    }
    
    # Method 3: Use netstat as fallback (more reliable on some systems)
    try {
        $netstatOutput = netstat -ano | Select-String ":8000.*LISTENING"
        if ($netstatOutput) {
            $netstatPids = $netstatOutput | ForEach-Object {
                if ($_ -match '\s+(\d+)\s*$') {
                    [int]$matches[1]
                }
            }
            $processes += $netstatPids
        }
    } catch {
        # If netstat fails, continue
    }
    
    return ($processes | Select-Object -Unique | Where-Object { $_ -ne $null -and $_ -gt 0 })
}

# Check multiple times to catch processes that might be starting
$maxAttempts = 3
$allFoundProcesses = @()
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    $foundProcesses = Find-Port8000Processes
    $allFoundProcesses += $foundProcesses
    if ($attempt -lt $maxAttempts) {
        Start-Sleep -Milliseconds 500
    }
}

# Get unique list of all processes found
$allProcesses = $allFoundProcesses | Select-Object -Unique | Where-Object { $_ -ne $null -and $_ -gt 0 }

if ($allProcesses) {
    Write-Host "Found existing server(s) on port 8000. Stopping them..." -ForegroundColor Yellow
    $stoppedCount = 0
    $allProcesses | ForEach-Object {
        try {
            $proc = Get-Process -Id $_ -ErrorAction SilentlyContinue
            if ($proc) {
                Write-Host "  Stopping process: $($proc.ProcessName) (PID: $_)" -ForegroundColor Yellow
                Stop-Process -Id $_ -Force -ErrorAction Stop
                $stoppedCount++
            }
        } catch {
            Write-Warning "  Could not stop process (PID: $_). You may need to stop it manually."
        }
    }
    
    # Wait longer for port to be released
    Start-Sleep -Seconds 4
    
    # Verify port is free - check multiple times
    $portStillInUse = $true
    for ($check = 1; $check -le 5; $check++) {
        try {
            $stillInUse = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
            if (-not $stillInUse) {
                $portStillInUse = $false
                break
            }
        } catch {
            # If check fails, assume port might be free
            $portStillInUse = $false
            break
        }
        Start-Sleep -Seconds 1
    }
    
    if ($portStillInUse) {
        Write-Warning "Port 8000 may still be in use. Attempting to continue anyway..."
        Start-Sleep -Seconds 2
    }
}

# Start backend in background (output will appear in this terminal)

# Determine which port to use (8000 or 8001 as fallback)
# Wait a moment for port to fully release after process cleanup
Start-Sleep -Seconds 2

# Function to reliably check if a port is in use
function Test-PortInUse {
    param([int]$Port)
    
    try {
        # Method 1: Try to bind to the port (most reliable)
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
        $listener.Start()
        $listener.Stop()
        return $false  # Port is free
    } catch {
        return $true  # Port is in use
    }
}

# Check ports with multiple methods
$backendPort = $null
$testPorts = @(8000, 8001, 8002, 8003)

foreach ($testPort in $testPorts) {
    $isInUse = Test-PortInUse -Port $testPort
    if (-not $isInUse) {
        $backendPort = $testPort
        if ($testPort -ne 8000) {
            Write-Host "Using port $testPort (8000 in use)" -ForegroundColor Yellow
        }
        break
    }
}

if (-not $backendPort) {
    Write-Error "All tested ports ($($testPorts -join ', ')) are in use. Please free one of them or stop other Django servers."
    Write-Host "`nTo manually free a port, run:" -ForegroundColor Yellow
    Write-Host "  netstat -ano | findstr :8000" -ForegroundColor Cyan
    Write-Host "  taskkill /PID <PID> /F" -ForegroundColor Cyan
    exit 1
}

# Start Django server with Daphne (for WebSocket support)
Push-Location $backendPath

# Build command arguments for Daphne
$daphneArgs = @('-m', 'daphne', 'core.asgi:application', '--bind', '0.0.0.0', '--port', "$backendPort")

# Redirect backend output to avoid interfering with Flutter's interactive commands
# (logsDir already created earlier in the script)
# Store in script scope so cleanup block can access them
# Use project logs directory instead of system temp
$script:backendOutputFile = Join-Path $logsDir "django_backend_output_$backendPort.txt"
$script:backendErrorFile = Join-Path $logsDir "django_backend_error_$backendPort.txt"

if ($pythonArgs.Count -gt 0) {
    $allArgs = $pythonArgs + $daphneArgs
    $backendProcess = Start-Process -FilePath $pythonExe `
        -ArgumentList $allArgs `
        -WorkingDirectory $backendPath `
        -NoNewWindow `
        -PassThru `
        -RedirectStandardOutput $script:backendOutputFile `
        -RedirectStandardError $script:backendErrorFile
} else {
    $backendProcess = Start-Process -FilePath $pythonExe `
        -ArgumentList $daphneArgs `
    -WorkingDirectory $backendPath `
    -NoNewWindow `
        -PassThru `
        -RedirectStandardOutput $script:backendOutputFile `
        -RedirectStandardError $script:backendErrorFile
}

Pop-Location

# Wait a moment for server to start
Start-Sleep -Seconds 3

# Check if backend process is still running
if ($backendProcess -and !$backendProcess.HasExited) {
    Write-Host "Backend started on port $backendPort" -ForegroundColor Green
    
    # Set up log tailing using runspace for real-time console output
    # Wait a moment for log file to be created
    Start-Sleep -Seconds 1
    
    # Create a runspace that outputs directly to console
    $script:logTailRunspace = [runspacefactory]::CreateRunspace()
    $script:logTailRunspace.ApartmentState = [System.Threading.ApartmentState]::STA
    # ThreadOptions is not available in all PowerShell versions, so we skip it
    # The runspace will work fine without it
    $script:logTailRunspace.Open()
    
    $ps = [PowerShell]::Create()
    $ps.Runspace = $script:logTailRunspace
    
    # Script that tails logs and writes directly to host
    $tailScript = @"
        `$outputFile = '$($script:backendOutputFile)'
        `$errorFile = '$($script:backendErrorFile)'
        `$lastSize = 0
        `$lastErrorSize = 0
        
        while (`$true) {
            # Check output file
            if (Test-Path `$outputFile) {
                try {
                    `$file = Get-Item `$outputFile -ErrorAction SilentlyContinue
                    if (`$file -and `$file.Length -gt `$lastSize) {
                        `$stream = [System.IO.FileStream]::new(`$outputFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                        `$stream.Position = `$lastSize
                        `$reader = New-Object System.IO.StreamReader(`$stream)
                        while (`$null -ne (`$line = `$reader.ReadLine())) {
                            if (`$line.Trim()) {
                                [Console]::WriteLine("[BACKEND] `$line")
                            }
                        }
                        `$lastSize = `$stream.Position
                        `$reader.Close()
                        `$stream.Close()
                    }
                } catch { }
            }
            
            # Check error file
            if (Test-Path `$errorFile) {
                try {
                    `$file = Get-Item `$errorFile -ErrorAction SilentlyContinue
                    if (`$file -and `$file.Length -gt `$lastErrorSize) {
                        `$stream = [System.IO.FileStream]::new(`$errorFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                        `$stream.Position = `$lastErrorSize
                        `$reader = New-Object System.IO.StreamReader(`$stream)
                        while (`$null -ne (`$line = `$reader.ReadLine())) {
                            if (`$line.Trim()) {
                                [Console]::ForegroundColor = [ConsoleColor]::Red
                                [Console]::WriteLine("[BACKEND ERROR] `$line")
                                [Console]::ResetColor()
                            }
                        }
                        `$lastErrorSize = `$stream.Position
                        `$reader.Close()
                        `$stream.Close()
                    }
                } catch { }
            }
            
            Start-Sleep -Milliseconds 300
        }
"@
    
    $ps.AddScript($tailScript) | Out-Null
    $script:logTailHandle = $ps.BeginInvoke()
    $script:logTailPowerShell = $ps
    
    # Store reference for cleanup
    $script:backendProcess = $backendProcess
    $script:backendPort = $backendPort
} else {
    Write-Error "Daphne server failed to start!"
    if ($backendProcess -and $backendProcess.HasExited) {
        Write-Host "Process exited with code: $($backendProcess.ExitCode)" -ForegroundColor Yellow
    }
    Write-Host "Troubleshooting: pip install daphne, check port $backendPort, verify venv" -ForegroundColor Yellow
    exit 1
}

if ($Device -eq 'windows') {
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


# Check if Flutter is available in PATH
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (!$flutterCmd) {
    # Try to find Flutter in common installation locations
    $flutterPaths = @(
        "$env:LOCALAPPDATA\flutter\bin\flutter.bat",
        "$env:ProgramFiles\flutter\bin\flutter.bat",
        "$env:ProgramFiles(x86)\flutter\bin\flutter.bat",
        "$env:USERPROFILE\flutter\bin\flutter.bat",
        "$env:USERPROFILE\AppData\Local\flutter\bin\flutter.bat",
        "C:\src\flutter\bin\flutter.bat",
        "C:\flutter\bin\flutter.bat",
        "D:\flutter\bin\flutter.bat",
        "E:\flutter\bin\flutter.bat",
        "$env:USERPROFILE\Documents\flutter\bin\flutter.bat",
        "$env:USERPROFILE\Downloads\flutter\bin\flutter.bat"
    )
    
    # Also search in common development directories
    $devDirs = @("C:\src", "C:\dev", "C:\development", "D:\dev", "D:\development", "$env:USERPROFILE\dev", "$env:USERPROFILE\development")
    foreach ($devDir in $devDirs) {
        if (Test-Path $devDir) {
            $flutterPaths += "$devDir\flutter\bin\flutter.bat"
        }
    }
    
    $flutterFound = $false
    foreach ($path in $flutterPaths) {
        if (Test-Path $path) {
            $flutterCmd = $path
            $flutterFound = $true
            break
        }
    }
    
    if (!$flutterFound) {
        Write-Host "Flutter not found - Running backend only on port $backendPort" -ForegroundColor Yellow
        Write-Host "Install: https://flutter.dev/docs/get-started/install/windows" -ForegroundColor Gray
        Write-Host "Press Ctrl+C to stop the backend." -ForegroundColor Yellow
        
        # Wait for user to stop backend
        try {
            while ($true) {
                Start-Sleep -Seconds 1
            }
        }
        catch {
            # User pressed Ctrl+C
        }
        exit 0
    }
} else {
    $flutterCmd = "flutter"
}

Write-Host "API: http://127.0.0.1:$backendPort/api | WebSocket: ws://127.0.0.1:$backendPort/ws/chat/<chat_id>/" -ForegroundColor Green

# Create Flutter log file paths (for reference, Flutter runs interactively)
$script:flutterLogFile = Join-Path $logsDir "flutter_output.log"
$script:flutterErrorLogFile = Join-Path $logsDir "flutter_error.log"

Push-Location $flutterPath
try {
    $flutterArgs = @('run', '-d', $Device)
    if ($Release) {
        $flutterArgs += '--release'
    }
    
    Write-Host "Starting Flutter app on $Device..." -ForegroundColor Cyan
    
    # Run Flutter directly - this blocks and shows output in this terminal
    # Backend logs are being displayed in real-time via the runspace (running in parallel)
    # Note: DevTools cleanup errors are harmless and can be ignored
    # Flutter needs to run directly for hot reload to work properly
    & $flutterCmd @flutterArgs
}
catch {
    $errorMsg = $_.ToString()
    # DevTools cleanup errors are harmless - don't show them as critical errors
    if ($errorMsg -match "DevTools|websocket.*tooling|SocketException.*refused.*network connection") {
        Write-Host "[FLUTTER] Note: DevTools cleanup warning (harmless)" -ForegroundColor Yellow
    } else {
        Write-Host "[FLUTTER] Error: $errorMsg" -ForegroundColor Red
    }
}
finally {
    Pop-Location
    Write-Host "`nCleaning up..." -ForegroundColor Yellow
    
    # Stop log tailing runspace
    if ($script:logTailPowerShell) {
        try {
            $script:logTailPowerShell.Stop() | Out-Null
            $script:logTailPowerShell.Dispose() | Out-Null
        } catch { }
    }
    if ($script:logTailRunspace) {
        try {
            $script:logTailRunspace.Close() | Out-Null
            $script:logTailRunspace.Dispose() | Out-Null
        } catch { }
    }
    
    # Stop the backend process gracefully
    if ($script:backendProcess -and !$script:backendProcess.HasExited) {
        try {
            $script:backendProcess.CloseMainWindow() | Out-Null
            if (-not $script:backendProcess.HasExited) {
                Start-Sleep -Seconds 1
                $script:backendProcess.Kill()
            }
        }
        catch {
            if (-not $script:backendProcess.HasExited) {
                $script:backendProcess.Kill()
            }
        }
        $script:backendProcess.WaitForExit()
    }
    
}

Write-Host "All processes stopped." -ForegroundColor Green