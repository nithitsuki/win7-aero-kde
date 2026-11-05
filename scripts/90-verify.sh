#!/usr/bin/env bash
# shellcheck disable=SC2016  # single-quoted bash -c checks intentionally run later
set -euo pipefail
source "$ROOT/lib/common.sh"

log "Verifying the setup"
failures=0

check() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        ok "$desc"
    else
        warn "FAIL: $desc"
        failures=$((failures + 1))
    fi
}

check "Caps Lock option is ctrl:nocaps" \
    grep -q 'ctrl:nocaps' <<< "$(kread --file "$HOME/.config/kxkbrc" --group Layout --key Options 2>/dev/null || true)"
check "ResetOldOptions is enabled" \
    grep -qx 'true' <<< "$(kread --file "$HOME/.config/kxkbrc" --group Layout --key ResetOldOptions 2>/dev/null || true)"
check "Segoe UI is installed" \
    bash -c "fc-match 'Segoe UI' | grep -qi segoeui"
check "Windows 7 fonts present" \
    bash -c "test -d /usr/share/fonts/win7 || fc-list | grep -qi 'Segoe UI'"
check "AeroThemePlasma look-and-feel" test -f /usr/share/plasma/look-and-feel/authui7/metadata.json
check "Seven-Black Plasma style" test -f /usr/share/plasma/desktoptheme/Seven-Black/metadata.json
check "ATP shell" test -f /usr/share/plasma/shells/io.gitgud.wackyideas.desktop/metadata.json
check "SMOD decoration plugin" bash -c \
    'test -f /usr/lib/qt6/plugins/org.kde.kdecoration3/org.smod.smod.so || test -f /usr/lib/qt6/plugins/org.kde.kdecoration2/org.smod.smod.so'
check "AeroThemePlasma session" test -f /usr/share/wayland-sessions/aerothemeplasma.desktop
check "SDDM theme installed" test -f /usr/share/sddm/themes/sddm-theme-mod/Main.qml
check "KDE icon theme" \
    bash -c '[[ "$(kreadconfig6 --file kdeglobals --group Icons --key Theme)" == "Windows 7 Aero" ]]'
check "KDE font" \
    bash -c '[[ "$(kreadconfig6 --file kdeglobals --group General --key font)" == Segoe* ]]'
check "SMOD window decoration" \
    bash -c '[[ "$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library)" == "org.smod.smod" ]]'
check "Aeroglassblur enabled" \
    bash -c '[[ "$(kreadconfig6 --file kwinrc --group Plugins --key aeroglassblurEnabled)" == true ]]'
check "Screenshot tool (Spectacle)" test -x /usr/bin/spectacle
check "Windows-key shortcut helper" test -x "$HOME/.local/bin/win7-shortcuts"
check "Windows-key shortcut autostart" test -f "$HOME/.config/autostart/win7-shortcuts.desktop"
check "Stock launcher no longer uses Meta" \
    bash -c '[[ "$(kreadconfig6 --file kglobalshortcutsrc --group plasmashell --key "activate application launcher")" == Alt+F1* ]]'
check "Command Prompt launcher" test -x "$HOME/.local/bin/cmd"
check "Command Prompt desktop entry" test -f "$HOME/.local/share/applications/cmd.desktop"
check "Command Prompt shell config" test -f "$HOME/.config/win7-cmd/bashrc"
check "Konsole color scheme" test -f "$HOME/.local/share/konsole/Win7CMD.colorscheme"
check "Original sounds installed" test -f "$HOME/.local/share/sounds/Windows 7 Original/index.theme"
check "Extracted icons" test -d "$STATE_DIR/extracted/icons/imageres/png"
check "Extracted cursors" test -d "$STATE_DIR/extracted/cursors"
check "Harmony wallpaper" bash -c "find '$STATE_DIR/wallpapers' -maxdepth 1 -name 'harmony-*.jpg' | grep -q ."

if command -v sddm >/dev/null 2>&1; then
    check "SDDM theme selected" \
        bash -c "sudo kreadconfig6 --file /etc/sddm.conf.d/kde_settings.conf --group Theme --key Current | grep -qx sddm-theme-mod"
    check "SDDM session selected" \
        bash -c "sudo grep -q 'aerothemeplasma.desktop' /var/lib/sddm/state.conf"
fi

echo
if [[ $failures -eq 0 ]]; then
    ok "All checks passed"
else
    warn "$failures check(s) failed. Review the output above and $LOG_FILE."
    exit 1
fi
