# Tested reference

The setup in this repo was built and verified on the following machine on
2026-11-05. It is a reference, not a hard pin: ATP tracks the `Plasma/6.8`
branch.

| Component | Version / commit |
|---|---|
| Distro | Arch Linux (rolling) |
| Plasma | 6.8.2 |
| KDE Frameworks | 6.31.0 |
| Qt | 6.12.0 |
| KWin | 6.8.2, Wayland |
| Konsole | 26.08.2 |
| Spectacle | 6.8.2 |
| Monitor | 3840×2160 @ 60 Hz, 2× scale (logical 1920×1080) |
| AeroThemePlasma | `547dcd3f68a1ceb6af46f587c08106c0ae3d64ec` (`Plasma/6.8`) |
| libplasma fork | `c962fb360e5b8288b274a5294c14e8125c02aba0` |
| uac-polkit-agent | `5627680e94bf1d24769b1b0d25e21679e269d9b6` |
| smod | `67e24c0212a955a8684701cdde05c27215618e7b` |
| aeroshell-workspace | `abb45d8d00e128e2cb85ec608161ad498abd3a20` |
| aeroshell-kwin-components | `4a28963f1f751e93350e86e2b5bf1afb5380fcd6` |
| aeroshell-sddm-kcm | `8c94283c2689b3f0837efda0be8107e42a265e0f` |
| aerothemeplasma-icons | `0100536bb0fb4b731b6cf776f3bc6dc5d3c74bfc` |
| aerothemeplasma-sounds | `55d2f5fd15f53cccbbb13388941b930442db1159` |
| Windows-7-Better GTK | `53d0072591167404cafc4615b5389365adff1152` |
| LinVer | `087f2746703d9c885de2e1a4f6360314283703f4` |

## Windows 7 source image

| Field | Value |
|---|---|
| Item | `en_windows_7_professional_with_sp1_x86_dvd_u_677056_201708` |
| File | `en_windows_7_professional_with_sp1_x86_dvd_u_677056.iso` |
| Size | 2,564,476,928 bytes |
| SHA1 | `d89937df3a9bc2ec1a1486195fd308cd3dade928` |

Fonts were installed on the reference machine through `ttf-win7-fonts 7.1-9`;
this repo installs the extracted font files directly instead.

## Wallpaper source

| Field | Value |
|---|---|
| File | `Harmony` / `Img0 (Windows 7).jpg` |
| Resolution | 1920×1200 |
| SHA256 | `6ea9f8468c76aa511a5b3cfc36fb212b86e7abd377f147042d2f25572bf206a2` |

