# Download and run script in a temporary directory
$TempDir = [System.IO.Path]::Combine($env:TEMP, "NFTTools-$(Get-Random)")
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

# Program Information
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Welcome to the NFTTools Bidding Bot Setup" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "This script will set up and launch the NFTTools Bidding Bot using Docker Compose." -ForegroundColor White
Write-Host "Ensure you have Docker installed before running this script." -ForegroundColor Yellow

# Set working directory to temp location
$ScriptDirectory = $TempDir
$ComposeFileUrl = "https://raw.githubusercontent.com/NFTToolz/Bidding-Bot-Install/main/compose.prod.yaml"
$LocalComposeFile = Join-Path $ScriptDirectory "compose.prod.yaml"
$EnvFile = Join-Path $ScriptDirectory ".env"

# Relaunch script as admin if not running with elevated privileges
function Run-AsAdmin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "This script needs to run with administrative privileges." -ForegroundColor Yellow
        Write-Host "Restarting the script as administrator..." -ForegroundColor Cyan
        Start-Process powershell "-NoProfile -ExecutionPolicy Bypass -Command `"iex ((New-Object System.Net.WebClient).DownloadString('YOUR_RAW_GITHUB_URL'))`"" -Verb RunAs
        Exit
    }
}
Run-AsAdmin

# Check if Docker is installed
if (-Not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker is not installed on your system." -ForegroundColor Red
    Write-Host "Please install Docker Desktop for Windows/macOS or Docker Engine for Linux." -ForegroundColor Yellow
    Write-Host "Visit the Docker installation page: https://www.docker.com/products/docker-desktop" -ForegroundColor Cyan
    Exit
} else {
    Write-Host "Docker is installed. Proceeding..." -ForegroundColor Green
}

# Check if Docker Compose is installed
if (-Not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
    Write-Host "Docker Compose is not installed." -ForegroundColor Red
    Write-Host "Docker Compose comes bundled with Docker Desktop on Windows/macOS." -ForegroundColor Yellow
    Write-Host "If you're on Linux, you can install Docker Compose manually." -ForegroundColor Yellow
    Write-Host "Visit the Docker Compose installation guide: https://docs.docker.com/compose/install/" -ForegroundColor Cyan
    Exit
} else {
    Write-Host "Docker Compose is installed. Proceeding..." -ForegroundColor Green
}

# Handle existing compose file
if (Test-Path $LocalComposeFile) {
    Write-Host "Removing existing compose file to avoid conflict..." -ForegroundColor Yellow
    Remove-Item -Path $LocalComposeFile -Force
}

# Check if the compose file exists locally
if (-Not (Test-Path $LocalComposeFile)) {
    Write-Host "Compose file not found locally. Attempting to download..."
    try {
        $response = Invoke-WebRequest -Uri $ComposeFileUrl -UseBasicParsing -ErrorAction Stop
        $response.Content | Out-File -FilePath $LocalComposeFile -Encoding UTF8
        Write-Host "Compose file downloaded successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Error details:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host "`nTrying to access URL: $ComposeFileUrl" -ForegroundColor Yellow
        Write-Host "Please verify the URL is correct and accessible." -ForegroundColor Yellow
        Exit 1
    }

    # Wait until the file is completely written
    $RetryCount = 0
    $MaxRetries = 10
    while (-Not (Test-Path $LocalComposeFile) -or (Get-Item $LocalComposeFile).Length -eq 0) {
        Start-Sleep -Milliseconds 500
        $RetryCount++
        if ($RetryCount -ge $MaxRetries) {
            Write-Host "Compose file is still not ready after multiple attempts." -ForegroundColor Red
            Exit 1
        }
    }
}

# Notify and collect environment variables
if (-Not (Test-Path $EnvFile)) {
    Write-Host "`nSetting up environment configuration..." -ForegroundColor Cyan
    Write-Host "Please provide the following information:" -ForegroundColor Yellow

    # Email Configuration
    Write-Host "`nEmail Configuration:" -ForegroundColor Cyan
    $emailUsername = Read-Host "Enter your email username"
    $emailPassword = Read-Host "Enter your email password" -AsSecureString
    $emailPasswordText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($emailPassword))

    # URL Configuration
    Write-Host "`nURL Configuration:" -ForegroundColor Cyan
    $clientUrl = Read-Host "Enter your client URL (e.g., http://localhost:3000)"
    $serverWebsocket = Read-Host "Enter your server websocket URL (e.g., ws://localhost:8080)"

    # Create .env file with user input
@"
EMAIL_USERNAME=$emailUsername
EMAIL_PASSWORD=$emailPasswordText
CLIENT_URL=$clientUrl
NEXT_PUBLIC_CLIENT_URL=$clientUrl
NEXT_PUBLIC_SERVER_WEBSOCKET=$serverWebsocket
"@ | Out-File $EnvFile -Encoding utf8

    Write-Host "`nEnvironment configuration saved to $EnvFile" -ForegroundColor Green
    Write-Host "You can edit these values manually in the .env file if needed." -ForegroundColor Cyan
    
    # Prompt for confirmation
    Write-Host "`nWould you like to review the configuration before continuing?" -ForegroundColor Yellow
    $review = Read-Host "Enter 'yes' to review or press Enter to continue"
    if ($review.ToLower() -eq 'yes') {
        Get-Content $EnvFile
        Write-Host "`nPress Enter to continue..." -ForegroundColor Cyan
        Read-Host
    }
} else {
    Write-Host "`nExisting .env file found. Using current configuration." -ForegroundColor Yellow
    Write-Host "To reconfigure, delete the .env file and run the script again." -ForegroundColor Cyan
}


# Prompt for continue
Write-Host "`nReady to start the services?" -ForegroundColor Yellow
$continue = Read-Host "Enter 'yes' to continue or 'no' to exit"
if ($continue.ToLower() -ne 'yes') {
    Write-Host "Setup cancelled by user." -ForegroundColor Red
    Exit
}

# Start Docker Compose
Write-Host "Building and starting the NFTTools Bidding Bot with Docker Compose..." -ForegroundColor Green
docker compose -f $LocalComposeFile build
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker Compose build failed. Please check your configuration." -ForegroundColor Red
    Exit $LASTEXITCODE
}

docker compose -f $LocalComposeFile up --watch
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker Compose up failed. Please check your logs for errors." -ForegroundColor Red
    Exit $LASTEXITCODE
}

# Notify user about the bot's interface
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "NFTTools Bidding Bot is now running!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Visit the bot`'s web interface at your CLIENT_URL if configured." -ForegroundColor White

# Cleanup temp directory on exit
trap {
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force
    }
    break
}
