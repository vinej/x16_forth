# ForthX16_816Bank9

Forth TX16 running **in place from Commander X16 ROM bank 9, in 65816 native
mode** — the interpreter lives in ROM (so all of low RAM is free) *and* uses the
65816 for a faster inner loop, with the **bank-I/O words built in** so every
high-RAM bank is usable for data.

| | |
|---|---|
| Platform | Commander X16 with a 65C816 (ROM-resident) |
| CPU | 65816 |
| Build flags (`build.asm`) | `X16ROM=1`, `X16=1`, `NATIVE816=1` (GFXTOOLKIT defaults on) |
| Release binary | **ForthX16_816Bank9.bin** (256 KB ROM: pristine ROM + Forth in bank 9) |
| Source used | `fthtx16.asm` + `x16prims.asm` + `x16.asm` (RAM KERNAL bridges) |

## What it is
The 65816-native counterpart of `ForthX16_6502Bank9`. Boots to ~30.9 KB free low
RAM. Because the dictionary lives in low RAM (not the banks), **every high-RAM
bank is free for your own data** — use the built-in `BANKLOAD` / `BANKSAVE` /
`BANK>MEM` / `MEM>BANK` (and `B@`/`B!`) to stream game levels and other data in
and out. Graphics are **not** baked in (that headroom is what makes the bank
words fit) — `INCLUDE GFX.FTH` for `GINIT`/`PSET`/`LINE`/`RECT`/`OVAL`/… when you
want them.

## Build
Run `make.bat`: assembles the 16 KB bank image (`--cpu 65816`) and splices it
into a pristine **256 KB** ROM at bank 9 → `ForthX16_816Bank9.bin`. Patch base:
`r49.bin` in this folder (git-ignored), else `emulator\rom.bin.orig`/`rom.bin`.

## Test
Run `test.bat` — launches `x16emu -c816 -rom ...\ForthX16_816Bank9.bin`. At the
BASIC `READY.` prompt type **`TEST`** to start Forth. (`loader.prg` / `SYS 2064`
also works.)

> Emulator-verified: boots native from ROM, the bank words round-trip (incl.
> disk save/load through the ROM's KERNAL bridges), and `GFX.FTH` loads and
> draws.
