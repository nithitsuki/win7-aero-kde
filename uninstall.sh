#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export ROOT
export STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/win7-aero"
export CACHE_DIR="$STATE_DIR/cache"
export BACKUP_ROOT="$STATE_DIR/backups"
export LOG_FILE="$STATE_DIR/install.log"

PURGE=0
YES=0
for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=1 ;;
        --yes|-y) YES=1 ;;
        -h|--help)
            echo "Usage: ./uninstall.sh [--yes] [--purge]"
            echo "  --yes    Do not ask for confirmation"
            echo "  --purge  Also delete $STATE_DIR (source, logs, backups, extracted assets)"
            exit 0
            ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

source "$ROOT/lib/common.sh"

if [[ ${PLASMA_DEFAULT_SHELL:-} == io.gitgud.wackyideas.desktop ]]; then
    warn "You are currently in the AeroThemePlasma shell. Log into a normal Plasma session before uninstalling."
fi

cat <<'EOF'
This will:
  - run AeroThemePlasma's uninstaller
  - reinstall the distro libplasma package
  - remove Windows 7 fonts, CMD launcher, wallpaper autostart and original sound theme
  - restore the most recent config backup
EOF

if [[ $YES != 1 ]]; then
    read -r -p "Continue? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || exit 0
fi

if [[ -f "$STATE_DIR/src/aerothemeplasma/uninstall.sh" ]]; then
    log "Running AeroThemePlasma uninstaller"
    ( cd "$STATE_DIR/src/aerothemeplasma" && bash uninstall.sh ) || warn "ATP uninstaller returned an error"
else
    warn "ATP source tree not found; skipping its uninstaller."
fi

log "Reinstalling the distro libplasma package"
as_root pacman -S --noconfirm libplasma || warn "Could not reinstall libplasma; do it manually."

log "Removing Windows 7 fonts"
as_root rm -rf /usr/share/fonts/win7
as_root fc-cache -f >/dev/null 2>&1 || true

log "Removing Command Prompt and wallpaper autostart"
rm -f \
    "$HOME/.local/bin/cmd" \
    "$HOME/.local/bin/win7-cmd-shell" \
    "$HOME/.local/bin/win7-shortcuts" \
    "$HOME/.local/share/konsole/Win7CMD.colorscheme" \
    "$HOME/.local/share/applications/cmd.desktop" \
    "$HOME/.local/share/icons/hicolor/scalable/apps/win7-cmd.svg" \
    "$HOME/.config/autostart/atp-wallpaper.desktop" \
    "$HOME/.config/autostart/win7-shortcuts.desktop"
rm -rf "$HOME/.config/win7-cmd"
rm -rf "$HOME/.local/share/sounds/Windows 7 Original"

log "Restoring the most recent config backup"
latest="$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1 || true)"
if [[ -n "$latest" && -d "$latest" ]]; then
    for f in \
        "$HOME/.config/kxkbrc" \
        "$HOME/.config/kdeglobals" \
        "$HOME/.config/kwinrc" \
        "$HOME/.config/plasmarc" \
        "$HOME/.config/kcminputrc" \
        "$HOME/.config/ksplashrc" \
        "$HOME/.config/kglobalshortcutsrc" \
        "$HOME/.config/plasmashellrc" \
        "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"; do
        if [[ -e "$latest$f" ]]; then
            mkdir -p "$(dirname "$f")"
            cp -a "$latest$f" "$f"
        fi
    done
    if [[ -d "$latest/etc/sddm.conf.d" ]]; then
        as_root cp -a "$latest/etc/sddm.conf.d/." /etc/sddm.conf.d/
    fi
    if [[ -f "$latest/var/lib/sddm/state.conf" ]]; then
        as_root cp -a "$latest/var/lib/sddm/state.conf" /var/lib/sddm/state.conf
    fi
    ok "Restored configs from $latest"
else
    warn "No backup directory found; configs were left as-is."
fi

refresh_ksycoca

if [[ $PURGE == 1 ]]; then
    warn "Deleting $STATE_DIR"
    rm -rf "$STATE_DIR"
fi

ok "Uninstall complete. Log out and back in."
