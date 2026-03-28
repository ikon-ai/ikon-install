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

## Create a new Ikon AI App

Scaffold a new app project in your current directory:

```bash
ikon app new MyFirstAIApp
```

This creates a `MyFirstAIApp` folder in your current directory with a ready-to-run app, sample code, and configuration.

> If an app already exists on the Ikon platform, you can download it instead with `ikon app load`.

## Run the Ikon AI App locally

Start the local development server from the project directory:

```bash
cd MyFirstAIApp
ikon app run
```

You can also open the project in your preferred IDE (any IDE that supports .NET projects) and run it directly from there.

When the app starts, its UI will open automatically in your default web browser.

> Note (Windows): On the first run, you may see a firewall prompt asking for network access permission. Make sure to allow access.

> Note (macOS): You may be prompted to enter the login keychain password (usually your macOS user password). Enter the password and click `Always Allow`.

## Deploy to Ikon Cloud

Bundle and deploy your latest build to the Ikon Cloud:

```bash
ikon app deploy
```

The URL of your deployed app will be printed in the terminal after a successful deployment.

## Save your work

The Ikon tool has built-in version control. Review your changes and save them:

```bash
ikon app changes
ikon app save
```

## Explore available commands

Run the Ikon tool without arguments to see all available commands, or add a subcommand to see its verbs:

```bash
ikon
ikon app
```

## Get AI App examples

Browse the examples in your browser or download them locally:

```bash
ikon examples open
ikon examples download
```

## Develop with coding agents

Open the project folder with your preferred coding agent (e.g., [Cursor](https://cursor.com/), [Claude Code](https://github.com/anthropics/claude-code), [Codex CLI](https://github.com/openai/codex)) and start coding or ask questions. The project contains documentation files (e.g., `AGENTS.md`) to help the agent understand the codebase.

## Quick reference

| Step        | Command              | Purpose                         |
| ----------- | -------------------- | ------------------------------- |
| **Login**   | `ikon login`         | Authenticate the CLI            |
| **Create**  | `ikon app new MyApp` | Create a new Ikon app           |
| **Load**    | `ikon app load`      | Download an existing app        |
| **Run**     | `ikon app run`       | Start the local dev server      |
| **Deploy**  | `ikon app deploy`    | Upload the app bundle           |
| **Changes** | `ikon app changes`   | Show uncommitted changes        |
| **Save**    | `ikon app save`      | Save changes to version control |
| **Update**  | `ikon app update`    | Update Ikon package references  |
