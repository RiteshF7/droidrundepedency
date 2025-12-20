# Script to start Resizable_Experimental AVD on Windows PowerShell

$AVD_NAME = "Resizable_Experimental"

Write-Host "Starting Android Virtual Device: $AVD_NAME"
Write-Host "=========================================="

# Check if emulator command is available
if (-not (Get-Command emulator -ErrorAction SilentlyContinue)) {
    Write-Host "Error: emulator command not found" -ForegroundColor Red
    Write-Host "Please ensure Android SDK emulator is in your PATH"
    Write-Host "You can add it using: .\add_android_to_path.ps1"
    exit 1
}

# Check if AVD exists
$availableAVDs = emulator -list-avds
if ($availableAVDs -notcontains $AVD_NAME) {
    Write-Host "Error: AVD '$AVD_NAME' not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Available AVDs:"
    $availableAVDs
    exit 1
}

# Start the emulator in background
Write-Host "Launching $AVD_NAME..."
Start-Process -NoNewWindow emulator -ArgumentList "-avd", $AVD_NAME

Write-Host ""
Write-Host "AVD is starting in the background..."
Write-Host "The emulator window should appear shortly."
Write-Host ""
Write-Host "To check if it's ready, run: adb devices"
Write-Host "To stop the emulator, close the emulator window or run: adb emu kill"

