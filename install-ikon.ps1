# Set-ExecutionPolicy Bypass -Scope Process -Force; iwr "https://ikon.live/install.ps1" -useb | iex

$ErrorActionPreference = "Stop"

$DOTNET_SDK_VERSION = "8.0.414"
$DOTNET_SDK_MAJOR = 8

$dotnetSdkUrl = "https://builds.dotnet.microsoft.com/dotnet/Sdk/$DOTNET_SDK_VERSION/dotnet-sdk-$DOTNET_SDK_VERSION-win-x64.exe"
$gitInstallerUrl = "https://github.com/git-for-windows/git/releases/download/v2.51.0.windows.2/Git-2.51.0.2-64-bit.exe"

function Refresh-EnvironmentPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path","User")
    $env:Path = if ($machinePath -and $userPath) { 
        "$machinePath;$userPath" 
    } elseif ($machinePath) { 
        $machinePath 
    } elseif ($userPath) { 
        $userPath 
    } else { 
        $env:Path 
    }
}

Write-Host "Checking pre-requisites for Ikon tool installation..."

# Check if dotnet is installed and if version is sufficient
$needsDotnetInstall = $false
$dotnetVersion = $null

try {
    $dotnetVersion = dotnet --version 2>$null
    if (-not $dotnetVersion) {
        throw "dotnet command not found"
    }
    
    $majorVersion = [int]($dotnetVersion.Split('.')[0])
    if ($majorVersion -lt $DOTNET_SDK_MAJOR) {
        Write-Host ".NET SDK version $dotnetVersion found, but version $DOTNET_SDK_MAJOR or higher is required" -ForegroundColor Yellow
        $needsDotnetInstall = $true
    } else {
        Write-Host ".NET SDK $dotnetVersion found" -ForegroundColor DarkGreen
    }
} catch {
    Write-Host ".NET SDK is not installed." -ForegroundColor Yellow
    $needsDotnetInstall = $true
}

if ($needsDotnetInstall) {
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
        Write-Host "Installing .NET SDK $DOTNET_SDK_MAJOR using winget..." -ForegroundColor Yellow
        try {
            winget install Microsoft.DotNet.SDK.$DOTNET_SDK_MAJOR --silent --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Host ".NET SDK $DOTNET_SDK_MAJOR has been installed successfully!" -ForegroundColor Green
                Refresh-EnvironmentPath
                
                try {
                    $dotnetVersion = dotnet --version 2>$null
                    if (-not $dotnetVersion) {
                        throw "dotnet command still not available"
                    }
                    Write-Host ".NET SDK $dotnetVersion found" -ForegroundColor DarkGreen
                } catch {
                    Write-Host "Please restart your terminal and run this script again to complete the Ikon tool installation." -ForegroundColor Yellow
                    Read-Host "Press Enter to exit"
                    return 0
                }
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
        Write-Host "Downloading .NET SDK $DOTNET_SDK_MAJOR installer..." -ForegroundColor Yellow
        $tempDir = [System.IO.Path]::GetTempPath()
        $installerPath = Join-Path $tempDir "dotnet-sdk-8-installer.exe"
        
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $dotnetSdkUrl -OutFile $installerPath -UseBasicParsing
            $ProgressPreference = 'Continue'
            Write-Host "Download complete. Running installer..." -ForegroundColor Yellow
            Start-Process -FilePath $installerPath -Wait -ArgumentList "/quiet", "/norestart"
            Write-Host ".NET SDK $DOTNET_SDK_MAJOR installer has completed!" -ForegroundColor Green
            Refresh-EnvironmentPath
            
            try {
                $dotnetVersion = dotnet --version 2>$null
                if (-not $dotnetVersion) {
                    throw "dotnet command still not available"
                }
                Write-Host ".NET SDK $dotnetVersion found" -ForegroundColor DarkGreen
            } catch {
                Write-Host "Please restart your terminal and run this script again to complete the Ikon tool installation." -ForegroundColor Yellow
                Read-Host "Press Enter to exit"
                return 0
            }
        } catch {
            Write-Host "Error: Failed to download or run the .NET SDK installer" -ForegroundColor Red
            Write-Host $_.Exception.Message
            Write-Host "Please manually download and install .NET SDK 8 from: $dotnetSdkUrl" -ForegroundColor Yellow
            return 1
        } finally {
            if (Test-Path $installerPath) {
                Remove-Item $installerPath -ErrorAction SilentlyContinue
            }
        }
    }
}

