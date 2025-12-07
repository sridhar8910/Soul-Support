param(
    [switch]$Release,
    [string]$DeviceId,
    [string]$AvdName,
    [string]$LanIp,
    [int]$BackendPort = 8000,
    [int]$DeviceBootTimeoutSeconds = 240,
    [switch]$SkipEmulatorLaunch,
    [ValidateSet("host", "angle_indirect", "swiftshader_indirect")]
    [string]$GpuMode = "host",
    [switch]$AutoKill,
    [switch]$WipeData
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "➡ $Message" -ForegroundColor Cyan
}

function Ensure-Path {
    param([string]$Path, [string]$Description)
    if (-not (Test-Path $Path)) {
        throw "$Description not found at '$Path'."
    }
}

function Ensure-Command {
    param([string]$Command, [string]$Hint)
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        if (-not $Hint) { $Hint = "Install $Command and add it to PATH." }
        throw "Required command '$Command' not found. $Hint"
    }
}

function Add-EnvPath {
    param([string]$PathToAdd)
    if ([string]::IsNullOrWhiteSpace($PathToAdd)) { return }
    if (-not (Test-Path $PathToAdd)) { return }
    if ($env:PATH.Split([IO.Path]::PathSeparator) -notcontains $PathToAdd) {
        $env:PATH = "$env:PATH$([IO.Path]::PathSeparator)$PathToAdd"
    }
}

function Get-AndroidSdkRoot {
    if ($env:ANDROID_HOME) { return $env:ANDROID_HOME }
    if ($env:ANDROID_SDK_ROOT) { return $env:ANDROID_SDK_ROOT }
    return Join-Path $env:LOCALAPPDATA "Android\Sdk"
}

function Test-PortAvailable {
    param([int]$Port)
    $connection = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    return (-not $connection)
}

function Get-PidUsingPort {
    param([int]$Port)
    $connections = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    if ($connections) {
        return $connections | Select-Object -ExpandProperty OwningProcess -Unique
    }
    return $null
}

function Try-FreePort {
    param([int]$Port, [bool]$AutoKill)
    
    $pids = Get-PidUsingPort -Port $Port
    if (-not $pids) {
        return $true  # Port is already free
    }
    
    Write-Host "Port $Port is in use by PID(s): $($pids -join ', ')" -ForegroundColor Yellow
    
    $shouldKill = $AutoKill
    if (-not $AutoKill) {
        $processNames = $pids | ForEach-Object {
            $proc = Get-Process -Id $_ -ErrorAction SilentlyContinue
            if ($proc) { "$($proc.ProcessName) (PID: $_)" } else { "PID: $_" }
        }
        Write-Host "  Process(es): $($processNames -join ', ')" -ForegroundColor Gray
        $response = Read-Host "Kill process(es) to free port ${Port}? (Y/N) [N]"
        $shouldKill = ($response -match '^[Yy]')
    }
    
    if ($shouldKill) {
        $allKilled = $true
        foreach ($processId in $pids) {
            try {
                $proc = Get-Process -Id $processId -ErrorAction SilentlyContinue
                if ($proc) {
                    Write-Host "  Stopping process: $($proc.ProcessName) (PID: $processId)" -ForegroundColor Yellow
                    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
                }
            } catch {
                # Try taskkill as fallback
                try {
                    & taskkill /F /PID $processId 2>&1 | Out-Null
                } catch {
                    Write-Warning "  Failed to kill PID $processId : $($_.Exception.Message)"
                    $allKilled = $false
                }
            }
        }
        Start-Sleep -Milliseconds 500
        if ($allKilled -and (Test-PortAvailable -Port $Port)) {
            Write-Host "Port $Port is now free." -ForegroundColor Green
            return $true
        }
    }
    
    return $false
}

function Find-AvailablePort {
    param([int[]]$PortList, [bool]$AutoKill = $false)
    
    foreach ($port in $PortList) {
        if (Test-PortAvailable -Port $port) {
            return $port
        }
        
        # Try to free the port if possible
        if (Try-FreePort -Port $port -AutoKill $AutoKill) {
            return $port
        }
        
        Write-Host "  Port $port unavailable, trying next..." -ForegroundColor Gray
    }
    return $null
}

