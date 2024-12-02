# Allow running downloaded scripts
Set-ExecutionPolicy Bypass -Scope Process -Force

# Create and navigate to installation directory
$InstallDir = "$env:USERPROFILE\NFTTools"
New-Item -ItemType Directory -Force -Path $InstallDir
Set-Location -Path $InstallDir

# Download the main script
$MainScriptUrl = "https://raw.githubusercontent.com/NFTToolz/Bidding-Bot-Install/main/windows.ps1"
Invoke-WebRequest -Uri $MainScriptUrl -OutFile "setup.ps1"

# Execute the script
.\setup.ps1
