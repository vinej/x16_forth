# ForthX16 — Advanced Guide: Defining Words & Compiling

This guide expands on three sections of the [user guide](userguide.md) that trip
up newcomers: **Defining words**, **Compiling and dictionary**, and **Control
flow**. These words are Forth's *metaprogramming* and structure toolkit — they let
you make new kinds of words, run code at compile time, reshape the dictionary, and
build branches and loops. Once they click, they are what makes Forth feel different
from every other language.

Everything here works on ForthX16 (TX16 2.0). Cells are **2 bytes** (16-bit).
Try the examples at the `OK` prompt as you read.

---

## 1. Foundations you need first

Three ideas underlie everything below. If these are clear, the rest is easy.

### Interpret state vs compile state

Forth is always in one of two modes:

- **Interpret state** (the `OK` prompt): each word you type is **executed now**.
- **Compile state** (inside a `: … ;` definition): each word you type is
  **appended to the definition** instead of run — it will run later, when the new
  word is called.

`:` switches into compile state; `;` switches back. `STATE` holds the current mode
(0 = interpret). The words in this guide mostly exist to *bend* this rule — to run
something at compile time, or to compile something by hand.

```
: SQUARE  DUP * ;      \ DUP and * are COMPILED into SQUARE, not run
5 SQUARE .             \ 25   -- now they run
```

### The dictionary

Every defined word is an entry in the **dictionary** — a linked list growing
upward in memory. `HERE` is the next free address; defining a word advances it.
Because it is just a list, you can also *remove* words (see `MARKER`/`FORGET`).
The newest definition of a name wins, so redefining a word shadows the old one.

### Execution tokens (xt)

An **execution token** is a word's "handle" — a value you can store, pass around,
and later run. You get one with `'` (tick) and run it with `EXECUTE`.

```
' SQUARE        \ pushes the xt of SQUARE
5 ' SQUARE EXECUTE .   \ 25   -- same as  5 SQUARE .
```

`EXECUTE` is the key: it turns "data" (an xt on the stack) back into "action."
This is how deferred words, callbacks (e.g. `IRQ`, `CATCH`), and jump tables work.

| word | what it gives you | where |
|---|---|---|
| `'` name | xt of *name* | interpret **or** compile |
| `[']` name | xt of *name*, **compiled as a literal** | inside `:` only |
| `EXECUTE` ( xt -- ) | run the xt | anywhere |
| `COMPILE,` ( xt -- ) | **append a call** to the xt to the current definition | compile time |

`'` vs `[']`: use `'` when you want the xt **now**; use `[']` when you are inside a
definition and want that word's xt pushed **each time the definition runs**.

```
: RUN-IT  ['] SQUARE EXECUTE ;   \ ['] because we're compiling
5 RUN-IT .                        \ 25
```

---

## 2. Defining words — making new words

### `:` `;` `:NONAME`

`:` starts a named definition, `;` ends it. `:NONAME` starts an **unnamed** one and
leaves its xt on the stack at `;` — handy for building tables of behaviours.

```
: GREET  ." Hello" CR ;      \ named
:NONAME  ." Hi" CR ;  CONSTANT SAY-HI   \ unnamed; keep the xt in a constant
SAY-HI EXECUTE               \ Hi
```

**When:** `:NONAME` is for anonymous callbacks you store in a variable, an array,
or a `DEFER` — when a name would just be clutter.

### `CONSTANT` `2CONSTANT` — name a value

A constant word pushes a fixed value when named. `2CONSTANT` does the same for a
double (2-cell) value.

```
10 CONSTANT TEN        TEN .            \ 10
1000000. 2CONSTANT MILLION   MILLION D. \ 1000000
```

**When:** magic numbers, hardware addresses, sizes — anything fixed you want to
name once. Faster and clearer than a variable you never change.

### `VARIABLE` `2VARIABLE` — named storage

A variable word pushes the **address** of its cell; use `@`/`!` (or `2@`/`2!`) to
read/write.

