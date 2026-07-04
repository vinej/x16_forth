# X16 BASIC commands as candidate Forth words

This is the list of Commander X16 BASIC statements and functions that touch the
**hardware or the system** and are therefore candidates for Forth words. Pure
BASIC-*language* commands (control flow, variables, editor, math/string
functions, etc.) have been excluded - see the note at the end.

Source: X16 ROM r49 keyword table (`basic/tokens.s`), `basic/x16additions.s`,
`basic/sound.s`, `bannex/*`.

Legend: **[x]** = already implemented in the Forth X16 build · **[ ]** = candidate.
Argument order shown is the BASIC order; Forth words follow the same left-to-right
order on the stack. Some syntax (esp. sprites/tiles) is approximate and will be
confirmed against the ROM when implemented.

> Tick the boxes for the ones you want built next.

---

## Video / VERA
- [x] `VPOKE bank, addr, value` — write a byte to VRAM
- [x] `VPEEK(bank, addr)` — read a byte from VRAM
- [x] `SCREEN mode` — set screen/video mode
- [x] `COLOR fg [, bg]` — set text colors (0-15)
- [x] `CLS` — clear the text screen
- [x] `LOCATE row, col` — move the text cursor
- (Forth extras already present: `VADDR  V!  V@  V!W  BORDER`)

## Graphics (bitmap drawing — KERNAL GRAPH API)
- [x] `GINIT` — enter 320x240x256 graphics mode (Forth-specific; call first)
- [x] `GCLS` — clear the graphics screen
- [x] `PSET x y color` — set a pixel
- [x] `LINE x1 y1 x2 y2 color` — draw a line
- [x] `FRAME x1 y1 x2 y2 color` — rectangle outline (two corner points)
- [x] `RECT x1 y1 x2 y2 color` — filled rectangle (two corner points)
- [x] `OVAL x1 y1 x2 y2 color` — filled ellipse (bounding box corners)
- [x] `RING x1 y1 x2 y2 color` — ellipse outline (bounding box corners)
- [x] `GTEXT ( x y color c-addr u -- )` — draw text into the bitmap (= BASIC CHAR;
      named GTEXT because CHAR is a Forth core word)

## Sprites
- [x] `SPRITE num zdepth` — set Z-depth (0=off 1-3) and enable the sprite layer
- [x] `SPRITE-MOV num x y` — set sprite position (= BASIC MOVSPR)
- [x] `SPRITE-MEM num bank addr` — set sprite image address, 4bpp/17-bit VRAM (= BASIC SPRMEM)
- (Also available as Forth-style words: `SPRITE-IMAGE SPRITE-POS SPRITE-SIZE
  SPRITE-Z SPRITES-ON SPRITES-OFF`. The optional BASIC `SPRITE` args
  paloffset/flips/size map to `SPRITE-SIZE` etc.)

## Tiles / tilemap (layer 1 text screen)
- [x] `TILE ( x y code attr -- )` — write a tile cell (code + colour attribute)
- [x] `TDATA ( x y -- code )` — read a tile cell's code
- [x] `TATTR ( x y -- attr )` — read a tile cell's colour attribute
  (cell address derived from VERA_L1_MAPBASE / VERA_L1_CONFIG, so mode-adaptive)

## Audio — PSG (VERA)  (voice on top of stack, like the other PSG words)
- [x] `PSGFREQ ( freq voice -- )` — set frequency
- [x] `PSGVOL ( vol voice -- )` — set volume (0-63)
- [x] `PSGWAV ( waveform voice -- )` — set waveform (0=pulse 1=saw 2=tri 3=noise)
- [x] `PSGINIT ( -- )` — reset/init all PSG voices
- [x] `PSGNOTE ( note voice -- )` — play a musical note (octave<<4 | 1..12, 0=off)
- [x] `PSGPAN ( pan voice -- )` — set stereo pan (1=left 2=right 3=both)
- [x] `PSGPLAY ( c-addr u voice -- )` — play a play-string (blocking)
- [x] `PSGCHORD ( c-addr u voice -- )` — play a chord string (blocking)

