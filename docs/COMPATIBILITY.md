# Compatibility

## Tested reference

Tested configuration, last verified on 2026-11-20.

| Component | Version |
|---|---|
| Distribution | Arch Linux (rolling) |
| Plasma | 6.8.2 |
| KDE Frameworks | 6.31.0 |
| Qt | 6.12.0 |
| KWin | 6.8.2, Wayland |
| Konsole | 26.08.2 |
| Spectacle | 6.8.2 |
| Monitor | 3840×2160 at 2× scale (logical 1920×1080) |

## Component commits

`versions.lock` records the same pins. Several scripts warn when a pin has
moved; nothing is enforced, and AeroThemePlasma tracks its `Plasma/6.8` branch.

| Component | Commit / version |
|---|---|
| AeroThemePlasma | `547dcd3f68a1ceb6af46f587c08106c0ae3d64ec` (`Plasma/6.8`) |
| libplasma fork | `c962fb360e5b8288b274a5294c14e8125c02aba0` |
| uac-polkit-agent | `5627680e94bf1d24769b1b0d25e21679e269d9b6` |
| smod | `67e24c0212a955a8684701cdde05c27215618e7b` |
| aeroshell-workspace | `abb45d8d00e128e2cb85ec608161ad498abd3a20` |
| aeroshell-kwin-components | `4a28963f1f751e93350e86e2b5bf1afb5380fcd6` |
| aeroshell-sddm-kcm | `8c94283c2689b3f0837efda0be8107e42a265e0f` |
| aerothemeplasma-icons | `0100536bb0fb4b731b6cf776f3bc6dc5d3c74bfc` |
| aerothemeplasma-sounds | `55d2f5fd15f53cccbbb13388941b930442db1159` |
| AeroShell Gadgets | `b2e999165eb92c9fdd7f712e368531a205af1b70` (`master`) |
| Windows-7-Better GTK | `53d0072591167404cafc4615b5389365adff1152` |
| LinVer | `v1.0.0` (version pin) |

The Sidebar gadget ports in `gadgets/` are local packages, so they have no
upstream commit.

## Support matrix

| Area | Supported | Notes |
|---|---|---|
| Plasma 6.8 | Yes | Tested branch |
| Plasma 6.7 and older | No | AeroThemePlasma `Plasma/6.8` only |
| Wayland | Yes | Supported target |
| X11 | No | Arch has no Plasma X11 session; untested |
| Arch Linux | Yes | Only supported distribution |
| Other distributions | Unsupported | `--force` exists for experiments only |
| Multi-monitor | Yes | Wallpaper follows the primary monitor |
| 2× / fractional scale | Yes | Wine apps need matching `LogPixels` |

## Windows 7 image

| Field | Value |
|---|---|
| Item | `en_windows_7_ultimate_with_sp1_x64_dvd_u_677332_202207` |
| File | `en_windows_7_ultimate_with_sp1_x64_dvd_u_677332.iso` |
| Size | 3,320,903,680 bytes |
| SHA-1 | `36ae90defbad9d9539e649b193ae573b77a71c83` |
| SHA-256 | `36f4fa2416d0982697ab106e3a72d2e120dbcdb6cc54fd3906d06120d0653808` |

Fonts are installed directly from this image. The reference machine used
`ttf-win7-fonts 7.1-9`; this repository does not depend on an AUR helper.

## Wallpaper source

| Field | Value |
|---|---|
| File | `Harmony` / `Img0 (Windows 7).jpg` |
| Source | `static.wikitide.net` (hash-verified download) |
| Resolution | 1920×1200 |
| SHA-256 | `6ea9f8468c76aa511a5b3cfc36fb212b86e7abd377f147042d2f25572bf206a2` |

## Windows 7 games

All eight offline games are built from the retail image and run under the
installed Proton (Wine 11 base) with a Windows 7 prefix. No code patch or
activation stub is used.

| Game | Status |
|---|---|
| Solitaire | Working |
| Spider Solitaire | Working |
| FreeCell | Working |
| Hearts | Working |
| Minesweeper | Working |
| Chess Titans | Working |
| Mahjong Titans | Working |
| Purble Place | Working |

Details: [GAMES.md](GAMES.md).

## Windows applications under Wine

The optional `wine/` layer uses the same 64-bit Windows 7 Ultimate SP1 image
as the theme assets.

| Application | Status |
|---|---|
| Notepad | Working |
| WordPad | Working (native `UIRibbon.dll`). Font group is blank |
| Paint | Working (native `UIRibbon.dll`). Text tool blackens the canvas |
| On-Screen Keyboard | Working (native `duser`/`dui70`) |
| Calculator | Blocked: `COMCTL32` ordinal 392 |
| Task Manager | Blocked: `SHELL32.FixupOptionalComponents` stub |
| System Configuration | Blocked: `SHELL32.SHEvaluateSystemCommandTemplate` |
| Character Map | Blocked: COM class not registered |
| Sticky Notes | Blocked: licence value |
| Magnifier | Blocked: DirectUI `InitGadgets` |
| Windows Media Player | Not supported from extracted files |

Details and exact errors: [WIN7-APPS.md](WIN7-APPS.md).
