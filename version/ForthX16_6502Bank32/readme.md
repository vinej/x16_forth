# ForthX16_6502Bank32

Forth TX16 in **Commander X16 ROM bank 32** (the MiSTer cartridge bank), running
in place. **No** `CX16` autoboot signature — the machine boots to BASIC and you
launch Forth manually.

| | |
|---|---|
| Platform | Commander X16 / MiSTer core |
| CPU | 65C02 |
| Build flags (`build.asm`) | `FORTH_BANK=32`, `X16CART=1`, `X16ROM=1`, `X16=1` |
| Release binary | **ForthX16_6502Bank32.bin** (16 KB bank image) |
| Source used | `fthtx16.asm` + `x16prims.asm` + `x16.asm` |

## What it is
The bank-9 run-from-ROM build relocated to ROM bank 32 (where the MiSTer maps a
cartridge). It is byte-identical to the bank-9 image except the bank number.
Because it enters from a running BASIC (like bank 9), no CHRGET/FP fix is needed.

## Build
Run `make.bat` — assembles `build.asm` (`--cpu 65c02`) to
`ForthX16_6502Bank32.rom`.

## Test
Run `test.bat` — launches `x16emu -cartbin ...\ForthX16_6502Bank32.bin`. At the
BASIC `READY.` prompt type:

```
LOAD"LOADER32",8 : RUN        (or:  SYS 2064)
```

`loader32.prg` lives in the repo root and is reachable over HostFS (device 8).

> Contrast with **ForthX16_6502Cart**, an auto-booting cartridge that copies the
> PRG into RAM instead of running in place.
