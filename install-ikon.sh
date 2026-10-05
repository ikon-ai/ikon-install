#!/usr/bin/env bash
# Ikon tool installer for macOS and Linux
#
#   curl -fsSL https://ikonai.com/install.sh | bash
#   curl -fsSL https://ikonai.com/install.sh | bash -s -- --machine
#
# Checks the .NET SDK, Node.js, Git and the Ikon tool, installs whatever is missing or too old,
# signs you in and reinstalls the Ikon tool packages. Running it again is how to repair an install.
#
# Options:
#   --machine      Install for every user with the system's installers, which needs sudo: apt, dnf,
#                  pacman or zypper on Linux, the official .pkg installers on macOS.
#                  Without it everything goes into your home folder and no sudo is needed, except
#                  for Git on Linux, which only the package manager provides.
#   --format json  One JSON event per line on stdout, everything else on stderr. Never prompts
#                  and never signs in.
#   --check        Only report what is installed.
#   --yes, -y      Do not ask before installing.
#   --no-login     Do not sign in.
#
# Everything below is functions; nothing runs until main is called on the last line, so a download
# that stops halfway runs nothing at all.

set -uo pipefail

# --- Versions -----------------------------------------------------------------------------------------

DOTNET_SDK_MAJOR="10"
DOTNET_SDK_VERSION="10.0.400"
NODE_MAJOR="24"
NODE_VERSION="24.19.0"

# --- Locations of a per-user install ---------------------------------------------------------------

DOTNET_USER_ROOT="$HOME/.dotnet"
NODE_USER_ROOT="$HOME/.local/share/ikon"
DOTNET_TOOLS_DIR="$HOME/.dotnet/tools"

COMPONENTS="dotnet node git ikon"
JSON=false
INTERACTIVE=false
MACHINE=false
CHECK_ONLY=false
IS_MAC=false
LINUX_FAMILY=""
ADDED_PATHS=""
PROBLEM=""
FAILURE=""
LOG=""

