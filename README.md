<!-- checked-against: e2897117e3b0c442e3b0c442 -->

# Getting started with IKON

You build an IKON app by telling a coding agent what the app should do. The agent creates the app
with the IKON tool, runs it on your computer and checks that it works. When you are happy with it,
one command puts it online.

There are three ways to start:

1. **IKON Studio** in your browser. It is still experimental and under development.
2. **IKON Desktop and Claude Desktop.** No terminal needed.
3. **A terminal**, with Claude Code, Codex or Gemini CLI.

For now we recommend the second or the third. Both install the same things and make the same kind of app, so you can
switch between them later.

## What you need

- A computer with Windows, macOS or Linux.
- An IKON account. You sign in to it while installing.
- For IKON Desktop: a Claude subscription, which Claude Desktop's **Code** tab needs.
- For a terminal: an account for the coding agent you use — a Claude subscription for Claude Code,
  a ChatGPT plan for Codex, or a Google account for Gemini CLI.

The AI your app uses, such as text, images or speech, is paid with IKON credits, not with your
coding agent's subscription.

## IKON Studio (experimental)

[IKON Studio](https://studio.ikonai.app) builds apps in the browser, with nothing to install. It is
still experimental and under development, so for now we recommend IKON Desktop or a terminal. An app
you build in Studio can move to your computer later, as described below.

## IKON Desktop and Claude Desktop

1. **[Download IKON Desktop](https://studio.ikonai.app/download)** for Windows, macOS (Apple silicon)
   or Linux. The installers are also on the
   [releases page](https://github.com/ikon-ai/ikon-install/releases/latest).
2. Open IKON Desktop and sign in to IKON. It installs .NET, Node.js, Git and the IKON tool, and
   keeps them up to date.
3. Install [Claude Desktop](https://claude.ai/download) if you don't have it yet; IKON Desktop can
   install it for you. Sign in to Claude.
4. In Claude Desktop, choose the **Code** tab and select the folder for your apps. IKON Desktop
   suggests `IKON Apps` in your home folder.
5. Say what you want, for example:

   > Use the ikon tool to create a new IKON app here. The app should let my book club vote on the
   > next book.

## A terminal

1. Install the IKON tool. On Windows, in PowerShell:

   ```powershell
   irm https://ikonai.com/install.ps1 | iex
   ```

   On macOS and Linux:

   ```bash
   curl -fsSL https://ikonai.com/install.sh | bash
   ```

   The script installs .NET, Node.js, Git and the IKON tool where they are missing or too old, and
   signs you in. Run it again any time to update or repair the install.
2. Open a new terminal, so that it finds `ikon`, and make a folder for your apps:

   ```bash
   mkdir ikon-apps
   cd ikon-apps
   ```

3. Start your coding agent there: `claude`, `codex` or `gemini`. If you don't have one yet, install
   one with `ikon install claude`, `ikon install codex` or `ikon install gemini`.
4. Say what you want, for example:

   > Use the ikon tool to create a new IKON app here. The app should let my book club vote on the
   > next book.

You can also create an app yourself with `ikon new <name>`, then start your agent in its folder.

## What happens next

The agent runs `ikon new` to create the app and reads the app's `AGENTS.md`, which explains how
IKON apps are built. Then it writes the app, runs it and checks that it works. Keep asking for
changes in the same conversation.

To run the app yourself, run `ikon run` in the app's folder. It prints the app's address when the app
is ready. Windows may ask you to allow network access the first time, and macOS may ask for your
login password to use the keychain; choose **Allow** or **Always Allow**.

To put the app online, run `ikon deploy` in the app's folder, or ask your agent to deploy it.
`ikon deploy` saves your changes and prints the app's public address.

## Work on a Studio app on your computer

In Studio, open the app's **Settings**, then **Code**, and choose **Open on your computer**. In IKON
Desktop, choose **Work on an app you already have**. Or run this in a terminal, with your app's id:

```bash
ikon open <app-id>
```

This signs you in, downloads the app with its history and checks that the computer can run it. Then
`ikon run` runs it, and `ikon save` sends your changes back to Studio.