```
VARIABLE COUNT     0 COUNT !
COUNT @ 1+ COUNT !     COUNT @ .   \ 1
```

**When:** mutable state that changes often. (For a value you set occasionally and
read by name, `VALUE` is nicer — see below.)

### `VALUE` `2VALUE` `TO` — a variable that reads by name

A `VALUE` behaves like a constant when named (pushes its value, no `@` needed) but
you change it with `TO`.

```
5 VALUE SPEED
SPEED .            \ 5      -- no @ needed
7 TO SPEED         SPEED .   \ 7
```

**When:** a setting you read a lot and write rarely. Cleaner than `VARIABLE` +
`@` everywhere. Inside a definition, `TO` still works: `: FASTER  SPEED 1+ TO SPEED ;`.

### `BUFFER:` — a block of bytes

`BUFFER:` makes a word that pushes the address of an *n*-byte uninitialised block.

```
80 BUFFER: LINE        \ LINE pushes the address of 80 bytes
LINE 80 32 FILL        \ blank it with spaces
```

**When:** input line buffers, scratch areas, small tables — when you need raw
bytes, not a cell.

### `CREATE` and `>BODY` — the raw building block

`CREATE name` makes a word whose only behaviour is to **push the address of its own
data field** (the memory right after its header, i.e. `HERE` at creation time). You
then lay down data with `,` (cell), `C,` (byte), or `ALLOT` (raw space).

```
CREATE PRIMES  2 , 3 , 5 , 7 , 11 ,    \ five cells of data
PRIMES @ .           \ 2      (first cell)
PRIMES 2 CELLS + @ . \ 5      (third cell)
```

`>BODY` turns a `CREATE`d word's **xt** back into that data address —
`' PRIMES >BODY` equals what `PRIMES` pushes.

**When:** any custom data structure — arrays, records, lookup tables. But the real
power comes when you attach *behaviour* with `DOES>`.

### `CREATE … DOES>` — the defining-word factory ★

This is the crown jewel of Forth, and the main reason this guide exists.

`CREATE … DOES>` lets you write a word that **defines other words** and gives each
of them shared run-time behaviour. Read it as two halves:

- Code **before `DOES>`** runs when you *define* a word (build its data).
- Code **after `DOES>`** runs when you *use* one of those words, with the word's
  data-field address already on the stack.

The classic example — defining `CONSTANT` yourself:

```
: MY-CONSTANT  ( n "name" -- )  CREATE ,  DOES>  ( -- n )  @ ;
10 MY-CONSTANT TEN
TEN .            \ 10
```

What happened: `10 MY-CONSTANT TEN` ran the *before* part — `CREATE TEN` then `,`
stored 10 into TEN's data field. Later, `TEN` ran the *after* part — it received
TEN's data address and did `@`, pushing 10.

A more useful one — an indexed array:

```
: ARRAY  ( n "name" -- )  CREATE CELLS ALLOT
         DOES>  ( i -- addr )  SWAP CELLS + ;
10 ARRAY SCORES              \ room for 10 cells
99 3 SCORES !                \ store 99 at index 3
3 SCORES @ .                 \ 99
```

Every word made with `ARRAY` shares the same indexing behaviour; only the data
differs. That is the pattern: **`CREATE…DOES>` factors out a family of words.**

**When:** whenever you find yourself writing several words that differ only in
their data — units (`: METERS CREATE , DOES> @ 1000 * ;`), state machines, colour
tables, opcode tables, DSLs. If you're about to copy-paste a definition and change
a number, reach for `CREATE…DOES>`.

---

## 3. Deferred (revectorable) words

A **deferred** word is a named "slot" whose action you can change at run time —
Forth's function pointer / hook.

| word | effect |
|---|---|
| `DEFER name` | create a deferred word (initially unset) |
| `' action IS name` | set *name* to run *action* |
| `ACTION-OF name` | ( -- xt ) the xt *name* currently runs |
| `DEFER@` ( xt1 -- xt2 ) | read a deferred word's action, by xt |
| `DEFER!` ( xt2 xt1 -- ) | set a deferred word's action, by xt |