main() {
    local yes=false login=true
    if [[ "${CI:-}" == "true" ]]; then
        yes=true
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --machine) MACHINE=true ;;
            --format) shift; [[ "${1:-}" == "json" ]] || usage "--format takes json"; JSON=true ;;
            --format=json) JSON=true ;;
            --check) CHECK_ONLY=true ;;
            --yes|-y) yes=true ;;
            --no-login) login=false ;;
            *) usage "Unknown option '$1'" ;;
        esac
        shift
    done

    setup_output
    detect_platform
    LOG="$(mktemp)"

    # A global.json in the current folder could pin an SDK this machine does not have
    cd "$HOME" || fail "Cannot enter the home folder $HOME"
    export DOTNET_NOLOGO=1
    # .NET's first run would otherwise make the development certificate itself, in the middle of the
    # tool install, asking for the keychain; the certificate step at the end is where that belongs
    export DOTNET_GENERATE_ASPNET_CERTIFICATE=false
    use_user_installs

    # --- Check what is installed ----------------------------------------------------------------

    say ""
    say "Ikon tool installer ($([[ "$MACHINE" == "true" ]] && echo "for every user" || echo "for this user"))" "$CYAN"
    say ""
    detect_all

    if [[ "$CHECK_ONLY" == "true" ]]; then
        finish false
    fi

    local missing="" names="" id
    for id in $COMPONENTS; do
        if [[ "$(status_of "$id")" != "ok" ]]; then
            missing="$missing $id"
            [[ "$id" == "ikon" ]] || names="$names, $(name_of "$id")"
        fi
    done
    missing="${missing# }"
    names="${names#, }"
    [[ "$names" == *", "* ]] && names="${names%, *} and ${names##*, }"
    # shellcheck disable=SC2086 # a word list on purpose: an empty array breaks `set -u` in bash 3.2
    emit "{\"event\":\"plan\",\"install\":$(json_array $missing),\"scope\":\"$([[ "$MACHINE" == "true" ]] && echo machine || echo user)\"}"

    if [[ "$INTERACTIVE" == "true" && "$yes" != "true" ]]; then
        say ""
        local tool="updates"
        [[ "$(status_of ikon)" == "ok" ]] || tool="installs"
        if [[ -n "$names" ]]; then
            say "This installs $names, $tool the Ikon tool and signs you in."
        else
            say "Everything is installed. This $tool the Ikon tool and reinstalls its packages."
        fi
        local reply
        read -r -p "Continue? (y/n) " reply < /dev/tty
        if [[ ! "$reply" =~ ^[Yy] ]]; then
            say "Cancelled" "$YELLOW"
            exit 1
        fi
    fi

    # --- Install the prerequisites ----------------------------------------------------------------

    # Only .NET, which the Ikon tool runs on, stops the run; the rest still installs without Node or Git
    local reason
    for id in dotnet node git; do
        if [[ "$(status_of "$id")" == "ok" ]]; then
            continue
        fi
        step "$id" "start" "Installing $(name_of "$id")..."
        PROBLEM=""
        if "install_$id"; then
            detect "$id"
            reason="$(name_of "$id") is still $(status_of "$id") after installing it. $(version_error "$id")"
        else
            reason="$(name_of "$id") could not be installed${PROBLEM:+: $PROBLEM}"
        fi

        if [[ "$(status_of "$id")" == "ok" ]]; then
            step "$id" "done" "$(name_of "$id") $(version_of "$id") installed"
        elif [[ "$id" == "dotnet" ]]; then
            fail "$reason"
        else
            step "$id" "failed" "$reason"
            FAILURE="${FAILURE:-$reason}"
        fi
    done

    # --- The Ikon tool: update, install, or reinstall ---------------------------------------------

    step ikon "start" "Installing the Ikon tool..."
    install_ikon_tool
    step ikon "done" "Ikon tool $(tool_version ikon) installed"

    # --- The tool packages: reinstalled when they were here already, installed by signing in -----
    # Reinstalling is the repair a re-run is for; packages a sign-in has just installed need none

    local signed_in=false
    if is_signed_in; then
        signed_in=true
        step packages "start" "Reinstalling the Ikon tool packages..."
        # Not fatal: the tool is installed either way, and it reinstalls a broken package itself
        if reinstall_tool_packages; then
            step packages "done" "Ikon tool packages reinstalled"
        else
            step packages "warning" "The Ikon tool packages could not be reinstalled. Run 'ikon self update' to try again"
        fi
    elif [[ "$login" == "true" && "$INTERACTIVE" == "true" ]]; then
        step login "start" "Signing in to Ikon..."
        if ikon --disable-auto-update login < /dev/tty; then
            signed_in=true
            step login "done" "Signed in"
        else
            step login "warning" "Not signed in. Run 'ikon login' later; it installs the Ikon tool packages"
        fi
    else
        step packages "skipped" "The Ikon tool packages install when you sign in with 'ikon login'"
    fi

    # --- HTTPS development certificate for apps run locally ---------------------------------------

    if [[ "$INTERACTIVE" == "true" ]]; then
        trust_dev_certificate
    elif [[ "${CI:-}" == "true" ]]; then
        quietly dotnet dev-certs https || true
    fi

    say ""
    detect_all
    say ""
    if [[ -n "$FAILURE" ]]; then
        say "Not finished: $FAILURE" "$RED"
    else
        say "Done. Open a new terminal to use 'ikon'." "$GREEN"
    fi
    finish "$signed_in"
}

# --- Output: text for people, JSON events for programs ------------------------------------------

