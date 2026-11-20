#!/usr/bin/env bash
# Install the Windows 7 games from the retail ISO.
#
# The games are extracted from the user's own image, their MUI resources are
# merged (Wine has no MUI redirection), and they are launched with Proton.
# No repackaged binaries and no fake activation DLL are used.
set -euo pipefail
source "$ROOT/lib/common.sh"

EXTRACT="$STATE_DIR/extracted"
SRC="${WIN7_GAMES_DIR:-$EXTRACT/games}"
PFX="${WIN7_PREFIX:-$HOME/.win7games-proton/pfx}"
export WINEPREFIX="$PFX"
GAMES_DEST="$PFX/drive_c/Program Files/Microsoft Games"
BINDIR="$HOME/.local/bin"
APPS_DESKTOP="$HOME/.local/share/applications"
ICON_ROOT="$HOME/.local/share/icons/hicolor"
SYS32="$PFX/drive_c/windows/system32"
SYSWOW="$PFX/drive_c/windows/syswow64"

find_proton() {
    if [[ -n "${PROTON_DIR:-}" && -x "$PROTON_DIR/files/bin/wine" ]]; then
        printf '%s\n' "$PROTON_DIR"; return 0
    fi
    local base d
    local -a cands=()
    for base in "$HOME/.local/share/Steam/steamapps/common" \
                "$HOME/.steam/root/steamapps/common" \
                "$HOME/.steam/steam/steamapps/common" \
                /d/SteamLibrary/steamapps/common \
                /c/SteamLibrary/steamapps/common; do
        [[ -d "$base" ]] || continue
        for d in "$base"/Proton*; do
            [[ -x "$d/files/bin/wine" ]] && cands+=("$d")
        done
    done
    [[ ${#cands[@]} -eq 0 ]] && return 1
    local stable
    stable=$(printf '%s\n' "${cands[@]}" | grep -E '/Proton [0-9]' | sort -V | tail -1)
    [[ -n "$stable" ]] && { printf '%s\n' "$stable"; return 0; }
    printf '%s\n' "${cands[@]}" | grep -E 'Experimental' | head -1 && return 0
    printf '%s\n' "${cands[0]}"
}

game_slug() {
    case "$1" in
        Solitaire)        echo "solitaire|Solitaire" ;;
        SpiderSolitaire)  echo "spidersolitaire|Spider Solitaire" ;;
        FreeCell)         echo "freecell|FreeCell" ;;
        Hearts)           echo "hearts|Hearts" ;;
        Minesweeper)      echo "minesweeper|Minesweeper" ;;
        Chess)            echo "chess|Chess Titans" ;;
        Mahjong)          echo "mahjong|Mahjong Titans" ;;
        "Purble Place")   echo "purble-place|Purble Place" ;;
        *)                echo "" ;;
    esac
}

if [[ ${DRY_RUN:-0} == 1 ]]; then
    log "DRY-RUN: install games from $SRC into $PFX"
    exit 0
fi

if [[ ! -d "$SRC/Microsoft Games" ]]; then
    warn "Game files are missing from $SRC."
    warn "Run the asset step first, or set WIN7_GAMES_DIR to an extracted copy."
    exit 0
fi

PROTON_DIR="$(find_proton)" || {
    warn "No working Proton runtime found; skipping the games."
    warn "Install Proton in Steam and run: ROOT=\"$ROOT\" bash \"$ROOT/scripts/49-games.sh\""
    exit 0
}
export LD_LIBRARY_PATH="$PROTON_DIR/files/lib64:$PROTON_DIR/files/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# --- Windows prefix -------------------------------------------------------

if [[ ! -d "$PFX/drive_c" ]]; then
    log "Initialising the Wine prefix at $PFX"
    mkdir -p "$PFX"
    "$PROTON_DIR/files/bin/wine" wineboot -u >>"$LOG_FILE" 2>&1 \
        || die "Could not initialise the Wine prefix"
fi

# The retail games reject Windows 10; a Windows 7 prefix runs them unmodified.
timeout 30 "$PROTON_DIR/files/bin/wine" winecfg -v win7 >>"$LOG_FILE" 2>&1 \
    || warn "Could not set the prefix to Windows 7"

mkdir -p "$SYS32" "$SYSWOW"

