# Troubleshooting

Each entry states the symptom, the cause and the fix. Most items are handled
automatically; the exceptions are noted. This page is for diagnosing a failed
run or a machine that drifted after an update.

## Installation and the ISO

### The downloaded ISO fails the hash check

**Symptom:** `30-assets.sh` aborts with a SHA-1 mismatch.

**Cause:** Archive.org hosts several items with Microsoft's exact filename but a
different hash.

**Fix:** Delete the cached image and rerun. Do not bypass the check.

```bash
rm -f ~/.local/share/win7-aero/cache/win7-ultimate-x64.iso
./install.sh
```

If you use `WIN7_ISO`, the file is trusted as yours and a mismatch is only a
warning.

### The ISO download takes a long time

**Symptom:** A single connection to archive.org runs at about 1 MB/s.

**Cause:** Archive.org throttles per connection.

**Fix:** `30-assets.sh` already uses `aria2c -x16 -s16 -k1M`, which is
substantially faster. Install `aria2` if it is missing; otherwise the script
falls back to `curl`.

## Build failures

### CMake cannot find `WaylandProtocols`

**Symptom:**

```text
Could NOT find WaylandProtocols (missing: WaylandProtocols_DATADIR)
```

**Cause:** The package is `wayland-protocols`, not `plasma-wayland-protocols`.

**Fix:** `10-deps.sh` installs both. To repair manually:

```bash
sudo pacman -S wayland-protocols plasma-wayland-protocols
```

### `target not found: kwin-x11` (old checkouts)

**Symptom:** The dependency transaction stops.

**Cause:** Current `kwin` has no X11 compositor and no `kwin-x11` package
exists.

**Fix:** The package list no longer includes it. Update the repository before
installing.

### AeroThemePlasma ignores `--ninja`

**Symptom:** The build uses Make even when `--ninja` is passed.

**Cause:** The upstream installer has no argument parsing.

**Fix:** `40-atp.sh` exports `CMAKE_GENERATOR=Ninja` instead, which CMake
honours.

### A component repository has no `Plasma/6.8` branch

**Symptom:** `git checkout Plasma/6.8` prints a pathspec error and the installer
continues.

**Cause:** A few AeroShell repositories (`aeroshell-sddm-kcm`,
`aerothemeplasma-icons`, `aerothemeplasma-sounds`) only publish `master`.

**Fix:** The warning is harmless. The repository continues on `master` and
verifies the installed files instead of trusting that exit code.

### SMOD cannot find Vulkan

**Symptom:**

```text
Could NOT find Vulkan (missing: Vulkan_INCLUDE_DIR)
```

**Cause:** KWin's CMake config requires the Vulkan headers.

**Fix:** `10-deps.sh` installs `vulkan-headers`.

### The patched-libplasma check warns on a good install

**Symptom:** A warning that `libplasma` files were altered, even when the fork is
correct.

**Cause:** `pacman -Qkk` exits non-zero when it finds altered files, which trips
`pipefail` even when the expected file is present.

**Fix:** Already handled: the script captures the output, sets `LC_ALL=C` and
matches the altered-file count instead of the exit code.

## Shell, effects and shortcuts

### Caps Lock still acts as Caps Lock

**Symptom:** `Options=ctrl:nocaps` is present but ignored.

**Cause:** KWin only passes the option to libxkbcommon when
`ResetOldOptions=true` is also set.

**Fix:** `20-capslock.sh` writes both keys. Log out and back in; KWin does not
reload this in every session.

```ini
[Layout]
Options=ctrl:nocaps
ResetOldOptions=true
Use=true
```

### `plasma-apply-lookandfeel` prints X11 authorization errors

**Symptom:** X11 errors on a Wayland session.

**Cause:** The tool still calls `xrdb`, and `XAUTHORITY` is not in the
environment.

**Fix:** `lib/common.sh` imports `XAUTHORITY` from
`systemctl --user show-environment` before applying the look and feel.

### Effects or decorations do not appear until the next login

**Symptom:** Blur, Peek or the decorations are missing after install.

**Cause:** KWin does not hot-load scripted effects just because `kwinrc` changed
and `reconfigure` was called.

**Fix:** `50-kde.sh` calls the Effects D-Bus methods `loadEffect`/`unloadEffect`
and loads `smodpeekscript` and `minimizeall` explicitly. If it still fails, log
out and back in.

### The Windows key does nothing

**Symptom:** Meta does not open SevenStart.

**Cause:** The stock "activate application launcher" action owns Meta, and the
ATP shell has no visible launcher for it, so the key is swallowed.

**Fix:** `72-shortcuts.sh` moves the stock action to Alt+F1 and gives SevenStart
the Meta shortcut after login.

If a runtime shortcut change occurs, KGlobalAccel rewrites
`kglobalshortcutsrc` from memory about 500 ms later. The script waits past that
write, restores Alt+F1 and verifies the value. A relogin is still required for
the session to pick up the new state.

### PrintScreen does nothing

**Symptom:** No screenshot UI.

