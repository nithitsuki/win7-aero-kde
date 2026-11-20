# Architecture

This repository is not a theme pack. It assembles a Windows 7 desktop by
mapping each Windows 7 layer onto a KDE Plasma component, then wires those
components together in the right order and verifies the result.

## Layer model

```text
┌──────────────────────────────────────────────────────────────┐
│ Session      SDDM theme, AeroThemePlasma session             │  60-sddm
├──────────────────────────────────────────────────────────────┤
│ Shell        SevenStart, SevenTasks, panel, Aero decorations │  40-atp, 50-kde
├──────────────────────────────────────────────────────────────┤
│ Look & feel  Plasma style, colors, fonts, KWin effects       │  50-kde
├──────────────────────────────────────────────────────────────┤
│ Assets       Fonts, sounds, cursors, shell icons, wallpaper  │  30-assets, 80-wallpaper
├──────────────────────────────────────────────────────────────┤
│ Gadgets      AeroShell desktop widgets, Sidebar ports        │  45-gadgets, 46-sidebar-gadgets
├──────────────────────────────────────────────────────────────┤
│ Integrations GTK theme, winver, Recycle Bin, CMD, shortcuts  │  47, 48, 55, 70, 72
├──────────────────────────────────────────────────────────────┤
│ Applications Windows 7 games and utilities under Wine        │  49-games, wine/
└──────────────────────────────────────────────────────────────┘
```

The installer visits the layers in this order. The numbered steps do not map
one-to-one: assets are extracted before the shell is installed and SDDM is
configured near the end. Each step remains independently skippable.

## Conversion map

| Windows 7 | Implementation | Repo artefact |
|---|---|---|
| Aero Glass, blur, animations | AeroThemePlasma KWin effects and `aeroshell-kwin-components` | `40-atp`, `50-kde` |
| Start menu | SevenStart (ATP) | `40-atp`, `72-shortcuts` |
| Taskbar and thumbnails | SevenTasks (ATP) | `40-atp` |
| Window frame and shadow | SMOD KDecoration3 engine | `40-atp`, `50-kde` |
| System tray and clock | ATP panel layout | `50-kde` |
| Segoe UI, Tahoma and friends | Fonts extracted from `install.wim` | `30-assets` |
| Startup, logon and notification sounds | Windows 7 sound scheme from the ISO, selected in KDE | `30-assets`, `50-kde` |
| Aero cursors | Aero cursor theme (`aero-drop`) | `40-atp`, `50-kde` |
| Shell icons | AeroThemePlasma icon theme (`Seven-Black`) | `40-atp`, `50-kde` |
| Harmony wallpaper | Cover-cropped to the monitor's native mode | `80-wallpaper` |
| Desktop gadgets | AeroShell Clock/CPU/Notes/RSS/Slideshow | `45-gadgets` |
| Sidebar gadgets | QML ports of Picture Puzzle, Calendar, Currency | `46-sidebar-gadgets` |
| Recycle Bin | Desktop icon backed by `trash:/` and a path unit | `55-desktop-trash` |
| Command Prompt | Konsole profile, palette, banner and aliases | `70-konsole` |
| UAC prompt | `uac-polkit-agent` | `40-atp` |
| `winver` dialog | LinVer | `48-linver` |
| Login screen | ATP SDDM theme | `60-sddm` |
| GTK applications | Windows 7 Better GTK2/3/4 theme | `47-gtk` |
| Notepad, Paint, WordPad, OSK | Windows 7 binaries from the ISO under Wine | `wine/` |
| Solitaire, FreeCell, Hearts, Spider, Minesweeper, Chess Titans, Mahjong Titans, Purble Place | Original game files from the ISO under Wine | `49-games` |

## Component responsibilities