function Get-AdbDevices {
    # Temporarily change error action to prevent termination on adb daemon messages
    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        # Capture both stdout and stderr, filter out daemon startup messages
        $output = & adb devices 2>&1 | ForEach-Object {
            $line = if ($_ -is [System.Management.Automation.ErrorRecord]) {
                # Convert error records to strings, but filter out daemon messages
                $_.Exception.Message
            } else {
                $_.ToString()
            }
            # Skip daemon startup messages
            if ($line -like "*daemon*") {
                return $null
            }
            return $line
        } | Where-Object { $_ -ne $null }
        
        foreach ($line in $output) {
            $trimmed = $line.Trim()
            if (-not $trimmed) { continue }
            if ($trimmed -like "List of devices*") { continue }
            $parts = $trimmed -split "\s+"
            if ($parts.Count -ge 2) {
                [PSCustomObject]@{
                    Id     = $parts[0]
                    Status = $parts[1]
                }
            }
        }
    } catch {
        # Return empty array if adb fails
        return @()
    } finally {
        $ErrorActionPreference = $oldErrorAction
    }
}

function Wait-ForDeviceReady {
    param(
        [string]$DeviceId,
        [int]$TimeoutSeconds = 240
    )

    Write-Host "Waiting for device $DeviceId to be ready..." -ForegroundColor Cyan
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $lastStatus = ""
    
    while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        # Check if device appears in adb devices
        $state = Get-AdbDevices | Where-Object { $_.Id -eq $DeviceId -and $_.Status -eq "device" }
        if ($state) {
            # Check boot completion
            $booted = (& adb -s $DeviceId shell getprop sys.boot_completed 2>$null | Out-String).Trim()
            if ($booted -eq "1") {
                # Additional check: ensure package manager is ready
                $pmReady = (& adb -s $DeviceId shell pm path android 2>$null | Out-String).Trim()
                if ($pmReady -and -not $pmReady.Contains("error")) {
                    Write-Host "Device $DeviceId is ready!" -ForegroundColor Green
                    return $true
                }
            }
            
            $currentStatus = "Device connected, booting... (boot_completed=$booted)"
            if ($currentStatus -ne $lastStatus) {
                Write-Host "  $currentStatus" -ForegroundColor Gray
                $lastStatus = $currentStatus
            }
        } else {
            $currentStatus = "Waiting for device to appear in ADB..."
            if ($currentStatus -ne $lastStatus) {
                Write-Host "  $currentStatus" -ForegroundColor Yellow
                $lastStatus = $currentStatus
            }
        }
        Start-Sleep -Seconds 3
    }
    
    Write-Host "Device $DeviceId did not become ready within $TimeoutSeconds seconds." -ForegroundColor Red
    return $false
}