setup_output() {
    # Human text goes to fd 3: the terminal normally, stderr with --format json
    if [[ "$JSON" == "true" ]]; then
        exec 3>&2
    else
        exec 3>&1
    fi

    RED="" GREEN="" YELLOW="" CYAN="" GRAY="" NC=""
    if [[ -t 3 ]]; then
        RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' CYAN='\033[0;36m' GRAY='\033[0;90m' NC='\033[0m'
    fi

    # The terminal, not stdin: under `curl | bash` stdin is the script itself
    if [[ "$JSON" != "true" && "${CI:-}" != "true" ]] && (exec < /dev/tty) 2> /dev/null; then
        INTERACTIVE=true
    fi
}

say() {
    printf "%b%s%b\n" "${2:-}" "$1" "${2:+$NC}" >&3
}

emit() {
    if [[ "$JSON" == "true" ]]; then
        printf '%s\n' "$1"
    fi
}

# One step of the install: start, done, skipped, warning or failed. fail() ends the run instead
step() {
    local color
    case "$2" in
        "start") color="$CYAN" ;; "done") color="$GREEN" ;; "skipped") color="$GRAY" ;; "warning") color="$YELLOW" ;; *) color="$RED" ;;
    esac
    emit "{\"event\":\"step\",\"step\":\"$1\",\"state\":\"$2\",\"message\":$(json_str "$3")}"
    say "$3" "$color"
}

# Says why something could not be done, and keeps it for the final result
problem() {
    PROBLEM="$1"
    say "$1" "$RED"
}

fail() {
    say "Error: $1" "$RED"
    emit "{\"event\":\"result\",\"ok\":false,\"message\":$(json_str "$1")}"
    exit 1
}

usage() {
    echo "$1. Options: --machine, --format json, --check, --yes, --no-login" >&2
    exit 2
}

finish() {
    local ok=true components="" id
    for id in $COMPONENTS; do
        [[ "$(status_of "$id")" == "ok" ]] || ok=false
        components="$components,{\"component\":\"$id\",\"version\":$(json_str "$(version_of "$id")"),\"status\":\"$(status_of "$id")\"}"
    done
    # shellcheck disable=SC2086 # a word list on purpose, as in main
    emit "{\"event\":\"result\",\"ok\":$ok,\"signedIn\":$1,\"components\":[${components#,}],\"paths\":$(json_array $ADDED_PATHS),\"message\":$(json_str "$FAILURE")}"
    [[ "$ok" == "true" ]] && rm -f "$LOG"
    [[ "$ok" == "true" ]] && exit 0 || exit 1
}

json_str() {
    if [[ -z "$1" ]]; then
        printf 'null'
        return
    fi
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\t'/ }"
    s="${s//$'\r'/}"
    s="${s//$'\n'/ }"
    printf '"%s"' "$s"
}

json_array() {
    local out="" item
    for item in "$@"; do
        out="$out,$(json_str "$item")"
    done
    printf '[%s]' "${out#,}"
}

# Runs a program; with --format json its output goes to stderr, so stdout carries nothing but events
run() {
    if [[ "$JSON" == "true" ]]; then
        "$@" >&2
    else
        "$@"
    fi
}

# Runs an installer with its output kept in a log
logged() {
    "$@" >> "$LOG" 2>&1
}

# The same, showing the end of the log when it fails
quietly() {
    logged "$@" && return 0
    local status=$?
    show_log
    return $status
}

show_log() {
    say "$(tail -n 20 "$LOG")" "$GRAY"
    say "Full output: $LOG" "$GRAY"
}

# Runs a program as root: directly when already root, through sudo otherwise. Without a person to
# type a password, only passwordless sudo will do.
as_root() {
    if is_root; then
        "$@"
    elif ! command -v sudo > /dev/null 2>&1; then
        problem "This needs root, and sudo is not installed"
        return 1
    elif [[ "$INTERACTIVE" == "true" ]]; then
        sudo "$@"
    else
        sudo -n "$@"
    fi
}

is_root() {
    [[ "$(id -u)" == "0" ]]
}

# --- Checking the components -----------------------------------------------------------------------

name_of() {
    case "$1" in
        dotnet) echo ".NET SDK" ;; node) echo "Node.js" ;; git) echo "Git" ;; ikon) echo "Ikon tool" ;;
    esac
}

status_of() { local v="STATUS_$1"; echo "${!v:-missing}"; }
version_of() { local v="VERSION_$1"; echo "${!v:-}"; }

# Whether version $1 is at most version $2, comparing the numbers between the dots
version_at_most() {
    local -a left right
    local i l r
    IFS=. read -r -a left <<< "$1"
    IFS=. read -r -a right <<< "$2"
    for i in 0 1 2; do
        l="${left[i]:-0}"
        r="${right[i]:-0}"
        (( l < r )) && return 0
        (( l > r )) && return 1
    done
    return 0
}