```
DEFER EMITTER            \ a slot
' EMIT IS EMITTER        \ point it at EMIT
65 EMITTER               \ A     -- behaves like EMIT
:NONAME  DROP [CHAR] * EMIT ;  IS EMITTER   \ re-point it
65 EMITTER               \ *     -- now everything prints as '*'
```

`IS`/`ACTION-OF` are the by-name forms; `DEFER!`/`DEFER@` are the by-xt forms for
when you already hold the deferred word's xt (e.g. in generic code).

**When:** pluggable behaviour — swap an output routine, a comparison function for a
sort, a strategy at run time — without rewriting the callers. Also the clean way to
let a low-level word call something defined *later*.

---

## 4. Immediate words & compile-time control

Normally a word inside a `: … ;` is compiled (deferred). An **immediate** word is
different: it **runs even while you are compiling**. That is how `IF`, `;`, `."`
and friends do their work — they execute at compile time to build the definition.
These tools let you write your own.

### `IMMEDIATE`

Marks the word just defined as immediate, so it executes during compilation.

```
: SAY-NOW  ." (compiling)" ;  IMMEDIATE
: TEST  SAY-NOW  1 2 + ;      \ prints (compiling) WHILE TEST is being compiled
```

### `[` and `]` — drop to interpret mid-definition

`[` leaves compile state (start interpreting) and `]` re-enters it. Use them to
compute a value **once, at compile time**, then bake it in.

### `LITERAL` `2LITERAL` `SLITERAL` — bake a value in

`LITERAL` takes a value that's on the stack *at compile time* and compiles it so it
gets pushed *at run time*. Combined with `[ … ]`:

```
: CIRCUMFERENCE-OF-7  ( -- n )  [ 7 2 * 314 * 100 / ] LITERAL ;
CIRCUMFERENCE-OF-7 .     \ 43   -- the arithmetic ran at compile time, not run time
```

`2LITERAL` does the same for a double; `SLITERAL ( addr len -- )` compiles a string
so `S"`-style text survives into the definition.

**When:** precompute constants, table sizes, or masks so the running word does no
arithmetic. Also the standard way to move an xt or address into a definition.

### `POSTPONE` — compile a word's compile-time behaviour ★

`POSTPONE name` is the modern, reliable way to build new compiling words. It says:
"whatever *name* would do at compile time, do **that** when *this* word compiles."

- For a normal word, `POSTPONE` compiles a call to it.
- For an immediate word, `POSTPONE` compiles it so it runs when *your* word is used
  to compile something.

```
: [MY-IF]  POSTPONE IF ;  IMMEDIATE      \ a synonym for IF
: ABS?  DUP 0< [MY-IF] NEGATE THEN ;
-5 ABS? .        \ 5
```

**When:** writing your own control-flow or DSL words that expand into other words.
`POSTPONE` replaces the fragile legacy pair below.

### `[COMPILE]` and `COMPILE` (legacy)

Older Forths split the job `POSTPONE` now does into two words: `[COMPILE] name`
force-compiles an *immediate* word, and `COMPILE` (a run-time helper) compiled the
*next* word. Both are supported for porting old code, but **prefer `POSTPONE`** in
new code — it handles immediate and non-immediate words uniformly.

---

## 5. Managing the dictionary

### `MARKER` `FORGET` — roll back definitions

`MARKER name` creates a word that, when run, **forgets everything defined after the
marker** (including the marker itself), reclaiming the memory. `FORGET name`
removes *name* and everything after it.

```
MARKER -EXPERIMENT
: FOO ." foo" ;   VARIABLE BAR   : BAZ ." baz" ;
-EXPERIMENT       \ FOO, BAR, BAZ (and -EXPERIMENT) are gone; HERE rolls back
```

**When:** interactive development — drop a `MARKER` before loading a file or trying
an idea, run the marker to wipe the slate and reload cleanly. Far better than
redefining words over and over and leaking dictionary space.

### `,"` — compile an inline counted string

