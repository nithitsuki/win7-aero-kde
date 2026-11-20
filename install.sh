#!/usr/bin/env bash
# Windows 7 conversion for KDE Plasma 6.8 on Arch Linux.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export ROOT

export STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/win7-aero"
export CACHE_DIR="$STATE_DIR/cache"
export BACKUP_ROOT="$STATE_DIR/backups"
export LOG_FILE="$STATE_DIR/install.log"

export SKIP_DEPS=0 SKIP_CAPS=0 SKIP_ASSETS=0 SKIP_ATP=0 SKIP_GADGETS=0
export SKIP_GAMES=0
export SKIP_SIDEBAR_GADGETS=0
export SKIP_GTK=0 SKIP_LINVER=0
export SKIP_KDE=0 SKIP_TRASH=0 SKIP_SDDM=0 SKIP_KONSOLE=0 SKIP_SHORTCUTS=0 SKIP_WALLPAPER=0 SKIP_VERIFY=0
export KEEP_ISO=0 FORCE=0 DRY_RUN=0 REINSTALL_ATP=0 REINSTALL_GADGETS=0 GUI=0
export REINSTALL_SIDEBAR_GADGETS=0
export REINSTALL_GTK=0 REINSTALL_LINVER=0

usage() {
    cat <<'EOF'
Windows 7 conversion for KDE Plasma

Usage: ./install.sh [options]

Options:
  --skip-deps         Skip pacman dependency installation
  --skip-caps         Skip Caps Lock -> Ctrl
  --skip-assets       Skip Windows 7 ISO/fonts/sounds/icons/games extraction
  --skip-atp          Skip AeroThemePlasma build/install
  --skip-gadgets      Skip the AeroShell desktop gadgets
  --skip-sidebar-gadgets  Skip the Picture Puzzle, Calendar and Currency widgets
  --skip-games        Skip the Windows 7 games
  --skip-gtk          Skip the Windows 7 Better GTK theme
  --skip-linver       Skip the LinVer winver clone
  --skip-kde          Skip Plasma/KWin theme configuration
  --skip-trash        Skip the Recycle Bin desktop icon
  --skip-sddm         Skip SDDM theme/session configuration
  --skip-konsole      Skip the Command Prompt lookalike
  --skip-shortcuts    Skip Windows-key and screenshot shortcut setup
  --skip-wallpaper    Skip wallpaper download/resize
  --skip-verify       Skip the final checks
  --verify-only       Run the preflight and final checks only
  --keep-iso          Keep the Windows 7 ISO and extraction tree
  --reinstall-atp     Rebuild ATP even if it is already installed
  --reinstall-gadgets Rebuild the AeroShell desktop gadgets
  --reinstall-sidebar-gadgets Rebuild the Picture Puzzle, Calendar and Currency widgets
  --reinstall-gtk     Reinstall the Windows 7 Better GTK theme
  --reinstall-linver  Rebuild LinVer
  --force             Continue on a non-Arch system (unsupported)
  --dry-run           Print what would run without changing anything
  --gui               Open the graphical installer
  -h, --help          Show this help

Environment:
  WIN7_ISO=/path/to/Win7.iso    Use a local ISO instead of downloading one
  WALLPAPER_SRC=/path/file.jpg  Use a local Harmony wallpaper source
  WIN7_GAMES_DIR=/path/games    Use extracted games instead of the asset cache
  WIN7_PREFIX=/path/pfx         Use a different Wine prefix for games/apps
  PROTON_DIR=/path/Proton       Use a specific Proton runtime
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-deps)       SKIP_DEPS=1 ;;
        --skip-caps)       SKIP_CAPS=1 ;;
        --skip-assets|--skip-fonts) SKIP_ASSETS=1 ;;
        --skip-atp)        SKIP_ATP=1 ;;
        --skip-gadgets)    SKIP_GADGETS=1 ;;
        --skip-sidebar-gadgets) SKIP_SIDEBAR_GADGETS=1 ;;
        --skip-games)      SKIP_GAMES=1 ;;
        --skip-gtk)        SKIP_GTK=1 ;;
        --skip-linver)     SKIP_LINVER=1 ;;
        --skip-kde)        SKIP_KDE=1 ;;
        --skip-trash)      SKIP_TRASH=1 ;;
        --skip-sddm)       SKIP_SDDM=1 ;;
        --skip-konsole)    SKIP_KONSOLE=1 ;;
        --skip-shortcuts)  SKIP_SHORTCUTS=1 ;;
        --skip-wallpaper)  SKIP_WALLPAPER=1 ;;
        --skip-verify)     SKIP_VERIFY=1 ;;
        --verify-only)
            SKIP_DEPS=1 SKIP_CAPS=1 SKIP_ASSETS=1 SKIP_ATP=1 SKIP_GADGETS=1
            SKIP_SIDEBAR_GADGETS=1 SKIP_GAMES=1
            SKIP_GTK=1 SKIP_LINVER=1
            SKIP_KDE=1 SKIP_TRASH=1 SKIP_SDDM=1 SKIP_KONSOLE=1 SKIP_SHORTCUTS=1
            SKIP_WALLPAPER=1 SKIP_VERIFY=0
            ;;
        --keep-iso)        KEEP_ISO=1 ;;
        --reinstall-atp)   REINSTALL_ATP=1 ;;
        --reinstall-gadgets) REINSTALL_GADGETS=1 ;;
        --reinstall-sidebar-gadgets) REINSTALL_SIDEBAR_GADGETS=1 ;;
        --reinstall-gtk)   REINSTALL_GTK=1 ;;
        --reinstall-linver) REINSTALL_LINVER=1 ;;
        --force)           FORCE=1 ;;
        --dry-run)         DRY_RUN=1 ;;
        --gui)             GUI=1 ;;
        -h|--help)         usage; exit 0 ;;
        *)                 echo "Unknown option: $1" >&2; usage; exit 2 ;;
    esac
    shift
