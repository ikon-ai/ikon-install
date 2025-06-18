# Set-ExecutionPolicy Bypass -Scope Process -Force; iwr "https://ikon.live/install.ps1" -useb | iex

$ErrorActionPreference = "Stop"
$dotnetSdkUrl = "https://builds.dotnet.microsoft.com/dotnet/Sdk/8.0.411/dotnet-sdk-8.0.411-win-x64.exe"

Write-Host "Checking pre-requisites for ikon tool installation..."

# Check if dotnet is installed
try {
    $dotnetVersion = dotnet --version 2>$null
    if (-not $dotnetVersion) {
        throw "dotnet command not found"
    }
} catch {
    Write-Host "Error: .NET SDK is not installed" -ForegroundColor Red
    Write-Host "Please install the .NET SDK 8: $dotnetSdkUrl"
    exit 1
}

# Check dotnet version
$majorVersion = [int]($dotnetVersion.Split('.')[0])

if ($majorVersion -lt 8) {
    Write-Host "Error: .NET SDK version 8 or higher is required" -ForegroundColor Red
    Write-Host "Current version: $dotnetVersion"
    Write-Host "Please install the .NET SDK 8: $dotnetSdkUrl"
    exit 1
}

Write-Host ".NET SDK $dotnetVersion found" -ForegroundColor DarkGreen

# Silently uninstall old IkonTool package if it exists
try {
    dotnet tool uninstall IkonTool -g 2>&1 | Out-Null
} catch {
}

# Install ikon tool globally
Write-Host "Installing ikon tool..."

try {
    dotnet tool install ikon -g
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet tool install failed with exit code $LASTEXITCODE"
    }
} catch {
    Write-Host "Error: Failed to install ikon tool" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

try {
    $ikonPath = Get-Command ikon -ErrorAction Stop
} catch {
    Write-Host "Error: ikon command not found in PATH" -ForegroundColor Red
    Write-Host "Please restart your terminal and try again"
    exit 1
}

# Test ikon version command
Write-Host "Testing ikon tool installation..."

try {
    ikon version
    if ($LASTEXITCODE -ne 0) {
        throw "ikon version command failed with exit code $LASTEXITCODE"
    }
} catch {
    Write-Host "Error: ikon tool has not been installed correctly" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

Write-Host "Next step, to login to the ikon backend, run:"
Write-Host "ikon login" -ForegroundColor Yellow
