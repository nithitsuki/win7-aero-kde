#!/usr/bin/env bash
# One-shot Windows 7 Aero setup for KDE Plasma 6.8 on Arch Linux.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export ROOT
export STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/win7-aero"
export CACHE_DIR="$STATE_DIR/cache"
export BACKUP_ROOT="$STATE_DIR/backups"
export LOG_FILE="$STATE_DIR/install.log"

export SKIP_DEPS=0 SKIP_CAPS=0 SKIP_ASSETS=0 SKIP_ATP=0
export SKIP_KDE=0 SKIP_SDDM=0 SKIP_KONSOLE=0 SKIP_SHORTCUTS=0 SKIP_WALLPAPER=0 SKIP_VERIFY=0
export KEEP_ISO=0 FORCE=0 DRY_RUN=0 REINSTALL_ATP=0

usage() {
    cat <<'EOF'
Windows 7 Aero for KDE Plasma - one-shot installer

Usage: ./install.sh [options]

Options:
  --skip-deps         Skip pacman dependency installation
  --skip-caps         Skip Caps Lock -> Ctrl
  --skip-assets       Skip Windows 7 ISO/fonts/sounds/icons extraction
  --skip-atp          Skip AeroThemePlasma build/install
  --skip-kde          Skip Plasma/KWin theme configuration
  --skip-sddm         Skip SDDM theme/session configuration
  --skip-konsole      Skip the Command Prompt lookalike
  --skip-shortcuts    Skip Windows-key and screenshot shortcut setup
  --skip-wallpaper    Skip wallpaper download/resize
  --skip-verify       Skip the final checks
  --verify-only       Run the preflight and final checks only
  --keep-iso          Keep the Windows 7 ISO and extraction tree
  --reinstall-atp     Rebuild ATP even if it is already installed
  --force             Continue on a non-Arch system (unsupported)
  --dry-run           Print what would run without changing anything
  -h, --help          Show this help

Environment:
  WIN7_ISO=/path/to/Win7.iso    Use a local ISO instead of downloading one
  WALLPAPER_SRC=/path/file.jpg  Use a local Harmony wallpaper source
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-deps)       SKIP_DEPS=1 ;;
        --skip-caps)       SKIP_CAPS=1 ;;
        --skip-assets|--skip-fonts) SKIP_ASSETS=1 ;;
        --skip-atp)        SKIP_ATP=1 ;;
        --skip-kde)        SKIP_KDE=1 ;;
        --skip-sddm)       SKIP_SDDM=1 ;;
        --skip-konsole)    SKIP_KONSOLE=1 ;;
        --skip-shortcuts)  SKIP_SHORTCUTS=1 ;;
        --skip-wallpaper)  SKIP_WALLPAPER=1 ;;
        --skip-verify)     SKIP_VERIFY=1 ;;
        --verify-only)
            SKIP_DEPS=1 SKIP_CAPS=1 SKIP_ASSETS=1 SKIP_ATP=1
            SKIP_KDE=1 SKIP_SDDM=1 SKIP_KONSOLE=1 SKIP_SHORTCUTS=1
            SKIP_WALLPAPER=1 SKIP_VERIFY=0
            ;;
        --keep-iso)        KEEP_ISO=1 ;;
        --reinstall-atp)   REINSTALL_ATP=1 ;;
        --force)           FORCE=1 ;;
        --dry-run)         DRY_RUN=1 ;;
        -h|--help)         usage; exit 0 ;;
        *)                 echo "Unknown option: $1" >&2; usage; exit 2 ;;
    esac
    shift
done

source "$ROOT/lib/common.sh"

# One shared backup directory for every step, so uninstall can restore a
# consistent snapshot instead of only the last component's backup.
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
export BACKUP_DIR
mkdir -p "$BACKUP_DIR"

printf '\n%sWindows 7 Aero for KDE Plasma%s\n' "$C_BLUE" "$C_RESET"
printf 'Repo:  %s\nState: %s\nLog:   %s\n\n' "$ROOT" "$STATE_DIR" "$LOG_FILE"

run() {
    local script="$1"
    shift
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
[[ $SKIP_KDE       == 1 ]] || run 50-kde.sh
[[ $SKIP_SDDM      == 1 ]] || run 60-sddm.sh
[[ $SKIP_KONSOLE   == 1 ]] || run 70-konsole.sh
[[ $SKIP_SHORTCUTS == 1 ]] || run 72-shortcuts.sh
[[ $SKIP_WALLPAPER == 1 ]] || run 80-wallpaper.sh
[[ $SKIP_VERIFY    == 1 ]] || run 90-verify.sh

cat <<EOF

${C_GREEN}Setup complete.${C_RESET}

Next step:
  1. Log out.
  2. Choose the "AeroThemePlasma" session (it is already preselected).
  3. On the first login, accept the AeroThemePlasma OOTB wizard.

If you skipped ATP, the session will not exist yet.

Logs and backups: $STATE_DIR
Verify later:      ./install.sh --verify-only
Uninstall:         ./uninstall.sh
EOF
