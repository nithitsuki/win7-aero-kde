# Installation

## Requirements

- Arch Linux with KDE Plasma 6.8 installed
- `sudo` (the installer asks once, or once per privileged step)
- At least 8 GB free disk for the ISO, WIM and builds (10 GB recommended)
- Network access for repositories, AeroThemePlasma and the ISO
- A graphical KDE session is recommended; a TTY install works but the live theme
  apply is deferred until login

Supported session: **Plasma 6.8 on Wayland**. X11 is not supported (Arch no
longer ships a Plasma X11 session and the tested AeroThemePlasma branch targets
Wayland).

## Quick start

```bash
git clone https://github.com/nithitsuki/win7-aero-kde.git
cd win7-aero-kde
./install.sh
```

Re-running is safe: completed components are skipped, and the `--reinstall-*`
flags rebuild a specific component.

## Options

| Option | Effect |
|---|---|
| `--skip-deps` | Skip `pacman` dependency installation |
| `--skip-caps` | Skip Caps Lock → Ctrl |
| `--skip-assets` | Skip ISO download and font/sound/icon extraction |
| `--skip-atp` | Skip AeroThemePlasma build and install |
| `--skip-gadgets` | Skip the AeroShell desktop gadgets |
| `--skip-sidebar-gadgets` | Skip Picture Puzzle, Calendar and Currency |
| `--skip-gtk` | Skip the Windows 7 Better GTK theme |
| `--skip-linver` | Skip the LinVer `winver` clone |
| `--skip-kde` | Skip Plasma/KWin configuration |
| `--skip-trash` | Skip the Recycle Bin desktop icon |
| `--skip-sddm` | Skip the SDDM theme and default session |
| `--skip-konsole` | Skip the Command Prompt lookalike |
| `--skip-shortcuts` | Skip Meta and PrintScreen shortcut setup |
| `--skip-wallpaper` | Skip wallpaper download and resize |
| `--skip-verify` | Skip the final checks |
| `--verify-only` | Run the preflight and final checks only |
| `--keep-iso` | Keep the ISO and WIM extraction tree |
| `--reinstall-atp` | Rebuild AeroThemePlasma |
| `--reinstall-gadgets` | Rebuild the AeroShell desktop gadgets |
| `--reinstall-sidebar-gadgets` | Rebuild the Sidebar gadgets |
| `--reinstall-gtk` | Reinstall the GTK theme |
| `--reinstall-linver` | Rebuild LinVer |
| `--force` | Continue on a non-Arch system (unsupported) |
| `--dry-run` | Print the steps; state directories and the log are still created |

## Environment overrides

```bash
WIN7_ISO=/path/to/Windows7.iso ./install.sh      # use a local ISO
WALLPAPER_SRC=/path/to/harmony.jpg ./install.sh
```

`--skip-fonts` is an alias for `--skip-assets`.

A local ISO with a different SHA-1 is accepted with a warning because it is the
user's own image. The default download is checked against the tested Microsoft
hash, and a mismatch is fatal.

## What runs

The scripts run in this order:

| Step | Script | Purpose |
|---|---|---|
| 1 | `00-preflight.sh` | Arch, `sudo`, disk, network, session |
| 2 | `10-deps.sh` | Repository packages |
| 3 | `20-capslock.sh` | Caps Lock → Ctrl |
| 4 | `30-assets.sh` | ISO verify and asset extraction |
| 5 | `40-atp.sh` | AeroThemePlasma install |
| 6 | `45-gadgets.sh` | Desktop gadgets |
| 7 | `46-sidebar-gadgets.sh` | Sidebar gadget ports |
| 8 | `47-gtk.sh` | GTK theme |
| 9 | `48-linver.sh` | LinVer |
| 10 | `50-kde.sh` | Plasma/KWin configuration |
| 11 | `55-desktop-trash.sh` | Recycle Bin icon |
| 12 | `60-sddm.sh` | SDDM theme and session |
| 13 | `70-konsole.sh` | Command Prompt |
| 14 | `72-shortcuts.sh` | Meta and PrintScreen |
| 15 | `80-wallpaper.sh` | Harmony wallpaper |
| 16 | `90-verify.sh` | Final checks |

## After install

1. Log out.
2. Select the **AeroThemePlasma** session. It is preselected for your user in SDDM.
3. Accept AeroThemePlasma's first-run wizard. It finalizes effects, fonts, SDDM
   sync and the shell.

