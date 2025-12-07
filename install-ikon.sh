#!/usr/bin/env bash

# bash <(curl -fsSL https://ikon.live/install.sh)

DOTNET_SDK_MAJOR="10"

set -e

RED='\033[0;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SKIP_CONFIRMATION=false
if [[ "$CI" == "true" ]]; then
    SKIP_CONFIRMATION=true
fi
for arg in "$@"; do
    if [[ "$arg" == "--yes" ]] || [[ "$arg" == "-y" ]]; then
        SKIP_CONFIRMATION=true
        break
    fi
done

if [[ "$SKIP_CONFIRMATION" != "true" ]]; then
    echo
    echo -e "${CYAN}====================================================================${NC}"
    echo -e "${CYAN}              Ikon Tool Installation Script${NC}"
    echo -e "${CYAN}====================================================================${NC}"
    echo
    echo -e "${YELLOW}This script will:${NC}"
    echo -e "  1. Check for and install .NET SDK ${DOTNET_SDK_MAJOR} (if not present or outdated)"
    echo -e "  2. Check for and install Node.js (if not present)"
    echo -e "  3. Check for and install Git (if not present)"
    echo -e "  4. Install the Ikon command-line tool"
    echo -e "  5. Trust HTTPS development certificates for localhost"
    echo
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${YELLOW}Installation methods (macOS):${NC}"
        echo -e "  - Homebrew (will be installed if not present)"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo -e "${YELLOW}Installation methods (Linux):${NC}"
        echo -e "  - apt-get (if available)"
        echo -e "  - Official .NET install script (fallback)"
    fi
    echo
    echo -e "${YELLOW}Note: Administrator privileges (sudo) may be required for some installations.${NC}"
    echo
    
    read -p "Do you want to continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installation cancelled by user.${NC}"
        exit 0
    fi
    echo
fi

