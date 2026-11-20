#!/usr/bin/env bash
# Remove the games installed by scripts/49-games.sh.
# The Wine prefix and saved games are left in place.
set -euo pipefail

PFX="${WIN7_PREFIX:-$HOME/.win7games-proton/pfx}"
GAMES_DEST="$PFX/drive_c/Program Files/Microsoft Games"
BINDIR="$HOME/.local/bin"
APPS_DESKTOP="$HOME/.local/share/applications"
ICON_ROOT="$HOME/.local/share/icons/hicolor"

SLUGS=(solitaire spidersolitaire freecell hearts minesweeper chess mahjong purble-place)

log() { printf '==> %s\n' "$*"; }

log "Removing launchers and icons"
for slug in "${SLUGS[@]}"; do
    rm -f "$APPS_DESKTOP/win7games-$slug.desktop"
    for size in 256 48 32 16; do
        rm -f "$ICON_ROOT/${size}x${size}/apps/win7games-$slug.png"
    done
done

log "Removing game files"
rm -rf "$GAMES_DEST"
rm -f "$BINDIR/win7games-run"

command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$ICON_ROOT" >/dev/null 2>&1 || true
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS_DESKTOP" >/dev/null 2>&1 || true
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1 || true

echo
echo "Removed. The Wine prefix and saved games were kept."
