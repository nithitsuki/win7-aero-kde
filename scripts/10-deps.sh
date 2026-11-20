#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/lib/common.sh"

# The list is intentionally explicit: ATP's INSTALL.md omits wayland-protocols,
# which CMake needs in addition to plasma-wayland-protocols.
PKGS=(
    git cmake extra-cmake-modules ninja base-devel curl unzip
    plasma-desktop plasma-workspace kwin plasma-nm plasma-pa
    qt6-base qt6-virtualkeyboard qt6-multimedia qt6-5compat qt6-wayland qt6-tools
    plasma-wayland-protocols wayland-protocols plasma5support
    vulkan-headers
    kunitconversion kholidays wimlib
    gtk3 gtk4
    kvantum sddm sddm-kcm konsole spectacle
    7zip aria2 icoutils imagemagick python tk uv
)

if [[ ${DRY_RUN:-0} == 1 ]]; then
    log "DRY-RUN: pacman -S --needed --noconfirm ${PKGS[*]}"
    exit 0
fi

log "Installing KDE/build dependencies (safe to re-run)"
as_root pacman -S --needed --noconfirm "${PKGS[@]}" 2>&1 | tee -a "$LOG_FILE"

ok "Dependencies installed"
