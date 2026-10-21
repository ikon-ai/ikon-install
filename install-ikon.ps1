# IKON tool installer for Windows
#
#   irm https://ikonai.com/install.ps1 | iex
#   & ([scriptblock]::Create((irm https://ikonai.com/install.ps1))) --machine
#   powershell -ExecutionPolicy Bypass -File install-ikon.ps1 [options]
#
# Checks the .NET SDK, Node.js, Git and the IKON tool, installs whatever is missing or too old,
# signs you in and reinstalls the IKON tool packages. Running it again is how to repair an install.
#
# Options:
#   --machine      Install for every user with winget, which needs an administrator.
#                  Without it everything goes into your own folders and no administrator is needed.
#   --format json  One JSON event per line on stdout, everything else on stderr. Never prompts
#                  and never signs in.
#   --check        Only report what is installed.
#   --yes, -y      Do not ask before installing.
#   --no-login     Do not sign in.

# --- Versions ---------------------------------------------------------------------------------------

$DOTNET_SDK_MAJOR = 10
$NODE_MAJOR = 24
$NODE_VERSION = "24.21.0"

# --- Locations of a per-user install ---------------------------------------------------------------

$DotnetUserRoot = Join-Path $env:LOCALAPPDATA "Microsoft\dotnet"
$NodeUserRoot = Join-Path $env:LOCALAPPDATA "Ikon\node"
$GitUserRoot = Join-Path $env:LOCALAPPDATA "Programs\Git"
$DotnetToolsDir = Join-Path $env:USERPROFILE ".dotnet\tools"

$AgentNames = [ordered]@{ claude = "Claude Code"; codex = "Codex"; agy = "Antigravity" }

