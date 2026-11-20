#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/lib/common.sh"

if [[ -f "$ROOT/versions.lock" ]]; then
    # shellcheck disable=SC1091
    source "$ROOT/versions.lock"
fi

SRC="$STATE_DIR/src/Windows-7-Better"
DEST="$HOME/.themes/Windows-7-Better"
THEME="Windows-7-Better"
REINSTALL_GTK="${REINSTALL_GTK:-0}"

gtk2_selected=0
grep -q '^gtk-theme-name="Windows-7-Better"' "$HOME/.gtkrc-2.0" 2>/dev/null && gtk2_selected=1

if [[ -f "$DEST/gtk-3.0/gtk.css" \
    && -f "$HOME/.config/gtk-4.0/gtk.css" \
    && ! -L "$HOME/.config/gtk-4.0/gtk.css" \
    && $gtk2_selected -eq 1 \
    && "$(kread --file gtk-3.0/settings.ini --group Settings --key gtk-theme-name 2>/dev/null || true)" == "$THEME" \
    && "$(kread --file gtk-4.0/settings.ini --group Settings --key gtk-theme-name 2>/dev/null || true)" == "$THEME" \
    && $REINSTALL_GTK -ne 1 ]]; then
    ok "Windows 7 Better GTK theme is already selected; skipping (use --reinstall-gtk to force)"
    exit 0
fi

log "Cloning/updating Windows 7 Better GTK theme"
mkdir -p "$(dirname "$SRC")"
if [[ ! -d "$SRC/.git" ]]; then
    git clone https://gitgud.io/Gamer95875/Windows-7-Better.git "$SRC" \
        2>&1 | tee -a "$LOG_FILE"
else
    git -C "$SRC" fetch --all --prune >/dev/null 2>&1 || true
    git -C "$SRC" pull --ff-only >/dev/null 2>&1 \
        || warn "Could not fast-forward Windows 7 Better; using the existing checkout"
fi

if [[ -n "${WINDOWS7_BETTER_COMMIT:-}" ]]; then
    current="$(git -C "$SRC" rev-parse HEAD)"
    if [[ "$current" != "$WINDOWS7_BETTER_COMMIT" ]]; then
        warn "Windows 7 Better HEAD is $current; tested commit was $WINDOWS7_BETTER_COMMIT. Continuing."
    fi
fi

backup_gtk_config() {
    # Only record the pre-Windows-7 state once. A reinstall would otherwise
    # overwrite the backup with the already-themed state.
    local candidate marker="$STATE_DIR/manifests/gtk-config.recorded"
    [[ -f "$marker" ]] && return 0
    if [[ -d "$BACKUP_ROOT" ]]; then
        while IFS= read -r candidate; do
            if [[ -e "$candidate$HOME/.config/gtk-3.0/settings.ini" \
                || -e "$candidate$HOME/.config/gtk-4.0" \
                || -e "$candidate$HOME/.gtkrc-2.0" ]]; then
                # Skip backups taken after a previous install; they already
                # select this theme and are not the pre-install state.
                if grep -qx 'gtk-theme-name=Windows-7-Better' \
                    "$candidate$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null; then
                    continue
                fi
                mkdir -p "$(dirname "$marker")"
                : > "$marker"
                return 0
            fi
        done < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r)
    fi
    backup_file \
        "$HOME/.config/gtk-3.0/settings.ini" \
        "$HOME/.config/gtk-4.0" \
        "$HOME/.gtkrc-2.0"
    mkdir -p "$(dirname "$marker")"
    : > "$marker"
}

backup_gtk_config

log "Installing Windows 7 Better GTK2/GTK3/GTK4 themes"
mkdir -p "$HOME/.themes" "$HOME/.config/gtk-4.0"
rm -rf "$DEST"
mkdir -p "$DEST"
cp -a "$SRC/index.theme" "$SRC/gtk-2.0" "$SRC/gtk-3.0" "$SRC/gtk-4.0" "$DEST/"
# The libadwaita override recipe commonly symlinks gtk.css, gtk-dark.css or
# assets into another theme. Remove the top-level links first: cp refuses to
# replace a symlink-to-directory, and copying through a file link would corrupt
# the other theme.
find "$HOME/.config/gtk-4.0" -mindepth 1 -maxdepth 1 -type l -delete
cp -a --remove-destination "$SRC/gtk-4.0/." "$HOME/.config/gtk-4.0/"

kwrite --file gtk-3.0/settings.ini --group Settings --key gtk-theme-name "$THEME"
kwrite --file gtk-4.0/settings.ini --group Settings --key gtk-theme-name "$THEME"
kwrite --file gtk-3.0/settings.ini --group Settings --key gtk-decoration-layout "menu:minimize,maximize,close"
kwrite --file gtk-4.0/settings.ini --group Settings --key gtk-decoration-layout "menu:minimize,maximize,close"

# GTK2 reads ~/.gtkrc-2.0, which is not an INI file.
if [[ -f "$HOME/.gtkrc-2.0" ]]; then
    if grep -q '^gtk-theme-name=' "$HOME/.gtkrc-2.0"; then
        sed -i 's|^gtk-theme-name=.*|gtk-theme-name="Windows-7-Better"|' "$HOME/.gtkrc-2.0"
    else
        printf '\ngtk-theme-name="Windows-7-Better"\n' >> "$HOME/.gtkrc-2.0"
    fi
else
    printf 'gtk-theme-name="Windows-7-Better"\n' > "$HOME/.gtkrc-2.0"
fi

refresh_ksycoca
ok "Windows 7 Better GTK theme installed. Restart GTK apps (including Firefox) to apply it."