| Path | Responsibility |
|---|---|
| `install.sh` | Parses options, owns the run order, creates one shared backup directory |
| `uninstall.sh` | Reverses every step using its manifests and the shared backup |
| `lib/common.sh` | Logging, `sudo` wrapper, backups, `XAUTHORITY` import, Plasma helpers |
| `scripts/00-preflight.sh` | Arch, `sudo`, disk space, network, session checks |
| `scripts/10-deps.sh` | Repository packages (including `wayland-protocols`, `vulkan-headers`) |
| `scripts/20-capslock.sh` | Caps Lock → Ctrl with `ResetOldOptions=true` |
| `scripts/30-assets.sh` | ISO download/verify, WIM extraction of fonts, sounds, cursors, icons, gadget art |
| `scripts/40-atp.sh` | AeroThemePlasma clone, build, install, completeness check |
| `scripts/45-gadgets.sh` | AeroShell desktop gadget build and manifest |
| `scripts/46-sidebar-gadgets.sh` | QML Sidebar ports plus ISO artwork |
| `scripts/47-gtk.sh` | Windows 7 Better GTK theme and libadwaita override |
| `scripts/48-linver.sh` | LinVer build and install |
| `scripts/49-games.sh` | Windows 7 games from the extracted image |
| `scripts/50-kde.sh` | Look-and-feel, fonts, KWin effects, decoration |
| `scripts/55-desktop-trash.sh` | Recycle Bin desktop icon and systemd path unit |
| `scripts/60-sddm.sh` | SDDM theme and default session |
| `scripts/70-konsole.sh` | Command Prompt profile and launcher |
| `scripts/72-shortcuts.sh` | Meta → SevenStart, PrintScreen → Spectacle |
| `scripts/80-wallpaper.sh` | Native-resolution Harmony wallpaper and autostart |
| `scripts/90-verify.sh` | End-to-end verification |
| `wine/` | Optional Windows 7 applications layer (independent of the theme) |

## Data flow

1. `30-assets.sh` verifies the Windows 7 ISO, extracts `install.wim`, and pulls
   only the files the theme needs, including the game directories. The ISO is
   deleted afterwards unless `--keep-iso` is used.
2. `40-atp.sh` installs AeroThemePlasma from its own repository and checks the
   pieces it claims to install.
3. `46-sidebar-gadgets.sh` combines the QML packages in `gadgets/` with the
   Microsoft artwork extracted in step 1.
4. `49-games.sh` installs the extracted games into the shared Wine prefix,
   merges their MUI resources and writes launchers.
5. `50-kde.sh` writes Plasma/KWin configuration and triggers a live reload.
6. `90-verify.sh` re-reads the resulting configuration and files rather than
   trusting the exit codes of the earlier steps.

## Design constraints

- **Plasma 6.8 and Wayland.** Arch no longer ships a Plasma X11 session, and the
  tested AeroThemePlasma branch targets Wayland. X11 is not supported.
- **A patched libplasma is required.** AeroThemePlasma replaces the distro
  `libplasma` with a fork that adds four `PlasmaQuick::Dialog` properties used by
  Aero popups. `uninstall.sh` restores the distro package.
- **No redistributed Microsoft assets.** Fonts, sounds, cursors, icons and
  gadget art are extracted locally from the user's own Windows 7 image. The
  wallpaper is downloaded from a public mirror and hash-verified.
- **Reversible by construction.** Destructive steps record manifests and backups
  under `~/.local/share/win7-aero/`; `uninstall.sh` reverses them and restores
  each configuration file for which a backup exists.

## Failure handling

The scripts encode workarounds for behaviours that are not obvious from the
component documentation. The full list, with symptoms and fixes, is in
[TROUBLESHOOTING.md](TROUBLESHOOTING.md). The most important ones:

- KGlobalAccel rewrites `kglobalshortcutsrc` from its in-memory state shortly
  after a runtime change, which can delete the Alt+F1 fallback binding.
- Plasma only opens a desktop file without a confirmation dialog when the
  Folder View URL is exactly `desktop:/`.
- `plasma-apply-lookandfeel` calls `xrdb` even on Wayland and needs
  `XAUTHORITY`.
- KWin does not hot-load scripted effects; the installer calls the Effects D-Bus
  methods explicitly.
- `pacman -Qkk` exits non-zero when it finds altered files, which trips
  `pipefail` unless the output is captured first.
