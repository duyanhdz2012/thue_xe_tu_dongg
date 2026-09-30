@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"
set "FRONTEND_DIR=%PROJECT_DIR%\car-rental-frontend"
set "CHECK_ONLY=0"
if /I "%~1"=="--check" set "CHECK_ONLY=1"

title DriveNow - Start all services
cd /d "%PROJECT_DIR%"

echo ============================================================
echo   DriveNow - MySQL + 4 backend apps + frontend + ngrok
echo ============================================================
echo.

call :require_command docker "Docker Desktop / docker CLI"
if errorlevel 1 goto failed
call :require_command java "Java 21"
if errorlevel 1 goto failed
call :require_command npm "Node.js / npm"
if errorlevel 1 goto failed

docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker Desktop is not running.
    echo         Open Docker Desktop, wait until it is ready, then run this file again.
    goto failed
)

set "BUILD_REQUIRED=0"
if not exist "%PROJECT_DIR%\auth-service\target\auth-service-1.0.0.jar" set "BUILD_REQUIRED=1"
if not exist "%PROJECT_DIR%\car-service\target\car-service-1.0.0.jar" set "BUILD_REQUIRED=1"
if not exist "%PROJECT_DIR%\booking-service\target\booking-service-1.0.0.jar" set "BUILD_REQUIRED=1"
if not exist "%PROJECT_DIR%\api-gateway\target\api-gateway-1.0.0.jar" set "BUILD_REQUIRED=1"

if "%BUILD_REQUIRED%"=="1" (
    call :find_maven
    if errorlevel 1 goto failed
)

if "%CHECK_ONLY%"=="1" (
    echo [OK] Docker Desktop is running.
    echo [OK] Java and npm are available.
    if "%BUILD_REQUIRED%"=="1" (
        echo [OK] Backend JARs are missing, but Maven is available for automatic build.
    ) else (
        echo [OK] All backend JARs are available.
    )
    if exist "C:\ngrok.exe" (
        echo [OK] Optional ngrok executable found at C:\ngrok.exe.
    ) else (
        echo [INFO] C:\ngrok.exe was not found. The other 6 terminals can still run.
    )
    echo.
    echo Validation completed. No service was started.
    exit /b 0
)

if "%BUILD_REQUIRED%"=="1" (
    echo [BUILD] Backend JARs are missing. Building all backend modules...
    call "%MAVEN_CMD%" clean package -DskipTests
    if errorlevel 1 (
        echo [ERROR] Backend build failed. Review the Maven output above.
        goto failed
    )
    echo [OK] Backend build completed.
    echo.
)

echo [1/7] Starting MySQL...
docker compose up -d mysql
if errorlevel 1 (
    echo [ERROR] Could not start the MySQL container.
    goto failed
)

set "MYSQL_CONTAINER="
for /f %%I in ('docker compose ps -q mysql') do set "MYSQL_CONTAINER=%%I"
if not defined MYSQL_CONTAINER (
    echo [ERROR] Docker Compose did not return a MySQL container ID.
    goto failed
)

echo [WAIT] Waiting for MySQL to become healthy...
set "MYSQL_HEALTH="
for /L %%N in (1,1,60) do (
    for /f %%H in ('docker inspect -f "{{.State.Health.Status}}" "!MYSQL_CONTAINER!" 2^>nul') do set "MYSQL_HEALTH=%%H"
    if /I "!MYSQL_HEALTH!"=="healthy" goto mysql_ready
    timeout /t 2 /nobreak >nul
)

echo [ERROR] MySQL did not become healthy within 120 seconds.
docker compose ps mysql
goto failed

:mysql_ready
echo [OK] MySQL is healthy.
start "01 - MySQL logs (3307)" /D "%PROJECT_DIR%" cmd /k "docker compose logs -f mysql"

echo [2/7] Opening Auth Service on port 8081...
start "02 - Auth Service (8081)" /D "%PROJECT_DIR%" cmd /k "java -jar ""auth-service\target\auth-service-1.0.0.jar"" --spring.profiles.active=mysql"

echo [3/7] Opening Car Service on port 8082...
start "03 - Car Service (8082)" /D "%PROJECT_DIR%" cmd /k "java -jar ""car-service\target\car-service-1.0.0.jar"" --spring.profiles.active=mysql"

echo [4/7] Opening Booking Service on port 8083...
start "04 - Booking Service (8083)" /D "%PROJECT_DIR%" cmd /k "java -jar ""booking-service\target\booking-service-1.0.0.jar"" --spring.profiles.active=mysql"

echo [5/7] Opening API Gateway on port 8080...
start "05 - API Gateway (8080)" /D "%PROJECT_DIR%" cmd /k "java -jar ""api-gateway\target\api-gateway-1.0.0.jar"""

echo [6/7] Opening Next.js frontend on port 3000...
start "06 - Frontend (3000)" /D "%FRONTEND_DIR%" cmd /k "if not exist node_modules call npm install ^&^& npm run dev"

echo [7/7] Checking optional ngrok tunnel...
if exist "C:\ngrok.exe" (
    tasklist /FI "IMAGENAME eq ngrok.exe" 2>nul | find /I "ngrok.exe" >nul
    if errorlevel 1 (
        start "07 - Ngrok to Gateway (8080)" /D "%PROJECT_DIR%" cmd /k "C:\ngrok.exe http 8080"
        echo [OK] Ngrok terminal opened for Gateway port 8080.
    ) else (
        echo [INFO] Ngrok is already running, so a duplicate tunnel was not opened.
    )
) else (
    echo [INFO] C:\ngrok.exe was not found. Skipping the optional ngrok terminal.
)

echo.
echo ============================================================
echo All available terminals have been opened.
echo Website:       http://localhost:3000
echo Gateway health: http://localhost:8080/actuator/health
echo.
echo Close a service with Ctrl+C in its terminal.
echo MySQL data is persistent; do NOT use: docker compose down -v
echo ============================================================
timeout /t 8 /nobreak >nul
exit /b 0

:require_command
where %~1 >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Missing %~2. Command "%~1" is not available in PATH.
    exit /b 1
)
exit /b 0

:find_maven
set "MAVEN_CMD="
for /f "delims=" %%M in ('where mvn 2^>nul') do if not defined MAVEN_CMD set "MAVEN_CMD=%%M"
if not defined MAVEN_CMD if exist "C:\Program Files\JetBrains\IntelliJ IDEA 2026.1.1\plugins\maven\lib\maven3\bin\mvn.cmd" set "MAVEN_CMD=C:\Program Files\JetBrains\IntelliJ IDEA 2026.1.1\plugins\maven\lib\maven3\bin\mvn.cmd"
if not defined MAVEN_CMD (
    echo [ERROR] Backend JARs are missing and Maven could not be found.
    echo         Install Maven or build the project in IntelliJ, then run this file again.
    exit /b 1
)
exit /b 0

:failed
echo.
echo Startup was stopped because of the error above.
pause
exit /b 1
