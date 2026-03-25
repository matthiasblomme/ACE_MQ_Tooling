@echo off
setlocal EnableDelayedExpansion

:: ============================================================
:: mqsirestart
:: Stops then starts an IBM ACE integration node or server.
:: Uses the same connectionSpec and flags as mqsistop / mqsistart.
:: Note: --immediate / -i is a stop-only flag and is stripped
::       from the arguments passed to mqsistart automatically.
:: ============================================================

if "%~1"=="" (
    echo BIP8117I: Restarts components.
    echo Syntax:
    echo   mqsirestart ^(connectionSpec^) [--integration-server ^<server^> ^| --all-integration-servers]
    echo               [--timeout-seconds ^<seconds^>] [--detail-level ^<level^>] [--trace ^<traceFileName^>]
    echo               [--https ^[--cacert ^<cacertFile^> ^[--cacert-password ^<cacertPassword^>^] ^| --insecure^]^]
    echo               [--no-https]
    echo.
    echo BIP8006E: Flag missing.  One of the flags in list ^(connectionSpec^) must be specified.
    echo When using this command interface the user should select all required flags.
    echo Correct and reissue the command.
    exit /b 1
)

:: --- Extract node name (first positional arg) ---
set "NODE_NAME=%~1"
set "SERVER_NAME="

:: --- Find --integration-server / -e value for display ---
set "PARSE_NEXT=0"
for %%A in (%*) do (
    if "!PARSE_NEXT!"=="1" (
        set "SERVER_NAME=%%~A"
        set "PARSE_NEXT=0"
    )
    if /I "%%~A"=="--integration-server" set "PARSE_NEXT=1"
    if /I "%%~A"=="-e"                   set "PARSE_NEXT=1"
)

:: --- Build start args: same as stop args minus --immediate / -i ---
set "START_ARGS="
for %%A in (%*) do (
    if /I "%%~A"=="--immediate" (
        rem stop-only flag, skip it
    ) else if /I "%%~A"=="-i" (
        rem stop-only flag, skip it
    ) else (
        set "START_ARGS=!START_ARGS! %%~A"
    )
)

:: =========================
:: STOP PHASE
:: =========================
if defined SERVER_NAME (
    echo Stopping integration server %SERVER_NAME% on node %NODE_NAME%
) else (
    echo Stopping integration node %NODE_NAME%
)
echo.

mqsistop %* 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo mqsirestart: Stop phase failed with error %ERRORLEVEL%. Aborting restart.
    exit /b %ERRORLEVEL%
)

echo.

:: =========================
:: START PHASE
:: =========================
if defined SERVER_NAME (
    echo Starting integration server %SERVER_NAME% on node %NODE_NAME%
) else (
    echo Starting integration node %NODE_NAME%
)
echo.

mqsistart %START_ARGS% 2>&1
exit /b %ERRORLEVEL%
