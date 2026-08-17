# How to get started with Ikon development

## Install the Ikon tool

### Windows

Open Terminal (right click on Desktop and select `Open in Terminal`) and run:

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

> If an app already exists on the Ikon platform, you can download it instead with `ikon app clone` — or with `ikon load <ref>` (see below) when coming from Studio.

## Take a Studio project local

Apps built in Ikon Studio move to local development with one command:

```bash
ikon load <ref>
```

In Studio, open your app and click **Open locally** to get the command with your project's ref already filled in. It downloads the project with its full history, restores dependencies, and offers to open it in a detected editor.

From there the normal loop applies: `ikon app run` runs the app locally, and `ikon app save` publishes your changes back — Studio picks them up the next time you open the project.

## What a new app already has

Every new app references these, with their namespaces already imported in `GlobalUsings.cs`:

| Package | What it gives you |
|---|---|
| `Ikon.App` | The app itself: reactive state, clients, lifecycle, endpoints, databases, payments, notifications |
| `Ikon.AI` | Image, speech, video, OCR, embeddings, web search and scraping |
| `Ikon.AI.Emergence` | `Emerge.Run<T>()` — LLM text and structured output |
| `Ikon.Agent` | Tools for the model to call (`Tool.Of`, `AddTool`) and agent threads |
| `Ikon.Parallax` | UI components |
| `Ikon.Crosswind` | Styling and motion |
| `Ikon.Resonance` | Audio synthesis and effects |
| `Ikon.App.Storage.Postgres` | Persistent state backed by Postgres |

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

Package and deploy your latest build to the Ikon Cloud:

```bash
ikon app deploy
```

The URL of your deployed app will be printed in the terminal after a successful deployment.

## Save your work

The Ikon tool has built-in version control. Review your changes and save them:

```bash
ikon app diff
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

If you don't have one installed yet, the CLI installs the latest of either:

```bash
ikon install claude
ikon install codex
```

Both then sign in against your own Claude or OpenAI account the first time you run them.

## Quick reference

| Step        | Command              | Purpose                         |
| ----------- | -------------------- | ------------------------------- |
| **Login**   | `ikon login`         | Authenticate the CLI            |
| **Create**  | `ikon app new MyApp` | Create a new Ikon app           |
| **Clone**   | `ikon app clone`     | Download an existing app        |
| **Load**    | `ikon load <ref>`    | Take a Studio project local     |
| **Run**     | `ikon app run`       | Start the local dev server      |
| **Deploy**  | `ikon app deploy`    | Deploy the app to Ikon Cloud    |
| **Diff**    | `ikon app diff`      | Show uncommitted changes        |
| **Save**    | `ikon app save`      | Save changes to version control |
| **Update**  | `ikon app update`    | Update Ikon package references  |

Deploying from CI rather than your own terminal needs a credential that does not involve a browser — see the [CI authentication guide](ikon-ci-authentication-guide.md).
