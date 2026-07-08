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
| [ForthX16_816WideRom](ForthX16_816WideRom/readme.md) | X16 · 65816, wide dict in ROM banks | `ForthX16_816WideRom.prg` | `x16emu -c816` (real MiSTer) |
| [ForthX16_816WideRam](ForthX16_816WideRam/readme.md) | X16 · 65816, wide dict in RAM banks | `ForthX16_816WideRam.prg` | `x16emu -c816` |
| [ForthX16_816WideFar](ForthX16_816WideFar/readme.md) | X16 · 65816, wide dict + far headers | `ForthX16_816WideFar.prg` | `x16emu -c816` |

**X16 6502 vs 65816.** The `6502` X16 builds run on the stock CPU; the `816`
builds need a 65C816 (a MiSTer core, or `x16emu -c816`). The three **Wide** builds
add the 65816 `WIDEDICT` large dictionary — `WideRam`/`WideFar` store code (and,
for `WideFar`, headers) in 8 KB RAM banks and are emulator-testable; `WideRom`
stores code in 16 KB ROM banks and is meant for real MiSTer hardware.

**Bank32 vs Cart.** `ForthX16_6502Bank32` runs the interpreter *in place* in ROM
bank 32 and is launched from BASIC with `loader32`; `ForthX16_6502Cart` is an
*auto-booting* cartridge that copies the PRG into RAM and starts it with no
loader.

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
   `FPX.FTH`, `BASICSTR.FTH`, `PCMAUDIO.FTH`, `ASSEMBLER.FTH` (add `FLOAT.FTH`
   for the full FLOATING/FLOATING-EXT set). On the **C64/F256** versions only
   `ASSEMBLER.FTH` applies — the others use X16-only words.

2. **Launch the version** (run its `test.bat`) and at the `OK` prompt `INCLUDE`
   each library:
   ```
   S" FPX.FTH" INCLUDED
   S" BASICSTR.FTH" INCLUDED
   S" PCMAUDIO.FTH" INCLUDED
   S" ASSEMBLER.FTH" INCLUDED
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