## Audio — FM (YM2151)  (channel on top of stack, like the other FM words)
- [x] `FMINIT ( -- )` — init chip + load default patches
- [x] `FMINST ( inst channel -- )` — load an instrument patch (0-162)
- [x] `FMVOL ( vol channel -- )` — set volume (0-63)
- [x] `FMNOTE ( note channel -- )` — play a note (octave<<4 | 1..12, 0=off)
- [x] `FMFREQ ( freq channel -- )` — play by raw frequency in Hz (17..4434)
- [x] `FMDRUM ( drum channel -- )` — play a drum sound (25-87, 0=none)
- [x] `FMVIB ( speed depth -- )` — set the global vibrato (depth 0..127)
- [x] `FMPAN ( pan channel -- )` — set stereo pan (1=left 2=right 3=both)
- [x] `FMPLAY ( c-addr u channel -- )` — play a play-string (blocking)
- [x] `FMCHORD ( c-addr u channel -- )` — play a chord string (blocking)
- [x] `FMPOKE ( value reg -- )` — write a YM2151 register via the API (shadow-tracked);
      `YM!` is the equivalent raw register write

## Load / Save   (filenames are Forth strings: c-addr u)
- [x] `LOAD ( c-addr u dev -- )` — load a PRG to its header address
- [x] `BLOAD ( c-addr u dev addr -- )` — load a PRG relocated to addr
- [x] `VLOAD ( c-addr u dev bank vaddr -- )` — load a (headered) file into VRAM
- [x] `SAVE ( c-addr u dev start end -- )` — save a memory range as a PRG (BASIC BSAVE)
- [x] `BVLOAD ( c-addr u dev bank vaddr -- )` — headerless load into VRAM
- [x] `BVERIFY ( c-addr u dev addr -- flag )` — verify a file against memory (-1 match / 0 mismatch)

## Input devices
- [x] `JOY ( n -- buttons )` — read joystick/gamepad n (0=keyboard, 1-4 gamepads)
- [x] `MOUSE ( mode -- )` — configure the mouse (0=off, 1=on, -1=auto-scale)
- [x] `MX ( -- x )` / `MY ( -- y )` — mouse X / Y position
- [x] `MB ( -- buttons )` — mouse button bitmask
- [x] `MWHEEL ( -- delta )` — mouse wheel delta (signed)

