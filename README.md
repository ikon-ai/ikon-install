# ikon-install

Installer scripts for the `ikon` command-line tool. Each script installs the .NET SDK and Node.js
versions the tool needs, then the tool itself, and puts `ikon` on your PATH.

## Windows

Open Terminal and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iwr "https://ikonai.com/install.ps1" -useb | iex
```

## macOS and Linux

Open a terminal and run:

```bash
bash <(curl -fsSL https://ikonai.com/install.sh)
```

## Building an app

Apps are built in Ikon Studio at [studio.ikonai.app](https://studio.ikonai.app). To work on a Studio
project from your own machine, open it in Studio, click **Open locally**, and run the command it
shows:

```bash
ikon load <ref>
```

This signs you in, downloads the project, restores its dependencies and offers to open it in an
editor. `ikon app run` then runs it locally and `ikon app save` publishes your changes back to
Studio.

Run `ikon` without arguments to list every command.