function Install-Ikon {
    $ErrorActionPreference = "Stop"
    $ProgressPreference = "SilentlyContinue"

    # --- Options ------------------------------------------------------------------------------------

    $script:Json = $false
    $script:StartPath = $env:Path
    $script:AddedPaths = @()
    $script:Failure = $null
    $script:Log = Join-Path ([IO.Path]::GetTempPath()) ("ikon-install-" + [guid]::NewGuid().ToString("N") + ".log")
    $machine = $false
    $script:CheckOnly = $false
    $yes = $env:CI -eq "true"
    $login = $true

    for ($i = 0; $i -lt $args.Count; $i++) {
        switch ($args[$i]) {
            "--machine" { $machine = $true }
            "--format" { $i++; if ($args[$i] -ne "json") { return (Stop-Usage "--format takes json") }; $script:Json = $true }
            "--format=json" { $script:Json = $true }
            "--check" { $script:CheckOnly = $true }
            { $_ -in "--yes", "-y" } { $yes = $true }
            "--no-login" { $login = $false }
            default { return (Stop-Usage "Unknown option '$($args[$i])'") }
        }
    }

    $interactive = -not $script:Json -and $env:CI -ne "true" -and -not [Console]::IsInputRedirected

    # A global.json in the current folder could pin an SDK this machine does not have
    Push-Location $env:USERPROFILE
    $env:DOTNET_NOLOGO = "1"
    # .NET's first run would otherwise make the development certificate itself, in the middle of the
    # tool install; the certificate step at the end is where that belongs
    $env:DOTNET_GENERATE_ASPNET_CERTIFICATE = "false"

    try {
        Use-UserInstalls

        # --- Check what is installed ----------------------------------------------------------------

        Say ""
        Say "IKON tool installer ($(if ($machine) { 'for every user' } else { 'for this user' }))" Cyan
        Say ""

        $before = Get-AllComponents
        Write-Components $before

        if ($script:CheckOnly) {
            return (Complete-Run $before)
        }

        $missing = @($before | Where-Object { $_.status -ne "ok" } | ForEach-Object { $_.component })
        Emit ([ordered]@{ event = "plan"; install = $missing; scope = $(if ($machine) { "machine" } else { "user" }) })

        if ($interactive -and -not $yes) {
            Say ""
            $toInstall = @($missing | Where-Object { $_ -ne "ikon" } | ForEach-Object { $Names[$_] })
            $list = if ($toInstall.Count -gt 1) { ($toInstall[0..($toInstall.Count - 2)] -join ", ") + " and " + $toInstall[-1] } else { "$toInstall" }
            $tool = if ($missing -contains "ikon") { "installs" } else { "updates" }
            if ($list) {
                Say "This installs $list, $tool the IKON tool and signs you in."
            } else {
                Say "Everything is installed. This $tool the IKON tool and reinstalls its packages."
            }
            if ((Read-Host "Continue? (y/n)") -notmatch '^[Yy]') {
                Say "Cancelled" Yellow
                return 1
            }
        }

        # The IKON tool comes from dotnet tool, so only the other three need winget
        if ($machine -and @($missing | Where-Object { $_ -ne "ikon" }).Count -gt 0 -and -not (Get-Command winget -ErrorAction SilentlyContinue)) {
            throw "--machine installs with winget, which is not available. Install App Installer from the Microsoft Store, or run without --machine"
        }

        # --- Install the prerequisites --------------------------------------------------------------

        # Only .NET, which the IKON tool runs on, stops the run; the rest still installs without Node or Git
        foreach ($component in $before | Where-Object { $_.status -ne "ok" -and $_.component -ne "ikon" }) {
            $id = $component.component
            Step $id "start" "Installing $($Names[$id])..."

            try {
                if ($machine) { Install-WithWinget $id } else { & "Install-$id-User" }
                $after = Get-Component $id
                if ($after.status -ne "ok") {
                    throw "$($Names[$id]) is still $($after.status) after installing it. Open a new terminal and run the installer again"
                }
            } catch {
                if ($id -eq "dotnet") { throw }
                $reason = $_.Exception.Message
                Step $id "failed" $reason
                if (-not $script:Failure) { $script:Failure = $reason }
                continue
            }
            Step $id "done" "$($Names[$id]) $($after.version) installed"
            if (-not $machine) { Write-ShadowWarning $id }
        }

        # --- The IKON tool: update, install, or reinstall ---------------------------------------

        Step "ikon" "start" "Installing the IKON tool..."
        Install-IkonTool
        Step "ikon" "done" "IKON tool $(Get-ToolVersion ikon) installed"

        # --- The tool packages: reinstalled when they were here already, installed by signing in ---
        # Reinstalling is the repair a re-run is for; packages a sign-in has just installed need none

        $signedIn = Test-SignedIn
        if ($signedIn) {
            Step "packages" "start" "Reinstalling the IKON tool packages..."
            # Not fatal: the tool is installed either way, and it reinstalls a broken package itself
            if ((Invoke-Native ikon @("--disable-auto-update", "self", "update")) -eq 0) {
                Step "packages" "done" "IKON tool packages reinstalled"
            } else {
                Step "packages" "warning" "The IKON tool packages could not be reinstalled. Run 'ikon self update' to try again"
            }
        } elseif ($login -and $interactive) {
            Step "login" "start" "Signing in to IKON..."
            if ((Invoke-Attached ikon @("--disable-auto-update", "login")) -eq 0) {
                $signedIn = $true
                Step "login" "done" "Signed in"
            } else {
                Step "login" "warning" "Not signed in. Run 'ikon login' later; it installs the IKON tool packages"
            }
        } else {
            Step "packages" "skipped" "The IKON tool packages install when you sign in with 'ikon login'"
        }

        # --- HTTPS development certificate for apps run locally ---------------------------------

        if ($interactive) {
            Step "certificate" "start" "Trusting the HTTPS development certificate (Windows asks to confirm)..."
            if ((Invoke-Quietly dotnet @("dev-certs", "https", "--trust")) -eq 0) {
                Step "certificate" "done" "HTTPS development certificate trusted"
            } else {
                Step "certificate" "warning" "The HTTPS development certificate is not trusted. Run 'ikon install certificate' later"
            }
        } elseif ($env:CI -eq "true") {
            $null = Invoke-Quietly dotnet @("dev-certs", "https")
        }

        Say ""
        $after = Get-AllComponents
        Write-Components $after
        if ($script:Failure) {
            Say ""
            Say "Not finished: $($script:Failure)" Red
        } elseif (-not $script:Json) {
            Write-Next
        }
        Remove-Item $script:Log -ErrorAction SilentlyContinue
        return (Complete-Run $after $signedIn)
    } catch {
        Say "Error: $($_.Exception.Message)" Red
        Emit ([ordered]@{ event = "result"; ok = $false; message = $_.Exception.Message })
        return 1
    } finally {
        Pop-Location
    }
}