install_homebrew_if_needed() {
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}Homebrew not found. Installing Homebrew...${NC}"
        if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
            echo -e "${GREEN}Homebrew installed successfully!${NC}"
            
            # Add Homebrew to PATH for this session
            if [[ "$(uname -m)" == "arm64" ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            else
                eval "$(/usr/local/bin/brew shellenv)"
            fi
            
            if ! command -v brew &> /dev/null; then
                echo -e "${YELLOW}Please restart your terminal and run this script again.${NC}"
                return 1
            fi
        else
            echo -e "${RED}Failed to install Homebrew${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}Homebrew is already installed${NC}"
    fi

    echo -e "${YELLOW}Updating Homebrew...${NC}"
    if brew update --auto-update; then
        echo -e "${GREEN}Homebrew updated successfully!${NC}"
    else
        echo -e "${RED}Homebrew update failed${NC}"
        return 1
    fi

    return 0
}

print_dotnet_install_instructions() {
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
        echo "Please install .NET SDK ${DOTNET_SDK_MAJOR} with Homebrew:"
        echo "brew install --cask dotnet-sdk"
    else
        echo "Please install .NET SDK ${DOTNET_SDK_MAJOR} from: https://dotnet.microsoft.com/en-us/download/dotnet/${DOTNET_SDK_MAJOR}.0"
    fi
    echo
    echo "And then restart your terminal and run this script again!"
}

install_dotnet_via_script() {
    local shell_rc="$1"

    echo -e "${YELLOW}Falling back to official .NET install script...${NC}"

    local dotnet_root="$HOME/.dotnet"
    mkdir -p "$dotnet_root"

    local install_script
    install_script="$(mktemp)"

    if ! curl -L https://dot.net/v1/dotnet-install.sh -o "$install_script"; then
        echo -e "${RED}Failed to download .NET install script${NC}"
        print_dotnet_install_instructions
        return 1
    fi

    chmod +x "$install_script"

    if ! "$install_script" --channel "${DOTNET_SDK_MAJOR}.0" --install-dir "$dotnet_root"; then
        echo -e "${RED}Failed to install .NET SDK using official install script${NC}"
        print_dotnet_install_instructions
        return 1
    fi

    export PATH="$dotnet_root:$PATH"
    export DOTNET_ROOT="$dotnet_root"

    echo 'export DOTNET_ROOT="$HOME/.dotnet"' >> "$shell_rc"
    echo 'export PATH="$PATH:$HOME/.dotnet"' >> "$shell_rc"

    echo -e "${GREEN}.NET SDK ${DOTNET_SDK_MAJOR} has been installed using the official install script!${NC}"
    return 0
}

install_dotnet_if_needed() {
    local shell_rc="$1"
    local needs_install=false
    
    # Check if dotnet exists and get version
    if command -v dotnet &> /dev/null; then
        DOTNET_VERSION="$(dotnet --version 2>/dev/null || echo "0.0.0")"
        MAJOR_VERSION="$(echo "$DOTNET_VERSION" | cut -d'.' -f1)"
        
        if [ "$MAJOR_VERSION" -lt "$DOTNET_SDK_MAJOR" ]; then
            echo -e "${YELLOW}.NET SDK version $DOTNET_VERSION found, but version ${DOTNET_SDK_MAJOR} or higher is required${NC}"
            needs_install=true
        else
            echo -e "${GREEN}.NET SDK $DOTNET_VERSION is already installed${NC}"
            return 0
        fi
    else
        needs_install=true
    fi
    
    if [[ "$needs_install" == "true" ]]; then
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command -v apt-get &> /dev/null; then
                echo -e "${YELLOW}Installing .NET SDK ${DOTNET_SDK_MAJOR}...${NC}"

                if sudo apt-get update && sudo apt-get install -y dotnet-sdk-${DOTNET_SDK_MAJOR}.0; then
                    echo -e "${GREEN}.NET SDK ${DOTNET_SDK_MAJOR} has been installed successfully!${NC}"

                    if ! command -v dotnet &> /dev/null; then
                        echo -e "${YELLOW}Please restart your terminal and run this script again to complete the Ikon tool installation.${NC}"
                        return 1
                    fi
                else
                    echo -e "${YELLOW}Failed to install .NET SDK via apt-get, trying official install script...${NC}"
                    if ! install_dotnet_via_script "$shell_rc"; then
                        return 1
                    fi
                fi
            else
                echo -e "${YELLOW}apt-get not available, trying official install script...${NC}"
                if ! install_dotnet_via_script "$shell_rc"; then
                    return 1
                fi
            fi
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            echo -e "${YELLOW}Installing .NET SDK via Homebrew...${NC}"
            
            if brew install --cask dotnet-sdk; then
                echo -e "${GREEN}.NET SDK has been installed successfully!${NC}"
                
                if ! command -v dotnet &> /dev/null; then
                    echo -e "${YELLOW}Please restart your terminal and run this script again to complete the Ikon tool installation.${NC}"
                    return 1
                fi
            else
                echo -e "${RED}Failed to install .NET SDK via Homebrew${NC}"
                print_dotnet_install_instructions
                return 1
            fi
        else
            # Other OS
            echo -e "${RED}.NET SDK is not installed${NC}"
            print_dotnet_install_instructions
            return 1
        fi
    fi
    return 0
}

install_node_if_needed() {
    if ! command -v node &> /dev/null; then
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command -v apt-get &> /dev/null; then
                echo -e "${YELLOW}Installing Node.js LTS...${NC}"
                # Install from NodeSource repository for latest LTS
                if curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && \
                   sudo apt-get install -y nodejs; then
                    echo -e "${GREEN}Node.js installed successfully!${NC}"
                else
                    echo -e "${RED}Failed to install Node.js${NC}"
                    return 1
                fi
            else
                echo -e "${RED}Node.js is not installed. Please install Node.js for your distribution.${NC}"
                return 1
            fi
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            echo -e "${YELLOW}Installing Node.js LTS via Homebrew...${NC}"
            if brew install node; then
                echo -e "${GREEN}Node.js installed successfully!${NC}"
            else
                echo -e "${RED}Failed to install Node.js${NC}"
                return 1
            fi
        else
            echo -e "${RED}Node.js is not installed. Please install Node.js for your OS.${NC}"
            return 1
        fi
    else
        NODE_VERSION="$(node --version)"
        echo -e "${GREEN}Node.js $NODE_VERSION is already installed${NC}"
    fi
    return 0
}

install_git_if_needed() {
    if ! command -v git &> /dev/null; then
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command -v apt-get &> /dev/null; then
                echo -e "${YELLOW}Installing git...${NC}"
                if sudo apt-get update && sudo apt-get install -y git; then
                    echo -e "${GREEN}git installed successfully!${NC}"
                else
                    echo -e "${RED}Failed to install git${NC}"
                    return 1
                fi
            else
                echo -e "${RED}git is not installed. Please install git for your distribution.${NC}"
                return 1
            fi
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            echo -e "${YELLOW}Installing git via Homebrew...${NC}"
            if brew install git; then
                echo -e "${GREEN}git installed successfully!${NC}"
            else
                echo -e "${RED}Failed to install git${NC}"
                return 1
            fi
        else
            echo -e "${RED}git is not installed. Please install git for your OS.${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}git is already installed${NC}"
    fi
    return 0
}

detect_shell_rc() {
    # Determine shell config file for adding PATH changes
    local current_shell="${SHELL##*/}"
    local shell_rc=""

    case "$current_shell" in
        zsh)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                shell_rc="$HOME/.zprofile"
            else
                shell_rc="$HOME/.zshrc"
            fi
            ;;
        bash)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                if [[ -f "$HOME/.bash_profile" ]]; then
                    shell_rc="$HOME/.bash_profile"
                else
                    shell_rc="$HOME/.bashrc"
                fi
            else
                shell_rc="$HOME/.bashrc"
            fi
            ;;
        *)
            # Fallback: try detected versions, then .profile
            if [[ -n "$ZSH_VERSION" ]]; then
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    shell_rc="$HOME/.zprofile"
                else
                    shell_rc="$HOME/.zshrc"
                fi
            elif [[ -n "$BASH_VERSION" ]]; then
                shell_rc="$HOME/.bashrc"
            else
                shell_rc="$HOME/.profile"
            fi
            ;;
    esac

    mkdir -p "$(dirname "$shell_rc")" 2>/dev/null || true
    touch "$shell_rc" 2>/dev/null || true
    echo "$shell_rc"
}

