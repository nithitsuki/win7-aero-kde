#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/lib/common.sh"

if [[ -f "$ROOT/versions.lock" ]]; then
    # shellcheck disable=SC1091
    source "$ROOT/versions.lock"
fi

GADGETS_BRANCH="${GADGETS_BRANCH:-master}"
REINSTALL_GADGETS="${REINSTALL_GADGETS:-0}"
SRC="$STATE_DIR/src/aeroshell-gadgets"
manifest="$STATE_DIR/manifests/aeroshell-gadgets.manifest"
GADGET_DIR="/usr/share/plasma/plasmoids"
GADGETS=(clock cpu notes rssfeeds slideshow)

installed=1
for gadget in "${GADGETS[@]}"; do
    [[ -f "$GADGET_DIR/io.gitgud.catpswin56.gadgets.$gadget/metadata.json" ]] || installed=0
done

if [[ $installed == 1 && $REINSTALL_GADGETS != 1 && -f "$manifest" ]]; then
    ok "AeroShell gadgets are already installed; skipping (use --reinstall-gadgets to force)"
    exit 0
fi

log "Cloning/updating AeroShell gadgets (branch $GADGETS_BRANCH)"
mkdir -p "$(dirname "$SRC")"
if [[ ! -d "$SRC/.git" ]]; then
    git clone --branch "$GADGETS_BRANCH" \
        https://github.com/aeroshell-desktop/aeroshell-gadgets.git "$SRC" \
        2>&1 | tee -a "$LOG_FILE"
else
    git -C "$SRC" fetch --all --prune >/dev/null 2>&1 || true
    git -C "$SRC" checkout "$GADGETS_BRANCH" >/dev/null 2>&1 \
        || warn "Could not check out $GADGETS_BRANCH; using the existing checkout"
    git -C "$SRC" pull --ff-only >/dev/null 2>&1 \
        || warn "Could not fast-forward AeroShell gadgets; using the existing checkout"
fi

if [[ -n "${GADGETS_COMMIT:-}" ]]; then
    current="$(git -C "$SRC" rev-parse HEAD)"
    if [[ "$current" != "$GADGETS_COMMIT" ]]; then
        warn "AeroShell gadgets HEAD is $current; tested commit was $GADGETS_COMMIT. Continuing."
    fi
fi

log "Building AeroShell gadgets (system-wide install; sudo was cached by preflight)"
(
    cd "$SRC"
    export CMAKE_GENERATOR=Ninja
    export GIT_TERMINAL_PROMPT=0
    bash install.sh
) 2>&1 | tee -a "$LOG_FILE"

# The upstream installer does not keep its manifest, so save it for uninstall.
mkdir -p "$(dirname "$manifest")"
if [[ -f "$SRC/build/install_manifest.txt" ]]; then
    cp "$SRC/build/install_manifest.txt" "$manifest"
else
    warn "AeroShell gadgets install manifest not found; uninstall will remove the plasmoid directories directly."
fi

if [[ -f "$manifest" ]]; then
    manifest_missing=()
    while IFS= read -r installed_file || [[ -n "$installed_file" ]]; do
        [[ -z "$installed_file" || -e "$installed_file" ]] || manifest_missing+=("$installed_file")
    done < "$manifest"
    if [[ ${#manifest_missing[@]} -gt 0 ]]; then
        printf 'Files missing after AeroShell gadgets install:\n' >&2
        printf '  %s\n' "${manifest_missing[@]}" >&2
        die "AeroShell gadgets installation is incomplete. See $LOG_FILE."
    fi
fi

missing=()
for gadget in "${GADGETS[@]}"; do
    [[ -f "$GADGET_DIR/io.gitgud.catpswin56.gadgets.$gadget/metadata.json" ]] \
        || missing+=("$gadget")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    printf 'Missing gadgets after install:\n' >&2
    printf '  %s\n' "${missing[@]}" >&2
    die "AeroShell gadgets installation is incomplete. See $LOG_FILE."
fi

refresh_ksycoca
ok "AeroShell gadgets installed: ${GADGETS[*]}. Add them from the desktop's Add Widgets dialog."
