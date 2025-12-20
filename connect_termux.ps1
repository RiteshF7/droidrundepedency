# PowerShell script to connect to Termux via SSH
# Usage: .\connect_termux.ps1 [username] [host] [port]

param(
    [string]$Username = "username",
    [string]$Host = "127.0.0.1",
    [int]$Port = 8022
)

$Password = "trex"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Termux SSH Connection Helper" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Username: $Username"
Write-Host "Host: $Host"
Write-Host "Port: $Port"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if plink is available (PuTTY)
if (Get-Command plink -ErrorAction SilentlyContinue) {
    Write-Host "Using plink (PuTTY) for SSH connection..." -ForegroundColor Yellow
    $env:TERMUX_PASSWORD = $Password
    plink -ssh -P $Port $Username@$Host -pw $Password
} else {
    Write-Host "Note: plink not found. Using native SSH..." -ForegroundColor Yellow
    Write-Host "You may need to enter password manually: $Password" -ForegroundColor Yellow
    Write-Host ""
    
    # Try using ssh with password via here-string (may not work on all systems)
    Write-Host "Connecting to ${Username}@${Host}:${Port}..." -ForegroundColor Green
    ssh -p $Port "${Username}@${Host}"
}

