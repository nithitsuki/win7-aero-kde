# Hiccups and how this repo handles them

These are the actual failures from the live setup, not theoretical issues.

## 1. Caps Lock looked configured but was ignored

`~/.config/kxkbrc` already had `Options=ctrl:nocaps`, yet Caps Lock stayed Caps
Lock. KWin only passes the option to libxkbcommon when **`ResetOldOptions=true`**
is also present:

```ini
[Layout]
Options=ctrl:nocaps
ResetOldOptions=true
Use=true
```

`scripts/20-capslock.sh` writes both, preserves any existing XKB options, and
defaults the layout only if none exists. KWin does not hot-reload this in every
session, so it is applied on the next login.

## 2. ATP's first build failed on `wayland-protocols`

CMake died with:

```text
Could NOT find WaylandProtocols (missing: WaylandProtocols_DATADIR)
```

The missing package is `wayland-protocols` (not `plasma-wayland-protocols`).
`scripts/10-deps.sh` installs both.

## 3. ATP's `--ninja` flag is ignored

The upstream `install.sh` contains no argument parsing, so `bash install.sh --ninja`
still invokes Make. `scripts/40-atp.sh` sets `CMAKE_GENERATOR=Ninja` instead,
which CMake honors.

## 4. Some ATP component repos have no `Plasma/6.8` branch

`aeroshell-sddm-kcm`, `aerothemeplasma-icons` and `aerothemeplasma-sounds` only
have `master`. The upstream installer runs `git checkout Plasma/6.8` anyway,
prints a `pathspec` error and continues on `master`. That is expected; the
installer verifies the final installed files rather than trusting the exit code.

## 5. The fake Windows 7 ISO

Archive.org contains an item with the exact Microsoft filename
`en_windows_7_professional_with_sp1_x86_dvd_u_677056.iso` but a different SHA1.
The installer uses the genuine item and refuses to extract unless the SHA1 is:

```text
d89937df3a9bc2ec1a1486195fd308cd3dade928
```

If the hash fails, delete the cached ISO and retry. Do not bypass this check.

## 6. The ISO download was ~45 minutes

A single curl connection to archive.org ran at roughly 1 MB/s. `scripts/30-assets.sh`
uses `aria2c -x16 -s16 -k1M`, which brought the same image down at ~28 MiB/s.
The ISO is deleted afterward unless `--keep-iso` is used.

## 7. `plasma-apply-lookandfeel` printed X11 authorization errors

On Wayland, `plasma-apply-lookandfeel` still calls `xrdb`. If `XAUTHORITY` is not
in the environment it prints errors. The installers import `XAUTHORITY` from
`systemctl --user show-environment` first.

## 8. KWin did not hot-load the new effects

Writing `<effect>Enabled=true` to `kwinrc` and calling `reconfigure` was not enough
in the tested session. `scripts/50-kde.sh` also calls the Effects D-Bus methods
`loadEffect`/`unloadEffect` and loads the two KWin scripts
(`smodpeekscript`, `minimizeall`) explicitly.

## 9. CMD prompt had mixed slashes

The first Windows-path conversion produced `C:\Users\<user>/Projects` because
only `$HOME` was translated, not the suffix. The prompt code now replaces `/`
with `\` for the suffix and for arbitrary paths.

## 10. CMD window title and toolbars

The first Konsole window showed `~ : bash — Konsole` and had the tab/tool bars.
The launcher now passes `--qwindowtitle "Command Prompt"`,
`--hide-menubar`, `--hide-tabbar`, `--hide-toolbars`, and sets the tab title
format. Konsole still appends `— Konsole` to the window title; that is a Konsole
behavior, not the theme.

## 11. Wallpaper was 1920×1200 on a 4K monitor

The monitor's native mode is 3840×2160 at 2× scale, so the 1920×1200 original
would be upscaled by the compositor. `scripts/80-wallpaper.sh` reads the starred
mode from `kscreen-doctor`, cover-crops the source with Lanczos, and writes
`harmony-3840x2160.jpg`. An autostart entry re-applies it after the ATP shell
creates its new desktop containment.

## 12. The AUR font package was unnecessary

The reference machine installed `ttf-win7-fonts` through `makepkg`. The repo
does not depend on AUR helpers. `scripts/30-assets.sh` copies the font files
directly to `/usr/share/fonts/win7` and runs `fc-cache`, which is simpler and
portable across Arch installs. Removal is a single directory.

## 13. A sound-theme copy failed silently

The first copy targeted `~/.local/share/sounds/` before that directory existed,
and the error was suppressed. The script now creates the directory first and
uses a clean remove-then-copy so a partial theme cannot linger.

## 14. The Windows key did nothing

`kglobalshortcutsrc` had the stock shortcut:

```ini
[plasmashell]
activate application launcher=Meta\tAlt+F1,Meta\tAlt+F1,Activate Application Launcher
```

The ATP shell has no stock application launcher, so that action was a no-op and
it still owned the Meta key. SevenStart only opens when its own applet action is
triggered. The fix is to remove the stock launcher from Meta and register the
SevenStart applet action instead:

```bash
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
  'var ws=panels()[0].widgets(); ... ws[j].globalShortcut="Meta";'

qdbus6 org.kde.kglobalaccel /kglobalaccel \
  org.kde.KGlobalAccel.unregister plasmashell 'activate application launcher'
```

`scripts/72-shortcuts.sh` installs an autostart helper that does both after every
login, and writes the stock launcher back to `Alt+F1` in the config.

## 15. PrintScreen did nothing

`spectacle` was not installed. Spectacle's `.desktop` file already contains
`X-KDE-Shortcuts=Print`; KGlobalAccel registers it as soon as the package is
installed. `scripts/10-deps.sh` installs Spectacle and
`scripts/72-shortcuts.sh` verifies the binary is present.

## 16. Arch no longer ships a Plasma X11 session package

`plasma-x11-session` is not in the Arch repositories. ATP's `Plasma/6.8` branch
supports Wayland; that is the supported target here. X11-specific effects may
behave differently if you build an X11 session manually.
