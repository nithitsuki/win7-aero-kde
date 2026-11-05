# win7-aero-kde

One-shot Windows 7 Aero theming for **KDE Plasma 6.8 on Arch Linux**, built from
the setup that was tested live on a 4K Wayland desktop.

It does the annoying parts in the right order, including the traps:

- Caps Lock → Ctrl **with `ResetOldOptions=true`** (without it KWin ignores `Options=`)
- Installs the missing `wayland-protocols` dependency before building ATP
- Uses the **genuine Windows 7 ISO** and verifies the SHA1 before extracting anything
- Downloads the ISO with 16 aria2c connections instead of a 45-minute single curl
- Uses `CMAKE_GENERATOR=Ninja` because ATP's `--ninja` flag is silently ignored
- Verifies ATP actually installed all its pieces; the upstream script exits 0 even
  when a component fails
- Detects the monitor's **native** mode (e.g. 3840×2160 at 2× scale) and renders
  the wallpaper at that resolution
- Installs a Konsole-based **Command Prompt** lookalike with Windows paths,
  aliases, black/silver palette, Consolas and the correct 80×25 shape
- Binds the **Windows/Meta key** to SevenStart (the stock launcher action is
  removed from Meta because it has no visible launcher in the ATP shell)
- Installs **Spectacle** so **PrintScreen** opens the screenshot UI
- Backs up configs and provides an uninstall path

> ⚠️ AeroThemePlasma is not a simple theme. Its official installer replaces the
> distro `libplasma` with a fork that adds four `PlasmaQuick::Dialog` properties
> (`customImagePath`, `marginsEnabled`, `shadowEnabled`, `shadowBordersSync`) so
> Aero popups can draw their own frames/shadows. This repo automates that official
> install path. The uninstaller restores the distro package.

## Tested on

- Arch Linux, Plasma **6.8.2**, KDE Frameworks **6.31.0**, Qt **6.12.0**
- KWin Wayland, 3840×2160 native at 2× scale
- AeroThemePlasma `Plasma/6.8` @ `547dcd3`
- Windows 7 Professional SP1 x86 ISO
  SHA1 `d89937df3a9bc2ec1a1486195fd308cd3dade928`

See [docs/TESTED.md](docs/TESTED.md) and [docs/HICCUPS.md](docs/HICCUPS.md).

## Requirements

- Arch Linux with KDE Plasma already installed
- `sudo` (a password prompt is fine; the installer asks once)
- ~10 GB free disk (ISO + WIM + builds)
- Network access
- An existing graphical KDE session is recommended. The installer can run from a
  TTY, but the live theme apply is skipped until login.

## One-shot install

```bash
gh repo clone YOUR_GITHUB_USER/win7-aero-kde
cd win7-aero-kde
./install.sh

# or
git clone https://github.com/YOUR_GITHUB_USER/win7-aero-kde.git
cd win7-aero-kde
./install.sh
```

Replace `YOUR_GITHUB_USER` with the account that owns the repository.

The script is idempotent. Re-running it skips already-installed pieces and
rebuilds only when asked.

### Options

```text
--skip-deps        Skip pacman dependency installation
--skip-caps        Skip Caps Lock -> Ctrl
--skip-assets      Skip Windows 7 ISO/fonts/sounds/icons extraction
--skip-atp         Skip AeroThemePlasma build/install
--skip-kde         Skip Plasma/KWin theme configuration
--skip-sddm        Skip SDDM theme/session configuration
--skip-konsole     Skip the Command Prompt lookalike
--skip-shortcuts   Skip Windows-key and screenshot shortcut setup
--skip-wallpaper   Skip wallpaper download/resize
--skip-verify      Skip final checks
--keep-iso         Keep the ISO and WIM extraction tree
--reinstall-atp    Rebuild ATP even if already installed
--force            Continue on non-Arch (unsupported)
--dry-run          Print steps without changing anything
```

Environment overrides:

```bash
WIN7_ISO=/path/to/Win7.iso ./install.sh       # use a local ISO
WALLPAPER_SRC=/path/to/harmony.jpg ./install.sh
```

A local ISO with a different SHA1 is accepted with a warning (it is your image).
The default download is always checked against the tested Microsoft hash; a
mismatch there is fatal.

## After install

1. Log out.
2. Pick the **AeroThemePlasma** session — it is already preselected in SDDM.
3. Accept ATP's first-run OOTB wizard.

The first login runs ATP's OOTB helper, which finalizes effects, fonts, SDDM
sync and the shell. After that, the desktop uses SevenStart/SevenTasks.

## Shortcuts

- **Windows/Meta** opens SevenStart. The stock `activate application launcher`
  action is removed from Meta at login because it has no visible target in the ATP
  shell and would otherwise swallow the key.
- **PrintScreen** opens Spectacle. Spectacle's desktop file registers the
  shortcut through `X-KDE-Shortcuts=Print`; the dependency step installs it.
- **Shift+Print** captures the full desktop, **Meta+Print** the active window,
  and **Meta+Shift+Print** a rectangular region.

## Command Prompt

Run `cmd` or pick **Command Prompt** from the app menu. It opens Konsole with the
Win7 console palette, Consolas 12, 80×25, hidden chrome, a
`Microsoft Windows [Version 6.1.7601]` banner and Windows-style paths.

CMD aliases include `dir`, `cls`, `copy`, `move`, `del`, `type`, `md`, `rd`,
`where`, `ipconfig`, `tasklist`, `taskkill`, `ver`, `vol`, `title`.

## Verify

```bash
./install.sh --skip-deps --skip-assets --skip-atp --skip-kde \
             --skip-sddm --skip-konsole --skip-wallpaper
```

Or read the final section of `~/.local/share/win7-aero/install.log`.

## Uninstall

```bash
./uninstall.sh          # asks for confirmation
./uninstall.sh --yes    # no prompt
./uninstall.sh --purge  # also delete ~/.local/share/win7-aero
```

This runs ATP's own uninstaller, reinstalls the distro `libplasma`, removes the
fonts/CMD/sounds, restores the most recent config backup and puts SDDM back.

## Repo layout

```text
install.sh                 orchestrator
uninstall.sh               reversible teardown
lib/common.sh              logging, sudo, backups, helpers
scripts/00-preflight.sh    Arch/sudo/disk/network checks
scripts/10-deps.sh         pacman dependencies, incl. wayland-protocols
scripts/20-capslock.sh     Caps Lock -> Ctrl (with ResetOldOptions)
scripts/30-assets.sh       ISO download, hash check, fonts/sounds/icons/cursors
scripts/40-atp.sh          ATP clone/build/install + completeness checks
scripts/50-kde.sh          look-and-feel, fonts, effects, decoration
scripts/60-sddm.sh         SDDM theme and default session
scripts/70-konsole.sh      Command Prompt lookalike
scripts/72-shortcuts.sh    Meta -> SevenStart, PrintScreen -> Spectacle
scripts/80-wallpaper.sh    native-resolution Harmony wallpaper
scripts/90-verify.sh       end-to-end checks
assets/                    Konsole profile, colorscheme, bashrc, icon, desktop files
docs/HICCUPS.md            every trap and how it is handled
docs/TESTED.md             reference versions and component commits
versions.lock              tested ATP/component commits (reference only)
```

## Copyright

This repo contains only original scripts, configs and an original SVG icon. It
does **not** redistribute Windows assets or the Harmony wallpaper. The installer
downloads/extracts them from Microsoft images for personal use. Windows, Aero and
Command Prompt are Microsoft trademarks.
