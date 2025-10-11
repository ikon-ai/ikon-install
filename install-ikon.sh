#!/usr/bin/env bash

# Ikon Tool Installer
#
# Installation methods:
# 1. Direct execution (requires terminal restart or manual PATH update):
#    bash <(curl -sSL https://ikon.live/install.sh)
#
# 2. Source to get immediate PATH updates in current terminal:
#    source <(curl -sSL https://ikon.live/install.sh)
#    Note: Sourcing will update your current shell's PATH automatically

# .NET SDK version configuration
DOTNET_SDK_VERSION="8.0.414"
DOTNET_SDK_MAJOR="8"

# Detect if being sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    SOURCED=true
    # Disable set -e when sourced to prevent closing user's terminal on errors
    set +e
else
    SOURCED=false
    set -e
fi

# Safe exit function that works whether sourced or executed
script_exit() {
    local exit_code=$1
    if [[ "$SOURCED" == "true" ]]; then
        return $exit_code
    else
        exit $exit_code
    fi
}

RED='\033[0;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

get_dotnet_install_instructions() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            echo "Please install .NET SDK ${DOTNET_SDK_MAJOR} with following command:"
            echo "sudo apt-get update && sudo apt-get install -y dotnet-sdk-${DOTNET_SDK_MAJOR}.0"
            echo
            echo "More instructions at: https://learn.microsoft.com/en-us/dotnet/core/install/linux?WT.mc_id=dotnet-35129-website"
        else
            echo "Please install .NET SDK ${DOTNET_SDK_MAJOR} - check instructions for your distribution at:"
            echo "https://learn.microsoft.com/en-us/dotnet/core/install/linux?WT.mc_id=dotnet-35129-website"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ $(uname -m) == "arm64" ]]; then
            echo "Please install .NET SDK ${DOTNET_SDK_MAJOR} from: https://dotnet.microsoft.com/en-us/download/dotnet/thank-you/sdk-${DOTNET_SDK_VERSION}-macos-arm64-installer"
        else
            echo "Please install .NET SDK ${DOTNET_SDK_MAJOR} from: https://dotnet.microsoft.com/en-us/download/dotnet/thank-you/sdk-${DOTNET_SDK_VERSION}-macos-x64-installer"
        fi
    else
        echo "Please install .NET SDK ${DOTNET_SDK_MAJOR} from: https://dotnet.microsoft.com/en-us/download/dotnet/${DOTNET_SDK_MAJOR}.0"
    fi
    echo
    echo "And then restart your terminal and run this script again!"
}

echo "Checking pre-requisites for Ikon tool installation..."

