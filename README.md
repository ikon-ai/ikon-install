<!-- checked-against: 942c8919a86125dce3b0c442 -->

# Getting started with IKON

You build an IKON app in [IKON Studio](https://studio.ikonai.app) by saying what the app should do.
Studio plans the app, builds it, checks that it works and puts it online. All you need is a browser
and an IKON account.

## Build in IKON Studio

Open [IKON Studio](https://studio.ikonai.app), sign in and describe the app you want. Studio drafts
a plan, builds the app and shows it running. Keep asking for changes in the same place.

Building with Studio uses IKON credits, and so does the AI your app uses, such as text, images or
speech.

## Use your own coding agent

Studio can also build with a coding agent on your own computer, signed in with your own account and
working under your plan with it. This needs a computer with Windows, macOS or Linux, where the agent
runs:

1. **[Download IKON Desktop](https://studio.ikonai.app/download)**, open it and sign in to IKON.
2. Under **Your coding agents**, install the ones you have an account for and sign in to each.
3. Select **Connect Studio**.
4. In Studio, choose your agent under **Runs on**, below the field where you type.

## Build on your own

You can also build IKON apps without Studio, in a desktop coding app or in a terminal. Both make
the same kind of app, and an app can move between Studio and your computer.

### In a desktop coding app

IKON Desktop installs and opens the desktop coding apps it supports, under **Desktop apps**.

1. Open the app and sign in with your account there.
2. Choose the `IKON Apps` folder in your home folder as the folder to work in.
3. Say what you want, for example:

   > Use the ikon tool to create a new IKON app in a new folder inside this one. The app should let
   > my book club vote on the next book.

### In a terminal

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

3. Start your coding agent there. If you don't have one yet, `ikon agent list` lists the ones IKON
   works with and the command that installs each.
4. Say what you want, as in the example above.

You can also create an app yourself with `ikon new <name>`, then start your agent in its folder.

### What happens next

The agent runs `ikon new` to create the app and reads the app's `AGENTS.md`, which explains how
IKON apps are built. Then it writes the app, runs it and checks that it works. Keep asking for
changes in the same conversation.

To run the app yourself, run `ikon run` in the app's folder. It prints the app's address when the app
is ready. Windows may ask you to allow network access the first time, and macOS may ask for your
login password to use the keychain; choose **Allow** or **Always Allow**. If your browser says
the app is not secure, run `ikon install certificate`.

To put the app online, run `ikon deploy` in the app's folder, or ask your agent to deploy it.
`ikon deploy` saves your changes and prints the app's public address.

## Work on a Studio app on your computer

In Studio, open the app's **Settings**, then **Code**, choose **Open on your computer**, then **Open
in IKON Desktop**. Or, in IKON Desktop, open **Desktop apps** and choose **Work on an app you already
have**. Or run this in a terminal, with your app's id:

```bash
ikon open <app-id>
```

This signs you in, downloads the app with its history and checks that the computer can run it. Then
`ikon run` runs it, and `ikon save` sends your changes back to Studio.