# This script is published when the repository changes and the tool when it is released, so the
# tool it has just installed can be older than the script. A tool up to LAST_TOOL_INSTALL_VERB_VERSION
# reinstalls its packages with 'tool install --all' and does not know 'self update'.
LAST_TOOL_INSTALL_VERB_VERSION="2.36.2"

reinstall_tool_packages() {
    local version
    version="$(tool_version ikon)"
    if [[ -n "$version" ]] && version_at_most "$version" "$LAST_TOOL_INSTALL_VERB_VERSION"; then
        run ikon --disable-auto-update tool install --all
    else
        run ikon --disable-auto-update self update
    fi
}

# The last version number a program prints about itself, or nothing when it does not run
tool_version() {
    local output
    command -v "$1" > /dev/null 2>&1 || return 0

    # Without the command line tools, macOS's /usr/bin/git opens an install dialog instead of answering
    if [[ "$1" == "git" && "$IS_MAC" == "true" && "$(command -v git)" == "/usr/bin/git" ]] &&
        ! xcode-select -p > /dev/null 2>&1; then
        return 0
    fi

    output="$("$1" --version 2> /dev/null)" ||
        # Older ikon releases know only the 'version' verb, which may print warnings before the version
        { [[ "$1" == "ikon" ]] && output="$(ikon --disable-auto-update version 2> /dev/null)"; } ||
        return 0
    printf '%s\n' "$output" | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)*' | tail -n 1
}

# Why a program does not answer: the first line of what it says, stack traces left out
version_error() {
    local output
    command -v "$1" > /dev/null 2>&1 || { echo "Open a new terminal and run the installer again"; return; }
    output="$( ("$1" --version) 2>&1)"
    printf '%s\n' "$output" | grep -v -e '^Process terminated' -e '^ *at ' -e '^ *$' | head -n 1
}

detect() {
    local id="$1" version status required=""
    version="$(tool_version "$id")"
    case "$id" in dotnet) required="$DOTNET_SDK_MAJOR" ;; node) required="$NODE_MAJOR" ;; esac
    if [[ -z "$version" ]]; then
        status=missing
    elif [[ -n "$required" && "${version%%.*}" -lt "$required" ]]; then
        status=outdated
    else
        status=ok
    fi
    printf -v "STATUS_$id" '%s' "$status"
    printf -v "VERSION_$id" '%s' "$version"
    emit "{\"event\":\"detect\",\"component\":\"$id\",\"version\":$(json_str "$version"),\"status\":\"$status\"}"
}

detect_all() {
    local id color
    for id in $COMPONENTS; do
        detect "$id"
        [[ "$(status_of "$id")" == "ok" ]] && color="$GREEN" || color="$YELLOW"
        say "$(printf "  %-10s %-14s %s" "$(name_of "$id")" "$(version_of "$id" | sed 's/^$/-/')" "$(status_of "$id")")" "$color"
    done
}

is_signed_in() {
    local status pattern='"state": *"(logged-in|renewal-failed)"'
    status="$(ikon --disable-auto-update status --format json 2> /dev/null)"
    [[ "$status" =~ $pattern ]]
}

# --- Platform --------------------------------------------------------------------------------------

detect_platform() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        IS_MAC=true
        return
    fi

    # .NET and Node.js publish no builds that run on a bare musl system
    if ls /lib/ld-musl-* > /dev/null 2>&1; then
        fail "musl-based Linux (Alpine and similar) is not supported"
    fi

    # ID_LIKE places derivatives (Mint, Pop!_OS, Manjaro, Rocky, ...) in the family they share a
    # package manager with
    local id
    # shellcheck source=/dev/null
    for id in $(. /etc/os-release 2> /dev/null; echo "${ID:-} ${ID_LIKE:-}"); do
        case "$id" in
            debian|ubuntu) LINUX_FAMILY=debian; return ;;
            fedora|rhel|centos) LINUX_FAMILY=fedora; return ;;
            arch) LINUX_FAMILY=arch; return ;;
            suse|opensuse) LINUX_FAMILY=suse; return ;;
        esac
    done
}