`," ccc"` lays a counted string directly into the dictionary at compile time
(length byte + characters). Usually paired with `CREATE`:

```
CREATE TITLE  ," ForthX16"
TITLE COUNT TYPE      \ ForthX16   ( COUNT turns a counted string into addr+len )
```

**When:** storing fixed strings (labels, messages, filenames) as part of a data
structure.

### `?COMP` `?STACK` — sanity checks

- `?COMP` aborts unless you are currently compiling. Put it at the top of an
  immediate word that only makes sense inside a definition, so misuse fails loudly
  instead of corrupting things.
- `?STACK` checks the data stack for under/overflow. Handy sprinkled into
  interactive sessions or long definitions while debugging.

```
: ONLY-IN-DEFS  ?COMP  POSTPONE DROP ;  IMMEDIATE
ONLY-IN-DEFS     \ error: used outside a definition
```

---

## 6. Control flow

All the words here are **IMMEDIATE and compile-only** — they run at *compile time*
to weave branches and loops into your definition, so they only work inside
`: … ;` (use them at the `OK` prompt and you get `?COMP`). Two rules to keep in
mind at *run time*:

- **Truth is a number:** `0` is false, any non-zero is true (the canonical true is
  `-1`, i.e. all bits set). Comparison words like `<` `=` `0=` leave such a flag.
- The stack effects shown are what happens **when the finished word runs**, not
  when it compiles.

### Conditionals — `IF` `ELSE` `THEN`

`IF` consumes a flag; if true it runs up to `ELSE` (or `THEN`), otherwise it jumps
to after `ELSE`. `THEN` marks the join point (it does *not* mean "then" as in other
languages — read it as "endif").

```
: CLASSIFY ( n -- )
   DUP 0< IF   ." negative"
   ELSE  0> IF ." positive"
         ELSE ." zero"
         THEN
   THEN ;
-3 CLASSIFY      \ negative
```

**When:** any decision. Nest freely, but each `IF` needs its own `THEN`.

### Multi-way — `CASE` `OF` `ENDOF` `ENDCASE`

A readable alternative to a stack of `IF`s when you're testing one value against
several constants. `ENDCASE` drops the value being tested.

```
: DAY ( n -- )
   CASE
     1 OF ." Mon" ENDOF
     2 OF ." Tue" ENDOF
     ." other"           \ default: the value is still on the stack here
   ENDCASE ;
2 DAY            \ Tue
9 DAY            \ other
```

**When:** dispatch on a small set of known values (menu keys, opcodes, states).

### Indefinite loops — `BEGIN … UNTIL` / `AGAIN` / `WHILE … REPEAT`

Loops with no fixed count.

- **`BEGIN … UNTIL`** — test at the **bottom**; `UNTIL` loops back while the flag is
  false, exits when true (runs at least once).
- **`BEGIN … AGAIN`** — loop **forever**; leave with `EXIT` or `LEAVE` inside.
- **`BEGIN … WHILE … REPEAT`** — test in the **middle**; `WHILE` exits the loop
  (to after `REPEAT`) when its flag is false.

```
: COUNTDOWN ( n -- )  BEGIN DUP . 1- DUP 0= UNTIL DROP ;
5 COUNTDOWN                 \ 5 4 3 2 1

: STARS ( n -- )  BEGIN DUP 0> WHILE [CHAR] * EMIT 1- REPEAT DROP ;
5 STARS                     \ *****
```

**When:** you loop until a condition rather than a fixed number of times (reading
until EOF, polling, draining a stack). Use `WHILE…REPEAT` when the test belongs at
the top (may run zero times); `UNTIL` when it belongs at the bottom (runs ≥ once).

### Counted loops — `DO` `?DO` `LOOP` `+LOOP` (and `I` `J` `LEAVE` `UNLOOP`)

`limit start DO … LOOP` counts `start` up to but **not including** `limit`.
`I` is the current index, `J` the index of the next loop out. `+LOOP` steps by a
value you give (may be negative). `?DO` skips the whole loop when `limit = start`
(plain `DO` would wrap around and run ~65536 times — a classic bug).

