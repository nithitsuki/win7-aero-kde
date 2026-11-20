#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/lib/common.sh"

# The Plasma Trash widget cannot carry the name "Recycle Bin", and it cannot
# follow the Folder View icon size. A desktop icon can do both. A systemd user
# path unit rewrites the icon between empty and full.
DESKTOP_FILE="$HOME/Desktop/Recycle Bin.desktop"
UPDATER="$HOME/.local/bin/win7-recycle-bin"
UNIT_DIR="$HOME/.config/systemd/user"
TRASH_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/Trash"
OLD_MANIFEST="$STATE_DIR/manifests/desktop-trash.manifest"
MANIFEST="$STATE_DIR/manifests/desktop-recycle-bin.manifest"

log "Adding the Recycle Bin icon to the desktop"

if [[ ${DRY_RUN:-0} == 1 ]]; then
    log "DRY-RUN: would add the Recycle Bin icon and its icon updater"
    exit 0
fi

trash_is_full() {
    [[ -d "$TRASH_ROOT/files" ]] \
        && [[ -n "$(find "$TRASH_ROOT/files" -mindepth 1 -maxdepth 1 \
            -print -quit 2>/dev/null)" ]]
}

trash_icon() {
    if trash_is_full; then
        printf 'user-trash-full\n'
    else
        printf 'user-trash\n'
    fi
}

plasma_eval() {
    qdbus6 org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript "$1"
}

# Plasma runs a .desktop file on the desktop without an Open/Execute dialog
# only when the Folder View URL is exactly "desktop:/". That URL maps to the
# XDG desktop directory, so that directory must be the real Desktop folder.
# The AeroThemePlasma default is "desktop:/".
ensure_desktop_root() {
    # A bogus x-scheme-handler/file association makes KIO send every file URL to
    # the file manager before MIME detection. Desktop files then open in Dolphin
    # and fail with "Trying to open a file as a folder". The Association is not
    # needed: inode/directory already selects Dolphin.
    local mimeapps="$HOME/.config/mimeapps.list"
    if [[ -f "$mimeapps" ]] \
        && [[ -n "$(kread --file mimeapps.list --group 'Default Applications' --key x-scheme-handler/file 2>/dev/null || true)$(kread --file mimeapps.list --group 'Added Associations' --key x-scheme-handler/file 2>/dev/null || true)" ]]; then
        backup_file "$mimeapps"
        kwrite --file mimeapps.list --group 'Default Applications' --key x-scheme-handler/file --delete || true
        kwrite --file mimeapps.list --group 'Added Associations' --key x-scheme-handler/file --delete || true
        log "Removed the x-scheme-handler/file association (it breaks desktop files)"
    fi

    if ! has_plasma_session; then
        warn "Log in and re-run this script to align the Desktop folder and the Folder View URL."
        return 0
    fi

    local current
    current="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
    if [[ "$current" != "$HOME/Desktop" ]]; then
        if have xdg-user-dirs-update; then
            backup_file "$HOME/.config/user-dirs.dirs"
            xdg-user-dirs-update --set DESKTOP "$HOME/Desktop"
            log "Desktop folder set to $HOME/Desktop"
        else
            warn "Install xdg-user-dirs so the Desktop folder can point at $HOME/Desktop."
            return 0
        fi
    fi

    # Changing the URL before the folder would show the home directory. Check
    # the folder again before the URL change.
    current="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
    if [[ "$current" != "$HOME/Desktop" ]]; then
        warn "XDG_DESKTOP_DIR is $current, not $HOME/Desktop; leaving the Folder View URL alone."
        return 0
    fi

    local url
    url="$(plasma_eval '
var d = desktopsForActivity(currentActivity())[0];
d.currentConfigGroup = ["General"];
print(d.readConfig("url", ""));
' 2>>"$LOG_FILE" || true)"
    if [[ "$url" == "desktop:/" ]]; then
        return 0
    fi

    plasma_eval '
var desktops = desktopsForActivity(currentActivity());
for (var i = 0; i < desktops.length; i++) {
    desktops[i].currentConfigGroup = ["General"];
    desktops[i].writeConfig("url", "desktop:/");
    desktops[i].reloadConfig();
}
' >>"$LOG_FILE" 2>&1 || true
    sleep 1
    url="$(plasma_eval '
var d = desktopsForActivity(currentActivity())[0];
d.currentConfigGroup = ["General"];
print(d.readConfig("url", ""));
' 2>>"$LOG_FILE" || true)"
    if [[ "$url" == "desktop:/" ]]; then
        log "Folder View URL set to desktop:/"
    else
        warn "Could not set the Folder View URL to desktop:/; log in and re-run this script."
    fi
}