# Proton's wined3d needs these next to the builtin DLLs.
for f in "$PROTON_DIR/files/lib/vkd3d/x86_64-windows/"*.dll; do
    [[ -f "$f" ]] && cp -f "$f" "$SYS32/"
done
for f in "$PROTON_DIR/files/lib/vkd3d/i386-windows/"*.dll; do
    [[ -f "$f" ]] && cp -f "$f" "$SYSWOW/"
done

if [[ -f "$SRC/CardGames.dll" ]]; then
    if file "$SRC/CardGames.dll" | grep -q 'PE32+'; then
        cp -f "$SRC/CardGames.dll" "$SYS32/"
    else
        cp -f "$SRC/CardGames.dll" "$SYSWOW/"
    fi
fi

# --- Install files --------------------------------------------------------

log "Installing games into $GAMES_DEST"
rm -rf "$GAMES_DEST"
mkdir -p "$GAMES_DEST"
cp -a "$SRC/Microsoft Games/." "$GAMES_DEST/"

log "Merging MUI resources"
for dir in "$GAMES_DEST"/*/; do
    [[ -d "$dir" ]] || continue
    for exe in "$dir"*.exe; do
        [[ -f "$exe" ]] || continue
        base="$(basename "$exe")"
        mui="$(find "$dir" -maxdepth 2 -type f -iname "$base.mui" -print -quit)"
        [[ -n "$mui" ]] || { warn "No MUI for $base"; continue; }
        rel="${mui#"$dir"/}"
        ( cd "$dir" && uv run --quiet --no-project --with 'lief==0.17.1' --with pefile \
            python3 "$ROOT/lib/patch_mui.py" "$base" "$rel" >>"$LOG_FILE" 2>&1 ) \
            || warn "Could not merge $base.mui"
    done
done

# --- Launchers and icons --------------------------------------------------

log "Installing launchers"
mkdir -p "$APPS_DESKTOP" "$ICON_ROOT"
install -Dm755 "$ROOT/games/win7games-run" "$BINDIR/win7games-run"
rm -f "$APPS_DESKTOP"/win7games-*.desktop

for dir in "$GAMES_DEST"/*/; do
    name="$(basename "${dir%/}")"
    spec="$(game_slug "$name")"
    [[ -n "$spec" ]] || continue
    slug="${spec%%|*}"
    label="${spec#*|}"
    exe="$(find "$dir" -maxdepth 1 -type f -iname '*.exe' -print -quit)"
    [[ -n "$exe" ]] || continue
    exe_name="$(basename "$exe")"

    best=""; best_width=0
    for id in $(wrestool -l -t 14 "$exe" 2>/dev/null \
                  | grep -oE 'name=[0-9]+' | cut -d= -f2 | sort -nu); do
        ico="$STATE_DIR/tmp/$slug-$id.ico"
        mkdir -p "$STATE_DIR/tmp"
        wrestool -x -t 14 -n "$id" "$exe" >"$ico" 2>/dev/null || continue
        width="$(icotool -l "$ico" 2>/dev/null | grep -oE 'width=[0-9]+' | cut -d= -f2 | sort -n | tail -1)"
        if [[ -n "$width" && "$width" -gt "$best_width" ]]; then
            best="$ico"; best_width="$width"
        fi
    done

    if [[ -n "$best" ]]; then
        png="$STATE_DIR/tmp/$slug.png"
        icotool -x -w "$best_width" -h "$best_width" -o "$png" "$best" 2>/dev/null
        for size in 256 48 32 16; do
            mkdir -p "$ICON_ROOT/${size}x${size}/apps"
            magick "$png" -resize "${size}x${size}" "$ICON_ROOT/${size}x${size}/apps/win7games-$slug.png"
        done
        icon="win7games-$slug"
    else
        icon="applications-games"
    fi

    cat > "$APPS_DESKTOP/win7games-$slug.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$label
Comment=Windows 7 $label (from the retail ISO)
Exec=$BINDIR/win7games-run "$name/$exe_name"
Icon=$icon
Terminal=false
Categories=Game;
StartupNotify=true
EOF
done

rm -rf "$STATE_DIR/tmp"
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$ICON_ROOT" >/dev/null 2>&1 || true
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS_DESKTOP" >/dev/null 2>&1 || true
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1 || true

ok "Games installed. Resize a window once and the game remembers it."
