# Windows 7 games

The installer adds the eight offline Windows 7 games from the user's own ISO:

| Game | Launcher |
|---|---|
| Solitaire | `win7games-solitaire` |
| Spider Solitaire | `win7games-spidersolitaire` |
| FreeCell | `win7games-freecell` |
| Hearts | `win7games-hearts` |
| Minesweeper | `win7games-minesweeper` |
| Chess Titans | `win7games-chess` |
| Mahjong Titans | `win7games-mahjong` |
| Purble Place | `win7games-purble-place` |

The names are desktop entries. From a terminal, use
`win7games-run "Solitaire/Solitaire.exe"`.

## Source

The games are extracted from the user's own Windows 7 ISO. The asset step
verifies the image's SHA-1 before extraction. The binaries are unmodified
except for the MUI resource merge, and no activation stub is used — Wine's own
`slc.dll` is sufficient.

The image must be the x64 edition. The 32-bit card games draw a black play area
under Wine 11. The 64-bit games from the same image render correctly.

## How it works

1. `scripts/30-assets.sh` extracts `Program Files/Microsoft Games` and
   `Windows/System32/CardGames.dll` from `install.wim` into
   `~/.local/share/win7-aero/extracted/games/`.
2. `scripts/49-games.sh` creates the shared Wine prefix if needed and sets it to
   **Windows 7**. The retail binaries reject Windows 10 and run unmodified on a
   Windows 7 version.
3. It copies Proton's vkd3d DLLs into the prefix. A bare `wineboot` prefix
   lacks them, and wined3d cannot initialise Direct3D without them.
4. It copies `CardGames.dll` into the 32-bit or 64-bit system directory,
   depending on the PE architecture of the image.
5. It merges each `*.exe.mui` resource file into its executable. Wine has no MUI
   redirection, so without this the menus and dialogs are blank.
6. It extracts each game's icon and writes a desktop entry.
7. `games/win7games-run` detects the installed Proton runtime on every launch, so
   a Proton update does not break the launchers.

There is no code patch and no activation DLL.

## Requirements

- The same Windows 7 ISO used for the theme assets
  (`en_windows_7_ultimate_with_sp1_x64_dvd_u_677332.iso`,
  SHA-1 `36ae90defbad9d9539e649b193ae573b77a71c83`)
- A Proton runtime installed through Steam
- `uv`, `7zip`, `icoutils`, ImageMagick (installed by the dependency step)

If Proton is missing, the game step warns and skips; the rest of the conversion
continues. After installing Proton:

From the checkout:

```bash
ROOT="$PWD" bash scripts/49-games.sh
```

If you installed with `get.sh`, the checkout is in `~/.cache/win7-aero/repo`:

```bash
ROOT="$HOME/.cache/win7-aero/repo" bash "$ROOT/scripts/49-games.sh"
```

If the games were not extracted because the install used `--skip-assets`, run
the asset step first.

## HiDPI

The games store their window size in their own preferences. Resize a window
once; the game remembers it. At 2× scale the card games are comfortable at
1600 px wide and Chess Titans at 1600×992 (client).

## Uninstall

From the checkout:

```bash
./games/uninstall-games.sh
```

The main uninstaller calls this step automatically.

This removes the game files, launchers and icons. The Wine prefix and saved
games are kept.
