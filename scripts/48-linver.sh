#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/lib/common.sh"

if [[ -f "$ROOT/versions.lock" ]]; then
    # shellcheck disable=SC1091
    source "$ROOT/versions.lock"
fi

AUR="$STATE_DIR/src/linver-aur"
REINSTALL_LINVER="${REINSTALL_LINVER:-0}"

if pacman -Q linver >/dev/null 2>&1 && have linver && [[ $REINSTALL_LINVER != 1 ]]; then
    ok "LinVer is already installed; skipping (use --reinstall-linver to force)"
    exit 0
fi

if pacman -Q linver-bin >/dev/null 2>&1 || pacman -Q linver-git >/dev/null 2>&1; then
    if have linver; then
        ok "LinVer is already provided by an alternate AUR package; skipping"
        exit 0
    fi
    die "linver-bin or linver-git is installed but the linver binary is missing. Remove it first."
fi

log "Building LinVer from the AUR"
mkdir -p "$(dirname "$AUR")"
if [[ ! -d "$AUR/.git" ]]; then
    git clone https://aur.archlinux.org/linver.git "$AUR" 2>&1 | tee -a "$LOG_FILE"
else
    git -C "$AUR" pull --ff-only >/dev/null 2>&1 \
        || warn "Could not update the LinVer AUR checkout; using the existing one"
fi

(
    cd "$AUR"
    makepkg -si --noconfirm
) 2>&1 | tee -a "$LOG_FILE"

have linver || die "LinVer installed, but the linver binary is not on PATH. See $LOG_FILE."

installed_version="$(pacman -Q linver 2>/dev/null | awk '{print $2}' || true)"
installed_version="${installed_version:-unknown}"
if [[ -n "${LINVER_VERSION:-}" && "$installed_version" != "${LINVER_VERSION}-"* ]]; then
    warn "LinVer $installed_version is installed; tested version was $LINVER_VERSION."
fi

ok "LinVer installed ($installed_version). Run 'linver' to show the About Windows dialog."
