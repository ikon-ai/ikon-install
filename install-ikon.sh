#!/usr/bin/env bash

# bash <(curl -fsSL https://ikon.live/install.sh)

DOTNET_SDK_MAJOR="10"
NODE_MAJOR="24"
NODE_VERSION="24.14.0"

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
    echo -e "  2. Check for and install Node.js ${NODE_MAJOR} (if not present or outdated)"
    echo -e "  3. Check for and install Git (if not present)"
    echo -e "  4. Install the Ikon command-line tool"
    echo -e "  5. Trust HTTPS development certificates for localhost"
    echo
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${YELLOW}Installation methods (macOS):${NC}"
        echo -e "  - Xcode Command Line Tools (for git)"
        echo -e "  - Official .pkg installers (for .NET SDK and Node.js)"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo -e "${YELLOW}Installation methods (Linux):${NC}"
        echo -e "  - apt-get (if available)"
        echo -e "  - Official .NET install script (fallback)"
    fi
    echo
    echo -e "${YELLOW}Note: Administrator privileges (sudo) may be required for some installations.${NC}"
    echo
    
    read -p "Do you want to continue? (y/n) " -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installation cancelled by user.${NC}"
        exit 0
    fi
    echo
fi

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
        echo "Please download and install .NET SDK ${DOTNET_SDK_MAJOR} from:"
        if [[ "$(uname -m)" == "arm64" ]]; then
            echo "https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.101/dotnet-sdk-10.0.101-osx-arm64.pkg"
        else
            echo "https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.101/dotnet-sdk-10.0.101-osx-x64.pkg"
        fi
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
            echo -e "${YELLOW}Installing .NET SDK ${DOTNET_SDK_MAJOR} via official installer...${NC}"

            local dotnet_pkg_url
            if [[ "$(uname -m)" == "arm64" ]]; then
                dotnet_pkg_url="https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.101/dotnet-sdk-10.0.101-osx-arm64.pkg"
            else
                dotnet_pkg_url="https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.101/dotnet-sdk-10.0.101-osx-x64.pkg"
            fi

            local dotnet_pkg="/tmp/dotnet-sdk.pkg"
            echo -e "${YELLOW}Downloading .NET SDK installer...${NC}"
            if ! curl -fsSL -o "$dotnet_pkg" "$dotnet_pkg_url"; then
                echo -e "${RED}Failed to download .NET SDK installer${NC}"
                print_dotnet_install_instructions
                return 1
            fi

            echo -e "${YELLOW}Installing .NET SDK (requires administrator privileges)...${NC}"
            if sudo installer -pkg "$dotnet_pkg" -target /; then
                echo -e "${GREEN}.NET SDK has been installed successfully!${NC}"
                rm -f "$dotnet_pkg"

                # Add dotnet to PATH for current session (pkg installs to /usr/local/share/dotnet)
                export PATH="/usr/local/share/dotnet:$PATH"
                export DOTNET_ROOT="/usr/local/share/dotnet"

                if ! command -v dotnet &> /dev/null; then
                    echo -e "${YELLOW}Please restart your terminal and run this script again to complete the Ikon tool installation.${NC}"
                    return 1
                fi
            else
                echo -e "${RED}Failed to install .NET SDK${NC}"
                rm -f "$dotnet_pkg"
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
    local shell_rc="$1"
    local needs_install=false
    
    # Check if node exists and get version
    if command -v node &> /dev/null; then
        local node_current
        node_current="$(node --version 2>/dev/null || echo "v0.0.0")"
        # Remove 'v' prefix and get major version
        MAJOR_VERSION="$(echo "$node_current" | sed 's/^v//' | cut -d'.' -f1)"

        if [ "$MAJOR_VERSION" -lt "$NODE_MAJOR" ]; then
            echo -e "${YELLOW}Node.js version $node_current found, but version ${NODE_MAJOR} or higher is required${NC}"
            needs_install=true
        else
            echo -e "${GREEN}Node.js $node_current is already installed${NC}"
            return 0
        fi
    else
        needs_install=true
    fi
    
    if [[ "$needs_install" == "true" ]]; then
        # Warn if a version manager is detected
        local version_manager=""
        if [ -n "$NVM_DIR" ]; then
            version_manager="nvm"
        elif command -v fnm &> /dev/null; then
            version_manager="fnm"
        elif command -v volta &> /dev/null; then
            version_manager="volta"
        fi

        if [ -n "$version_manager" ]; then
            echo -e "${YELLOW}Warning: Node.js appears to be managed by ${version_manager}.${NC}"
            echo -e "${YELLOW}Installing Node ${NODE_MAJOR} via system package may not override it.${NC}"
            if [ "$version_manager" = "nvm" ]; then
                echo -e "${YELLOW}Consider running: nvm install ${NODE_MAJOR} && nvm alias default ${NODE_MAJOR}${NC}"
            elif [ "$version_manager" = "fnm" ]; then
                echo -e "${YELLOW}Consider running: fnm install ${NODE_MAJOR} && fnm default ${NODE_MAJOR}${NC}"
            elif [ "$version_manager" = "volta" ]; then
                echo -e "${YELLOW}Consider running: volta install node@${NODE_MAJOR}${NC}"
            fi
        fi

        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command -v apt-get &> /dev/null; then
                echo -e "${YELLOW}Installing Node.js ${NODE_MAJOR}...${NC}"
                # Install specific major version from NodeSource repository
                if curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | sudo -E bash - && \
                   sudo apt-get install -y nodejs; then
                    hash -r
                    echo -e "${GREEN}Node.js installed successfully!${NC}"
                else
                    echo -e "${RED}Failed to install Node.js${NC}"
                    return 1
                fi
            else
                echo -e "${RED}Node.js is not installed. Please install Node.js ${NODE_MAJOR} or higher for your distribution.${NC}"
                return 1
            fi
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            echo -e "${YELLOW}Installing Node.js ${NODE_MAJOR} via official installer...${NC}"

            local node_pkg_url="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}.pkg"
            local node_pkg="/tmp/node.pkg"

            echo -e "${YELLOW}Downloading Node.js installer...${NC}"
            if ! curl -fsSL -o "$node_pkg" "$node_pkg_url"; then
                echo -e "${RED}Failed to download Node.js installer${NC}"
                echo -e "${YELLOW}Please download and install Node.js ${NODE_MAJOR} from: https://nodejs.org/${NC}"
                return 1
            fi

            echo -e "${YELLOW}Installing Node.js (requires administrator privileges)...${NC}"
            if sudo installer -pkg "$node_pkg" -target /; then
                hash -r
                echo -e "${GREEN}Node.js installed successfully!${NC}"
                rm -f "$node_pkg"

                # Ensure the new binary is in PATH for the current session
                if [ -d "/usr/local/bin" ] && [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
                    export PATH="/usr/local/bin:$PATH"
                fi
            else
                echo -e "${RED}Failed to install Node.js${NC}"
                rm -f "$node_pkg"
                echo -e "${YELLOW}Please download and install Node.js ${NODE_MAJOR} from: https://nodejs.org/${NC}"
                return 1
            fi
        else
            echo -e "${RED}Node.js is not installed. Please install Node.js ${NODE_MAJOR} or higher for your OS.${NC}"
            return 1
        fi

        # Verify the installed version is sufficient
        # Check known system binary paths first, since version managers may shadow `node`
        local system_node=""
        if [[ "$OSTYPE" == "linux-gnu"* ]] && [ -x "/usr/bin/node" ]; then
            system_node="/usr/bin/node"
        elif [[ "$OSTYPE" == "darwin"* ]] && [ -x "/usr/local/bin/node" ]; then
            system_node="/usr/local/bin/node"
        fi

        local post_install_version
        local post_install_major
        if [ -n "$system_node" ]; then
            post_install_version="$("$system_node" --version 2>/dev/null || echo "v0.0.0")"
        else
            post_install_version="$(node --version 2>/dev/null || echo "v0.0.0")"
        fi
        post_install_major="$(echo "$post_install_version" | sed 's/^v//' | cut -d'.' -f1)"

        if [ "$post_install_major" -lt "$NODE_MAJOR" ]; then
            echo -e "${RED}Error: Node.js ${NODE_MAJOR} installation failed — $post_install_version found at ${system_node:-node}${NC}"
            return 1
        fi

        # Check if `node` still resolves to an older version (version manager override)
        local active_version
        active_version="$(node --version 2>/dev/null || echo "v0.0.0")"
        local active_major
        active_major="$(echo "$active_version" | sed 's/^v//' | cut -d'.' -f1)"
        if [ "$active_major" -lt "$NODE_MAJOR" ] && [ -n "$version_manager" ]; then
            echo -e "${YELLOW}Warning: Node.js ${NODE_MAJOR} was installed to ${system_node}, but ${version_manager} is providing $active_version as the active version.${NC}"
            if [ "$version_manager" = "nvm" ]; then
                echo -e "${YELLOW}Consider running: nvm install ${NODE_MAJOR} && nvm alias default ${NODE_MAJOR}${NC}"
            elif [ "$version_manager" = "fnm" ]; then
                echo -e "${YELLOW}Consider running: fnm install ${NODE_MAJOR} && fnm default ${NODE_MAJOR}${NC}"
            elif [ "$version_manager" = "volta" ]; then
                echo -e "${YELLOW}Consider running: volta install node@${NODE_MAJOR}${NC}"
            fi
        fi
    fi
    return 0
}

