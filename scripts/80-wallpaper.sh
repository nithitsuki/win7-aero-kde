#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/lib/common.sh"

WALLPAPER_URL='https://static.wikitide.net/windowswallpaperwiki/5/50/Img0_%28Windows_7%29.jpg'
WALLPAPER_SHA256='6ea9f8468c76aa511a5b3cfc36fb212b86e7abd377f147042d2f25572bf206a2'
WP_DIR="$STATE_DIR/wallpapers"
SRC="$WP_DIR/harmony-source.jpg"
mkdir -p "$WP_DIR"

log "Preparing the Windows 7 Harmony wallpaper"

if [[ -n "${WALLPAPER_SRC:-}" ]]; then
    [[ -f "$WALLPAPER_SRC" ]] || die "WALLPAPER_SRC does not exist: $WALLPAPER_SRC"
    SRC="$WALLPAPER_SRC"
    warn "Using local wallpaper source; SHA256 verification skipped."
elif [[ -f "$SRC" ]] && [[ "$(sha256sum "$SRC" | awk '{print $1}')" == "$WALLPAPER_SHA256" ]]; then
    ok "Reusing verified wallpaper source"
else
    rm -f "$SRC"
    if ! curl -fL --retry 5 --retry-delay 3 -o "$SRC" "$WALLPAPER_URL" 2>>"$LOG_FILE"; then
        warn "Could not download the Harmony wallpaper."
        warn "Set WALLPAPER_SRC=/path/to/harmony.jpg and re-run just this step."
        exit 0
    fi
    if [[ "$(sha256sum "$SRC" | awk '{print $1}')" != "$WALLPAPER_SHA256" ]]; then
        warn "Wallpaper SHA256 did not match; using the file anyway is not safe. Skipping wallpaper."
        rm -f "$SRC"
        exit 0
    fi
    ok "Wallpaper source verified"
fi

detect_resolution() {
    local raw mode w h rest
    if have kscreen-doctor; then
        raw="$(kscreen-doctor -o 2>/dev/null | perl -pe 's/\e\[[0-9;]*[A-Za-z]//g' || true)"
        mode="$(printf '%s\n' "$raw" | grep -m1 -E 'Modes:.*\*' | grep -oE '[0-9]+x[0-9]+@[0-9.]+[^ ]*\*' | head -1)"
        if [[ -n "$mode" ]]; then
            w="${mode%%x*}"
            rest="${mode#*x}"
            h="${rest%%@*}"
            printf '%sx%s\n' "$w" "$h"
            return
        fi
    fi
    if have xrandr; then
        mode="$(xrandr --current 2>/dev/null | awk '/\*/ {print $1; exit}')"
        if [[ -n "$mode" ]]; then
            printf '%s\n' "$mode"
            return
        fi
    fi
    printf '1920x1080\n'
}

RES="$(detect_resolution)"
WIDTH="${RES%x*}"
HEIGHT="${RES#*x}"
OUT="$WP_DIR/harmony-${WIDTH}x${HEIGHT}.jpg"

log "Rendering wallpaper at native resolution ${WIDTH}x${HEIGHT}"
if have magick; then
    magick "$SRC" -resize "${WIDTH}x${HEIGHT}^" -gravity center \
        -crop "${WIDTH}x${HEIGHT}+0+0" +repage -filter Lanczos -quality 95 "$OUT"
elif have convert; then
    convert "$SRC" -resize "${WIDTH}x${HEIGHT}^" -gravity center \
        -crop "${WIDTH}x${HEIGHT}+0+0" +repage -filter Lanczos -quality 95 "$OUT"
else
    die "ImageMagick is required to resize the wallpaper."
fi

if has_plasma_session; then
    if plasma-apply-wallpaperimage "$OUT" >>"$LOG_FILE" 2>&1; then
        ok "Wallpaper applied for the current session"
    else
        warn "Could not apply the wallpaper to the current session"
    fi
else
    warn "No running Plasma session; the wallpaper will be applied on login."
fi

mkdir -p "$HOME/.config/autostart"
sed "s|@WALLPAPER@|$OUT|g" "$ROOT/assets/atp-wallpaper.desktop.in" \
    > "$HOME/.config/autostart/atp-wallpaper.desktop"
chmod 644 "$HOME/.config/autostart/atp-wallpaper.desktop"

ok "Wallpaper ready: $OUT"
