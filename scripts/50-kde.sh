#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/lib/common.sh"

[[ -f /usr/share/plasma/look-and-feel/authui7/metadata.json ]] \
    || die "AeroThemePlasma is not installed. Run the ATP step first (or remove --skip-atp)."

log "Applying AeroThemePlasma look-and-feel and KDE settings"
apply_xauthority

backup_file \
    "$HOME/.config/kdeglobals" \
    "$HOME/.config/kwinrc" \
    "$HOME/.config/plasmarc" \
    "$HOME/.config/kcminputrc" \
    "$HOME/.config/ksplashrc" \
    "$HOME/.config/kglobalshortcutsrc" \
    "$HOME/.config/plasmashellrc" \
    "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

if has_plasma_session; then
    plasma-apply-lookandfeel -a authui7 >>"$LOG_FILE" 2>&1 \
        || warn "plasma-apply-lookandfeel failed; falling back to direct config writes"
    kvantummanager --set Windows7Aero >>"$LOG_FILE" 2>&1 \
        || warn "Could not set the Kvantum Windows7Aero theme"
    plasma-apply-desktoptheme Seven-Black >>"$LOG_FILE" 2>&1 || true
    plasma-apply-colorscheme Aero >>"$LOG_FILE" 2>&1 || true
    plasma-apply-cursortheme aero-drop --size 32 >>"$LOG_FILE" 2>&1 || true
else
    warn "No running Plasma session detected; config files will be written, but live apply is skipped."
fi

FONT="Segoe UI,9,-1,5,50,0,0,0,0,0"
SMALL="Segoe UI,8,-1,5,50,0,0,0,0,0"

# Fonts and global style
kwrite --file kdeglobals --group General --key font "$FONT"
kwrite --file kdeglobals --group General --key smallestReadableFont "$SMALL"
kwrite --file kdeglobals --group General --key toolBarFont "$FONT"
kwrite --file kdeglobals --group General --key menuFont "$FONT"
kwrite --file kdeglobals --group WM --key activeFont "$FONT"
kwrite --file kdeglobals --group Icons --key Theme "Windows 7 Aero"
kwrite --file kdeglobals --group KDE --key widgetStyle kvantum
kwrite --file kdeglobals --group Sounds --key Theme "Windows 7"

# Plasma and input
kwrite --file plasmarc --group Theme --key name Seven-Black
kwrite --file kcminputrc --group Mouse --key cursorTheme aero-drop
kwrite --file kcminputrc --group Mouse --key cursorSize 32
kwrite --file ksplashrc --group KSplash --key Theme authui7

# Window decoration / switcher
kwrite --file kwinrc --group org.kde.kdecoration2 --key library org.smod.smod
kwrite --file kwinrc --group org.kde.kdecoration2 --key theme SMOD
kwrite --file kwinrc --group WindowSwitcher --key LayoutName thumbnail_aero
kwrite --file kwinrc --group TabBox --key LayoutName thumbnail_aero
kwrite --file kwinrc --group TabBoxAlternative --key LayoutName flip3d

# Aero effects. These are the IDs used by ATP's own OOTB wizard.
ENABLE_EFFECTS=(
    aeroglassblur aeroglide smodglow smodpeekeffect
    libkwin_effect_smodsnap launchfeedback fadingpopupsaero
    squashaero dimscreenaero aeroshell-thumbnails
)
DISABLE_EFFECTS=(
    blur login logout maximize scale squash slide fade
    slidingpopups slidingnotifications dialogparent
    fadingpopups windowaperture
)

for e in "${ENABLE_EFFECTS[@]}"; do
    kwrite --file kwinrc --group Plugins --key "${e}Enabled" true
done
for e in "${DISABLE_EFFECTS[@]}"; do
    kwrite --file kwinrc --group Plugins --key "${e}Enabled" false
done
kwrite --file kwinrc --group Plugins --key smodpeekscriptEnabled true
kwrite --file kwinrc --group Plugins --key minimizeallEnabled true

if has_plasma_session; then
    for e in "${ENABLE_EFFECTS[@]}"; do
        qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect "$e" >/dev/null 2>&1 || true
    done
    for e in "${DISABLE_EFFECTS[@]}"; do
        qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect "$e" >/dev/null 2>&1 || true
    done

    if [[ -f /usr/share/kwin/scripts/smodpeekscript/contents/ui/main.qml ]]; then
        qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadDeclarativeScript \
            /usr/share/kwin/scripts/smodpeekscript/contents/ui/main.qml smodpeekscript >/dev/null 2>&1 || true
    fi
    if [[ -f /usr/share/kwin/scripts/minimizeall/contents/code/main.js ]]; then
        qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript \
            /usr/share/kwin/scripts/minimizeall/contents/code/main.js minimizeall >/dev/null 2>&1 || true
    fi
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null 2>&1 || true
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
fi

refresh_ksycoca
ok "KDE theme settings applied"