# Check if git is installed
try {
    $gitVersion = git --version 2>$null
    if (-not $gitVersion) {
        throw "git command not found"
    }
    Write-Host "Git $gitVersion found" -ForegroundColor DarkGreen
} catch {
    Write-Host "Git is not installed. Installing..." -ForegroundColor Yellow
    
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
        Write-Host "Installing Git using winget..." -ForegroundColor Yellow
        try {
            winget install --id Git.Git -e --source winget --silent --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Git has been installed successfully!" -ForegroundColor Green
                Refresh-EnvironmentPath
                
                try {
                    $null = git --version 2>$null
                    if (-not $?) {
                        throw "git command still not available"
                    }
                } catch {
                    Write-Host "Please restart your terminal and run this script again to complete the installation." -ForegroundColor Yellow
                    Read-Host "Press Enter to exit"
                    return 0
                }
            } else {
                throw "winget install failed with exit code $LASTEXITCODE"
            }
        } catch {
            Write-Host "Warning: Failed to install Git using winget" -ForegroundColor Yellow
            Write-Host "Falling back to manual download..." -ForegroundColor Yellow
            $wingetAvailable = $false
        }
    }
    
    # If winget is not available or failed, download and run the installer
    if (-not $wingetAvailable -or $LASTEXITCODE -ne 0) {
        Write-Host "Downloading Git installer..." -ForegroundColor Yellow
        $tempDir = [System.IO.Path]::GetTempPath()
        $installerPath = Join-Path $tempDir "git-installer.exe"
        
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $gitInstallerUrl -OutFile $installerPath -UseBasicParsing
            $ProgressPreference = 'Continue'
            Write-Host "Download complete. Running installer..." -ForegroundColor Yellow
            Start-Process -FilePath $installerPath -Wait -ArgumentList "/VERYSILENT", "/NORESTART"
            Write-Host "Git installer has completed!" -ForegroundColor Green
            Refresh-EnvironmentPath
            
            try {
                $null = git --version 2>$null
                if (-not $?) {
                    throw "git command still not available"
                }
            } catch {
                Write-Host "Please restart your terminal and run this script again to complete the installation." -ForegroundColor Yellow
                Read-Host "Press Enter to exit"
                return 0
            }
        } catch {
            Write-Host "Error: Failed to download or run the Git installer" -ForegroundColor Red
            Write-Host $_.Exception.Message
            Write-Host "Please manually download and install Git from: $gitInstallerUrl" -ForegroundColor Yellow
            return 1
        } finally {
            if (Test-Path $installerPath) {
                Remove-Item $installerPath -ErrorAction SilentlyContinue
            }
        }
    }
}

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
    return 1
}

try {
    $ikonPath = Get-Command ikon -ErrorAction Stop
} catch {
    Write-Host "Error: ikon command not found in PATH" -ForegroundColor Red
    Write-Host "Please restart your terminal and try again"
    return 1
}

Write-Host "Testing Ikon tool installation..."

try {
    ikon version
    if ($LASTEXITCODE -ne 0) {
        throw "ikon version command failed with exit code $LASTEXITCODE"
    }
} catch {
    Write-Host "Error: Ikon tool has not been installed correctly" -ForegroundColor Red
    Write-Host $_.Exception.Message
    return 1
}

Write-Host "Trusting HTTPS development certificates for localhost..."

try {
    if ($env:CI -eq "true") {
        dotnet dev-certs https
    } else {
        dotnet dev-certs https --trust
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Warning: Failed to trust HTTPS development certificates" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Warning: Failed to trust HTTPS development certificates" -ForegroundColor Yellow
    Write-Host $_.Exception.Message
}

Write-Host ""
Write-Host "Next step, to login to the Ikon backend, run:"
Write-Host "ikon login" -ForegroundColor Yellow
