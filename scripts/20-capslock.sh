#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/lib/common.sh"

log "Mapping Caps Lock to Ctrl"

KXKB="$HOME/.config/kxkbrc"
backup_file "$KXKB"

opts="$(kread --file "$KXKB" --group Layout --key Options 2>/dev/null || true)"
case ",$opts," in
    *,ctrl:nocaps,*) ;;
    *) opts="${opts:+$opts,}ctrl:nocaps" ;;
esac

# ResetOldOptions is the part everyone misses: KWin ignores Options= otherwise.
kwrite --file "$KXKB" --group Layout --key Options "$opts"
kwrite --file "$KXKB" --group Layout --key ResetOldOptions true
kwrite --file "$KXKB" --group Layout --key Use true

if [[ -z "$(kread --file "$KXKB" --group Layout --key LayoutList 2>/dev/null || true)" ]]; then
    kwrite --file "$KXKB" --group Layout --key LayoutList us
    warn "No keyboard layout was configured; defaulted LayoutList to 'us'."
fi

ok "Caps Lock -> Ctrl written to $KXKB (takes effect on the next KWin start / login)"
