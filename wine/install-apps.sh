#!/usr/bin/env bash
# Install genuine Windows 7 utilities from the retail ISO into the Wine prefix.
#
# The ISO is hash-verified before anything is extracted. No files come from
# repackaging sites. See ../docs/WIN7-APPS.md.
#
# Usage: install-apps.sh /path/to/Windows7.iso
set -euo pipefail

ISO="${1:-${WIN7_ISO:-}}"
[[ -n "$ISO" ]] || { echo "Usage: $0 /path/to/Windows7.iso (or set WIN7_ISO)" >&2; exit 2; }
ISO_SHA256="${WIN7_ISO_SHA256:-36f4fa2416d0982697ab106e3a72d2e120dbcdb6cc54fd3906d06120d0653808}"
WIM_INDEX="${WIN7_WIM_INDEX:-1}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORK="${XDG_CACHE_HOME:-$HOME/.cache}/win7apps"
PFX="$HOME/.win7games-proton/pfx"
APPDIR="$PFX/drive_c/Program Files/Windows 7 Apps"
BINDIR="$HOME/.local/bin"
APPS_DESKTOP="$HOME/.local/share/applications"
ICON_ROOT="$HOME/.local/share/icons/hicolor"

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

PROTON_DIR="$(find_proton)" || die "No working Proton runtime found in the Steam libraries"
export LD_LIBRARY_PATH="$PROTON_DIR/files/lib64:$PROTON_DIR/files/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Apps that start under Wine 11. The others are installed for future Wine
# versions but get no launcher. See ../docs/WIN7-APPS.md.
SUPPORTED="notepad wordpad paint osk"

# name | exe | desktop name | mime types
APPS=(
  "notepad|notepad.exe|Notepad|text/plain;"
  "wordpad|wordpad.exe|WordPad|application/rtf;application/msword;"
  "paint|mspaint.exe|Paint|image/bmp;image/png;image/jpeg;"
  "calculator|calc.exe|Calculator|"
  "stickynotes|StikyNot.exe|Sticky Notes|"
  "taskmgr|taskmgr.exe|Task Manager|"
  "msconfig|msconfig.exe|System Configuration|"
  "charmap|charmap.exe|Character Map|"
  "magnify|Magnify.exe|Magnifier|"
  "osk|osk.exe|On-Screen Keyboard|"
)

log() { printf '==> %s\n' "$*"; }
die() { printf '[error] %s\n' "$*" >&2; exit 1; }
supported() { [[ " $SUPPORTED " == *" $1 "* ]]; }

[[ -f "$ISO" ]] || die "ISO not found: $ISO"
log "Verifying ISO SHA-256"
got="$(sha256sum "$ISO" | awk '{print $1}')"
[[ "$got" == "$ISO_SHA256" ]] || die "ISO hash mismatch:
  expected $ISO_SHA256
  got      $got"

for tool in wimlib-imagex 7z wrestool icotool magick uv; do
  command -v "$tool" >/dev/null || die "$tool is required"
done

mkdir -p "$WORK" "$APPDIR"
if [[ ! -d "$PFX/drive_c" ]]; then
  log "Initialising the Wine prefix at $PFX"
  mkdir -p "$PFX"
  WINEPREFIX="$PFX" "$PROTON_DIR/files/bin/wine" wineboot -u >/dev/null 2>&1 \
    || die "Could not initialise the Wine prefix"
fi
WIM="${WIN7_WIM:-$WORK/sources/install.wim}"
if [[ ! -f "$WIM" ]]; then
  log "Extracting install.wim from the ISO"
  7z x -y -o"$WORK" "$ISO" sources/install.wim >/dev/null
  WIM="$WORK/sources/install.wim"
fi

app_dir() {
  case "$1" in
    wordpad) echo "/Program Files/Windows NT/Accessories" ;;
    *)       echo "/Windows/System32" ;;
  esac
}

paths=()
for spec in "${APPS[@]}"; do
  IFS='|' read -r name exe _ _ <<<"$spec"
  d="$(app_dir "$name")"
  paths+=("$d/$exe" "$d/en-US/$exe.mui")
done
paths+=("/Windows/System32/UIRibbon.dll" "/Windows/System32/UIRibbonRes.dll"
        "/Windows/System32/mfc42u.dll" "/Windows/System32/dui70.dll"
        "/Windows/System32/duser.dll" "/Windows/System32/pcwum.dll"
        "/Windows/System32/getuname.dll" "/Windows/System32/msswch.dll"
        "/Windows/System32/wmsgapi.dll")

SRC="$WORK/apps"
rm -rf "$SRC"
mkdir -p "$SRC"
log "Extracting applications from WIM image $WIM_INDEX"
wimlib-imagex extract "$WIM" "$WIM_INDEX" --nullglob --dest-dir "$SRC" "${paths[@]}" \
  >/dev/null 2>"$WORK/extract.err" || { cat "$WORK/extract.err" >&2; die "WIM extraction failed"; }

log "Installing application files"
for spec in "${APPS[@]}"; do
  IFS='|' read -r name exe _ _ <<<"$spec"
  [[ -f "$SRC/$exe" ]] || { echo "  skip $name ($exe not in image)"; continue; }

  dest="$APPDIR/$name"
  mkdir -p "$dest"
  cp -f "$SRC/$exe" "$dest/$exe"

  if [[ -f "$SRC/$exe.mui" ]]; then
    cp -f "$SRC/$exe.mui" "$dest/$exe.mui"
    uv run --quiet --no-project --with 'lief==0.17.1' --with pefile \
      python3 "$SCRIPT_DIR/../lib/patch_mui.py" "$dest/$exe" "$dest/$exe.mui" >/dev/null
    rm -f "$dest/$exe.mui"
  fi

  supported "$name" || echo "  $name installed, not launchable under Wine 11"
