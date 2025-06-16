#!/bin/bash

# curl -sSL https://ikon.live/install.sh | bash

set -e

RED='\033[0;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Checking pre-requisites for ikon tool installation..."

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
}

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

# Install ikon tool globally
echo "Installing ikon tool..."
if ! dotnet tool install IkonTool -g; then
    echo -e "${RED}Error: Failed to install ikon tool${NC}"
    exit 1
fi

# Determine the dotnet tools path
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    DOTNET_TOOLS_PATH="$HOME/.dotnet/tools"
    SHELL_RC="$HOME/.zshrc"
    if [ -f "$HOME/.bash_profile" ]; then
        SHELL_RC="$HOME/.bash_profile"
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    DOTNET_TOOLS_PATH="$HOME/.dotnet/tools"
    SHELL_RC="$HOME/.bashrc"
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    fi
else
    echo -e "${YELLOW}Warning: Unknown OS type, using default path${NC}"
    DOTNET_TOOLS_PATH="$HOME/.dotnet/tools"
    SHELL_RC="$HOME/.bashrc"
fi

# Add to PATH for current session
export PATH="$DOTNET_TOOLS_PATH:$PATH"

# Add to shell configuration file for future sessions
if ! grep -q "$DOTNET_TOOLS_PATH" "$SHELL_RC" 2>/dev/null; then
    echo "export PATH=\"$DOTNET_TOOLS_PATH:\$PATH\"" >> "$SHELL_RC"
fi

# Check if ikon command is available
if ! command -v ikon &> /dev/null; then
    echo -e "${RED}Error: ikon command not found in PATH${NC}"
    echo "Please restart your terminal and try again"
    exit 1
fi

# Test ikon version command
echo "Testing ikon tool installation..."
if ! ikon version; then
    echo -e "${RED}Error: ikon tool has not been installed correctly${NC}"
    exit 1
fi

echo -e "${GREEN}Installation completed successfully!${NC}"
echo "Next step: Run 'ikon login' command to login to the backend"
