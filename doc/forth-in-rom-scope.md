# Scope: run ForthX16 from ROM (v3) — replace demo bank $09

Goal: run the Forth interpreter **in place from a ROM bank** (bank `$09`, the demo
bank, which the FPGA build already skips) so the interpreter code no longer sits
in low RAM. Result: the user dictionary gets ~12 KB more low RAM (roughly 20 KB →
32 KB), and the door opens to a banked-RAM dictionary later — i.e. "run like BASIC,
almost all RAM free for code."

---

## STATUS (2026-07-02): working — boots and runs from ROM

The `X16ROM` build target is implemented and **functionally complete**: Forth
cold-starts in place from ROM bank `$09`, and the **entire test suite passes from
ROM** (the seven `tests-X16` self-tests plus the standard Forth 2012 suite, 0
errors). Integer, floating point, audio, strings, VERA/sprite/tile access, RANDOM,
and binary LOAD/SAVE all work from ROM.

### How to build and test
- **Build:** `makex16rom.bat` → `forthx16rom.bin`, a full 16 KB bank image
  (`buildx16rom.asm` sets `X16ROM=1`; assemble with `--cpu 65c02`). The core is
  ~13.5 KB, so it fits the 16 KB bank with ~2.3 KB to spare after the bridge and
  vectors.
- **Test (patch rom.bin):** back up the emulator ROM, then write the bank image
  into bank 9 (offset `9*16384 = $24000`):
  `dd if=forthx16rom.bin of=rom.bin bs=1 seek=147456 conv=notrunc`
- **Invoke:** type **`TEST`** at the BASIC prompt (the command that used to run the
  demo). The bank starts with the 4-word vector table `TEST` expects; `TEST`
  copies the bank to RAM `$1000` and jumps into a small launcher there, which
  `jsrfar`s back into bank 9 to start Forth **in place**. (A loader PRG can also
  enter directly: `jsr $FF6E / !word coldstart / !byte $09`, where `coldstart` is
  just past the vector table + launcher.)

### What was built (all guarded by the `X16ROM` flag; other builds unaffected)
0. **Launch via `TEST`** — the bank begins with the 4-word vector table the BASIC
   `TEST` command expects (all four entries point at a launcher). `TEST` copies the
   16 KB bank to RAM `$1000` and `jmp ($1000+n*2)`; the launcher (now in RAM,
   bank 0) `jsrfar`s back into bank 9's `coldstart` so Forth runs in place. The RAM
   copy is scratch (the dictionary overwrites it). So replacing demo → typing
   `TEST` boots Forth. Verified end-to-end (full suite passes when launched this
   way).
1. **Memory map / build config** — code placed at `$C000` with `!pseudopc`; the
   dictionary relocates to RAM (`$0801`, reusing the C64 `CART` path); hmbuffers
   in low RAM (currently from `$9000` down — a placeholder, see TODO).
2. **KERNAL bridge** — a bank at `$C000` cannot call `$FFxx` directly (that window
   *is* the bank). A ROM template of 17 small RAM trampolines is copied to RAM at
   cold start; each saves the ROM bank, selects bank 0, `jsr`s the real routine,
   and restores the bank (preserving A/X/Y and carry). The KERNAL symbols
   (`CHROUT`, `CHRIN`, `SETNAM`, …, plus `KLOAD`/`KSAVE`/`PLOT`/`SCREENMODE`/
   `ENTROPY`) are redefined to the trampolines, so no call sites change.
3. **`jsrfar` bridge** — FP (bank 4) and audio (bank `$0A`) reach their banks via
   `brg_jsrfar`, the ROM part of the KERNAL `jsrfar` ported into bank 9 (hands off
   to the KERNAL RAM part `jsrfar3` at `$02C4`).
4. **CPU vectors** — bank 9's `$FFFA-$FFFF` point at the KERNAL's low-RAM banked
   IRQ/NMI trampolines (`irq=$038B`, `nmi=$03B7`); no custom IRQ stub is needed for
   IRQ survival.

### Key bug found and fixed
`fsp` (the float-stack pointer) was an inline `!byte 0,0` **in the code** — fine in
RAM/PRG builds, but read-only in ROM, so it stayed `$0000` and FP wrote its results
over the RAM/ROM bank registers (`$00`/`$01`) → crash. Moved to a RAM hmbuffer.
This was the scope's "inline mutable storage in ROM" hazard (item 5); `fsp` was the
only such case — the standard suite's `DEFER`/`VALUE` tests pass from ROM.

### Completed since (all guarded by `X16ROM`; other builds unaffected)
- **ROM-mode `IRQ` callback.** The KERNAL's `jmp (CINV)` runs with ROM bank 0
  selected, so `CINV` (`$0314`) can't point straight at `irq_handler` (that address
  is KERNAL ROM in bank 0). It now points at `bridge_irq`, a small RAM trampoline
  (17th entry in the bridge template, at `brg_ram + 17*BRIDGE_LEN`) that saves the
  bank, selects bank 9, `jsr`s `irq_handler`, restores the bank, then chains. The
  handler's chain-out sites `rts` back to the trampoline in ROM mode (the callback
  path returns cleanly because `irqpause` restores the 6502 SP first). `X16IRQ.FTH`
  now passes from ROM.
- **RAM map finalized.** hmbuffers grow down from `$9F00` (top byte `$9EFF`, just
  under I/O at `$9F00`) instead of the old `$9000` placeholder. `UNUSED` reports
  ~31 KB free for the dictionary at boot (vs ~18 KB in the PRG build).
- **Boot free-memory report.** `forth_system` now prints "NNNNN BYTES FREE" after
  the banner, mirroring BASIC.
- **rom.bin integration.** `makeromforth.bat` copies the pristine 16-bank ROM
  (`emulator\rom.bin.orig`) to `emulator\rom.bin` and patches bank `$09` (byte
  offset 147456) with `forthx16rom.bin`. Boot that ROM and type `TEST` to launch
  Forth. The FPGA ROM path (`rom_banks.sv` / `make_compact_rom.py`) is intentionally
  left unchanged.

The design notes below are the original plan; the items above record what was
actually implemented.

---

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