# --- Output: text for people, JSON events for programs --------------------------------------------

$Names = [ordered]@{ dotnet = ".NET SDK"; node = "Node.js"; git = "Git"; ikon = "IKON tool" }

function Say([string]$text, [string]$color = "Gray") {
    if ($script:Json) { [Console]::Error.WriteLine($text) } else { Write-Host $text -ForegroundColor $color }
}

function Emit($event) {
    if ($script:Json) { [Console]::Out.WriteLine(($event | ConvertTo-Json -Compress -Depth 5)) }
}

# One step of the install: start, done, skipped, warning or failed. A thrown error ends the run instead
function Step([string]$id, [string]$state, [string]$message) {
    Emit ([ordered]@{ event = "step"; step = $id; state = $state; message = $message })
    $color = @{ start = "Cyan"; done = "Green"; skipped = "DarkGray"; warning = "Yellow"; failed = "Red" }[$state]
    Say $message $color
}

function Write-Components($components) {
    foreach ($c in $components) {
        $color = @{ ok = "Green"; outdated = "Yellow"; missing = "Yellow" }[$c.status]
        $version = if ($c.version) { $c.version } else { "-" }
        Say ("  {0,-10} {1,-14} {2}" -f $Names[$c.component], $version, $c.status) $color
    }
}

function Complete-Run($components, [bool]$signedIn = $false) {
    $ok = -not ($components | Where-Object { $_.status -ne "ok" })
    $agents = [ordered]@{}
    foreach ($id in $AgentNames.Keys) { $agents[$id] = Test-Agent $id }
    $agents["claudeDesktop"] = Test-ClaudeDesktop
    Emit ([ordered]@{ event = "result"; ok = $ok; signedIn = $signedIn; components = @($components); paths = @($script:AddedPaths); agents = $agents; message = $script:Failure })
    if ($ok) { return 0 } else { return 1 }
}

# What to do next, laid out as the ikon tool's own Next blocks: a yellow heading and numbered steps.
# A command is written in braces and shown highlighted.
function Write-Next {
    $steps = @()
    # Run as a file, this script cannot change the PATH of the terminal that started it. Run through iex,
    # it shares that terminal's PATH, which already has every change
    if ($runAsFile -and @("ikon", "dotnet", "node", "git" | Where-Object { -not (Test-OnPath $script:StartPath $_) }).Count -gt 0) {
        $steps += "Open a new terminal"
    }
    $agent = @($AgentNames.Keys | Where-Object { Test-Agent $_ }) | Select-Object -First 1
    if (-not $agent) {
        $steps += "Install a coding agent: {ikon agent list} lists them with the command that installs each"
    }
    $steps += "Make a folder for your apps and go into it: {mkdir ikon-apps; cd ikon-apps}"
    if ($agent) {
        $steps += "Start $($AgentNames[$agent]) with {$agent} and say what the app should do"
    } else {
        $steps += "Start your coding agent there and say what the app should do"
    }

    Write-Host ""
    Write-Host "Next" -ForegroundColor Yellow
    for ($i = 0; $i -lt $steps.Count; $i++) {
        Write-Host "  $($i + 1). " -NoNewline
        foreach ($part in $steps[$i] -split '(\{[^}]*\})') {
            if ($part -match '^\{(.*)\}$') { Write-Host $Matches[1] -NoNewline -ForegroundColor Cyan } elseif ($part) { Write-Host $part -NoNewline }
        }
        Write-Host ""
    }
}

function Stop-Usage([string]$message) {
    Say "$message. Options: --machine, --format json, --check, --yes, --no-login" Red
    return 2
}

# --- Running other programs ----------------------------------------------------------------------