function Launch-Emulator {
    param(
        [string]$EmulatorExecutable,
        [string]$GpuMode,
        [int]$TimeoutSeconds,
        [bool]$WipeData = $false,
        [string]$AvdName = $null
    )

    $avdList = (& $EmulatorExecutable -list-avds 2>$null | Out-String).Trim().Split("`r`n", [System.StringSplitOptions]::RemoveEmptyEntries)
    if (-not $avdList -or $avdList.Count -eq 0) {
        throw "No Android Virtual Devices defined. Create one from Android Studio."
    }

    if ($AvdName) {
        # find a match (case-insensitive)
        $match = $avdList | Where-Object { $_.Trim().ToLower() -eq $AvdName.Trim().ToLower() }
        if (-not $match) {
            Write-Host "Requested AVD '$AvdName' not found. Available AVDs: $($avdList -join ', ')" -ForegroundColor Red
            throw "Requested AVD not found."
        }
        $avdName = $match.Trim()
    } else {
        $avdName = $avdList[0].Trim()
    }
    if ($WipeData) {
        Write-Step "Launching emulator '$avdName' with WIPE DATA (GPU: $GpuMode, Memory: 4096MB)"
    } else {
        Write-Step "Launching emulator '$avdName' (GPU: $GpuMode, Memory: 4096MB)"
    }

    $emuArgs = @(
        "-avd", $avdName,
        "-netfast",
        "-no-snapshot-load",  # Force fresh boot (prevents corrupted snapshot hangs)
        "-no-snapshot-save",  # Don't save snapshot on exit
        "-memory", "4096",    # Use 4096MB RAM (updated in AVD config)
        "-gpu", $GpuMode
    )
    
    if ($WipeData) {
        $emuArgs += "-wipe-data"  # Wipe user data (fixes corrupted AVD state)
        Write-Host "WARNING: Wipe data enabled - all user data will be erased!" -ForegroundColor Yellow
    }

    $process = Start-Process -FilePath $EmulatorExecutable -ArgumentList $emuArgs -PassThru
    Start-Sleep -Seconds 5

    $timer = [Diagnostics.Stopwatch]::StartNew()
    while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $device = Get-AdbDevices | Select-Object -First 1
        if ($device) {
            if (Wait-ForDeviceReady -DeviceId $device.Id -TimeoutSeconds ($TimeoutSeconds - [int]$timer.Elapsed.TotalSeconds)) {
                return [PSCustomObject]@{
                    Id       = $device.Id
                    Process  = $process
                    Launched = $true
                }
            }
            break
        }
        Start-Sleep -Seconds 3
    }

    $process | Stop-Process -Force -ErrorAction SilentlyContinue
    $suggestion = ""
    if ($GpuMode -eq "host") {
        $suggestion = " Try using `-GpuMode angle_indirect` or `-GpuMode swiftshader_indirect` for software rendering."
    } elseif ($GpuMode -eq "angle_indirect") {
        $suggestion = " Try using `-GpuMode swiftshader_indirect` for software rendering, or `-GpuMode host` for hardware acceleration."
    } else {
        $suggestion = " Try using `-GpuMode host` for hardware acceleration or `-GpuMode angle_indirect` for ANGLE rendering."
    }
    throw "Emulator failed to boot within $TimeoutSeconds seconds. Check emulator logs (missing opengl32sw.dll is common).$suggestion"
}

function Resolve-Device {
    param(
        [string]$DeviceId,
        [switch]$AllowLaunch,
        [string]$EmulatorExecutable,
        [string]$GpuMode,
        [int]$TimeoutSeconds,
        [bool]$WipeData = $false,
        [string]$AvdName = $null
    )

    if ($DeviceId) {
        Write-Step "Targeting requested device '$DeviceId'"
        if (Wait-ForDeviceReady -DeviceId $DeviceId -TimeoutSeconds $TimeoutSeconds) {
            return [PSCustomObject]@{ Id = $DeviceId; Launched = $false; Process = $null }
        }
        throw "Device '$DeviceId' not detected over adb."
    }

    $connected = Get-AdbDevices | Where-Object { $_.Status -eq "device" } | Select-Object -First 1
    if ($connected) {
        Write-Step "Using connected device $($connected.Id)"
        return [PSCustomObject]@{ Id = $connected.Id; Launched = $false; Process = $null }
    }

    if (-not $AllowLaunch) {
        throw "No Android devices detected and emulator launch disabled."
    }

    return Launch-Emulator -EmulatorExecutable $EmulatorExecutable -GpuMode $GpuMode -TimeoutSeconds $TimeoutSeconds -WipeData $WipeData -AvdName $AvdName
}

function Resolve-LanIp {
    param([string]$Preferred, [string]$DeviceId)

    if ($Preferred) { return $Preferred }
    if ($DeviceId -like "emulator-*") { return "10.0.2.2" }

    $ip = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike "169.254.*" -and
            $_.IPAddress -ne "127.0.0.1" -and
            $_.InterfaceAlias -notlike "*Virtual*"
        } |
        Sort-Object SkipAsSource, PrefixOrigin |
        Select-Object -First 1

    if ($ip) { return $ip.IPAddress }
    return "127.0.0.1"
}

function Stop-ProcessSafe {
    param([Diagnostics.Process]$Process)
    if (-not $Process) { return }
    try {
        if (-not $Process.HasExited) {
            $Process.CloseMainWindow() | Out-Null
            Start-Sleep -Milliseconds 300
        }
        if (-not $Process.HasExited) {
            $Process.Kill()
        }
        $Process.WaitForExit()
    } catch {
        # ignore
    }
}

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $projectRoot) { $projectRoot = Get-Location }

