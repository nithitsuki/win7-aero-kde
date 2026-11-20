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
check "AeroShell desktop gadgets" bash -c \
    'for g in clock cpu notes rssfeeds slideshow; do test -f "/usr/share/plasma/plasmoids/io.gitgud.catpswin56.gadgets.$g/metadata.json" || exit 1; done'
check "AeroShell gadget files" bash -c \
    'manifest="$STATE_DIR/manifests/aeroshell-gadgets.manifest"; [ ! -f "$manifest" ] || while IFS= read -r f || [ -n "$f" ]; do [ -z "$f" ] || [ -e "$f" ] || exit 1; done < "$manifest"'
check "Picture Puzzle icon" test -f "$HOME/.local/share/icons/hicolor/scalable/apps/io.github.win7aero.picturepuzzle.svg"
check "Picture Puzzle widget" bash -c \
    'd="$HOME/.local/share/plasma/plasmoids/io.github.win7aero.picturepuzzle"; test -f "$d/metadata.json" && test -f "$d/contents/images/background.png" && test -f "$d/contents/images/1.png"'
check "Calendar widget" bash -c \
    'd="$HOME/.local/share/plasma/plasmoids/io.github.win7aero.calendar"; test -f "$d/metadata.json" && test -f "$d/contents/images/calendar_double.png"'
check "Currency widget" bash -c \
    'd="$HOME/.local/share/plasma/plasmoids/io.github.win7aero.currency"; test -f "$d/metadata.json" && test -f "$d/contents/images/base-undocked-3.png"'
check "Recycle Bin desktop icon" bash -c \
    'f="$HOME/Desktop/Recycle Bin.desktop"; test -f "$f" && grep -qx "Type=Link" "$f" && grep -qx "Name=Recycle Bin" "$f" && grep -qx "URL=trash:/" "$f" && grep -qx "X-Win7Aero-Installer=true" "$f"'
check "Recycle Bin icon updater" bash -c \
    'test -x "$HOME/.local/bin/win7-recycle-bin" && test -f "$HOME/.config/systemd/user/win7-recycle-bin.service" && test -f "$HOME/.config/systemd/user/win7-recycle-bin.path" && { ! qdbus6 org.kde.KWin /KWin >/dev/null 2>&1 || systemctl --user is-enabled win7-recycle-bin.path >/dev/null 2>&1; }'
check "Recycle Bin icon state" bash -c \
    'trash="${XDG_DATA_HOME:-$HOME/.local/share}/Trash"; want=user-trash; if [ -d "$trash/files" ] && [ -n "$(find "$trash/files" -mindepth 1 -maxdepth 1 -print -quit)" ]; then want=user-trash-full; fi; have="$(awk -F= "\$1 == \"Icon\" { print \$2; exit }" "$HOME/Desktop/Recycle Bin.desktop")"; [ "$have" = "$want" ]'
check "Desktop folder" bash -c \
    '[[ "$(xdg-user-dir DESKTOP)" == "$HOME/Desktop" ]]'
check "Folder View URL" bash -c \
    'qdbus6 org.kde.KWin /KWin >/dev/null 2>&1 || exit 0; u="$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "var d=desktopsForActivity(currentActivity())[0]; d.currentConfigGroup=[\"General\"]; print(d.readConfig(\"url\", \"\"));" 2>/dev/null)"; [[ "$u" == desktop:/ ]]'
check "File scheme association" bash -c \
    '[[ -z "$(kreadconfig6 --file mimeapps.list --group "Default Applications" --key x-scheme-handler/file 2>/dev/null)" && -z "$(kreadconfig6 --file mimeapps.list --group "Added Associations" --key x-scheme-handler/file 2>/dev/null)" ]]'
check "Windows 7 Better GTK theme" test -f "$HOME/.themes/Windows-7-Better/gtk-3.0/gtk.css"
check "GTK3 theme selected" bash -c \
    '[[ "$(kreadconfig6 --file gtk-3.0/settings.ini --group Settings --key gtk-theme-name)" == Windows-7-Better ]]'
check "GTK4 theme selected" bash -c \
    '[[ "$(kreadconfig6 --file gtk-4.0/settings.ini --group Settings --key gtk-theme-name)" == Windows-7-Better ]]'
check "GTK2 theme selected" grep -q '^gtk-theme-name="Windows-7-Better"' "$HOME/.gtkrc-2.0"
check "GTK4 theme override" bash -c \
    'test -f "$HOME/.config/gtk-4.0/gtk.css" && test ! -L "$HOME/.config/gtk-4.0/gtk.css"'
check "LinVer" command -v linver
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
