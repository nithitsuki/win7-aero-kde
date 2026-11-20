#!/usr/bin/env bash
# Shared helpers for the win7-aero-kde installer.
# This file is sourced by install.sh and scripts/*.sh.

set -euo pipefail

: "${ROOT:?ROOT must be set by the caller}"
: "${STATE_DIR:=${XDG_DATA_HOME:-$HOME/.local/share}/win7-aero}"
: "${CACHE_DIR:=$STATE_DIR/cache}"
: "${BACKUP_ROOT:=$STATE_DIR/backups}"
: "${LOG_FILE:=$STATE_DIR/install.log}"
: "${DRY_RUN:=0}"

mkdir -p "$STATE_DIR" "$CACHE_DIR" "$BACKUP_ROOT"
touch "$LOG_FILE"

if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'
    C_BLUE=$'\033[1;34m'
    C_YELLOW=$'\033[1;33m'
    C_RED=$'\033[1;31m'
    C_GREEN=$'\033[1;32m'
else
    C_RESET=''
    C_BLUE=''
    C_YELLOW=''
    C_RED=''
    C_GREEN=''
fi

log()  { printf '%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*" | tee -a "$LOG_FILE"; }
ok()   { printf '%s[ok]%s %s\n' "$C_GREEN" "$C_RESET" "$*" | tee -a "$LOG_FILE"; }
warn() { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" | tee -a "$LOG_FILE" >&2; }
die()  { printf '%s[error]%s %s\n' "$C_RED" "$C_RESET" "$*" | tee -a "$LOG_FILE" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

as_root() {
    if [[ ${DRY_RUN:-0} == 1 ]]; then
        log "DRY-RUN: sudo $*"
        return 0
    fi
    sudo "$@"
}

set_backup_dir() {
    if [[ -z "${BACKUP_DIR:-}" ]]; then
        BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
        export BACKUP_DIR
        mkdir -p "$BACKUP_DIR"
    fi
}

# Copy each path into a timestamped backup tree that mirrors the filesystem.
# Example: backup_file "$HOME/.config/kxkbrc" /etc/sddm.conf.d
backup_file() {
    local f rel
    set_backup_dir
    for f in "$@"; do
        [[ -e "$f" ]] || continue
        rel="${f#/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        rm -rf "${BACKUP_DIR:?}/$rel"
        cp -a "$f" "$BACKUP_DIR/$rel"
    done
}

kwrite() { kwriteconfig6 "$@"; }
kread()  { kreadconfig6 "$@"; }

has_plasma_session() {
    have qdbus6 && qdbus6 org.kde.KWin /KWin >/dev/null 2>&1
}

refresh_ksycoca() {
    if have kbuildsycoca6; then
        kbuildsycoca6 >/dev/null 2>&1 || true
    fi
}

# plasma-apply-lookandfeel calls xrdb on X11 even in a Wayland session. Get the
# current Xauthority from the systemd user environment to avoid noisy failures.
apply_xauthority() {
    if [[ -z "${XAUTHORITY:-}" ]] && have systemctl; then
        XAUTHORITY="$(systemctl --user show-environment 2>/dev/null | sed -n 's/^XAUTHORITY=//p')"
        if [[ -n "$XAUTHORITY" ]]; then
            export XAUTHORITY
        fi
    fi
}