## Memory / banking / system
- [~] `POKE` / `PEEK` — Forth already has `C! C@ ! @`
- [x] `SETBANK ( bank -- )` — select the RAM bank at $A000-$BFFF (ROM bank not exposed)
- [ ] `I2CPOKE`/`I2CPEEK` — removed from the core to save ROM (rarely used; the
      KERNAL I2C entries aren't reachable from the bank-9 ROM anyway). Add a
      `SYSCALL`-based version to a toolkit if needed.
- [x] `SLEEP ( jiffies -- )` — wait n/60 seconds
- [x] `MS ( u -- )` — wait ~u milliseconds (calibrated busy loop)
- [x] `RESET ( -- )` — system reset (via SMC)
- [x] `REBOOT ( -- )` — soft reboot (reset vector)
- [x] `POWEROFF ( -- )` — power off (via SMC)
- [x] `KEYMAP ( c-addr u -- )` — set the keyboard layout by name, e.g. `S" en-us" KEYMAP`

## Math functions
Integer-friendly (feasible now — this Forth is 16-bit integer):
- [x] `SGN ( n -- -1|0|1 )` — sign
- [x] `RND ( u -- n )` — random number in 0..u-1 (built on `RANDOM`)
- [x] `RANDOM ( -- u )` — raw 16-bit random (KERNAL entropy source)
- [x] `POS ( -- col )` — current cursor column
- [~] `ABS(n)` — Forth already has `ABS`
- [~] `MOD(a, b)` — Forth already has `MOD`
- [~] `MIN(a, b)` / `MAX(a, b)` — Forth already has `MIN` / `MAX`
- [~] `FRE(n)` — free memory: Forth already has `UNUSED`
- [~] `INT(n)` — integer part: identity for 16-bit ints (no word needed)

Floating point — DONE by wrapping the ROM FP package (bank 4). The X16 keeps
FAC/ARG and all FP temporaries in $A9-$D2, clear of Forth's $22-$7F, so the ROM
math routines are called via jsrfar without corrupting Forth. Native words with
a dedicated float stack:
- [x] `S>F ( n -- ) (F: -- r )`, `F>S ( -- n ) (F: r -- )` — int <-> float
- [x] `F+ F- F* F/` — arithmetic
- [x] `FDUP FDROP FSWAP FOVER FNEGATE` — float-stack ops
- [x] `FSQRT FSIN FCOS FTAN FATAN FLN FEXP` — transcendentals
- [x] `F@ F!` — float memory ; `F< F0< F0=` — comparisons
- [x] `>FLOAT` and interpreter float literals (`3.14`, `1E3`, `-2.5E-2` in interpret mode)
- [x] `F.` — print a float ; `ISQRT ( n -- m )` — integer square root
- [x] `FVARIABLE FCONSTANT` (toolkit/X16FP.FTH)
- [x] BASIC names `SQR SIN COS TAN ATN LOG EXP` — aliases of the `F*` words; load `INCLUDE BASICMATH.FTH` (toolkit)
- [ ] optional polish: `FS. FE.`, float literals inside `:` definitions, signed `F>S`

## String / number-conversion functions   (in toolkit/X16STR.FTH — INCLUDE it)
Forth uses an `addr len` string model, so these take/return `c-addr u`:
- [x] `HEX$ ( u -- c-addr u )` — number → hex digits
- [x] `BIN$ ( u -- c-addr u )` — number → binary digits
- [x] `STR$ ( n -- c-addr u )` — signed number → string
- [x] `VAL ( c-addr u -- n )` — string → number
- [x] `ASC ( c-addr u -- code )` — first character's code
- [x] `CHR$ ( code -- c-addr 1 )` — code → 1-char string
- [x] `LEN ( c-addr u -- u )` — string length
- [x] `LEFT$ ( c-addr u n -- c-addr n2 )` — first n characters
- [x] `RIGHT$ ( c-addr u n -- c-addr2 n2 )` — last n characters
- [x] `MID$ ( c-addr u start len -- c-addr2 len2 )` — substring (start 1-based)
- [x] `RPT$ ( char n -- c-addr u )` — char repeated n times

## System / dev
- [x] `USR ( addr -- )` — call a machine-language routine at addr (must RTS)
- [x] `MONITOR ( -- )` — enter the built-in ML monitor (exit with X; needs no BASIC)
- [x] `EDIT ( c-addr u -- )` — launch the X16 full-screen text editor on a file
      (u=0 = new buffer). Save + quit, then INCLUDE the file. Uses the X16EDIT
      ROM bank; Forth's zero page is saved/restored around the call.
      KNOWN ISSUE: returning from the editor leaves Forth's first console
      operation glitchy (first RETURN swallowed; an immediate `INCLUDED` won't
      compile). BASIC's EDIT returns cleanly; the cause is Forth-specific and
      unresolved. Workaround: edit + save + quit, then RESET Forth (relaunch /
      cold start) and `INCLUDED` in the fresh session. See doc/EDIT-known-issue.md.
- [x] `OPEN ( c-addr u fam -- fileid ior )` — alias of `OPEN-FILE` (toolkit/X16BASIC.FTH)
- [x] `CLOSE ( fileid -- ior )` — alias of `CLOSE-FILE` (toolkit/X16BASIC.FTH)
- [x] `LINPUT ( c-addr +n -- +n2 )` — alias of `ACCEPT` (toolkit/X16BASIC.FTH)

Not implemented — these need the BASIC environment (they parse the BASIC text
buffer and/or use BASIC's zero page, which conflicts with Forth's), so they can't
be clean Forth words:
- `DOS` `HELP` `BOOT` `MENU` — BASIC-integrated commands (`BOOT` even RUNs a
  BASIC program). `MENU` is a BASIC-oriented launcher. (`EDIT` IS provided - it
  drives the standalone X16EDIT ROM, not the BASIC-coupled wrapper.)
- `LINPUT#` `BINPUT#` — read into BASIC string variables; use Forth's `READ-LINE` /
  `READ-FILE` instead.

---

### Excluded (pure BASIC-language commands)
Control flow & vars: `END FOR NEXT DATA INPUT# INPUT DIM READ LET GOTO RUN IF
RESTORE GOSUB RETURN REM STOP ON WAIT DEF CONT LIST CLR CMD GET NEW GET# ON…GOTO`.
Console/print: `PRINT PRINT# TAB SPC`.
Tape/legacy: `CLOAD CSAVE CVERIFY`.
Editor/dev/OS (BASIC environment): `DOS OLD BOOT MENU HELP EDIT REN EXEC BASLOAD
TEST BANNER LINPUT# BINPUT#`.
Variable introspection: `POINTER STRPTR`.