cpu_arch() {
    case "$(uname -m)" in
        arm64|aarch64) echo arm64 ;;
        *) echo x64 ;;
    esac
}

package_install() {
    case "$LINUX_FAMILY" in
        debian) quietly as_root apt-get update && quietly as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;;
        fedora) quietly as_root dnf install -y "$@" ;;
        arch) quietly as_root pacman -S --needed --noconfirm "$@" ;;
        suse) quietly as_root zypper --non-interactive install "$@" ;;
        *) problem "No supported package manager on this Linux"; return 1 ;;
    esac
}

package_command() {
    case "$LINUX_FAMILY" in
        debian) echo "sudo apt-get install -y $1" ;;
        fedora) echo "sudo dnf install -y $1" ;;
        arch) echo "sudo pacman -S $1" ;;
        suse) echo "sudo zypper install $1" ;;
        *) echo "your package manager" ;;
    esac
}

# --- Paths -------------------------------------------------------------------------------------------

# The file the user's shell reads at start, where PATH changes have to go to outlive this script
shell_profile() {
    case "${SHELL##*/}" in
        zsh) [[ "$IS_MAC" == "true" ]] && echo "$HOME/.zprofile" || echo "$HOME/.zshrc" ;;
        # Terminal.app starts login shells, which read .bash_profile; Linux terminals read .bashrc
        bash) [[ "$IS_MAC" == "true" ]] && echo "$HOME/.bash_profile" || echo "$HOME/.bashrc" ;;
        fish) echo "${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/ikon.fish" ;;
        *) echo "$HOME/.profile" ;;
    esac
}

# An earlier run's per-user installs, found even from a terminal opened before it, and put back on
# PATH should a shell profile have lost them. Only when new enough: an old one would shadow a newer
# copy installed for every user.
use_user_installs() {
    local version
    version="$("$DOTNET_USER_ROOT/dotnet" --version 2> /dev/null)"
    if [[ "${version%%.*}" -ge "$DOTNET_SDK_MAJOR" ]] 2> /dev/null; then
        add_variable DOTNET_ROOT "$DOTNET_USER_ROOT"
        add_path "$DOTNET_USER_ROOT"
    fi

    version="$("$NODE_USER_ROOT/node/bin/node" --version 2> /dev/null)"
    version="${version#v}"
    if [[ "${version%%.*}" -ge "$NODE_MAJOR" ]] 2> /dev/null; then
        add_path "$NODE_USER_ROOT/node/bin"
    fi

    if [[ -x "$DOTNET_TOOLS_DIR/ikon" ]]; then
        add_path "$DOTNET_TOOLS_DIR"
    else
        # Only for this run, where it keeps `dotnet tool install` from asking for it
        export PATH="$DOTNET_TOOLS_DIR:$PATH"
    fi
}

# Puts a folder first on PATH, now and in every new shell
add_path() {
    local folder="$1" profile line
    export PATH="$folder:$PATH"
    # --check changes nothing, so it reports no folder as put on PATH
    if [[ "$CHECK_ONLY" != "true" && " $ADDED_PATHS " != *" $folder "* ]]; then
        ADDED_PATHS="$ADDED_PATHS $folder"
    fi

    profile="$(shell_profile)"
    if [[ "$profile" == *.fish ]]; then
        line="fish_add_path --global --prepend ${folder/#$HOME/\$HOME}"
    else
        line="export PATH=\"${folder/#$HOME/\$HOME}:\$PATH\""
    fi
    persist_line "$profile" "$line"
}

# Sets a variable now and in every new shell
add_variable() {
    local profile line
    export "$1=$2"
    profile="$(shell_profile)"
    if [[ "$profile" == *.fish ]]; then
        line="set -gx $1 ${2/#$HOME/\$HOME}"
    else
        line="export $1=\"${2/#$HOME/\$HOME}\""
    fi
    persist_line "$profile" "$line"
}