**Cause:** Spectacle is not installed.

**Fix:** `10-deps.sh` installs Spectacle. Its desktop file already registers
`X-KDE-Shortcuts=Print`, so no extra binding is needed.

## Desktop

### A desktop file asks "Open or Execute?"

**Symptom:** Double-clicking a desktop file shows a dialog, and choosing Open
sends it to Dolphin.

**Cause:** Plasma only skips the dialog when the Folder View URL is exactly
`desktop:/`. A URL such as `desktop:/Desktop/` always shows it.

**Fix:** The installer points `XDG_DESKTOP_DIR` at `~/Desktop` and sets the
Folder View URL to `desktop:/`. Re-run `55-desktop-trash.sh` after changing the
desktop location.

### Dolphin says "Trying to open a file as a folder"

**Symptom:** Desktop files or links open Dolphin instead of their target.

**Cause:** A bogus `x-scheme-handler/file` association in
`~/.config/mimeapps.list`. KIO checks scheme handlers before MIME detection.

**Fix:** The installer removes
`x-scheme-handler/file=org.kde.dolphin.desktop` and keeps a backup. The
association is unnecessary because `inode/directory` already selects Dolphin.

### The wallpaper looks soft on a 4K monitor

**Symptom:** The Harmony wallpaper is upscaled or cropped badly.

**Cause:** The original is 1920×1200, smaller than a 3840×2160 panel.

**Fix:** `80-wallpaper.sh` reads the starred mode from `kscreen-doctor`,
cover-crops the source with Lanczos and writes a native-resolution copy. An
autostart entry re-applies it after the ATP shell creates its containment.

### The Recycle Bin icon does not update

**Symptom:** The icon stays empty or full after changing the Trash.

**Cause:** The systemd user path unit is not running, usually because the
installer ran from a TTY.

**Fix:** Log in and re-run the step:

```bash
ROOT="$PWD" bash scripts/55-desktop-trash.sh
```

The icon follows the home Trash only. A Trash on another partition uses its own
`.Trash-<uid>` directory.

## Command Prompt

### The prompt shows mixed slashes

**Symptom:** Paths look like `C:\Users\<user>/Projects`.

**Cause:** Only `$HOME` was translated, not the suffix.