# Runs a program and returns its exit code. With --format json its output goes to stderr, so stdout
# carries nothing but events.
function Invoke-Native([string]$exe, [string[]]$arguments) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        if ($script:Json) {
            & $exe @arguments 2>&1 | ForEach-Object { [Console]::Error.WriteLine("$_") }
        } else {
            & $exe @arguments 2>&1 | ForEach-Object { "$_" } | Out-Host
        }
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $saved
    }
}

# Runs an installer with its output kept in a log. Returns the exit code.
function Invoke-Logged([string]$exe, [string[]]$arguments) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $exe @arguments *>&1 | ForEach-Object { "$_" } | Add-Content $script:Log
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $saved
    }
}

# The same, showing the end of the log when it fails
function Invoke-Quietly([string]$exe, [string[]]$arguments) {
    $code = Invoke-Logged $exe $arguments
    if ($code -ne 0) { Write-LogTail }
    return $code
}

function Write-LogTail {
    Get-Content $script:Log -Tail 20 -ErrorAction SilentlyContinue | ForEach-Object { Say $_ DarkGray }
    Say "Full output: $($script:Log)" DarkGray
}

# Runs a program and returns what it printed on stdout, or $null when it fails or is not installed
function Invoke-Capture([string]$exe, [string[]]$arguments) {
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) {
        return $null
    }
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $text = & $exe @arguments 2>$null | Out-String
        if ($LASTEXITCODE -eq 0) { return $text }
    } catch {
        # A program that cannot even start reads the same as one that is not installed
    } finally {
        $ErrorActionPreference = $saved
    }
    return $null
}

# Runs a program on this console, for one that talks to the person (sign-in)
function Invoke-Attached([string]$exe, [string[]]$arguments) {
    $process = Start-Process -FilePath (Get-Command $exe).Source -ArgumentList $arguments -NoNewWindow -Wait -PassThru
    return $process.ExitCode
}

function Get-ToolVersion([string]$command) {
    $text = Invoke-Capture $command @("--version")

    # Older ikon releases know only the 'version' verb, which may print warnings before the version
    if (-not $text -and $command -eq "ikon") {
        $text = Invoke-Capture ikon @("--disable-auto-update", "version")
    }
    $versions = @([regex]::Matches("$text", '\d+\.\d+(\.\d+)*') | ForEach-Object { $_.Value })
    if ($versions.Count -gt 0) { return $versions[-1] }
    return $null
}

# --- Checking the components ---------------------------------------------------------------------

function Get-Component([string]$id) {
    $version = Get-ToolVersion $id
    $required = @{ dotnet = $DOTNET_SDK_MAJOR; node = $NODE_MAJOR }[$id]
    $status = if (-not $version) { "missing" } elseif ($required -and [int]($version.Split('.')[0]) -lt $required) { "outdated" } else { "ok" }
    Emit ([ordered]@{ event = "detect"; component = $id; version = $version; status = $status })
    return [pscustomobject][ordered]@{ component = $id; version = $version; status = $status }
}

function Get-AllComponents {
    foreach ($id in $Names.Keys) { Get-Component $id }
}

# Whether the tool's sign-in file, login.json in its data folder, is in any folder the tool may keep it in:
# IKON_DATA_DIR, %LOCALAPPDATA%, then the tool's fallbacks. Without it nobody is signed in. A sandboxed tool keeps
# its data under IKON_SANDBOX_ROOT, where only the tool knows the path, so this returns true and the tool is asked
function Test-SignInFile {
    if ($env:IKON_SANDBOX_ROOT) { return $true }
    foreach ($folder in @($env:IKON_DATA_DIR, $env:LOCALAPPDATA, $env:APPDATA, $env:USERPROFILE, $env:HOME)) {
        if ($folder -and (Test-Path -LiteralPath (Join-Path $folder "ikon\login.json") -PathType Leaf)) { return $true }
    }
    return $false
}