```
: TENS   10 0 DO I . LOOP ;          \ 0 1 2 3 4 5 6 7 8 9
: EVENS  10 0 DO I .  2 +LOOP ;      \ 0 2 4 6 8
: DOWN   0 10 DO I . -1 +LOOP ;      \ 10 9 8 ... 0
: GRID   3 0 DO 3 0 DO J . I . SPACE LOOP LOOP ;   \ 00 01 02 10 11 ...
```

- **`LEAVE`** exits the innermost loop immediately.
- **`UNLOOP`** discards the loop's control values; use it **before `EXIT`** when you
  want to leave the *whole word* from inside a loop.

```
: FIND5 ( -- )  10 0 DO I 5 = IF ." got 5" LEAVE THEN LOOP ;
: FIRST-BIG ( -- n )  100 0 DO I DUP 50 > IF UNLOOP EXIT THEN DROP LOOP -1 ;
```

**When:** you know the range up front. Prefer **`?DO`** whenever the count could be
zero. `I`/`J` are listed under *Return stack and loop index* in the user guide,
because that's where the loop index actually lives.

### Early return & recursion — `EXIT` `RECURSE` `AHEAD`

- **`EXIT`** returns from the current word immediately (like an early `return`).
- **`RECURSE`** calls the definition *currently being compiled*. You need it because
  a word's own name isn't findable until `;`, so you can't call yourself by name.
- **`AHEAD`** compiles an unconditional forward branch closed by `THEN` — a
  low-level building block for custom control structures; rarely used directly.

```
: CHECK ( n -- )  DUP 0= IF ." zero" DROP EXIT THEN  . ;
0 CHECK          \ zero
7 CHECK          \ 7

: FACT ( n -- n! )  DUP 1 > IF DUP 1- RECURSE * THEN ;
5 FACT .         \ 120
```

**When:** `EXIT` to bail out of a word early (guard clauses); `RECURSE` for
recursive algorithms (factorial, tree walks) — but watch the return stack depth.

### Restarting & aborting — `QUIT` `ABORT` `ABORT"`

- **`ABORT`** clears both stacks and returns to the interpreter.
- **`QUIT`** empties the return stack and re-enters the interpreter with no message
  (keeps the data stack).
- **`ABORT" msg"`** ( flag -- ) aborts **and prints `msg`** when the flag is true —
  the everyday way to guard against bad input.

```
: SAFE/  ( a b -- a/b )  DUP 0= ABORT" divide by zero"  / ;
10 2 SAFE/ .     \ 5
10 0 SAFE/       \ divide by zero   (and back to OK, stacks cleared)
```

**When:** `ABORT"` for precondition checks; `ABORT`/`QUIT` to unwind from deep
nesting. For a **recoverable** error (handle it and continue), use `CATCH`/`THROW`.

### Exceptions — `CATCH` `THROW` (and `SP@` `RP@` `HANDLER`)

`CATCH`/`THROW` are the recoverable version of `ABORT`. `CATCH` runs an xt inside a
protected frame: if the xt finishes normally, `CATCH` returns `0`; if anything
under it does `THROW n` (n ≠ 0), execution jumps back to the `CATCH`, which returns
`n` with the stacks restored to their depth at the `CATCH`.

```
: MIGHT-FAIL ( flag -- )  IF 99 THROW THEN  ." ok" ;
TRUE  ' MIGHT-FAIL CATCH .    \ 99      (threw; caught here)
FALSE ' MIGHT-FAIL CATCH .    \ ok 0    (completed; CATCH returned 0)
```

Use `[']` instead of `'` when the `CATCH` is *inside* a definition. `SP@`/`RP@`
(stack-pointer fetches) and `HANDLER` (the current exception-frame variable) are
the primitives `CATCH` is built from — you rarely call them directly.

**When:** an operation that might fail where you want to recover instead of
resetting the whole system — trying to open a file, parsing user input, a plugin
that might misbehave. Pair a `THROW n` deep in the code with a `CATCH` up top.

