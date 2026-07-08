# ForthF256_6502Prg

Forth TX16 for the **Foenix F256** as a **PGZ** executable.

| | |
|---|---|
| Platform | Foenix F256 (6502-based; ASCII console, its own file I/O) |
| CPU | 65C02 |
| Build flags (`build.asm`) | `F256=1` |
| Release binary | **ForthF256_6502Prg.pgz** |
| Source used | `fthtx16.asm` (shared core) + `fileio_f256.asm` + `console_F256.asm` |

## What it is
The F256 port. Same Forth 2012 core; console and file I/O are F256-specific.
Uses ASCII (no C64 character-set hacks). Platform word is `F256`.

## Build
Run `make.bat` — assembles `build.asm` to `ForthF256_6502Prg.pgz` in this folder.

## Test
There is **no F256 emulator** bundled with this repo, so `test.bat` only builds
and prints instructions. To run it:
- install the **Foenix IDE** (https://github.com/Trinity-11/FoenixIDE) and point
  its "SD card" folder at this directory so the `.pgz` is visible, **or**
- copy `ForthF256_6502Prg.pgz` onto a real F256 SD card.