# Remove the Trash widget that earlier versions added. This is a migration,
# not a failure path: the icon below replaces the widget either way.
if [[ -f "$OLD_MANIFEST" ]]; then
    old_desktop="$(awk -F= '$1 == "DESKTOP_ID" { sub(/^[^=]*=/, ""); print; exit }' "$OLD_MANIFEST")"
    old_applet="$(awk -F= '$1 == "APPLET_ID" { sub(/^[^=]*=/, ""); print; exit }' "$OLD_MANIFEST")"
    if ! has_plasma_session; then
        warn "The old Trash widget is still on the desktop; log in and re-run this script to remove it."
    elif [[ ! "$old_desktop" =~ ^[0-9]+$ || ! "$old_applet" =~ ^[0-9]+$ ]]; then
        warn "No valid ids in $OLD_MANIFEST; remove the old Trash widget by hand."
    else
        removed="$(qdbus6 org.kde.plasmashell /PlasmaShell \
            org.kde.PlasmaShell.evaluateScript "
var desktop = desktopById($old_desktop);
var out = 'GONE';
if (desktop) {
    var widget = desktop.widgetById($old_applet);
    if (widget && widget.type === 'org.kde.plasma.trash') {
        widget.remove();
        out = 'REMOVED';
    } else if (widget) {
        out = 'FOREIGN ' + widget.type;
    }
}
print(out);
" 2>>"$LOG_FILE" || true)"
        case "$removed" in
            *REMOVED*)
                ok "Removed the old Trash widget"
                rm -f "$OLD_MANIFEST"
                ;;
            *GONE*)
                ok "The old Trash widget is already gone"
                rm -f "$OLD_MANIFEST"
                ;;
            *FOREIGN*)
                warn "Applet $old_applet is now another widget; leaving it alone."
                ;;
            *)
                warn "Could not remove the old Trash widget (${removed:-no reply}); remove it by hand."
                ;;
        esac
    fi
fi

ensure_desktop_root

# Desktop icons need the Folder View containment. The ATP shell ships its own
# Folder View fork, so accept both and warn only for a foreign containment.
if has_plasma_session; then
    containment="$(qdbus6 org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript '
var desktops = desktopsForActivity(currentActivity());
var target = null;
for (var i = 0; i < desktops.length; i++) {
    if (desktops[i].screen === 0) { target = desktops[i]; break; }
}
if (target === null && desktops.length > 0) { target = desktops[0]; }
print(target === null ? "" : target.type);
' 2>>"$LOG_FILE" || true)"
    if [[ -n "$containment" \
        && "$containment" != org.kde.plasma.folder \
        && "$containment" != io.gitgud.wackyideas.desktopcontainment ]]; then
        warn "The desktop containment is $containment, not Folder View; desktop icons may not show."
    fi
fi

icon="$(trash_icon)"
mkdir -p "$HOME/Desktop"
# The marker records who created the file. Back up anything else, including a
# symlink, so a user file or its target is never lost.
if [[ -e "$DESKTOP_FILE" || -L "$DESKTOP_FILE" ]] \
    && ! grep -qx 'X-Win7Aero-Installer=true' "$DESKTOP_FILE" 2>/dev/null; then
    backup_file "$DESKTOP_FILE"
    warn "Replaced $DESKTOP_FILE; the previous file is in $BACKUP_DIR"