---

## Quick reference

**Defining words**

| word | stack | one-liner |
|---|---|---|
| `: ;` | `( "name" -- )` | start / end a definition |
| `:NONAME` | `( -- xt )` | unnamed definition, xt at `;` |
| `CONSTANT` / `2CONSTANT` | `( n\|d "name" -- )` | name a (double) value |
| `VARIABLE` / `2VARIABLE` | `( "name" -- )` | named 1-/2-cell storage |
| `VALUE` / `2VALUE` + `TO` | `( n\|d "name" -- )` | value read by name, set with `TO` |
| `BUFFER:` | `( n "name" -- )` | n-byte block |
| `CREATE` | `( "name" -- )` | word pushing its data address |
| `DOES>` | `( -- )` | attach run-time behaviour to `CREATE`d words |
| `DEFER` `IS` `ACTION-OF` `DEFER!` `DEFER@` | — | revectorable words (hooks) |

**Compiling & dictionary**

| word | stack | one-liner |
|---|---|---|
| `'` / `[']` | `( "name" -- xt )` | xt now / xt compiled in a definition |
| `EXECUTE` | `( xt -- )` | run an xt |
| `COMPILE,` | `( xt -- )` | append a call to an xt |
| `[` / `]` | `( -- )` | interpret / compile state |
| `LITERAL` `2LITERAL` `SLITERAL` | `( x -- )` | bake a compile-time value in |
| `POSTPONE` | `( "name" -- )` | compile a word's compile-time behaviour |
| `[COMPILE]` `COMPILE` | `( "name" -- )` | legacy — prefer `POSTPONE` |
| `IMMEDIATE` | `( -- )` | make the last word run at compile time |
| `MARKER` / `FORGET` | `( "name" -- )` | roll back the dictionary |
| `>BODY` | `( xt -- addr )` | data field of a `CREATE`d word |
| `,"` | `( "ccc\"" -- )` | inline counted string |
| `?COMP` / `?STACK` | `( -- )` | compile-state / stack sanity checks |

**Control flow** (all IMMEDIATE / compile-only)

| word(s) | run-time stack | one-liner |
|---|---|---|
| `IF` `ELSE` `THEN` | `( flag -- )` | conditional; `THEN` = endif |
| `CASE` `OF` `ENDOF` `ENDCASE` | `( x -- )` | multi-way branch on a value |
| `BEGIN … UNTIL` | `( flag -- )` | loop until true (test at bottom) |
| `BEGIN … AGAIN` | `( -- )` | loop forever (leave with `EXIT`/`LEAVE`) |
| `BEGIN … WHILE … REPEAT` | `( flag -- )` | loop while true (test in middle) |
| `DO … LOOP` / `?DO` | `( limit start -- )` | counted loop; `?DO` skips if equal |
| `+LOOP` | `( n -- )` | counted loop, step by n |
| `I` `J` | `( -- n )` | index of innermost / next-outer loop |
| `LEAVE` / `UNLOOP` | `( -- )` | exit loop / drop loop control before `EXIT` |
| `EXIT` | `( -- )` | return from the current word |
| `RECURSE` | `( -- )` | call the word being compiled |
| `AHEAD` | `( -- )` | unconditional forward branch (advanced) |
| `ABORT` / `QUIT` | `( -- )` | clear stacks / return stack, re-enter interpreter |
| `ABORT"` | `( flag -- )` | abort + print a message if flag is true |
| `CATCH` | `( i*x xt -- j*x 0 \| i*x n )` | run xt, catching a `THROW` |
| `THROW` | `( n -- )` | unwind to the nearest `CATCH` (0 = no-op) |

---

### Where to go next
- The full per-word list with terse signatures is in
  [userguide.md](userguide.md) (sections *Defining words*, *Compiling and
  dictionary*, and *Control flow*).
- The return stack and loop indices (`>R R> R@ I J …`) are covered in
  *Return stack and loop index* in the user guide.
