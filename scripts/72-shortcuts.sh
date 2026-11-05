#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/lib/common.sh"

log "Configuring Windows key and screenshot shortcuts"

# Meta should open SevenStart, not the stock (absent) application launcher.
kwrite --file kglobalshortcutsrc --group plasmashell \
    --key 'activate application launcher' \
    'Alt+F1,Alt+F1,Activate Application Launcher'

install -Dm755 "$ROOT/assets/win7-shortcuts" "$HOME/.local/bin/win7-shortcuts"
mkdir -p "$HOME/.config/autostart"
sed "s|@HOME@|$HOME|g" "$ROOT/assets/win7-shortcuts.desktop.in" \
    > "$HOME/.config/autostart/win7-shortcuts.desktop"
chmod 644 "$HOME/.config/autostart/win7-shortcuts.desktop"

# Spectacle's desktop file ships X-KDE-Shortcuts=Print and registers itself
# with KGlobalAccel. Installing it is the whole PrintScreen setup.
if ! have spectacle; then
    warn "spectacle is not installed; PrintScreen will not work."
fi

if has_plasma_session; then
    "$HOME/.local/bin/win7-shortcuts" || true
fi

refresh_ksycoca
ok "Meta -> SevenStart configured; PrintScreen -> Spectacle"