fi
# Remove the old file first: a redirect follows a symlink and would overwrite
# the file the link points to.
rm -f "$DESKTOP_FILE"
# A Link opens trash:/ directly. An Application with Exec= would make Plasma
# ask "Open or Execute?" for an executable desktop file; choosing Open hands
# the .desktop file to Dolphin, which cannot open a file as a folder.
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Link
Name=Recycle Bin
Comment=Open the Trash
URL=trash:/
Icon=$icon
X-Win7Aero-Installer=true
EOF
chmod 755 "$DESKTOP_FILE"
log "Desktop icon: $DESKTOP_FILE ($icon)"

# The updater runs from systemd. It changes only the Icon= line, so every other
# key in the desktop file stays as written.
mkdir -p "$(dirname "$UPDATER")"
cat > "$UPDATER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Rewrite the Icon= line of the Recycle Bin desktop file when the home trash
# changes between empty and full.
desktop="${1:-$HOME/Desktop/Recycle Bin.desktop}"
trash="${XDG_DATA_HOME:-$HOME/.local/share}/Trash"

[[ -f "$desktop" ]] || exit 0

if [[ -d "$trash/files" ]] \
    && [[ -n "$(find "$trash/files" -mindepth 1 -maxdepth 1 \
        -print -quit 2>/dev/null)" ]]; then
    icon=user-trash-full
else
    icon=user-trash
fi

current="$(awk -F= '$1 == "Icon" { sub(/^[^=]*=/, ""); print; exit }' "$desktop")"
[[ "$current" == "$icon" ]] && exit 0

sed -i 's|^Icon=.*|Icon='"$icon"'|' "$desktop"
EOF
chmod 755 "$UPDATER"

mkdir -p "$UNIT_DIR"
cat > "$UNIT_DIR/win7-recycle-bin.service" <<'EOF'
[Unit]
Description=Recycle Bin desktop icon updater

[Service]
Type=oneshot
ExecStart=%h/.local/bin/win7-recycle-bin

[Install]
WantedBy=default.target
EOF
cat > "$UNIT_DIR/win7-recycle-bin.path" <<EOF
[Unit]
Description=Watch the home trash for the Recycle Bin icon

[Path]
PathChanged=$TRASH_ROOT/files
PathChanged=$TRASH_ROOT/info
Unit=win7-recycle-bin.service

[Install]
WantedBy=default.target
EOF

units_ok=1
if ! have systemctl; then
    warn "systemctl is not installed; the Recycle Bin icon will not update its state."
    units_ok=0
else
    systemctl --user daemon-reload 2>>"$LOG_FILE" || units_ok=0
    systemctl --user enable --now win7-recycle-bin.path 2>>"$LOG_FILE" || units_ok=0
    systemctl --user enable win7-recycle-bin.service 2>>"$LOG_FILE" || units_ok=0
    systemctl --user start win7-recycle-bin.service 2>>"$LOG_FILE" || units_ok=0
fi
if [[ $units_ok == 0 ]]; then
    warn "The Recycle Bin icon updater is installed but not active."
    warn "Log in and re-run: ROOT=\"$ROOT\" bash scripts/55-desktop-trash.sh"
fi

"$UPDATER" "$DESKTOP_FILE" \
    || warn "The Recycle Bin icon updater failed; run $UPDATER by hand."

mkdir -p "$(dirname "$MANIFEST")"
{
    printf 'DESKTOP_FILE=%s\n' "$DESKTOP_FILE"
    printf 'UPDATER=%s\n' "$UPDATER"
} > "$MANIFEST"

if [[ $units_ok == 1 ]]; then
    ok "Recycle Bin desktop icon installed; the icon updates its state automatically"
else
    ok "Recycle Bin desktop icon installed; its state updater is not active"
fi
