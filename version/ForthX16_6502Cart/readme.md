# ForthX16_6502Cart

Forth TX16 as a **Commander X16 auto-booting cartridge**. A small bank-32 loader
stub with the `CX16` signature copies the Forth image down to low RAM, switches
back to the KERNAL, and starts the interpreter — so Forth runs from RAM exactly
like the PRG, but boots straight from the cartridge with no loading.

| | |
|---|---|
| Platform | Commander X16 / MiSTer core |
| CPU | 6502 |
| `build.asm` | the cartridge loader/wrapper (formerly `x16cart.asm`) |
| Release binary | **ForthX16_6502Cart.bin** (16 KB bank image) |
| Source used | wraps the **ForthX16_6502Prg** build (`fthtx16.asm` + `x16prims.asm` + `x16.asm`) |

## What it is
The KERNAL detects a cartridge by the PETSCII signature `CX16` at `$C000` in ROM
bank 32 and calls `$C004`. Since bank 32 shares the `$C000-$FFFF` KERNAL window,
this stub copies the embedded PRG to `$0801`, selects ROM bank 0, and jumps to
Forth's cold start.

## Build
Run `make.bat` — two steps: it first builds the X16 6502 PRG
(`version/ForthX16_6502Prg/build.asm`) into a temporary file, then assembles the
wrapper (`build.asm`) which embeds it, producing `ForthX16_6502Cart.bin`.

## Test
Run `test.bat` — launches `x16emu -cartbin ...\ForthX16_6502Cart.bin`. It
**auto-boots** straight into Forth (no loader needed).

> Contrast with **ForthX16_6502Bank32**, which runs *in place* in bank 32 and
> needs a manual `loader32` launch.
