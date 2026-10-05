<!-- checked-against: d90cd82ae3b0c442e3b0c442 -->

# ikon-install

Installers for the `ikon` command-line tool.

## Ikon Desktop

Ikon Desktop is the app for everyone who would rather not use a terminal: download it, open it and
sign in. It installs the Ikon tool for you, keeps it up to date, opens Ikon Studio in its own window
and lets your apps use this computer through Ikon Connect.

**[Download Ikon Desktop](https://github.com/ikon-ai/ikon-install/releases/latest)** for Windows,
macOS (Apple silicon) or Linux.

If your Mac will not open the downloaded app, install it from Terminal instead, which puts the same
app in Applications and opens it:

```bash
curl -fsSL https://ikonai.com/install-desktop.sh | bash
```

## Install scripts

For a computer without a desktop, or when you would rather work in a terminal. The script checks the .NET SDK, Node.js, Git and the Ikon tool, installs
whatever is missing or too old, signs you in and gets the tool ready. Run it again any time to
update or repair the install.

Windows, in PowerShell:

```powershell
irm https://ikonai.com/install.ps1 | iex
```

macOS and Linux:

```bash
curl -fsSL https://ikonai.com/install.sh | bash
```

Everything goes into your own folders, so no administrator password is needed. The exceptions are Git
on Linux, which only your package manager installs, and the ICU library .NET needs, which a minimal
Linux (a container, a server) may lack and the package manager installs the same way; on a Mac Git comes with Apple's command line
tools, whose installer the script opens for you.

Options, passed as `bash -s -- <options>` after the pipe on macOS and Linux, and as
`& ([scriptblock]::Create((irm https://ikonai.com/install.ps1))) <options>` on Windows:

| Option | |
| --- | --- |
| `--machine` | Install for every user instead, with winget, the official macOS installers or your Linux package manager. Needs an administrator |
| `--check` | Only show what is installed |
| `--yes` | Do not ask before installing |
| `--no-login` | Do not sign in |
| `--format json` | Machine-readable progress, one JSON object per line |

## Connecting this computer to your apps

An app can run its coding agents, and use your browser and files, on your own computer through
Ikon Connect. Start Ikon Connect once, then connect the app by its address, inside the repository
its agents should work in. For Ikon Studio:

```bash
ikon service install
ikon connect https://studio.ikonai.app
```

`ikon service install` starts Ikon Connect now and whenever you log in (a LaunchAgent on macOS, an
at-logon task on Windows). On Linux it is a user unit with lingering, so it starts at boot and keeps
running after logout; where lingering needs an administrator it starts at login, and the tool prints
the command that changes that. `ikon connect <app>` signs you in if you are not, asks you to confirm
the app and what it may do, and prints a six-digit code: type it into **Connect your computer** in
Studio, where your computer appears waiting for it. `ikon connect list` shows what is connected, and
`ikon connect delete <app>` disconnects one.

## Building an app

Apps are built in Ikon Studio at [studio.ikonai.app](https://studio.ikonai.app). To work on a Studio
project from your own machine, open it in Studio, choose **Open on your computer** from the app's
**⋯** menu, and run the command it shows:

```bash
ikon open <app-id> prod
```

This signs you in, downloads the project, checks what the computer needs to run it and offers to
open it in an editor. `ikon run` then runs it locally and `ikon save` publishes your changes back to
Studio.

Run `ikon` without arguments to list its commands and command groups, and `ikon <group>` for the
commands in one.
