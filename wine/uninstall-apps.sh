#!/usr/bin/env bash
# Remove the Windows 7 applications layer installed by install-apps.sh.
# The Wine prefix and the shared user folders are left in place.
set -euo pipefail

PFX="$HOME/.win7games-proton/pfx"
APPDIR="$PFX/drive_c/Program Files/Windows 7 Apps"
BINDIR="$HOME/.local/bin"
APPS_DESKTOP="$HOME/.local/share/applications"
ICON_ROOT="$HOME/.local/share/icons/hicolor"
SYS32="$PFX/drive_c/windows/system32"

APPS=(notepad wordpad paint calculator stickynotes taskmgr msconfig charmap magnify osk)

log() { printf '==> %s\n' "$*"; }

log "Removing launchers and icons"
for name in "${APPS[@]}"; do
  rm -f "$APPS_DESKTOP/win7-$name.desktop"
  for size in 256 48 32 16; do
    rm -f "$ICON_ROOT/${size}x${size}/apps/win7-$name.png"
  done
done

log "Restoring the Wine UIRibbon stub"
for f in uiribbon.dll uiribbonres.dll; do
  if [[ -e "$SYS32/$f.wine-backup" || -L "$SYS32/$f.wine-backup" ]]; then
    rm -f "$SYS32/$f"
    mv "$SYS32/$f.wine-backup" "$SYS32/$f"
  elif [[ "$f" == uiribbonres.dll ]]; then
    # Wine ships no uiribbonres.dll; if there is no backup, ours is the only one.
    rm -f "$SYS32/$f"
  fi
done

log "Removing application files"
rm -rf "$APPDIR"
rm -f "$BINDIR/win7app-run"

command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$ICON_ROOT" >/dev/null 2>&1 || true
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS_DESKTOP" >/dev/null 2>&1 || true
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1 || true

echo
echo "Removed. The Wine prefix and the shared folder symlinks were kept."
