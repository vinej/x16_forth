# ForthC64_6502Prg

Forth TX16 for the **Commodore 64**, built as a loadable **PRG**.

| | |
|---|---|
| Platform | Commodore 64 (any C64-KERNAL-compatible machine) |
| CPU | 6502 |
| Build flags (`build.asm`) | `PRG=1`, `C64=1` |
| Release binary | **ForthC64_6502Prg.prg** (CBM PRG, loads at `$0801`) |
| Source used | `fthtx16.asm` (shared core) + `fileio_c64.asm` |

## What it is
The generic C64 build: the full Forth 2012 core, but **none** of the X16-only
extensions (no VERA/sprite/audio words, no floating point).

## Build
Run `make.bat` — assembles `build.asm` with ACME and writes
`ForthC64_6502Prg.prg` into this folder.

## Test
Run `test.bat` — builds, then autostarts the PRG in VICE (`x64sc -autostart`).
On the C64 you would `LOAD"FORTHC64_6502PRG.PRG",8` then `RUN`.

Requires ACME in `.\asm\` and VICE in `.\vice\` (see `version/readme.md`).
