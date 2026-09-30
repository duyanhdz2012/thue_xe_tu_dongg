@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"
set "CHECK_ONLY=0"
if /I "%~1"=="--check" set "CHECK_ONLY=1"

title DriveNow - Stop all services
cd /d "%PROJECT_DIR%"

echo ============================================================
echo   DriveNow - Stop all project services safely
echo ============================================================
echo.

if "%CHECK_ONLY%"=="1" goto check_only

echo [1/7] Stopping Auth Service on port 8081...
call :stop_port 8081 java

echo [2/7] Stopping Car Service on port 8082...
call :stop_port 8082 java

echo [3/7] Stopping Booking Service on port 8083...
call :stop_port 8083 java

echo [4/7] Stopping API Gateway on port 8080...
call :stop_port 8080 java

echo [5/7] Stopping Next.js frontend on port 3000...
call :stop_port 3000 node

echo [6/7] Stopping ngrok tunnels that forward to port 8080...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$items = Get-CimInstance Win32_Process -Filter 'Name=''ngrok.exe''' -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match '(?i)\bhttp\s+(?:https?://)?(?:localhost:)?8080\b' }; if (-not $items) { Write-Host '[INFO] No project ngrok tunnel is running.' } else { foreach ($item in $items) { Write-Host ('[STOP] ngrok PID ' + $item.ProcessId); Stop-Process -Id $item.ProcessId -Force -ErrorAction SilentlyContinue } }"

echo [7/7] Stopping MySQL container without deleting data...
where docker >nul 2>&1
if errorlevel 1 (
    echo [INFO] Docker CLI was not found. MySQL was not changed.
) else (
    docker info >nul 2>&1
    if errorlevel 1 (
        echo [INFO] Docker Desktop is not running. MySQL is already unavailable.
    ) else (
        docker compose stop mysql
        if errorlevel 1 (
            echo [WARN] Docker could not stop the MySQL service. Review the message above.
        ) else (
            echo [OK] MySQL stopped. Docker volume and database data were preserved.
        )
    )
)

call :close_project_windows

echo.
echo ============================================================
echo Project services have been stopped.
echo MySQL data was preserved. This file never runs docker compose down -v.
echo ============================================================
timeout /t 5 /nobreak >nul
exit /b 0

:stop_port
powershell -NoProfile -ExecutionPolicy Bypass -Command "$port = %~1; $expected = '%~2'; $ids = @(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique); if ($ids.Count -eq 0) { Write-Host ('[INFO] Port ' + $port + ' is already free.'); exit 0 }; foreach ($ownerId in $ids) { $process = Get-Process -Id $ownerId -ErrorAction SilentlyContinue; if ($process -and $process.ProcessName -ieq $expected) { Write-Host ('[STOP] ' + $process.ProcessName + ' PID ' + $ownerId + ' on port ' + $port); Stop-Process -Id $ownerId -Force -ErrorAction SilentlyContinue } elseif ($process) { Write-Host ('[SKIP] Port ' + $port + ' belongs to ' + $process.ProcessName + ' PID ' + $ownerId + ', not this project process.') } }"
exit /b 0

:close_project_windows
taskkill /FI "WINDOWTITLE eq 01 - MySQL logs (3307)*" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq 02 - Auth Service (8081)*" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq 03 - Car Service (8082)*" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq 04 - Booking Service (8083)*" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq 05 - API Gateway (8080)*" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq 06 - Frontend (3000)*" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq 07 - Ngrok to Gateway (8080)*" /T /F >nul 2>&1
exit /b 0

:check_only
echo Validation mode: no process or container will be stopped.
echo.
for %%P in (3000 8080 8081 8082 8083) do (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$items = @(Get-NetTCPConnection -State Listen -LocalPort %%P -ErrorAction SilentlyContinue); if ($items.Count -gt 0) { $ids = $items.OwningProcess | Select-Object -Unique; Write-Host ('[RUNNING] Port %%P - PID ' + ($ids -join ', ')) } else { Write-Host '[STOPPED] Port %%P' }"
)

where docker >nul 2>&1
if errorlevel 1 (
    echo [INFO] Docker CLI was not found.
) else (
    docker info >nul 2>&1
    if errorlevel 1 (
        echo [STOPPED] Docker Desktop is not running.
    ) else (
        docker compose ps mysql
    )
)
echo.
echo Validation completed. Nothing was stopped.
exit /b 0
