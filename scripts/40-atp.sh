#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/lib/common.sh"

# Tested commit is recorded for reference only; the upstream installer tracks
# the Plasma/6.8 branch because its component clones are not pinned.
if [[ -f "$ROOT/versions.lock" ]]; then
    # shellcheck disable=SC1091
    source "$ROOT/versions.lock"
fi

SRC="$STATE_DIR/src/aerothemeplasma"
REINSTALL_ATP="${REINSTALL_ATP:-0}"

if [[ -f /usr/share/plasma/look-and-feel/authui7/metadata.json ]] && [[ $REINSTALL_ATP != 1 ]]; then
    ok "AeroThemePlasma is already installed; skipping (use --reinstall-atp to force a rebuild)"
    exit 0
fi

log "Cloning/updating AeroThemePlasma (branch Plasma/6.8)"
mkdir -p "$(dirname "$SRC")"
if [[ ! -d "$SRC/.git" ]]; then
    git clone --branch Plasma/6.8 https://github.com/aeroshell-desktop/aerothemeplasma.git "$SRC" \
        2>&1 | tee -a "$LOG_FILE"
else
    git -C "$SRC" fetch --all --prune >/dev/null 2>&1 || true
    git -C "$SRC" checkout Plasma/6.8 >/dev/null 2>&1 || true
    git -C "$SRC" pull --ff-only >/dev/null 2>&1 || warn "Could not fast-forward ATP; using the existing checkout"
fi

if [[ -n "${ATP_COMMIT:-}" ]]; then
    current="$(git -C "$SRC" rev-parse HEAD)"
    if [[ "$current" != "$ATP_COMMIT" ]]; then
        warn "ATP HEAD is $current; tested commit was $ATP_COMMIT. Continuing with the branch head."
    fi
fi

log "Building AeroThemePlasma. This takes roughly 15-30 minutes; you may be prompted for sudo."
(
    cd "$SRC"
    export LIBEXEC_DIR=lib
    export CMAKE_GENERATOR=Ninja
    export GIT_TERMINAL_PROMPT=0
    bash install.sh
) 2>&1 | tee -a "$LOG_FILE"

required=(
    /usr/share/plasma/look-and-feel/authui7/metadata.json
    /usr/share/plasma/desktoptheme/Seven-Black/metadata.json
    /usr/share/plasma/shells/io.gitgud.wackyideas.desktop/metadata.json
    /usr/share/plasma/layout-templates/io.gitgud.wackyideas.taskbar/metadata.json
    /usr/share/sounds/Windows\ 7/index.theme
    /usr/share/icons/Windows\ 7\ Aero/index.theme
    /usr/share/sddm/themes/sddm-theme-mod/Main.qml
    /usr/share/wayland-sessions/aerothemeplasma.desktop
    /usr/share/kwin/scripts/smodpeekscript/metadata.json
    /usr/share/Kvantum/Windows7Aero
)
missing=()
for p in "${required[@]}"; do
    [[ -e "$p" ]] || missing+=("$p")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    printf 'Missing after ATP install:\n' >&2
    printf '  %s\n' "${missing[@]}" >&2
    die "ATP installation is incomplete. See $LOG_FILE."
fi

if ! pacman -Qkk libplasma 2>&1 | grep -q 'altered files'; then
    warn "Patched libplasma was not detected. ATP's dialog/Aero effects may be missing."
else
    ok "Patched libplasma detected"
fi

ok "AeroThemePlasma installed"
