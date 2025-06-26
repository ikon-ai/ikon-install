# How to get started with Ikon development

## Request an Ikon account

Request an account from Ikon and make sure you can login to the [Ikon Portal](https://portal.prod.ikon.live/).

## Install the Ikon tool

*Note:*  [.NET 8 SDK](https://dotnet.microsoft.com/en-us/download) must be installed before installing the Ikon tool.

### Windows

Open the PowerShell terminal and run the following command:

    Set-ExecutionPolicy Bypass -Scope Process -Force; iwr "https://ikon.live/install.ps1" -useb | iex

### macOS

Open the terminal and run the following command:

    source <(curl -sSL https://ikon.live/install.sh)

### Linux

Open the terminal and run the following command:

    source <(curl -sSL https://ikon.live/install.sh)

## Login with the Ikon tool

Run the following command to login with the Ikon tool:

    ikon login