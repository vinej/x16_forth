# ForthX16_6502Prg

Forth TX16 for the **Commander X16** as a loadable **PRG** (stock 6502).

| | |
|---|---|
| Platform | Commander X16 |
| CPU | 6502 |
| Build flags (`build.asm`) | `PRG=1`, `X16=1` |
| Release binary | **ForthX16_6502Prg.prg** |
| Source used | `fthtx16.asm` + `x16prims.asm` + `x16.asm` + `fileio_c64.asm` |

## What it is
The standard Commander X16 build. Includes the full X16 extension word set:
VERA video & bitmap graphics, hardware sprites, PSG and YM2151 (FM) audio,
floating point (via the ROM FP package), and binary LOAD/SAVE. Platform word is
`X16`.

## Build
Run `make.bat` — assembles `build.asm` to `ForthX16_6502Prg.prg` in this folder.

## Test
Run `test.bat` — builds, then launches the X16 emulator:
`x16emu -rom .\emulator\rom.bin -prg ...\ForthX16_6502Prg.prg -run`.

Requires ACME in `.\asm\` and the X16 emulator in `.\emulator\` (with `rom.bin`).