persist_line() {
    [[ "$CHECK_ONLY" == "true" ]] && return 0
    mkdir -p "$(dirname "$1")"
    if ! grep -qxF "$2" "$1" 2> /dev/null; then
        printf '%s\n' "$2" >> "$1"
    fi
}

# --- .NET SDK ----------------------------------------------------------------------------------------

install_dotnet() {
    if [[ "$MACHINE" == "true" && "$IS_MAC" == "true" ]]; then
        install_mac_pkg "https://builds.dotnet.microsoft.com/dotnet/Sdk/$DOTNET_SDK_VERSION/dotnet-sdk-$DOTNET_SDK_VERSION-osx-$(cpu_arch).pkg" || return 1
        export PATH="/usr/local/share/dotnet:$PATH"
        return 0
    fi

    if [[ "$MACHINE" == "true" ]]; then
        local package="dotnet-sdk-$DOTNET_SDK_MAJOR.0"
        [[ "$LINUX_FAMILY" == "arch" ]] && package="dotnet-sdk"

        # A distribution's package can trail the SDK needed, so it only counts if it is new enough
        local installed
        if package_install "$package" && hash -r && installed="$(tool_version dotnet)" && [[ "${installed%%.*}" -ge "$DOTNET_SDK_MAJOR" ]] 2> /dev/null; then
            return 0
        fi
        step dotnet "warning" "No .NET SDK $DOTNET_SDK_MAJOR from the package manager; installing it into $DOTNET_USER_ROOT instead"
    fi

    # Microsoft's own install script, into the home folder
    local script
    script="$(mktemp)"
    curl -fsSL --retry 3 https://dot.net/v1/dotnet-install.sh -o "$script" &&
        quietly bash "$script" --channel "$DOTNET_SDK_MAJOR.0" --install-dir "$DOTNET_USER_ROOT" --no-path
    local result=$?
    rm -f "$script"
    [[ $result -eq 0 ]] || return 1

    add_variable DOTNET_ROOT "$DOTNET_USER_ROOT"
    add_path "$DOTNET_USER_ROOT"
    install_icu
}

# .NET needs the system's ICU library, which a minimal Linux (a container, a server) may lack
install_icu() {
    [[ "$IS_MAC" == "true" ]] && return 0
    [[ "$(version_error dotnet)" == *ICU* ]] || return 0

    # Debian and openSUSE version the library's name; the -dev package is the unversioned way to ask
    local package="" fallback=libicu
    case "$LINUX_FAMILY" in
        debian)
            fallback=libicu-dev
            quietly as_root apt-get update
            package="$(apt-cache pkgnames libicu | grep -E '^libicu[0-9]+$' | sort -V | tail -n 1)"
            ;;
        fedora) package=libicu ;;
        arch) package=icu fallback=icu ;;
        suse)
            fallback=libicu-devel
            package="$(zypper -q search 'libicu*' | awk -F'|' '{ gsub(/ /, "", $2) } $2 ~ /^libicu[0-9]+$/ { print $2 }' | sort -V | tail -n 1)"
            ;;
    esac

    if [[ -z "$package" ]] || ! package_install "$package"; then
        problem ".NET needs the ICU library, which is not installed. Install it with $(package_command "${package:-$fallback}")"
        return 1
    fi
}

# --- Node.js -----------------------------------------------------------------------------------------

install_node() {
    # A version manager already looking after Node keeps doing so
    local manager
    manager="$(node_version_manager)"
    if [[ -n "$manager" ]]; then
        install_node_with "$manager"
        return
    fi

    if [[ "$MACHINE" == "true" && "$IS_MAC" == "true" ]]; then
        install_mac_pkg "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.pkg" || return 1
        export PATH="/usr/local/bin:$PATH"
        return 0
    fi

    if [[ "$MACHINE" == "true" ]]; then
        case "$LINUX_FAMILY" in
            debian|fedora)
                local repo=deb
                [[ "$LINUX_FAMILY" == "fedora" ]] && repo=rpm
                curl -fsSL --retry 3 "https://$repo.nodesource.com/setup_$NODE_MAJOR.x" -o /tmp/nodesource-setup.sh &&
                    quietly as_root bash /tmp/nodesource-setup.sh && package_install nodejs && hash -r && return 0
                ;;
            arch) package_install nodejs npm && hash -r && return 0 ;;
        esac
        step node "warning" "No Node.js $NODE_MAJOR from the package manager; installing it into $NODE_USER_ROOT instead"
    fi

    install_node_archive
}

