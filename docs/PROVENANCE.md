# Provenance: third-party game payloads vs the retail ISO

The Windows 7 games used alongside this conversion are installed from the
third-party [win7games.com](https://win7games.com/) package. The package is not
installed by this repository; it is an external companion. That package is not
Microsoft signed and its installer is a repackaging, so every game binary it
installs was compared against a verified retail Microsoft image. This page
records the method, the hashes and the verdict.

**Verdict: no evidence of malware. Two deliberate modifications were found — an
OS-version compatibility patch in every game EXE and a fake activation DLL
(`slc.dll`). Both are documented below; the `slc.dll` replacement is the one to
be aware of.**

## Image used

| | |
|---|---|
| File | `en_windows_7_ultimate_with_sp1_x64_dvd_u_677332.iso` |
| Source | `archive.org/download/en_windows_7_ultimate_with_sp1_x64_dvd_u_677332_202207` |
| SHA-1 | `36ae90defbad9d9539e649b193ae573b77a71c83` |
| SHA-256 | `36f4fa2416d0982697ab106e3a72d2e120dbcdb6cc54fd3906d06120d0653808` |
| WIM image compared | index 2, `Windows 7 HOMEPREMIUM` |

The SHA-1 is the published MSDN hash for this filename, so the image is the
genuine Microsoft DVD and not a tweaked build.

## Method

1. Install the win7games.com 4.3 package into a throwaway prefix so the files
   are pristine — no MUI merge and no audio patch applied.
2. Extract `/Program Files/Microsoft Games`, `/Windows/System32/CardGames.dll`
   and `/Windows/System32/slc.dll` from the WIM with `wimlib-imagex`.
3. SHA-256 every file and diff the executables section by section.

## Results

| Group | Files | Result |
|---|---|---|
| DLLs, MUI files, PNGs | 19 | byte-identical to the ISO |
| Game executables | 8 | differ by exactly **2 bytes** in `.text` |
| `CardGames.dll` (shipped per game) | 4 | byte-identical to the ISO's `System32` copy |
| `slc.dll` (shipped per game) | 8 | **replaced with a 2 KB stub** |

### 1. Executables: 2-byte OS-version patch

Every game EXE differs from the retail binary by exactly one instruction in
`.text`, for example:

```text
solitaire.exe  @204297  3b c6  ->  39 c0
freecell.exe   @182957  3b c6  ->  39 c0
chess.exe      @279689  3b c6  ->  39 c0
```

`cmp eax, esi` becomes `cmp eax, eax` (a comparison forced to always match).
This is the well-known "run the Windows 7 games on Windows 8+" compatibility
patch — PCGamingWiki documents the same two-byte edit for Chess Titans. The
win7games.com installer applies it to every game so they start on newer Windows. It is a
deliberate behaviour change, not malicious code.

### 2. `slc.dll`: activation-check bypass

The genuine Windows 7 `System32\slc.dll` is **30,720 bytes** and exports the
full Software Licensing Client API (`SLClose`, `SLConsumeRight`,
`SLGenerateOfflineInstallationId`, …).

The file shipped in every game folder is **2,048 bytes**, exports only
`SLGetWindowsInformationDWORD`, and disassembles to:

```asm
mov  eax, 1
ret
mov  dword ptr [rdx], 1
xor  eax, eax
ret
```

The games call this to ask whether Windows is activated; the stub always
answers "yes". This is a licensing bypass. It is not malware, but it is not a
Microsoft binary either, and it should not be treated as one.

### 3. `CardGames.dll` is genuine

The per-game `CardGames.dll` is byte-identical to the ISO's
`Windows\System32\CardGames.dll`
(`959f28d9c016d64552321a46c8179fdb5241f24dedfacbb71c4dd2d51da0b05a`).

### 4. Everything else matches

All MUI resource files, the `*MCE.png` artwork and the game DLLs are
byte-identical to the retail image. No unknown executables or DLLs were found
beyond the `slc.dll` replacement. The only other files present are the
installer's own `unins000.*` uninstaller and the `games.ico` shell icon, which
are not game payloads and are excluded from the table below.

## Full hash table

The table below is generated from the comparison; `2-byte .text patch` rows
differ from the ISO only at the offsets shown above.

| File | SHA-256 (win7games.com) | SHA-256 (Windows 7 ISO) | Result |
|---|---|---|---|
| `Chess/chess.dll` | `64c25845a595cecbc279d170475e9287b8aafa1d5d86af3fc0230b634d3d9b95` | `64c25845a595cecbc279d170475e9287b8aafa1d5d86af3fc0230b634d3d9b95` | match |
| `Chess/chess.exe` | `0f43907c81a248e955e771c258329e929ff6f8ee10bd8431aa496d353c590487` | `9b39147e1ba781ea8e463c22700f6ce354ac5e775e36657fd87bf41074835602` | 2-byte .text patch (2 bytes differ) |
| `Chess/ChessMCE.png` | `39e75cb96943df0b8a66bd48ed06bd87caa58533449aa0c89b17b89dfddbd316` | `39e75cb96943df0b8a66bd48ed06bd87caa58533449aa0c89b17b89dfddbd316` | match |
| `Chess/en-us/Chess.exe.mui` | `38b2fb19429d669db7339c9e505555cf065bf694fe7a9711f0ed4a1c05335c1a` | `38b2fb19429d669db7339c9e505555cf065bf694fe7a9711f0ed4a1c05335c1a` | match |
| `Chess/slc.dll` | `9c2ad5c652b0c183e8f9451232bad811f040d93be5557febf6ad47a694642148` | `90a88986c8c5f30fb153ec803feda6572b2c2630a6c9578fcc017800692694d5` | **REPLACED — 2 KB stub** |
| `FreeCell/CardGames.dll` | `959f28d9c016d64552321a46c8179fdb5241f24dedfacbb71c4dd2d51da0b05a` | `959f28d9c016d64552321a46c8179fdb5241f24dedfacbb71c4dd2d51da0b05a` | match (ISO System32) |
| `FreeCell/en-us/FreeCell.exe.mui` | `9bd2aa17372290b7126b0227458a06b21514bbbd8fd7ba7596a841040c547cad` | `9bd2aa17372290b7126b0227458a06b21514bbbd8fd7ba7596a841040c547cad` | match |
| `FreeCell/FreeCell.exe` | `f7e6b4184ba95af30e3f8edf4c0322691662e8132ae43c5d70870747597769c2` | `93609f1c460fb778e4ae7809455febba3476dcca7c14a461066767442e166f8a` | 2-byte .text patch (2 bytes differ) |
| `FreeCell/FreeCellMCE.png` | `5b3836cbdaa75ae229691de3ae29acf38859d761b74e62a8fe77c8faa243717d` | `5b3836cbdaa75ae229691de3ae29acf38859d761b74e62a8fe77c8faa243717d` | match |
| `FreeCell/slc.dll` | `9c2ad5c652b0c183e8f9451232bad811f040d93be5557febf6ad47a694642148` | `90a88986c8c5f30fb153ec803feda6572b2c2630a6c9578fcc017800692694d5` | **REPLACED — 2 KB stub** |
| `Hearts/CardGames.dll` | `959f28d9c016d64552321a46c8179fdb5241f24dedfacbb71c4dd2d51da0b05a` | `959f28d9c016d64552321a46c8179fdb5241f24dedfacbb71c4dd2d51da0b05a` | match (ISO System32) |
| `Hearts/en-us/Hearts.exe.mui` | `89ae43168fe914479b706e4757cf4c70a354d959d96ecaa9d8224212dad3f199` | `89ae43168fe914479b706e4757cf4c70a354d959d96ecaa9d8224212dad3f199` | match |
| `Hearts/Hearts.exe` | `ada013b603e870ebe577d9603931b5dabc2ba7697116146b9a0e4a390ed0e7b4` | `a5bf1cc9dad3f2c8f6212f7bf7e98ddd65528c1243b2b1f697fdd12fbfbe9e7b` | 2-byte .text patch (2 bytes differ) |
| `Hearts/HeartsMCE.png` | `134c358f14e5c1da69f5c5e4297e9ba9784214c5c9d70f9608c96016b38b9c95` | `134c358f14e5c1da69f5c5e4297e9ba9784214c5c9d70f9608c96016b38b9c95` | match |
| `Hearts/slc.dll` | `9c2ad5c652b0c183e8f9451232bad811f040d93be5557febf6ad47a694642148` | `90a88986c8c5f30fb153ec803feda6572b2c2630a6c9578fcc017800692694d5` | **REPLACED — 2 KB stub** |
| `Mahjong/en-us/Mahjong.exe.mui` | `72835ccdffff164463b3e4c2927752ef5f2dbf802cd18f2c05130f349ddbf696` | `72835ccdffff164463b3e4c2927752ef5f2dbf802cd18f2c05130f349ddbf696` | match |
| `Mahjong/Mahjong.dll` | `8681c9d02e440352a7a1666712a607de2310c6b3134b78d3d6f30c68cd1517ea` | `8681c9d02e440352a7a1666712a607de2310c6b3134b78d3d6f30c68cd1517ea` | match |
| `Mahjong/Mahjong.exe` | `d6145aaad3a4dd610177bf234192a8dabc8a28fd4f5ac748c4a7062807a215b6` | `c59f21a65dcebb5e4195087c21e71e055061763c80fd9c681c6a4c0e4b276bcf` | 2-byte .text patch (2 bytes differ) |
| `Mahjong/MahjongMCE.png` | `88634c6bbd132bcf7d4ee7d931cfb066240447f5d10a3d604e71c3c071a13359` | `88634c6bbd132bcf7d4ee7d931cfb066240447f5d10a3d604e71c3c071a13359` | match |
| `Mahjong/slc.dll` | `9c2ad5c652b0c183e8f9451232bad811f040d93be5557febf6ad47a694642148` | `90a88986c8c5f30fb153ec803feda6572b2c2630a6c9578fcc017800692694d5` | **REPLACED — 2 KB stub** |
| `Minesweeper/en-us/Minesweeper.exe.mui` | `1704775ae05950a3e16bb8c9df8ce3a3bd73444e7062b326aba91b778500f836` | `1704775ae05950a3e16bb8c9df8ce3a3bd73444e7062b326aba91b778500f836` | match |
| `Minesweeper/Minesweeper.dll` | `9c858cd324b9154753b6fa09856e73ecfe64a0740d22429e46368239836d56b3` | `9c858cd324b9154753b6fa09856e73ecfe64a0740d22429e46368239836d56b3` | match |
| `Minesweeper/Minesweeper.exe` | `81157c48df91288fd3020ac581722d40e619285da541e179579b4511f8df8dc4` | `f46beabb222d534a11fc3f88b295f9e20962fc8a75cbc19ca25ebfb9b89013ac` | 2-byte .text patch (2 bytes differ) |
| `Minesweeper/slc.dll` | `9c2ad5c652b0c183e8f9451232bad811f040d93be5557febf6ad47a694642148` | `90a88986c8c5f30fb153ec803feda6572b2c2630a6c9578fcc017800692694d5` | **REPLACED — 2 KB stub** |
| `Purble Place/en-us/PurblePlace.exe.mui` | `6832e5039a96fbe2c27faed617c20f362b8f7cb0a7a955336a1b6c2b0d08018e` | `6832e5039a96fbe2c27faed617c20f362b8f7cb0a7a955336a1b6c2b0d08018e` | match |
| `Purble Place/PurblePlace.dll` | `faae4466e1b5fe6103891f69db68f8a1f59e46d727b87143abfb38771d7bed8a` | `faae4466e1b5fe6103891f69db68f8a1f59e46d727b87143abfb38771d7bed8a` | match |
| `Purble Place/PurblePlace.exe` | `44028407c9d0ded4f134dce6450bebc03058f75c88d5cb9e0c6b542738b96b0f` | `e10f315021eef7585b086547741c3b78da85e1220c161a063fe0126b17938112` | 2-byte .text patch (2 bytes differ) |
| `Purble Place/PurblePlace2.dll` | `d8f3d78ff3773cc1d57545041739a056eb12bff78cd2311ff62bc32a9e34bd61` | `d8f3d78ff3773cc1d57545041739a056eb12bff78cd2311ff62bc32a9e34bd61` | match |
| `Purble Place/slc.dll` | `9c2ad5c652b0c183e8f9451232bad811f040d93be5557febf6ad47a694642148` | `90a88986c8c5f30fb153ec803feda6572b2c2630a6c9578fcc017800692694d5` | **REPLACED — 2 KB stub** |
| `Solitaire/CardGames.dll` | `959f28d9c016d64552321a46c8179fdb5241f24dedfacbb71c4dd2d51da0b05a` | `959f28d9c016d64552321a46c8179fdb5241f24dedfacbb71c4dd2d51da0b05a` | match (ISO System32) |
| `Solitaire/en-us/Solitaire.exe.mui` | `2f8a3082e7e37a5cb1c9cf22ed0b6b3c62e9cd6588fac8d379d4db25bc05bb72` | `2f8a3082e7e37a5cb1c9cf22ed0b6b3c62e9cd6588fac8d379d4db25bc05bb72` | match |
| `Solitaire/slc.dll` | `9c2ad5c652b0c183e8f9451232bad811f040d93be5557febf6ad47a694642148` | `90a88986c8c5f30fb153ec803feda6572b2c2630a6c9578fcc017800692694d5` | **REPLACED — 2 KB stub** |
| `Solitaire/Solitaire.exe` | `531e8794492b041f81c9e23951349dc2f69a202de64feb1199b3a2d8bdf1b669` | `fd8a8fcf5c1d869864145fbbed7c2dabadd368e4e5b755821ffc4812c0eacf9f` | 2-byte .text patch (2 bytes differ) |
| `Solitaire/SolitaireMCE.png` | `4dfff21b0129a0c443208b64ae71dac6d0100ce044ae4ba71a8207e5fb7766c5` | `4dfff21b0129a0c443208b64ae71dac6d0100ce044ae4ba71a8207e5fb7766c5` | match |
| `SpiderSolitaire/CardGames.dll` | `959f28d9c016d64552321a46c8179fdb5241f24dedfacbb71c4dd2d51da0b05a` | `959f28d9c016d64552321a46c8179fdb5241f24dedfacbb71c4dd2d51da0b05a` | match (ISO System32) |
| `SpiderSolitaire/en-us/SpiderSolitaire.exe.mui` | `0ccd4d1c7f5bd7de3d13ffda23d295eb495a3ba037b58786859348ea253f3fce` | `0ccd4d1c7f5bd7de3d13ffda23d295eb495a3ba037b58786859348ea253f3fce` | match |
| `SpiderSolitaire/slc.dll` | `9c2ad5c652b0c183e8f9451232bad811f040d93be5557febf6ad47a694642148` | `90a88986c8c5f30fb153ec803feda6572b2c2630a6c9578fcc017800692694d5` | **REPLACED — 2 KB stub** |
| `SpiderSolitaire/SpiderSolitaire.exe` | `1f2e56901c2fbcc5e0584d7f9dccb5122b91c0b4b5946f6243e8070cd37eee6f` | `59ac7a6bec0c00352fd321d7375e143db940a77c4e1cade30eb9a6d38b6355f5` | 2-byte .text patch (2 bytes differ) |
| `SpiderSolitaire/SpiderSolitaireMCE.png` | `d3f0ceae6d026b75a4f60ae7301da13bca6e3f49c25b0dd9eb06be3d30429a13` | `d3f0ceae6d026b75a4f60ae7301da13bca6e3f49c25b0dd9eb06be3d30429a13` | match |
