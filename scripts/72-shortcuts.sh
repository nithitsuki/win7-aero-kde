#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/lib/common.sh"

log "Configuring Windows key and screenshot shortcuts"

# Meta should open SevenStart, not the stock (absent) application launcher.
bind_launcher() {
    kwrite --file kglobalshortcutsrc --group plasmashell \
        --key 'activate application launcher' \
        'Alt+F1,Alt+F1,Activate Application Launcher'
}
bind_launcher

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

    # A runtime shortcut change makes KGlobalAccel rewrite kglobalshortcutsrc
    # 500 ms later from its in-memory copy. If this script runs inside an ATP
    # session, that copy can still hold Meta for the stock action. Wait past
    # the write, then restore Alt+F1 and confirm it survived.
    sleep 1
    restored=0
    for _ in 1 2 3; do
        bind_launcher
        if [[ "$(kread --file kglobalshortcutsrc --group plasmashell \
                --key 'activate application launcher' 2>/dev/null || true)" == Alt+F1* ]]; then
            restored=1
            break
        fi
        sleep 1
    done
    [[ $restored == 1 ]] || warn "Could not restore the Alt+F1 launcher binding; it applies on the next login."
fi

refresh_ksycoca
ok "Meta -> SevenStart configured; PrintScreen -> Spectacle"
