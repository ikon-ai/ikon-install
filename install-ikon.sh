#!/bin/bash

# source <(curl -sSL https://ikon.live/install.sh)

set -e

RED='\033[0;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

get_dotnet_install_instructions() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ $(uname -m) == "arm64" ]]; then
            echo "Please install .NET SDK 8 from: https://dotnet.microsoft.com/en-us/download/dotnet/thank-you/sdk-8.0.411-macos-arm64-installer"
        else
            echo "Please install .NET SDK 8 from: https://dotnet.microsoft.com/en-us/download/dotnet/thank-you/sdk-8.0.411-macos-x64-installer"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            echo "Please install .NET SDK 8 with:"
            echo "sudo apt-get update && sudo apt-get install -y dotnet-sdk-8.0"
        else
            echo "Please install .NET SDK 8 - check instructions for your distribution at:"
            echo "https://learn.microsoft.com/en-us/dotnet/core/install/linux?WT.mc_id=dotnet-35129-website"
        fi
    else
        echo "Please install .NET SDK 8 from: https://dotnet.microsoft.com/en-us/download/dotnet/8.0"
    fi
    echo "And then run this script again"
}

echo "Checking pre-requisites for ikon tool installation..."

# Check if dotnet is installed
if ! command -v dotnet &> /dev/null; then
    echo -e "${RED}Error: .NET SDK is not installed${NC}"
    get_dotnet_install_instructions
    exit 1
fi

# Check dotnet version
DOTNET_VERSION=$(dotnet --version)
MAJOR_VERSION=$(echo $DOTNET_VERSION | cut -d'.' -f1)

if [ "$MAJOR_VERSION" -lt 8 ]; then
    echo -e "${RED}Error: .NET SDK version 8 or higher is required${NC}"
    echo "Current version: $DOTNET_VERSION"
    get_dotnet_install_instructions
    exit 1
fi

echo -e "${GREEN}.NET SDK $DOTNET_VERSION found${NC}"

# Determine the dotnet tools path
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    DOTNET_TOOLS_PATH="$HOME/.dotnet/tools"
    SHELL_RC="$HOME/.zprofile"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    DOTNET_TOOLS_PATH="$HOME/.dotnet/tools"
    SHELL_RC="$HOME/.bashrc"
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    fi
else
    echo -e "${YELLOW}Warning: Unknown OS type, using default paths${NC}"
    DOTNET_TOOLS_PATH="$HOME/.dotnet/tools"
    SHELL_RC="$HOME/.bashrc"
fi

PATH_ALREADY_CONFIGURED=false

# Check if dotnet tools path is already in PATH
if echo "$PATH" | grep -q "$DOTNET_TOOLS_PATH"; then
    PATH_ALREADY_CONFIGURED=true
else
    export PATH="$DOTNET_TOOLS_PATH:$PATH"
fi

# Install ikon tool globally
echo "Installing ikon tool..."

if ! dotnet tool install ikon -g; then
    echo -e "${RED}Error: Failed to install ikon tool${NC}"
    exit 1
fi

# Add to shell configuration file for future sessions (only if not already in PATH or in the config)
if [[ "$PATH_ALREADY_CONFIGURED" == "false" ]]; then
    if ! grep -q "$DOTNET_TOOLS_PATH" "$SHELL_RC" 2>/dev/null; then
        echo "Adding dotnet tools path $DOTNET_TOOLS_PATH to $SHELL_RC for future sessions"
        echo "export PATH=\"$DOTNET_TOOLS_PATH:\$PATH\"" >> "$SHELL_RC"
    fi
fi

# Test ikon command
echo "Testing ikon tool installation..."
if ! ikon version; then
    echo -e "${RED}Error: ikon tool has not been installed correctly${NC}"
    exit 1
fi

# Only show PATH instructions if not sourced and PATH wasn't already configured
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] && [[ "$PATH_ALREADY_CONFIGURED" == "false" ]]; then
    echo "To use ikon tool in this terminal session, run:"
    echo -e "${YELLOW}export PATH=\"$DOTNET_TOOLS_PATH:\$PATH\"${NC}"
    echo "Or restart your terminal to pick up the PATH changes automatically."
fi

echo "Next step, to login to the ikon backend, run:"
echo -e "${YELLOW}ikon login${NC}"
