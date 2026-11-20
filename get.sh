#!/usr/bin/env bash
# Fetch and run the Windows 7 conversion installer.
#
#   curl -fsSL https://raw.githubusercontent.com/nithitsuki/win7-aero-kde/main/get.sh | bash
#   curl -fsSL .../get.sh | bash -s -- --gui
set -euo pipefail

REPO_URL="${WIN7_AERO_REPO:-https://github.com/nithitsuki/win7-aero-kde.git}"
DEST="${WIN7_AERO_SRC:-${XDG_CACHE_HOME:-$HOME/.cache}/win7-aero/repo}"

# Running from a checkout: use it directly.
if [[ -f "./install.sh" && -d "./scripts" ]]; then
    exec ./install.sh "$@"
fi

command -v git >/dev/null || {
    echo "git is required to fetch the installer." >&2
    echo "Install it with: sudo pacman -S git" >&2
    exit 1
}

if [[ -d "$DEST/.git" ]]; then
    echo "Updating $DEST"
    git -C "$DEST" pull --ff-only
elif [[ -e "$DEST" ]]; then
    echo "$DEST exists but is not a git checkout." >&2
    echo "Remove it or set WIN7_AERO_SRC to another directory." >&2
    exit 1
else
    echo "Fetching the installer into $DEST"
    mkdir -p "$(dirname "$DEST")"
    git clone --depth 1 "$REPO_URL" "$DEST"
fi

exec "$DEST/install.sh" "$@"
