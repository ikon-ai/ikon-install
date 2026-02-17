# How to get started with Ikon development

## Install the Ikon tool

### Windows

Open PowerShell and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iwr "https://ikonai.com/install.ps1" -useb | iex
```

### macOS

Open Terminal and run:

```bash
bash <(curl -fsSL https://ikonai.com/install.sh)
```

### Linux

Open your preferred shell and run:

```bash
bash <(curl -fsSL https://ikonai.com/install.sh)
```

## Log in with the Ikon tool

Authenticate to the Ikon platform:

```bash
ikon login
```

> Note: This will open a browser window to https://ikonai.com where you can complete the authentication process.

## Create a new Ikon AI App

Create a directory for your new app, open it in the terminal, and scaffold the project:

```bash
ikon app new MyFirstAIApp
```

The command creates a ready-to-run app with sample code and configuration.

## Run the Ikon AI App locally

Start the local development server from the project directory:

```bash
ikon app run
```

You can also open the project in your preferred IDE (any IDE that supports .NET projects) and run it directly from there.

When the app starts, its UI will open automatically in your default web browser.

> Note: On the first run, you may see a firewall prompt asking for network access permission. Make sure to allow access. On macOS, you may be prompted to enter the login keychain password. Enter your password and press `Allow Always`.

## Deploy to Ikon Cloud

Bundle and deploy your latest build to the Ikon Cloud:

```bash
ikon app deploy
```

## Quick reference

| Step       | Command              | Purpose                        |
| ---------- | -------------------- | ------------------------------ |
| **Login**  | `ikon login`         | Authenticate the CLI           |
| **Create** | `ikon app new MyApp` | Create a new Ikon app          |
| **Run**    | `ikon app run`       | Start the local dev server     |
| **Deploy** | `ikon app deploy`    | Upload the app bundle          |
| **Update** | `ikon app update`    | Update Ikon package references |
