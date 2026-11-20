#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/lib/common.sh"

# Windows 7 Ultimate SP1 x64, English. This is the genuine Microsoft image.
# The hash check matters: archive.org has items with the same filename but a
# modified/repacked image.
ISO_URL="https://archive.org/download/en_windows_7_ultimate_with_sp1_x64_dvd_u_677332_202207/en_windows_7_ultimate_with_sp1_x64_dvd_u_677332.iso"
ISO_SHA1="36ae90defbad9d9539e649b193ae573b77a71c83"
ISO_NAME="win7-ultimate-x64.iso"

ISO="$CACHE_DIR/$ISO_NAME"
WORK="$CACHE_DIR/work"
WIM="$WORK/sources/install.wim"
EXTRACT="$STATE_DIR/extracted"
FONT_DIR="/usr/share/fonts/win7"
USER_ISO=0

mkdir -p "$CACHE_DIR" "$WORK" "$EXTRACT"

if [[ -n "${WIN7_ISO:-}" ]]; then
    [[ -f "$WIN7_ISO" ]] || die "WIN7_ISO does not exist: $WIN7_ISO"
    ISO="$WIN7_ISO"
    USER_ISO=1
    log "Using local Windows 7 ISO: $ISO"
fi

verify_iso() {
    local strict="$1" got
    got="$(sha1sum "$ISO" | awk '{print $1}')"
    if [[ "$got" != "$ISO_SHA1" ]]; then
        if [[ "$strict" == 1 ]]; then
            die "Windows 7 ISO SHA1 mismatch.
  expected: $ISO_SHA1
  got:      $got
Delete the file and retry. Beware archive.org items with the same filename but a modified image."
        else
            warn "Local ISO SHA1 differs from the tested image (got $got); using it anyway."
            return 0
        fi
    fi
    ok "Windows 7 ISO SHA1 verified"
}

if [[ $USER_ISO == 1 ]]; then
    verify_iso 0
elif [[ -f "$ISO" ]] && [[ "$(sha1sum "$ISO" | awk '{print $1}')" == "$ISO_SHA1" ]]; then
    ok "Reusing verified ISO cache: $ISO"
else
    rm -f "$ISO"
    log "Downloading Windows 7 ISO (~3.3 GB). This is the slow step."
    if have aria2c; then
        aria2c -x16 -s16 -k1M --file-allocation=none --allow-overwrite=true \
            --auto-file-renaming=false -d "$CACHE_DIR" -o "$ISO_NAME" "$ISO_URL" \
            2>&1 | tee -a "$LOG_FILE"
    else
        curl -fL --retry 5 --retry-delay 3 --continue-at - -o "$ISO" "$ISO_URL" \
            2>&1 | tee -a "$LOG_FILE"
    fi
    verify_iso 1
fi

log "Extracting install.wim from the ISO"
7z x -y -o"$WORK" "$ISO" sources/install.wim >>"$LOG_FILE" 2>&1 \
    || die "Could not extract sources/install.wim"

arch="$(wimlib-imagex info "$WIM" 2>/dev/null | awk -F': *' '/^Architecture:/{print $2; exit}' || true)"
if [[ -n "$arch" && "$arch" != x86_64 ]]; then
    warn "This image reports architecture $arch."
    warn "Use the 64-bit Ultimate image instead."
    warn "The 32-bit games render a black play area under Wine 11."
fi

log "Extracting fonts, sounds, cursors, icon DLLs and sidebar gadgets"
rm -rf "$WORK/wim"
# These paths come from the Windows 7 Ultimate SP1 x64 image. A missing
# gadget folder stops the install on purpose: the packages need the official art.
7z x -y -o"$WORK/wim" "$WIM" \
    '1/Windows/Fonts' \
    '1/Windows/Media' \
    '1/Windows/Cursors' \
    '1/Windows/explorer.exe' \
    '1/Windows/System32/imageres.dll' \
    '1/Windows/System32/shell32.dll' \
    '1/Windows/System32/ExplorerFrame.dll' \
    '1/Windows/System32/DDORes.dll' \
    '1/Windows/System32/accessibilitycpl.dll' \
    '1/Windows/System32/pifmgr.dll' \
    '1/Program Files/Windows Sidebar/Gadgets/PicturePuzzle.Gadget' \
    '1/Program Files/Windows Sidebar/Gadgets/Calendar.Gadget' \
    '1/Program Files/Windows Sidebar/Gadgets/Currency.Gadget' \
    >>"$LOG_FILE" 2>&1 || die "Could not extract the selected WIM paths"

[[ -d "$WORK/wim/1/Windows/Fonts" ]] || die "Fonts directory missing from the extracted WIM"

# Games live in the same image. Keep them next to the other assets so the game
# step can install them without downloading the ISO again.
if [[ ${SKIP_GAMES:-0} != 1 ]]; then
    # Starter lacks Chess and Mahjong; use the first image that has the full set.
    GAME_INDEX=""
    for i in $(wimlib-imagex info "$WIM" | sed -n 's/^Index: *//p'); do
        if wimlib-imagex dir "$WIM" "$i" --path="/Program Files/Microsoft Games/Chess" >/dev/null 2>&1; then
            GAME_INDEX="$i"; break
        fi
    done
    [[ -n "$GAME_INDEX" ]] || die "No WIM image with the full Windows 7 game set"
    log "Extracting Windows 7 games from image $GAME_INDEX"
    rm -rf "$EXTRACT/games"
    mkdir -p "$EXTRACT/games"
    7z x -y -o"$EXTRACT/games" "$WIM" \
        "$GAME_INDEX/Program Files/Microsoft Games" \
        "$GAME_INDEX/Windows/System32/CardGames.dll" >>"$LOG_FILE" 2>&1 \
        || die "Could not extract the Windows 7 games"
    mv "$EXTRACT/games/$GAME_INDEX/Program Files/Microsoft Games" "$EXTRACT/games/Microsoft Games"
    mv "$EXTRACT/games/$GAME_INDEX/Windows/System32/CardGames.dll" "$EXTRACT/games/CardGames.dll"
    rm -rf "$EXTRACT/games/$GAME_INDEX"
    [[ -d "$EXTRACT/games/Microsoft Games" ]] || die "Game files are missing after extraction"
    ok "Games extracted: $(find "$EXTRACT/games/Microsoft Games" -name '*.exe' | wc -l) executables"