# The official archive, checked against its published digest, into the home folder
install_node_archive() {
    local platform=linux name archive expected actual
    [[ "$IS_MAC" == "true" ]] && platform=darwin
    name="node-v$NODE_VERSION-$platform-$(cpu_arch)"
    archive="$(mktemp)"

    curl -fsSL --retry 3 "https://nodejs.org/dist/v$NODE_VERSION/$name.tar.gz" -o "$archive" || { rm -f "$archive"; return 1; }
    expected="$(curl -fsSL --retry 3 "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt" | awk -v file="$name.tar.gz" '$2 == file { print $1 }')"
    if command -v shasum > /dev/null 2>&1; then
        actual="$(shasum -a 256 "$archive" | awk '{ print $1 }')"
    else
        actual="$(sha256sum "$archive" | awk '{ print $1 }')"
    fi
    if [[ -z "$expected" || "$expected" != "$actual" ]]; then
        rm -f "$archive"
        problem "The Node.js download does not match its published checksum"
        return 1
    fi

    # Unpacked under its version, reached through a link that keeps its name across versions
    mkdir -p "$NODE_USER_ROOT"
    rm -rf "${NODE_USER_ROOT:?}/$name"
    tar -xzf "$archive" -C "$NODE_USER_ROOT" || { rm -f "$archive"; return 1; }
    rm -f "$archive"
    ln -sfn "$NODE_USER_ROOT/$name" "$NODE_USER_ROOT/node"
    add_path "$NODE_USER_ROOT/node/bin"
}

