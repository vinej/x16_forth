# ForthX16_816Bank32

Forth TX16 in **Commander X16 ROM bank 32, 65816 native mode** (the MiSTer
cartridge bank), running in place. **No** `CX16` autoboot signature — the machine
boots to BASIC and you launch Forth manually.

| | |
|---|---|
| Platform | Commander X16 / MiSTer core with a 65C816 |
| CPU | 65816 |
| Build flags (`build.asm`) | `FORTH_BANK=32`, `X16CART=1`, `X16ROM=1`, `X16=1`, `NATIVE816=1` |
| Release binary | **ForthX16_816Bank32.bin** (16 KB bank image) |
| Source used | `fthtx16.asm` + `x16prims.asm` + `x16.asm` |

## What it is
The 65816-native counterpart of `ForthX16_6502Bank32` (and the bank-32 sibling of
`ForthX16_816Bank9`): 65816 Forth in ROM bank 32, ~30.9 KB free low RAM, every
high-RAM bank free for data. **Bank-I/O words built in** (`BANKLOAD`/`BANKSAVE`/
`BANK>MEM`/`MEM>BANK`); **graphics via `INCLUDE GFX.FTH`** (not baked in). Byte
layout is identical to `ForthX16_816Bank9` except the bank number.

## Build
Run `make.bat` — assembles `build.asm` (`--cpu 65816`) to
`ForthX16_816Bank32.bin`.

## Test
Run `test.bat` — launches `x16emu -c816 -cartbin ...\ForthX16_816Bank32.bin`. At
the BASIC `READY.` prompt type:

```
LOAD"LOADER32",8 : RUN        (or:  SYS 2064)
```

`loader32.prg` lives in the repo root and is reachable over HostFS.
