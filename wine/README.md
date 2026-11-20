# Windows 7 applications

Installs genuine Windows 7 utilities from a retail ISO into the Proton/Wine
prefix used by the games.

From the repository root:

```bash
export WIN7_ISO=/path/to/en_windows_7_ultimate_with_sp1_x64_dvd_u_677332.iso
./wine/install-apps.sh "$WIN7_ISO"
```

Contents:

| File | Purpose |
|---|---|
| `install-apps.sh` | ISO verification, WIM extraction, MUI merge, launchers |
| `win7app-run` | Proton detection, path conversion, per-app DLL overrides |
| `uninstall-apps.sh` | Removes the applications, launchers, icons and `win7app-run` |

What the installer does:

1. Verifies the ISO SHA-256 against the known Microsoft hash
   (`36f4fa2416d0982697ab106e3a72d2e120dbcdb6cc54fd3906d06120d0653808`).
2. Extracts the binaries, their `en-US` MUI files and the shared DLLs from
   `install.wim` (`WIN7_WIM`/`WIN7_WIM_INDEX` can point at an extracted WIM).
3. Merges each MUI file into its executable — Wine has no MUI redirection.
4. Installs the ISO's `UIRibbon.dll`/`UIRibbonRes.dll` into the prefix
   `system32`, backing up Wine's stub, so WordPad and Paint can start.
5. Installs `win7app-run` plus one `.desktop` launcher per supported app, with an
   icon extracted from the binary itself. MUI merging uses the shared
   `../lib/patch_mui.py`.
6. Links the prefix's Desktop/Documents/Downloads/Music/Pictures/Videos folders to
   the user's XDG folders when they are empty.

Uninstall with `./wine/uninstall-apps.sh`.

Applications install to:

```text
~/.win7games-proton/pfx/drive_c/Program Files/Windows 7 Apps/<app>/
```

See [../docs/WIN7-APPS.md](../docs/WIN7-APPS.md) for status, HiDPI and Dolphin
integration.
