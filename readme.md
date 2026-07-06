# ForthX16
## Intro
Development up to version 1.5 was done by Vasyl Tsvirkunov, on his GitHub here: https://github.com/VasylTsv/ForthX16

Version 2.0, on my GitHub at https://github.com/vinej/x16_forth, was developed by Claude Opus 4.8 and Claude Fable. Fable found the last bug that Opus could not resolve. My contribution was to help with testing and debugging — Claude wrote all the code. Version 2.0 has the same features as X16 BASIC 2.0, and all the features of the X16 can be used. I have only tested the new version on the X16 and on a MiSTer core: https://github.com/vinej/x16_mister

I am not the developer in this case, only the analyst/tester who helped Claude implement all the features.

see: /doc/userguide.md for more info on V 2.0

Forth TX16 (or ForthX16) is an enhanced port of the older project [Forth Model T](https://github.com/VasylTsv/ForthModelT) for the [Commander X16](https://www.commanderx16.com/) and other 6502-based platforms. It is a completely functional implementation of the Forth 2012 standard. Unlike Forth Model T, which used a direct-threaded model, Forth TX16 uses a token-threaded model. This was mostly done to minimize size — one of the goals of the project was to fit the entire interpreter on an 8K C64 cartridge.

The other — or rather the main — goal of the project was to create an interpreter as compliant with the Forth 2012 standard as possible.

**New to Forth or this system?** See [doc/userguide.md](doc/userguide.md) for a tutorial and a full reference of every built-in word (with an alphabetical index).
## Supported Platforms
The original target platform was Commander X16. However, in the middle of developmente I've realized that the same code would run on Commodore 64 with reasonable effort. Thus C64 became a second platform. The third platform is quite different and it was added separately - [Foenix F256](https://c256foenix.com). It is also 6502-based (sort of), but not derived from C64, so console and file I/O are very different. More platforms may be coming.
## Prerequisites and Building
The instructions below are for Windows-based systems. It should not be difficult to modify them to other platforms as long as ACME assembler is available there.
[ACME assembler](https://sourceforge.net/projects/acme-crossass/files/win32/) is used to build the interpreter from the source. It is expected to be places in a subfolder ASM in the project folder.
Optionally, platform emulators can be used for testing. Scripts assume [VICE](https://vice-emu.sourceforge.io/) for C64 and the [official X16 emulator](https://cx16forum.com/forum/viewtopic.php?t=8443) for Commander X16. These should be placed in subfolders VICE and X16 correspondingly. [Foenix F256 IDE](https://github.com/Trinity-11/FoenixIDE) can be used to test that platform, but there is no special support for it in the scripts. Just install the IDE and point the "SD card" to the location of the binaries.

* `makeprg.bat` will build PRG compatible with both C64 and X16
* `makecart.bat` will build cartridge image for C64
* `makediskc64.bat` builds a disk image for C64. It can be used on X16, but there is not much point
* `makef256.bat` build PGZ executable for F256

* `testcart.bat` will build and load the cartridge in VICE
* `testdiskc64.bat` tests the disk image in VICE as well
* `testprg.bat` will build and start PRG file in X16 emulator

There are pre-build binaries in the `binary` folder.
## The Language Support

This implementation closely follows the Forth 2012 Standard. The following describes the list
of supported words grouped per the said standard.

### Core words
```
!			#			#>			#S			'			(			*			*/
*/MOD		+			+!			+LOOP		,			-			.			."
/			/MOD		0<			0=			1+			1-			2!			2*
2/			2@			2DROP		2DUP		2OVER		2SWAP		:			;
<			<#			=			>			>BODY		>IN			>NUMBER		>R
?DUP		@			ABORT		ABORT"		ABS			ACCEPT		ALIGN		ALIGNED
ALLOT		AND			BASE		BEGIN		BL			C!			C,			C@
CELL+		CELLS		CHAR		CHAR+		CHARS		CONSTANT	COUNT		CR
CREATE		DECIMAL		DEPTH		DO			DOES>		DROP		DUP			ELSE
EMIT		ENVIRONMENT? EVALUATE	EXECUTE		EXIT		FILL		FIND		FM/MOD
HERE		HOLD		I			IF			IMMEDIATE	INVERT		J			KEY
LEAVE		LITERAL		LOOP		LSHIFT		M*			MAX			MIN			MOD
MOVE		NEGATE		OR			OVER		POSTPONE	QUIT		R>			R@
RECURSE		REPEAT		ROT			RSHIFT		S"			S>D			SIGN		SM/REM
SOURCE		SPACE		SPACES		STATE		SWAP		THEN		TYPE		U.
U<			UM*			UM/MOD		UNLOOP		UNTIL		VARIABLE	WHILE		WORD
XOR			[			[']			[CHAR]		]
```
### Core Extension words
```
.(			.R			0<>			0>			2>R			2R>			2R@			:NONAME
<>			?DO			ACTION-OF	AGAIN		BUFFER:		C"			CASE		COMPILE,
DEFER		DEFER!		DEFER@		ENDCASE		ENDOF		ERASE		FALSE		HEX
HOLDS		IS			MARKER		NIP			OF			PAD			PARSE		PARSE-NAME
PICK		REFILL		RESTORE-INPUT ROLL		S\"			SAVE-INPUT	SOURCE-ID	TO
TRUE		TUCK		U.R			U>			UNUSED		VALUE		WITHIN		[COMPILE]
\
```
All of Core and Core Extension words are supported and perform very close to the Standard.
Note that the cell size for CELL+ and CELLS is 2 bytes as the system is inherently 16-bit.
However, compilation tokens may be just one byte in size. This does not contradict the standard.
The word ENVIRONMENT? is recognized but does nothing. It is rarely used and defined in a very
strange way largely inconsistent with the rest of the language.

There are a few non-standard words supported by this implementation:
* `0` `-1` `1` `2` - self-explanatory
* `PLACE` and `+PLACE` - these are two very useful string manipulation words from [a Standard proposal](https://forth-standard.org/proposals/place-place)
* `?COMP` - check if current mode is compilation, abort otherwise
* `?STACK` - check the data stack for overflow/underflow
* `UD/MOD ( ud1 u1 -- u2 ud2 )` - commonly used word to divide unsigned double `ud1` by unsigned `u1`. 'u2' is remainder and 'ud2' is quotient. Notice that unlike `UM/MOD`, the quotient is a double.
* `VER ( -- d )` - returns the interpreter version number. For 2.0 it will return 0x0200
* `C64` or `F256` (only one present) - platform indentifying words to support platform-specific code

### Block words
Not supported and not planned. This set makes more sense for embedded systems without existing filesystems, so not very useful
for this implementation.

### Double-Number words
```
2CONSTANT	2LITERAL	2VARIABLE	D+			D-			D.			D.R			D0<
D0=			D2*			D2/			D<			D=			D>S			DABS		DMAX
DMIN		DNEGATE		M*/			M+
```
### Double-Number extension words
```
2ROT		2VALUE		DU<
```
All Double-Number and Extension words are completely supported and compliant.

### Exception words
`CATCH` ( i*x xt -- j*x 0 | i*x n ) and `THROW` ( k*x n -- k*x | i*x n ) are
supported: `CATCH` runs an xt and returns 0 or the thrown code with the stacks
restored; `THROW` unwinds to the nearest `CATCH` (0 is a no-op, an uncaught throw
does `ABORT`). Also `SP@ RP@ HANDLER` (the primitives they build on). The
`ABORT`/`ABORT"`-with-codes niceties are not added, but roll-your-own is trivial.

### Facility words
No words from the main Facility set are currently supported.

### Facility extension words
Partial support.
```
+FIELD   BEGIN-STRUCTURE   CFIELD:   END-STRUCTURE   FIELD:
```
Only a small group of Facility words is supported, but those are compliant with the standard.
The rest of the group is considered for possible extension in the future. Most of those words
are quite simple but they would take too much RAM just for names.

### File-Access words
All File-Access words are supported, but not all of them work completely or at all on some platforms. Check platform-specific notes for details
```
( (extended) BIN		CLOSE-FILE	CREATE-FILE	DELETE-FILE	FILE-POSITION FILE-SIZE	INCLUDE-FILE
INCLUDED	OPEN-FILE	R/O			R/W			READ-FILE	READ-LINE	REPOSITION-FILE RESIZE-FILE
S" (extended) SOURCE-ID	W/O			WRITE-FILE	WRITE-LINE
```
### File-Access extension words
```
FILE-STATUS	FLUSH-FILE	INCLUDE		REFILL (extended) RENAME-FILE	REQUIRE		REQUIRED S\" (extended)
```
### Floating-Point words
Not supported in the generic (C64/F256) builds. The **Commander X16 build does
have floating point** - it wraps the ROM's FP package. See the Floating point
subsection under Commander X16 Extensions below.

### Local words
Not supported and not planned. I find this set a very questionable addition to the standard.

### Memory-Allocation
Supported as an extension. Include DYNAMIC.FS and initialize that library for complete support.

### Programming-Tools
```
.S   ?   WORDS
```
### Programming-Tools extension
Small subset is supported.
```
BYE   FORGET
```
The following are not supported:
```
DUMP		SEE

;CODE		AHEAD		ASSEMBLER	CODE		CS-PICK		CS-ROLL		EDITOR		N>R
NAME>COMPILE NAME>INTERPRET	NAME>STRING NR>		STATE (extended)		SYNONYM		TRAVERSE-WORDLIST
[DEFINED]	[ELSE]		[IF]		[THEN]		[UNDEFINED]
```
Some of these are planned for extensions.

### Search-Order
All Search-Order and Extension words are completely supported.
```
DEFINITIONS FIND (extended) FORTH-WORDLIST GET-CURRENT GET-ORDER SEARCH-WORDLIST SET-CURRENT
SET-ORDER WORDLIST
```
### Search-Order extension
```
ALSO   FORTH   ONLY   ORDER   PREVIOUS
```
### String
```
/STRING		BLANK		CMOVE		CMOVE>		COMPARE		SLITERAL
```
Most words with exception for `-TRAILING` and `SEARCH` are supported. None of the three extension words
(`REPLACES` `SUBSTITUTE` `UNESCAPE`) are supported at this time. Support through extension is considered.
### Extended-Character words
Not supported and not planned.

## Assembler
Forth 6502 assembler can be added by either `INCLUDE ASSEMBLER.FTH` or `INCLUDE FORTH/ASSEMBLER.FTH` depending on the system. The assembler implementation is based on W. F. Ragsdale's one from Dr. Dobbs Toolbook of Forth (M&T Publishing, 1986, pg.203-214). It is a very compact implementation and in provides access to practically all 6502 opcodes while staying close to Forth conventions and concepts. Because of the latter, it may look a bit unusual and take a while to pick up, but once you get the idea, it makes sense.

To define a word in assembly a special pair words is used instead of colon and semicolon, correpondingly `CODE` and `END-CODE`. Note that `END-CODE` just completes the definition, but it does not finalize the execution (does not emit any opcodes), so in most cases words should explicitly jump to `NEXT`. An example from the original book:
```
CODE MON BRK, NEXT JMP, END-CODE
```
Note that all opcodes end with comma. This is one of the conventions, and it makes it easier to distinguish opcodes. Instruction parameters precede opcodes.

It is possible to emit opcodes without creating a Forth word as all assembler words are interpreted immediately - there is no strictly compilation stage. The assembler implementation actually contains one example (the `SETUP` routine).

The following opcodes don't have any parameters:
```
BRK, CLC, CLD, CLI, CLV, DEX,
DEY, INX, INY, NOP, PHA, PHP,
PLA, PLP, RTI, RTS, SEC, SED,
SEI, TAX, TAY, TSX, TXS, TXA,
TYA,
```
And these take parameters from the stack:
```
ADC, AND, CMP, EOR, LDA, ORA,
SBC, STA, ASL, DEC, INC, LSR,
ROL, ROR, STX, CPX, CPY, LDX,
LDY, STY, JSR, JMP, BIT,
```
The way it works, the parameter (address or immediate value) goes first (so on the stack), then a modifier for all modes but the memory one follow, and lastly the opcode completes the instruction. These are the modifiers:
```
Modifier   Mode                  Operand
   .A    accumulator           none
    #    immediate             eight bits only
   ,X    indexed X             z-page or absolute
   ,Y    indexed Y             z-page or absolute
   X)    indexed indirect X    z-page only
   )Y    indirect indexed Y    z-page only
    )    indirect absolute     absolute only
 none    memory                z-page or absolute
```
Note that the assembler automatically generates zero page or absolute addresses based on the value on stack.

Here are some examples:
```
.A ROL,          rol     or    rol a
1 # LDY,         ldy #1
DATA ,X STA,     sta data,x
DATA ,Y CMP,     cmp data,y
6 X) ADC,        adc (06,x)
POINT )Y STA,    sta (point),y
VECTOR ) JMP,    jmp (vector)
```
You may have noticed that the lists above don't contain conditional jumps. This is where this assembler goes a bit further Forth way. Instead of the conditional instructions there are control flow words. There are five words that work very similarly to their Forth counterparts, just with machine code:
```
BEGIN, UNTIL, IF, ELSE, THEN,
```
Note the comma at the end of each word. The kind of condition is set by words very similar to regular 6502 opcodes. Logically, they have the same meaning, but the implementation is actually such that the inverse condision opcodes are generated (this may be confusing, but it will make sense as soon as you write the first `IF,`/`THEN,` block). Here are the conditions:
```
BCC: BCS: BEQ: BNE: BMI: BPL: BVC: BVS:
```
A simple example:
```
PORT LDA, BNE: IF KEYPRESSED JMP, THEN,
```
The equivalent in a more conventional assembler is
```
lda port
beq +
jmp keypressed
+ ...
```
Control flows can be nested and there are some checks that will tell you if a flow is malformed.

Worth noting that the original Ragsdale's implementation used different way to specify conditions (like `0=`, `0>`, etc.) I've found collisions with the standard words too confusing and I hope my solution is cleaner.

There are a few more less important items implemented by the assembler. These came from the original implementation and some may not make that much sense anymore (the original implementation was based on Fig-Forth), but the following are defined:

`IP` and `W` - internal Forth registers. Not documenting them here as they are very hard to use and explain without complete understanding how the current implementation of the Forth interpreter works. Given that the Forth T is using token thread code, it is even harder to use it from assembly.
`UP` - user pointer containing address of the base of the user area. Also not particularly useful.
`N` - a utility area in z-page from N-1 through N+7. This is quite useful for safe temporary storage.
`XSAVE` - one byte storage, typically to stash register X temporarily.
`DTOP` - address of the top of the data stack.
`SETUP` - address of routine to move up to four stack elements to the utility area. The code
```
3 # LDA, SETUP JSR,
```
will remove three top elements from the data stack and place them in N, N+1, and N+2.

Lastly, all assembler words except `CODE` reside in the `ASSEMBLER` wordlist, so they are generally not visible during normal use, but you don't need to add `ASSEMBLER` to search list explictly. `CODE` does that automatically and `END-CODE` removes it again.

## Commander X16 Extensions

There is a dedicated build target for the Commander X16 that adds native words for
the X16-specific hardware: the VERA video chip, hardware sprites, the PSG and
YM2151 (FM) audio, and binary LOAD/SAVE. These words are only present in the X16
build; the plain C64/X16-compatible PRG (`makeprg.bat`) does not include them.

* `makex16.bat` builds `forthx16.prg` (defines `X16 = 1`, which implies the C64
  KERNAL-compatible core). The build files are `buildx16prg.asm`, `x16prims.asm`
  (referenceable VERA primitives, placed above the token boundary) and `x16.asm`
  (the higher-level words).
* `testx16.bat` builds and launches the result in the X16 emulator.

The platform-identifying word is `X16` (instead of `C64`/`F256`).

#### Cartridge build (ROM bank 32)

The X16 build can also be packaged as a cartridge that auto-boots from ROM bank 32:

* `makex16crt.bat` builds `forthcart.bin` - a 16K ROM-bank image. It first builds
  `forthx16.prg`, then wraps it with `x16cart.asm`.
* `testx16crt.bat` builds and boots it: `x16emu -cartbin forthcart.bin`.

The KERNAL detects a cartridge by the PETSCII signature `CX16` at `$C000` in ROM
bank 32 and calls the entry point at `$C004`. Because bank 32 shares the
`$C000-$FFFF` window with the KERNAL, `x16cart.asm` is a small loader stub that
copies the Forth image into low RAM, switches to ROM bank 0, and starts the
interpreter - so Forth runs from RAM exactly as the PRG does, but boots straight
from the cartridge with no loading. The whole image fits in one 16K bank
(currently ~9K, leaving ~7K for more words).

#### Run-from-ROM build (v3, experimental)

There is also a build that runs the interpreter **in place from an X16 ROM bank**
(`$C000-$FFFF`, intended for bank `$09`), so the ~13.5 KB of interpreter code lives
in ROM instead of low RAM - freeing that RAM for the user dictionary. This is
different from the cartridge above, which copies itself to RAM.

* `makex16rom.bat` builds `forthx16rom.bin`, a full 16 KB bank image
  (`buildx16rom.asm` sets `X16ROM = 1`; it must be assembled with `--cpu 65c02`).

Since a bank at `$C000` cannot call the KERNAL (`$FFxx`) directly - that window is
the bank itself - the build installs a small set of RAM *bridge trampolines* at
cold start and points the KERNAL symbols at them; FP/audio reach their banks by
porting the KERNAL `jsrfar` into the bank; and the bank's CPU vectors point at the
KERNAL's low-RAM IRQ handlers. The whole thing boots to `OK` and passes the full
test suite from ROM (integer, floating point, audio, strings, VERA, LOAD/SAVE).

Because it replaces the demo bank (`$09`), it is launched by the BASIC **`TEST`**
command - the same one that used to run the demo. The bank starts with the 4-word
vector table `TEST` expects; `TEST` copies the bank to RAM `$1000` and jumps into a
small launcher there, which `jsrfar`s back into bank 9 to start Forth in place. So
on a machine whose ROM has Forth in bank 9, you just type `TEST` at the READY
prompt.

To build a ready-to-run ROM: `makex16rom.bat` (produces `forthx16rom.bin`) then
`makeromforth.bat`, which copies the pristine 16-bank ROM (`emulator\rom.bin.orig`)
to `emulator\rom.bin` with bank `$09` patched to Forth. Launch the emulator from
`emulator\` and type `TEST`. Forth cold-starts in place and reports ~31 KB free
(all of low RAM, since the interpreter is in ROM), including a BASIC-style
`NNNNN BYTES FREE` line at boot. Floating point/audio (via `jsrfar`), the `IRQ`
Forth-callback (via a RAM CINV trampoline), VERA, and disk LOAD/SAVE all work from
ROM; the full test suite passes. Design notes and status are in
`doc/forth-in-rom-scope.md`.

Wherever it is reasonable the words mirror the corresponding X16 BASIC command,
but follow Forth stack conventions. Arguments are pushed in the same
left-to-right order as the BASIC command, so BASIC `VPOKE bank,addr,value`
becomes Forth `bank addr value VPOKE`.

### VERA video
```
VADDR  ( bank addr -- )       point VERA's data port at VRAM (bank:addr), auto-increment 1
V!     ( byte -- )            store a byte through the data port
V@     ( -- byte )            read a byte through the data port
V!W    ( w -- )               store a 16-bit word (low byte first)
VPOKE  ( bank addr value -- ) BASIC VPOKE
VPEEK  ( bank addr -- value ) BASIC VPEEK
```
`bank` is the 17th VRAM address bit (0 or 1). VRAM is 128K: `$0:0000`..`$1:FFFF`.

### Text screen
```
SCREEN ( mode -- )   set screen mode (0=80x60, 1=80x30, 2=40x60, 3=40x30, 128=320x240@256c)
COLOR  ( fg bg -- )  set text colors 0-15 (BASIC COLOR)
BORDER ( color -- )  set the display border color 0-15
CLS    ( -- )        clear the text screen
LOCATE ( row col -- ) move the text cursor (BASIC LOCATE)
CURSOR ( -- row col ) read the text cursor position (inverse of LOCATE)
SCROLLX ( n -- )     set the layer-1 hardware horizontal scroll (0-4095)
SCROLLY ( n -- )     set the layer-1 hardware vertical scroll (0-4095)
```

### Bitmap graphics
Enter graphics mode with `GINIT` first (320x240, 256 colors). Coordinates are
0-319 (x) by 0-239 (y). The rectangle/oval words take two corner points.
```
GINIT ( -- )                     enter 320x240x256 graphics mode
GCLS  ( -- )                     clear the graphics screen
PSET  ( x y color -- )           set a pixel
LINE  ( x1 y1 x2 y2 color -- )   draw a line
FRAME ( x1 y1 x2 y2 color -- )   rectangle outline
RECT  ( x1 y1 x2 y2 color -- )   filled rectangle
RING  ( x1 y1 x2 y2 color -- )   ellipse outline
OVAL  ( x1 y1 x2 y2 color -- )   filled ellipse
GTEXT ( x y color c-addr u -- )  draw a string into the bitmap (BASIC CHAR)
```

### Sprites
Sprite attributes live in VRAM (bank 1). Enable the layer, point a sprite at its
image data, set size/position/Z-depth. Sprite numbers are 0-127.
```
SPRITES-ON   ( -- )                enable the sprite layer
SPRITES-OFF  ( -- )                disable the sprite layer
SPRITE-IMAGE ( graphaddr sprite -- ) set 4bpp image address (32-aligned VRAM address)
SPRITE-POS   ( x y sprite -- )     set position
SPRITE-GET   ( sprite -- x y )     read a sprite's position (inverse of SPRITE-POS)
SPRITE-SIZE  ( width height sprite -- ) size codes 0-3 = 8/16/32/64 pixels
SPRITE-Z     ( z sprite -- )       Z-depth 0=off 1=behind 2=between 3=front
SPRITE-MOV   ( num x y -- )        set sprite position (= BASIC MOVSPR)
SPRITE-MEM   ( num bank addr -- )  set sprite image address, 4bpp (= BASIC SPRMEM)
```
Plus `SPRITE ( num zdepth -- )` — set Z-depth (0=off 1-3) and enable the sprite
layer (= BASIC SPRITE).

### Audio
PSG voices (0-15). `PSGFREQ/PSGVOL/PSGWAV` write VERA's PSG registers directly;
the others use the audio ROM API.
```
PSGFREQ  ( freq voice -- )      set frequency word
PSGVOL   ( vol voice -- )       set volume 0-63 (both L and R)
PSGWAV   ( waveform voice -- )  0=pulse 1=saw 2=triangle 3=noise
PSGINIT  ( -- )                 reset all PSG voices
PSGNOTE  ( note voice -- )      play a note (octave<<4 | 1..12, 0=off)
PSGPAN   ( pan voice -- )       stereo pan (1=left 2=right 3=both)
PSGPLAY  ( c-addr u voice -- )  play a play-string (blocking)
PSGCHORD ( c-addr u voice -- )  play a chord string (blocking)
```
FM (YM2151). `YM!` writes chip registers directly and is always safe; the other
FM words call the audio ROM API through `jsrfar` (channels 0-7):
```
YM!     ( value reg -- )        write a YM2151 register (raw)
FMINIT  ( -- )                  init the chip and load the default patches
FMINST  ( inst channel -- )     load instrument patch 0-162
FMVOL   ( vol channel -- )      set volume 0-63
FMNOTE  ( note channel -- )     play a packed note (octave<<4 | 1..12, 0=off)
FMFREQ  ( freq channel -- )     play a raw frequency in Hz (17..4434)
FMDRUM  ( drum channel -- )     play a drum sound (25-87)
FMVIB   ( speed depth -- )      set the global vibrato (depth 0..127)
FMPAN   ( pan channel -- )      stereo pan (1=left 2=right 3=both)
FMPLAY  ( c-addr u channel -- ) play a play-string (blocking)
FMCHORD ( c-addr u channel -- ) play a chord string (blocking)
FMPOKE  ( value reg -- )        write a YM2151 register via the API (shadow-tracked)
```

### Tiles (layer-1 text screen)
Read and write cells of the layer-1 tilemap. Each cell is a screen/tile code
plus a colour attribute; the address is derived from the VERA layer-1 registers,
so it follows the current screen mode.
```
TILE  ( x y code attr -- )   write a tile cell
TDATA ( x y -- code )        read a tile cell's code
TATTR ( x y -- attr )        read a tile cell's colour attribute
```

### Math helpers
Integer helpers matching BASIC. (BASIC's floating-point functions `SQR SIN COS`…
are provided too - see Floating point below.) `ABS MIN MAX MOD` are core words.
```
SGN    ( n -- -1|0|1 )   sign of a signed number
RND    ( u -- n )        pseudo-random number in 0..u-1
RANDOM ( -- u )          raw 16-bit pseudo-random number
POS    ( -- col )        current text cursor column
```

### Bit / byte manipulation
```
CATNIB ( nh nl -- byte )  concatenate two nibbles: (nh<<4) | nl
SPLIT  ( n -- bh bl )     split a cell into high and low bytes
SBIT   ( addr mask -- )   set the masked bits of the byte at addr
CBIT   ( addr mask -- )   clear the masked bits of the byte at addr
FBIT   ( flag addr mask -- ) set the masked bits if flag is true, else clear
```
(`LSHIFT` and `RSHIFT` are core words.) These are handy for I/O-register work.

### Input devices
```
JOY    ( n -- buttons )   read joystick/gamepad n (0=keyboard, 1-4 gamepads);
                          button bits active-high, 0 if not present
MOUSE  ( mode -- )        configure the mouse (0=off, 1=on, -1=auto-scale)
MX     ( -- x )           mouse X position
MY     ( -- y )           mouse Y position
MB     ( -- buttons )     mouse button bitmask (bit0 left, bit1 right, bit2 mid)
MWHEEL ( -- delta )       mouse wheel movement since last read (signed)
```

### Floating point
The X16 build has floating point, implemented by calling the ROM's FP package
(the X16 keeps its FP accumulator clear of Forth's zero page). Floats live on a
dedicated float stack (shown as `F:` below).
```
S>F  ( n -- ) ( F: -- r )     integer to float
F>S  ( -- n ) ( F: r -- )     float to integer (non-negative)
F+ F- F* F/  ( F: a b -- c )  arithmetic
FDUP FDROP FSWAP FOVER FNEGATE   float-stack operations
FSQRT FSIN FCOS FTAN FATAN FLN FEXP FABS   ( F: r -- f(r) )
FPOW  F**  ( F: x y -- x^y )   power via exp(y*ln x), x>0
FMAX FMIN  ( F: r1 r2 -- r )   larger / smaller of two floats
F@ F!  ( f-addr -- )          fetch / store a float (5 bytes) in memory
F< F0< F0=                    comparisons ( -- flag )
>FLOAT ( c-addr u -- flag )   parse a string as a float (pushes it if valid)
F.   ( F: r -- )              print a float
ISQRT ( n -- m )              integer square root
```
More FLOATING / FLOATING-EXT words are in `toolkit/FPX.FTH` (`INCLUDE FPX.FTH`),
composed from the primitives above: constants `FPI FPI2 FLN10`; sizing
`FLOAT+ FLOATS FALIGN FALIGNED`; `FROT FSINCOS`; `FLOG FALOG FLNP1 FEXPM1`;
hyperbolic `FSINH FCOSH FTANH`; inverse trig `FASIN FACOS FATAN2`; and
`F~` (approximate compare).
Float **literals** can be typed directly at the interpreter, e.g. `3.14`, `1E3`,
`-2.5E-2` — they are recognized and pushed to the float stack. (Inside a `:`
definition use `S" ..." >FLOAT` or an `FCONSTANT`.)
The FP defining words `FVARIABLE` and `FCONSTANT` are built into the X16 build.
The BASIC math names `SQR SIN COS TAN ATN LOG EXP` are just aliases of the `F*`
words, so to save ROM space they live in `toolkit/BASICMATH.FTH` — `INCLUDE
BASICMATH.FTH` to get them, or use `FSQRT`/`FSIN`/… directly.
Example: `2 S>F FSQRT F.` prints `1.41421356`.

### System / dev
```
USR      ( addr -- )   call a machine-language routine at addr (it must RTS)
IRQ      ( xt -- )     run a Forth word on every 60 Hz VSYNC interrupt (arm with
                       an xt from `'`; `0 IRQ` disarms). The callback must be short
                       and stack-neutral; it runs on its own stacks. (RAM/PRG build.)
EDIT     ( c-addr u -- )  edit a file in the X16 full-screen editor (u=0 = new)
SETBANK  ( bank -- )   select the RAM bank visible at $A000-$BFFF
B@       ( bank off -- byte )   read a byte from banked RAM (off 0..8191)
B!       ( byte bank off -- )   store a byte into banked RAM (off 0..8191)
SLEEP    ( jiffies -- )  wait 'jiffies' 1/60-second ticks
MS       ( u -- )        wait ~u milliseconds (calibrated 8 MHz busy loop)
KEYMAP   ( c-addr u -- )  set the keyboard layout, e.g. S" en-us" KEYMAP
REBOOT   ( -- )        soft reboot through the reset vector

  -- game-support primitives --
VSYNC    ( -- )        wait for the next video frame (frame-locked 60 Hz, via a
                       VERA-VSYNC IRQ counter; pace a loop, tear-free draw)
FRAMES   ( -- n )      the video frame counter 0..255 (deltas for timing/FPS)
VFILL    ( value count -- )  fill 'count' VRAM bytes with a value (set addr with
                       VADDR first) - fast native loop for clearing bitmaps/tilemaps
*.       ( n1 n2 -- n3 )  signed 8.8 fixed-point multiply (n1*n2>>8), for sub-pixel motion
COLLIDE? ( ax ay aw ah bx by bw bh -- flag )  bounding-box overlap test
```
`EDIT` drives the standalone X16EDIT ROM (not the BASIC wrapper) to create and
edit files directly on the machine. The general "swallowed RETURN after a device-8
file read" glitch is **fixed** — `ACCEPT` resets the KERNAL screen-editor
line-input state before each keyboard line, so a plain `S" X.FTH" INCLUDED`
followed by a command works on the first RETURN. **`EDIT` still has a residual
glitch**, though: the first keyboard line right after quitting the editor is
swallowed (x16edit leaves more KERNAL state off than a file read does, beyond what
the `ACCEPT` reset covers). Reliable EDIT workflow: `S" MYPROG.FTH" EDIT`, write
out and quit, then reset Forth (relaunch / cold start) and
`S" MYPROG.FTH" INCLUDED` in the fresh session. See `doc/EDIT-known-issue.md`.

BASIC-style aliases for existing Forth words are **built into the X16 build**:
`OPEN` (=`OPEN-FILE`), `CLOSE` (=`CLOSE-FILE`), `LINPUT` (=`ACCEPT`). The other
BASIC-integrated commands (`DOS HELP BOOT MENU`) are not provided: they parse the
BASIC text buffer and use BASIC's zero page, which conflicts with Forth.

The string / number-conversion functions
(`NHEX NBIN STR VAL ASC CHR LEN LEFT RIGHT MID RPT`), using Forth's
`c-addr u` string model, live in `toolkit/BASICSTR.FTH` (`INCLUDE BASICSTR.FTH`)
— they are plain Forth over the pictured-numeric-output words, so they were moved
out of the ROM core to make room for the filesystem words. They carry no trailing
`$` (so the names are valid Forth); `NHEX`/`NBIN` take an `N` prefix because `HEX`
and `BIN` are core words. `FVARIABLE`/`FCONSTANT` are built in; the BASIC math
names (`SQR SIN COS TAN ATN LOG EXP`) are in `toolkit/FPX.FTH`.

### Binary LOAD / SAVE
Filenames are Forth strings `( c-addr u )`, e.g. `S" DATA.BIN"`. `dev` is the
device number (usually 8).
```
LOAD    ( c-addr u dev -- )              load a PRG to the address in its 2-byte header
BLOAD   ( c-addr u dev addr -- )         load a PRG relocated to addr
VLOAD   ( c-addr u dev bank vaddr -- )   load a (headered) file into VRAM
BVLOAD  ( c-addr u dev bank vaddr -- )   load a headerless file into VRAM
SAVE    ( c-addr u dev start end -- )    save memory [start,end) as a PRG (BASIC BSAVE)
VSAVE   ( c-addr u bank vaddr len -- )   save 'len' bytes of VRAM to a headerless
                                         file (device 8); the inverse of BVLOAD
BVERIFY ( c-addr u dev addr -- flag )    verify a file against memory (-1 match / 0 mismatch)
```
The KERNAL `SAVE` cannot read VRAM, so `VSAVE` streams the bytes out through the
VERA data port to an open file (device 8). Convenience words save/load sprite and
tile *definitions* on top of `VSAVE`/`BVLOAD` (all on device 8):
```
SPRSAVE  ( c-addr u sprite -- )  save a sprite's image pixels (address and byte
SPRLOAD  ( c-addr u sprite -- )  count are read from the sprite's own attributes)
TILESAVE ( c-addr u vaddr len -- ) save a bank-1 tileset (explicit address + size)
TILELOAD ( c-addr u vaddr -- )     load a bank-1 tileset
TMAPSAVE ( c-addr u -- )         save the layer-1 tilemap (self-sizing, from the
TMAPLOAD ( c-addr u -- )         VERA layer-1 MAPBASE/CONFIG registers)
```

## Platform-Specific Notes

### Commodore 64
* KEY echoes the input character
* BYE reboots the interpreter in cartridge mode and attempts to return to Basic in PRG (that is not working properly yet).
* R/W mode is not supported, the word will do the same as W/O.
* FILE-POSITION FILE-SIZE	REPOSITION-FILE RESIZE-FILE are not functional and will just fail.
* Opening file for write does not overwrite an existing file. This is a default system behavior but it feels quite wrong.
* C64 file handling makes it very hard to distinguish 0-byte file from a non-existing one. INCLUDE will just fail on empty files.

### Commander X16
All Commodore 64 notes apply except for BYE which properly returns to Basic.

### Foenix F256
* BYE will restart the interpreter.
* R/W mode is not supported, the word will do the same as W/O.
* FILE-POSITION FILE-SIZE REPOSITION-FILE RESIZE-FILE are not functional and will just fail.

## Other Notes

A modified copy of dynamic memory support package can be found in `dynamic`. This brings in standard Memory-Allocation set. The modification was needed to fix a non-compliant issue - allocations of negative size were not properly rejected.

The interpreter will look for file `AUTORUN.FTH` and execute it if found.

**AUTORUN and the toolkit images per build (X16).** ForthX16 can run three ways, and each build needs its own compiled-toolkit image (a `SAVE-IMAGE` snapshot is tied to the exact binary that made it - loading another build's image crashes). The `emulator/` folder ships one image per build plus a ready-made autorun for each:

| Build | Started by | Toolkit image | Autorun file |
|---|---|---|---|
| Program (`forthx16.prg`) | `LOAD"FORTHX16.PRG",8` + `RUN` from BASIC | `TKPRG.DIC/.TOK/.VAR` | `AUTORUNPRG.FTH` |
| ROM bank 9 (`forthx16rom.bin` in `rom.bin`) | `loader.prg` (or `TEST`) from BASIC | `TK9.DIC/.TOK/.VAR` | `AUTORUN9.FTH` |
| ROM bank 32 cartridge (`boot2.rom`) | autoboots (`CX16` signature) | `TK32.DIC/.TOK/.VAR` | `AUTORUN32.FTH` |

Only the file literally named `AUTORUN.FTH` runs at boot, so copy the variant matching the build over it (e.g. for bank 9: `AUTORUN9.FTH` -> `AUTORUN.FTH`). The shipped `AUTORUN.FTH` is a copy of `AUTORUN32.FTH` (the cartridge case). Each variant just does `S" TKxx" LOAD-IMAGE DROP` and prints a `TOOLKIT READY` banner naming its target, so a mismatch is easy to spot. All three images bundle the same toolkit: `FPX BASICSTR PCMAUDIO ASSEMBLER DIRNAV`.

A modified copy of Forth test suite is in `tests` - copy files from there to the file system of Commander X16 and start it with `INCLUDE RUNTESTS.FTH`. The current version should run all tests without errors. The runtime on the emulator is about 4 minutes on Commander X16 (and a LOT more on C64).

`tests-X16` holds self-checking tests and demos for the Commander X16 extension words (VERA, sprites, tiles, audio, floating point, the baked-in string/BASIC-alias/FP toolkit words, the bit/byte words, `SCROLLX/SCROLLY` + `IRQ`, and the sprite/tile disk save-load words). Each is self-contained - run e.g. `INCLUDE X16TEST.FTH`; see `tests-X16/readme.txt` for the list.

A practically stock copy of Forth test suite is in `tests-F256` as that platform uses ASCII and does not need character hacks.

A few examples and benchmarks are in `other`.

**Benchmarks & samples.** `BENCH.FTH` and `ERASTO.FTH` are old benchmarking programs calculating primes, practically unchanged (`BENCH` had a few `ENDIF`s replaced by `THEN`s). `RC4TEST.FTH` is a sample from the [Wikipedia](https://en.wikipedia.org/wiki/Forth_(programming_language)) page, unmodified.

**`GAME.FTH`** is a small proof-of-concept 2D game ("catch the dots") showing the game-support primitives together - hardware sprites, `VSYNC` pacing, `COLLIDE?` collision, `VFILL` (building sprite images), `JOY` input and `RND`: `INCLUDE GAME.FTH` then `PLAY` (arrow keys to move, Start to quit), or `SELFTEST` for a non-interactive frame.

**`GAMEYM.FTH`** is the same game with its audio switched from the VERA PSG to the YM2151 FM synth - only section 4 differs, using `FMINIT`/`FMINST`/`FMNOTE`/`FMVOL` (a demonstration of the FM words and of swapping a sound backend).

**`SPLIT.FTH`** is a split-screen helper library for the X16: it puts a 320x240 bitmap on VERA layer 0 and confines the text console to a window on layer 1 (composited on top), giving a graphics-top / text-bottom screen with no raster interrupt - `INCLUDE SPLIT.FTH` then `SPLIT-DEMO`; `SPLITON`/`SPLITOFF` enter/leave it (`SPLIT-ROWS` sets the text-window height). It also provides the full bitmap-graphics vocabulary as direct-to-VERA words that work in BOTH the split and normal `GINIT` full-screen mode (both use the same $0000 bitmap): `GCLS PSET LINE FRAME RECT RING OVAL GTEXT`, radius circles `CIRCLE`/`FCIRCLE` (same names/signatures as the KERNAL GRAPH words, which they redefine), plus low-level `BPSET BHLINE BVLINE BLINE BFILL BRECT BCLS`. A persistent-pen API avoids repeating the colour: `n GCOLOR` then `PLOT DRAW BOX FBOX ELL FELL CIRC DISC SAY`.

**`MORTGAGE.FTH`** is a Canadian mortgage calculator: it uses the semi-annual-compounding rule (`i = (1+j/2)^(1/6)-1`) and the floating-point words to compute the monthly payment and print a full capital/interest amortization grid - `INCLUDE MORTGAGE.FTH` then `300000. 25 550 MTG` ($300k, 25 yr, 5.50%; principal takes a trailing dot so it can exceed 16 bits, rate is x100), then `SCHEDULE` for the month-by-month table or `YEARLY` for a yearly one. It doubles as a worked example of building a power function from `FLN`/`FEXP` and printing money to the cent past `F>S`'s 65535 limit via a 32-bit double and pictured numeric output.

**`HP50.FTH`** is an HP-50g-style RPN scientific calculator: a typed value stack, an HP-style numbered-level display, and a small object system. Types: reals; exact 32-bit integers with BIN/OCT/DEC/HEX bases and bitwise `AND OR XOR NOT`; complex numbers `(re,im)` (`+ - * / CONJ RE IM ARG ABS R->C C->R`); and lists `[ 1 2 3 ]` (`SIZE GET`, `+` concatenates) which double as vectors (`DOT V+ V- NORM CROSS`) and matrices (`DET TRN M*`). It also has named user variables (`STO RCL PURGE CLVAR`, and a bare name recalls) that persist across `CLEAR`. Plus the usual scientific functions (`SIN COS TAN ASIN ACOS ATAN LN EXP LOG ALOG ^ SQRT`, DEG/RAD, STD/FIX) and an RPN command parser - `INCLUDE HP50.FTH` then `HP` (`OFF` quits), with `HP50TEST.FTH` self-checking it (78 tests).

**Compiled-image snapshot.** Because compiling a large library from source is slow (~30s, dominated by the per-word dictionary search), two native words snapshot the compiled dictionary for a ~1s reload. `S" NAME" SAVE-IMAGE` ( c-addr u -- ) writes the dictionary bytes, the user token-table slice, and the dictionary-state pointers to three device-8 files named `NAME.DIC`/`NAME.TOK`/`NAME.VAR`; `S" NAME" LOAD-IMAGE` ( c-addr u -- flag ) restores them (it is native so it can safely replace the dictionary). They are generic (work for any compiled `.FTH`) and work in the PRG, bank-9 ROM and bank-32 cartridge builds. One image can bundle **several** libraries at once - `INCLUDE` them all, finish with `ONLY FORTH DEFINITIONS DECIMAL`, then one `SAVE-IMAGE`; make `S" NAME" LOAD-IMAGE DROP` the last line of `AUTORUN.FTH` to auto-load the whole toolkit at boot. The image is tied to the exact interpreter build (rebuild it if you rebuild the `.prg`/`rom.bin`). See the user guide ("Bundling several libraries into one image") for the full rules.

## Known Issues

The error recovery has a bug that causes to lock the interpreter in some cases. The cause is not clear yet and the issue seems to be random.

**Fixed in 2.0 - data-stack overflow detection.** `?STACK` compares `DEPTH` (a count in *cells*) against `STACKLIMIT`, but `STACKLIMIT` was previously derived from `DSIZE` in *bytes* - roughly twice the real capacity. As a result a data-stack overflow of a few hundred cells was never detected and silently ran off the end of the stack into the adjacent buffers (the float stack, the INCLUDE and `S"` buffers, etc.), which could corrupt them. `STACKLIMIT` is now a proper cell count (`DSIZE/2 - 2*SSAFE`), so `?STACK` aborts on a genuine overflow before it can corrupt neighbouring memory. This was a distinct, reproducible defect; testing did not tie it to the random error-recovery lock noted above, which remains unconfirmed.

On the Commander X16, `EDIT` returns from the X16 editor with Forth's first console operation broken (the first RETURN is swallowed; an `INCLUDED` run immediately afterward won't compile). BASIC's own `EDIT` returns cleanly, so the cause is Forth-specific and unresolved. Workaround: after editing, reset Forth (relaunch / cold start) before `INCLUDE`-ing the file. Details in `doc/EDIT-known-issue.md`.

## Roadmap

I don't have any particular time estimates, but I do have some plans. The following items can be
considered my roadmap for the project.

### Cleanups
The project was originally based on the source code written in one weekend so it was already quite messy.
Multiple optimization passes may have improved the size, but did not make it cleaner. The latest addition
of F256 target was a bit rushed as well. As a result, the code is not in the best shape, needs some
cleaning and documenting. Mind you, it is practically impossbile to make a largish 6502 assembly project
to look clean, there are always some tricks there that would look questionable. So, the best effort here.

### Optimization in F256 specific section
F256 has a large block of platform specific code for console and file I/O. The file I/O may be more or
less straightforward, but console I/O may still shed some bytes.

### Atari 8-bit target
My first computer was Atari 65XE, so it is only right to support that. Now that I have support for two
very different platforms the actual platform dependencies are easy to identify and port.

### Toolkits
These are required for any usable Forth system. I am already looking into inline assembler. Editor is
a reasonable thing to have. Some parts of the Standard may be added through a toolkit expansion.
Finally, there are also a lot of platform-specific things that would make the system a lot more usable.
(On the X16 the string, BASIC-alias, and floating-point toolkits are now baked into the build.)

### Run from ROM (v3)
Running ForthX16 in place from an X16 ROM bank (see the "Run-from-ROM build"
section above and `doc/forth-in-rom-scope.md`) so the interpreter lives in ROM and
low RAM is freed for the user dictionary. Launched by the BASIC `TEST` command
(replacing the demo), it passes the full test suite from ROM including the ROM-mode
`IRQ` callback, reports ~31 KB free with the finalized RAM map, and is packaged with
`makeromforth.bat`. (The FPGA ROM path is left unchanged.)
