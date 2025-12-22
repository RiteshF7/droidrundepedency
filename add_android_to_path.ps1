# Add Android SDK paths to User PATH permanently
$emulatorPath = "$env:LOCALAPPDATA\Android\Sdk\emulator"
$platformToolsPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools"

# Get current User PATH
$currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$pathsToAdd = @()

# Check if emulator path exists and is not in PATH
if (Test-Path $emulatorPath) {
    if ($currentPath -notlike "*$emulatorPath*") {
        $pathsToAdd += $emulatorPath
        Write-Host "Will add: $emulatorPath"
    } else {
        Write-Host "Already in PATH: $emulatorPath"
    }
} else {
    Write-Host "Warning: Emulator path not found: $emulatorPath"
}

# Check if platform-tools path exists and is not in PATH
if (Test-Path $platformToolsPath) {
    if ($currentPath -notlike "*$platformToolsPath*") {
        $pathsToAdd += $platformToolsPath
        Write-Host "Will add: $platformToolsPath"
    } else {
        Write-Host "Already in PATH: $platformToolsPath"
    }
} else {
    Write-Host "Warning: Platform-tools path not found: $platformToolsPath"
}

# Add paths if any
if ($pathsToAdd.Count -gt 0) {
    $newPath = $currentPath
    foreach ($path in $pathsToAdd) {
        $newPath += ";$path"
    }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Host ""
    Write-Host "Successfully added Android SDK paths to User PATH!"
    Write-Host "Please restart your terminal/CMD/PowerShell for changes to take effect."
    Write-Host ""
    Write-Host "After restarting, you can use:"
    Write-Host "  emulator -list-avds"
    Write-Host "  emulator -avd <avd_name>"
    Write-Host "  adb devices"
} else {
    Write-Host ""
    Write-Host "All Android SDK paths are already in your PATH."
}



