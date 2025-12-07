# How to get started with Ikon development

## Request an Ikon account

Request an account from Ikon and make sure you can log in to the [Ikon Portal](https://portal.prod.ikon.live/).

## Install the Ikon tool

### Windows

Open PowerShell and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iwr "https://ikon.live/install.ps1" -useb | iex
```

### macOS

Open Terminal and run:

```bash
bash <(curl -fsSL https://ikon.live/install.sh)
```

### Linux

Open your preferred shell and run:

```bash
bash <(curl -fsSL https://ikon.live/install.sh)
```

## Log in with the Ikon tool

Authenticate against the Ikon backend:

```bash
ikon login
```
