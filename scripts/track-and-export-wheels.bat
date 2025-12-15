@echo off
REM Windows batch wrapper for track-and-export-wheels.sh
REM Usage: track-and-export-wheels.bat [--install] [package1] [package2] ...

setlocal

REM Get the script directory
set SCRIPT_DIR=%~dp0
set SCRIPT_PATH=%SCRIPT_DIR%track-and-export-wheels.sh

REM Check if Git Bash is available
where bash >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: bash not found. Please install Git Bash or use WSL.
    exit /b 1
)

REM Check if ADB is available
where adb >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: adb not found. Please add Android SDK platform-tools to PATH.
    exit /b 1
)

REM Run the script with all arguments
bash "%SCRIPT_PATH%" %*

endlocal



