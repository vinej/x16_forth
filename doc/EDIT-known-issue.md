# `EDIT` — return-to-Forth console glitch (open issue)

Status: **open / unresolved** as of 2026-07-01.

`EDIT ( c-addr u -- )` launches the standalone X16 editor (x16edit, ROM bank
`$0D`) via `jsrfar $C006`, exactly like BASIC's `EDIT`. Creating / editing /
saving files works fine. The problem is the hand-off **back to Forth**.

## Symptoms (after quitting the editor, back at the Forth `OK` prompt)

1. **First RETURN is swallowed.** On the first input line after the editor,
   pressing ENTER inserts a space / advances the cursor instead of ending the
   line. It takes many presses (or pressing cursor-DOWN once, then ENTER)
   before a RETURN registers. After the first line finally goes through,
   subsequent lines behave normally.
2. **Immediate programmatic `INCLUDED` fails.** A word that does
   `... EDIT INCLUDED` (e.g. `: ED 2DUP EDIT INCLUDED ;`) runs `INCLUDED` with
   the correct filename (verified: `2DUP TYPE` prints `JYV.FTH`) but nothing
   compiles — no error, the word just isn't defined afterward.

Both are the **first KERNAL console operation after the editor**. An earlier
stray-character bug (`CHRIN` reading e.g. a spurious `"S` past the typed text)
was fixed and has NOT recurred.

## Key facts established

- **BASIC's own `EDIT` returns cleanly** from the identical editor (first ENTER
  works, files load) — so x16edit itself restores the console correctly; the
  problem is specific to how *Forth* re-enters the KERNAL afterward.
- x16edit's own exit path (`x16-rom-r49/x16-edit/main.asm` `main_loop`
  shutdown) already: clears the screen (`CHROUT $93`), `irq_restore`,
  `scancode_restore`, and `ram_restore` (restores zp `$22-$35` and golden RAM
  `$0400-$07FF` to entry values). It leaves the **RAM-bank register set to its
  `mem_start` = 10**, not 0.
- Emulator ROM is **R49** and its `kernal.sym` addresses match the r49 source
  tree, so all variable pokes below hit the right locations.
- `INCLUDED` from inside a colon word works fine with **no** editor involved
  (`: LD S" JYV.FTH" INCLUDED ;  LD  → JYV = 24`). A manually-typed
  `S" f" INCLUDED` *without* editing also works. So `INCLUDED` itself is fine;
  only the post-editor state breaks it.
- Forth (X16 build) installs **no custom IRQ** (plain `SYS 2061` prolog), so the
  IRQ vector is the KERNAL default before/after — not the cause.

## Fixes attempted in `EDIT` cleanup — none resolved it

(addresses from `emulator/kernal.sym`, all verified)

- Screen clear `CHROUT $93`.
- `CLRCHN` ($FFCC) — restore default keyboard-in / screen-out channels.
- `CINT`/`SCINIT` ($FF81, confirmed = `cint`) — full screen-editor re-init.
- Line-link table reset `ldtb1` = `$FF` × 8 at `$036A` (fixed the stray-char
  bug, but forcing it broke *wrapped* input lines, so it was removed).
- Keyboard buffer flush `ndx` = 0 at `$A80A` (buffer `keyd` = `$A800`, 10 bytes).
- Modifier / dead-key clears: `shflag` `$A80C`, `dk_scan` `$A882`,
  `dk_shift` `$A881`.
- Quote / insert / reverse mode clears: `qtsw` `$0381`, `insrt` `$0385`,
  `rvs` `$0377`.
- `RAM bank ← 0` (`STA $00`) — needed before any KERNAL var poke / KERNAL call,
  since the editor leaves the bank at 10 (a busy-loop settle that called
  `RDTIM`/`GETIN` with bank 10 selected *crashed* to the boot screen — those
  KERNAL routines need bank 0).
- ~0.8–1.2 s settle delay (pure busy loop + keyboard drain).

Current `EDIT` cleanup (in `x16.asm`) = bank 0 → `CINT` → `CLRCHN` → clear
`ndx`/`shflag`/`dk_shift`/`dk_scan`. It does not cure the symptoms but launches
and saves reliably.

Note: ACME builds with `--cpu 6502`, so `STZ`/`PHY`/`PLY` become silent no-ops —
use `LDA #0`/`STA` etc. in any new code here.

## Working workaround (recommended dev loop)

Treat `EDIT` as an editor only; load with a **clean reload**:

1. `S" PROG.FTH" EDIT`  → write code, save, quit.
2. Reset Forth (relaunch the emulator, or cold-start) — a fresh session's
   keyboard and file I/O are perfect.
3. `S" PROG.FTH" INCLUDED`  → loads flawlessly.

## Next step for a real fix (not yet done)

Byte-level comparison of KERNAL state **after the editor** in the working case
(BASIC) vs the broken case (Forth): dump RAM/zero-page in both and diff to find
the differing location. Emulator supports `-dump {C|R|B|V}` (default `RB`);
needs a trigger mechanism. Likely suspects to inspect: the KERNAL "current
device"/`basin`/`basout` default channel state, `crsw`/`pntr`/`tblx` cursor
tracking vs the physical cursor, and whether Forth's `ACCEPT` (raw `CHRIN`
loop, `fthtx16.asm` ~line 2598) needs the same pre-input setup BASIC's main
loop does. Consider comparing to what BASIC does right before `INLIN`.
