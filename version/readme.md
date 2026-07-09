# Forth TX16 — build versions

This folder holds one subfolder per **buildable version** of Forth TX16. Each
version is self-contained: it has its own `build.asm`, `make.bat`, `test.bat`,
and `readme.md`, and its regenerated release binary lands **in that folder**.

---

## ⚠️ Prerequisites you must supply yourself (not in this repo)

These folders are **git-ignored and are NOT on GitHub** — after cloning, you have
to put them in the repo root yourself before anything will build or run:

| Folder | What | Where to get it |
|---|---|---|
| `asm/` | The **ACME** cross-assembler (`asm/acme.exe`) — required to build every version | https://sourceforge.net/projects/acme-crossass/files/win32/ |
| `emulator/` | The official **Commander X16 emulator** (`emulator/x16emu.exe` + `emulator/rom.bin`) — required to test the X16 versions | https://github.com/X16Community/x16-emulator/releases |
| `vice/` | **VICE** (`vice/bin/x64sc.exe`, `cartconv.exe`) — required to build/test the C64 versions | https://vice-emu.sourceforge.io/ |

The **Foenix F256** has no bundled emulator; test its `.pgz` with the
[Foenix IDE](https://github.com/Trinity-11/FoenixIDE) (see that version's readme).

Everything else the builds need — `fthtx16.asm` and its platform includes
(`x16.asm`, `x16prims.asm`, `fileio_c64.asm`, `fileio_f256.asm`,
`console_F256.asm`, …), plus `loader.prg`/`loader32.prg` — lives in the repo root
and **is** in the repo.

---

## How each version folder works

- **`build.asm`** — the ACME entry point: sets the build flags, then
  `!source "fthtx16.asm"`.
- **`make.bat`** — assembles from the **repo root** (so ACME's `!source` paths
  resolve) and writes the release binary **into this folder**, named after the
  folder. Just run it.
- **`test.bat`** — runs `make.bat`, then launches the right emulator for that
  platform.
- **`readme.md`** — what the version is, its platform/CPU, the source files and
  build flags it uses, the release binary name, and how to test it.

### The bundled SD card (X16 test.bats)

Every X16 `test.bat` launches with **`-sdcard sdcard\sdcard.img`**, a ready-made
35 MB FAT32 card so device 8 is stocked with all the `toolkit/` and `other/`
`.FTH` files, the `HELP` system (loader + `helpdoc/` topics), the ROM-bank-32
`LOADER`/`LOADER32`, and an `AUTORUN.FTH` that loads `HELP` and prints a hint. So
after any X16 build boots you can immediately `S" ASSEMBLER.FTH" INCLUDED`,
`INCLUDE HELP` (already loaded — just type `HELP`), `DIR`, etc. Rebuild the image
with **`python sdcard/make_sdcard.py`** (needs `pip install pyfatfs`); 35 MB is the
smallest spec-valid FAT32 (the X16 KERNAL is FAT32-only). Verified on the PRG,
Wide and 65C02 bank-9 builds.

## The versions

| Folder | Platform / CPU | Release binary | Test with |
|---|---|---|---|
| [ForthC64_6502Prg](ForthC64_6502Prg/readme.md) | C64 · 6502 | `ForthC64_6502Prg.prg` | VICE `x64sc` |
| [ForthC64_6502Cart](ForthC64_6502Cart/readme.md) | C64 cartridge · 6502 | `ForthC64_6502Cart.crt` | VICE `-cartcrt` |
| [ForthC64_6502Disk](ForthC64_6502Disk/readme.md) | C64 disk image · 6502 | `ForthC64_6502Disk.d64` | VICE `x64sc` |
| [ForthF256_6502Prg](ForthF256_6502Prg/readme.md) | Foenix F256 · 65C02 | `ForthF256_6502Prg.pgz` | Foenix IDE (manual) |
| [ForthX16_6502Prg](ForthX16_6502Prg/readme.md) | Commander X16 · 6502 | `ForthX16_6502Prg.prg` | `x16emu` |
| [ForthX16_6502Bank9](ForthX16_6502Bank9/readme.md) | X16 ROM bank 9 · 65C02 | `ForthX16_6502Bank9.bin` | `x16emu` (ROM patch, `TEST`) |
| [ForthX16_6502Bank32](ForthX16_6502Bank32/readme.md) | X16 ROM bank 32 · 65C02 | `ForthX16_6502Bank32.bin` | `x16emu -cartbin` + `loader32` |
| [ForthX16_6502Cart](ForthX16_6502Cart/readme.md) | X16 autoboot cart · 6502 | `ForthX16_6502Cart.bin` | `x16emu -cartbin` (autoboots) |
| [ForthX16_816Prg](ForthX16_816Prg/readme.md) | X16 · 65816 native | `ForthX16_816Prg.prg` | `x16emu -c816` |
| [ForthX16_816Bank9](ForthX16_816Bank9/readme.md) | X16 ROM bank 9 · 65816 | `ForthX16_816Bank9.bin` | `x16emu -c816` (ROM patch, `TEST`) |
| [ForthX16_816Bank32](ForthX16_816Bank32/readme.md) | X16 ROM bank 32 · 65816 | `ForthX16_816Bank32.bin` | `x16emu -c816 -cartbin` + `loader32` |
| [ForthX16_816WideRom](ForthX16_816WideRom/readme.md) | X16 · 65816, wide dict in ROM banks | `ForthX16_816WideRom.prg` | `x16emu -c816` (real MiSTer) |
| [ForthX16_816WideRam](ForthX16_816WideRam/readme.md) | X16 · 65816, wide dict in RAM banks | `ForthX16_816WideRam.prg` | `x16emu -c816` |
| [ForthX16_816WideFar](ForthX16_816WideFar/readme.md) | X16 · 65816, wide dict + far headers | `ForthX16_816WideFar.prg` | `x16emu -c816` |

### Size & memory reference

`Size` = the interpreter image (the code); `Free` = low-RAM dictionary/data
space the interpreter reports at boot ("`NNNNN BYTES FREE`"). All X16 figures are
with the default `GFXTOOLKIT=1` (graphics moved to `GFX.FTH`). The **Bank** builds
run the interpreter from a ROM bank, so nearly all low RAM is free for the
dictionary; every X16 build can additionally stream data into the high-RAM banks
(`BANKLOAD`/`BANK>MEM`, all CPUs).

| Folder | Description | Free (bytes) | Size (bytes) | Where code / data live |
|---|---|--:|--:|---|
| ForthC64_6502Prg | C64 program | — | 8319 | code + data in low RAM ($0801+) |
| ForthC64_6502Cart | C64 8K cartridge | — | 8192 | code in the 8K cart ROM; data + dictionary in low RAM |
| ForthC64_6502Disk | C64 program on a .d64 | — | 8319¹ | code + data in low RAM (loaded from the .d64) |
| ForthF256_6502Prg | Foenix F256 .pgz | — | 8879 | code + data in F256 RAM ($200+) |
| ForthX16_6502Prg | X16 program, 6502 | **15941** | 15715 | code + data in low RAM ($0801+) |
| ForthX16_6502Bank9 | X16 in ROM bank 9, 65C02 | **30887** | 16242² | **code in ROM bank 9**; data + dictionary in low RAM |
| ForthX16_6502Bank32 | X16 in ROM bank 32, 65C02 | ~30887 | 16242² | **code in ROM bank 32**; data + dictionary in low RAM |
| ForthX16_6502Cart | X16 autoboot cart, 6502 | ~15941 | 15715 | code copied to low RAM ($0801) at boot; data + dictionary in low RAM (cart `.bin` is 16 KB) |
| ForthX16_816Prg | X16 program, 65816 | **15956** | 15700 | code + data in low RAM ($0801+) |
| ForthX16_816Bank9 | X16 in ROM bank 9, 65816 | **30887** | 16227² | **code in ROM bank 9**; data + dictionary in low RAM, **+ all high-RAM banks free for data** |
| ForthX16_816Bank32 | X16 in ROM bank 32, 65816 | ~30887 | 16227² | **code in ROM bank 32**; data + dictionary in low RAM, **+ all high-RAM banks** |
| ForthX16_816WideRom | X16, wide dict in ROM banks | 12650 ³ | 17173 | interpreter code, word headers + data in low RAM; **compiled word bodies in 16K ROM banks 33+** ($C000 window) |
| ForthX16_816WideRam | X16, wide dict in RAM banks | 12536 ³ | 17287 | interpreter code, word headers + data in low RAM; **compiled word bodies in 8K RAM banks** ($A000 window) |
| ForthX16_816WideFar | X16, wide dict + far headers | 11674 ³ | 18121 | interpreter code + data in low RAM; **word headers + bodies in 8K RAM banks** ($A000 window) |

¹ interpreter code; the `.d64` disk image itself is 174848 bytes (it also carries
the test suite + toolkits). ² **real bytes used in the bank** (not 16384): the raw
ROM-bank image is padded to a full 16 KB (**16384-byte**) bank file, and the
`Bank9`/`Bank32` **release file** is the whole 256 KB ROM (pristine ROM + this
bank). ³ the *near* free — the wide builds also grow the dictionary into RAM/ROM
banks well beyond this. C64/F256 boot-free is platform-specific and not measured
here.

**X16 6502 vs 65816.** The `6502` X16 builds run on the stock CPU; the `816`
builds need a 65C816 (a MiSTer core, or `x16emu -c816`). The three **Wide** builds
add the 65816 `WIDEDICT` large dictionary — `WideRam`/`WideFar` store code (and,
for `WideFar`, headers) in 8 KB RAM banks and are emulator-testable; `WideRom`
stores code in 16 KB ROM banks and is meant for real MiSTer hardware.

**`Bank9` / `Bank32` (65C02 and 65816).** These run the interpreter *in place*
from an X16 ROM bank, freeing ~31 KB of low RAM. `Bank9` replaces the demo bank
and is started with `TEST`; `Bank32` uses the MiSTer cartridge bank and is
started with `loader32`. The **816** ones additionally have the bank-I/O words
(`BANKLOAD`/`BANK>MEM`/…) built in, so every high-RAM bank is usable for data.
`ForthX16_6502Cart` is a different thing — an *auto-booting* cartridge that
copies the PRG into RAM and starts it with no loader.

**Graphics are a toolkit (all X16 builds).** The bitmap-graphics words
(`GINIT`/`PSET`/`LINE`/`RECT`/`OVAL`/`GTEXT`/…) are **not** baked into the X16
builds anymore — that saves ~513 bytes everywhere (which is what lets the ROM
builds carry the bank words). `INCLUDE GFX.FTH` (in `toolkit/`) to get them, or
bundle it into a `TK` image (below). Build with `GFXTOOLKIT=0` to bake them back
into the core the old way.

---

## Toolkit image (`TK*.*`) and AUTORUN

Recompiling the toolkit libraries from source at every boot is slow (tens of
seconds). Instead you compile them once and take a **`SAVE-IMAGE` snapshot** —
the `TK.DIC` / `TK.TOK` / `TK.VAR` files — which reloads in about a second. A
one-line `AUTORUN.FTH` then loads that snapshot automatically at boot.

> ⚠️ **A `TK` image is locked to the exact binary that made it.** An image built
> on one version will **not** load on another version, or even on the *same*
> version after you rebuild it — loading a stale image corrupts the dictionary.
> So build a fresh `TK` image **per version**, and rebuild it whenever you
> rebuild that version's binary. (This is mainly a **Commander X16** concern —
> the toolkit libraries need the X16 words.)