# Asks the tool only when its sign-in file exists, because the tool's first start on Windows takes up to ten seconds
function Test-SignedIn {
    if (-not (Test-SignInFile)) { return $false }
    $text = Invoke-Capture ikon @("--disable-auto-update", "status", "--format", "json")
    try {
        $status = $text | ConvertFrom-Json
        return [bool]($status.environments | Where-Object { $_.state -in "logged-in", "renewal-failed" })
    } catch {
        # An ikon that cannot report its status has no usable sign-in either
        return $false
    }
}

# --- Coding agents, for the Next steps and IKON Desktop -------------------------------------------

# On PATH, or in a folder an installer puts it in that this PATH may not include yet: Claude Code's own installer,
# npm's global folder, 'ikon install' when that folder is not writable, and Antigravity's installer
function Test-Agent([string]$name) {
    if (Get-Command $name -ErrorAction SilentlyContinue) { return $true }
    return Test-OnPath ((Join-Path $env:USERPROFILE ".local\bin"), (Join-Path $env:APPDATA "npm"), (Join-Path $env:LOCALAPPDATA "ikon-toolchains\npm"), (Join-Path $env:LOCALAPPDATA "agy\bin") -join ';') $name
}

# An older per-user installer, or the Store package the current installer registers, as the ikon
# tool's own check finds it
function Test-ClaudeDesktop {
    if (Test-Path (Join-Path $env:LOCALAPPDATA "AnthropicClaude\claude.exe")) { return $true }
    $packages = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages"
    return [bool](Get-ChildItem $packages -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like "Claude_*pzs8sxrjxfjjc" })
}

# Whether a command is in one of the folders of a PATH value
function Test-OnPath([string]$path, [string]$name) {
    foreach ($folder in $path -split ';' | Where-Object { $_ }) {
        foreach ($extension in ".exe", ".cmd", ".bat", ".ps1") {
            if (Test-Path -LiteralPath (Join-Path ([Environment]::ExpandEnvironmentVariables($folder)) "$name$extension")) { return $true }
        }
    }
    return $false
}

# --- Paths --------------------------------------------------------------------------------------

# Finds an earlier run's per-user installs, even from a window opened before that run, and puts them
# back on PATH if the user environment lost them. Only new enough ones: an old one would shadow a
# newer copy installed for every user.
function Use-UserInstalls {
    $dotnet = Invoke-Capture (Join-Path $DotnetUserRoot "dotnet.exe") @("--version")
    if ($dotnet -and [int]($dotnet.Split('.')[0]) -ge $DOTNET_SDK_MAJOR) {
        if (-not $script:CheckOnly) { [Environment]::SetEnvironmentVariable("DOTNET_ROOT", $DotnetUserRoot, "User") }
        $env:DOTNET_ROOT = $DotnetUserRoot
        Add-UserPath $DotnetUserRoot
    }
    $node = Invoke-Capture (Join-Path $NodeUserRoot "node.exe") @("--version")
    if ($node -and [int]($node.TrimStart('v').Split('.')[0]) -ge $NODE_MAJOR) {
        Add-UserPath $NodeUserRoot
    }
    if (Test-Path (Join-Path $DotnetToolsDir "ikon.exe")) {
        Add-UserPath $DotnetToolsDir
    }
}

# Puts a folder first on the user's own PATH, which needs no administrator, and on this session's.
# The user PATH is read and written raw: SetEnvironmentVariable would store every %VAR% in the user PATH expanded, so an
# entry like %JAVA_HOME%\bin would stop following JAVA_HOME for good
function Add-UserPath([string]$folder) {
    if (-not $script:CheckOnly) {
        $key = Get-Item "HKCU:\Environment"
        $raw = $key.GetValue("Path", "", "DoNotExpandEnvironmentNames")
        $entries = @($raw -split ';' | Where-Object { $_ -and [Environment]::ExpandEnvironmentVariables($_) -ne $folder })
        $updated = (@($folder) + $entries) -join ';'
        if ($updated -ne $raw) {
            Set-ItemProperty "HKCU:\Environment" -Name Path -Value $updated -Type ExpandString
            Send-EnvironmentChange
        }
    }
    $env:Path = "$folder;" + (($env:Path -split ';' | Where-Object { $_ -ne $folder }) -join ';')
    # --check changes nothing, so it reports no folder as put on PATH
    if (-not $script:CheckOnly -and $script:AddedPaths -notcontains $folder) { $script:AddedPaths += $folder }
}

