#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/lib/common.sh"

REINSTALL_SIDEBAR_GADGETS="${REINSTALL_SIDEBAR_GADGETS:-0}"
ART_ROOT="$STATE_DIR/extracted/sidebar-gadgets"
DEST_ROOT="$HOME/.local/share/plasma/plasmoids"

# Header-only identify returns success on the corrupt spinner, so ask for the
# geometry. That forces ImageMagick to decode the image data.
png_decodes() {
    identify -format '%wx%h' "$1" >/dev/null 2>&1
}

# The official Currency spinner has an invalid pAni chunk. A PNG chunk type
# needs an uppercase third letter, so Qt rejects the file. Drop that chunk and
# keep every other byte.
sanitize_png() {
    local png="$1"
    [[ -f "$png" ]] || return 0
    if ! have python3; then
        die "python3 is required to strip the invalid pAni chunk from the official Currency spinner. Install python3 and retry."
    fi
    python3 - "$png" <<'PY'
import struct
import sys

path = sys.argv[1]
data = open(path, "rb").read()
if not data.startswith(b"\x89PNG\r\n\x1a\n"):
    sys.exit(0)
out = [data[:8]]
i = 8
while i + 12 <= len(data):
    length = struct.unpack(">I", data[i:i + 4])[0]
    kind = data[i + 4:i + 8]
    end = i + 12 + length
    if end > len(data):
        break
    if kind != b"pAni":
        out.append(data[i:end])
    i = end
open(path, "wb").write(b"".join(out))
PY
    if ! have identify; then
        die "ImageMagick identify is required to check the repaired Currency spinner. Install imagemagick and retry."
    fi
    if ! png_decodes "$png"; then
        die "The repaired Currency spinner still does not decode: $png"
    fi
}

# Package name, the .Gadget folder that 30-assets.sh keeps, and the image that
# proves the package is complete.
NAMES=(picturepuzzle calendar currency)
FOLDERS=(PicturePuzzle.Gadget Calendar.Gadget Currency.Gadget)
KEY_IMAGES=(background.png calendar_double.png base-undocked-3.png)

if [[ ${DRY_RUN:-0} == 1 ]]; then
    log "DRY-RUN: would install sidebar gadgets ${NAMES[*]} to $DEST_ROOT"
    exit 0
fi

for i in "${!NAMES[@]}"; do
    name="${NAMES[$i]}"
    folder="${FOLDERS[$i]}"
    key_image="${KEY_IMAGES[$i]}"
    src="$ROOT/gadgets/$name"
    dest="$DEST_ROOT/io.github.win7aero.$name"
    art="$ART_ROOT/$folder"

    [[ -d "$src" ]] || die "Sidebar gadget package source is missing: $src"

    installed=1
    if [[ $REINSTALL_SIDEBAR_GADGETS == 1 \
        || ! -f "$dest/metadata.json" \
        || ! -f "$dest/contents/images/$key_image" ]]; then
        installed=0
    fi
    # A previous run can fail after it writes the package but before the spinner
    # is repaired. Do not skip that package: install again so the art is fixed.
    if [[ $installed == 1 && $name == currency ]] \
        && ! png_decodes "$dest/contents/images/activity16v.png"; then
        installed=0
    fi
    if [[ $installed == 1 ]]; then
        ok "$name sidebar gadget is already installed; skipping (use --reinstall-sidebar-gadgets to force)"
        continue
    fi

    if [[ ! -d "$art" ]]; then
        die "Official gadget art is missing. Run ./install.sh without --skip-assets so 30-assets.sh extracts it from the Windows 7 ISO."
    fi

    # The official folders use Images for Picture Puzzle and images for Calendar
    # and Currency. Accept both names, and a flat folder, so the copy stays safe.
    if [[ -d "$art/Images" ]]; then
        image_dir="$art/Images"
    elif [[ -d "$art/images" ]]; then
        image_dir="$art/images"
    else
        image_dir="$art"
    fi
    if ! compgen -G "$image_dir/*.png" >/dev/null; then
        die "Official gadget art is missing. Run ./install.sh without --skip-assets so 30-assets.sh extracts it from the Windows 7 ISO."
    fi

    log "Installing the $name sidebar gadget"
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -a "$src/." "$dest/"
    mkdir -p "$dest/contents/images"
    cp -f "$image_dir"/*.png "$dest/contents/images/"
    sanitize_png "$dest/contents/images/activity16v.png"

    [[ -f "$dest/metadata.json" ]] \
        || die "Sidebar gadget $name has no metadata.json after install"
    [[ -f "$dest/contents/images/$key_image" ]] \
        || die "Sidebar gadget $name is missing its key image: contents/images/$key_image"
    [[ -n "$(find "$dest" -mindepth 1 -print -quit)" ]] \
        || die "Sidebar gadget $name installed to an empty directory"
done

# The widget explorer uses the icon theme, so install the custom icon into the
# per-user hicolor theme. The Windows 7 Aero theme inherits hicolor.
ICON_SRC="$ROOT/assets/icons/io.github.win7aero.picturepuzzle.svg"
ICON_DEST="$HOME/.local/share/icons/hicolor/scalable/apps/io.github.win7aero.picturepuzzle.svg"
if [[ -f "$ICON_SRC" ]]; then
    install -Dm644 "$ICON_SRC" "$ICON_DEST"
    if have gtk-update-icon-cache; then
        gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
    fi
else
    warn "Picture Puzzle icon is missing from the repo: $ICON_SRC"
fi

refresh_ksycoca
ok "Sidebar gadgets installed: ${NAMES[*]}. Add them from the desktop's Add Widgets dialog."