fi

# The official gadgets carry their art inside the .Gadget folders. The QML ports
# in this repo ship no Microsoft images, so keep a copy for 46-sidebar-gadgets.sh.
SIDEBAR_WIM="$WORK/wim/1/Program Files/Windows Sidebar/Gadgets"
SIDEBAR_OUT="$EXTRACT/sidebar-gadgets"
rm -rf "$SIDEBAR_OUT"
mkdir -p "$SIDEBAR_OUT"

copy_sidebar_images() {
    local folder="$1" sub="$2" src
    src="$SIDEBAR_WIM/$folder"
    [[ -d "$src" ]] || die "Sidebar gadget folder is missing from install.wim: $folder"
    [[ -d "$src/$sub" ]] || die "Sidebar gadget image folder is missing from install.wim: $folder/$sub"
    mkdir -p "$SIDEBAR_OUT/$folder"
    cp -a "$src/$sub/." "$SIDEBAR_OUT/$folder/"
    if ! compgen -G "$SIDEBAR_OUT/$folder/*.png" >/dev/null; then
        die "Sidebar gadget images are missing after extraction: $folder/$sub"
    fi
}

log "Copying the official sidebar gadget art to $SIDEBAR_OUT"
copy_sidebar_images "PicturePuzzle.Gadget" "Images"
copy_sidebar_images "Calendar.Gadget" "images"
copy_sidebar_images "Currency.Gadget" "images"
ok "Sidebar gadget art extracted: $(find "$SIDEBAR_OUT" -name '*.png' | wc -l) PNG files"

log "Installing Windows 7 fonts into $FONT_DIR"
as_root install -d -m 755 "$FONT_DIR"
as_root cp -a "$WORK/wim/1/Windows/Fonts/." "$FONT_DIR/"
as_root fc-cache -f >/dev/null 2>&1 || true
ok "Fonts installed; Segoe UI faces visible: $(fc-list 2>/dev/null | grep -ci 'Segoe UI' || true)"

log "Extracting original sounds, icons and cursors to $EXTRACT"
mkdir -p \
    "$EXTRACT/sounds/Windows 7 Original/stereo" \
    "$EXTRACT/sounds/Windows 7 Original/schemes" \
    "$EXTRACT/cursors" \
    "$EXTRACT/icons"

find "$WORK/wim/1/Windows/Media" -maxdepth 1 -type f -iname '*.wav' \
    -exec cp -f {} "$EXTRACT/sounds/Windows 7 Original/stereo/" \;
for d in "$WORK/wim/1/Windows/Media"/*/; do
    [[ -d "$d" ]] || continue
    cp -a "$d" "$EXTRACT/sounds/Windows 7 Original/schemes/$(basename "$d")"
done

cat > "$EXTRACT/sounds/Windows 7 Original/index.theme" <<'EOF'
[Sound Theme]
Name=Windows 7 Original
Comment=Original Windows 7 sound scheme extracted from the retail ISO
Directories=stereo

[stereo]
OutputProfile=stereo
EOF

mkdir -p "$HOME/.local/share/sounds"
rm -rf "$HOME/.local/share/sounds/Windows 7 Original"
cp -a "$EXTRACT/sounds/Windows 7 Original" "$HOME/.local/share/sounds/"

cp -a "$WORK/wim/1/Windows/Cursors/." "$EXTRACT/cursors/"

ICON_OUT="$EXTRACT/icons"
rm -rf "$ICON_OUT"
mkdir -p "$ICON_OUT"

extract_icons() {
    local src="$1" name="$2"
    mkdir -p "$ICON_OUT/$name/ico" "$ICON_OUT/$name/png"
    wrestool -x -t 14 -o "$ICON_OUT/$name/ico" "$src" >/dev/null 2>&1 || true
    icotool -x -o "$ICON_OUT/$name/png" "$ICON_OUT/$name/ico"/*.ico >/dev/null 2>&1 || true
}

for f in imageres.dll shell32.dll ExplorerFrame.dll DDORes.dll accessibilitycpl.dll pifmgr.dll; do
    extract_icons "$WORK/wim/1/Windows/System32/$f" "${f%.dll}"
done
extract_icons "$WORK/wim/1/Windows/explorer.exe" "explorer"

icon_count="$(find "$ICON_OUT" -type f | wc -l)"
ok "Extracted $icon_count icon files, plus $(find "$EXTRACT/cursors" -type f | wc -l) cursors and $(find "$EXTRACT/sounds/Windows 7 Original/stereo" -type f | wc -l) WAVs"

if [[ ${KEEP_ISO:-0} == 1 ]]; then
    warn "Keeping ISO and extraction tree because --keep-iso was used: $ISO / $WORK"
else
    if [[ $USER_ISO == 0 ]]; then
        rm -f "$ISO"
    fi
    rm -rf "$WORK"
    log "Removed ISO and temporary WIM extraction tree"
fi
