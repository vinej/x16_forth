# ForthX16_816Prg

Forth TX16 for the **Commander X16 in 65816 native mode** (e.g. a MiSTer core
with a 65C816 CPU), as a PRG.

| | |
|---|---|
| Platform | Commander X16 with a 65C816 CPU |
| CPU | 65816 |
| Build flags (`build.asm`) | `PRG=1`, `X16=1`, `NATIVE816=1` |
| Release binary | **ForthX16_816Prg.prg** |
| Source used | `fthtx16.asm` + `x16prims.asm` + `x16.asm` (65816 native primitives) |

## What it is
The 65816 native-mode X16 build. Same feature set as `ForthX16_6502Prg`, but the
inner interpreter and primitives use 65816 native (16-bit) instructions. This is
the **baseline** for the three "wide dictionary" builds
(`ForthX16_816WideRom` / `WideRam` / `WideFar`).

## Build
Run `make.bat` — assembles `build.asm` (`--cpu 65816`) to `ForthX16_816Prg.prg`.

## Test
Run `test.bat` — launches `x16emu ... -run -c816`.

> The **`-c816`** flag is required: without it the emulator runs a 65C02 core,
> hits a 65816 opcode, and drops to the machine-language monitor at boot.