# What SetEnvironmentVariable does after its own registry write: tells Explorer, so a terminal opened
# from it gets the new PATH without signing out
function Send-EnvironmentChange {
    if (-not ("IkonInstall.Environment" -as [type])) {
        Add-Type -Namespace IkonInstall -Name Environment -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, UIntPtr wParam, string lParam, uint flags, uint timeout, out UIntPtr result);
'@
    }
    $result = [UIntPtr]::Zero
    $null = [IkonInstall.Environment]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, "Environment", 2, 5000, [ref]$result)
}

# Windows puts the machine PATH before the user's, so an older copy installed for every user wins
# in new terminals over the one just installed here
function Write-ShadowWarning([string]$id) {
    $exe = @{ dotnet = "dotnet.exe"; node = "node.exe"; git = "git.exe" }[$id]
    foreach ($folder in [Environment]::GetEnvironmentVariable("Path", "Machine") -split ';') {
        if ($folder -and (Test-Path (Join-Path $folder $exe))) {
            Step $id "warning" "The $($Names[$id]) installed for every user in $folder comes first in new terminals. Run the installer with --machine to update that one"
            return
        }
    }
}

# Reloads PATH after an installer changed it in the registry, keeping this session's own entries first
function Update-SessionPath {
    $registry = @([Environment]::GetEnvironmentVariable("Path", "Machine"), [Environment]::GetEnvironmentVariable("Path", "User")) -join ';'
    $env:Path = (@($env:Path -split ';') + @($registry -split ';') | Where-Object { $_ } | Select-Object -Unique) -join ';'
}

# --- Installing for this user ----------------------------------------------------------------------

function Install-dotnet-User {
    # Microsoft's own install script, run as a script block so no execution policy can stop it
    $installer = [scriptblock]::Create((Invoke-RestMethod "https://dot.net/v1/dotnet-install.ps1"))
    try {
        & $installer -Channel "$DOTNET_SDK_MAJOR.0" -InstallDir $DotnetUserRoot -NoPath *>&1 | ForEach-Object { "$_" } | Add-Content $script:Log
    } catch {
        Write-LogTail
        throw
    }
    [Environment]::SetEnvironmentVariable("DOTNET_ROOT", $DotnetUserRoot, "User")
    $env:DOTNET_ROOT = $DotnetUserRoot
    Add-UserPath $DotnetUserRoot
}

function Install-node-User {
    # The official archive, checked against its published digest
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "x64" }
    $name = "node-v$NODE_VERSION-win-$arch"
    $archive = Join-Path ([IO.Path]::GetTempPath()) "$name.zip"
    Invoke-WebRequest "https://nodejs.org/dist/v$NODE_VERSION/$name.zip" -OutFile $archive -UseBasicParsing
    $sums = (Invoke-WebRequest "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt" -UseBasicParsing).Content
    $expected = ($sums -split "`n" | Where-Object { $_ -match "\s$name\.zip$" }) -replace '\s.*$', ''
    if (-not $expected -or $expected -ne (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()) {
        Remove-Item $archive -ErrorAction SilentlyContinue
        throw "The Node.js download does not match its published checksum"
    }

    # Always the same folder, so PATH stays right across Node versions
    $parent = Split-Path $NodeUserRoot
    try {
        if (Test-Path $NodeUserRoot) { Remove-Item $NodeUserRoot -Recurse -Force -ErrorAction Stop }
    } catch {
        Remove-Item $archive -ErrorAction SilentlyContinue
        throw "The Node.js in $NodeUserRoot is in use, so it cannot be replaced. Close what runs it (IKON Connect, a dev server) and run the installer again"
    }
    Remove-Item (Join-Path $parent $name) -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive $archive -DestinationPath $parent -Force
    Rename-Item (Join-Path $parent $name) (Split-Path $NodeUserRoot -Leaf)
    Remove-Item $archive
    Add-UserPath $NodeUserRoot
}

