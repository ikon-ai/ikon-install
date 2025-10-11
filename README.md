# How to get started with Ikon development

## Request an Ikon account

Request an account from Ikon and make sure you can log in to the [Ikon Portal](https://portal.prod.ikon.live/).

## Install the Ikon tool

### Windows

Open the PowerShell terminal and run the following command:

    Set-ExecutionPolicy Bypass -Scope Process -Force; iwr "https://ikon.live/install.ps1" -useb | iex

### macOS

Open the terminal and run the following command:

    source <(curl -sSL https://ikon.live/install.sh)

### Linux

Open the terminal and run the following command:

    source <(curl -sSL https://ikon.live/install.sh)

## Log in with the Ikon tool

Run the following command in the terminal to log in (select Production environment when prompted):

    ikon login