$backendDir = Join-Path $projectRoot "backend"
$flutterDir = Join-Path $projectRoot "apps\app_user"
$pythonExe  = Join-Path $projectRoot ".venv\Scripts\python.exe"
$managePy   = Join-Path $backendDir "manage.py"

Write-Step "Validating project structure"
Ensure-Path $backendDir "Backend directory"
Ensure-Path $flutterDir "Flutter directory"
Ensure-Path $pythonExe  "Backend virtualenv Python"
Ensure-Path $managePy   "manage.py"
Ensure-Path (Join-Path $flutterDir "pubspec.yaml") "Flutter pubspec"

Ensure-Command "flutter" "Install Flutter SDK and ensure 'flutter' is in PATH."

$sdkRoot = Get-AndroidSdkRoot
Ensure-Path $sdkRoot "Android SDK root"
Add-EnvPath (Join-Path $sdkRoot "platform-tools")
Add-EnvPath (Join-Path $sdkRoot "emulator")
Ensure-Command "adb" "Install Android platform-tools from the SDK Manager."

$emulatorExe = Join-Path $sdkRoot "emulator\emulator.exe"
Ensure-Path $emulatorExe "Android emulator executable"

$softwareGl = Join-Path $sdkRoot "emulator\lib64\opengl32sw.dll"
if (-not (Test-Path $softwareGl) -and $GpuMode -eq "swiftshader_indirect") {
    Write-Warning "opengl32sw.dll missing. SwiftShader software rendering may fail. Consider using `-GpuMode host` for hardware acceleration or `-GpuMode angle_indirect` for ANGLE rendering."
}

Write-Step "Resolving Android target"
$deviceInfo = Resolve-Device -DeviceId $DeviceId -AllowLaunch:(-not $SkipEmulatorLaunch) -EmulatorExecutable $emulatorExe -GpuMode $GpuMode -TimeoutSeconds $DeviceBootTimeoutSeconds -WipeData $WipeData -AvdName $AvdName
$targetDeviceId = $deviceInfo.Id