done

if [[ $GUI == 1 ]]; then
    export WIN7_GUI_SKIP_GAMES="$SKIP_GAMES"
    exec "$ROOT/gui/win7-installer"
fi

source "$ROOT/lib/common.sh"

# One shared backup directory for every step, so uninstall can restore a
# consistent snapshot instead of only the last component's backup.
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
export BACKUP_DIR
mkdir -p "$BACKUP_DIR"

printf '\n%sWindows 7 for KDE Plasma%s\n' "$C_BLUE" "$C_RESET"
printf 'Repo:  %s\nState: %s\nLog:   %s\n\n' "$ROOT" "$STATE_DIR" "$LOG_FILE"

STEP=0
TOTAL_STEPS=1   # preflight always runs
[[ $SKIP_VERIFY == 1 ]] || TOTAL_STEPS=$((TOTAL_STEPS + 1))
for flag in SKIP_DEPS SKIP_CAPS SKIP_ASSETS SKIP_ATP SKIP_GADGETS \
            SKIP_SIDEBAR_GADGETS SKIP_GTK SKIP_LINVER SKIP_GAMES SKIP_KDE \
            SKIP_TRASH SKIP_SDDM SKIP_KONSOLE SKIP_SHORTCUTS SKIP_WALLPAPER; do
    [[ ${!flag} == 1 ]] || TOTAL_STEPS=$((TOTAL_STEPS + 1))
done

