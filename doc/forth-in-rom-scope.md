# Scope: run ForthX16 from ROM (v3) — replace demo bank $09

Goal: run the Forth interpreter **in place from a ROM bank** (bank `$09`, the demo
bank, which the FPGA build already skips) so the interpreter code no longer sits
in low RAM. Result: the user dictionary gets ~12 KB more low RAM (roughly 20 KB →
32 KB), and the door opens to a banked-RAM dictionary later — i.e. "run like BASIC,
almost all RAM free for code."

## Verdict: feasible, medium effort

A run-from-ROM Forth **already exists** in this codebase: the **C64 cartridge build**
(`makecart.bat`, `CART=1`) runs the interpreter from cartridge ROM at `$8000` with
the dictionary in RAM at `$0801`. The X16 bank-9 port is essentially "the C64 CART
build, relocated to `$C000`, plus the X16 bank/KERNAL plumbing."

### What already works in our favour

- **All mutable interpreter state is in zero page** (`_here _base _latest _state
  _source _hightoken`, the wordlists, stack pointers, etc. — [fthtx16.asm:218-257](../fthtx16.asm#L218)). Moving code to ROM strands nothing.
- **The token table is rebuilt into RAM at cold start** by `generate_token_table`
  ([fthtx16.asm:638](../fthtx16.asm#L638)); `TOKENS` is a RAM buffer. It scans the
  (ROM) core dictionary and fills the (RAM) table — already ROM-friendly.
- **The dictionary already relocates to RAM for carts**: `!if C64 and CART { _here
  = $0801 }` ([fthtx16.asm:632](../fthtx16.asm#L632)). Core (ROM) + user (RAM)
  split dictionary is the norm; link fields crossing ROM→RAM are fine.
- **Only ~11 unique KERNAL routines** are called (CHROUT CHRIN CLRCHN OPEN CLOSE
  CHKIN CHKOUT READST GETIN SETLFS SETNAM), ~38 sites. Everything else is Forth.
- **x16edit is a working template** for a ROM-resident bank that calls the KERNAL:
  it copies a small **bridge** to RAM (`x16-edit/bridge.inc`) that does *save ROM
  bank → select bank 0 → jsr KERNAL → restore bank*, and patches the target per call.

## Work items (new for the X16 bank-9 target)

1. **Build config / relocation.** New target (e.g. `X16ROM=1`) that assembles the
   core with `CODESTART=$C000` and `!pseudopc` into a 16 KB bank image (core is
   ~12 KB, fits). Reuse the `CART` dictionary path so `_here=$0801`. Emit
   `forthbank09.bin`; wire it into the rom source `Makefile` in place of
   `demo.bin` at bank `$09`, and into the FPGA `make_compact_rom.py` (which
   currently *skips* `$09`).

2. **KERNAL RAM bridge.** Bank 9 cannot call `$FFxx` directly (that window is its
   own bank, not the KERNAL). Add ~11 RAM trampolines (copied from ROM at cold
   start), each: save `$01`, set ROM bank 0, `jsr <kernal>`, restore `$01`,
   preserving A/X/Y and flags/carry across the restore (OPEN/READST/CHRIN return
   values & carry matter). Then **redefine the KERNAL symbols** (`CHROUT=…` etc.)
   to the trampoline addresses so existing `jsr CHROUT` sites need no edits.
   (ACME builds `--cpu 6502`, so use `LDA #0/STA`, not `STZ`, in the bridge.)

3. **High-memory buffer placement.** `hmbuffer`s currently start at `$A000` and
   grow down ([fthtx16.asm:284](../fthtx16.asm#L284)) — on the X16 that is the
   *banked* RAM window and butts against I/O at `$9F00`. For the ROM build put the
   stacks/buffers/`TOKENS` in a clean fixed low-RAM region (and/or a chosen banked-RAM
   bank). Needs a deliberate memory map; the PRG's current layout must not be
   copied blindly.

4. **Self-modifying code → RAM/indirect.** ROM can't be patched. Known site:
   [x16.asm:1257](../x16.asm#L1257) `jmp $ffff ; operand patched above` (USR /
   arbitrary-address call) — change to `jmp (vec)` through a zp/RAM vector. Audit
   for any others (search patched operands, `sta` into code).

5. **Core VALUE/DEFER inline storage.** `dovalue`/`dodefer` keep their datum inside
   the word body. Any *core* word that is a VALUE or DEFER (e.g. I/O deferred
   vectors) would have its mutable cell in ROM → must relocate that cell to RAM.
   Audit the core for dovalue/dodefer usage.

6. **Bank CPU vectors + IRQ.** While bank 9 is selected, the CPU fetches
   `$FFFA-$FFFF` from bank 9, so the bank needs valid NMI/RESET/IRQ vectors →
   typically a tiny RAM IRQ stub that switches to bank 0 and chains the KERNAL IRQ
   (`$0314`). Mirror x16edit's IRQ handling (`x16-edit/irq.inc`).

7. **Invocation.** Decide how Forth is launched: a BASIC command (like the demo is
   reachable via `basic/x16additions.s`), a boot/menu entry, or a KERNAL hook.
   Simplest first cut: a BASIC keyword or `SYS`-style far-call that `jsrfar`s into
   bank 9's cold-start entry.

8. **Cold start.** Entry runs with bank 9 selected: install the RAM bridge + IRQ
   stub, set zp, `generate_token_table`, init stacks, enter QUIT. Keep AUTORUN.FTH.

## Risks / open questions

- Exact X16 rule for calling KERNAL / handling IRQ from a non-0 ROM bank — resolve
  definitively against x16edit (proven) before committing.
- hmbuffer/`TOKENS` reserved region currently overlaps `$9F00` I/O in the PRG (only
  the used low part is touched); the ROM build should fix this properly.
- Register/flag preservation in the KERNAL bridge (carry from OPEN, A from CHRIN/READST).
- `>512`-cell not relevant here; but confirm no core word assumes code is writable.

## Effort & phasing (suggested)

- **Phase 0 (done):** this scope.
- **Phase 1:** memory map + build config; get a bank-9 image that boots to `OK` with
  the KERNAL bridge and prints/reads the console. (Biggest single step.)
- **Phase 2:** file I/O through the bridge (INCLUDE/LOAD/SAVE); run the full test suite.
- **Phase 3:** invocation + rom.bin/FPGA integration; measure freed RAM.
- **Phase 4 (optional, later):** banked-RAM dictionary for the "almost all memory" win.

## Recommendation

Do it as **v3**, phased. Phase 1 is the make-or-break (memory map + KERNAL bridge +
boot to OK); once that's green the rest is mechanical. Keep the existing PRG and C64
cart builds untouched — add `X16ROM` as a parallel target so nothing regresses.