# nvm, fnm or volta when the active node is theirs, or when there is no node and one is installed
node_version_manager() {
    local real
    if command -v node > /dev/null 2>&1; then
        real="$(cd "$(dirname "$(command -v node)")" && pwd -P)"
        case "$real" in
            */.nvm/versions/node/*) echo nvm ;;
            */fnm/node-versions/*|*/fnm_multishells/*) echo fnm ;;
            */.volta/*) echo volta ;;
        esac
    elif [[ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]]; then
        echo nvm
    elif command -v fnm > /dev/null 2>&1; then
        echo fnm
    elif command -v volta > /dev/null 2>&1; then
        echo volta
    fi
}

install_node_with() {
    local bin=""
    case "$1" in
        nvm)
            # nvm is not written for `set -u`
            export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
            set +u
            # shellcheck disable=SC1091
            . "$NVM_DIR/nvm.sh" && run nvm install "$NODE_MAJOR" && run nvm alias default "$NODE_MAJOR" && bin="$(dirname "$(nvm which default)")"
            set -u
            [[ -n "$bin" ]] || return 1
            ;;
        fnm)
            run fnm install "$NODE_MAJOR" && run fnm default "$NODE_MAJOR" || return 1
            bin="${FNM_DIR:-$HOME/.local/share/fnm}/aliases/default/bin"
            ;;
        volta)
            run volta install "node@$NODE_MAJOR" || return 1
            bin="${VOLTA_HOME:-$HOME/.volta}/bin"
            ;;
    esac
    # On PATH for this run only: the version manager's own shell setup keeps it there from now on
    export PATH="$bin:$PATH"
    ADDED_PATHS="$ADDED_PATHS $bin"
}

# --- Git -----------------------------------------------------------------------------------------------

install_git() {
    if [[ "$IS_MAC" == "true" ]]; then
        # Only Apple's own dialog installs the command line tools that bring git
        xcode-select --install > /dev/null 2>&1 || true
        if [[ "$INTERACTIVE" != "true" ]]; then
            problem "Finish installing the command line tools in the dialog that opened, then run the installer again"
            return 1
        fi
        say "Click Install in the dialog that opened. Waiting for it to finish..." "$YELLOW"
        local waited=0
        until xcode-select -p > /dev/null 2>&1 && git --version > /dev/null 2>&1; do
            [[ $waited -ge 1200 ]] && return 1
            sleep 5
            waited=$((waited + 5))
        done
        return 0
    fi

    if ! package_install git; then
        problem "Git needs root to install. Run: $(package_command git)"
        return 1
    fi
    hash -r
}

install_mac_pkg() {
    local dir
    dir="$(mktemp -d)"
    curl -fsSL --retry 3 "$1" -o "$dir/installer.pkg" && quietly as_root installer -pkg "$dir/installer.pkg" -target /
    local result=$?
    rm -rf "$dir"
    return $result
}

# --- The Ikon tool -------------------------------------------------------------------------------------

install_ikon_tool() {
    # A config of its own: a global tool install still reads NuGet settings from the current folder
    local config_dir config
    config_dir="$(mktemp -d)"
    config="$config_dir/NuGet.Config"
    cat > "$config" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
</configuration>
EOF
    local common=(ikon --global --no-http-cache --configfile "$config")

    # Update what is there, install what is not, and replace an install too broken for either. A dev
    # channel build (ikon-dev) owns the 'ikon' command, so it goes too: this installs the released tool
    logged dotnet tool update "${common[@]}" ||
        logged dotnet tool install "${common[@]}" ||
        { logged dotnet tool uninstall ikon --global; logged dotnet tool uninstall ikon-dev --global; logged dotnet tool install "${common[@]}"; }
    local result=$?
    rm -rf "$config_dir"
    if [[ $result -ne 0 ]]; then
        show_log
        fail "The Ikon tool could not be installed"
    fi

    add_path "$DOTNET_TOOLS_DIR"
    [[ -n "$(tool_version ikon)" ]] || fail "The Ikon tool was installed but does not run"
}

# --- HTTPS development certificate ---------------------------------------------------------------------

trust_dev_certificate() {
    if [[ "$IS_MAC" == "true" ]]; then
        step certificate "start" "Trusting the HTTPS development certificate (macOS asks for your password)..."
        if quietly dotnet dev-certs https --trust; then
            step certificate "done" "HTTPS development certificate trusted"
        else
            step certificate "warning" "The HTTPS development certificate is not trusted. Run 'dotnet dev-certs https --trust' later"
        fi
        return
    fi

    quietly dotnet dev-certs https || return 0

    # Linux keeps trusted certificates in a system store, which needs root
    if [[ "$MACHINE" != "true" ]] && ! is_root; then
        step certificate "skipped" "HTTPS development certificate created. Trusting it needs root: run the installer with --machine"
        return
    fi

    local anchor refresh pem
    if command -v update-ca-trust > /dev/null 2>&1 && [[ -d /etc/pki/ca-trust/source/anchors ]]; then
        anchor=/etc/pki/ca-trust/source/anchors refresh=update-ca-trust
    elif command -v update-ca-trust > /dev/null 2>&1 && [[ -d /etc/ca-certificates/trust-source/anchors ]]; then
        anchor=/etc/ca-certificates/trust-source/anchors refresh=update-ca-trust
    elif command -v update-ca-certificates > /dev/null 2>&1 && [[ -d /etc/pki/trust/anchors ]]; then
        anchor=/etc/pki/trust/anchors refresh=update-ca-certificates
    elif command -v update-ca-certificates > /dev/null 2>&1 && [[ -d /usr/local/share/ca-certificates ]]; then
        anchor=/usr/local/share/ca-certificates refresh=update-ca-certificates
    else
        step certificate "warning" "No system certificate store found to trust the HTTPS development certificate in"
        return
    fi

    step certificate "start" "Trusting the HTTPS development certificate..."
    pem="$(mktemp)"
    if quietly dotnet dev-certs https -ep "$pem" --format PEM && quietly as_root cp "$pem" "$anchor/ikon-https-dev.crt" && quietly as_root "$refresh"; then
        step certificate "done" "HTTPS development certificate trusted"
    else
        step certificate "warning" "The HTTPS development certificate could not be trusted"
    fi
    rm -f "$pem"
}

main "$@"
