@echo off
REM Script to start Resizable_Experimental AVD on Windows

set AVD_NAME=Resizable_Experimental

echo Starting Android Virtual Device: %AVD_NAME%
echo ==========================================

REM Check if emulator command is available
where emulator >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: emulator command not found
    echo Please ensure Android SDK emulator is in your PATH
    echo You can add it using: add_android_to_path.ps1
    exit /b 1
)

REM Start the emulator
echo Launching %AVD_NAME%...
start /b emulator -avd %AVD_NAME%

echo.
echo AVD is starting in the background...
echo The emulator window should appear shortly.
echo.
echo To check if it's ready, run: adb devices
echo To stop the emulator, close the emulator window or run: adb emu kill


