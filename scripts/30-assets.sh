#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/lib/common.sh"

# Windows 7 Professional SP1 x86, English. This is the genuine Microsoft image.
# The hash check matters: archive.org has items with the same filename but a
# modified/repacked image.
ISO_URL="https://archive.org/download/en_windows_7_professional_with_sp1_x86_dvd_u_677056_201708/en_windows_7_professional_with_sp1_x86_dvd_u_677056.iso"
ISO_SHA1="d89937df3a9bc2ec1a1486195fd308cd3dade928"
ISO_NAME="win7-pro-x86.iso"

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
    log "Downloading Windows 7 ISO (~2.4 GB). This is the slow step."
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

log "Extracting fonts, sounds, cursors and icon DLLs"
rm -rf "$WORK/wim"
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
    >>"$LOG_FILE" 2>&1 || die "Could not extract the selected WIM paths"

[[ -d "$WORK/wim/1/Windows/Fonts" ]] || die "Fonts directory missing from the extracted WIM"

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