echo "Checking pre-requisites for Ikon tool installation..."

SHELL_RC="$(detect_shell_rc)"
SHELL_NAME="${SHELL##*/}"

if [[ "$OSTYPE" == "darwin"* ]]; then
    install_homebrew_if_needed || exit 1
fi

install_dotnet_if_needed "$SHELL_RC" || exit 1
install_node_if_needed || exit 1
install_git_if_needed || exit 1

# Check dotnet version (final verification after installation)
DOTNET_VERSION="$(dotnet --version)"
MAJOR_VERSION="$(echo "$DOTNET_VERSION" | cut -d'.' -f1)"

if [ "$MAJOR_VERSION" -lt "$DOTNET_SDK_MAJOR" ]; then
    echo -e "${RED}Error: .NET SDK version ${DOTNET_SDK_MAJOR} or higher is required${NC}"
    echo "Current version: $DOTNET_VERSION"
    print_dotnet_install_instructions
    exit 1
fi

DOTNET_TOOLS_PATH="$HOME/.dotnet/tools"

# Ensure tools are available inside this script
export PATH="$PATH:$DOTNET_TOOLS_PATH"

# Silently uninstall other ikon tool packages if they exist
dotnet tool uninstall IkonTool -g >/dev/null 2>&1 || true
dotnet tool uninstall ikon-internal -g >/dev/null 2>&1 || true

# Install Ikon tool globally
echo "Installing Ikon tool..."
if ! dotnet tool install ikon -g; then
    echo -e "${RED}Error: Failed to install Ikon tool${NC}"
    exit 1
fi

# Persist tools path for future terminals
if ! grep -q '\$HOME/.dotnet/tools' "$SHELL_RC" 2>/dev/null; then
    echo "Adding dotnet tools path $DOTNET_TOOLS_PATH to $SHELL_RC for future sessions"
    echo 'export PATH="$PATH:$HOME/.dotnet/tools"' >> "$SHELL_RC"
fi

echo "Testing Ikon tool installation..."
if ! ikon version; then
    echo -e "${RED}Error: Ikon tool has not been installed correctly${NC}"
    exit 1
fi

echo "Trusting HTTPS development certificates for localhost..."
if [[ "$CI" == "true" ]]; then
    if ! dotnet dev-certs https; then
        echo -e "${YELLOW}Warning: Failed to generate HTTPS development certificates${NC}"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    if ! dotnet dev-certs https --trust; then
        echo -e "${YELLOW}Warning: Failed to trust HTTPS development certificates${NC}"
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Generating HTTPS development certificate (per-user)..."
    if ! dotnet dev-certs https; then
        echo -e "${YELLOW}Warning: Failed to generate HTTPS development certificates${NC}"
    else
        tmp_cert="$(mktemp)"
        if dotnet dev-certs https -ep "$tmp_cert" --format PEM; then
            echo "Installing HTTPS development certificate into Ubuntu trust store (requires sudo)..."
            if sudo mkdir -p /usr/local/share/ca-certificates/aspnet && \
               sudo cp "$tmp_cert" /usr/local/share/ca-certificates/aspnet/ikon-https-dev.crt && \
               sudo update-ca-certificates; then
                echo -e "${GREEN}HTTPS development certificate trusted by system CA store.${NC}"
            else
                echo -e "${YELLOW}Warning: Failed to install HTTPS development certificate into system trust store${NC}"
            fi
        else
            echo -e "${YELLOW}Warning: Failed to export HTTPS development certificate for trust installation${NC}"
        fi
        rm -f "$tmp_cert"
    fi
else
    echo -e "${YELLOW}Warning: Unsupported OS for HTTPS certificate trust${NC}"
fi

echo
echo -e "${GREEN}Ikon tool installation completed.${NC}"
echo
echo "IMPORTANT:"
echo "  1) Close this terminal window (or log out) and open a NEW terminal."
echo "  2) In the new terminal, run the following command to sign in:"
echo
echo -e "     ${YELLOW}ikon login${NC}"
echo
echo "The Ikon tool will only work after you have opened a new terminal session."