After that, the desktop uses SevenStart, SevenTasks and the Aero decorations.

## Using the desktop

### Desktop gadgets

The AeroShell gadgets are installed system-wide. Right-click the desktop, choose
**Add Widgets**, and select **Clock**, **CPU**, **Notes**, **RSS** or
**Slideshow**. They are desktop widgets, not replacements for the panel clock.

### Sidebar gadgets

The installer adds three widgets ported from the official Windows 7 Sidebar
packages: **Picture Puzzle**, **Calendar** and **Currency**. Add them from
**Add Widgets**.

Only QML and configuration are in this repository. The Microsoft artwork is
extracted from the Windows 7 ISO at install time by `30-assets.sh` and copied
into the packages by `46-sidebar-gadgets.sh`.

- **Picture Puzzle**: 4×4 puzzle, 11 original pictures, timer, hint and the
  original win message.
- **Calendar**: month grid plus tear-off day page in the undocked layout, one
  day page in the docked layout. Arrows change the month; the month/year title
  opens the 12-month view.
- **Currency**: converts one base amount into three target currencies. It uses
  the Frankfurter API (European Central Bank reference rates) because the
  original Windows Live service is gone. Rates update daily; the widget shows
  the rate age and an offline state.

Each widget has a **Configure** dialog for layout and settings.

### Recycle Bin

The installer adds a **Recycle Bin** desktop icon and points `XDG_DESKTOP_DIR`
at `~/Desktop`. Double-clicking opens `trash:/`; the icon switches between empty
and full through a systemd user path unit.

The desktop file is a Link, not an Application, so Plasma does not show an
"Open or Execute?" dialog. That behaviour depends on the Folder View URL being
exactly `desktop:/`, which the installer also sets.

Limits: the icon is not a drop target, and it follows the home Trash only
(a Trash on another partition has its own `.Trash-<uid>` directory).

If the installer ran from a TTY, log in and re-run the step so the systemd units
are enabled:

```bash
ROOT="$PWD" bash scripts/55-desktop-trash.sh
```

### Shortcuts

| Key | Action |
|---|---|
| **Windows/Meta** | Opens SevenStart |
| **Alt+F1** | Stock application launcher (moved off Meta) |
| **PrintScreen** | Spectacle |
| **Shift+Print** | Full desktop |
| **Meta+Print** | Active window |
| **Meta+Shift+Print** | Rectangular region |

### Command Prompt

Run `cmd` or select **Command Prompt** from the application menu. It opens
Konsole with the Windows 7 console palette, Consolas 12, an 80×25 grid, hidden
chrome, the `Microsoft Windows [Version 6.1.7601]` banner and Windows-style
paths.

Aliases: `dir`, `cls`, `copy`, `move`, `del`, `type`, `md`, `rd`, `where`,
`ipconfig`, `tasklist`, `taskkill`, `ver`, `vol`, `title`.

### GTK and winver

The Windows 7 Better GTK2/3/4 theme is installed and selected; restart GTK
applications, including Firefox, to load it. The libadwaita override is copied
to `~/.config/gtk-4.0`.

GTK3 and GTK4 come from the Arch repositories. GTK2 is AUR-only (`gtk2`);
`gtk2-compat` is a GTK3 shim and is not a substitute.

Run `linver` for the Windows 7-style **About Windows** dialog.

### Windows applications (optional)

The `wine/` directory installs genuine Windows 7 Notepad, WordPad, Paint and
On-Screen Keyboard from the ISO into a Wine prefix, with real icons and native
HiDPI. See [WIN7-APPS.md](WIN7-APPS.md).

## Verify

```bash
./install.sh --verify-only
```

The checks re-read the installed configuration and files. Results are appended
to `~/.local/share/win7-aero/install.log`.

## Uninstall

```bash
./uninstall.sh          # asks for confirmation
./uninstall.sh --yes    # no prompt
./uninstall.sh --purge  # also delete ~/.local/share/win7-aero
```

The uninstaller runs AeroThemePlasma's own uninstaller, removes the gadgets and
Sidebar widgets, the Recycle Bin icon and its updater, the GTK theme and LinVer,
reinstalls the distro `libplasma`, removes fonts/sounds/cursors, restores the
most recent configuration backup and restores the SDDM configuration backup.

It removes the Recycle Bin desktop file only when it contains the installer
marker, so a user-created icon with the same name is left alone. Other user
files are not touched.