function Install-git-User {
    # Git for Windows' own installer, which installs without an administrator when asked for this user
    # only. Run by an administrator it installs for every user anyway, into Program Files.
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "64-bit" }
    $release = Invoke-RestMethod "https://api.github.com/repos/git-for-windows/git/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -match "^Git-[\d.]+-$arch\.exe$" } | Select-Object -First 1
    if (-not $asset) {
        throw "No Git for Windows installer found for $arch"
    }
    $installer = Join-Path ([IO.Path]::GetTempPath()) $asset.name
    Invoke-WebRequest $asset.browser_download_url -OutFile $installer -UseBasicParsing
    $process = Start-Process $installer -ArgumentList "/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-", "/SUPPRESSMSGBOXES", "/CURRENTUSER" -Wait -PassThru
    Remove-Item $installer -ErrorAction SilentlyContinue
    if ($process.ExitCode -ne 0) {
        throw "The Git installer failed (exit code $($process.ExitCode))"
    }
    # The installer puts its folder on PATH itself, the user's or the machine's
    Update-SessionPath
    $userCmd = Join-Path $GitUserRoot "cmd"
    if (Test-Path $userCmd) { $script:AddedPaths += $userCmd }
}

# --- Installing for every user ---------------------------------------------------------------------

function Install-WithWinget([string]$id) {
    $package = @{
        dotnet = @("Microsoft.DotNet.SDK.$DOTNET_SDK_MAJOR")
        node = @("OpenJS.NodeJS.LTS", "--version", $NODE_VERSION)
        git = @("Git.Git")
    }[$id]
    $code = Invoke-Quietly winget (@("install", "--id") + $package + @("-e", "--source", "winget", "--silent", "--accept-source-agreements", "--accept-package-agreements", "--disable-interactivity"))
    if ($code -ne 0) {
        throw "winget could not install $($Names[$id]) (exit code $code)"
    }
    Update-SessionPath
}

# --- The IKON tool ---------------------------------------------------------------------------------

function Install-IkonTool {
    # A config of its own: a global tool install still reads NuGet settings from the current folder
    $configDir = Join-Path ([IO.Path]::GetTempPath()) ("ikon-nuget-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory $configDir | Out-Null
    $config = Join-Path $configDir "NuGet.Config"
    Set-Content $config -Encoding UTF8 -Value @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
</configuration>
'@
    $common = @("ikon", "--global", "--no-http-cache", "--configfile", $config)

    try {
        # Update what is there, install what is not, and replace an install too broken for either. A dev
        # channel build (ikon-dev) also provides the 'ikon' command, so it is removed too, because this
        # installs the released tool
        if ((Invoke-Logged dotnet (@("tool", "update") + $common)) -ne 0 -and
            (Invoke-Logged dotnet (@("tool", "install") + $common)) -ne 0) {
            $null = Invoke-Logged dotnet @("tool", "uninstall", "ikon", "--global")
            $null = Invoke-Logged dotnet @("tool", "uninstall", "ikon-dev", "--global")
            if ((Invoke-Logged dotnet (@("tool", "install") + $common)) -ne 0) {
                Write-LogTail
                $running = if (Get-Process ikon -ErrorAction SilentlyContinue) { ". An ikon process is running; stop it (IKON Connect included) and try again" } else { "" }
                throw "The IKON tool could not be installed$running"
            }
        }
    } finally {
        Remove-Item $configDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Add-UserPath $DotnetToolsDir
    if (-not (Get-ToolVersion ikon)) {
        throw "The IKON tool was installed but does not run"
    }
}

# --- Run ---------------------------------------------------------------------------------------------

# Run as a file of its own, report through the exit code. Under iex this code runs in the caller's
# scope, where exit would close their window or end their script, so it only sets $LASTEXITCODE.
$command = $MyInvocation.MyCommand
$runAsFile = $command.CommandType -eq "ExternalScript" -and $command.ScriptContents -match "function Install-Ikon"

$exitCode = Install-Ikon @args

if ($runAsFile) {
    exit $exitCode
}
$global:LASTEXITCODE = $exitCode