# Check if dotnet is installed
if ! command -v dotnet &> /dev/null; then
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            echo -e "${YELLOW}Installing .NET SDK ${DOTNET_SDK_MAJOR}...${NC}"

            if sudo apt-get update && sudo apt-get install -y dotnet-sdk-${DOTNET_SDK_MAJOR}.0; then
                echo -e "${GREEN}.NET SDK ${DOTNET_SDK_MAJOR} has been installed successfully!${NC}"

                if ! command -v dotnet &> /dev/null; then
                    echo -e "${YELLOW}Please restart your terminal and run this script again to complete the Ikon tool installation.${NC}"
                    script_exit 0
                fi
            else
                echo -e "${RED}Failed to install .NET SDK via apt-get${NC}"
                get_dotnet_install_instructions
                script_exit 1
            fi
        else
            echo -e "${RED}.NET SDK is not installed${NC}"
            get_dotnet_install_instructions
            script_exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${YELLOW}Downloading .NET SDK ${DOTNET_SDK_MAJOR} installer...${NC}"
        TEMP_DIR=$(mktemp -d)
        trap 'rm -rf "$TEMP_DIR"' EXIT INT TERM

        if [[ $(uname -m) == "arm64" ]]; then
            DOTNET_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-osx-arm64.pkg"
            INSTALLER_PATH="$TEMP_DIR/dotnet-sdk-${DOTNET_SDK_MAJOR}-arm64.pkg"
        else
            DOTNET_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-osx-x64.pkg"
            INSTALLER_PATH="$TEMP_DIR/dotnet-sdk-${DOTNET_SDK_MAJOR}-x64.pkg"
        fi
        
        if curl -sSL "$DOTNET_URL" -o "$INSTALLER_PATH"; then
            echo -e "${YELLOW}Download complete. Running installer...${NC}"
            
            if sudo installer -pkg "$INSTALLER_PATH" -target /; then
                echo -e "${GREEN}.NET SDK ${DOTNET_SDK_MAJOR} has been installed successfully!${NC}"
                rm -rf "$TEMP_DIR"
                
                if ! command -v dotnet &> /dev/null; then
                    echo -e "${YELLOW}Please restart your terminal and run this script again to complete the Ikon tool installation.${NC}"
                    script_exit 0
                fi
            else
                echo -e "${RED}Failed to run the installer${NC}"
                rm -rf "$TEMP_DIR"
                get_dotnet_install_instructions
                script_exit 1
            fi
        else
            echo -e "${RED}Failed to download the installer${NC}"
            rm -rf "$TEMP_DIR"
            get_dotnet_install_instructions
            script_exit 1
        fi
    else
        # Other OS
        echo -e "${RED}.NET SDK is not installed${NC}"
        get_dotnet_install_instructions
        script_exit 1
    fi
fi

# Check dotnet version
DOTNET_VERSION=$(dotnet --version)
MAJOR_VERSION=$(echo "$DOTNET_VERSION" | cut -d'.' -f1)

if [ "$MAJOR_VERSION" -lt "$DOTNET_SDK_MAJOR" ]; then
    echo -e "${RED}Error: .NET SDK version ${DOTNET_SDK_MAJOR} or higher is required${NC}"
    echo "Current version: $DOTNET_VERSION"
    get_dotnet_install_instructions
    script_exit 1
fi

echo -e "${GREEN}.NET SDK $DOTNET_VERSION found${NC}"

# Determine the dotnet tools path
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    DOTNET_TOOLS_PATH="$HOME/.dotnet/tools"
    SHELL_RC="$HOME/.bashrc"
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    DOTNET_TOOLS_PATH="$HOME/.dotnet/tools"
    SHELL_RC="$HOME/.zprofile"
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

# Silently uninstall old IkonTool package if it exists
dotnet tool uninstall IkonTool -g >/dev/null 2>&1 || true

# Install Ikon tool globally
echo "Installing Ikon tool..."
if ! dotnet tool install ikon -g; then
    echo -e "${RED}Error: Failed to install Ikon tool${NC}"
    script_exit 1
fi

# Add to shell configuration file for future sessions (only if not already in PATH or in the config)
if [[ "$PATH_ALREADY_CONFIGURED" == "false" ]]; then
    if ! grep -q "$DOTNET_TOOLS_PATH" "$SHELL_RC" 2>/dev/null; then
        echo "Adding dotnet tools path $DOTNET_TOOLS_PATH to $SHELL_RC for future sessions"
        echo "export PATH=\"$DOTNET_TOOLS_PATH:\$PATH\"" >> "$SHELL_RC"
    fi
fi

echo "Testing Ikon tool installation..."
if ! ikon version; then
    echo -e "${RED}Error: Ikon tool has not been installed correctly${NC}"
    script_exit 1
fi

echo "Trusting development certificates..."
if ! dotnet dev-certs https --trust; then
    echo -e "${YELLOW}Warning: Failed to trust development certificates${NC}"
fi

echo "Next step, to login to the Ikon backend, run:"

if [[ "$SOURCED" == "false" ]] && [[ "$PATH_ALREADY_CONFIGURED" == "false" ]]; then
    echo -e "${YELLOW}export PATH=\"$DOTNET_TOOLS_PATH:\$PATH\"${NC}"
fi

echo -e "${YELLOW}ikon login${NC}"
