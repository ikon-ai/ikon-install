#!/usr/bin/env bash
# Ikon Desktop installer for macOS
#
#   curl -fsSL https://ikonai.com/install-desktop.sh | bash
#
# Downloads the latest Ikon Desktop .dmg, copies the app into Applications and opens it; the app then
# installs the Ikon tool itself. A browser download is quarantined, and macOS refuses to open a
# quarantined app that is not notarized. curl sets no quarantine flag, so this path opens the same app
# without that check, whatever the state of its notarization.
#
# Options:
#   --no-open      Install without opening the app.
#
# Everything below is functions; nothing runs until main is called on the last line, so a download
# that stops halfway runs nothing at all.

set -uo pipefail

RELEASES="https://github.com/ikon-ai/ikon-install/releases"
APP_NAME="Ikon Desktop"
WORK=""
MOUNT=""
MOUNTED=false

main() {
    local open_app=true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-open) open_app=false ;;
            *) fail "Unknown option '$1'" ;;
        esac
        shift
    done

    if [[ "$(uname -s)" != "Darwin" ]]; then
        fail "This installer is for macOS. On Windows and Linux, download Ikon Desktop from $RELEASES/latest"
    fi

    # Not uname -m, which says x86_64 to a shell running under Rosetta on an Apple silicon Mac
    if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null)" != "1" ]]; then
        fail "Ikon Desktop is built for Apple silicon Macs only. On this Mac, install the Ikon tool with: curl -fsSL https://ikonai.com/install.sh | bash"
    fi

    WORK="$(mktemp -d)" || fail "Cannot create a temporary folder"
    trap cleanup EXIT

    local version dmg
    version="$(latest_version)" || exit 1
    dmg="IkonDesktop-$version-macos-arm64.dmg"
    say "Downloading Ikon Desktop $version"
    curl -fL --progress-bar -o "$WORK/$dmg" "$RELEASES/download/v-ikon-desktop-$version/$dmg" \
        || fail "Could not download $RELEASES/download/v-ikon-desktop-$version/$dmg"

    MOUNT="$WORK/mount"
    mkdir -p "$MOUNT"
    hdiutil attach -nobrowse -readonly -noautoopen -quiet -mountpoint "$MOUNT" "$WORK/$dmg" \
        || fail "Could not open $dmg"
    MOUNTED=true

    if [[ ! -d "$MOUNT/$APP_NAME.app" ]]; then
        fail "$dmg does not contain $APP_NAME.app"
    fi

    local applications target staged previous
    applications="$(applications_folder)" || exit 1
    target="$applications/$APP_NAME.app"
    # Copied beside the installed app and swapped in, so a copy that fails halfway leaves the old
    # app working rather than none
    staged="$applications/.$APP_NAME.app.new"
    previous="$applications/.$APP_NAME.app.old"
    say "Installing into $applications"
    rm -rf "$staged" "$previous"
    ditto "$MOUNT/$APP_NAME.app" "$staged" || { rm -rf "$staged"; fail "Could not copy $APP_NAME.app into $applications"; }
    # Nothing on this path sets the flag, but a copy that inherited one would be refused on open
    xattr -dr com.apple.quarantine "$staged" 2>/dev/null || true

    quit_running_app

    if [[ -e "$target" ]]; then
        mv "$target" "$previous" || { rm -rf "$staged"; fail "Could not replace $target"; }
    fi

    if ! mv "$staged" "$target"; then
        mv "$previous" "$target" 2>/dev/null || true
        fail "Could not move the new $APP_NAME.app into $applications"
    fi

    rm -rf "$previous"

    say "Ikon Desktop $version is installed in $applications"

    if [[ "$open_app" == true ]]; then
        open "$target" || fail "Could not open $target"
        say "Ikon Desktop is opening. It installs the Ikon tool and signs you in from there"
    fi
}

latest_version() {
    # The release page redirects to the latest tag, which spares the GitHub API and its 60 requests an
    # hour per address, a limit an office behind one address would reach
    local url version
    url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$RELEASES/latest")" \
        || fail "Could not reach $RELEASES/latest"
    version="${url##*/v-ikon-desktop-}"

    if [[ "$version" == "$url" || -z "$version" ]]; then
        fail "The latest release at $RELEASES/latest is not an Ikon Desktop release ($url)"
    fi

    printf '%s\n' "$version"
}

applications_folder() {
    # An installed copy is replaced where it is: a second one elsewhere would leave login and Launch
    # Services starting whichever they found first
    if [[ -d "/Applications/$APP_NAME.app" ]]; then
        if [[ ! -w /Applications ]]; then
            fail "Ikon Desktop is installed in /Applications, which only an administrator can update. Run this as an administrator"
        fi
        printf '/Applications
'
        return
    fi

    if [[ -d "$HOME/Applications/$APP_NAME.app" ]]; then
        printf '%s
' "$HOME/Applications"
        return
    fi

    # An administrator can write to /Applications without sudo; a standard user gets their own, which
    # Finder, Spotlight and Launchpad find as well
    if [[ -w /Applications ]]; then
        printf '/Applications\n'
        return
    fi

    mkdir -p "$HOME/Applications" || fail "Cannot create $HOME/Applications"
    printf '%s\n' "$HOME/Applications"
}

quit_running_app() {
    if ! pgrep -xq "$APP_NAME" 2>/dev/null && ! pgrep -fq "/$APP_NAME.app/Contents/MacOS/" 2>/dev/null; then
        return
    fi

    say "Quitting the running Ikon Desktop"
    osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || true

    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        if ! pgrep -fq "/$APP_NAME.app/Contents/MacOS/" 2>/dev/null; then
            return
        fi
        sleep 1
    done

    # Not killed: only a quit stops the Ikon Connect it supervises, which would otherwise outlive it
    # and run beside the new app's own
    fail "Ikon Desktop did not quit. Quit it from its menu bar icon and run this again"
}

cleanup() {
    if [[ "$MOUNTED" == true ]]; then
        if ! hdiutil detach -quiet "$MOUNT" 2>/dev/null && ! hdiutil detach -quiet -force "$MOUNT" 2>/dev/null; then
            # Removing the folder would walk into the read-only volume still mounted in it; the
            # temporary folder is cleared at the next restart instead
            return
        fi
    fi

    if [[ -n "$WORK" ]]; then
        rm -rf "$WORK"
    fi
}

say() {
    printf '%s\n' "$*" >&2
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

main "$@"
