# ForthX16_816WideRam

65816 X16 PRG with the **WIDEDICT** wide dictionary storing compiled code in
**8 KB RAM banks** (banks 2+) through the `$A000` window (`WD_ROMBANKS=0`).
Colon-word **bodies** live in the banks; headers stay in near RAM.

| | |
|---|---|
| Platform | stock Commander X16 with a 65816 (e.g. MiSTer) |
| CPU | 65816 |
| Build flags (`build.asm`) | `PRG=1`, `X16=1`, `NATIVE816=1`, `WIDEDICT=1`, `WD_ROMBANKS=0` |
| Release binary | **ForthX16_816WideRam.prg** |
| Source used | `fthtx16.asm` + `x16prims.asm` + `x16.asm` |

## What it is
The RAM-bank wide dictionary: compiled colon-word bodies go into high RAM banks
via the `$A000` window, so low RAM fills much more slowly. Fully
emulator-testable and passes the ANS test suite.

## Build
Run `make.bat` — assembles to `ForthX16_816WideRam.prg`.

## Test
Run `test.bat` — launches `x16emu ... -c816`. Define many colon words and watch
`FREE`: the near pool fills far more slowly than the plain `ForthX16_816Prg`
build because the bodies live in the RAM banks.

> For the largest capacity (headers in the banks too), use
> **ForthX16_816WideFar**.
