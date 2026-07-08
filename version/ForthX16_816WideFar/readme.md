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

## Using RAM banks for your own data
The dictionary claims code banks **top-down** (from the highest RAM bank toward
bank 2), so the lower banks are free for your own data — read/write them with
`B@ ( bank off -- byte )` / `B! ( byte bank off -- )` (`off` = 0..8191 into the
`$A000` window; both save/restore the window register, so they are safe).
`DATABANK ( -- bank )` returns the highest bank the dictionary is **not** yet
using (0 if none) — a safe point to allocate downward from instead of
hard-coding bank numbers. Caveats: banks 0–1 are the KERNAL's; the dictionary
keeps growing downward, so grab your data banks **early** and don't let it grow
into them; and `EDIT` (x16edit) uses banks 10+.

**Bulk & disk I/O for banks.** Beyond byte-at-a-time `B@`/`B!` (all four
save/restore the window register, so they are safe alongside the dictionary):
- `BANK>MEM ( bank boff addr u -- )` — fast copy `u` bytes from `bank:boff` to
  low-RAM `addr`, auto-advancing across bank boundaries. Pull the active game
  level into low RAM with this.
- `MEM>BANK ( addr bank boff u -- )` — the reverse (stage/compute into a bank).
- `BANKLOAD ( c-addr u dev bank -- )` — load a PRG file straight into `bank`
  (the KERNAL spills a file bigger than 8K into the following banks). Load all
  your levels into banks once at start-up.
- `BANKSAVE ( c-addr u dev bank off len -- )` — save `len` bytes of `bank:off`
  to a PRG file (one bank per call — `off+len` must be ≤ 8192).

Sketch — levels in banks, activated on demand:
```
S" LEVEL1" 8 20 BANKLOAD          \ file -> bank 20 (spills to 21,22... if >8K)
S" LEVEL2" 8 23 BANKLOAD          \ file -> bank 23
20 0 LEVELBUF 8192 BANK>MEM       \ when needed: bank 20 -> low-RAM LEVELBUF
```
