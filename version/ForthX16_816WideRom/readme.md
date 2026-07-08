# ForthX16_816WideRom

65816 X16 PRG with the **WIDEDICT** wide dictionary storing compiled code in
**16 KB ROM banks** (banks 33+) through the `$C000` window (`WD_ROMBANKS=1`).

| | |
|---|---|
| Platform | X16 with a 65816 **and writable ROM banks** — the MiSTer core |
| CPU | 65816 |
| Build flags (`build.asm`) | `PRG=1`, `X16=1`, `NATIVE816=1`, `WIDEDICT=1` (`WD_ROMBANKS` defaults to 1) |
| Release binary | **ForthX16_816WideRom.prg** |
| Source used | `fthtx16.asm` + `x16prims.asm` + `x16.asm` |

## What it is
The wide dictionary variant that puts compiled colon-word code into 16 KB ROM
banks (the MiSTer target). Frees low RAM for a much larger dictionary.

## Build
Run `make.bat` — assembles to `ForthX16_816WideRom.prg`.

## Test
Run `test.bat` — launches `x16emu ... -c816`.

> **Caveat:** the stock X16 emulator's ROM banks are **not writable**, so on the
> emulator the wide dictionary silently falls back to normal in-RAM bodies — the
> build still boots and runs, but you are not exercising the ROM-bank feature.
> Test the real ROM-bank wide dictionary on the **MiSTer** core. For an
> emulator-testable wide build, use **ForthX16_816WideRam** or
> **ForthX16_816WideFar** (RAM-bank storage).
