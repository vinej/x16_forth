# ForthX16_816WideFar

65816 X16 PRG with **WIDEDICT + far headers** (`WD_ROMBANKS=0`, `WD_FARHDR=1`):
word **headers *and* bodies** live in the 8 KB RAM banks, so near RAM holds
essentially only data. This is the **latest / largest-capacity** wide build.

| | |
|---|---|
| Platform | stock Commander X16 with a 65816 (e.g. MiSTer) |
| CPU | 65816 |
| Build flags (`build.asm`) | `PRG=1`, `X16=1`, `NATIVE816=1`, `WIDEDICT=1`, `WD_ROMBANKS=0`, `WD_FARHDR=1` |
| Release binary | **ForthX16_816WideFar.prg** |
| Source used | `fthtx16.asm` + `x16prims.asm` + `x16.asm` |

## What it is
Builds on `ForthX16_816WideRam` by also moving the word **header record** into
the RAM banks. Near RAM then costs only a few bytes per word (its token-table
slot), so word count rises toward the token-table ceiling and near RAM frees up
for `VARIABLE`/`CREATE`/string data. Passes the full ANS suite (Total 0).

## Build
Run `make.bat` — assembles to `ForthX16_816WideFar.prg`.

## Test
Run `test.bat` — launches `x16emu ... -c816`. Define hundreds of colon words and
`FREE` shows the near pool barely moving while the code-bank pool shrinks.

> Images from this build carry an extra `<name>.TKB` file (the per-token bank
> table) alongside the usual `.DIC/.TOK/.VAR` — needed to restore far dispatch.