progress_label() {
    case "$1" in
        00-preflight.sh)       echo "Checking your system" ;;
        10-deps.sh)            echo "Installing required packages" ;;
        20-capslock.sh)        echo "Configuring the keyboard" ;;
        30-assets.sh)          echo "Copying Windows 7 files" ;;
        40-atp.sh)             echo "Installing the Windows 7 shell" ;;
        45-gadgets.sh)         echo "Installing desktop gadgets" ;;
        46-sidebar-gadgets.sh) echo "Installing Sidebar gadgets" ;;
        47-gtk.sh)             echo "Installing the GTK theme" ;;
        48-linver.sh)          echo "Installing LinVer" ;;
        49-games.sh)           echo "Installing games" ;;
        50-kde.sh)             echo "Applying desktop settings" ;;
        55-desktop-trash.sh)   echo "Creating the Recycle Bin" ;;
        60-sddm.sh)            echo "Configuring the login screen" ;;
        70-konsole.sh)         echo "Configuring Command Prompt" ;;
        72-shortcuts.sh)       echo "Configuring shortcuts" ;;
        80-wallpaper.sh)       echo "Setting the wallpaper" ;;
        90-verify.sh)          echo "Finishing up" ;;
        *)                     echo "Working" ;;
    esac
}

run() {
    local script="$1"
    shift
    STEP=$((STEP + 1))
    if [[ ${WIN7_PROGRESS:-0} == 1 ]]; then
        printf '@@STEP %d %d %s\n' "$STEP" "$TOTAL_STEPS" "$(progress_label "$script")"
    fi
    if [[ $DRY_RUN == 1 ]]; then
        log "DRY-RUN: bash scripts/$script $*"
        return 0
    fi
    bash "$ROOT/scripts/$script" "$@"
}

run 00-preflight.sh
[[ $SKIP_DEPS      == 1 ]] || run 10-deps.sh
[[ $SKIP_CAPS      == 1 ]] || run 20-capslock.sh
[[ $SKIP_ASSETS    == 1 ]] || run 30-assets.sh
[[ $SKIP_ATP       == 1 ]] || run 40-atp.sh
[[ $SKIP_GADGETS   == 1 ]] || run 45-gadgets.sh
[[ $SKIP_SIDEBAR_GADGETS == 1 ]] || run 46-sidebar-gadgets.sh
[[ $SKIP_GTK       == 1 ]] || run 47-gtk.sh
[[ $SKIP_LINVER    == 1 ]] || run 48-linver.sh
[[ $SKIP_GAMES     == 1 ]] || run 49-games.sh
[[ $SKIP_KDE       == 1 ]] || run 50-kde.sh
[[ $SKIP_TRASH     == 1 ]] || run 55-desktop-trash.sh
[[ $SKIP_SDDM      == 1 ]] || run 60-sddm.sh
[[ $SKIP_KONSOLE   == 1 ]] || run 70-konsole.sh
[[ $SKIP_SHORTCUTS == 1 ]] || run 72-shortcuts.sh
[[ $SKIP_WALLPAPER == 1 ]] || run 80-wallpaper.sh
[[ $SKIP_VERIFY    == 1 ]] || run 90-verify.sh

[[ ${WIN7_PROGRESS:-0} == 1 ]] && printf '@@DONE\n'

cat <<EOF

${C_GREEN}Setup complete.${C_RESET}

Next step:
  1. Log out.
  2. Choose the "AeroThemePlasma" session (it is already preselected).
  3. On the first login, accept the AeroThemePlasma OOTB wizard.

If you skipped ATP, the session will not exist yet.

Desktop gadgets: right-click the desktop, choose Add Widgets, and pick
Clock, CPU, Notes, RSS or Slideshow.
Sidebar gadgets: Picture Puzzle, Calendar and Currency are in Add Widgets.
Games: Solitaire, FreeCell, Hearts, Spider, Minesweeper, Chess Titans,
Mahjong Titans and Purble Place are installed when Proton is available.
Recycle Bin: the desktop icon opens the Trash and updates its empty/full
icon automatically. From a TTY, log in and re-run
scripts/55-desktop-trash.sh.
GTK theme: restart GTK apps (including Firefox) to load Windows 7 Better.
Windows version dialog: run 'linver'.

Logs and backups: $STATE_DIR
Verify later:      "$ROOT/install.sh" --verify-only
Uninstall:         "$ROOT/uninstall.sh"
EOF
