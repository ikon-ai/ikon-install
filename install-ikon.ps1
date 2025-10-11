# Set-ExecutionPolicy Bypass -Scope Process -Force; iwr "https://ikon.live/install.ps1" -useb | iex

$ErrorActionPreference = "Stop"
$dotnetSdkUrl = "https://builds.dotnet.microsoft.com/dotnet/Sdk/8.0.414/dotnet-sdk-8.0.414-win-x64.exe"

Write-Host "Checking pre-requisites for ikon tool installation..."

# Check if dotnet is installed
try {
    $dotnetVersion = dotnet --version 2>$null
    if (-not $dotnetVersion) {
        throw "dotnet command not found"
    }
} catch {
    Write-Host ".NET SDK is not installed. Installing..." -ForegroundColor Yellow
    
    # Check if winget is available
    $wingetAvailable = $false
    try {
        $wingetCheck = winget --version 2>$null
        if ($wingetCheck) {
            $wingetAvailable = $true
        }
    } catch {
        $wingetAvailable = $false
    }
    
    if ($wingetAvailable) {
        Write-Host "Installing .NET SDK 8 using winget..." -ForegroundColor Yellow
        try {
            winget install Microsoft.DotNet.SDK.8 --silent --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Host ".NET SDK 8 has been installed successfully!" -ForegroundColor Green
                Write-Host "Please restart your terminal and run this script again to complete the Ikon tool installation." -ForegroundColor Yellow
                exit 0
            } else {
                throw "winget install failed with exit code $LASTEXITCODE"
            }
        } catch {
            Write-Host "Warning: Failed to install .NET SDK using winget" -ForegroundColor Yellow
            Write-Host "Falling back to manual download..." -ForegroundColor Yellow
        }
    }
    
    # If winget is not available or failed, download and run the installer
    if (-not $wingetAvailable -or $LASTEXITCODE -ne 0) {
        Write-Host "Downloading .NET SDK 8 installer..." -ForegroundColor Yellow
        $tempDir = [System.IO.Path]::GetTempPath()
        $installerPath = Join-Path $tempDir "dotnet-sdk-8-installer.exe"
        
        try {
            Invoke-WebRequest -Uri $dotnetSdkUrl -OutFile $installerPath -UseBasicParsing
            Write-Host "Download complete. Running installer..." -ForegroundColor Yellow
            Write-Host "Please follow the installation prompts." -ForegroundColor Yellow
            
            Start-Process -FilePath $installerPath -Wait -ArgumentList "/quiet", "/norestart"
            
            Write-Host ".NET SDK 8 installer has completed!" -ForegroundColor Green
            Write-Host "Please restart your terminal and run this script again to complete the Ikon tool installation." -ForegroundColor Yellow
            
            exit 0
        } catch {
            Write-Host "Error: Failed to download or run the .NET SDK installer" -ForegroundColor Red
            Write-Host $_.Exception.Message
            Write-Host "Please manually download and install .NET SDK 8 from: $dotnetSdkUrl" -ForegroundColor Yellow
            exit 1
        } finally {
            if (Test-Path $installerPath) {
                Remove-Item $installerPath -ErrorAction SilentlyContinue
            }
        }
    }
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

# Install Ikon tool globally
Write-Host "Installing Ikon tool..."

try {
    dotnet tool install ikon -g
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet tool install failed with exit code $LASTEXITCODE"
    }
} catch {
    Write-Host "Error: Failed to install Ikon tool" -ForegroundColor Red
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
Write-Host "Testing Ikon tool installation..."

try {
    ikon version
    if ($LASTEXITCODE -ne 0) {
        throw "ikon version command failed with exit code $LASTEXITCODE"
    }
} catch {
    Write-Host "Error: Ikon tool has not been installed correctly" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

Write-Host "Next step, to login to the Ikon backend, run:"
Write-Host "ikon login" -ForegroundColor Yellow
