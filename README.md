# Windows 7 for KDE Plasma

A conversion project that turns a stock Arch + KDE Plasma 6.8 desktop into a
Windows 7 desktop: Aero shell, Start menu, taskbar, decorations, fonts, sounds,
cursors, gadgets, Recycle Bin, Command Prompt, login screen and optional Windows
applications.

It is not a theme pack. Each Windows 7 layer is mapped onto a specific KDE
component, installed in dependency order, and verified after the fact. Every component it
installs can be removed again.

## What gets converted

| Windows 7 | On KDE |
|---|---|
| Aero Glass, blur, animations | AeroThemePlasma KWin effects |
| Start menu | SevenStart |
| Taskbar with thumbnails | SevenTasks |
| Window frame and shadow | SMOD KDecoration3 |
| Segoe UI, Tahoma and friends | Fonts from the Windows 7 ISO |
| Sound scheme and cursors | Windows 7 sound scheme selected; Aero cursor theme |
| Harmony wallpaper | Cover-cropped to the native monitor mode |
| Desktop gadgets | AeroShell Clock, CPU, Notes, RSS, Slideshow |
| Sidebar gadgets | Picture Puzzle, Calendar, Currency (QML ports) |
| Recycle Bin | Desktop icon backed by `trash:/` |
| Command Prompt | Konsole profile with Windows paths and aliases |
| UAC prompt | `uac-polkit-agent` |
| `winver` | LinVer |
| Login screen | AeroThemePlasma SDDM theme |
| GTK applications | Windows 7 Better GTK2/3/4 |
| Notepad, Paint, WordPad, OSK | Windows 7 binaries from the ISO under Wine |
| Solitaire, FreeCell, Hearts, Spider, Minesweeper, Chess Titans, Mahjong Titans, Purble Place | Original game files from the ISO under Wine |

The full mapping, including which script owns each layer, is in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Requirements

- Arch Linux with KDE Plasma 6.8 on Wayland
- `sudo`, at least 10 GB free disk (12 GB recommended) and network access
- The installer downloads the Windows 7 Ultimate SP1 x64 ISO automatically.
  Set `WIN7_ISO=/path/to.iso` to use your own image.
- Proton in Steam for the optional Windows games and applications

X11 is not supported. Details: [docs/INSTALL.md](docs/INSTALL.md).

## Install

One line, no checkout:

```bash
curl -fsSL https://raw.githubusercontent.com/nithitsuki/win7-aero-kde/main/get.sh | bash
```

With the graphical installer:

```bash
curl -fsSL https://raw.githubusercontent.com/nithitsuki/win7-aero-kde/main/get.sh | bash -s -- --gui
```

Or from a checkout:

```bash
git clone https://github.com/nithitsuki/win7-aero-kde.git
cd win7-aero-kde
./install.sh          # terminal
./install.sh --gui    # Windows 7-style installer
```

`get.sh` caches the checkout in `~/.cache/win7-aero/repo` and updates it on
the next run.

The installer is safe to re-run: completed components are skipped, and
individual steps can be skipped or rebuilt with the flags in
[docs/INSTALL.md](docs/INSTALL.md).

After the first run:

1. Log out.
2. Select the **AeroThemePlasma** session (preselected for your user).
3. Complete AeroThemePlasma's first-run wizard.

## Optional layers

The base conversion is complete without these:

- **Desktop gadgets** — right-click the desktop, **Add Widgets**, then Clock,
  CPU, Notes, RSS or Slideshow.
- **Sidebar gadgets** — Picture Puzzle, Calendar and Currency. Their artwork is
  extracted from your own ISO at install time; the repository ships no Microsoft
  assets.
- **Windows applications** — genuine Notepad, WordPad, Paint and On-Screen
  Keyboard with real icons and matching HiDPI. See
  [docs/WIN7-APPS.md](docs/WIN7-APPS.md).

## Verify and uninstall

```bash
./install.sh --verify-only
./uninstall.sh          # asks for confirmation
./uninstall.sh --purge  # also removes $XDG_DATA_HOME/win7-aero
```

The uninstaller removes the components it installed, restores the distro
`libplasma`, and returns the recorded configuration backups.

## Documentation

| Document | Contents |
|---|---|
| [Documentation index](docs/README.md) | Short index of every document |
| [INSTALL.md](docs/INSTALL.md) | Requirements, options, walkthrough, usage, verify, uninstall |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Layer model, conversion map, script responsibilities |
| [COMPATIBILITY.md](docs/COMPATIBILITY.md) | Tested reference, commits, support matrix |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Symptom → cause → fix |
| [GAMES.md](docs/GAMES.md) | Windows 7 games built from the ISO |
| [WIN7-APPS.md](docs/WIN7-APPS.md) | Optional Windows applications under Wine |

## Repository layout

```text
get.sh                  one-line bootstrap (curl | bash)
install.sh              orchestrator
uninstall.sh            reversible teardown
gui/                    Windows 7-style graphical installer
lib/common.sh           logging, sudo, backups, helpers
scripts/                numbered install steps (00 → 90)
assets/                 Konsole profile, colorscheme, CMD shell, icons, desktop files
gadgets/                QML Sidebar gadget ports (art comes from the ISO)
games/                  Windows 7 games layer (built from the ISO)
wine/                   optional Windows 7 applications layer
docs/                   documentation
versions.lock           tested component commits (reference only)
```

## Design principles

- **Reversible.** Destructive steps record a manifest or backup under
  `~/.local/share/win7-aero/`; uninstall consumes them and restores every
  configuration file that has a backup.
- **ISO-sourced assets.** Microsoft fonts, sounds, cursors, icons and gadget
  artwork are extracted locally from the user's own Windows 7 image. The
  wallpaper is downloaded from a public mirror and hash-verified. None of these
  assets are redistributed here.
- **Verified, not assumed.** `90-verify.sh` re-reads the resulting files and
  configuration instead of trusting earlier exit codes.
- **Documented workarounds.** Non-obvious KDE and Wine behaviours are recorded
  with their symptoms and fixes in
  [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Contributing

Install steps are numbered scripts. Keep them idempotent, record every change
under `~/.local/share/win7-aero/` so `uninstall.sh` can reverse it, and update
the matching document when behaviour changes. Before a pull request:

```bash
./install.sh --dry-run
./install.sh --verify-only
```

## Copyright

This repository contains only original scripts, configuration and an original
SVG icon. It does not redistribute Windows assets or the Harmony wallpaper. The
installer extracts them from Microsoft images for personal use. Windows, Aero,
Command Prompt and the Windows 7 artwork are Microsoft trademarks.

Licensed under the MIT License; see [LICENSE](LICENSE).
