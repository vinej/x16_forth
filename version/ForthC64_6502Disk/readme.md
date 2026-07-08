# ForthC64_6502Disk

Forth TX16 for the **Commodore 64** packaged as a **1541 disk image (`.d64`)** —
the C64 PRG plus a set of source files on one disk, ready to mount in VICE or
write to a real 1541.

| | |
|---|---|
| Platform | Commodore 64 |
| CPU | 6502 |
| Build flags (`build.asm`) | `PRG=1`, `C64=1` (same interpreter as `ForthC64_6502Prg`) |
| Release binary | **ForthC64_6502Disk.d64** |
| Source used | `fthtx16.asm` + `fileio_c64.asm`; packaged with VICE `c1541` |

## What it is
The same interpreter as `ForthC64_6502Prg`, but delivered on a disk that also
carries the material you need to exercise it on the C64:

- the interpreter PRG (on-disk name `FORTH`),
- the Forth 2012 **test suite** (`RUNTESTS.FTH`, `PRELIM.FTH`, `TESTER.FR`,
  `CORE.FR`, `COREPLUS`, `UTIL`, `ERRORREP`, `COREEXT`, `DOUBLE`, `FACILITY`,
  `SEARCH`),
- `ASSEMBLER.FTH` (inline assembler),
- `DYNAMIC.FS` (the Memory-Allocation library — `INCLUDE` + initialize it to
  enable `ALLOCATE`/`FREE`/`RESIZE`, e.g. to run the memory tests),
- the `BENCH`, `ERASTO`, and `RC4TEST` examples.

## Build
Run `make.bat` — builds the PRG, formats a `.d64`, and writes the interpreter
and all the support files onto it (the intermediate `.prg` is removed; it lives
inside the disk). Requires VICE (`c1541`) in `.\vice\`.

## Test
Run `test.bat` — builds the disk and launches VICE (`x64sc -autostart`). On the
C64: `LOAD"*",8` then `RUN`; then e.g. `S" RUNTESTS.FTH" INCLUDED` to run the
suite (slow on a C64), or `S" BENCH.FTH" INCLUDED`.

> This is the same interpreter as `ForthC64_6502Prg` — use that folder for just
> the bare `.prg`, or this one for the disk-with-everything.
