# ikon-install
<!-- checked-against: 2905eb1ee3b0c442 -->

Installers for the `ikon` command-line tool.

## Ikon Desktop

Ikon Desktop is the app for everyone who would rather not use a terminal: download it, open it and
sign in. It installs the Ikon tool for you, keeps it up to date, opens Ikon Studio in its own window
and lets your apps use this computer through Ikon Connect.

**[Download Ikon Desktop](https://github.com/ikon-ai/ikon-install/releases/latest)** for Windows,
macOS (Apple silicon) or Linux.

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

Everything goes into your own folders, so no administrator password is needed. The exception is Git
on Linux, which only your package manager installs; on a Mac it comes with Apple's command line
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
Ikon Connect. Sign in once, then connect the app inside the repository its agents should work in:

```bash
ikon login
ikon connect <app>
ikon service install
```

`ikon connect <app>` asks you to confirm the app and what it may do, and `ikon service install`
starts Ikon Connect whenever you log in (a LaunchAgent on macOS, an at-logon task on Windows, a
user unit on Linux). `ikon connect list` shows what is connected, and `ikon connect delete <app>`
disconnects one.

## Building an app

Apps are built in Ikon Studio at [studio.ikonai.app](https://studio.ikonai.app). To work on a Studio
project from your own machine, open it in Studio, click **Open locally**, and run the command it
shows:

```bash
ikon open <ref>
```

This signs you in, downloads the project, restores its dependencies and offers to open it in an
editor. `ikon run` then runs it locally and `ikon save` publishes your changes back to
Studio.

Run `ikon` without arguments to list its commands and command groups, and `ikon <group>` for the
commands in one.
