# ForthC64_6502Cart

Forth TX16 for the **Commodore 64** as an 8K **cartridge**.

| | |
|---|---|
| Platform | Commodore 64 |
| CPU | 6502 |
| Build flags (`build.asm`) | `CART=1`, `C64=1` |
| Release binary | **ForthC64_6502Cart.crt** (VICE cartridge) |
| Intermediate | `ForthC64_6502Cart.rom` (raw 8K image) |
| Source used | `fthtx16.asm` (shared core) + `fileio_c64.asm` |

## What it is
The C64 build packaged as an auto-starting cartridge image. Fits in 8K — one of
the original goals of the project.

## Build
Run `make.bat` — two steps: ACME assembles `build.asm` to a raw `.rom`, then
VICE `cartconv` converts it to a `.crt`. Requires VICE in `.\vice\`.

## Test
Run `test.bat` — builds, then launches `x64sc -cartcrt` with the cartridge.

Note: on the cartridge build, `BYE` reboots the interpreter (see the C64 notes in
the root `readme.md`).