### Recreate the toolkit image + AUTORUN manually

1. **Make the source files reachable.** `SAVE-IMAGE` / `LOAD-IMAGE` and `INCLUDE`
   all use device 8 = HostFS (the folder you launch the emulator from) or the
   SD-card image. Put the toolkit `.FTH` files there — from `toolkit/`:
   `FPX.FTH`, `BASICSTR.FTH`, `ASSEMBLER.FTH`, `GFX.FTH` (add
   `FLOAT.FTH` for the full FLOATING/FLOATING-EXT set). `GFX.FTH` gives back the
   bitmap-graphics words that are no longer in the core. On the **C64/F256**
   versions only `ASSEMBLER.FTH` applies — the others use X16-only words.

2. **Launch the version** (run its `test.bat`) and at the `OK` prompt `INCLUDE`
   each library:
   ```
   S" FPX.FTH" INCLUDED
   S" BASICSTR.FTH" INCLUDED
   S" ASSEMBLER.FTH" INCLUDED
   S" GFX.FTH" INCLUDED
   ```

3. **Reset the search order.** `ASSEMBLER.FTH` ends with `ONLY`, so without this
   the snapshot would boot with a broken vocabulary:
   ```
   ONLY FORTH DEFINITIONS DECIMAL
   ```

4. **Take the snapshot:**
   ```
   S" TK" SAVE-IMAGE
   ```
   This writes `TK.DIC`, `TK.TOK`, `TK.VAR`. The wide builds write extra parts:
   `816WideRam` and `816WideFar` also write per-bank code slices `TK.C00`,
   `TK.C01`, …, and `816WideFar` additionally writes `TK.TKB`. **Keep every part
   together** — the image only reloads with all of them present.

5. **Auto-load at boot.** Put this single line in `AUTORUN.FTH` (device 8):
   ```
   S" TK" LOAD-IMAGE DROP
   ```
   Only the file literally named `AUTORUN.FTH` runs at boot. If you keep several
   images around, name them per build (e.g. `TKPRG` / `TK9` / `TK32`) and copy
   the matching autorun over `AUTORUN.FTH`.

You can bundle **several** libraries into one image — `INCLUDE` them all, finish
with `ONLY FORTH DEFINITIONS DECIMAL`, then a single `SAVE-IMAGE`. The root
[`readme.md`](../readme.md) ("AUTORUN and the toolkit images per build") and
`doc/userguide.md` have the deeper rules.
