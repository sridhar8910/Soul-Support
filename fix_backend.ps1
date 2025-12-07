# Quick fix script to stop blocking process and restart backend
Write-Host "=== Fixing Backend Connection ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Stop process blocking port 8000
Write-Host "[1/3] Stopping process blocking port 8000..." -ForegroundColor Yellow
$blockingProcess = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
if ($blockingProcess) {
    foreach ($pid in $blockingProcess) {
        try {
            $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if ($proc) {
                Write-Host "  Found process: $($proc.ProcessName) (PID: $pid)" -ForegroundColor Yellow
                Write-Host "  Attempting to stop..." -ForegroundColor Yellow
                Stop-Process -Id $pid -Force -ErrorAction Stop
                Write-Host "  ✓ Process stopped" -ForegroundColor Green
            }
        } catch {
            Write-Warning "  ✗ Could not stop process $pid. You may need to:"
            Write-Host "    1. Open Task Manager" -ForegroundColor Yellow
            Write-Host "    2. Find process with PID $pid" -ForegroundColor Yellow
            Write-Host "    3. End the process manually" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  Or run PowerShell as Administrator and try again." -ForegroundColor Yellow
        }
    }
    Start-Sleep -Seconds 2
} else {
    Write-Host "  ✓ Port 8000 is free" -ForegroundColor Green
}

Write-Host ""
Write-Host "[2/3] Checking for available ports..." -ForegroundColor Cyan
$testPorts = @(8000, 8080, 9001, 8001)
foreach ($port in $testPorts) {
    $isUsed = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($isUsed) {
        Write-Host "  Port $port: ✗ In use" -ForegroundColor Red
    } else {
        Write-Host "  Port $port: ✓ Available" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "[3/3] Next Steps:" -ForegroundColor Cyan
Write-Host "  1. If port 8000 is now free, restart your backend:" -ForegroundColor White
Write-Host "     .\run_counsellor.ps1 -d chrome" -ForegroundColor Green
Write-Host ""
Write-Host "  2. If port 8000 is still blocked, the script will automatically" -ForegroundColor White
Write-Host "     use port 8080 or 9001. The Flutter app will auto-detect it." -ForegroundColor White
Write-Host ""
Write-Host "  3. If you need to manually stop the blocking process:" -ForegroundColor White
Write-Host "     - Open Task Manager (Ctrl+Shift+Esc)" -ForegroundColor Yellow
Write-Host "     - Go to Details tab" -ForegroundColor Yellow
Write-Host "     - Find process with PID 2556 (or any PID using port 8000)" -ForegroundColor Yellow
Write-Host "     - Right-click and select 'End Task'" -ForegroundColor Yellow
Write-Host ""