**Fix:** `70-konsole.sh` replaces `/` with `\` for the home suffix and for
arbitrary paths.

### The Command Prompt shows tabs or toolbars

**Symptom:** Konsole chrome is visible, or the title reads `~ : bash — Konsole`.

**Cause:** Konsole defaults.

**Fix:** The launcher passes `--qwindowtitle "Command Prompt"`,
`--hide-menubar`, `--hide-tabbar`, `--hide-toolbars` and sets the tab title
format. Konsole still appends `— Konsole` to the window title; that is Konsole
behaviour, not the theme.

## Gadgets

### The gadgets are not in the panel clock slot

**Symptom:** Adding a gadget does not replace the panel clock.

**Cause:** The AeroShell gadgets are desktop widgets by design.

**Fix:** Right-click the desktop and use **Add Widgets**. The panel clock stays
as the `digitalclocklite` applet.

### A Sidebar gadget reports missing artwork

**Symptom:** `46-sidebar-gadgets.sh` stops with a missing-image error.

**Cause:** The Microsoft art was not extracted, usually because the install
skipped `30-assets.sh`.

**Fix:** Run the asset step, then the gadget step:

```bash
ROOT="$PWD" bash scripts/30-assets.sh
ROOT="$PWD" bash scripts/46-sidebar-gadgets.sh
```

### The Currency gadget has no rates

**Symptom:** The widget shows the offline state.

**Cause:** It needs network access. The original Windows Live service is gone,
so the port uses the Frankfurter API (daily ECB reference rates), not live
quotes.

**Fix:** Check connectivity. Rates update once per day; the widget shows the age
of the current rate.

### The Currency spinner is rejected by Qt

**Symptom:** A broken or blank spinner in the Currency widget.

**Cause:** The original PNG contains an invalid `pAni` chunk; Qt rejects the
file.

**Fix:** `46-sidebar-gadgets.sh` strips that chunk and verifies the repaired file
with ImageMagick. `python3` and `imagemagick` are required.

## GTK and LinVer

### GTK2 applications ignore the theme

**Symptom:** GTK3/4 apps are themed, GTK2 apps are not.

**Cause:** GTK2 is AUR-only (`gtk2`), and `gtk2-compat` is a GTK3 shim, not a
replacement.

**Fix:** Install `gtk2` from the AUR if GTK2 applications matter.

### The GTK theme does not apply after install

**Symptom:** Firefox and other GTK apps keep their old look.

**Cause:** Running applications do not reload the theme.

**Fix:** Restart the applications. The libadwaita override is already in
`~/.config/gtk-4.0`.

### `--reinstall-gtk` overwrites the original backup

**Symptom:** Uninstall restores the already-themed GTK settings.

**Cause:** The backup would be taken a second time, after theming.

**Fix:** Already handled: the first backup is marked with
`manifests/gtk-config.recorded` and later runs keep it.

### The libadwaita override damaged another theme

**Symptom:** Another GTK theme's `gtk.css`, `gtk-dark.css` or `assets` changed.

**Cause:** `~/.config/gtk-4.0` can contain symlinks into that theme; a plain
`cp` writes through a file symlink and refuses to replace a directory symlink.

**Fix:** `47-gtk.sh` removes top-level symlinks before copying the override.

### `linver` is missing

**Symptom:** The command is not found after a partial install.

**Cause:** LinVer is a small AUR package built with `makepkg`, not a theme
component.

**Fix:** `ROOT="$PWD" bash scripts/48-linver.sh` from the checkout.

## Games

### The game step was skipped

**Symptom:** No game launchers after install.

**Cause:** Proton is not installed, or the assets were skipped.

**Fix:** Install Proton in Steam and run
`ROOT="$PWD" bash scripts/49-games.sh` from the checkout (with `get.sh`, use
`~/.cache/win7-aero/repo`). If the install used `--skip-assets`, run the asset
step first.

### "Critical Error: No suitable graphics devices found"

**Symptom:** A card game shows a DirectX error dialog and exits.

**Cause:** The prefix is missing Proton's vkd3d DLLs, which wined3d imports.
A bare `wineboot` prefix does not have them.

**Fix:** Re-run `49-games.sh`; it copies them into `system32` and `syswow64`.

### Blank menus and dialogs in a game

**Cause:** The MUI resources were not merged and Wine has no MUI redirection.

**Fix:** Re-run `49-games.sh`.

### A card game shows a black play area

**Symptom:** The window opens and the menu bar is correct, but the cards and the
table are black.

**Cause:** The games come from a 32-bit image. The 32-bit card games do not draw
their Direct3D scene under Wine 11.

**Fix:** Use the 64-bit Ultimate SP1 image and run `./install.sh` again. If
`WIN7_ISO` points at a 32-bit image, unset it first. Remove the old image from
the cache to free disk space:

```bash
rm -f ~/.local/share/win7-aero/cache/win7-pro-x86.iso
```

### A game exits immediately or complains about Windows

**Cause:** The prefix reports Windows 10; the retail games reject it.

**Fix:** `49-games.sh` sets the prefix to Windows 7. Re-run it, or set the
version manually:

```bash
WINEPREFIX=~/.win7games-proton/pfx winecfg -v win7
```

### Games stop working after a Steam update

**Symptom:** `wine: could not load kernel32.dll, status c0000135`.

**Cause:** Proton symlinks its builtins into the prefix. When Steam removes or
replaces a Proton build, those links dangle.

**Fix:** `win7games-run` detects the installed Proton and repoints the links
before launch. Run any game launcher once after the update.

## Optional Windows applications

### Every Wine application is small

**Symptom:** Menus and dialogs look half-size on a HiDPI desktop.

**Cause:** Wine is DPI-aware, so the compositor does not scale its windows, and
`LogPixels` is still 96.

**Fix:** Set `LogPixels` to 96 × the session scale:

```bash
# 96 = 1x, 168 = 1.75x, 192 = 2x
WINEPREFIX=~/.win7games-proton/pfx \
  ~/.local/share/Steam/steamapps/common/'Proton - Experimental'/files/bin/wine \
  reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d 192 /f
```

### Wine applications show blank menus and dialogs

**Symptom:** Empty menu bars and message boxes with no text.

**Cause:** The binaries are MUI-based and Wine does not implement MUI
redirection.

**Fix:** The utilities installer merges each `.mui` file into its executable.
Re-run `wine/install-apps.sh` to repair an installation.

### WordPad or Paint says "Unable to create new document"

**Symptom:** The app shows an error dialog instead of a window.

**Cause:** Wine's `uiribbon.dll` is a stub that returns
`CLASS_E_CLASSNOTAVAILABLE`.

**Fix:** Install the ISO's `UIRibbon.dll` and `UIRibbonRes.dll` into the prefix
`system32` (the installer does this and backs up the Wine stub) and force
`uiribbon=n`. The launchers already pass the override. The installer also
registers the Ribbon COM classes, which the DLL does not register itself.

### WordPad Font group is blank

**Symptom:** The font family and font size boxes are empty. The Bold, Italic
and Underline buttons show no glyph.

**Cause:** Wine's support for the Ribbon framework does not draw the font
control.

**Fix:** None yet. Text entry and the paragraph commands still work.

### Paint canvas turns black with the Text tool

**Symptom:** After you click the Text tool and then the canvas, the canvas is
black and does not redraw.

**Cause:** Wine does not draw the text box on the canvas.

**Fix:** Close Paint and discard the changes. Do not use the Text tool until
Wine corrects the bug.

## Repairing a single step

Every step is idempotent and can run alone:

```bash
ROOT="$PWD" bash scripts/50-kde.sh     # from the checkout
```

Logs and backups live under `~/.local/share/win7-aero/`. The final verification
is:

```bash
./install.sh --verify-only
```
