# ForthX16_6502Bank9

Forth TX16 running **in place from Commander X16 ROM bank 9** (the old DEMO
bank), so the ~13.5 KB interpreter lives in ROM and all of low RAM is free for
the user dictionary.

| | |
|---|---|
| Platform | Commander X16 (ROM-resident) |
| CPU | 65C02 |
| Build flags (`build.asm`) | `X16ROM=1`, `X16=1` |
| Release binary | **ForthX16_6502Bank9.bin** (a full **256 KB** ROM: pristine ROM + Forth in bank 9) |
| Source used | `fthtx16.asm` + `x16prims.asm` + `x16.asm` (with RAM KERNAL bridge trampolines) |

## What it is
The run-from-ROM build (v3). A bank at `$C000` cannot call the KERNAL directly,
so it installs RAM bridge trampolines at cold start; FP/audio reach their banks
via `jsrfar`. Reports ~31 KB free at boot. See `doc/forth-in-rom-scope.md`.

## Build
Run `make.bat`. It does two things:
1. assembles `build.asm` (`--cpu 65c02`) into the 16 KB bank-9 image, then
2. splices that image into a pristine **256 KB** ROM at bank 9 (byte offset
   147456), producing the ready-to-run `ForthX16_6502Bank9.bin`.

The patch base is, in order of preference: **`r49.bin` in this folder** (drop a
pristine R49 ROM here — it is git-ignored, so it won't be uploaded), else
`emulator\rom.bin.orig`, else `emulator\rom.bin`.

## Test
Run `test.bat` — runs `make.bat`, then launches `x16emu -rom
...\ForthX16_6502Bank9.bin`. At the BASIC `READY.` prompt type **`TEST`** to
start Forth in place. (`loader.prg` / `SYS 2064` also works.)