Write-Step "Creating and running database migrations"
Push-Location $backendDir
try {
    # First, make all migrations
    Write-Host "Creating migrations..." -ForegroundColor Cyan
    $makemigrationsArgs = @("manage.py", "makemigrations")
    $makemigrationsProcess = Start-Process -FilePath $pythonExe -ArgumentList $makemigrationsArgs -WorkingDirectory $backendDir -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$env:TEMP\django_makemigrations_android.txt" -RedirectStandardError "$env:TEMP\django_makemigrations_android_err.txt"
    
    if ($makemigrationsProcess.ExitCode -ne 0) {
        Write-Warning "makemigrations had issues (exit code: $($makemigrationsProcess.ExitCode))"
        if (Test-Path "$env:TEMP\django_makemigrations_android_err.txt") {
            $errorOutput = Get-Content "$env:TEMP\django_makemigrations_android_err.txt" -Raw
            if ($errorOutput) {
                Write-Host $errorOutput -ForegroundColor Yellow
            }
        }
    } else {
        $makemigrationsOutput = ""
        if (Test-Path "$env:TEMP\django_makemigrations_android.txt") {
            $makemigrationsOutput = Get-Content "$env:TEMP\django_makemigrations_android.txt" -Raw
        }
        if ($makemigrationsOutput -and $makemigrationsOutput -notmatch "No changes detected") {
            Write-Host "New migrations created:" -ForegroundColor Green
            Write-Host $makemigrationsOutput -ForegroundColor Gray
        } else {
            Write-Host "No new migrations to create." -ForegroundColor Gray
        }
    }
    
    # Then, apply migrations
    Write-Host "Applying migrations..." -ForegroundColor Cyan
    $migrateArgs = @("manage.py", "migrate", "--noinput")
    $migrateProcess = Start-Process -FilePath $pythonExe -ArgumentList $migrateArgs -WorkingDirectory $backendDir -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$env:TEMP\django_migrate_android.txt" -RedirectStandardError "$env:TEMP\django_migrate_android_err.txt"
    
    if ($migrateProcess.ExitCode -ne 0) {
        Write-Warning "Migration had issues (exit code: $($migrateProcess.ExitCode))"
        if (Test-Path "$env:TEMP\django_migrate_android_err.txt") {
            $errorOutput = Get-Content "$env:TEMP\django_migrate_android_err.txt" -Raw
            if ($errorOutput) {
                Write-Host $errorOutput -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "Migrations applied successfully." -ForegroundColor Green
    }
}
finally {
    Pop-Location
}

Write-Step "Starting Django backend with Daphne (ASGI for WebSocket support)"
# List of ports to try in order (priority: requested port first, then common alternatives)
$portList = @($BackendPort, 8001, 8080, 9001, 9002, 3000)

# Find an available port from the list (will attempt to free ports if AutoKill is set or user approves)
Write-Host "Finding available port from: $($portList -join ', ')" -ForegroundColor Cyan
if ($AutoKill) {
    Write-Host "AutoKill mode: will automatically free occupied ports when possible." -ForegroundColor Yellow
}
$selectedPort = Find-AvailablePort -PortList $portList -AutoKill $AutoKill

if (-not $selectedPort) {
    Write-Host "ERROR: None of the ports ($($portList -join ', ')) are available." -ForegroundColor Red
    Write-Host "Please free up a port or manually stop processes using:" -ForegroundColor Yellow
    $portList | ForEach-Object {
        $pids = Get-PidUsingPort -Port $_
        if ($pids) {
            $processNames = $pids | ForEach-Object {
                $proc = Get-Process -Id $_ -ErrorAction SilentlyContinue
                if ($proc) { "$($proc.ProcessName) (PID: $_)" } else { "PID: $_" }
            }
            Write-Host "  Port $_ is in use by: $($processNames -join ', ')" -ForegroundColor Yellow
            Write-Host "    netstat -ano | findstr :$_" -ForegroundColor Gray
            Write-Host "    taskkill /F /PID <PID>" -ForegroundColor Gray
        }
    }
    throw "No available port found. Please free up at least one port from the list or run with -AutoKill to automatically free ports."
}

# Update BackendPort to the selected port
if ($selectedPort -ne $BackendPort) {
    Write-Host "Port $BackendPort was not available. Selected port $selectedPort instead." -ForegroundColor Yellow
    $BackendPort = $selectedPort
} else {
    Write-Host "Using requested port $BackendPort" -ForegroundColor Green
}

# Use Daphne for ASGI (WebSocket support) - REQUIRED for WebSocket functionality
# Build arguments as array for Start-Process
$backendArgs = @("-m", "daphne", "core.asgi:application", "--bind", "0.0.0.0", "--port", "$BackendPort")
$backendProcess = Start-Process -FilePath $pythonExe -ArgumentList $backendArgs -WorkingDirectory $backendDir -NoNewWindow -PassThru
Start-Sleep -Seconds 3

Write-Step "Running Flutter app"
# Verify device is still connected and ready before running Flutter
Write-Host "Verifying device $targetDeviceId is ready..." -ForegroundColor Cyan
$deviceReady = Wait-ForDeviceReady -DeviceId $targetDeviceId -TimeoutSeconds 30
if (-not $deviceReady) {
    Write-Host "WARNING: Device $targetDeviceId may not be fully ready. Attempting to continue anyway..." -ForegroundColor Yellow
    Write-Host "If Flutter fails, try manually: adb -s $targetDeviceId shell getprop sys.boot_completed" -ForegroundColor Gray
}

$lanIp = Resolve-LanIp -Preferred $LanIp -DeviceId $targetDeviceId
$backendUrl = "http://$($lanIp):$BackendPort/api"
Write-Host "Backend URL injected into Flutter: $backendUrl" -ForegroundColor Yellow

$flutterArgs = @("run", "-d", $targetDeviceId, "--dart-define=BACKEND_BASE_URL=$backendUrl")
if ($Release) { $flutterArgs += "--release" }

Push-Location $flutterDir
try {
    Write-Host "Starting Flutter build and deployment..." -ForegroundColor Cyan
    flutter @flutterArgs
} finally {
    Pop-Location
    Write-Step "Cleaning up"
    Stop-ProcessSafe -Process $backendProcess
    if ($deviceInfo.Launched) {
        Stop-ProcessSafe -Process $deviceInfo.Process
    }
}


