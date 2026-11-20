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

[[ $EUID -ne 0 ]] || die "Do not run this as root. Run it as your normal desktop user."

if [[ ${PLASMA_DEFAULT_SHELL:-} == io.gitgud.wackyideas.desktop ]]; then
    warn "You are currently in the AeroThemePlasma shell. Log into a normal Plasma session before uninstalling."
fi

cat <<'EOF'
This will:
  - run AeroThemePlasma's uninstaller
  - remove the AeroShell desktop gadgets
  - remove the Picture Puzzle, Calendar and Currency widgets
  - remove the desktop Recycle Bin icon and its icon updater
  - remove the Windows 7 Better GTK theme and LinVer
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

log "Removing AeroShell desktop gadgets"
manifest="$STATE_DIR/manifests/aeroshell-gadgets.manifest"
if [[ -f "$manifest" ]]; then
    as_root xargs -a "$manifest" rm -f
fi
as_root rm -rf /usr/share/plasma/plasmoids/io.gitgud.catpswin56.gadgets.*
as_root ldconfig

# The official sidebar gadgets are per-user packages. The extracted art stays in
# STATE_DIR so a later install can reuse it.
log "Removing the Picture Puzzle, Calendar and Currency widgets"
rm -rf \
    "$HOME/.local/share/plasma/plasmoids/io.github.win7aero.picturepuzzle" \
    "$HOME/.local/share/plasma/plasmoids/io.github.win7aero.calendar" \
    "$HOME/.local/share/plasma/plasmoids/io.github.win7aero.currency"
rm -f "$HOME/.local/share/icons/hicolor/scalable/apps/io.github.win7aero.picturepuzzle.svg"
if have gtk-update-icon-cache; then
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
fi
refresh_ksycoca

# The Recycle Bin is a desktop icon plus a systemd user updater. The unit names
# belong to this repo, so remove them even when the manifest is missing. Use the
# fixed paths: the manifest only shows that the installer ran.
log "Removing the desktop Recycle Bin icon"
trash_manifest="$STATE_DIR/manifests/desktop-recycle-bin.manifest"
desktop_file="$HOME/Desktop/Recycle Bin.desktop"
icon_left=0

if have systemctl; then
    systemctl --user disable --now win7-recycle-bin.path 2>>"$LOG_FILE" \
        || warn "Could not stop win7-recycle-bin.path; do it by hand."
    systemctl --user disable win7-recycle-bin.service 2>>"$LOG_FILE" \
        || warn "Could not disable win7-recycle-bin.service; do it by hand."
else
    warn "systemctl not found; disable the Recycle Bin units by hand."
fi
rm -f "$HOME/.config/systemd/user/win7-recycle-bin.service" \
    "$HOME/.config/systemd/user/win7-recycle-bin.path" \
    "$HOME/.config/systemd/user/default.target.wants/win7-recycle-bin.service" \
    "$HOME/.config/systemd/user/default.target.wants/win7-recycle-bin.path"
if have systemctl; then
    systemctl --user daemon-reload 2>>"$LOG_FILE" \
        || warn "Could not reload the user systemd manager."
fi
rm -f "$HOME/.local/bin/win7-recycle-bin"
ok "Removed the Recycle Bin icon updater"

# Remove the desktop file only when this installer wrote it: the name and the
# marker must both match.
if [[ -e "$desktop_file" || -L "$desktop_file" ]]; then
    if grep -qx 'Name=Recycle Bin' "$desktop_file" 2>/dev/null \
        && grep -qx 'X-Win7Aero-Installer=true' "$desktop_file" 2>/dev/null; then
        rm -f "$desktop_file"
        ok "Removed the Recycle Bin desktop icon"
    else
        warn "$desktop_file is not the icon this installer created; leaving it alone."
        icon_left=1
    fi
fi

if [[ $icon_left == 0 ]]; then
    rm -f "$trash_manifest"
elif [[ -f "$trash_manifest" ]]; then
    warn "Keeping $trash_manifest; the desktop file is still in place."
fi

log "Removing Windows 7 Better GTK theme"
rm -rf "$HOME/.themes/Windows-7-Better"

log "Removing LinVer"
for pkg in linver-debug linver linver-bin linver-git; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
        as_root pacman -R --noconfirm "$pkg" || warn "Could not remove $pkg; do it manually."
    fi
done

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

