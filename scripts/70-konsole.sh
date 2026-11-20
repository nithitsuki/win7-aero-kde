#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/lib/common.sh"

log "Installing the Command Prompt lookalike"
have konsole || die "konsole is not installed (the dependency step should have installed it)."

install -Dm755 "$ROOT/assets/cmd"          "$HOME/.local/bin/cmd"
install -Dm755 "$ROOT/assets/win7-cmd-shell" "$HOME/.local/bin/win7-cmd-shell"
install -Dm644 "$ROOT/assets/win7-cmd-bashrc" "$HOME/.config/win7-cmd/bashrc"
install -Dm644 "$ROOT/assets/Win7CMD.colorscheme" "$HOME/.local/share/konsole/Win7CMD.colorscheme"
install -Dm644 "$ROOT/assets/win7-cmd.svg" "$HOME/.local/share/icons/hicolor/scalable/apps/win7-cmd.svg"

mkdir -p "$HOME/.local/share/applications"
sed "s|@HOME@|$HOME|g" "$ROOT/assets/cmd.desktop.in" > "$HOME/.local/share/applications/cmd.desktop"
chmod 644 "$HOME/.local/share/applications/cmd.desktop"

bash -n "$HOME/.config/win7-cmd/bashrc"
refresh_ksycoca
if have gtk-update-icon-cache; then
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
fi

ok "Command Prompt installed: run 'cmd' or use the app menu entry"
