#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/lib/common.sh"

log "Configuring SDDM"

if [[ ! -f /usr/share/sddm/themes/sddm-theme-mod/Main.qml ]]; then
    warn "sddm-theme-mod is not installed; skipping SDDM configuration."
    exit 0
fi
if [[ ! -f /usr/share/wayland-sessions/aerothemeplasma.desktop ]]; then
    warn "The AeroThemePlasma session file is missing; skipping SDDM session selection."
    exit 0
fi

backup_file /etc/sddm.conf.d

as_root kwriteconfig6 --file /etc/sddm.conf.d/kde_settings.conf \
    --group Theme --key Current sddm-theme-mod
as_root kwriteconfig6 --file /etc/sddm.conf.d/kde_settings.conf \
    --group Theme --key CursorTheme aero-drop
as_root kwriteconfig6 --file /etc/sddm.conf.d/kde_settings.conf \
    --group Theme --key Font "Segoe UI,9,-1,5,50,0,0,0,0,0"

if getent passwd sddm >/dev/null 2>&1; then
    as_root kwriteconfig6 --file /var/lib/sddm/state.conf \
        --group Last --key User "$USER"
    as_root kwriteconfig6 --file /var/lib/sddm/state.conf \
        --group Last --key Session /usr/share/wayland-sessions/aerothemeplasma.desktop
else
    warn "The sddm user does not exist; not touching /var/lib/sddm/state.conf."
fi

ok "SDDM set to sddm-theme-mod; AeroThemePlasma preselected (backup: ${BACKUP_DIR:-none})"
