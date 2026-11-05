#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/lib/common.sh"

log "Preflight checks"

[[ $EUID -ne 0 ]] || die "Do not run this as root. Run it as your normal desktop user."
[[ -f /etc/arch-release ]] || {
    if [[ ${FORCE:-0} == 1 ]]; then
        warn "Non-Arch system detected; continuing because --force was passed."
    else
        die "This installer targets Arch Linux. Use --force only if you know the dependencies are present."
    fi
}

if ! df -Pk / | awk 'NR==2 { exit ($4 < 8*1024*1024) }'; then
    die "At least 8 GB free disk space is required."
fi

if ! sudo -n true 2>/dev/null; then
    log "Requesting sudo once for the system-level steps"
    sudo -v || die "sudo is required to install packages, ATP and fonts."
fi

if ! curl -fsI --max-time 8 https://github.com >/dev/null 2>&1; then
    warn "Could not reach github.com. Package/ISO downloads may fail."
fi

for cmd in git cmake ninja pacman kwriteconfig6 kreadconfig6; do
    have "$cmd" || warn "Missing command: $cmd (the dependency step will install it if available)"
done

apply_xauthority

ok "Preflight complete"
