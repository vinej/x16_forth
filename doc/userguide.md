# ForthX16 (TX16 2.0) — User Guide

A Forth 2012 system for the Commander X16 (and C64 / Foenix F256). This guide has
three parts:

- **[Section 1 — Tutorial](#section-1--tutorial)**: what Forth is, how to use the
  system, and how to program in it.
- **[Section 2 — Word reference](#section-2--word-reference)**: every word built
  into TX16, with its stack effect, purpose, and a small example, preceded by an
  alphabetical **[index](#index)**.
- **[Section 3 — Split-screen & bitmap graphics](#section-3)**: the optional
  `SPLIT.FTH` library — a bitmap graphics toolkit and a graphics/text split screen.
- **[Section 4 — Mortgage calculator](#section-4)**: the optional `MORTGAGE.FTH`
  library — a Canadian (semi-annual-compounding) mortgage payment and amortization
  calculator, and a worked example of floating point + currency formatting.
- **[Section 5 — RPN calculator (HP50.FTH)](#section-5)**: the optional `HP50.FTH`
  library — an HP-50g-style RPN scientific calculator (reals, integers, bases,
  bitwise, complex numbers, lists, vectors & matrices), with a fast
  turnkey-image reload.

Notation used throughout: a word's **stack effect** is written `( before -- after )`
with the top of stack on the right. `n`=signed number, `u`=unsigned, `d`=double
(two-cell) number, `c`=character, `addr`=address, `xt`=execution token, `flag`=
`TRUE`(-1)/`FALSE`(0), `f:`=floating-point stack item.

## Further reading

**This project**
- [Advanced guide](advanceguide.md) — the harder words explained with worked,
  tested examples: defining words (incl. `CREATE … DOES>`), compiling / the
  dictionary, and control flow.

**The Forth 2012 standard** (TX16 targets this standard)
- [forth-standard.org](https://forth-standard.org/) — the official, searchable
  Forth 2012 Standard; browse and read every standard word.

**Learning Forth** (free books & tutorials)
- [Starting FORTH](https://www.forth.com/starting-forth/) — Leo Brodie's classic
  beginner tutorial, free online edition. The best place to start.
- [Easy Forth](https://skilldrick.github.io/easyforth/) — Nick Morgan's
  interactive, in-browser tutorial: run the code as you read.
- [Thinking Forth](http://thinking-forth.sourceforge.net/) — Leo Brodie on Forth
  style and design philosophy (free, Creative Commons).
- [Gforth](https://gforth.org/) — a mature Forth 2012 implementation with a
  comprehensive manual; handy as a cross-reference on a desktop machine.

External tutorials use their own Forth systems, so a few words or details may
differ from TX16 — Section 2 below is the authoritative reference for *this* system.

---

# Section 1 — Tutorial

## 1.1 What is Forth?

Forth is an interactive, stack-based language. Instead of `2 + 3`, you write
`2 3 +` — this is **Reverse Polish Notation (RPN)**: values are pushed onto a
**data stack**, and words (Forth's name for functions/commands) consume them and
push results.

You type at the `OK` prompt. Numbers are pushed; words are executed immediately.
`.` prints and removes the top of stack:

```
2 3 + .        \ prints: 5
```

Everything is either a **number** or a **word**, separated by spaces. Spaces
matter; `2 3+` is the single unknown word `3+`, not `3 +`.

## 1.2 The data stack

The stack is the heart of Forth. Words document what they do with a **stack
effect comment** `( before -- after )`:

```
DUP    ( x -- x x )        duplicate the top item
DROP   ( x -- )            discard the top item
SWAP   ( a b -- b a )      exchange the top two
OVER   ( a b -- a b a )    copy the second item to the top
ROT    ( a b c -- b c a )  rotate the third item to the top
```

Try them and inspect the stack with `.S` (non-destructive print):

```
1 2 3 .S       \ <3> 1 2 3
SWAP .S        \ <3> 1 3 2
DROP .S        \ <2> 1 3
```

`.` prints and pops; `.S` prints the whole stack without changing it; `DEPTH`
pushes the number of items on the stack.

## 1.3 Numbers and BASE

Numbers are read in the current radix, set by `DECIMAL` (default) or `HEX`:

```
DECIMAL 255 .   \ 255
HEX 0FF .       \ FF   (leading 0 avoids clashing with a word)
DECIMAL
```

`.` prints signed, `U.` unsigned, `.R`/`U.R` in a field width. A number too big
for one 16-bit cell is a **double** (`d`), printed with `D.`. Write double
literals with a `.` in them: `10.` is the double `10 0`.

## 1.4 Defining new words

`:` starts a definition, `;` ends it. Between them, words are *compiled* rather
than executed:

```
: SQUARE ( n -- n^2 )  DUP * ;
5 SQUARE .      \ 25
```

Good style: give every definition a stack-effect comment. Keep words short — a
line or two — and build bigger words from smaller ones. This "factoring" is the
core Forth skill.

```
: 2DUP*  ( a b -- a b a*b )  2DUP * ;
: HYP²   ( a b -- c )  DUP * SWAP DUP * + ;   \ a² + b²
3 4 HYP² .      \ 25
```

## 1.5 Variables, constants, values

```
VARIABLE X          \ reserve one cell named X; X pushes its address
42 X !              \ store 42 into X   ( ! = store )
X @ .               \ 42                ( @ = fetch )
1 X +!              \ add 1 to X
X @ .               \ 43

10 CONSTANT TEN     \ TEN pushes 10
TEN .               \ 10

VALUE V 5 TO V      \ VALUE V starts 0; V pushes 5 after TO; read as V
7 TO V   V .        \ 7
```

Memory words: `@` `!` fetch/store a cell (2 bytes); `C@` `C!` a single byte;
`2@` `2!` a double/two cells; `+!` adds to a cell.

## 1.6 Conditionals and loops

Control-flow words only work **inside a definition**. A flag is any number:
`0` is false, non-zero is true; comparison words produce `TRUE`(-1)/`FALSE`(0).

```
: SIGN? ( n -- )
   DUP 0> IF   ." positive"
   ELSE DUP 0< IF ." negative"
        ELSE ." zero" THEN
   THEN DROP ;
```

Counted loop with `DO ... LOOP` (index from `I`):

```
: STARS ( n -- )  0 ?DO  [CHAR] * EMIT  LOOP ;
5 STARS         \ *****
```

- `DO ... LOOP` runs `limit start DO`, `I` is the index. Use `?DO` when the count
  may be zero. `+LOOP` steps by a value. `LEAVE` exits early; `UNLOOP` discards
  loop control before an early `EXIT`.
- `BEGIN ... UNTIL` loops until a flag is true; `BEGIN ... WHILE ... REPEAT` tests
  in the middle; `BEGIN ... AGAIN` loops forever (exit via `EXIT`/`LEAVE`).
- `CASE val OF ... ENDOF ... ENDCASE` is a multi-way branch.

```
: COUNTDOWN ( n -- )  BEGIN DUP . 1- DUP 0= UNTIL DROP ;
5 COUNTDOWN     \ 5 4 3 2 1
```

## 1.7 The return stack

Each `:` word has a **return stack** used for return addresses and loop indices.
You may borrow it briefly with `>R` (move to return stack) and `R>` (move back),
`R@` (copy). **Balance every `>R` with an `R>` in the same word**, and never
leave items across `;`. `I`/`J` read `DO`-loop indices from it.

## 1.8 Strings and text

```
." hello"                 \ compile-time: prints "hello" when the word runs
S" some text"             \ pushes ( c-addr u ) — address and length
S" file.fth" INCLUDED     \ load and interpret a file
." A" ." B"  →  AB
```

- `."` prints a literal string (inside a definition).
- `S"` gives a string as `( addr len )`; `TYPE` prints such a string; `COUNT`
  converts a counted string (`c-addr`) to `( addr len )`.
- `[CHAR] x` compiles the code of `x`; `CHAR x` gives it interpreting.
- `.(` prints immediately (handy at the top level).

## 1.9 Interpreting vs compiling; immediacy

`STATE` is false while interpreting, true while compiling (inside `:`). Words
marked **IMMEDIATE** run even during compilation — that is how `IF`, `."`, `(`
work. Advanced: `POSTPONE`, `[`, `]`, `LITERAL`, `[']`, and `CREATE ... DOES>`
let you build your own compiling words and data structures.

```
: CONSTANT2 ( n -- ) CREATE , DOES> @ ;   \ a hand-made CONSTANT
7 CONSTANT2 SEVEN   SEVEN .    \ 7
```

## 1.10 Using the system on the X16

- **Charset:** ForthX16 puts the console into **ISO mode** at cold start (it
  emits `$0F`), so text is normal PC-style ASCII — true upper- *and* lower-case,
  and a real backslash `\`. No PETSCII case inversion, and word lookup ignores
  case so you can type words in any case. If something switched the console
  away, `15 EMIT` re-enables ISO; `14 EMIT` = PETSCII upper/lower, `142 EMIT` =
  PETSCII upper/graphics. (Under `CHARSET`, ISO is charset 1.)
- **Loading files:** put `.FTH`/`.FR` files on the SD card (or host FS in the
  emulator) and use `S" NAME.FTH" INCLUDED`. On boot, `AUTORUN.FTH` (if present)
  is loaded automatically.
- **Free memory:** the boot banner prints `NNNNN BYTES FREE`; `UNUSED` pushes the
  bytes left for new definitions.
- **Run from ROM:** in the ROM build (bank 9) Forth is launched by typing `TEST`
  at the BASIC `READY.` prompt (see `doc/forth-in-rom-scope.md`). Everything in
  this guide works identically whether Forth runs from RAM (the `.PRG`) or in
  place from ROM.
- **Floating point** uses a separate floating-point stack (see §2, *Floating
  point*): `S>F` pushes an integer onto it, `F.` prints, `F+ F* FSQRT …` compute.
- **Hardware** words mirror the X16 BASIC 2.0 commands (VPOKE, SPRITE, FMNOTE,
  VLOAD, …) and generally take the **same argument order** as BASIC.

## 1.11 Handy habits

- Inspect with `.S` constantly; a growing stack usually means a missing `DROP`.
- `WORDS` lists the dictionary; `' NAME` gives a word's execution token; `SEE`-
  style introspection is not included, but `'` + `EXECUTE` lets you call by xt.
- `MARKER SAVE` then later `SAVE` (the marker word) rolls the dictionary back to
  that point — great for experimenting.
- Errors print `?` and abort to the prompt; the data stack is cleared on `ABORT`.
- Comments: `\ to end of line` and `( inline )`.

---

# Section 2 — Word reference

Every word built into TX16, grouped by topic. Each entry gives the **stack effect**, a one-line purpose, and a small example. Standard Forth 2012 words behave as in the standard; X16 words mirror the matching BASIC 2.0 command and generally take the same argument order.

## Index

Click a word to jump to its category section (words are also findable with your editor's search). Floating-point items operate on the FP stack.

**Symbols / digits** — [`!`](#memory), [`#`](#numeric-output), [`#>`](#numeric-output), [`#S`](#numeric-output), [`#TIB`](#interpreter-and-input-source), [`'`](#compiling-and-dictionary), [`(`](#interpreter-and-input-source), [`*`](#arithmetic), [`*.`](#game-support), [`*/`](#arithmetic), [`*/MOD`](#arithmetic), [`+`](#arithmetic), [`+!`](#memory), [`+FIELD`](#structures), [`+LOOP`](#control-flow), [`+PLACE`](#characters-and-strings), [`,`](#memory), [`,"`](#compiling-and-dictionary), [`-`](#arithmetic), [`-1`](#constants-and-literals), [`-ROT`](#stack-manipulation), [`.`](#numeric-output), [`."`](#characters-and-strings), [`.(`](#terminal-io), [`.R`](#numeric-output), [`.S`](#stack-manipulation), [`/`](#arithmetic), [`/MOD`](#arithmetic), [`/STRING`](#characters-and-strings), [`0`](#constants-and-literals), [`0<`](#comparison-and-logic), [`0<>`](#comparison-and-logic), [`0=`](#comparison-and-logic), [`0>`](#comparison-and-logic), [`1`](#constants-and-literals), [`1+`](#arithmetic), [`1-`](#arithmetic), [`2`](#constants-and-literals), [`2!`](#memory), [`2*`](#arithmetic), [`2+`](#arithmetic), [`2-`](#arithmetic), [`2/`](#arithmetic), [`2>R`](#return-stack-and-loop-index), [`2@`](#memory), [`2CONSTANT`](#defining-words), [`2DROP`](#stack-manipulation), [`2DUP`](#stack-manipulation), [`2LITERAL`](#compiling-and-dictionary), [`2OVER`](#stack-manipulation), [`2R>`](#return-stack-and-loop-index), [`2R@`](#return-stack-and-loop-index), [`2ROT`](#stack-manipulation), [`2SWAP`](#stack-manipulation), [`2VALUE`](#defining-words), [`2VARIABLE`](#defining-words), [`:`](#defining-words), [`:NONAME`](#defining-words), [`;`](#defining-words), [`<`](#comparison-and-logic), [`<#`](#numeric-output), [`<>`](#comparison-and-logic), [`=`](#comparison-and-logic), [`>`](#comparison-and-logic), [`>BODY`](#compiling-and-dictionary), [`>FLOAT`](#floating-point), [`>IN`](#interpreter-and-input-source), [`>NUMBER`](#number-and-text-parsing), [`>R`](#return-stack-and-loop-index), [`?`](#numeric-output), [`?COMP`](#compiling-and-dictionary), [`?DO`](#control-flow), [`?DUP`](#stack-manipulation), [`?STACK`](#compiling-and-dictionary), [`@`](#memory), [`[`](#compiling-and-dictionary), [`[']`](#compiling-and-dictionary), [`[CHAR]`](#characters-and-strings), [`[COMPILE]`](#compiling-and-dictionary), [`\`](#interpreter-and-input-source), [`]`](#compiling-and-dictionary)

**A** — [`ABORT`](#control-flow), [`ABORT"`](#control-flow), [`ABS`](#arithmetic), [`ACCEPT`](#terminal-io), [`ACTION-OF`](#defining-words), [`AGAIN`](#control-flow), [`AHEAD`](#control-flow), [`ALIGN`](#memory), [`ALIGNED`](#memory), [`ALLOT`](#memory), [`ALSO`](#wordlists-and-search-order), [`AND`](#bitwise), [`ASC`](#basic-alias-and-string-toolkit), [`ATN`](#basic-alias-and-string-toolkit)

**B** — [`B!`](#x16-system-control), [`B@`](#x16-system-control), [`BASE`](#numeric-output), [`BEGIN`](#control-flow), [`BEGIN-STRUCTURE`](#structures), [`BIN`](#files), [`BL`](#constants-and-literals), [`BLANK`](#memory), [`BLOAD`](#x16-load-and-save), [`BORDER`](#x16-video-screen-and-cursor), [`BUFFER:`](#defining-words), [`BVERIFY`](#x16-load-and-save), [`BVLOAD`](#x16-load-and-save), [`BYE`](#system-and-environment)

**C** — [`C!`](#memory), [`C"`](#characters-and-strings), [`C,`](#memory), [`C64`](#system-and-environment), [`C@`](#memory), [`CASE`](#control-flow), [`CATCH`](#control-flow), [`CATNIB`](#bit-and-byte-toolkit), [`CBIT`](#bit-and-byte-toolkit), [`CELL+`](#memory), [`CELLS`](#memory), [`CFIELD:`](#structures), [`CHAR`](#characters-and-strings), [`CHAR+`](#memory), [`CHARS`](#memory), [`CHR`](#basic-alias-and-string-toolkit), [`CLOSE`](#basic-alias-and-string-toolkit), [`CLOSE-FILE`](#files), [`CLOSE-SOURCE`](#interpreter-and-input-source), [`CLS`](#x16-video-screen-and-cursor), [`CMOVE`](#memory), [`CMOVE>`](#memory), [`COLLIDE?`](#game-support), [`COLOR`](#x16-video-screen-and-cursor), [`COMPARE`](#characters-and-strings), [`COMPILE`](#compiling-and-dictionary), [`COMPILE,`](#compiling-and-dictionary), [`CONSTANT`](#defining-words), [`COS`](#basic-alias-and-string-toolkit), [`COUNT`](#characters-and-strings), [`CR`](#terminal-io), [`CREATE`](#defining-words), [`CREATE-FILE`](#files), [`CURSOR`](#x16-video-screen-and-cursor)

**D** — [`D+`](#double-cell-math), [`D-`](#double-cell-math), [`D.`](#numeric-output), [`D.R`](#numeric-output), [`D0<`](#double-cell-math), [`D0=`](#double-cell-math), [`D2*`](#double-cell-math), [`D2/`](#double-cell-math), [`D<`](#double-cell-math), [`D=`](#double-cell-math), [`D>S`](#double-cell-math), [`DABS`](#double-cell-math), [`DECIMAL`](#numeric-output), [`DEFER`](#defining-words), [`DEFER!`](#defining-words), [`DEFER@`](#defining-words), [`DEFINITIONS`](#wordlists-and-search-order), [`DELETE-FILE`](#files), [`DEPTH`](#stack-manipulation), [`DMAX`](#double-cell-math), [`DMIN`](#double-cell-math), [`DNEGATE`](#double-cell-math), [`DO`](#control-flow), [`DOES>`](#defining-words), [`DROP`](#stack-manipulation), [`DU<`](#double-cell-math), [`DUP`](#stack-manipulation)

**E** — [`EDIT`](#x16-system-control), [`ELSE`](#control-flow), [`EMIT`](#terminal-io), [`END-STRUCTURE`](#structures), [`ENDCASE`](#control-flow), [`ENDOF`](#control-flow), [`ENVIRONMENT?`](#system-and-environment), [`ERASE`](#memory), [`EVALUATE`](#interpreter-and-input-source), [`EXECUTE`](#control-flow), [`EXIT`](#control-flow), [`EXP`](#basic-alias-and-string-toolkit)

**F** — [`F!`](#floating-point), [`F*`](#floating-point), [`F**`](#floating-point), [`F+`](#floating-point), [`F-`](#floating-point), [`F.`](#floating-point), [`F/`](#floating-point), [`F0<`](#floating-point), [`F0=`](#floating-point), [`F256`](#system-and-environment), [`F<`](#floating-point), [`F>S`](#floating-point), [`F@`](#floating-point), [`FABS`](#floating-point), [`FALSE`](#constants-and-literals), [`FATAN`](#floating-point), [`FBIT`](#bit-and-byte-toolkit), [`FCONSTANT`](#basic-alias-and-string-toolkit), [`FCOS`](#floating-point), [`FDROP`](#floating-point), [`FDUP`](#floating-point), [`FEXP`](#floating-point), [`FIELD:`](#structures), [`FILE-POSITION`](#files), [`FILE-SIZE`](#files), [`FILE-STATUS`](#files), [`FILL`](#memory), [`FIND`](#number-and-text-parsing), [`FLN`](#floating-point), [`FLUSH-FILE`](#files), [`FM/MOD`](#arithmetic), [`FMAX`](#floating-point), [`FMIN`](#floating-point), [`FMCHORD`](#x16-audio), [`FMDRUM`](#x16-audio), [`FMFREQ`](#x16-audio), [`FMINIT`](#x16-audio), [`FMINST`](#x16-audio), [`FMNOTE`](#x16-audio), [`FMPAN`](#x16-audio), [`FMPLAY`](#x16-audio), [`FMPOKE`](#x16-audio), [`FMVIB`](#x16-audio), [`FMVOL`](#x16-audio), [`FNEGATE`](#floating-point), [`FORGET`](#compiling-and-dictionary), [`FORTH`](#wordlists-and-search-order), [`FORTH-WORDLIST`](#wordlists-and-search-order), [`FOVER`](#floating-point), [`FPOW`](#floating-point), [`FRAME`](#x16-graphics), [`FRAMES`](#game-support), [`FSIN`](#floating-point), [`FSQRT`](#floating-point), [`FSWAP`](#floating-point), [`FTAN`](#floating-point), [`FVARIABLE`](#basic-alias-and-string-toolkit), [`F~`](#floating-point)

**G** — [`GCLS`](#x16-graphics), [`GET-CURRENT`](#wordlists-and-search-order), [`GET-ORDER`](#wordlists-and-search-order), [`GINIT`](#x16-graphics), [`GTEXT`](#x16-graphics)

**H** — [`HANDLER`](#control-flow), [`HERE`](#memory), [`HEX`](#numeric-output), [`HOLD`](#numeric-output), [`HOLDS`](#numeric-output)

**I** — [`I`](#return-stack-and-loop-index), [`IF`](#control-flow), [`IMMEDIATE`](#compiling-and-dictionary), [`INCLUDE`](#files), [`INCLUDE-FILE`](#files), [`INCLUDED`](#files), [`INVERT`](#bitwise), [`IRQ`](#system-and-environment), [`IS`](#defining-words), [`ISQRT`](#floating-point)

**J** — [`J`](#return-stack-and-loop-index), [`JOY`](#x16-input-devices)

**K** — [`KEY`](#terminal-io), [`KEYMAP`](#x16-system-control)

**L** — [`LEAVE`](#control-flow), [`LEFT`](#basic-alias-and-string-toolkit), [`LEN`](#basic-alias-and-string-toolkit), [`LINE`](#x16-graphics), [`LINPUT`](#basic-alias-and-string-toolkit), [`LITERAL`](#compiling-and-dictionary), [`LOAD`](#x16-load-and-save), [`LOCATE`](#x16-video-screen-and-cursor), [`LOG`](#basic-alias-and-string-toolkit), [`LOOP`](#control-flow), [`LSHIFT`](#bitwise)

**M** — [`M*`](#arithmetic), [`M*/`](#arithmetic), [`M+`](#double-cell-math), [`MARKER`](#compiling-and-dictionary), [`MAX`](#arithmetic), [`MB`](#x16-input-devices), [`MID`](#basic-alias-and-string-toolkit), [`MIN`](#arithmetic), [`MOD`](#arithmetic), [`MOUSE`](#x16-input-devices), [`MOVE`](#memory), [`MS`](#x16-system-control), [`MWHEEL`](#x16-input-devices), [`MX`](#x16-input-devices), [`MY`](#x16-input-devices)

**N** — [`NBIN`](#basic-alias-and-string-toolkit), [`NEGATE`](#arithmetic), [`NHEX`](#basic-alias-and-string-toolkit), [`NIP`](#stack-manipulation)

**O** — [`OF`](#control-flow), [`ONLY`](#wordlists-and-search-order), [`OPEN`](#basic-alias-and-string-toolkit), [`OPEN-FILE`](#files), [`OR`](#bitwise), [`ORDER`](#wordlists-and-search-order), [`OVAL`](#x16-graphics), [`OVER`](#stack-manipulation)

**P** — [`PAD`](#memory), [`PARSE`](#number-and-text-parsing), [`PARSE-NAME`](#number-and-text-parsing), [`PICK`](#stack-manipulation), [`PLACE`](#characters-and-strings), [`POS`](#x16-video-screen-and-cursor), [`POSTPONE`](#compiling-and-dictionary), [`PREVIOUS`](#wordlists-and-search-order), [`PSET`](#x16-graphics), [`PSGCHORD`](#x16-audio), [`PSGFREQ`](#x16-audio), [`PSGINIT`](#x16-audio), [`PSGNOTE`](#x16-audio), [`PSGPAN`](#x16-audio), [`PSGPLAY`](#x16-audio), [`PSGVOL`](#x16-audio), [`PSGWAV`](#x16-audio)

**Q** — [`QUIT`](#control-flow)

**R** — [`R/O`](#files), [`RP@`](#control-flow), [`R/W`](#files), [`R>`](#return-stack-and-loop-index), [`R@`](#return-stack-and-loop-index), [`RANDOM`](#system-and-environment), [`RDROP`](#return-stack-and-loop-index), [`READ-FILE`](#files), [`READ-LINE`](#files), [`REBOOT`](#x16-system-control), [`RECT`](#x16-graphics), [`RECURSE`](#control-flow), [`REFILL`](#interpreter-and-input-source), [`RENAME-FILE`](#files), [`REPEAT`](#control-flow), [`REPOSITION-FILE`](#files), [`REQUIRE`](#files), [`REQUIRED`](#files), [`RESIZE-FILE`](#files), [`RESTORE-INPUT`](#interpreter-and-input-source), [`RIGHT`](#basic-alias-and-string-toolkit), [`RING`](#x16-graphics), [`RND`](#system-and-environment), [`ROLL`](#stack-manipulation), [`ROT`](#stack-manipulation), [`RPT`](#basic-alias-and-string-toolkit), [`RSHIFT`](#bitwise)

**S** — [`S"`](#characters-and-strings), [`S>D`](#double-cell-math), [`S>F`](#floating-point), [`SAVE`](#x16-load-and-save), [`SAVE-INPUT`](#interpreter-and-input-source), [`SBIT`](#bit-and-byte-toolkit), [`SCREEN`](#x16-video-screen-and-cursor), [`SCROLLX`](#x16-video-screen-and-cursor), [`SCROLLY`](#x16-video-screen-and-cursor), [`SEARCH-WORDLIST`](#wordlists-and-search-order), [`SET-CURRENT`](#wordlists-and-search-order), [`SET-ORDER`](#wordlists-and-search-order), [`SETBANK`](#x16-system-control), [`SGN`](#arithmetic), [`SIGN`](#numeric-output), [`SIN`](#basic-alias-and-string-toolkit), [`SLEEP`](#x16-system-control), [`SLITERAL`](#compiling-and-dictionary), [`SM/REM`](#arithmetic), [`SOURCE`](#interpreter-and-input-source), [`SOURCE-ID`](#interpreter-and-input-source), [`SP@`](#control-flow), [`SPACE`](#terminal-io), [`SPACES`](#terminal-io), [`SPLIT`](#bit-and-byte-toolkit), [`SPRITE`](#x16-sprites), [`SPRITE-GET`](#x16-sprites), [`SPRITE-IMAGE`](#x16-sprites), [`SPRITE-MEM`](#x16-sprites), [`SPRITE-MOV`](#x16-sprites), [`SPRITE-POS`](#x16-sprites), [`SPRITE-SIZE`](#x16-sprites), [`SPRITE-Z`](#x16-sprites), [`SPRITES-OFF`](#x16-sprites), [`SPRITES-ON`](#x16-sprites), [`SPRLOAD`](#x16-load-and-save), [`SPRSAVE`](#x16-load-and-save), [`SQR`](#basic-alias-and-string-toolkit), [`STATE`](#interpreter-and-input-source), [`STR`](#basic-alias-and-string-toolkit), [`SWAP`](#stack-manipulation), [`S\"`](#characters-and-strings)

**T** — [`TAN`](#basic-alias-and-string-toolkit), [`TATTR`](#x16-video-screen-and-cursor), [`TDATA`](#x16-video-screen-and-cursor), [`THEN`](#control-flow), [`THROW`](#control-flow), [`TIB`](#interpreter-and-input-source), [`TILE`](#x16-video-screen-and-cursor), [`TILELOAD`](#x16-load-and-save), [`TILESAVE`](#x16-load-and-save), [`TMAPLOAD`](#x16-load-and-save), [`TMAPSAVE`](#x16-load-and-save), [`TO`](#defining-words), [`TRUE`](#constants-and-literals), [`TUCK`](#stack-manipulation), [`TYPE`](#characters-and-strings)

**U** — [`U.`](#numeric-output), [`U.R`](#numeric-output), [`U<`](#comparison-and-logic), [`U>`](#comparison-and-logic), [`UD*`](#arithmetic), [`UD/MOD`](#arithmetic), [`UM*`](#arithmetic), [`UM/MOD`](#arithmetic), [`UNLOOP`](#control-flow), [`UNTIL`](#control-flow), [`UNUSED`](#memory), [`USR`](#system-and-environment)

**V** — [`V!`](#x16-video-screen-and-cursor), [`V!W`](#x16-video-screen-and-cursor), [`V@`](#x16-video-screen-and-cursor), [`VADDR`](#x16-video-screen-and-cursor), [`VAL`](#basic-alias-and-string-toolkit), [`VALUE`](#defining-words), [`VARIABLE`](#defining-words), [`VER`](#system-and-environment), [`VFILL`](#game-support), [`VLOAD`](#x16-load-and-save), [`VPEEK`](#x16-video-screen-and-cursor), [`VPOKE`](#x16-video-screen-and-cursor), [`VSAVE`](#x16-load-and-save), [`VSYNC`](#game-support)

**W** — [`W/O`](#files), [`WHILE`](#control-flow), [`WITHIN`](#comparison-and-logic), [`WORD`](#number-and-text-parsing), [`WORDLIST`](#wordlists-and-search-order), [`WORDS`](#wordlists-and-search-order), [`WRITE-FILE`](#files), [`WRITE-LINE`](#files)

**X** — [`X16`](#system-and-environment), [`XOR`](#bitwise)

**Y** — [`YM!`](#x16-audio)


## Stack manipulation

- **`DUP`** ( x -- x x ) — duplicate the top item. `5 DUP` → `5 5`
- **`DROP`** ( x -- ) — discard the top item. `1 2 DROP` → `1`
- **`OVER`** ( a b -- a b a ) — copy the second item to the top. `1 2 OVER` → `1 2 1`
- **`SWAP`** ( a b -- b a ) — exchange the top two. `1 2 SWAP` → `2 1`
- **`NIP`** ( a b -- b ) — drop the second item. `1 2 NIP` → `2`
- **`TUCK`** ( a b -- b a b ) — copy the top under the second. `1 2 TUCK` → `2 1 2`
- **`ROT`** ( a b c -- b c a ) — rotate the third item to the top. `1 2 3 ROT` → `2 3 1`
- **`-ROT`** ( a b c -- c a b ) — rotate the top item down to third. `1 2 3 -ROT` → `3 1 2`
- **`PICK`** ( xu..x0 u -- xu..x0 xu ) — copy the u-th item (0 = top). `9 8 7 2 PICK` → `9 8 7 9`
- **`ROLL`** ( xu..x0 u -- .. x0 xu ) — move the u-th item to the top. `1 2 3 2 ROLL` → `2 3 1`
- **`DEPTH`** ( -- n ) — number of items on the data stack. `1 2 DEPTH` → `1 2 2`
- **`2DROP`** ( a b -- ) — drop a pair. `1 2 3 2DROP` → `1`
- **`2DUP`** ( a b -- a b a b ) — duplicate the top pair. `1 2 2DUP` → `1 2 1 2`
- **`2SWAP`** ( a b c d -- c d a b ) — exchange the top two pairs.
- **`2OVER`** ( a b c d -- a b c d a b ) — copy the second pair to the top.
- **`2ROT`** ( a b c d e f -- c d e f a b ) — rotate the third pair to the top.
- **`?DUP`** ( x -- x x | 0 ) — duplicate only if non-zero. `5 ?DUP` → `5 5`; `0 ?DUP` → `0`
- **`.S`** ( -- ) — print the whole stack without changing it. `1 2 .S` → `<2> 1 2`

## Arithmetic

- **`+`** ( n1 n2 -- n3 ) — add. `2 3 +` → `5`
- **`-`** ( n1 n2 -- n3 ) — subtract. `7 3 -` → `4`
- **`*`** ( n1 n2 -- n3 ) — multiply. `4 5 *` → `20`
- **`/`** ( n1 n2 -- n3 ) — signed divide. `17 5 /` → `3`
- **`MOD`** ( n1 n2 -- rem ) — remainder. `17 5 MOD` → `2`
- **`/MOD`** ( n1 n2 -- rem quot ) — remainder and quotient. `17 5 /MOD` → `2 3`
- **`*/`** ( n1 n2 n3 -- n ) — `n1*n2/n3` with a double-precision intermediate (no overflow). `10 3 4 */` → `7`
- **`*/MOD`** ( n1 n2 n3 -- rem quot ) — like `*/` but also the remainder.
- **`FM/MOD`** ( d n -- rem quot ) — floored division of a double by a single.
- **`SM/REM`** ( d n -- rem quot ) — symmetric (truncating) division of a double by a single.
- **`UM/MOD`** ( ud u -- urem uquot ) — unsigned double / single.
- **`UD/MOD`** ( ud u -- urem udquot ) — unsigned double / single giving a double quotient (mixed-precision helper).
- **`UM*`** ( u1 u2 -- ud ) — unsigned multiply to a double. `1000 1000 UM* D.` → `1000000`
- **`M*`** ( n1 n2 -- d ) — signed multiply to a double.
- **`UD*`** ( ud u -- ud ) — unsigned double × single (mixed-precision helper used by number output).
- **`M*/`** ( d n1 n2 -- d ) — `d*n1/n2` with triple-precision intermediate.
- **`ABS`** ( n -- u ) — absolute value. `-5 ABS` → `5`
- **`NEGATE`** ( n -- -n ) — negate. `5 NEGATE` → `-5`
- **`1+`** ( n -- n+1 ). `9 1+` → `10`
- **`1-`** ( n -- n-1 ). `9 1-` → `8`
- **`2+`** ( n -- n+2 ). `9 2+` → `11`
- **`2-`** ( n -- n-2 ). `9 2-` → `7`
- **`2*`** ( n -- n*2 ) — arithmetic shift left. `5 2*` → `10`
- **`2/`** ( n -- n/2 ) — arithmetic shift right (keeps sign). `-10 2/` → `-5`
- **`MAX`** ( n1 n2 -- n ) — larger. `3 9 MAX` → `9`
- **`MIN`** ( n1 n2 -- n ) — smaller. `3 9 MIN` → `3`
- **`SGN`** ( n -- -1|0|1 ) — sign of n (X16, mirrors BASIC `SGN`). `-7 SGN` → `-1`

## Double-cell math

Doubles occupy two stack cells (low then high). Type a double literal with a dot: `10.`

- **`S>D`** ( n -- d ) — single to double (sign-extend). `5 S>D D.` → `5`
- **`D>S`** ( d -- n ) — double to single (drop high cell).
- **`DNEGATE`** ( d -- -d ) — negate a double.
- **`DABS`** ( d -- ud ) — absolute value of a double.
- **`M+`** ( d n -- d ) — add a single to a double.
- **`D+`** ( d1 d2 -- d3 ) — add doubles. `10. 20. D+ D.` → `30`
- **`D-`** ( d1 d2 -- d3 ) — subtract doubles.
- **`D2*`** ( d -- 2d ) — double a double.
- **`D2/`** ( d -- d/2 ) — halve a double (arithmetic).
- **`D=`** ( d1 d2 -- flag ) — doubles equal?
- **`D<`** ( d1 d2 -- flag ) — signed double less-than.
- **`DU<`** ( ud1 ud2 -- flag ) — unsigned double less-than.
- **`D0=`** ( d -- flag ) — double is zero?
- **`D0<`** ( d -- flag ) — double is negative?
- **`DMAX`** ( d1 d2 -- d ) — larger double.
- **`DMIN`** ( d1 d2 -- d ) — smaller double.

## Comparison and logic

Comparisons return `TRUE` (-1, all bits set) or `FALSE` (0).

- **`0=`** ( x -- flag ) — equal to zero? (also logical NOT). `0 0=` → `-1`
- **`0<`** ( n -- flag ) — negative? `-3 0<` → `-1`
- **`0>`** ( n -- flag ) — positive?
- **`0<>`** ( x -- flag ) — non-zero?
- **`=`** ( a b -- flag ) — equal? `5 5 =` → `-1`
- **`<>`** ( a b -- flag ) — not equal?
- **`<`** ( n1 n2 -- flag ) — signed less-than. `3 9 <` → `-1`
- **`>`** ( n1 n2 -- flag ) — signed greater-than.
- **`U<`** ( u1 u2 -- flag ) — unsigned less-than.
- **`U>`** ( u1 u2 -- flag ) — unsigned greater-than.
- **`WITHIN`** ( n lo hi -- flag ) — is `lo <= n < hi`? `5 0 10 WITHIN` → `-1`

## Bitwise

- **`AND`** ( x1 x2 -- x3 ) — bitwise AND. `$0F $33 AND` → `3` (in HEX)
- **`OR`** ( x1 x2 -- x3 ) — bitwise OR.
- **`XOR`** ( x1 x2 -- x3 ) — bitwise exclusive-OR.
- **`INVERT`** ( x -- ~x ) — one's complement (flip all bits). `0 INVERT` → `-1`
- **`LSHIFT`** ( x u -- x' ) — logical shift left by u bits. `1 4 LSHIFT` → `16`
- **`RSHIFT`** ( x u -- x' ) — logical shift right by u bits. `256 4 RSHIFT` → `16`

## Constants and literals

- **`0`** ( -- 0 ), **`1`** ( -- 1 ), **`2`** ( -- 2 ), **`-1`** ( -- -1 ) — fast common constants.
- **`TRUE`** ( -- -1 ) — canonical true flag.
- **`FALSE`** ( -- 0 ) — canonical false flag.
- **`BL`** ( -- 32 ) — the blank (space) character code. `BL EMIT` prints a space.

## Memory

Cells are 16-bit (2 bytes). Addresses are byte addresses.

- **`@`** ( addr -- x ) — fetch a cell. `X @`
- **`!`** ( x addr -- ) — store a cell. `42 X !`
- **`C@`** ( addr -- c ) — fetch a byte.
- **`C!`** ( c addr -- ) — store a byte.
- **`2@`** ( addr -- x1 x2 ) — fetch a double / two cells.
- **`2!`** ( x1 x2 addr -- ) — store two cells.
- **`+!`** ( n addr -- ) — add n to the cell at addr. `1 X +!`
- **`,`** ( x -- ) — compile a cell into the dictionary at `HERE`. `CREATE T 1 , 2 , 3 ,`
- **`C,`** ( c -- ) — compile a byte into the dictionary.
- **`HERE`** ( -- addr ) — next free dictionary address.
- **`ALLOT`** ( n -- ) — reserve n bytes of dictionary space. `CREATE BUF 100 ALLOT`
- **`UNUSED`** ( -- u ) — bytes of dictionary space remaining. `UNUSED .`
- **`PAD`** ( -- addr ) — address of a scratch buffer (not preserved across words).
- **`ERASE`** ( addr u -- ) — set u bytes to 0.
- **`FILL`** ( addr u c -- ) — set u bytes to character c.
- **`BLANK`** ( addr u -- ) — set u bytes to spaces.
- **`MOVE`** ( src dst u -- ) — copy u bytes, handling overlap correctly.
- **`CMOVE`** ( src dst u -- ) — copy u bytes low→high.
- **`CMOVE>`** ( src dst u -- ) — copy u bytes high→low.
- **`CELL+`** ( addr -- addr+2 ) — advance one cell.
- **`CELLS`** ( n -- n*2 ) — n cells in bytes. `3 CELLS` → `6`
- **`CHAR+`** ( addr -- addr+1 ) — advance one char.
- **`CHARS`** ( n -- n ) — n chars in bytes (1 byte/char here).
- **`ALIGN`** ( -- ) — align `HERE` (no-op on this byte-addressed CPU).
- **`ALIGNED`** ( addr -- addr ) — align an address (no-op here).

## Numeric output

- **`.`** ( n -- ) — print a signed number and a space. `42 .` → `42 `
- **`U.`** ( u -- ) — print an unsigned number.
- **`.R`** ( n width -- ) — print n right-justified in a field. `5 4 .R` → `   5`
- **`U.R`** ( u width -- ) — unsigned, right-justified.
- **`D.`** ( d -- ) — print a double. `1000000. D.` → `1000000`
- **`D.R`** ( d width -- ) — print a double right-justified.
- **`?`** ( addr -- ) — print the cell stored at addr. `X ?`
- **`<#`** ( -- ) — begin pictured numeric output.
- **`#`** ( ud -- ud' ) — convert one digit into the output.
- **`#S`** ( ud -- 0 0 ) — convert all remaining digits.
- **`#>`** ( ud -- addr len ) — end pictured output, leaving the string.
- **`HOLD`** ( c -- ) — insert a character into the pictured output.
- **`HOLDS`** ( addr len -- ) — insert a string into the pictured output.
- **`SIGN`** ( n -- ) — insert a `-` if n is negative.
- **`DECIMAL`** ( -- ) — set radix to 10.
- **`HEX`** ( -- ) — set radix to 16.
- **`BASE`** ( -- addr ) — variable holding the current radix. `BASE @ .`

Pictured example (format with a decimal point): `: .## ( n -- ) 0 <# # # [CHAR] . HOLD #S #> TYPE ;`  `1234 .##` → `12.34`

## Number and text parsing

- **`>NUMBER`** ( ud addr len -- ud' addr' len' ) — accumulate digits into a double until a non-digit.
- **`WORD`** ( c -- c-addr ) — parse the next `c`-delimited word into a counted string. `BL WORD`
- **`PARSE`** ( c -- addr len ) — parse the input up to the next `c` (no leading skip).
- **`PARSE-NAME`** ( -- addr len ) — parse the next space-delimited name.
- **`FIND`** ( c-addr -- c-addr 0 | xt 1 | xt -1 ) — look up a counted-string name; 1 = immediate, -1 = normal.

## Characters and strings

- **`S"`** ( "ccc\"" -- addr len ) — a string literal. `S" hello" TYPE` → `hello`
- **`S\"`** ( "ccc\"" -- addr len ) — string literal with escapes: `\n \t \" \\ \e` etc.
- **`."`** ( "ccc\"" -- ) — print a literal string when the word runs. `: HI ." hello" ;`
- **`C"`** ( "ccc\"" -- c-addr ) — a counted-string literal.
- **`COUNT`** ( c-addr -- addr len ) — convert a counted string to address/length.
- **`TYPE`** ( addr len -- ) — print a string. `S" hi" TYPE`
- **`COMPARE`** ( a1 u1 a2 u2 -- n ) — compare two strings; -1/0/1.
- **`/STRING`** ( addr len n -- addr+n len-n ) — remove n characters from the front.
- **`PLACE`** ( addr len dst -- ) — store a string as a counted string at dst.
- **`+PLACE`** ( addr len dst -- ) — append a string to the counted string at dst.
- **`CHAR`** ( "c" -- n ) — code of the next character (interpreting). `CHAR A` → `65`
- **`[CHAR]`** ( "c" -- ) — compile the code of the next character (in a definition). `[CHAR] *`

## Terminal I/O

- **`EMIT`** ( c -- ) — output one character. `65 EMIT` → `A`
- **`CR`** ( -- ) — output a newline.
- **`SPACE`** ( -- ) — output one space.
- **`SPACES`** ( n -- ) — output n spaces.
- **`KEY`** ( -- c ) — wait for and return one keypress.
- **`ACCEPT`** ( addr n -- len ) — read an input line (max n chars) into addr; return the count.
- **`.(`** ( "ccc)" -- ) — print a string immediately, even while interpreting. `.( hello)`

## Interpreter and input source

- **`TIB`** ( -- addr ) — the terminal input buffer.
- **`#TIB`** ( -- addr ) — variable: number of characters in TIB.
- **`>IN`** ( -- addr ) — variable: current parse offset into the input.
- **`SOURCE`** ( -- addr len ) — the current input buffer and its length.
- **`SOURCE-ID`** ( -- 0 | -1 | fileid ) — 0 = keyboard, -1 = `EVALUATE`, else a file.
- **`REFILL`** ( -- flag ) — read the next input line; false at end.
- **`EVALUATE`** ( addr len -- ) — interpret a string as Forth. `S" 2 3 +" EVALUATE .` → `5`
- **`SAVE-INPUT`** ( -- xn..x1 n ) — save the input position.
- **`RESTORE-INPUT`** ( xn..x1 n -- flag ) — restore a saved input position.
- **`CLOSE-SOURCE`** ( -- ) — close the current file input source (used by nested `INCLUDE`).
- **`STATE`** ( -- addr ) — variable: non-zero while compiling.
- **`(`** ( "ccc)" -- ) — inline comment up to `)`. `( n -- n*2 )`
- **`\`** ( "line" -- ) — comment to end of line.

## Defining words

> New to these? The [advanced guide](advanceguide.md) explains them with worked
> examples and when-to-use notes — especially `CREATE … DOES>` and `VALUE`/`TO`.

- **`:`** ( "name" -- ) — start a new definition (enter compile state). `: SQ DUP * ;`
- **`;`** ( -- ) — finish a definition (IMMEDIATE).
- **`:NONAME`** ( -- xt ) — start an unnamed definition; leaves its xt at `;`.
- **`CREATE`** ( "name" -- ) — make a word that pushes its data-field address.
- **`VARIABLE`** ( "name" -- ) — create a 1-cell variable. `VARIABLE X`
- **`2VARIABLE`** ( "name" -- ) — create a 2-cell (double) variable.
- **`CONSTANT`** ( n "name" -- ) — create a constant. `10 CONSTANT TEN`
- **`2CONSTANT`** ( d "name" -- ) — create a double constant.
- **`VALUE`** ( n "name" -- ) — create a value; read by name, change with `TO`. `5 VALUE V`
- **`2VALUE`** ( d "name" -- ) — create a double value.
- **`DEFER`** ( "name" -- ) — create a revectorable word. `DEFER EMITTER`
- **`BUFFER:`** ( n "name" -- ) — create an n-byte buffer word. `80 BUFFER: LINE`
- **`DOES>`** ( -- ) — give a `CREATE`d word run-time behaviour. `: CONST CREATE , DOES> @ ;`
- **`TO`** ( n "name" -- ) — store into a `VALUE`. `7 TO V`
- **`IS`** ( xt "name" -- ) — set a `DEFER`'s action. `' CR IS EMITTER`
- **`ACTION-OF`** ( "name" -- xt ) — get a `DEFER`'s current action.
- **`DEFER@`** ( xt1 -- xt2 ) — fetch the action of a deferred word by xt.
- **`DEFER!`** ( xt2 xt1 -- ) — set the action of a deferred word by xt.

## Compiling and dictionary

> These metaprogramming words (execution tokens, immediate words, `POSTPONE`,
> `MARKER`, …) are explained with examples in the [advanced guide](advanceguide.md).

- **`'`** ( "name" -- xt ) — find a word's execution token. `' DUP EXECUTE`
- **`[']`** ( "name" -- ) — compile a word's xt (in a definition).
- **`COMPILE,`** ( xt -- ) — append a call to xt to the current definition.
- **`COMPILE`** ( -- ) — (legacy) compile the following word into the definition.
- **`[`** ( -- ) — switch to interpret state inside a definition (IMMEDIATE).
- **`]`** ( -- ) — switch back to compile state.
- **`LITERAL`** ( x -- ) — compile x as a literal (IMMEDIATE). `[ 2 3 + ] LITERAL`
- **`2LITERAL`** ( d -- ) — compile a double literal.
- **`SLITERAL`** ( addr len -- ) — compile a string literal.
- **`POSTPONE`** ( "name" -- ) — compile the compilation behaviour of a word (IMMEDIATE).
- **`[COMPILE]`** ( "name" -- ) — (legacy) force-compile an immediate word.
- **`IMMEDIATE`** ( -- ) — mark the most recent definition immediate.
- **`MARKER`** ( "name" -- ) — create a word that, when run, forgets everything defined after it. `MARKER SANDBOX`
- **`FORGET`** ( "name" -- ) — remove a word and all words defined after it.
- **`>BODY`** ( xt -- addr ) — data-field address of a `CREATE`d word.
- **`?COMP`** ( -- ) — abort unless currently compiling.
- **`?STACK`** ( -- ) — check the data stack for under/overflow.
- **`,"`** ( "ccc\"" -- ) — compile a counted string into the dictionary.

## Control flow

These are IMMEDIATE and used inside `:` definitions.

- **`IF`** ( flag -- ) — begin a conditional; runs to `ELSE`/`THEN` when flag is true.
- **`THEN`** ( -- ) — end an `IF`.
- **`ELSE`** ( -- ) — the false branch of `IF`.
- **`BEGIN`** ( -- ) — start of a loop.
- **`UNTIL`** ( flag -- ) — loop back to `BEGIN` until flag is true.
- **`AGAIN`** ( -- ) — loop back to `BEGIN` forever.
- **`WHILE`** ( flag -- ) — mid-test; falls through to after `REPEAT` when false.
- **`REPEAT`** ( -- ) — loop back to `BEGIN` (with `WHILE`).
- **`DO`** ( limit start -- ) — begin a counted loop. `10 0 DO I . LOOP`
- **`?DO`** ( limit start -- ) — like `DO` but skips entirely if `limit = start`.
- **`LOOP`** ( -- ) — increment the index by 1 and test.
- **`+LOOP`** ( n -- ) — increment the index by n and test. `10 0 DO I . 2 +LOOP`
- **`UNLOOP`** ( -- ) — discard loop control (before an early `EXIT`).
- **`LEAVE`** ( -- ) — exit the innermost loop immediately.
- **`CASE`** / **`OF`** ( x -- ) / **`ENDOF`** / **`ENDCASE`** — multi-way branch. `CASE 1 OF ." one" ENDOF ." other" ENDCASE`
- **`AHEAD`** ( -- ) — compile an unconditional forward branch (advanced).
- **`RECURSE`** ( -- ) — call the definition currently being compiled.
- **`EXIT`** ( -- ) — return from the current word.
- **`EXECUTE`** ( xt -- ) — call the word given by its xt. `' CR EXECUTE`
- **`QUIT`** ( -- ) — empty the return stack and re-enter the interpreter (no message).
- **`ABORT`** ( -- ) — clear both stacks and return to the interpreter.
- **`ABORT"`** ( flag "ccc\"" -- ) — if flag is true, print the message and `ABORT`. `x 0= ABORT" zero!"`
- **`CATCH`** ( i*x xt -- j*x 0 | i*x n ) — run `xt`; return `0` if it completes, or the code `n` passed to `THROW`, with the stacks restored. The recoverable alternative to `ABORT`. `' RISKY CATCH IF ." failed" THEN`
- **`THROW`** ( k*x n -- k*x | i*x n ) — if `n` is non-zero, unwind to the nearest `CATCH` and return `n` from it; `0 THROW` does nothing. An uncaught `THROW` performs `ABORT`.
- **`SP@`** ( -- addr ), **`RP@`** ( -- addr ) — fetch the data / return stack pointer (used by `CATCH`).
- **`HANDLER`** ( -- addr ) — variable holding the current exception frame (0 = none).

## Return stack and loop index

- **`>R`** ( x -- ) (R: -- x) — move an item to the return stack.
- **`R>`** ( -- x ) (R: x -- ) — move it back.
- **`R@`** ( -- x ) — copy the top of the return stack.
- **`RDROP`** (R: x -- ) — drop the top of the return stack.
- **`2>R`** ( x1 x2 -- ) — move a pair to the return stack.
- **`2R>`** ( -- x1 x2 ) — move a pair back.
- **`2R@`** ( -- x1 x2 ) — copy a pair.
- **`I`** ( -- n ) — index of the innermost `DO` loop.
- **`J`** ( -- n ) — index of the next-outer `DO` loop.

## Wordlists and search order

- **`WORDS`** ( -- ) — list the words in the context wordlist.
- **`GET-ORDER`** ( -- wid_n .. wid_1 n ) — current search order.
- **`SET-ORDER`** ( wid_n .. wid_1 n -- ) — set the search order.
- **`GET-CURRENT`** ( -- wid ) — the wordlist new definitions go into.
- **`SET-CURRENT`** ( wid -- ) — set that wordlist.
- **`ALSO`** ( -- ) — duplicate the top of the search order.
- **`ONLY`** ( -- ) — reduce the search order to the minimal set.
- **`PREVIOUS`** ( -- ) — drop the top wordlist from the search order.
- **`ORDER`** ( -- ) — display the search order and current wordlist.
- **`DEFINITIONS`** ( -- ) — make the top of the search order the current wordlist.
- **`WORDLIST`** ( -- wid ) — create a new, empty wordlist.
- **`SEARCH-WORDLIST`** ( addr len wid -- 0 | xt 1 | xt -1 ) — search one wordlist.
- **`FORTH`** ( -- ) — put the Forth wordlist at the top of the search order.
- **`FORTH-WORDLIST`** ( -- wid ) — the wid of the main Forth wordlist.

## Files

File access methods combine with `BIN`: e.g. `R/O BIN`.

- **`INCLUDE`** ( "name" -- ) — load and interpret a file by name. `INCLUDE GAME.FTH`
- **`INCLUDED`** ( addr len -- ) — load and interpret the file named by a string. `S" GAME.FTH" INCLUDED`
- **`INCLUDE-FILE`** ( fileid -- ) — interpret an already-open file.
- **`REQUIRE`** ( "name" -- ) / **`REQUIRED`** ( addr len -- ) — include a file only once.
- **`OPEN-FILE`** ( addr len fam -- fileid ior ) — open a file; ior 0 = success.
- **`CLOSE-FILE`** ( fileid -- ior ) — close a file.
- **`CREATE-FILE`** ( addr len fam -- fileid ior ) — create/overwrite a file.
- **`DELETE-FILE`** ( addr len -- ior ) — delete a file.
- **`RENAME-FILE`** ( a1 u1 a2 u2 -- ior ) — rename.
- **`RESIZE-FILE`** ( ud fileid -- ior ) — set a file's size.
- **`READ-FILE`** ( addr u fileid -- u2 ior ) — read up to u bytes.
- **`WRITE-FILE`** ( addr u fileid -- ior ) — write u bytes.
- **`READ-LINE`** ( addr u fileid -- u2 flag ior ) — read a line.
- **`WRITE-LINE`** ( addr u fileid -- ior ) — write a line + newline.
- **`FILE-POSITION`** ( fileid -- ud ior ) / **`REPOSITION-FILE`** ( ud fileid -- ior ) — get/set position.
- **`FILE-SIZE`** ( fileid -- ud ior ) — size in bytes.
- **`FILE-STATUS`** ( addr len -- x ior ) — query a named file.
- **`FLUSH-FILE`** ( fileid -- ior ) — flush buffers.
- **`R/O`** ( -- fam ) read-only, **`W/O`** write-only, **`R/W`** read/write, **`BIN`** ( fam -- fam ) binary modifier.

X16 SD-card directory (device 8):
- **`DIR`** ( -- ) — list the current directory (built in).
- **`CD`** ( "name" -- ) — change directory, parsing the name like `INCLUDE`: `CD FORTH`.
- **`CD..`** ( -- ) — go up to the parent; **`CD/`** ( -- ) — go to the root.
- **`(CD)`** ( c-addr u -- ) — the worker (built in); takes a string, e.g. `S" DR1" (CD)`,
  and first primes/mounts the card so the first `CD` after boot takes effect.
  (`CD`/`CD..`/`CD/` live in `toolkit/DIRNAV.FTH`, baked into the TK image.)

## Structures

- **`BEGIN-STRUCTURE`** ( "name" -- addr 0 ) — begin a structure definition. `BEGIN-STRUCTURE POINT`
- **`END-STRUCTURE`** ( addr n -- ) — end it; `name` then pushes the total size.
- **`FIELD:`** ( u1 "name" -- u2 ) — declare a cell-sized field. `FIELD: P.X  FIELD: P.Y`
- **`CFIELD:`** ( u1 "name" -- u2 ) — declare a byte-sized field.
- **`+FIELD`** ( u1 n "name" -- u2 ) — declare a field of n bytes.

## System and environment

- **`ENVIRONMENT?`** ( addr len -- false | i*x true ) — query a system attribute.
- **`BYE`** ( -- ) — leave Forth (ROM build restarts the cold boot).
- **`VER`** ( -- n ) — version number, high byte × 256 + low. `VER .`
- **`X16`** / **`C64`** / **`F256`** ( -- flag ) — build/platform flags (true for the current target).
- **`USR`** ( i*x addr -- j*x ) — call machine code at addr (X16), passing/returning the stack.
- **`RANDOM`** ( -- n ) — a 16-bit pseudo-random number (KERNAL entropy).
- **`RND`** ( u -- n ) — pseudo-random number in `0..u-1` (BASIC-style). `6 RND 1+` → a die roll.
- **`IRQ`** ( xt -- ) — arm a Forth word to run once per 60 Hz frame; `0 IRQ` disarms. Callback must be short and stack-neutral. `' TICK IRQ`

## Game support

Fast primitives for 2D games (work in both PRG and ROM builds).

- **`VSYNC`** ( -- ) — wait for exactly one video frame (1/60 s). On first use it hooks a tiny VERA-VSYNC interrupt handler that bumps a frame counter each frame; `VSYNC` then waits for the next tick, so it is frame-locked (precise 60 Hz) and reliable inside a tight loop. Use it to pace a game loop and to update VRAM tear-free. `BEGIN  move-things  draw-things  VSYNC  AGAIN`
- **`FRAMES`** ( -- n ) — the video frame counter (0..255, wraps), bumped once per frame by the same handler `VSYNC` installs. Take deltas (byte subtraction wraps correctly) for elapsed-frame timing, fixed-timestep catch-up, or spotting dropped frames. `FRAMES  ( … work … )  FRAMES SWAP - 255 AND  ( frames elapsed )`
- **`VFILL`** ( value count -- ) — write the byte `value` to the VERA data port `count` times (16-bit count), in a tight native loop — far faster than a `V!` loop for clearing bitmaps/tilemaps. Set the start address first with `VADDR`. `0 0 VADDR  32 2000 VFILL` (blank 2000 tiles).
- **`*.`** ( n1 n2 -- n3 ) — signed 8.8 fixed-point multiply, `n3 = (n1*n2)>>8`. Lets sprites move at fractional speeds: keep positions in 8.8 (value × 256), add a fixed-point velocity each frame, and use the integer part (`256 /` or `>>8`) as the pixel coordinate. `384 512 *.` → `768` (1.5 × 2.0 = 3.0).
- **`COLLIDE?`** ( ax ay aw ah bx by bw bh -- flag ) — axis-aligned bounding-box overlap of box A (x,y,w,h) and box B; TRUE if they overlap (edge-touching is not overlap). Coordinates are unsigned. `sprite1xy sprite1wh sprite2xy sprite2wh COLLIDE? IF ...hit... THEN`

For higher-level graphics (pixels, lines, shapes, a split screen with a text
window) see the loadable `SPLIT.FTH` library in [Section 3](#section-3).

## X16 video, screen and cursor

VERA is the X16's video chip. `VPOKE`/`VPEEK` do single random accesses; for bulk
access set the address once with `VADDR` then stream with `V!`/`V@`.

- **`VPOKE`** ( bank addr value -- ) — write a byte to VRAM (BASIC `VPOKE bank,addr,value`). `0 $1000 65 VPOKE`
- **`VPEEK`** ( bank addr -- value ) — read a byte from VRAM (BASIC `VPEEK(bank,addr)`).
- **`VADDR`** ( bank addr -- ) — point the VERA data port at VRAM (auto-increment 1). `bank` is the 17th address bit.
- **`V!`** ( byte -- ) — store a byte through the data port (address auto-increments).
- **`V@`** ( -- byte ) — read a byte through the data port (address auto-increments).
- **`V!W`** ( w -- ) — store a 16-bit word through the data port, low byte first.
- **`SCREEN`** ( mode -- ) — set the video mode. 0=80×60, 1=80×30, 2=40×60, 3=40×30, 128=320×240×256. `0 SCREEN`
- **`COLOR`** ( fg bg -- ) — set text foreground/background (0-15). `1 6 COLOR`
- **`BORDER`** ( color -- ) — set the display border color (0-15).
- **`CLS`** ( -- ) — clear the text screen.
- **`LOCATE`** ( row col -- ) — move the text cursor (BASIC `LOCATE row,col`).
- **`CURSOR`** ( -- row col ) — read the cursor position (inverse of `LOCATE`).
- **`POS`** ( -- col ) — current cursor column.
- **`SCROLLX`** ( n -- ) — set layer-1 horizontal hardware scroll (0-4095).
- **`SCROLLY`** ( n -- ) — set layer-1 vertical hardware scroll (0-4095).
- **`TILE`** ( x y code attr -- ) — set a tile cell (BASIC `TILE x,y,code,attr`).
- **`TDATA`** ( x y -- code ) — read a tile's code (BASIC `TDATA(x,y)`).
- **`TATTR`** ( x y -- attr ) — read a tile's attribute (BASIC `TATTR(x,y)`).

## X16 sprites

- **`SPRITES-ON`** ( -- ) — enable the sprite layer.
- **`SPRITES-OFF`** ( -- ) — disable the sprite layer.
- **`SPRITE-IMAGE`** ( graphaddr sprite -- ) — point a sprite's image at VRAM `graphaddr` (4bpp, 32-aligned).
- **`SPRITE-POS`** ( x y sprite -- ) — set a sprite's 12-bit position.
- **`SPRITE-GET`** ( sprite -- x y ) — read a sprite's position (inverse of `SPRITE-POS`).
- **`SPRITE-SIZE`** ( width height sprite -- ) — size codes 0-3 = 8/16/32/64 pixels.
- **`SPRITE-Z`** ( z sprite -- ) — Z-depth 0=off, 1=behind, 2=between, 3=front.
- **`SPRITE-MOV`** ( num x y -- ) — set position (= BASIC `MOVSPR num,x,y`).
- **`SPRITE-MEM`** ( num bank addr -- ) — point a sprite's image at VRAM `bank:addr` (= BASIC `SPRMEM num,bank,addr`).
- **`SPRITE`** ( num zdepth -- ) — set Z-depth and enable the sprite layer (BASIC `SPRITE num,zdepth`).

> To draw/edit sprite images interactively, load the `other/SPREDIT.FTH` utility
> (`INCLUDE SPREDIT.FTH`, then `SPED`) — a 4bpp sprite editor with `SPSET`/`SPGET`
> pixel words, `SPDUMP`, disk save/load, and a live on-screen preview.

## X16 graphics

Bitmap drawing in 320×240×256 mode.

- **`GINIT`** ( -- ) — enter 320×240×256 bitmap graphics mode.
- **`GCLS`** ( -- ) — clear the graphics screen.
- **`PSET`** ( x y color -- ) — set one pixel. `160 120 5 PSET`
- **`LINE`** ( x1 y1 x2 y2 color -- ) — draw a line.
- **`FRAME`** ( x1 y1 x2 y2 color -- ) — rectangle outline.
- **`RECT`** ( x1 y1 x2 y2 color -- ) — filled rectangle. Fills VRAM directly with hardware auto-increment (clipped to the 320×240 screen), so it is far faster than the KERNAL per-pixel fill — good for clearing regions or double-buffered redraws each frame.
- **`RING`** ( x1 y1 x2 y2 color -- ) — ellipse outline (inside the bounding box).
- **`OVAL`** ( x1 y1 x2 y2 color -- ) — filled ellipse.
- **`GTEXT`** ( x y color c-addr u -- ) — draw a string into the bitmap. `10 10 1 S" HI" GTEXT`

## X16 audio

Two synths: the VERA PSG (16 voices, 0-15) and the YM2151 FM chip (8 channels,
0-7). Volumes are 0-63. Play-strings and chord-strings use the ROM's audio API.

- **`PSGINIT`** ( -- ) — reset/initialize all PSG voices.
- **`PSGFREQ`** ( freq voice -- ) — set a voice's raw frequency.
- **`PSGNOTE`** ( note voice -- ) — play a note; `note = octave<<4 | (1..12)`, 0 = release.
- **`PSGVOL`** ( vol voice -- ) — set volume (0-63, both channels).
- **`PSGWAV`** ( waveform voice -- ) — waveform 0-3 (pulse/saw/triangle/noise).
- **`PSGPAN`** ( pan voice -- ) — stereo pan (1=left, 2=right, 3=both).
- **`PSGPLAY`** ( c-addr u voice -- ) — play a play-string on a voice (blocking).
- **`PSGCHORD`** ( c-addr u voice -- ) — play a chord string on a voice (blocking).
- **`YM!`** ( value reg -- ) — write a value to a YM2151 register directly.
- **`FMINIT`** ( -- ) — initialize the YM2151 and load default instrument patches.
- **`FMINST`** ( inst channel -- ) — select an instrument patch (BASIC `FMINST channel,inst`).
- **`FMVOL`** ( vol channel -- ) — set channel volume (0-63).
- **`FMNOTE`** ( note channel -- ) — play a note; `note` = octave (hi nibble) + note 1-12 (lo nibble), 0 = off.
- **`FMFREQ`** ( freq channel -- ) — play a raw frequency in Hz (17-4434).
- **`FMDRUM`** ( drum channel -- ) — play a drum sound (25-87, 0 = none).
- **`FMVIB`** ( speed depth -- ) — set global FM vibrato (0-127).
- **`FMPAN`** ( pan channel -- ) — stereo pan (1=left, 2=right, 3=both).
- **`FMPOKE`** ( value reg -- ) — write a YM2151 register through the API (keeps volume shadows in sync).
- **`FMPLAY`** ( c-addr u channel -- ) — play a play-string on an FM channel (blocking).
- **`FMCHORD`** ( c-addr u channel -- ) — play a chord string on an FM channel (blocking).

> To compose and play tunes interactively, load the `other/SNDEDIT.FTH` utility
> (`INCLUDE SNDEDIT.FTH`, then `SNDED`) — a PSG/FM step-sequencer song editor with
> `NOTE,`/`SG-PLAY` words and disk save/load a game can reuse.

## X16 load and save

`dev` is the device number (usually 8 for the SD card). Names are `( c-addr u )`
strings.

- **`LOAD`** ( c-addr u dev -- ) — load a PRG file to the address in its 2-byte header.
- **`BLOAD`** ( c-addr u dev addr -- ) — load a PRG file, relocating it to `addr`.
- **`VLOAD`** ( c-addr u dev bank vaddr -- ) — load a file into VRAM (BASIC `VLOAD name,dev,bank,addr`).
- **`SAVE`** ( c-addr u dev start end -- ) — save memory `start`..`end` as a PRG file (BASIC `BSAVE`).
- **`BVLOAD`** ( c-addr u dev bank vaddr -- ) — load a headerless file straight into VRAM.
- **`BVERIFY`** ( c-addr u dev addr -- flag ) — verify a headerless file against memory; -1 = match.
- **`VSAVE`** ( c-addr u bank vaddr len -- ) — save `len` bytes of VRAM to a headerless file on device 8 (inverse of `BVLOAD`).
- **`SPRSAVE`** ( c-addr u sprite -- ) — save a sprite's image pixel data to disk.
- **`SPRLOAD`** ( c-addr u sprite -- ) — load pixel data into a sprite's image area.
- **`TILESAVE`** ( c-addr u vaddr len -- ) — save `len` bytes of a bank-1 tileset.
- **`TILELOAD`** ( c-addr u vaddr -- ) — load a tileset into bank-1 VRAM at `vaddr`.
- **`TMAPSAVE`** ( c-addr u -- ) — save the layer-1 tilemap (self-sizing).
- **`TMAPLOAD`** ( c-addr u -- ) — load the layer-1 tilemap back to its VRAM address.

### Turnkey compiled image (fast reload)

Compiling a large `.FTH` library recompiles from source every boot (the cost is
the per-word dictionary search, ~30 s for a few hundred definitions). These two
words snapshot the **compiled** dictionary so it reloads in about a second. They
are generic — they work for any compiled code, not a specific program.

- **`SAVE-IMAGE`** ( c-addr u -- ) — write the current compiled dictionary to
  three files on device 8, named from the base string you give: `<name>.DIC`
  (dictionary bytes), `<name>.TOK` (the user portion of the token table),
  `<name>.VAR` (the dictionary-state pointers: `HERE`, the wordlist heads, the
  high token). Run it once, after loading your library. The base name is capped
  at 16 characters.
- **`LOAD-IMAGE`** ( c-addr u -- flag ) — reload the three files for that base
  name and restore the dictionary, making every saved word available
  immediately. `flag` is `TRUE` if the image loaded, `FALSE` if `<name>.DIC` was
  not found.

```
INCLUDE HP50.FTH   S" HP50" SAVE-IMAGE      \ once: the slow compile, then snapshot
( reboot )
S" HP50" LOAD-IMAGE DROP    HP              \ every boot after: ~1 s, ready to use
```

Notes: the image is tied to the exact interpreter build (it stores absolute
addresses and token numbers) — if you rebuild `forthx16.prg` **or** the bank-9
`forthx16rom.bin`, regenerate the image. Call `LOAD-IMAGE` from the keyboard or
as the **last** line of `AUTORUN.FTH`. Works in both the PRG build and the bank-9
ROM build.

### Bundling several libraries into one image

One image can hold **many** `.FTH` files at once: load them all, then take a
single snapshot. On the next boot `LOAD-IMAGE` brings back every word from every
library in about a second, instead of recompiling each file.

The build is just "include everything, tidy up, save". Do it interactively, or
put it in a temporary `AUTORUN.FTH` and boot once:

```
S" FPX.FTH"      INCLUDED      \ each library, in dependency order
S" BASICSTR.FTH" INCLUDED
S" PCMAUDIO.FTH" INCLUDED
S" ASSEMBLER.FTH" INCLUDED
ONLY FORTH DEFINITIONS         \ reset the search order (see rules)
DECIMAL                        \ reset BASE
S" TK" SAVE-IMAGE              \ -> TK.DIC  TK.TOK  TK.VAR
```

Then the real, permanent `AUTORUN.FTH` is one line:

```
S" TK" LOAD-IMAGE DROP
```

#### Rules for a multi-file image

1. **Everything gets baked in.** The snapshot captures the *whole* compiled
   dictionary at that moment — every word from every file you have `INCLUDED`,
   as one combined image. There is no per-file selection; curate by choosing
   which files to include before saving.
2. **Only Forth-level definitions are saved.** The image is dictionary bytes +
   token table + a few pointers — **not** machine code. Native (assembly) words
   already live in the ROM/PRG; you cannot add new native code through an image,
   and moving built-in words "into an image" does not free ROM.
3. **Load order matters.** Include a library *after* anything it depends on. If
   two files define the same word, the **last one loaded wins** — order them
   deliberately.
4. **Reset the search order before saving.** `SAVE-IMAGE` records the current
   search order, and some libraries change it (e.g. `ASSEMBLER.FTH` adds an
   `ASSEMBLER` wordlist and ends on `ONLY`). If you save while the order is
   non-standard, the restored image boots with a broken vocabulary. End the
   build with **`ONLY FORTH DEFINITIONS`** (and `DECIMAL`, in case a file left
   `HEX`).
5. **All the source files must be on device 8 at build time.** `INCLUDED` reads
   from the SD card (or, in the emulator without `-sdcard`, the host folder).
   The finished `TK.DIC/TK.TOK/TK.VAR` **and** `AUTORUN.FTH` must be there too
   for the fast boot to work. (Once the image exists, the `.FTH` sources are no
   longer needed at boot — the words come from the image.)
6. **Base name ≤ 16 characters;** it produces exactly three files
   `<name>.DIC` / `.TOK` / `.VAR`.
7. **Ship the image files.** A `LOAD-IMAGE` whose `<name>.DIC` is missing returns
   `FALSE`, and a failed file open at boot can disturb the next console/file
   operation — so make sure the three files are present, and keep `LOAD-IMAGE`
   the last meaningful action in `AUTORUN.FTH`.
8. **Rebuild the image whenever you rebuild the interpreter** (new `.prg` or
   `rom.bin`) — token numbers and addresses change, and an old image will not
   match.

## X16 input devices

- **`JOY`** ( n -- buttons ) — read joystick/gamepad n (0 = keyboard, 1-4 = gamepads); button bits active-high, 0 if absent.
- **`MOUSE`** ( mode -- ) — configure the mouse pointer (0 = off, 1 = on, -1 = auto-scale).
- **`MX`** ( -- x ) — mouse X position.
- **`MY`** ( -- y ) — mouse Y position.
- **`MB`** ( -- buttons ) — mouse buttons (bit0 left, bit1 right, bit2 middle).
- **`MWHEEL`** ( -- delta ) — signed mouse-wheel movement since the last read.

## Floating point

TX16 wraps the X16 ROM's floating-point unit. Floats live on a **separate FP
stack** (shown as `( F: … )`), stored as 5-byte values. Put an integer on the FP
stack with `S>F`, print with `F.`. Stack effects below show the FP stack; most
also leave the data stack unchanged.

- **`S>F`** ( n -- ) ( F: -- r ) — convert a signed integer to a float. `5 S>F F.` → `5`
- **`F>S`** ( -- n ) ( F: r -- ) — convert a (non-negative) float to an integer.
- **`>FLOAT`** ( c-addr u -- flag ) ( F: -- r | ) — parse a string to a float; flag true on success. `S" 3.14" >FLOAT`
- **`F@`** ( f-addr -- ) ( F: -- r ) — fetch a 5-byte float from memory.
- **`F!`** ( f-addr -- ) ( F: r -- ) — store the top float to memory.
- **`F+`** ( F: r1 r2 -- r1+r2 ) — add.
- **`F-`** ( F: r1 r2 -- r1-r2 ) — subtract.
- **`F*`** ( F: r1 r2 -- r1*r2 ) — multiply.
- **`F/`** ( F: r1 r2 -- r1/r2 ) — divide.
- **`FSQRT`** ( F: r -- sqrt ) — square root.
- **`FNEGATE`** ( F: r -- -r ) — negate.
- **`FABS`** ( F: r -- |r| ) — absolute value.
- **`FPOW`** ( F: x y -- x^y ) — raise to a power, via `exp(y*ln x)` (needs x > 0). `2 S>F 10 S>F FPOW F.` → `1024`
- **`F**`** ( F: x y -- x^y ) — the standard name for `FPOW`.
- **`FMAX`** ( F: r1 r2 -- r ), **`FMIN`** ( F: r1 r2 -- r ) — larger / smaller of two floats.
- **`F~`** ( F: r1 r2 r3 -- ) ( -- flag ) — approximate compare (`r3>0` absolute, `=0` exact, `<0` relative). *In `toolkit/FPX.FTH` — `INCLUDE FPX.FTH`.*

More Forth-2012 FLOATING/FLOATING-EXT words live in **`toolkit/FPX.FTH`** (`INCLUDE FPX.FTH`), built on the primitives above:
- Constants: **`FPI`** (π), **`FPI2`** (π/2), **`FLN10`** (ln 10).
- Memory/size: **`FLOAT+`** ( a -- a+5 ), **`FLOATS`** ( n -- 5n ), **`FALIGN`**/**`FALIGNED`** (no-ops here).
- Shuffles: **`FROT`** ( r1 r2 r3 -- r2 r3 r1 ), **`FSINCOS`** ( r -- sin cos ).
- Log/exp: **`FLOG`** (log₁₀), **`FALOG`** (10^r), **`FLNP1`** (ln 1+r), **`FEXPM1`** (e^r−1).
- Hyperbolic: **`FSINH`**, **`FCOSH`**, **`FTANH`**.
- Inverse trig: **`FASIN`**, **`FACOS`** (undefined at |r|=1), **`FATAN2`** ( y x -- angle ) full-quadrant.
- **`FDROP`** ( F: r -- ) — drop the top float.
- **`FDUP`** ( F: r -- r r ) — duplicate.
- **`FSWAP`** ( F: r1 r2 -- r2 r1 ) — swap.
- **`FOVER`** ( F: r1 r2 -- r1 r2 r1 ) — copy the second float.
- **`F.`** ( F: r -- ) — print the top float and a space. `2 S>F FSQRT F.` → `1.41421356`
- **`FSIN`** ( F: r -- sin ), **`FCOS`** ( F: r -- cos ), **`FTAN`** ( F: r -- tan ) — trig (radians).
- **`FATAN`** ( F: r -- atan ) — arctangent.
- **`FLN`** ( F: r -- ln ) — natural logarithm.
- **`FEXP`** ( F: r -- e^r ) — exponential.
- **`F0=`** ( F: r -- ) ( -- flag ) — true if r = 0.
- **`F0<`** ( F: r -- ) ( -- flag ) — true if r < 0.
- **`F<`** ( F: r1 r2 -- ) ( -- flag ) — true if r1 < r2.
- **`ISQRT`** ( u -- m ) — integer floor square root of an unsigned value, native (no floating point, so it does not disturb the FP stack and is fast enough to call per scanline). `144 ISQRT .` → `12`

## BASIC-alias and string toolkit

Convenience words baked into the build that mirror X16 BASIC. The math ones share
the corresponding FP word's body under a BASIC name.

- **`OPEN`** ( c-addr u fam -- fileid ior ) — open a file (like `OPEN-FILE`).
- **`CLOSE`** ( fileid -- ior ) — close a file.
- **`LINPUT`** ( c-addr +n -- +n2 ) — read a line from the keyboard into a buffer.
The BASIC math names below are **not** in the core — they only duplicated the
`F*` words, so they were moved to `toolkit/BASICMATH.FTH` to save ROM space. Load
them with `INCLUDE BASICMATH.FTH` (or just use `FSQRT`/`FSIN`/… directly):

- **`SQR`** ( F: r -- sqrt ) — square root (BASIC name for `FSQRT`).
- **`SIN`** ( F: r -- sin ), **`COS`** ( F: r -- cos ), **`TAN`** ( F: r -- tan ) — trig (= `FSIN`/`FCOS`/`FTAN`).
- **`ATN`** ( F: r -- atan ) — arctangent (= `FATAN`).
- **`LOG`** ( F: r -- ln ) — natural logarithm (= `FLN`).
- **`EXP`** ( F: r -- e^r ) — exponential (= `FEXP`).

The BASIC **string / number-conversion** words below were also moved out of the
core (to make room for `CD`/`DIR`) into `toolkit/BASICSTR.FTH` — they are plain
Forth over `<# #S #>`, `>NUMBER`, `/STRING`, `FILL`, `MIN`. Load them with
`INCLUDE BASICSTR.FTH`:

These carry no trailing `$` (unlike BASIC) so the names are valid Forth; `NHEX`/`NBIN`
use an `N` prefix because `HEX` and `BIN` are core words (`HEX` sets BASE=16, `BIN` is the file mode).

- **`NHEX`** ( u -- c-addr u ) — number as hexadecimal digits. `255 NHEX TYPE` → `FF`
- **`NBIN`** ( u -- c-addr u ) — number as binary digits. `5 NBIN TYPE` → `101`
- **`STR`** ( n -- c-addr u ) — signed number as a string (current base). `-12 STR TYPE` → `-12`
- **`VAL`** ( c-addr u -- n ) — string to number (current base). `S" 42" VAL .` → `42`
- **`ASC`** ( c-addr u -- code ) — code of the first character.
- **`CHR`** ( code -- c-addr 1 ) — one-character string (in PAD). `65 CHR TYPE` → `A`
- **`LEN`** ( c-addr u -- u ) — string length (returns the count).
- **`LEFT`** ( c-addr u n -- c-addr n2 ) — first n characters.
- **`RIGHT`** ( c-addr u n -- c-addr2 n2 ) — last n characters.
- **`MID`** ( c-addr u start len -- c-addr2 len2 ) — substring; `start` is 1-based. `S" HELLO" 2 3 MID TYPE` → `ELL`
- **`RPT`** ( char n -- c-addr u ) — a character repeated n times (in PAD). `[CHAR] * 5 RPT TYPE` → `*****`
- **`FVARIABLE`** ( "name" -- ) — create a float variable (5 bytes); read/write with `F@`/`F!`.
- **`FCONSTANT`** ( "name" -- ) ( F: r -- ) — create a word that pushes the float r. `3 S>F FCONSTANT THREE`

## Bit and byte toolkit

- **`SPLIT`** ( n -- bh bl ) — split a cell into its high and low bytes. `$1234 SPLIT` → `$12 $34`
- **`CATNIB`** ( nh nl -- byte ) — combine two nibbles: `(nh<<4) | nl`. `$A $5 CATNIB` → `$A5`
- **`SBIT`** ( addr mask -- ) — set the masked bits of the byte at addr.
- **`CBIT`** ( addr mask -- ) — clear the masked bits of the byte at addr.
- **`FBIT`** ( flag addr mask -- ) — set the masked bits if flag is true, else clear them.

## X16 system control

- **`EDIT`** ( c-addr u -- ) — open the named file in the built-in X16 text editor
  (`u`=0 for a new buffer); edit, save (Ctrl-S), quit (Ctrl-Q), then
  `INCLUDE` the file to compile it. **Known limitation:** the first keyboard line
  right after quitting `EDIT` is still glitched (a swallowed RETURN — takes
  several presses). This is now `EDIT`-specific: x16edit leaves more KERNAL state
  off than a plain file read, so the console-reader reset that fixed `INCLUDED`
  doesn't fully cover it. Workaround: after `EDIT`, reset Forth (relaunch /
  cold start), then `INCLUDE` the file. (Plain `INCLUDED` on its own is fine.)
- **`SETBANK`** ( bank -- ) — select the RAM bank visible at `$A000-$BFFF`.
- **`B@`** ( bank off -- byte ) — read a byte from banked RAM (`off` = 0..8191 into `$A000`).
- **`B!`** ( byte bank off -- ) — store a byte into banked RAM.
- **`SLEEP`** ( jiffies -- ) — wait `jiffies` 1/60-second ticks. `60 SLEEP` waits ~1 s.
- **`MS`** ( u -- ) — wait ~`u` milliseconds (calibrated 8 MHz busy loop; approximate but ≥ `u` ms). `1000 MS` ≈ 1 s.
- **`REBOOT`** ( -- ) — soft reboot through the reset vector.
- **`KEYMAP`** ( c-addr u -- ) — set the keyboard layout by name. `S" en-us" KEYMAP`

## X16 extended access (clock, palette, PCM, layers, VERA FX, KERNAL)

Native words closing the last gaps to the reference guide. All work in both the
PRG and the ROM-bank build.

Clock (battery RTC / system clock):
- **`TICKS`** ( -- ud ) — the 24-bit jiffy counter (1/60 s) as an unsigned double. `TICKS UD.`
- **`TIME@`** ( -- hour min sec ) — read the wall-clock time.
- **`DATE@`** ( -- year month day ) — read the date (`year` is the full 4-digit year).
- **`SETTIME`** ( year month day hour min sec -- ) — set the clock. `2025 7 3 14 30 45 SETTIME`

Palette:
- **`PAL!`** ( rgb index -- ) — set palette entry `index` (0-255) to a 12-bit `$RGB` colour. `$0F00 1 PAL!` (entry 1 = red).

PCM audio (VERA FIFO). The one-shot register words live in `toolkit/PCMAUDIO.FTH`
(`INCLUDE PCMAUDIO.FTH`); only the streaming `PCM-WRITE` is built in:
- **`PCMCTRL`** ( n -- ) — *(toolkit)* write AUDIO_CTRL: volume 0-15, bit4 stereo, bit5 16-bit, bit7 (write) resets the FIFO.
- **`PCMRATE`** ( n -- ) — *(toolkit)* sample rate (0 = stop … 128 = 48 kHz).
- **`PCM!`** ( byte -- ) — *(toolkit)* push one sample byte into the FIFO (ignored when full).
- **`PCMFULL?`** ( -- flag ) — *(toolkit)* true when the FIFO cannot accept more data.
- **`PCM-WRITE`** ( addr count -- ) — blast `count` bytes from RAM into the FIFO (for priming an empty ≤4 KB FIFO; does not throttle). Native.

VERA layers:
- **`LAYER-ON`** / **`LAYER-OFF`** ( layer -- ) — enable/disable display layer 0 or 1.
- **`MAPBASE`** ( layer bank addr -- ) — set a layer's tile-map base (VRAM `bank:addr`, 512-byte aligned).
- **`TILEBASE`** ( layer bank addr -- ) — set a layer's tile-data base (2 KB aligned; preserves tile size bits).
- **`LAYER-MODE`** ( layer cfg -- ) — write a layer's config byte (map size, T256C, bitmap mode, colour depth).

VERA FX:
- **`DCSEL`** ( n -- ) — select the DCSEL register bank (0-63) so FX registers at `$9F29-$9F2C` can be reached with `C!`/`C@`.
- **`FX-MULT`** ( a b -- lo hi ) — signed 16×16→32-bit product via VERA's hardware multiplier; result is `( low-cell high-cell )`. `1000 1000 FX-MULT SWAP . .` → `16960 15` (= 1,000,000).

KERNAL bridge:
- **`SYSCALL`** ( a x y addr -- a' x' y' ) — call the routine at `addr` in KERNAL bank 0 with `.A/.X/.Y` loaded, returning the callee's `.A/.X/.Y`. Reaches the whole KERNAL API (`GRAPH_*`, `console_*`, `MEMTOP`, …). `65 0 0 $FFD2 SYSCALL` prints "A" (CHROUT).
- **`CHARSET`** ( n -- ) — activate a built-in 8×8 charset (1 = ISO, 2 = PET upper/graphics, 3 = PET upper/lower, … 12 = Katakana; see Appendix I of the reference guide).

Keyboard:
- **`KEY?`** ( -- flag ) — true if a key is waiting (non-destructive queue peek).
- **`GETKEY`** ( -- char ) — block until a key is pressed, then return its PETSCII code.

---

<a id="section-3"></a>
# Section 3 — Split-screen & bitmap graphics (SPLIT.FTH)

`other/SPLIT.FTH` is an optional, loadable library (not built into the ROM). It
gives you a **320×240 256-colour bitmap** to draw on, and — its headline feature —
a **split screen**: graphics on top with a scrolling **text console window** at the
bottom, at the same time, with no raster interrupt.

It works because the X16's VERA video chip composites two independent layers: the
library puts the bitmap on **layer 0** and keeps the KERNAL text console on
**layer 1** on top of it. The same drawing words also work in ordinary full-screen
graphics mode (after `GINIT`), because both use the identical bitmap at VRAM
`$0000`.

```
INCLUDE SPLIT.FTH      \ (or:  S" SPLIT.FTH" INCLUDED )
SPLIT-DEMO             \ a demonstration
SPLITOFF               \ return to the normal text screen
```

## 3.1 Turning the split on and off

- **`SPLITON`** ( -- ) — enter the split: a 320×240 bitmap fills the screen with a
  text window at the bottom. While active the console is 40×30 and confined to the
  bottom rows; typing and scrolling stay inside that window and never disturb the
  graphics above.
- **`SPLITOFF`** ( -- ) — leave the split and return to the normal 80×60 text
  screen.
- **`SPLIT-ROWS`** ( -- n ) — a `VALUE` holding the text-window height (default 6).
  Change it *before* `SPLITON`: `8 TO SPLIT-ROWS`.

Text in the window uses the ordinary words — `LOCATE ( row col )`, `EMIT`, `TYPE`,
`."` — with window rows numbered `0 .. SPLIT-ROWS-1`.

You do **not** need the split to draw: after `GINIT` (full-screen graphics) the
same drawing words below work on the whole screen.

## 3.2 Colours and coordinates

The bitmap is 320 wide (x = 0..319) by 240 high (y = 0..239). Colours are palette
indices **0..255**; the first 16 are the usual C64 colours. **Colour 0 is
transparent**, so on a split screen the graphics show through wherever the text
layer (or a colour-0 pixel) is clear.

## 3.3 Drawing words (colour given per call)

Same names and signatures as the built-in KERNAL graphics words, which they
replace so they work in the split as well as full-screen.

| Word | Stack | Purpose |
|---|---|---|
| **`GCLS`** | ( -- ) | clear the whole bitmap (to colour 0) |
| **`PSET`** | ( x y color -- ) | plot one pixel |
| **`LINE`** | ( x1 y1 x2 y2 color -- ) | line between two points |
| **`FRAME`** | ( x1 y1 x2 y2 color -- ) | rectangle outline |
| **`RECT`** | ( x1 y1 x2 y2 color -- ) | filled rectangle |
| **`RING`** | ( x1 y1 x2 y2 color -- ) | ellipse outline (in the bounding box) |
| **`OVAL`** | ( x1 y1 x2 y2 color -- ) | filled ellipse |
| **`CIRCLE`** | ( x y r color -- ) | circle outline (centre x,y radius r) |
| **`FCIRCLE`** | ( x y r color -- ) | filled circle |
| **`GTEXT`** | ( x y color c-addr u -- ) | draw a string into the bitmap |

Two-corner shapes accept their corners in any order.

```
GCLS
10 10 300 150 3 FRAME
20 20 150 100 2 RECT
230 80 55 6 CIRCLE
230 80 25 5 FCIRCLE
10 160 300 160 7 LINE
40 40 1 S" HELLO" GTEXT
```

## 3.4 Pen API (set the colour once)

Call `GCOLOR` to set a persistent pen colour, then use the colour-less words.

| Word | Stack | Purpose |
|---|---|---|
| **`GCOLOR`** | ( n -- ) | set the pen colour (default 1 = white) |
| **`PLOT`** | ( x y -- ) | pixel |
| **`DRAW`** | ( x1 y1 x2 y2 -- ) | line |
| **`BOX`** | ( x1 y1 x2 y2 -- ) | rectangle outline |
| **`FBOX`** | ( x1 y1 x2 y2 -- ) | filled rectangle |
| **`ELL`** | ( x1 y1 x2 y2 -- ) | ellipse outline |
| **`FELL`** | ( x1 y1 x2 y2 -- ) | filled ellipse |
| **`CIRC`** | ( x y r -- ) | circle outline |
| **`DISC`** | ( x y r -- ) | filled circle |
| **`SAY`** | ( x y c-addr u -- ) | text |

```
2 GCOLOR  20 20 150 100 FBOX
1 GCOLOR  20 20 150 100 BOX
6 GCOLOR  245 70 55 DISC
3 GCOLOR  30 45 S" PEN API" SAY
```

## 3.5 Low-level helpers

The words above are built on these direct-to-VERA primitives, which you can also
use: **`BPSET`** ( x y color -- ), **`BHLINE`** ( x y len color -- ),
**`BVLINE`** ( x y len color -- ), **`BLINE`** ( x1 y1 x2 y2 color -- ),
**`BFILL`** ( x y w h color -- ), **`BRECT`** ( x y w h color -- ),
**`BCLS`** ( color -- ). (`BFILL`/`BRECT` take a corner plus width/height rather
than two corners.)

## 3.6 A worked example: a gauge with a live readout

```
: GAUGE ( percent -- )
   SPLITON  GCLS
   5 GCOLOR   0 0 319 191 BOX               \ frame the graphics area
   2 GCOLOR   10 20 300 60 FBOX             \ bar background (track)
   6 GCOLOR   DUP 3 * 10 + >R  10 20 R> 60 FBOX   \ filled part: x2 = 10 + percent*3
   1 0 COLOR
   0 0 LOCATE ." Level: " DUP . ." %" DROP ;
75 GAUGE
```

## 3.7 Notes and limits

- **Resolution while split:** VERA's scale is global, so both layers share one
  resolution; `SPLITON` uses `SCREEN 3` (40×30 text ⇒ 320×240), which is why the
  console is 40 columns while the split is active. `SPLITOFF` restores 80×60.
- **Filled shapes are fast.** Every fill (`RECT`/`FBOX`, and `OVAL`/`FELL`/
  `FCIRCLE`/`DISC`) draws each row with the native `VFILL` (a tight VERA
  auto-increment loop) instead of a per-pixel `V!` loop, and the ellipse/circle
  half-width uses the native integer `ISQRT` — no floating point per scanline. So
  large filled circles/ellipses are roughly an order of magnitude faster than
  before and fine for animation.
- **`RING`/`CIRCLE`** (outlines only) still use the floating-point unit for the
  point sweep and therefore disturb the FP stack.
- **`GTEXT`/`SAY`** render the 8×8 ROM font and assume the mixed-case character set
  (the state after `14 EMIT`, which the test/boot scripts set).
- The library **redefines** `PSET LINE FRAME RECT RING OVAL GTEXT GCLS`; the
  original ROM versions only worked in full-screen graphics mode 128.


<a name="section-4"></a>

---

# Section 4 — Mortgage calculator (MORTGAGE.FTH)

`other/MORTGAGE.FTH` is an optional, loadable library (not built into the ROM). It
computes the monthly payment for a fixed-rate mortgage and prints a full
capital/interest **amortization grid**, using the **Canadian** interest rule.

```
INCLUDE MORTGAGE.FTH        \ (or:  S" MORTGAGE.FTH" INCLUDED )
300000. 25 550  MTG         \ $300,000 loan, 25-year amortization, 5.50%
SCHEDULE                    \ then: the full month-by-month table
```

It needs the [floating-point words](#floating-point) (built into TX16), so no other
library is required.

## 4.1 The Canadian rule

In Canada, fixed-rate mortgages are **compounded semi-annually** (twice a year), not
monthly like a typical US loan — this is set by the *Interest Act* and is the main
thing that makes a "Canadian" mortgage different. The effective monthly rate is
therefore derived from a half-yearly rate:

```
    i = (1 + j/2) ^ (1/6) - 1          j = nominal annual rate, as a fraction
```

(the `1/6` because two compoundings a year spread over twelve months is `2/12`).
The level monthly payment for a loan `L` amortized over `n` monthly payments is the
standard annuity formula:

```
    M = L * i / (1 - (1+i)^-n)
```

## 4.2 Entering a loan

**`MTG`** ( d.principal years rate-bp -- ) — compute the loan, then print the
summary and a one-line-per-year grid.

Two input conventions matter:

- **The principal has a trailing dot** — `300000.` — which makes it a 32-bit
  *double*, so it can exceed 65535. Plain `300000` would overflow a 16-bit cell.
- **The rate is in hundredths of a percent** (basis points of a percent):
  `550` = 5.50%, `1025` = 10.25%, `10000` = 100%.

```
100000. 20 625  MTG         \ $100,000, 20 years, 6.25%
```

## 4.3 Reports

| Word | Stack | Purpose |
|---|---|---|
| **`MTG`** | ( d.principal years rate-bp -- ) | set the loan, then show `SUMMARY` + `YEARLY` |
| **`SUMMARY`** | ( -- ) | loan amount, rate, term, monthly payment, totals |
| **`YEARLY`** | ( -- ) | one aggregated row per year: principal, interest, year-end balance |
| **`SCHEDULE`** | ( -- ) | the full monthly grid: payment, principal, interest, balance |

`SUMMARY` / `YEARLY` / `SCHEDULE` all reuse the last loan set by `MTG` (or by
`SET-LOAN`), so you can run them in any order after `MTG`.

Example `SUMMARY` + `SCHEDULE` for `100000. 1 550 MTG`:

```
=== CANADIAN MORTGAGE (SEMI-ANNUAL COMPOUNDING) ===
LOAN AMOUNT:       $100000.00
ANNUAL RATE:        5.50%
AMORTIZATION:       1 YR  (12 PAYMENTS)
MONTHLY PAYMENT:   $8580.83
TOTAL OF PAYMENTS: $102970.01
TOTAL INTEREST:    $2970.01

 PMT      PAYMENT    PRINCIPAL     INTEREST      BALANCE
   1      8580.83      8127.67       453.17     91872.33
   2      8580.83      8164.50       416.34     83707.84
   ...
  12      8580.84      8542.13        38.71         0.00
```

The final payment is adjusted by a cent so the balance lands exactly on `0.00`.

## 4.4 Under the hood (a floating-point / currency example)

`MORTGAGE.FTH` is a compact example of two things that are easy to get wrong on a
16-bit Forth, and are worth copying for your own programs:

- **Power function.** There is no `F**`, so it builds one from logs:
  `: FPOW ( f: x y -- x^y )  FSWAP FLN F* FEXP ;` — because `x^y = e^(y·ln x)`.
- **Money to the cent, past 16 bits.** `F>S` tops out at 65535, but a payment in
  cents (e.g. `$2000.00` = 200000 cents) is larger. So amounts are converted to a
  32-bit **double** and printed with **pictured numeric output**:
  `: (.$) ( ud -- c-addr u )  <# # # [CHAR] . HOLD #S #> ;` places the two cent
  digits, then the decimal point, then the dollars.
- **Double → float.** The principal comes in as a double; `D>F` converts it using a
  *logical* `RSHIFT`/`AND` split so the low 16-bit word is treated as unsigned
  (a plain `S>F` would read a low word ≥ 32768 as negative).

Everything is ordinary Forth — no new native/primitive words were needed.

## 4.5 Notes and limits

- **Charset.** The report text is uppercase, to read correctly in the X16's default
  uppercase/graphics character set (see [1.10](#110-using-the-system-on-the-x16)).
  If you have switched to the mixed-case set with `14 EMIT`, PETSCII inverts the
  letter case, so run the calculator from a fresh screen (or `142 EMIT` first).
- **Precision.** The BASIC ROM floats carry ~9 significant digits; over a long
  amortization the running balance can drift by a cent or two. `SCHEDULE` corrects
  the last payment so it ends on exactly `0.00`; `YEARLY` clamps a tiny residual to
  `0.00`.
- These are Forth definitions loaded into RAM, so they cost no ROM space.


<a name="section-5"></a>

---

# Section 5 — RPN calculator (HP50.FTH)

`other/HP50.FTH` is an optional, loadable library: an **HP-50g-style RPN
scientific calculator**. It shows off the floating-point word set, a typed value
stack, and a small interpreter written in Forth. It is not the real 50g (no CAS
/ symbolic algebra; reals carry ~9 significant digits), but it behaves like an
RPN scientific/programmer calculator.

```
INCLUDE HP50.FTH   S" HP50" SAVE-IMAGE   \ once (slow compile, then snapshot)
S" HP50" LOAD-IMAGE DROP                 \ every boot after (fast) - or just INCLUDE HP50.FTH
HP                                       \ start the calculator
```

At the `>` prompt you enter numbers and commands RPN-style — numbers push onto a
stack, commands act on it:

```
3 4 + 5 *        ( -> 35 )
2 10 ^           ( -> 1024 )
45 SIN           ( sine of 45 degrees )
255 15 AND       ( -> 15 )
```

Type `OFF` to leave. Use the X16's default uppercase character set (do not
`14 EMIT` first — see [1.10](#110-using-the-system-on-the-x16)).

## 5.1 The stack display

The screen shows a status line and the numbered stack levels (level 1 = the top,
just above the input line), HP-style:

```
[ DEG   STD   DEPTH 3 ]
 3:                          3.1416
 2:                              42
 1:                          -1.500
> _
```

The status line shows the angle mode (`DEG`/`RAD`), the number format
(`STD`, or `FIX n`), the integer base when it is not decimal (`HEX`/`OCT`/`BIN`),
and the stack depth.

## 5.2 Object types

The stack holds typed objects, entered like this:

| Type | Entry | Example | Displays as |
|---|---|---|---|
| Real | with a `.` or `E` | `3.14`, `-2.5`, `1E3` | `3.14` (STD) or `3.1400` (FIX 4) |
| Integer | plain digits (no `.`) | `42`, `-7`, `1000000` | `42`; in HEX/OCT/BIN with a letter: `FFH` |
| Complex | `(re,im)` | `(3,4)`, `(1.5,-2)` | `(3,4)` |
| List | `[ … ]` | `[ 1 2 3 ]` | `[ 1 2 3 ]` |

Lists use square brackets `[ ]` (the X16 keyboard/charset has no usable `{ }`).
A **vector** is just a list of numbers; a **matrix** is a list of row-lists,
e.g. `[ [ 1 2 ] [ 3 4 ] ]`. Integer `+ - *` stay exact; `/` and the scientific
functions produce a real. Mixing a real and an integer, or a real and a complex,
promotes to the wider type.

## 5.3 Commands

| Group | Words |
|---|---|
| Arithmetic | `+` `-` `*` `/` `NEG` `INV` `SQ` `SQRT` `^` `ABS` |
| Scientific | `SIN` `COS` `TAN` `ASIN` `ACOS` `ATAN` `LN` `EXP` `LOG` `ALOG` `PI` |
| Integer / bitwise | `AND` `OR` `XOR` `NOT` `->I` (to integer) `->R` (to real) |
| Bases | `BIN` `OCT` `DEC` `HEX` |
| Complex | `CONJ` `RE` `IM` `ARG` `R->C` `C->R` (and `ABS` = magnitude) |
| Lists | `SIZE` `GET` (and `+` = concatenate) |
| Vectors | `DOT` `V+` `V-` `NORM` `CROSS` |
| Matrices | `DET` `TRN` (transpose) `M*` (multiply) |
| Variables | `STO` `RCL` `PURGE` `CLVAR` |
| Stack | `DUP` `DROP` `SWAP` `OVER` `ROT` `CLEAR` `DEPTH` |
| Modes | `DEG` `RAD` `STD` `n FIX` |
| Exit | `OFF` |

Trigonometric functions honour the current `DEG`/`RAD` mode. Angle mode, number
format, and base are **persistent** — they stay set until you change them.

## 5.4 Complex numbers

Enter a complex as `(re,im)`. Arithmetic and the type-conversion words work on
them; real/integer operands promote to complex automatically.

| Word | Effect |
|---|---|
| `+ - * / NEG INV SQ` | complex arithmetic |
| `ABS` | magnitude \|z\| (a real) |
| `ARG` | argument/angle (in the current angle mode) |
| `CONJ` | complex conjugate |
| `RE` / `IM` | real / imaginary part (a real) |
| `R->C` | ( re im -- (re,im) ) build from two reals |
| `C->R` | ( (re,im) -- re im ) split into two reals |

```
(1,2) (3,4) *        → (-5,10)
(3,4) ABS            → 5
(0,1) SQ             → (-1,0)     ( i² = -1 )
DEG (0,1) ARG        → 90
```

The scientific functions (`SIN`, `LN`, …) are real-only and reject a complex
argument.

## 5.5 Lists

A list is an ordered collection of any objects, entered between `[` and `]`.

| Word | Stack | Effect |
|---|---|---|
| `[` `…` `]` | ( -- list ) | build a list from the items typed between the brackets |
| `SIZE` | ( list -- n ) | number of elements |
| `GET` | ( list n -- obj ) | the n-th element (1-based) |
| `+` | ( list1 list2 -- list ) | concatenate |

```
[ 1 2 3 ] SIZE               → 3
[ 10 20 30 ] 2 GET           → 20
[ 1 2 ] [ 3 4 5 ] +          → [ 1 2 3 4 5 ]
[ 1 3.5 (2,3) ]              → a list mixing an integer, a real and a complex
```

List memory comes from a small heap that is freed by `CLEAR`; if it fills you get
`LIST FULL` — just `CLEAR`.

## 5.6 Vectors and matrices

A **vector** is a list of numbers; a **matrix** is a list of equal-length row
lists. The same `[ ]` entry is used.

| Word | Stack | Effect |
|---|---|---|
| `DOT` | ( v1 v2 -- s ) | dot product |
| `V+` / `V-` | ( v1 v2 -- v ) | element-wise add / subtract |
| `NORM` | ( v -- s ) | Euclidean length |
| `CROSS` | ( v1 v2 -- v ) | 3-element cross product |
| `DET` | ( m -- s ) | determinant (2×2 or 3×3) |
| `TRN` | ( m -- mᵀ ) | transpose |
| `M*` | ( a b -- a·b ) | matrix multiply (inner dims must match) |

```
[ 1 2 3 ] [ 4 5 6 ] DOT              → 32
[ 3 4 ] NORM                         → 5
[ 1 2 ] [ 3 4 ] V+                   → [ 4 6 ]
[ [ 1 2 3 ] [ 4 5 6 ] ] TRN          → [ [ 1 4 ] [ 2 5 ] [ 3 6 ] ]
[ [ 1 2 3 ] [ 4 5 6 ] [ 7 8 10 ] ] DET   → -3
[ [ 1 2 ] [ 3 4 ] ] [ [ 5 6 ] [ 7 8 ] ] M*   → [ [ 19 22 ] [ 43 50 ] ]
```

Note: `+` concatenates two lists (list semantics); use `V+` to add vectors.
`M*` needs the columns of `A` to equal the rows of `B` (else `BAD ARGUMENT VALUE`).

## 5.7 User variables

Store any object under a name with `STO`, get it back with `RCL`. The name is the
**next word** on the line (no quotes). Variables are **persistent** — unlike the
stack, they survive `CLEAR` (list/matrix values are deep-copied into their own
storage). Typing a bare variable name also recalls it.

| Word | Effect |
|---|---|
| `STO` | ( obj -- ) store level 1 into the named variable: `5 STO A` |
| `RCL` | ( -- obj ) recall the named variable: `RCL A` |
| *bare name* | ( -- obj ) using a variable name recalls it: `A` |
| `PURGE` | delete a variable: `PURGE A` |
| `CLVAR` | delete **all** variables |

```
5 STO A            store 5 in A
A A *              → 25         ( bare names recall )
[ 1 2 3 ] STO V    store a vector
CLEAR  RCL V       → [ 1 2 3 ]  ( survived CLEAR )
```

Up to 16 variables, names up to 8 characters. `CLVAR` also reclaims their storage.

## 5.8 Scripting and testing

- **`RUN"` `…"`** ( -- ) runs a line of calculator input non-interactively, e.g.
  `RUN" CLEAR 3 4 + 5 *"`. This is how the self-test `other/HP50TEST.FTH`
  exercises the calculator (78 checks across reals, integers, bases/bitwise,
  complex, lists, vectors/matrices, user variables and matrix multiply;
  `INCLUDE HP50TEST.FTH` runs them). Keep script lines under ~80 characters — the
  input buffer truncates longer lines.

## 5.9 Fast reload

`HP50.FTH` compiles in ~30 s (compilation is dictionary-search bound). To avoid
that on every boot, snapshot the compiled image once with `SAVE-IMAGE` and
reload it with `LOAD-IMAGE` (~1 s) — see
[Turnkey compiled image](#turnkey-compiled-image-fast-reload) in Section 2. The
shipped `emulator/AUTORUN.FTH` loads the image and even auto-starts `HP`, so the
calculator is on screen about a second after boot.

## 5.10 Notes and limits

- ~9-digit floats: `STD` display may show a trailing rounding artifact
  (e.g. `3.14159` as `3.141590001`).
- Integer arithmetic wraps at 32 bits; `/` promotes to a real.
- `DET` covers 2×2 and 3×3; `M*` works for any conformable sizes.
- No symbolic algebra (CAS) and no user programs — out of scope for this port.


# Section 6 — Inline assembler (ASSEMBLER.FTH)

`toolkit/ASSEMBLER.FTH` is a 6502 assembler (the classic Ragsdale FIG assembler,
adapted to ForthX16) that lets you define words whose body is hand-written
machine code. Reach for it for tight inner loops — memory fills/blits,
checksums, decompressors, collision scans — and for interrupt handlers, where
raw speed matters most.

```
S" ASSEMBLER.FTH" INCLUDED
```

## 6.1 Defining a CODE word

```
CODE name  ( stack effect )
   <6502 instructions>
   NEXT JMP,          \ hand control back to the interpreter
END-CODE
```

- **Opcodes** are written mnemonic-first with a trailing comma: `LDA,` `STA,`
  `INX,` `CLC,` `JSR,` … Structured control words exist too: `IF,` `ELSE,`
  `THEN,` `BEGIN,` `UNTIL,` (with condition prefixes `BEQ:` `BNE:` `BCC:`
  `BCS:` `BMI:` `BPL:` `BVC:` `BVS:`, named for the branch you *want taken*).
- **Addressing modes** are set by a word before the opcode:
  `n #` immediate · `addr` absolute/zero-page (default, `MEM`) · `addr ,X` ·
  `addr ,Y` · `addr )Y` indirect-indexed `(zp),Y` · `addr X)` indexed-indirect
  `(zp,X)` · `addr )` indirect · `.A` accumulator.

## 6.2 The register/stack model

- **`DTOP`** — the 16-bit top-of-stack, in zero page. `DTOP LDA,` / `DTOP 1+ LDA,`
  read its low/high byte; store back to change it in place.
- **`POP`** — `JSR POP` drops the top cell and returns it in **A=low, X=high**.
- **`PUSH`** — `JSR PUSH` pushes **A=low, X=high** as a new top cell.
- **`N`** — scratch; bytes `N-1 … N+7` are free for use within one CODE word.
- **`NEXT`** — jump here (`NEXT JMP,`) to return to the Forth interpreter.

The zero page is laid out so this mapping is exact (`DTOP` = data-stack top,
etc.); `VER >BODY` exposes the base and the `NEXT`/`POP`/`PUSH` addresses.

Example — a 16-bit increment with carry:

```
CODE 1+!  ( n -- n+1 )
   DTOP INC,
   BEQ: IF, DTOP 1+ INC, THEN,
   NEXT JMP,
END-CODE
```

## 6.3 Assembly in an interrupt (VSYNC) — the game case

The interrupt is usually the one place a game needs assembly (music tick, sprite
multiplexer, scroll, timers). ForthX16 supplies safe plumbing, so you never
touch `CINV`:

- **`xt IRQ`** — run execution-token `xt` once per interrupt (~60 Hz VSYNC);
  **`0 IRQ`** disarms. The dispatcher saves/restores the whole VM, runs the
  callback on private stacks, and chains to the KERNAL — so the callback may be
  any word. Install a **CODE word** and you have a pure-assembly ISR.
- **`VSYNC`** ( -- ) — block until the next video frame.
- **`FRAMES`** ( -- n ) — free-running 0..255 frame counter; take byte deltas.

```
VARIABLE GTICK
CODE IRQ-TICK ( -- )                 \ callbacks take nothing, keep them short
   GTICK INC,  BEQ: IF, GTICK 1+ INC, THEN,
   NEXT JMP,
END-CODE
['] IRQ-TICK IRQ                     \ arm;  0 IRQ  to stop
```

A callback must have stack effect `( -- )`, stay short, and save/restore any
VERA address ports it uses (the foreground may be mid-transfer).

## 6.4 Learning by example

Three self-checking files in `toolkit/` (load `ASSEMBLER.FTH` first):

- **`ASMTEST.FTH`** — 28 assertions covering every addressing mode, the 16-bit
  ALU idioms, `PUSH`/`POP`, and the control words. Run it after any change.
- **`ASMDEMO.FTH`** — `AFILLB` (memory fill) and `AXOR` (checksum) in assembly,
  each with a correctness check and a speed race against the pure-Forth version
  (`ASMDEMO` runs both; assembly wins by ~80×).
- **`ASMIRQ.FTH`** — an assembly VSYNC interrupt handler (`IRQ-DEMO` shows a
  counter advancing in the interrupt; `IRQ-TEST` self-checks it).

*Generated for ForthX16 / TX16 2.0. See also `readme.md`, `doc/forth-in-rom-scope.md`,
and the self-checking examples in `tests-X16/`.*