done

# Shared DLLs the applications import from the Windows installation.
log "Installing shared DLLs"
copy_dll() {
  local app="$1" dll="$2"
  [[ -f "$SRC/$dll" && -d "$APPDIR/$app" ]] || return 0
  cp -f "$SRC/$dll" "$APPDIR/$app/$dll"
}
for app in wordpad paint msconfig; do copy_dll "$app" mfc42u.dll; done
for app in stickynotes magnify; do copy_dll "$app" dui70.dll; done
copy_dll magnify duser.dll
copy_dll taskmgr pcwum.dll
copy_dll charmap getuname.dll
for dll in duser.dll dui70.dll msswch.dll wmsgapi.dll; do copy_dll osk "$dll"; done

# Share the user's real folders with the prefix so Dolphin and Wine's
# Open/Save dialogs operate on the same files.
USERDIR=""
for d in "$PFX/drive_c/users"/*/; do
  [[ "$(basename "$d")" == Public ]] && continue
  [[ -d "$d/AppData" ]] && { USERDIR="${d%/}"; break; }
done
if [[ -n "$USERDIR" ]]; then
  for name in Desktop Documents Downloads Music Pictures Videos; do
    src="$USERDIR/$name"; dst="$HOME/$name"
    mkdir -p "$dst"
    [[ -L "$src" ]] && continue
    if [[ ! -e "$src" ]]; then
      ln -s "$dst" "$src"
    elif [[ -d "$src" && -z "$(ls -A "$src")" ]]; then
      rmdir "$src"; ln -s "$dst" "$src"
    else
      echo "  note: $src is not empty; link it to $dst manually"
    fi
  done
fi

# WordPad and Paint use the Windows Ribbon. Wine ships only a stub uiribbon.dll,
# so install the real one and keep the stub as *.wine-backup.
SYS32="$PFX/drive_c/windows/system32"
for f in UIRibbon.dll UIRibbonRes.dll; do
  [[ -f "$SRC/$f" ]] || continue
  low="$(printf '%s' "$f" | tr 'A-Z' 'a-z')"
  if [[ -e "$SYS32/$low" || -L "$SYS32/$low" ]]; then
    if [[ ! -e "$SYS32/$low.wine-backup" && ! -L "$SYS32/$low.wine-backup" ]]; then
      cp -a "$SYS32/$low" "$SYS32/$low.wine-backup"
    fi
    rm -f "$SYS32/$low"
  fi
  cp -f "$SRC/$f" "$SYS32/$low"
done

log "Installing launchers and icons"
install -Dm755 "$SCRIPT_DIR/win7app-run" "$BINDIR/win7app-run"

for spec in "${APPS[@]}"; do
  IFS='|' read -r name exe label mimes <<<"$spec"
  launcher="$APPS_DESKTOP/win7-$name.desktop"

  if ! supported "$name" || [[ ! -f "$APPDIR/$name/$exe" ]]; then
    rm -f "$launcher"
    continue
  fi

  # Use the icon embedded in the Windows binary.
  best=""; best_width=0
  for id in $(wrestool -l -t 14 "$APPDIR/$name/$exe" 2>/dev/null \
                | grep -oE 'name=[0-9]+' | cut -d= -f2 | sort -nu); do
    ico="$WORK/$name-$id.ico"
    wrestool -x -t 14 -n "$id" "$APPDIR/$name/$exe" >"$ico" 2>/dev/null || continue
    width="$(icotool -l "$ico" 2>/dev/null | grep -oE 'width=[0-9]+' | cut -d= -f2 | sort -n | tail -1)"
    if [[ -n "$width" && "$width" -gt "$best_width" ]]; then
      best="$ico"; best_width="$width"
    fi
  done

  if [[ -n "$best" ]]; then
    png="$WORK/$name.png"
    icotool -x -w "$best_width" -h "$best_width" -o "$png" "$best" 2>/dev/null
    for size in 256 48 32 16; do
      mkdir -p "$ICON_ROOT/${size}x${size}/apps"
      magick "$png" -resize "${size}x${size}" "$ICON_ROOT/${size}x${size}/apps/win7-$name.png"
    done
    icon="win7-$name"
  else
    icon="application-x-executable"
  fi

  cat > "$launcher" <<EOF
[Desktop Entry]
Type=Application
Name=$label
Comment=Windows 7 $label (from the retail ISO)
Exec=$BINDIR/win7app-run $name $exe %F
Icon=$icon
Terminal=false
Categories=Utility;
$( [[ -n "$mimes" ]] && echo "MimeType=$mimes" )
StartupNotify=true
EOF
done

log "Refreshing caches"
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$ICON_ROOT" >/dev/null 2>&1 || true
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS_DESKTOP" >/dev/null 2>&1 || true
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1 || true

[[ ${KEEP_WIM:-0} == 1 ]] || rm -rf "$WORK"

echo
echo "Applications: $APPDIR"
echo "Launchers:    $APPS_DESKTOP/win7-*.desktop"
echo "Working:      $SUPPORTED"
echo "Other apps are installed for future Wine versions but have no launcher."