install_git_if_needed() {
    if ! git --version &> /dev/null; then
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
            echo -e "${YELLOW}Installing Xcode Command Line Tools (includes git)...${NC}"
            echo -e "${YELLOW}A dialog will appear - please click 'Install' to continue.${NC}"

            xcode-select --install 2>/dev/null || true

            # Wait for git to become available (polling)
            echo -e "${YELLOW}Waiting for installation to complete...${NC}"
            local max_wait=600  # 10 minutes max
            local waited=0
            while ! git --version &> /dev/null; do
                if [ $waited -ge $max_wait ]; then
                    echo -e "${RED}Timed out waiting for Xcode Command Line Tools installation.${NC}"
                    echo -e "${YELLOW}Please complete the installation manually and run this script again.${NC}"
                    return 1
                fi
                sleep 5
                waited=$((waited + 5))
            done
            echo -e "${GREEN}git installed successfully!${NC}"
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

install_dotnet_if_needed "$SHELL_RC" || exit 1
install_node_if_needed "$SHELL_RC" || exit 1
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

# Check node version (final verification after installation)
# Check known system paths first, then fall back to `node` in PATH
SYSTEM_NODE=""
if [[ "$OSTYPE" == "linux-gnu"* ]] && [ -x "/usr/bin/node" ]; then
    SYSTEM_NODE="/usr/bin/node"
elif [[ "$OSTYPE" == "darwin"* ]] && [ -x "/usr/local/bin/node" ]; then
    SYSTEM_NODE="/usr/local/bin/node"
fi

NODE_CURRENT="$(node --version 2>/dev/null || echo "v0.0.0")"
NODE_INSTALLED_MAJOR="$(echo "$NODE_CURRENT" | sed 's/^v//' | cut -d'.' -f1)"

if [ "$NODE_INSTALLED_MAJOR" -lt "$NODE_MAJOR" ]; then
    # Active `node` is too old — check if the system-installed binary has the right version
    if [ -n "$SYSTEM_NODE" ]; then
        SYSTEM_NODE_VERSION="$("$SYSTEM_NODE" --version 2>/dev/null || echo "v0.0.0")"
        SYSTEM_NODE_MAJOR="$(echo "$SYSTEM_NODE_VERSION" | sed 's/^v//' | cut -d'.' -f1)"
        if [ "$SYSTEM_NODE_MAJOR" -ge "$NODE_MAJOR" ]; then
            echo -e "${YELLOW}Warning: Node.js ${NODE_MAJOR} is installed at ${SYSTEM_NODE} ($SYSTEM_NODE_VERSION), but $NODE_CURRENT is the active version in PATH.${NC}"
            if [ -n "$NVM_DIR" ]; then
                echo "You appear to be using nvm. Run: nvm install ${NODE_MAJOR} && nvm alias default ${NODE_MAJOR}"
            elif command -v fnm &> /dev/null; then
                echo "You appear to be using fnm. Run: fnm install ${NODE_MAJOR} && fnm default ${NODE_MAJOR}"
            elif command -v volta &> /dev/null; then
                echo "You appear to be using volta. Run: volta install node@${NODE_MAJOR}"
            fi
        else
            echo -e "${RED}Error: Node.js ${NODE_MAJOR} or higher is required but $NODE_CURRENT is active${NC}"
            echo "Please install Node.js ${NODE_MAJOR} and ensure it is first in your PATH."
            exit 1
        fi
    else
        echo -e "${RED}Error: Node.js ${NODE_MAJOR} or higher is required but $NODE_CURRENT is active${NC}"
        if [ -n "$NVM_DIR" ]; then
            echo "You appear to be using nvm. Run: nvm install ${NODE_MAJOR} && nvm alias default ${NODE_MAJOR}"
        elif command -v fnm &> /dev/null; then
            echo "You appear to be using fnm. Run: fnm install ${NODE_MAJOR} && fnm default ${NODE_MAJOR}"
        elif command -v volta &> /dev/null; then
            echo "You appear to be using volta. Run: volta install node@${NODE_MAJOR}"
        else
            echo "Please install Node.js ${NODE_MAJOR} and ensure it is first in your PATH."
        fi
        exit 1
    fi
fi

DOTNET_TOOLS_PATH="$HOME/.dotnet/tools"

# Ensure tools are available inside this script
export PATH="$PATH:$DOTNET_TOOLS_PATH"

# Silently uninstall other ikon tool packages if they exist
dotnet tool uninstall IkonTool --global >/dev/null 2>&1 || true
dotnet tool uninstall ikon-internal --global >/dev/null 2>&1 || true

# Install Ikon tool globally
echo "Installing Ikon tool..."
if ! dotnet tool install ikon --global --no-http-cache; then
    echo -e "${RED}Error: Failed to install Ikon tool${NC}"
    exit 1
fi

# Persist tools path for future terminals
if ! grep -q '\$HOME/.dotnet/tools' "$SHELL_RC" 2>/dev/null; then
    echo "Adding dotnet tools path $DOTNET_TOOLS_PATH to $SHELL_RC for future sessions"
    echo 'export PATH="$PATH:$HOME/.dotnet/tools"' >> "$SHELL_RC"
fi

echo "Resetting Ikon tool data..."
IKON_RESET_CONFIRM=true ikon --reset

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