# Find the newest backup directory that contains a given path. Empty backup
# directories from --verify-only are skipped by requiring the path to exist.
newest_backup_with() {
    local rel="$1" candidate
    while IFS= read -r candidate; do
        if [[ -e "$candidate$rel" || -L "$candidate$rel" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name '[0-9]*' 2>/dev/null | sort -r)
    return 1
}

restore_path() {
    local src="$1" f="$2"
    if [[ -d "$src$f" ]]; then
        rm -rf "$f"
        mkdir -p "$(dirname "$f")"
        cp -a "$src$f" "$f"
    else
        mkdir -p "$(dirname "$f")"
        cp -a "$src$f" "$f"
    fi
}

latest=""
if [[ -d "$BACKUP_ROOT" ]]; then
    # --verify-only creates an empty backup directory; skip directories that
    # contain no files or symlinks rather than restoring nothing.
    while IFS= read -r candidate; do
        if [[ -n "$(find "$candidate" \( -type f -o -type l \) -print -quit 2>/dev/null)" ]]; then
            latest="$candidate"
            break
        fi
    done < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name '[0-9]*' 2>/dev/null | sort -r)
fi
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
        if [[ -e "$latest$f" || -L "$latest$f" ]]; then
            restore_path "$latest" "$f"
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

# GTK settings are written later in the run than the KDE configs, so the newest
# backup may not contain them. Restore each path from the newest backup that has
# it. If no backup has ~/.config/gtk-4.0, that directory did not exist before
# the install; remove the files the GTK step added instead of leaving them.
for f in \
    "$HOME/.config/gtk-3.0/settings.ini" \
    "$HOME/.config/gtk-4.0" \
    "$HOME/.gtkrc-2.0"; do
    if gtk_src="$(newest_backup_with "$f")"; then
        restore_path "$gtk_src" "$f"
        ok "Restored $f from $gtk_src"
    fi
done

# When there is no backup, only remove files if the GTK step recorded that it
# ran. Without the marker the user already had Windows-7-Better selected, so
# these files are theirs and must be left alone.
if [[ -f "$STATE_DIR/manifests/gtk-config.recorded" && -d "$BACKUP_ROOT" ]]; then
    if ! newest_backup_with "$HOME/.config/gtk-4.0" >/dev/null; then
        gtk4_src="$STATE_DIR/src/Windows-7-Better/gtk-4.0"
        if [[ -d "$gtk4_src" ]]; then
            log "Removing the GTK4 override files added by the installer"
            while IFS= read -r -d '' entry; do
                rm -rf -- "${HOME:?}/.config/gtk-4.0/${entry#"$gtk4_src"/}"
            done < <(find "$gtk4_src" -mindepth 1 -maxdepth 1 -print0)
            # settings.ini is written by the installer, not shipped with the theme.
            rm -f "$HOME/.config/gtk-4.0/settings.ini"
            rmdir "$HOME/.config/gtk-4.0" 2>/dev/null || true
        elif [[ -d "$HOME/.config/gtk-4.0" ]]; then
            warn "GTK theme source not found; remove the Windows 7 Better files from ~/.config/gtk-4.0 by hand."
        fi
    fi

    # Same for the GTK3 settings file and ~/.gtkrc-2.0: no backup means the
    # installer created them, so remove them if they still select this theme.
    if ! newest_backup_with "$HOME/.config/gtk-3.0/settings.ini" >/dev/null \
        && grep -qx 'gtk-theme-name=Windows-7-Better' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null; then
        rm -f "$HOME/.config/gtk-3.0/settings.ini"
    fi
    if ! newest_backup_with "$HOME/.gtkrc-2.0" >/dev/null \
        && grep -qx 'gtk-theme-name="Windows-7-Better"' "$HOME/.gtkrc-2.0" 2>/dev/null \
        && [[ -z "$(grep -v -e '^gtk-theme-name="Windows-7-Better"$' -e '^$' "$HOME/.gtkrc-2.0")" ]]; then
        rm -f "$HOME/.gtkrc-2.0"
    fi
fi

if [[ -x "$ROOT/games/uninstall-games.sh" ]]; then
    log "Removing the Windows 7 games"
    bash "$ROOT/games/uninstall-games.sh" || warn "Could not remove the games"
fi

refresh_ksycoca

if [[ $PURGE == 1 ]]; then
    warn "Deleting $STATE_DIR"
    rm -rf "$STATE_DIR"
fi

ok "Uninstall complete. Log out and back in."
