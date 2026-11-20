# Windows 7 applications under Wine

An optional layer that installs genuine Windows 7 utilities from the retail ISO
into a Wine prefix, with real Windows 7 icons, HiDPI support and Dolphin
integration.

It is independent of the theme: the conversion is complete without it. All
files are extracted from the retail ISO.

## Status

Working under Proton/Wine 11:

| Application | Launcher | Notes |
|---|---|---|
| Notepad | `win7-notepad` | Opens files passed from Dolphin |
| WordPad | `win7-wordpad` | Native `UIRibbon.dll`, override `uiribbon=n`. The Font group is blank |
| Paint | `win7-paint` | Native `UIRibbon.dll`, override `uiribbon=n`. The Text tool blackens the canvas |
| On-Screen Keyboard | `win7-osk` | Native `duser`/`dui70` |

The names above are desktop entries (`win7-*.desktop`). From a terminal, use
`win7app-run <name> <exe>`.

Installed but blocked by Wine 11.0:

| Application | Blocker |
|---|---|
| Calculator | `COMCTL32` ordinal 392 unimplemented in Wine's v6 comctl32 |
| Task Manager | `SHELL32.FixupOptionalComponents` is an unimplemented stub |
| System Configuration | `SHELL32.SHEvaluateSystemCommandTemplate` missing |
| Character Map | COM class `{8cec58e7-07a1-11d9-b15e-000d56bfe6ee}` not registered |
| Sticky Notes | requires the `StickyNotesLicensing-Enabled` licence value |
| Magnifier | DirectUI (`DUser.InitGadgets`) not implemented |

The blocked binaries remain installed under
`C:\Program Files\Windows 7 Apps\`, so a newer Wine may support them later.

Windows Media Player 12 cannot run from extracted files: it needs its services,
DRM components and codec stack. The practical alternatives are mpv or VLC with a
Windows 7-era skin, or the separate `winetricks -q wmp11` route.

## Requirements

- A working Proton runtime (Steam) and `uv`
- `wimlib`, `7zip`, `icoutils` (`wrestool`, `icotool`), ImageMagick
- The 64-bit Windows 7 Ultimate SP1 ISO
  (`SHA-256 36f4fa2416d0982697ab106e3a72d2e120dbcdb6cc54fd3906d06120d0653808`)
- An English (`en-US`) image: the installer reads the `en-US` MUI files

## Installation

```bash
export WIN7_ISO=/path/to/en_windows_7_ultimate_with_sp1_x64_dvd_u_677332.iso
./wine/install-apps.sh "$WIN7_ISO"
```

Optional environment variables:

| Variable | Meaning |
|---|---|
| `WIN7_WIM` | Use an already-extracted `install.wim` (the ISO is still verified) |
| `WIN7_WIM_INDEX` | WIM image index (default 1) |
| `WIN7_ISO_SHA256` | Override the expected ISO hash |
| `KEEP_WIM` | Keep the extracted WIM tree |

## How it works

1. Verifies the ISO SHA-256 before extracting anything.
2. Extracts the `.exe` and `en-US` `.mui` files from `install.wim`.
3. Extracts the shared DLLs the apps need: `mfc42u`, `UIRibbon`,
   `UIRibbonRes`, `duser`, `dui70`, `pcwum`, `getuname`, `msswch`, `wmsgapi`.
4. Merges each MUI resource file into its executable. Wine has no MUI
   redirection, so without this the menus and dialogs are blank.
5. Installs the real `UIRibbon` pair into the prefix `system32` (Wine's stub is
   backed up as `*.wine-backup`) and registers the Ribbon COM classes. Windows
   setup normally provides those classes, and the DLL does not register itself.
6. Installs `win7app-run` and one `.desktop` launcher per supported application,
   with an icon extracted from the application binary.

Files land in:

```text
~/.win7games-proton/pfx/drive_c/Program Files/Windows 7 Apps/<app>/
```

`win7app-run` selects an installed Proton runtime automatically, converts Linux
paths to Wine paths and applies the per-application DLL overrides. It is the
same runtime detection used by the games launcher.

## Known limitations

Two defects remain under Wine 11:

- **WordPad: the Font group is blank.** The font family and font size boxes
  are empty. The Bold, Italic and Underline buttons show no glyph. Text entry
  and the paragraph commands work.
- **Paint: the Text tool blackens the canvas.** Click the Text tool, then
  click the canvas. The canvas renders black and does not redraw. Close Paint
  without saving, then open it again.

These defects come from Wine, not from the extraction. A newer Wine version
may correct them.

## HiDPI

Wine is DPI-aware, so KWin does not bitmap-scale its windows. Match Wine's DPI
to the session scale instead:

```bash
# 96 = 1x, 168 = 1.75x, 192 = 2x
WINE=~/.local/share/Steam/steamapps/common/'Proton - Experimental'/files/bin/wine
WINEPREFIX=~/.win7games-proton/pfx "$WINE" reg add \
  'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d 192 /f
WINEPREFIX=~/.win7games-proton/pfx "$WINE" reg add \
  'HKCU\Control Panel\Desktop' /v Win8DpiScaling /t REG_DWORD /d 1 /f
```

Fonts, menus and dialogs then render natively at the session scale. Game and
application windows store their size in pixels; at 2× the card games are 1600 px
wide and Chess Titans uses a 1600×992 client area.

## Icons

Every launcher uses the icon embedded in its own Windows binary, extracted with
`wrestool` and `icotool` and installed into
`~/.local/share/icons/hicolor/<size>/apps/`. No generic Wine icon remains in the
menu.

## Integration with Dolphin

The prefix's shell folders are symlinked to the XDG folders:

```text
.../users/steamuser/Desktop   -> ~/Desktop
.../users/steamuser/Documents -> ~/Documents
.../users/steamuser/Downloads -> ~/Downloads
.../users/steamuser/Pictures  -> ~/Pictures
.../users/steamuser/Music     -> ~/Music
.../users/steamuser/Videos    -> ~/Videos
```

The installer creates these links when the prefix is new; a non-empty prefix
folder is left alone with a note. Wine's Open/Save dialogs and Dolphin therefore
see the same files, and `Z:` maps to `/`. Wine still draws its own dialogs (comdlg32); KDE's file dialog is not
used. A native bridge exists as
[aglab2/wine_xdg_portal](https://github.com/aglab2/wine_xdg_portal), but it is
unpackaged and experimental.

Files open from Dolphin through the launchers' `%F` argument; `win7app-run`
converts the path with `winepath -w`, so spaces and unicode work.

## Default applications (optional)

```bash
xdg-mime default win7-notepad.desktop text/plain
xdg-mime default win7-wordpad.desktop application/rtf
xdg-mime default win7-paint.desktop image/bmp
```

Prefer registering only `text/plain` and `application/rtf` unless Windows 7
Notepad should handle every text file; it has no tabs and limited UTF-8 support.

## Uninstall

```bash
./wine/uninstall-apps.sh
```

This removes the applications, launchers and icons, restores Wine's `UIRibbon`
stub and removes `win7app-run`. The Wine prefix and the shared folder links are
kept.

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for blank menus, the WordPad/Paint
"Unable to create new document" error, HiDPI and the Proton symlink failure.
