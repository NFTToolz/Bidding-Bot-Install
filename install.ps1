# Safe Installation Script for NFTTools
$ErrorActionPreference = 'Stop'

# Create installation directory
$InstallDir = "$env:USERPROFILE\NFTTools"
Write-Host "Creating installation directory at $InstallDir..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Set-Location -Path $InstallDir

# Check for Administrator privileges
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $IsAdmin) {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$InstallDir'; & '$PSCommandPath'`""
    exit
}

# Program Information
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Welcome to the NFTTools Bidding Bot Setup" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Verify Docker installation
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker is not installed. Please install Docker Desktop first." -ForegroundColor Red
    Write-Host "Download from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    Pause
    exit 1
}

# Download compose file
$ComposeFileUrl = "https://raw.githubusercontent.com/NFTToolz/Bidding-Bot-Install/main/compose.prod.yaml"
Write-Host "Downloading configuration files..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $ComposeFileUrl -OutFile "compose.prod.yaml" -UseBasicParsing

# Create .env file if it doesn't exist
if (-not (Test-Path ".env")) {
    Write-Host "`nSetting up environment configuration..." -ForegroundColor Cyan
    
    # Get user input
    $emailUsername = Read-Host "Enter your email username"
    $emailPassword = Read-Host "Enter your email password" -AsSecureString
    $emailPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($emailPassword)
    )
    $clientUrl = Read-Host "Enter your client URL (e.g., http://localhost:3000)"
    $serverWebsocket = Read-Host "Enter your server websocket URL (e.g., ws://localhost:8080)"

    # Create .env file
    @"
EMAIL_USERNAME=$emailUsername
EMAIL_PASSWORD=$emailPasswordText
CLIENT_URL=$clientUrl
NEXT_PUBLIC_CLIENT_URL=$clientUrl
NEXT_PUBLIC_SERVER_WEBSOCKET=$serverWebsocket
"@ | Out-File ".env" -Encoding utf8
}

# Start services
Write-Host "`nStarting services..." -ForegroundColor Green
docker compose -f compose.prod.yaml up --build -d

Write-Host "`nInstallation complete!" -ForegroundColor Green
Write-Host "Your NFTTools installation is located at: $InstallDir" -ForegroundColor Cyan
Write-Host "Visit your configured CLIENT_URL to access the interface." -ForegroundColor White

# Ask user if they want to open the webpage
$openBrowser = Read-Host "`nWould you like to open the interface in your default browser? (yes/no)"
if ($openBrowser.ToLower() -eq 'yes' -or $openBrowser.ToLower() -eq 'y') {
    # Get the client URL from .env file if it exists
    if (Test-Path ".env") {
        $envContent = Get-Content ".env" -Raw
        if ($envContent -match 'CLIENT_URL=(.+)') {
            $clientUrl = $matches[1].Trim()
        }
    }
    
    # Open the URL in default browser
    Write-Host "Opening $clientUrl in your default browser..." -ForegroundColor Cyan
    Start-Process $clientUrl
}

Pause
