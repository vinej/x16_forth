; Forth system for Commander X16 - port of Forth Model T
; by Vasyl Tsvirkunov (version 1.5)
; version 2.0 by Claude Opus 4.8 with the help of Jean-Yves Vinet
; At this point the compliance status is:
; * Forth-2012 System
; * Providing the Core Extensions word set
; * Providing the Double-Number word set
; * Providing the Double-Number Extensions word set
; * Providing the File Access word set
; * Providing the File Access Extensions word set
; * Providing the Search-Order word set
; * Providing the Search-Order Extensions word set
; * version 2.0 add all words to use audio/sprite/string/etc, features find in basic 2.0
; * version 2.0 is in par with Basic 2.0 and I kept the same names in forth find in Basic
; In addition, some words from String, Programming-Tools, and Facility sets are provided.
; File Access functionality is limited by the platform

; This system will pass all standard tests for Core, Core Extensions, Double-Number, and Search-Order.
; The supplied subset of Facility word set is sufficient to pass that test completely (only five words are tested).
; The partial Programming-Tools and String wordsets are compliant and will also pass individual tests.
; With dynamic-memory-allocation package by Ulrich Hoffmann installed the implementation will pass the
; Memory-Allocation tests (the implementation is slightly non-compliant and fails on negative sizes
; passed to ALLOCATE and RESIZE, those need to be patched for 100% clean test).
; Optional Block, Exception, and Locals sets are not implemented. No Floating-Point either.

; Significant changes compared to Forth Model T
; I/O functionality is limited according to the platform constraints
; TOUPPER has been removed as it does not make much sense with PETSCII. All string constants brought to uppercase
; Removed CSTR, not used
; Added PLACE and +PLACE
; A number of words were rewritten in assembly for speed
; Removed SAVE-SYSTEM - may come back in a different variation
; Removed non-standard flag support, did not serve much purpose, and caused implementation issues
; Removed ENVIRONMENT? queries, not required by standard, useless
; Changed some non-standard internal word semantics for better code reuse ((FIND), (CREATE))
; Made a number of non-standard words internal
; Added Search Order
; Switch to token threaded code and optimized many places

; Peculiarities:
;	C64 PETSCII charset does not have backslash. Pound symbol is used instead
;	It does not have tilde either. Not used in standard words, but it is used in test suite

; ACME assembler does not have facilities to convert between int and string, unless I've missed something...
VERSION_HIGH = "2"
VERSION_HIGH_INT = 2
VERSION_LOW = "0"
VERSION_LOW_INT = 0

; ACME does not assume non-existing symbols to resolve to 0, forcing it here
; X16 is a superset of the C64 target: it reuses the C64 KERNAL-compatible I/O
; and adds native words for the Commander X16 hardware (VERA video, sprites,
; audio, binary LOAD/SAVE). Defining X16 implies C64.
!ifndef X16ROM {
X16ROM = 0
}
!ifndef X16CART {
X16CART = 0		; 1 = bank-32 cartridge build (boot2.rom, autoboots via "CX16")
}
!ifndef NATIVE816 {
NATIVE816 = 0		; 1 = 65816 native-mode build (MiSTer core, flat 16MB RAM, X16 only)
}
!if X16ROM {
!ifndef X16 {
X16 = 1
}
}
!ifndef X16 {
X16 = 0
}
!if X16 {
!ifndef C64 {
C64 = 1
}
}
!ifndef C64 {
C64 = 0
}
!ifndef CART {
CART = 0
}
!ifndef F256 {
F256 = 0
}

; Validate platform defines so they don't need to be validated every time
!if C64 = 0 and F256 = 0 {
!error "Undefined platform"
}
!if CART != 0 and C64 = 0 {
!error "Invalid cartridge target"
}
!if NATIVE816 != 0 and X16 = 0 {
!error "NATIVE816 requires X16"
}

; FPCORE: 1 = floating point baked into the image (the original layout),
; 0 = FP moves to toolkit/FLOAT.FTH (self-contained CODE words over the same
; BASIC ROM bank-4 routines; load with  INCLUDE FLOAT.FTH ). With FPCORE=0
; the core keeps only a DEFERred >FLOAT hook so float literals start working
; the moment the toolkit loads (~1.3KB of image + 84 buffer bytes freed -
; which is what makes room for FASTLOAD in the 16K ROM/cart images). The
; ROM/cart images also embed the conventional jsrfar stub at $FF6E so the
; toolkit's cross-bank calls work with the Forth bank active.
!ifndef FPCORE {
FPCORE = 0
}

; FASTLOAD: fast .FTH source loading (hash index over the core dictionary for
; FIND - see build_hashtable - plus native READ-LINE/PARSE/WORD/NUMBER inner
; loops). All X16 builds; the ROM/cart images fit it thanks to FPCORE=0.
!ifndef FASTLOAD {
!if X16 {
FASTLOAD = 1
} else {
FASTLOAD = 0
}
}

; GFXTOOLKIT: the X16 bitmap-graphics words (GINIT GCLS PSET LINE FRAME RECT
; RING OVAL GTEXT) live in a loadable toolkit (INCLUDE GFX.FTH) instead of the
; core. Frees ~513 bytes in every X16 build - room for the bank-I/O words and
; future features, especially in the tight ROM/cart builds. DEFAULT 1 for X16
; (build with GFXTOOLKIT=0 to bake graphics back into the core the old way).
!ifndef GFXTOOLKIT {
!if X16 {
GFXTOOLKIT = 1
} else {
GFXTOOLKIT = 0
}
}
!if GFXTOOLKIT != 0 and X16 = 0 { !error "GFXTOOLKIT requires X16" }

; WIDEDICT: 65C816 Phase 2 - dictionary beyond 64KB (MiSTer flat-RAM core).
; Requires NATIVE816. Design: token ids and the 2-byte TOKENS offsets stay
; exactly as they are (the NEXT dispatch hot path is untouched); a parallel
; TOKBANK byte array holds each word's bank (0 = the home bank = today's
; behavior). Development flag - off everywhere by default, enabled only in
; the experimental buildx16prg816w.asm while Phase 2 lands step by step.
!ifndef WIDEDICT {
WIDEDICT = 0
}
!if WIDEDICT != 0 and NATIVE816 = 0 {
!error "WIDEDICT requires NATIVE816"
}
!ifndef WD_FARHDR { WD_FARHDR = 0 }	; WIDEDICT: also put word HEADERS (not just
			; bodies) into the code banks, so near holds ~only data.
			; RAM-window (WD_ROMBANKS=0) only; default off (isolated).
!if WD_FARHDR != 0 and WIDEDICT = 0 { !error "WD_FARHDR requires WIDEDICT" }
!ifndef WD_ROMBANKS { WD_ROMBANKS = 1 }	; WIDEDICT code-bank storage:
			; 1 = 16K ROM banks 33+ via the $C000 window ($01) -
			;     MiSTer / -cartbin; keeps the bank-2 data window.
			; 0 = 8K RAM banks 2-9 via the $A000 window ($00) -
			;     stock hardware; data stays near-only (the $00
			;     window is dynamic), x16edit keeps banks 10-255.
!if WD_FARHDR != 0 and WD_ROMBANKS != 0 { !error "WD_FARHDR requires WD_ROMBANKS=0" }

!if C64 {
!if X16ROM = 0 {
; KERNAL entries (direct). In X16ROM mode these are RAM bridge trampolines
; instead - see the bridge section further down (SETLFS = brg_ram + ...).
SETLFS = $FFBA
SETNAM = $FFBD
OPEN = $FFC0
CLOSE = $FFC3
CHKIN = $FFC6
CHKOUT = $FFC9
CLRCHN = $FFCC
CHRIN = $FFCF
CHROUT = $FFD2
GETIN = $FFE4
READST = $FFB7
STOP = $FFE1
}

!if X16ROM {
; v3: Forth runs in place from an X16 ROM bank ($09) at $C000 (see
; forth-in-rom-scope). The X16 KERNAL is already up when the bank is entered.
;
; Launch: the bank starts with the 4-word vector table the BASIC "TEST" command
; expects (TEST copies the whole 16K bank to RAM $1000 and does jmp ($1000+n*2)).
; All four vectors point at test_launcher, which - running from the $1000 RAM copy
; in bank 0 after TEST's copy - jsrfars back into bank 9 to start Forth IN PLACE.
; So typing "TEST" (replacing the demo) boots Forth from ROM. The 16K RAM copy is
; scratch (the dictionary overwrites it later). coldstart is also a direct jsrfar
; target (a loader can jsr $FF6E / !word coldstart / !byte $09).
!ifndef FORTH_BANK { FORTH_BANK = $09 }		; ROM bank this image lives in (a cart build overrides to 32)
* = $C000
start_of_image:
!if X16CART {
	; X16 cartridge: the KERNAL's boot_cartridge checks for "CX16" at $C000 and, if
	; found, far-calls $C004 with THIS ROM bank active and IRQs masked (screen/audio
	; already inited). On the MiSTer the file must be named boot2.rom to autoboot.
	; coldstart sits directly at $C004 - no jmp, no pad (every ROM byte is needed).
	!byte $43, $58, $31, $36		; "CX16" signature ($C000-$C003)
} else {
	; bank-9: 4-word TEST vector table + launcher (a loader can also jsrfar $C00F/bank 9).
	!word $1000 + (test_launcher - start_of_image)	; TEST / TEST 0
	!word $1000 + (test_launcher - start_of_image)	; TEST 1
	!word $1000 + (test_launcher - start_of_image)	; TEST 2
	!word $1000 + (test_launcher - start_of_image)	; TEST 3
test_launcher:
	; runs from the $1000 RAM copy (bank 0, IRQs on) - far-call into bank 9
	jsr $FF6E			; KERNAL jsrfar (real, not the bridge)
	!word coldstart
	!byte FORTH_BANK
	rts				; (Forth never returns)
}
coldstart:
!if X16CART {
	cli				; a cart is entered with IRQs masked; the console needs them
}
	ldx #0				; copy the KERNAL bridge trampolines into RAM
-	lda brg_template,x		; (needed before any KERNAL call)
	sta brg_ram,x
	lda brg_template+$100,x
	sta brg_ram+$100,x
	inx
	bne -
!if X16CART {
	; the cart boots BEFORE BASIC, so BASIC's CHRGET was never copied to zp $E7;
	; >FLOAT (float literals) does "jsr CHRGET". Install it ourselves. Cart-only:
	; bank-9/PRG enter from a running BASIC whose CHRGET is already set - never
	; touch $E7 there (overwriting it was the old bank-9 regression).
	ldx #chrget_template_end - chrget_template - 1
-	lda chrget_template,x
	sta $E7,x
	dex
	bpl -
}
warmstart:
} else if CART {
; Only used in cartridge build
IOINIT = $ff84
RAMTAS = $ff87
RESTOR = $ff8a
SCINIT = $ff81

* = $8000
start_of_image:
	!word coldstart
	!word warmstart
	!byte $c3,$c2,$cd,$38,$30;	"CBM80"

coldstart:
	sei
	jsr IOINIT
	jsr RAMTAS
	jsr RESTOR
	jsr SCINIT
	cli
warmstart:
} else {
; C64/Commander X16 prolog. "1 SYS 2061"
; Make sure the file is built in CBM mode (extra $01,$08 at the beginning)

* = $0801
start_of_image:
    !byte $0b,$08,$01,$00,$9e,$32,$30,$36,$31,$00,$00,$00
}

CODESTART = *
} else if F256 {
!source "api_acme.asm"
!source "pgz.asm"

+PGZ_HEADER
+SEGMENT start_of_image, end_of_image

CODESTART = $200
}

!convtab raw

!pseudopc CODESTART {

!if F256 {
start_of_image:
	jsr init_console
	jsr cls
}

; ==============================================================================
; Definitions - constants and variables. Unlike the original RatVM, C64 has some
; memory reserved for ROMs, some zero page locations for registers, etc. In short,
; more realistic case. Forth Model T assumes contiguous chunk of RAM, but the top
; location is configurable and the bottom is not assumed, which can be made
; compatible with X16 mmap.
; Per documentation: RAM goes $0000-$9EFF, but the PRG has to load above $801 (see the prolog).
; That gives 38K, not a whole lot, but enough for a competent Forth system.
; Locations $22-$7F on zero page are available, using those for variables.
; The stacks are a bit of pain. The thing is, 6502 is not really an 8-bit CPU, there
; were not that many truly 8-bit ones - that would restrict RAM to 256 bytes. So, the
; RAM bus is 16 bit, which is good, but the registers are all 8-bit, and that makes
; things difficult. The standard stack is only 256 bytes, not great for Forth (but
; many implementations use that for data stack anyway). For this implementation, we will
; get two 1K stacks.
; However, to make implementation more efficient, the very top element of the data stack
; is separated on the zero page. The safe areas against overflow/underflow are 4 cells vs
; 8 cells in Forth Model T. Return stack does not use safe areas, as it is rarely an issue
; (the system is likely to crash and burn at that point already).

SSAFE = 4		; Number of reserved cells on the both sides of data stack for protection
RSIZE = $0400	; Return stack in bytes
DSIZE = $0400	; Data stack in bytes
TOKEN_COUNT = $0600	; Maximal number of available tokens in token threaded model, must be divisible by 256

WORDLISTS = 10	; Maximum number of allocated wordlists including FORTH-WORDLIST
MAXORDER = 10	; Maximum number of wordlists in search order

; In case if these get moved - important requirement, stacks must be aligned on 16-bit boundary;
; the token table must be aligned on page boundary for performance reasons

NAMEMASK = 31 ; vocabulary entries can have up to 32 characters
IMM_FLAG = 128 ; flag for immediate words
VAL_TRUE = -1 ; required by current standard
VAL_FALSE = 0
JSR_INSTR = $20 ; DOES> needs to emit JSR opcode
JMP_INSTR = $4C ; in direct threading each Forth word stars with JMP CALL
RTS_INSTR = $60	; in size-optimized direct threading this is the entire prolog of Forth calls

NEW_LINE = $0D

!macro zero_page_begin .start {
	!set __zpaddr = .start
}

!macro zero_page_end .check {
	!if __zpaddr > .check {
		!error "Out of zero page storage area!"
	}
}

!macro zpbyte ~.name {
	.name = __zpaddr
	!set __zpaddr = __zpaddr+1
}

!macro zpword ~.name {
	.name = __zpaddr
	!set __zpaddr = __zpaddr+2
}

!macro zpbytearray ~.name, .size {
	.name = __zpaddr
	!set __zpaddr = __zpaddr+.size
}

!macro zpwordarray ~.name, .size {
	.name = __zpaddr
	!set __zpaddr = __zpaddr+2*.size
}

+zero_page_begin $22	; Commander X16 user space $22-7F (94 bytes)

; For the most purposes the order of these fielda does not matter, but for the assembler support the
; requirement is for the first field to be _ri and the order until _scratch_2 fixed as below
+zpword ~_ri					; inner interpreter registers
+zpword ~_w
+zpword ~_rstack				; stack pointers
+zpword ~_dstack
+zpword ~_dtop				; the very top element of the data stack
+zpword ~_rscratch			; four scratch registers used in multiple algorithms (sometimes aliased)
+zpword ~_wscratch
+zpword ~_scratch
+zpword ~_scratch_1
+zpword ~_scratch_2

+zpword ~_here
+zpword ~_base
+zpword ~_latest
+zpbyte ~_current
+zpword ~_state
+zpbyte ~_sflip				; flip-flop for S" buffer selection
+zpbyte ~_ibufcount			; number of used buffers
+zpword ~_source			; pointer to the current source
!if C64 {
+zpword ~_openfiles			; bitfield for files currently open to translate from C64 to Forth opening semantics
+zpword ~_eoffiles			; bitfield for files finished reading (set to 0 on open and to 1 when read to EOF)
+zpbyte ~_nodrive			; set if no drive has been detected on startup
} else if F256 {
+zpbyte ~_drive				; drive for file operations
}

+zpbyte ~_stopcheck

+zpword ~_hightoken

; Search-Order support
+zpwordarray ~_vocs, WORDLISTS
+zpwordarray ~_vocsref, WORDLISTS
+zpbyte ~_numvocs

+zpbytearray ~_context, MAXORDER
+zpbyte ~_numorder

+zero_page_end $7f

!macro high_memory_begin .addr {
	!set __hm_addr = .addr
}

!macro high_memory_end ~.label {
	.label = __hm_addr
}

!macro hmbuffer ~.name, .size {
	.name = __hm_addr - .size
	!set __hm_addr = .name
}

!if C64 {
	!if X16ROM {
		; v3 run-from-ROM RAM map. The interpreter is in ROM bank 9, so all of
		; low RAM is free for the user dictionary and these buffers. The X16's
		; contiguous "golden RAM" ends at $9EFF (I/O is $9F00-$9FFF), so the
		; buffers grow DOWN from $9F00 (top byte used = $9EFF) and the dictionary
		; grows UP from $0801. They meet in the middle: with ~7.2 KB of buffers
		; the dictionary gets roughly $0801..$82xx, ~30 KB (vs ~20 KB in the PRG
		; build, where the interpreter itself occupies low RAM). The 16 KB the
		; BASIC "TEST" command copies to $1000 is scratch - the dictionary
		; overwrites it once Forth is running.
		+high_memory_begin $9f00
	} else if CART {
		+high_memory_begin $8000
	} else {
		+high_memory_begin $a000
	}
} else if F256 {
	+high_memory_begin $c000
} else {
	!error "Not implemented"
}

+hmbuffer ~TOKENS, 2*TOKEN_COUNT	; token lookup table (XT->CFA)
!if WIDEDICT {
+hmbuffer ~TOKBANK, TOKEN_COUNT	; bank of each word's CFA (0 = home bank)
+hmbuffer ~_dictbank, 1		; bank HERE currently allocates in (0 for now)
+hmbuffer ~irq_save_ribank, 1	; _ribank across an IRQ Forth callback
+hmbuffer ~irq_save_bank, 1	; code-bank register across an IRQ callback
+hmbuffer ~irq_save_bank2, 1	; ROM mode: $00 data window across an IRQ
FARBANK = 2		; high-RAM bank holding the dictionary extension.
			; NOT bank 1: the KERNAL keeps keyboard/editor state
			; there. The extension is addressed THROUGH THE BANKED
			; WINDOW ($A000-$BFFF, RAM bank register $00) which is
			; pinned to FARBANK as Forth's resting state - data and
			; code there behave like ordinary near memory, so no
			; special far addressing is needed anywhere. (65816 DBR
			; addressing does NOT reach the window - both x16emu and
			; the hardware route $A000-$BFFF via the register.)
FARBASE = $A000		; the window; no near RAM pointer is ever >= $A000
FARTOP = $BF00		; leave slack below $BFFF

!if WD_ROMBANKS {
CBANKREG = $01		; code banks: ROM-bank register / $C000 window
CWIN_BASE = $C000
CWIN_TOP = $FE00	; $FE00-$FFFF reserved: IRQ stub + vectors tail
CBANK_FIRST = 33	; bank 32 = the Forth cart itself
CBANK_LAST = 255
} else {
CBANKREG = $00		; code banks: RAM-bank register / $A000 window
CWIN_BASE = $A000
CWIN_TOP = $BF00
			; RAM mode allocates code banks from the TOP of RAM
			; DOWNWARD (MEMTOP-1, -2, ...) while x16edit grows from
			; bank 10 UP - they only meet under a giant dict AND a
			; giant document. EDIT is capped just below Forth's
			; lowest bank so the editor can never overwrite it.
CBANK_FLOOR = 2		; never descend into the KERNAL's banks 0/1
}
PER_BANK = CWIN_TOP - CWIN_BASE	; usable bytes per code bank
WD_HEADROOM = $0400	; xcreate switches banks when less than this remains
+hmbuffer ~_memtop, 2		; current allocation limit (MEMTOP or FARTOP)
+hmbuffer ~_nearhere, 2		; near-dict end recorded at the allocation switch
				; (SAVE-IMAGE's .DIC must stop there, not at HERE)
+hmbuffer ~_chere, 2		; code-space allocation pointer (in CWIN window)
+hmbuffer ~_codebank, 1		; code bank _chere allocates in (0 = none claimed)
+hmbuffer ~_codetop, 1		; RAM mode: highest usable RAM bank (MEMTOP-1)
+hmbuffer ~_dhere, 2		; data-space HERE parked while compiling a body
+hmbuffer ~_dmemtop, 2		; data-space limit parked while compiling
+hmbuffer ~_incode, 1		; nonzero while HERE is swapped to code space
+hmbuffer ~_cbanks_ok, 1	; coldstart probe: code banks writable?
+hmbuffer ~kirq_vec, 2		; captured bank-0 native IRQ handler ($FFEE)
+hmbuffer ~knmi_vec, 2		; captured bank-0 native NMI handler ($FFEA)
+hmbuffer ~BSTK, 256		; bank stack: one byte per call-frame depth
+hmbuffer ~_bsp, 1		; bank stack pointer (index of next free slot)
+hmbuffer ~irq_save_bsp, 1	; _bsp across an IRQ Forth callback
+hmbuffer ~_ribank, 1		; bank of the token stream _ri points into
				; (0 = home). Not zero-page - the zp block is
				; full, and this is only ever loaded/stored
				; directly, never used as a pointer.
!if WD_FARHDR {
+hmbuffer ~_latestbank, 1	; code bank of the LATEST header (0 = near)
+hmbuffer ~_scanbank, 1		; bank of the header being examined; the
				; chain walkers (xfind/nextword/WORDS/FORGET)
				; keep it in step, wdhpeek/wdhcpeek read via it
+hmbuffer ~_vocsbank, WORDLISTS	; per-wordlist code bank of the head NFA
}
}
+hmbuffer ~RSTACK, RSIZE		; return stack
+hmbuffer ~DSTACK, DSIZE		; data stack

!if X16 {
!if FPCORE {
+hmbuffer ~FSTACK, 80		; floating-point stack: 16 x 5-byte MFLPT floats
FSTACK_TOP = FSTACK + 80
+hmbuffer ~fsp, 2		; float-stack pointer - MUST be in RAM (was inline in x16.asm,
				; which is read-only in the ROM build -> FP wrote to $0000). Set at cold start.
}

; State for the IRQ Forth-callback (see x16.asm). Kept in RAM (not in the code
; image) so it works when the interpreter runs from ROM later.
+hmbuffer ~irq_save, 20		; saved VM zero-page registers (_ri.._scratch_2)
!if FPCORE {
+hmbuffer ~irq_save_fsp, 2	; saved float-stack pointer
}
; Private data/return stacks for the callback. Re-entering the (non-atomic)
; push/pop routines on the foreground's stacks would corrupt a half-finished
; operation, so the callback runs on its own stacks. Keep callbacks shallow.
+hmbuffer ~irq_rstack, 64
+hmbuffer ~irq_dstack, 64
IRQ_RSTACK_TOP = irq_rstack + 64 - 2
IRQ_DSTACK_TOP = irq_dstack + 64 - 2
+hmbuffer ~irq_cb_token, 2	; callback execution token (0 = none)
+hmbuffer ~irq_chain, 2		; original CINV vector to chain to
+hmbuffer ~irq_saved_sp, 1	; 6502 stack pointer captured on IRQ entry
+hmbuffer ~irq_save_sc, 1	; saved _stopcheck (STOP-key check suppressed in the callback)
+hmbuffer ~irq_busy, 1		; re-entrancy guard while a callback runs
+hmbuffer ~irq_armed, 1		; non-zero when our handler is installed
; VSYNC frame counter: a tiny RAM IRQ stub (frame_isr, copied from a template on
; first use) hooks CINV, bumps frame_tick every VSYNC, and chains. VSYNC waits
; for frame_tick to change -> exactly one wait per video frame. All in RAM so it
; works in the ROM build too (no bank switch needed).
+hmbuffer ~frame_tick, 1	; incremented once per frame by the stub
+hmbuffer ~frame_chain, 2	; previous CINV vector the stub chains to
+hmbuffer ~frame_isr, 6		; the 6-byte stub lives here (RAM, so CINV can reach it)
}

!if X16 {
!if FPCORE = 0 {
; action vector for the >FLOAT hook (see x16prims.asm) - must be RAM because
; the word body itself may be in ROM. Coldstart points it at tofloat_stub.
+hmbuffer ~tofloat_vec, 2
}
}

; SAVE-IMAGE/LOAD-IMAGE turnkey: 64-byte buffer holding the saved dictionary-state
; zero-page block (see x16.asm).
!if WD_FARHDR {
+hmbuffer ~IMGBUF, 96		; +82 bytes of .VAR state (far-header fields)
} else if WIDEDICT {
+hmbuffer ~IMGBUF, 80		; +71 bytes of .VAR state (code-bank fields)
} else {
+hmbuffer ~IMGBUF, 64
}
; RAM copy of the image filename, built as <basename> + ".DIC"/".TOK"/".VAR".
; SAVE-IMAGE/LOAD-IMAGE take the base name on the stack ( c-addr u -- ), copy it
; here, append the suffix, then SETNAM. The buffer lives in RAM (readable in any
; bank) because the bridged KERNAL runs with bank 0 mapped. 16-char base + 4-char
; suffix = 20 (the KERNAL/CBM filename limit is 16, but the extra headroom is free).
+hmbuffer ~imgnam, 20
+hmbuffer ~imgbaselen, 1		; length of the copied base name
; SYSCALL builds a tiny "jsr JSRFAR / .word target / .byte 0 / rts" trampoline here
; at run time so it can call an arbitrary KERNAL routine (dynamic target) in bank 0
; from the bank-9 Forth ROM. In RAM so it is executable and (in ROM) modifiable.
+hmbuffer ~syscall_stub, 8
; CATCH/THROW: the current exception frame (0 = none). See EXCEPTION wordset.
+hmbuffer ~exc_handler, 2
; EDIT saves Forth's zero page ($22-$7F, 94 bytes) here across x16edit. Must be
; RAM: in the bank-9 ROM the code section is read-only, so this cannot be inline.
+hmbuffer ~edit_zpsave, $5e

!if FASTLOAD {
; Hash index over the (fixed, static) CORE dictionary, built once at
; coldstart. FIND's linear near-list scan (fast, favors self-references in
; user-compiled code) is unchanged; when that scan reaches forth_system_n
; (the boundary into the large static core section) it jumps to hash_lookup
; instead of continuing the slow linear walk (~440 named core words).
; Layout (compact bucket slices, not linked chains): HASHNFA is a contiguous
; array of 2-byte NFAs grouped by hash bucket; HASHIDX[b] points at the
; START of bucket b's slice and HASHIDX[b+1] at its end (129 entries, the
; last is the sentinel end-of-everything). Named core words only - nameless
; internal words can't be found by name, and zero-length lookups stay on
; the linear path. If the core ever outgrows HASHNFA_MAX, build_hashtable
; leaves hash_ok=0 and every lookup silently stays linear (degrades to
; slow, never to corrupt). See build_hashtable/hash_lookup.
HASH_BUCKETS = 128
HASH_MASK = HASH_BUCKETS-1
HASHNFA_MAX = 512		; named core words are ~442 as of this writing
; HASHNFA lives in the X16's golden RAM ($0400-$07FF, unused by this PRG
; build) - 512 entries x 2 bytes fills the 1KB block exactly and keeps that
; kilobyte out of the dictionary space. CAVEAT: x16edit also uses golden RAM,
; so EDIT rebuilds the table (jsr build_hashtable, idempotent) after the
; editor returns - see x16.asm.
HASHNFA = $0400
+hmbuffer ~HASHIDX, 2*HASH_BUCKETS+2	; bucket -> slice start; [128] = end sentinel
+hmbuffer ~hash_ok, 1			; 1 = table valid; 0 = fall back to linear
+hmbuffer ~rgn_ior, 1			; readgen_native: READST error bits latched
					; during the read = READ-LINE/READ-FILE ior
HASHNFA_END = HASHNFA + 2*HASHNFA_MAX
}

!if X16ROM {
; --- KERNAL bridge (v3 run-from-ROM) --------------------------------------
; A bank at $C000 cannot call the KERNAL ($FFxx) directly - that window is the
; bank itself. So the 12 KERNAL entries below become RAM trampolines: each
; saves the ROM bank, selects bank 0, JSRs the real routine, restores the bank
; (preserving A/X/Y and flags/carry). brg_template (in ROM) is copied to brg_ram
; at cold start; the KERNAL symbols point at the trampolines so no call site
; changes. TODO: JSRFAR (FP/audio) and the hard-coded jsr $FFxx (PLOT, SCREEN,
; LOAD, SAVE, entropy) are not bridged yet - those words won't work in ROM mode.
BRIDGE_LEN = 26			; bytes per trampoline (see the ktramp macro)
+hmbuffer ~brg_ram, 512		; the 12 trampolines live here in RAM
+hmbuffer ~brg_save, 1		; scratch for the saved ROM bank
SETLFS = brg_ram + 0*BRIDGE_LEN
SETNAM = brg_ram + 1*BRIDGE_LEN
OPEN   = brg_ram + 2*BRIDGE_LEN
CLOSE  = brg_ram + 3*BRIDGE_LEN
CHKIN  = brg_ram + 4*BRIDGE_LEN
CHKOUT = brg_ram + 5*BRIDGE_LEN
CLRCHN = brg_ram + 6*BRIDGE_LEN
CHRIN  = brg_ram + 7*BRIDGE_LEN
CHROUT = brg_ram + 8*BRIDGE_LEN
GETIN  = brg_ram + 9*BRIDGE_LEN
READST = brg_ram + 10*BRIDGE_LEN
STOP   = brg_ram + 11*BRIDGE_LEN
; hard-coded KERNAL calls, converted to symbols so they bridge too:
KLOAD      = brg_ram + 12*BRIDGE_LEN	; $FFD5 LOAD
KSAVE      = brg_ram + 13*BRIDGE_LEN	; $FFD8 SAVE
PLOT       = brg_ram + 14*BRIDGE_LEN	; $FFF0 PLOT
SCREENMODE = brg_ram + 15*BRIDGE_LEN	; $FF5F screen_mode
ENTROPY    = brg_ram + 16*BRIDGE_LEN	; $FECF entropy_get
RDTIM      = brg_ram + 17*BRIDGE_LEN	; $FFDE rdtim (jiffy clock; used by SLEEP/VSYNC)
; RAM IRQ trampoline (ROM mode): the KERNAL's jmp (CINV) runs with ROM bank 0
; selected, but irq_handler lives in bank 9, so CINV must point at this RAM stub
; which crosses into bank 9, runs the handler, restores the bank, then chains.
; Lives just past the KERNAL trampolines; its template is copied with them.
bridge_irq = brg_ram + 18*BRIDGE_LEN

; jsrfar (FP bank 4 / audio bank $0A) support. brg_jsrfar (ROM, bank 9) is the
; ROM part of the KERNAL jsrfar (inc/jsrfar.inc) ported into our bank: it reads
; the inline target/bank, then jmp's to the KERNAL's RAM part jsrfar3 ($02C4)
; which crosses to the target bank (via jmpfr), calls it, restores our bank, and
; returns to the caller. This is exactly how the KERNAL's own jsrfar works.
imparm   = $82		; zp scratch pointer (outside Forth's $22-$7F zone)
jmpfr    = $02df	; KERNAL RAM "jmp $xxxx" (jsrfar sets its operand, then calls it)
jsrfar3  = $02c4	; KERNAL RAM part of jsrfar (does the ROM-bank crossing)

; One bridge trampoline. Position-independent (only touches $01, brg_save, the
; fixed $FFxx target); copied verbatim from ROM to RAM. --cpu 6502: no STZ.
!macro ktramp .kaddr {
	php
	pha
	lda $01			; ROM_SEL: save current ROM bank
	sta brg_save
	lda #0			; KERNAL is ROM bank 0
	sta $01
	pla
	plp
	jsr .kaddr		; call the real KERNAL routine
	php
	pha
	lda brg_save		; restore our ROM bank
	sta $01
	pla
	plp
	rts
}
}

!if F256 {
+hmbuffer ~_streambuffer, 8*64		; filesystem read buffers. Using 64-byte buffers as there is actual limit
+hmbuffer ~_streamptr, 8		; in ReadData in microkernel for IEC devices. Should be good enough for SD
+hmbuffer ~_streamload, 8		; card anyway
+hmbuffer ~_streamid, 8			; the Forth system will be using buffer IDs instead of direct stream IDs
}

+hmbuffer ~_ibuf, 7*100			; seven 100-char buffers for INCLUDE-FILE
+hmbuffer ~_sbuf, 2*100			; two 100-char buffers for S" / S\"
+hmbuffer ~_fnamebuf, 100		; buffer for filename storage only

+hmbuffer ~_tib, 100			; input buffer (reserving 100 bytes although only 81 are really needed)
+hmbuffer ~_wordbuf, 100		; buffer to hold result of WORD (reserving 100 bytes)
+hmbuffer ~_pad, 100			; PAD buffer
+hmbuffer ~_hld, 100			; pointer for pictured numeric output, the 98-byte buffer follow
_hldend = _hld + 100

+hmbuffer ~_sourcestack_bottom, 120		; end of the stack for sources (120 bytes to accomodate 7 files and default)
_sourcestack = _sourcestack_bottom + 120

+high_memory_end ~MEMTOP

RSTACK_INIT = RSTACK + RSIZE - 2
DSTACK_INIT = DSTACK + DSIZE - 2*SSAFE - 2
; STACKLIMIT is compared by ?STACK against DEPTH, which is measured in CELLS, so
; the limit must also be a cell count. DSIZE is in bytes; DSIZE/2 is the stack's
; cell capacity, less SSAFE reserved cells at each end. (The old value DSIZE-4*SSAFE
; was a byte count - ~2x the real capacity - so a data-stack overflow of a few
; hundred cells was never detected and silently corrupted the adjacent buffers.
; This value still catches underflow too: DEPTH does a logical shift, so an
; underflowed stack pointer reads back as a large positive value, above the limit.)
STACKLIMIT = DSIZE/2 - 2*SSAFE


; Some commonly used 6502 idioms. Note that ACME does not allow passing immediate values to macros...

!macro add .op {
	clc
	adc #.op
}

!macro sub .op {
	sec
	sbc #.op
}

; These stay the original unconditional 8-bit A(low):X(high) pair convention
; even in NATIVE816 builds - NEXT/CALL/RETURN/CREATE/FIND/DOES>/the trampoline
; use them and stay permanently 8-bit (see the coldstart comment above). A
; converted +code word body that wants a native single-16-bit-A cell value
; just uses a plain "lda"/"sta" directly inside its own REP #$20 bracket -
; no macro needed there, since one native instruction already does the job
; these macros need two 8-bit instructions for.
!macro ldax .addr {
	lda .addr
	ldx .addr+1
}

!macro stax .addr {
	sta .addr
	stx .addr+1
}

; Small increment on A/X
!macro incax .op {
	clc
	adc #.op
	bcc +
	inx
+
}

!macro decax .op {
	sec
	sbc #.op
	bcs +
	dex
+
}

!macro incmem .addr, .val {
	lda .addr
	clc
	adc #.val
	sta .addr
	bcc +
	inc .addr+1
+
}

!macro inc16 .addr {
	inc .addr
	bne +
	inc .addr+1
+
}

!macro dec16 .addr {
	pha
	lda .addr
	bne +
	dec .addr+1
+	dec .addr
	pla
}

!macro bra .addr {
	!if F256 {
		bra .addr
	} else {
		jmp .addr
	}
}

; Fetch one byte of the token stream: lda (_ri),y honoring the stream's bank.
; WIDEDICT: colon-word bodies may live outside the home bank; _ribank tags
; the bank of the stream _ri points into. The far path brackets ONLY the
; fetch with a DBR switch (phb / set / fetch / plb) - DBR is 0 everywhere
; else, so no other code is affected. Label-free (byte-counted branches)
; because this expands inside several zones whose local labels would clash.
!macro ldri {
	lda (_ri),y	; token streams are always CPU-visible: near RAM or the
			; code-bank window with its register pinned by CALL
}

; Stack access is behind macros so it is easier to change in the future

!macro rpush {
	jsr push_rstack
}

!macro rpop {
	jsr pop_rstack
}

!macro dpush {
	jsr push_dstack
}

!macro dpop {
	jsr pop_dstack
}

; Elements of Forth word definition

; Complete word header including name, flags, and links
!macro header ~.token, ~.label_n, .name, .flags {
.label_n:
	!byte len(.name) +.flags
	!text .name
	!if .label_n-__prev_n < 128 {
		!byte .label_n-__prev_n
	} else {
		!if __prev_n = 0 {
			!byte 0
		} else {
			!byte ((.label_n-__prev_n) >> 8) | $80, (.label_n-__prev_n) & $FF
		}
	}
	!if __hide_tokens = 0 {
		.token = __prev_token + 1
		!set __prev_token = .token
	} else {
		!set __prev_token = __prev_token + 1
	}
	!set __prev_n = .label_n
}

!macro header ~.token, ~.label_n, .name {
	+header ~.token, ~.label_n, .name, 0
}

!macro header ~.token, ~.label_n {
	+header ~.token, ~.label_n, "", 0
}

!macro header {
.label_n:
	!byte 0
	!byte 0
.token = 15	; tokens 0-15 have special meaning extending tokens past 8 bit
	!set __prev_token = .token
	!set __prev_n = .label_n
	!set __hide_tokens = 0
}

!macro check_token_range {
	!if __prev_token >= $100 {
		!error "Out of short tokens!"
	} else if __prev_token >= $fa {
		!warn "Running low on short tokens!"
	}
	!set __hide_tokens = 1
}

!macro ignore_token_range {
	!set __hide_tokens = 0
}

; Beginning of a compiled Forth word. Tokens follow
!macro forth {
	rts
}

; Beginning of a native code word. Assembler codes follow
!macro code {
}

!macro goforth {
	jsr contforth
}

; Passing execution to native code elsewhere
!macro code .a {
	jmp .a
}

; 16-bit value (typically for preceeding LIT token). Can be a native address
!macro value .v {
	!word .v
}

; Similarly, 8-bite value for BLIT
!macro bvalue .v {
	!byte .v
}

; Address (typically for preceeding BRANCH or ?BRANCH tokens)
!macro address .a {
	!word .a
}

; Short relative address for BBRANCH and ?BBRANCH
!macro baddress .a {
	!byte .a-*
}

; Pascal-style string
!macro string .s {
	!byte len(.s)
	!text .s
}

; One to eight tokens per line
!macro token .t1 {
	!byte .t1
}

!macro token .t1, .t2 {
	!byte .t1, .t2
}

!macro token .t1, .t2, .t3 {
	!byte .t1, .t2, .t3
}

!macro token .t1, .t2, .t3, .t4 {
	!byte .t1, .t2, .t3, .t4
}

!macro token .t1, .t2, .t3, .t4, .t5 {
	!byte .t1, .t2, .t3, .t4, .t5
}

!macro token .t1, .t2, .t3, .t4, .t5, .t6 {
	!byte .t1, .t2, .t3, .t4, .t5, .t6
}

!macro token .t1, .t2, .t3, .t4, .t5, .t6, .t7 {
	!byte .t1, .t2, .t3, .t4, .t5, .t6, .t7
}

!macro token .t1, .t2, .t3, .t4, .t5, .t6, .t7, .t8 {
	!byte .t1, .t2, .t3, .t4, .t5, .t6, .t7, .t8
}

!macro literal .val {
	!ifdef .val {
		!if .val < 256 {
			+token blit
			+bvalue .val
		} else {
			+token lit
			+value .val
		}
	} else {
		+token lit			; all forward refs (not first pass) should be large values
		+value .val
	}
}

; Unfortunately, cannot create a single macro to automatically choose the right path -
; it causes "Symbol already defined" in ACME
!macro branch .addr {
	+token branch
	+address .addr
}

!macro branch_fwd .addr {
	+token bbranch
	+baddress .addr
}

!macro qbranch .addr {
	+token qbranch
	+address .addr
}

!macro qbranch_fwd .addr {
	+token qbbranch
	+baddress .addr
}

; This should be placed right before a word to create an identifiable abort message
!macro error_message ~.label {
.label:
	+literal '?'
	+token emit, xabortq
}

; ==============================================================================
; Initialize the system

!if NATIVE816 {
; Enter 65816 native mode (E=0). NEXT/CALL/RETURN/CREATE/FIND/DOES>/the RTS
; trampoline stay 8-bit A/X permanently and are UNCHANGED from the 6502
; version - NEXT's token fetch is byte-grain (one token byte at a time from a
; byte-oriented stream) and does not benefit from a wider accumulator, and the
; trampoline's raw PHA/PLA return-address construction is only correct at
; 8-bit A. So 8-bit-A/X is the PERMANENT RESTING STATE everywhere in this
; file, matching today's behavior exactly. Individual converted +code word
; bodies (the ones doing real 16-bit Forth-cell arithmetic) locally bracket
; just their own body with REP #$20 / SEP #$20 (widen A only, never X/Y) -
; see [[x16-forth-65c816-phase1-progress]] for the full rationale. Native
; mode (vs staying in emulation/E=1) is needed only so those local REP/SEP
; brackets - and later MVN/MVP bulk copies - have any effect at all; SEP/REP
; are no-ops in emulation mode.
	clc
	xce			; E=0 (native mode); C<->E swap, so C was cleared above
	sep #$30		; explicit known-good 8-bit A/X/Y (the resting state below)
	rep #$20		; briefly 16-bit A just to zero D cleanly (avoids stale
	!al			; garbage in the hidden high byte of C leaking into D)
	lda #$0000
	tcd			; D=$0000 - existing zero-page block $22-$7F stays valid
	!as
	sep #$20		; back to the permanent 8-bit-A resting state
	phk
	plb			; DBR = program bank (0) - matches KERNAL/VERA/zero-page
}
	lda #<forth_system_c
	ldx #>forth_system_c
	+stax _ri				; _w does not need to be initialized

	jsr init_rstack
	jsr init_dstack

	lda #0
	sta _sflip
	sta _ibufcount

	sta _tib
	sta _wordbuf

!if C64 {
	sta _openfiles+1
	lda #7			; do not try to open 0-2
	sta _openfiles
} else if F256 {
	jsr f256buffersinit
}

	lda #0			; CATCH/THROW: no exception frame installed yet
	sta exc_handler
	sta exc_handler+1

!if X16 {
!if FPCORE {
	lda #<FSTACK_TOP	; initialize the floating-point stack pointer
	sta fsp
	lda #>FSTACK_TOP
	sta fsp+1
} else {
	lda #<tofloat_stub	; >FLOAT vector: default to "not a float"
	sta tofloat_vec
	lda #>tofloat_stub
	sta tofloat_vec+1
}

	lda #0			; no IRQ callback installed yet
	sta irq_armed
	sta irq_busy
!if WIDEDICT {
	sta _ribank		; token stream starts in the home bank
	sta _incode
	sta _codebank		; no code bank claimed yet
	lda #<MEMTOP
	sta _memtop
	lda #>MEMTOP
	sta _memtop+1
	lda #<CWIN_BASE
	sta _chere
	lda #>CWIN_BASE
	sta _chere+1
!if WD_FARHDR {
	lda #0			; far-header state: everything near until the
	sta _latestbank		; first far create
	sta _scanbank
	ldx #WORDLISTS-1
cold_fhvb:
	sta _vocsbank,x
	dex
	bpl cold_fhvb
}
!if WD_ROMBANKS {
	lda #FARBANK		; resting state: the RAM window shows the
	sta $00			; bank-2 data extension; ROM window = KERNAL
	php			; capture the KERNAL's native-mode IRQ/NMI
	sei			; handlers - the per-bank vector tails route
	lda $01			; through them. The vectors MUST be read from
	pha			; ROM bank 0: a PRG is entered from BASIC with
	lda #0			; bank 4 mapped, and every bank has its own
	sta $01			; vector bytes at $FFEA/$FFEE.
	lda $FFEE
	sta kirq_vec
	lda $FFEF
	sta kirq_vec+1
	lda $FFEA
	sta knmi_vec
	lda $FFEB
	sta knmi_vec+1
	pla
	sta $01
	plp
} else {
	lda #0			; RAM mode: the $00 window is dynamic (code
	sta $00			; banks); no bank-2 data extension
	sec			; MEMTOP read: A = RAM bank count
	jsr $FF99
	sec			; top usable bank = count - 1
	sbc #1
	sta _codetop
}
	; probe: is the first code bank writable RAM? (MiSTer/-cartbin yes;
	; plain emulator ROM area no; stock X16 ROM no)
	php
	sei
	lda CBANKREG
	pha
!if WD_ROMBANKS {
	lda #CBANK_FIRST
} else {
	lda _codetop		; probe the first bank we'd actually claim
}
	sta CBANKREG
	lda CWIN_BASE
	pha			; preserve whatever lives there
	lda #$A5
	sta CWIN_BASE
	lda CWIN_BASE
	cmp #$A5
	bne wd_noprobe
	lda #$5A
	sta CWIN_BASE
	lda CWIN_BASE
	cmp #$5A
	bne wd_noprobe
	lda #1
	sta _cbanks_ok
	pla
	sta CWIN_BASE		; restore the probed byte
	bne wd_probed
	beq wd_probed
wd_noprobe:
	pla			; discard the saved byte (ROM - nothing changed)
	lda #0
	sta _cbanks_ok
wd_probed:
	pla
	sta CBANKREG
	plp
}
}

	lda #<forth_system_n
	ldx #>forth_system_n
	+stax _latest
	
!if CART or X16ROM {
	lda #<$0801
	ldx #>$0801
} else {
	lda #<end_of_image
	ldx #>end_of_image
}

	+stax _here

; In token threaded code we need to generate the mapping of tokens to addresses
	jsr generate_token_table
!if FASTLOAD {
	jsr build_hashtable
}

	lda #<forth_system
	ldx #>forth_system
	+stax _hightoken

; Prep for the Forth words, so RTS will jump to CALL. As call starts with the same
; sequence, it will be consistently repeatable while saving 2 bytes per Forth word
	lda #>call-1
	pha
	lda #<call-1
	pha

; Move the stack top down by one (which technically will move it below bottom, but
; this is fine here), it will be corrected back by the data push below. This allows
; to save quite a bit of memory on words that end with dpush/exit
	inc _dstack
	inc _dstack

; ==============================================================================
; Structure of a vocabulary word in token threaded code:
; offset     length      meaning
;    0          1        n - length of the name and flags (NFA)
;    1          n        name
;    n+1     1 or 2      link to the previous word (LFA)
;  [n+2(3)]     1        prologue, RTS in current model (CFA)
;    ...        x        tokens (PFA)
; This may be quite confusing. LFA is actually a variable length value - it is an
; _offset_ to the previous word (counting between NFAs). If is less than 128, it will
; take one byte. Otherwise it is MSB first with high bit set in MSB - so if the first
; byte has the high bit set, there will be two bytes. One exception - if the first
; byte is $ff, it is the only byte and it links to the last word in core (split memory
; support).
; Native word does not have a prologue, can start immediately after the LFA and should
; be ended with "jmp next". Forth words start with prologue consisting of the instruction
; RTS, that would cause an immediate jump to CALL.
; Most elements of a word definition are hidden behind macros. This is both for readability
; and to make it easier to modify in the future.
; All core words only refer to tokens below 256, so all token references take one byte.
; Note that the tokens are encoded with MSB first, but that MSB is always very small, and
; the implementation treats two-byte tokens as essentially two tokens (see trick in NEXT).

; ==============================================================================
; Inner interpreter
;
; To start the interpreter, RI needs to point to CFA of the first word to execute and NEXT should be executed

; NEXT - execute the word at RI (RI is pointer to CFA), prime the parameter pointer for CALL
;	W = mem(RI)
;	RI += 1		; token size(!)
;	goto mem(W)	; ->token

; Special case for words that end with push to data stack

dpush_and_next:
	+dpush
next:
	ldx #>TOKENS		; note that LSB is assumed to be 0
next_ext:
	ldy #0
	+ldri
	asl
	bcc +
	inx
+:
	inc _ri
	bne +
	inc _ri+1
+:
	+stax _scratch
fragment_1:
	lda (_scratch),y
	sta _w
	iny
	lda (_scratch),y
	sta _w+1
!if WD_FARHDR {
	cmp #>CWIN_BASE		; far-header CFA (in the window)? pin its bank
	bcs nextfar		; (A still = _w+1 high byte)
}
	jmp (_w)
; end of fragment_1

!if WD_FARHDR {
; The callee's header+CFA live in a code bank. token = (_scratch-TOKENS)>>1
; (TOKENS is page-aligned so its low byte is 0); pin $00 = TOKBANK[token] so
; the far RTS/CFA at _w executes from the right bank, then dispatch.
nextfar:
	lda _scratch+1
	sec
	sbc #>TOKENS
	lsr
	sta _rscratch+1		; token high
	lda _scratch		; 2*token low
	ror
	sta _rscratch		; token low
	clc
	lda _rscratch
	adc #<TOKBANK
	sta _rscratch
	lda _rscratch+1
	adc #>TOKBANK
	sta _rscratch+1
	ldy #0
	lda (_rscratch),y
	sta CBANKREG		; window -> callee's bank
	jmp (_w)
}


; Special entry for tokens 0-16 - the jump from next will lead directly here per the token table.
; The assumption is that _scratch has 2x the token id, so the exact page offset required. Token
; 0 is not useful in this context, but it is harmless
prefix_token:
	clc
	lda #>TOKENS
	adc _scratch
	tax
	bne next_ext

; CALL - this will execute the parameters at W
; 	rpush(RI)
;	RI = W+1	; offset for RTS
;	goto NEXT

call:
; prep for the subsequent call
	lda #>call-1
	pha
	lda #<call-1
	pha

; STOP key handler will trigger on every 256th execution of call
	inc _stopcheck
	bne +
!if C64 {
	jsr STOP
} else if F256 {
	bra +
; This causes bad issues with I/O and not really working. Need a better solution
;-:
;	jsr kernel_Yield
;	jsr kernel_NextEvent
;	bcs +
;	lda event_buffer+off_event_type    
;	cmp #kernel_event_key_RELEASED
;	bne -
;	lda event_buffer+off_event_key_flags 
;	and #event_key_META
;	bne +
;	lda event_buffer+off_event_key_ascii
;	cmp #3
} else {
	!error "Not implemented"
}

	bne +
	jmp abort_c
+:

	+ldax _ri
	+rpush
!if WIDEDICT {
	ldx _bsp		; caller's stream bank goes on the separate
	lda _ribank		; bank stack - the main rstack keeps its
	sta BSTK,x		; 1-cell return-address protocol (R> juggling,
	inc _bsp		; loop frames, xcode's frame drop all rely on it)
	; user colon words carry a [RTS][body:2][bank:1] stub; core colon
	; words (all below end_of_image) keep the classic RTS+tokens form
	lda _w+1
	cmp #>end_of_image
	bcc call_classic
	bne call_stub
	lda _w
	cmp #<end_of_image
	bcs call_stub
call_classic:
	; A near word's tokens are in low RAM, so it runs regardless of the
	; window - but words like xloop/xqdo/lit read INLINE data out of the
	; CALLER's body via rfrom+@, which may be far. So the near word
	; INHERITS the caller's bank (leave _ribank / CBANKREG untouched); the
	; matching return: restores it from BSTK to the same value.
	+ldax _w
	+incax 1
	+stax _ri
	jmp next
call_stub:
	ldy #1
	lda (_w),y
	sta _ri
	iny
	lda (_w),y
	sta _ri+1
	iny
	lda (_w),y
	sta _ribank		; 0 = visible body; else the code bank
	sta CBANKREG
	jmp next
}
	+ldax _w
	+incax 1
	+stax _ri
	+bra next

; EXIT - return from the current word to the caller (called "return" here to avoid conflict with EXIT word)
;	RI = rpop()
;	goto NEXT

return:
	+rpop
	+stax _ri
!if WIDEDICT {
	dec _bsp		; unstack the caller's bank and re-pin the
	ldx _bsp		; code-bank register to it
	lda BSTK,x
	sta _ribank
	sta CBANKREG
}
	+bra next

; INVOKE - this will execute word by CFA and continue to the next word (exposed to the language as EXECUTE)
;	W = pop()
;	goto mem(W)

invoke:
	+dpop
invokeax:
	asl
	sta _scratch
	txa
	rol
	adc #>TOKENS
	sta _scratch+1
	ldy #0
!if WIDEDICT {
	jmp fragment_1		; the grown CALL pushed this out of beq range
} else {
	beq fragment_1
}
;	lda (_scratch),y
;	sta _w
;	iny
;	lda (_scratch),y
;	sta _w+1
;	jmp (_w)

; CREATED - push the PFA on the stack (default semantics of a word after CREATE)
;	push(W+3)	; Note the offset 3 here. "Created" words have JMP CREATED prolog, not RTS!
;	goto NEXT

created:
	+ldax _w
	+incax 3
	jmp dpush_and_next

; DOES - semantics applied to the defined word by DOES>. It is an extension of CREATE semantics that redirects
; the execution to the creating word
;	rpush(RI)
;	RI = pop()	; this is supposed to be the return address from the SUB (JSR) instruction, not the top of the Forth stack!
;	push(W+3)	; offset for jmp call - see the above note
;	goto NEXT

does:
	+ldax _ri
	+rpush
!if WIDEDICT {
	ldx _bsp		; same frame contract as CALL; the DOES-body
	lda _ribank		; runs from the DEFINING word's body via the
	sta BSTK,x		; JSR return address. Defining words that use
	inc _bsp		; DOES> stay in VISIBLE space (bank 0) - see the
	lda #0			; _incode guard in xcw_advcheck / colon: far
	sta _ribank		; storage is skipped when a definition will
	sta CBANKREG		; carry a DOES> body (data rule + does rule).
}
	pla
	+add 1		; courtesy of 6502 JSR instruction, the return address is off by one
	sta _ri
	pla
	adc #0
	sta _ri+1
	
	+bra created	; starting with PUSH(W+2) it is the same

; DODEFER - semantics of the word created by DEFER
;	W = mem(W+3)	; offset for jmp dodefer
;	goto mem(W)

dodefer:
	ldy #4
	lda (_w),y
	tax
	dey
	lda (_w),y
	+bra invokeax


; DOVALUE - semantics of a VALUE
;	Assumes a very particular structure: pointer to semantics block followed by value bytes. Semantics block contains
;	three addresses: read semantics, write semantics, compilation semantics
;	push(W+5)			; offset for jmp dovalue and one pointer to semantics block
;	W = mem(mem(W+3))	; offset for jmp dovalue
;	goto mem(W)

dovalue:
	+ldax _w
	+incax 5
	+dpush

	ldy #4
	lda (_w),y
	sta _rscratch+1
	dey
	lda (_w),y
	sta _rscratch	; rscratch -> VALUE word semantics block

	ldy #1
	lda (_rscratch),y
	tax
	dey
	lda (_rscratch),y
	
	+bra invokeax

; A number of Forth words have constant semantics. Typical systems define CONSTANT using DOES> but that wastes a few
; bytes for the call. Using a separate semantic word instead.
;	push mem(W+3)	; offset for jmp doconst
;	goto NEXT

doconst:
	ldy #4
	lda (_w),y
	tax
	dey
	lda (_w),y
	jmp dpush_and_next


; Call to this subroutine (JSR contforth) allows to switch execution from native to Forth. One particular use case
; is error handling as it is easier to setup ABORT" from Forth
contforth:
	pla		; Note that 6502 has the address on the stack off by one, but the code in CALL will compensate by one
	sta _w
	pla
	sta _w+1
	rts



; Return stack and data stack implementations, using correspondingly _rstack and _dstack pointers.
; Note that the data stack has the topmost item stored separately in _dtop

init_rstack:
	lda #<RSTACK_INIT
	ldx #>RSTACK_INIT
	+stax _rstack
!if WIDEDICT {
	lda #0			; bank stack empty (QUIT/ABORT resync)
	sta _bsp
}
	rts

init_dstack:
	lda #<DSTACK_INIT
	ldx #>DSTACK_INIT
	+stax _dstack
	rts

push_rstack:
	ldy #0
	sta (_rstack),y
	iny
	txa
	sta (_rstack),y
	lda _rstack
	bne +
	dec _rstack+1
+:
	dec _rstack
	dec _rstack
	rts
	
pop_rstack:
	ldy #2
	lda (_rstack),y
	inc _rstack
	pha
	lda (_rstack),y
	tax
	pla
	inc _rstack
	bne +
	inc _rstack+1
+:
	rts

push_dstack:
	pha
	ldy #0
	lda _dtop
	sta (_dstack),y
	iny
	lda _dtop+1
	sta (_dstack),y
	pla
	+stax _dtop
	lda _dstack
	bne +
	dec _dstack+1
+:
	dec _dstack
	dec _dstack
	rts

pop_dstack:
	+ldax _dtop
	pha
	ldy #2
	lda (_dstack),y
	sta _dtop
	inc _dstack
	lda (_dstack),y
	sta _dtop+1
	inc _dstack
	bne +
	inc _dstack+1
+:
	pla
	rts

; Binary search for 16-bit value - adapted from code found online
bslow = _rscratch
bshigh = _wscratch
bsmid = _scratch
bsvalue = _dtop

binsearch:
bsloop:
	sec
	lda bshigh
	sbc bslow
	tax
	lda bshigh+1
	sbc bslow+1
	bcc bsdone		; LOW is ABOVE high, no more locations to check. C is 0
	lsr
	tay
	txa
	ror
	and #$fe		; Align to even
	adc bslow
	sta bsmid
	tya
	adc bslow+1
	sta bsmid+1		; At this point MID = LOW + (HIGH-LOW)/2 aligned
	lda bsvalue+1	; Check MSB and perform one of three possible steps below
	ldy #1
	cmp (bsmid),y
	beq bschklsb
	bcc bsmodhigh
bsmodlow:			; Move LOW to be one word above MID
	lda bsmid
	adc #1			; C is 1 as it can only be reached by BCS or fall through BCC
	sta bslow
	lda bsmid+1
	adc #0
	sta bslow+1
	+bra bsloop
bschklsb:			; MSB is matching. Check LSB and adjust HIGH or LOW depending on the value
	lda bsvalue
	dey
	cmp (bsmid),y
	beq bsdone		; MID is pointing at the exact value (and C is 1)
	bcs bsmodlow
bsmodhigh:			; Move HIGH to be one word below MID
	lda bsmid
	sbc #1			; C is 0 at this point as it is only reachable by BCC or fall through BCS
	sta bshigh
	lda bsmid+1
	sbc #0
	sta bshigh+1
	+bra bsloop
bsdone:
	rts


generate_token_table:
	; start scanning from the last word NFA
	lda #<forth_system_n
	ldx #>forth_system_n
	+stax _rscratch
	
	; set current token to be the last
	lda #(forth_system<<1)&$ff
	sta _scratch
	clc
	lda #>TOKENS
	adc #(forth_system<<1)>>8
	sta _scratch+1

gtt_next:
	; get the link
	lda #0
	sta _wscratch+1
	tay
	lda (_rscratch),y
	and #NAMEMASK
	tay
	iny					; name + name byte, now pointing at the LFA
	lda (_rscratch),y
	beq gtt_done
	bpl gtt_offsetok
	and #$7f
	sta _wscratch+1
	iny
	lda (_rscratch),y
gtt_offsetok:
	iny
	sta _wscratch

	; get the actual address
	tya
	clc
	adc _rscratch
	tax
	lda #0
	adc _rscratch+1
	
	; set the current token to that address
	ldy #1
	sta (_scratch),y
	dey
	txa
	sta (_scratch),y

	; step to previous token
	lda _scratch
	bne +
	dec _scratch+1
+:
	dec _scratch
	dec _scratch

	; step to the previous NFA
	jsr rscratch_sub_wscratch
;	sec
;	lda _rscratch
;	sbc _wscratch
;	sta _rscratch
;	lda _rscratch+1
;	sbc _wscratch+1
;	sta _rscratch+1
	+bra gtt_next

gtt_done:

	; fill in the bottom 16 entries with references to prefix_token
	lda #<TOKENS
	ldx #>TOKENS
	+stax _wscratch
	ldy #31
-:
	lda #>prefix_token
	sta (_wscratch),y
	dey
	lda #<prefix_token
	sta (_wscratch),y
	dey
	bpl -

!if WIDEDICT {
	lda #<TOKBANK		; every word starts in the home bank: clear the
	sta _wscratch		; whole bank table and the allocation bank
	lda #>TOKBANK
	sta _wscratch+1
	lda #0
	sta _dictbank
	ldx #>TOKEN_COUNT	; TOKEN_COUNT is page-divisible (asserted above)
	tay
gtt_zerobank:
	sta (_wscratch),y
	iny
	bne gtt_zerobank
	inc _wscratch+1
	dex
	bne gtt_zerobank
}
	rts


rscratch_sub_wscratch: ; Happens more than once, saving a few bytes here
	sec
	lda _rscratch
	sbc _wscratch
	sta _rscratch
	lda _rscratch+1
	sbc _wscratch+1
	sta _rscratch+1
	rts


; ==============================================================================
; Forth vocabulary starts here. This special header form reserves 16 tokens for
; extended token range. This essentially gives 4K-16 possible tokens maximum,
; which should be enough for any configuration (that many tokens will consume
; an 8K table, quite wasteful for common case)
+header

; ==============================================================================
; Hidden words to go from one vocabulary word part to another. All of these take
; one address from the top of the stack and return another

+header ~nfatolfa, ~nfatolfa_n
	+code

!if WD_FARHDR {
	lda _dtop+1		; far record: [len][name][token:2][nearhere:2]
	cmp #>CWIN_BASE		; [link:3] - the "LFA" is the link field at
	bcc +			; NFA+len+5; the len byte reads via _scanbank
	lda CBANKREG
	pha
	lda _scanbank
	sta CBANKREG
	ldy #0
	lda (_dtop),y
	and #NAMEMASK
	tay
	pla
	sta CBANKREG
	tya
	clc
	adc #5
	bcc field_adjust	; always (len+5 <= 36 leaves C clear)
+:
}
	ldy #0
	lda (_dtop),y
	and #NAMEMASK
	clc
	adc #1
field_adjust:
	adc _dtop
	sta _dtop
	bcc +
	inc _dtop+1
+:
	jmp next

+header ~lfatocfa, ~lfatocfa_n
	+code

!if WD_FARHDR {
	lda _dtop+1		; far link field is a fixed 3 bytes; the "CFA"
	cmp #>CWIN_BASE		; is the record end (colon: the real far stub;
	bcc +			; data words: fictional, only token@-7 is read)
	lda #3
	clc
	bcc field_adjust
+:
}
	ldy #0
	lda (_dtop),y
	bpl +
	iny
+:
	iny
	tya
	clc
	bcc field_adjust ; identical code and can use C==0 here
;	adc _dtop
;	sta _dtop
;	bcc +
;	inc _dtop+1
;+:
;	jmp next

!if WD_FARHDR {
; The short-token space is completely full, and the only user of the two
; hidden navigators below (the classic xforget) is compiled out in far-header
; builds - so their token slots are recycled for the header-window readers.
+header ~wdhpeek, ~wdhpeek_n	; ( a-addr -- x ) @ via _scanbank (headers)
	+code
	lda CBANKREG
	pha
	lda _scanbank
	sta CBANKREG
	ldy #1
	lda (_dtop),y
	tax
	dey
	lda (_dtop),y
	tay
	pla
	sta CBANKREG
	sty _dtop
	stx _dtop+1
	jmp next

+header ~wdhcpeek, ~wdhcpeek_n	; ( c-addr -- c ) C@ via _scanbank (headers)
	+code
	lda CBANKREG
	pha
	lda _scanbank
	sta CBANKREG
	ldy #0
	lda (_dtop),y
	tax
	pla
	sta CBANKREG
	stx _dtop
	lda #0
	sta _dtop+1
	jmp next
} else {
+header ~cfatolfa, ~cfatolfa_n
	+forth
	+token dup, twominus, cpeek
	+literal $80
	+token and_op
	+qbranch_fwd cfatolfa_1
	+token oneminus
cfatolfa_1:
	+token oneminus, exit


; This is one of the less trivial transitions in the current model. There is a trap here -
; using namemask to isolate just the low 5 bits of the length field is unsafe, it may
; misidentify bytes as length bytes (e.g., "AB" will break it). This means that there is only
; one bit for flags in that field.
+header ~lfatonfa, ~lfatonfa_n	; known in some dialects as L>NAME
	+forth
	+token oneminus, zero
lfatonfa_next:
	+token over, cpeek
	+literal $7f
	+token and_op, over, notequal
	+qbranch_fwd lfatonfa_found
	+token swap, oneminus, swap, oneplus, dup
	+literal 31
	+token greater
	+qbranch lfatonfa_next
	+token twodrop, zero, exit
lfatonfa_found:
	+token drop, exit
}

+header ~xttocfa, ~xttocfa_n
	+code
	asl _dtop
	rol _dtop+1
	lda #>TOKENS
	adc _dtop+1		; note that C is guaranteed to be 0 here
	sta _dtop+1
	jmp fragment_peek
;	ldy #1
;	lda (_dtop),y
;	tax
;	dey
;	lda (_dtop),y
;	+stax _dtop
;	jmp next


; ==============================================================================
; A very important word to translate CFA to XT

+header ~cfatoxt, ~cfatoxt_n
	+code

!if WD_FARHDR {
; Far-header records store their own token 7 bytes before the record end
; (which is what lfatocfa produces as the "CFA"), so no table search is
; needed - and none would work: window CFAs repeat across banks, so the
; user half of TOKENS is not value-sorted anymore.
	lda _dtop+1
	cmp #>CWIN_BASE
	bcc cfatoxt_near
	sec
	lda _dtop
	sbc #7
	sta _dtop
	bcs +
	dec _dtop+1
+:
	lda CBANKREG
	pha
	lda _scanbank
	sta CBANKREG
	ldy #0
	lda (_dtop),y
	tax
	iny
	lda (_dtop),y
	tay
	pla
	sta CBANKREG
	stx _dtop
	sty _dtop+1
	jmp next
cfatoxt_near:
}
; The code needs to be prepared for split system with core and compiled words in
; different parts of RAM. For that purpose binsearch should be called twice (words
; are sorted within each part)
; TOKENS to TOKENS+2*forth_system

; Prep for binsearch: _rscratch points to TOKENS, _wscratch is TOKENS+2*_hightoken
	lda #0
	sta _rscratch
	lda #<forth_system
	asl
	sta _wscratch
	sta _scratch_1
	lda #>TOKENS
	sta _rscratch+1
	lda #>forth_system
	rol
	adc #>TOKENS
	sta _wscratch+1
	sta _scratch_1+1

	jsr binsearch
	bcs cfatoxt_found

; TOKENS+2*forth_system+2 to TOKENS+2*_hightoken
	lda _scratch_1	; No need to clear C here as it was left 0 by the previous binsearch!
	adc #2
	sta _rscratch
	lda _scratch_1+1
	adc #0
	sta _rscratch+1
	lda _hightoken
	asl
	sta _wscratch
	lda _hightoken+1
	rol
	adc #>TOKENS
	sta _wscratch+1

	jsr binsearch

cfatoxt_found:		; Unless the system is broken, something has to be found and C is set!
	lda _scratch
	sbc #<TOKENS
	sta _dtop
	lda _scratch+1
	sbc #>TOKENS
	lsr
	sta _dtop+1
	ror _dtop
	jmp next

; ==============================================================================
; code exit
; code execute
; : quit (sst) ;code
; code abort
;

; EXIT is used to return from any word.
+header ~exit, ~exit_n, "EXIT"
	+code return

; Execute the word by address on the stack
+header ~execute, ~execute_n, "EXECUTE"
	+code invoke

; --- Exception handling: Forth 2012 EXCEPTION wordset ----------------------
; CATCH ( i*x xt -- j*x 0 | i*x n ) runs xt; returns 0 on normal completion, or
; the code n given to THROW, having restored the data & return stacks. THROW
; ( k*x n -- k*x | i*x n ) with n=0 is a no-op; otherwise it unwinds to the most
; recent CATCH. An uncaught THROW (no handler) performs ABORT. Classic Ragsdale
; implementation: the frame (prev-handler, saved SP) sits on the return stack and
; exc_handler points at it. SP@/RP@ read the stack pointers (TOS is cached in
; _dtop, so the memory pointers _dstack/_rstack are what save/restore).
+header ~spat, ~spat_n, "SP@"
	+code
	+ldax _dstack
	jmp dpush_and_next

+header ~rpat, ~rpat_n, "RP@"
	+code
	+ldax _rstack
	jmp dpush_and_next

+header ~handler, ~handler_n, "HANDLER"
	+code
	lda #<exc_handler
	ldx #>exc_handler
	jmp dpush_and_next

+header ~catch, ~catch_n, "CATCH"
	+forth
!if WIDEDICT {
	+literal _bsp		; bank-stack depth, restored by THROW
	+token cpeek, tor	; (via C@ - the short-token space is full)
}
	+token spat, tor, handler, peek, tor, rpat, handler, poke
	+token execute
	+token rfrom, handler, poke, rfrom, drop
!if WIDEDICT {
	+token rfrom, drop	; the bank-stack depth cell
}
	+token zero, exit

+header ~throw, ~throw_n, "THROW"
	+code
	lda _dtop			; n = 0 ?  -> drop and continue
	ora _dtop+1
	bne throw_do
	+dpop
	jmp next
throw_do:
	lda _dtop			; stash n on the CPU stack
	pha
	lda _dtop+1
	pha
	lda exc_handler			; no handler installed -> uncaught -> ABORT
	ora exc_handler+1
	bne throw_have
	pla
	pla
	jmp abort_c
throw_have:
	lda exc_handler			; restore return stack to the CATCH frame
	sta _rstack
	lda exc_handler+1
	sta _rstack+1
	jsr pop_rstack			; R> handler ! : previous handler
	sta exc_handler
	stx exc_handler+1
	jsr pop_rstack			; R> : saved SP -> _dstack
	sta _dstack
	stx _dstack+1
!if WIDEDICT {
	jsr pop_rstack			; R> : bank-stack depth as of CATCH entry
	sta _bsp
}
	jsr pop_dstack			; drop to the i*x below xt (TOS <- top of i*x)
	pla				; n back off the CPU stack
	tax
	pla
	jsr push_dstack			; push n as the result
	+rpop				; return to CATCH's caller with ( i*x n )
	+stax _ri
!if WIDEDICT {
	dec _bsp			; and its bank-stack entry, as RETURN would
	ldx _bsp
	lda BSTK,x
	sta _ribank
	sta CBANKREG
}
	jmp next

; Reset data stack and perform QUIT.
+header ~abort, ~abort_n, "ABORT"
	+code
abort_c:
	jsr init_dstack
	jmp quit_c

; Somehow this ended being a common byte sequence (8 instances), so we can save a few bytes here
+header ~twominus_zero_over_poke, ~twominus_zero_over_poke_n
	+forth
	+token twominus, zero, over, poke, exit

;
; : (sst) _sourcestack
;         2- 0 over ! 2- _tib over ! 2- 0 over ! 2- 0 over ! 2- 4 over !
;         _source ! 0 dup _sflip ! _ibufcount c! ; nonstandard
;

+header ~xsst, ~xsst_n			; Reset source stack
	+forth
	+literal _sourcestack
	+token twominus_zero_over_poke			; #TIB
	+token twominus
	+literal _tib
	+token over, poke						; TIB
	+token twominus_zero_over_poke			; >IN
	+token twominus_zero_over_poke			; SOURCE-ID
	+token twominus
	+literal $04
	+token over, poke		; standard input has 4 parameters: 0, >IN, TIB, #TIB
	+literal _source
	+token poke
	+token zero, dup
	+literal _sflip
	+token cpoke
	+literal _ibufcount
	+token cpoke, exit

; ==============================================================================
; Integer math

; Adding special constants for small numbers that are used very often. This makes both interpretation
; and execution a little bit more efficient.
;
; 0 constant 0
; 1 constant 1
; 2 constant 2
; -1 constant -1
;

+header ~zero, ~zero_n, "0"
	+code doconst
	+value $0000

+header ~one, ~one_n, "1"
	+code doconst
	+value $0001

+header ~two, ~two_n, "2"
	+code doconst
	+value $0002

+header ~minusone, ~minusone_n, "-1"
	+code doconst
	+value $FFFF

; The alternative high-level implementations are particularly useful on
; platforms without native multiplication or division.
;
; code +
; code -
; code *        alt: : * m* drop ;
; code /        alt: : / /mod nip ;
; code mod      alt: : mod /mod drop ;
; code /mod     alt: : /mod >r s>d r> sm/rem ;
; code */mod    alt: : */mod >r m* r> sm/rem ;
; code */       alt: : */ */mod nip ;
;

+header ~add, ~add_n, "+"
	+code
	+dpop
	clc
	adc _dtop
	sta _dtop
	txa
	adc _dtop+1
	sta _dtop+1
	jmp next

+header ~sub, ~sub_n, "-"
	+code
	+dpop
	+stax _rscratch
	lda _dtop
	sec
	sbc _rscratch
	sta _dtop
	lda _dtop+1
	sbc _rscratch+1
	sta _dtop+1
	jmp next

+header ~mult, ~mult_n, "*"
	+forth
	+token mmult, drop, exit

+header ~divmod, ~divmod_n, "/MOD"
	+forth
	+token tor, stod, rfrom, smrem, exit

+header ~multdivmod, ~multdivmod_n, "*/MOD"
	+forth
	+token tor, mmult, rfrom, smrem, exit

;
; code abs		alt: abs dup 0< if negate then ;
; code negate
; code 1+		alt:	: 1+ 1 + ;
; code 1-		alt:	: 1- 1 - ;
; code 2+		alt:	: 2+ 2 + ;
; code 2-		alt:	: 2- 2 - ;
; code 2/		alt:	: 2/ 2 / ;
; code 2*		alt:	: 2* 2 * ;
;

+header ~abs, ~abs_n, "ABS"
	+code
	lda _dtop+1
	bmi negate_c
	jmp next

+header ~negate, ~negate_n, "NEGATE"
	+code
negate_c:
	lda #0
	sec
	sbc _dtop
	sta _dtop
	lda #0
	sbc _dtop+1
	sta _dtop+1
	jmp next

+header ~oneplus, ~oneplus_n, "1+"
	+code
	inc _dtop
	bne +
	inc _dtop+1
+:
	jmp next

+header ~oneminus, ~oneminus_n, "1-"
	+code
	lda _dtop
	bne +
	dec _dtop+1
+:
	dec _dtop
	jmp next

+header ~twoplus, ~twoplus_n, "2+"
	+code
	+incmem _dtop, 2
	jmp next

+header ~twominus, ~twominus_n, "2-"
	+code
	+ldax _dtop
	+decax 2
	+stax _dtop
	jmp next

+header ~twodiv, ~twodiv_n, "2/"
	+code
	lda _dtop+1
	cmp #$80		; 6502 does not have native arithmetic shift right 
	ror _dtop+1
	ror _dtop
	jmp next

+header ~twomult, ~twomult_n, "2*"
	+code
	asl _dtop
	rol _dtop+1
	jmp next

;
; code lshift
; code rshift
;

!if NATIVE816 {
; NATIVE816: each iteration's 2-instruction 8-bit shift-pair on the _dtop
; cell fuses to one native 16-bit shift - same loop, same iteration count.
+header ~lshift, ~lshift_n, "LSHIFT"
	+code
	+dpop
	tax
	beq lshift_2
	rep #$20
lshift_1:
	clc
	asl _dtop
	dex
	bne lshift_1
	sep #$20
lshift_2:
	jmp next

+header ~rshift, ~rshift_n, "RSHIFT"
	+code
	+dpop
	tax
	beq rshift_2
	rep #$20
rshift_1:
	lsr _dtop
	dex
	bne rshift_1
	sep #$20
rshift_2:
	jmp next
} else {
+header ~lshift, ~lshift_n, "LSHIFT"
	+code
	+dpop
	tax
	beq lshift_2
lshift_1:
	clc
	asl _dtop
	rol _dtop+1
	dex
	bne lshift_1
lshift_2:
	jmp next

+header ~rshift, ~rshift_n, "RSHIFT"
	+code
	+dpop
	tax
	beq rshift_2
rshift_1:
	lsr _dtop+1
	ror _dtop
	dex
	bne rshift_1
rshift_2:
	jmp next
}

; Double-word math follows. Some words are in Core even if they work with double values. Depending on architecture, this
; part may be relatively easy to do or quite hard. RatC VM is clearly at the very hard end when it comes to division and
; multiplication. However, there are only two words that really need to be implemented there. There are different models
; but the easiest is to start from UM/MOD and UM*.

;
; : s>d dup 0< if -1 else 0 then ;
; : dnegate invert swap invert swap one m+ ;
; : dabs dup 0< if dnegate then ;
;

+header ~stod, ~stod_n, "S>D"
	+forth
	+token dup, zerolt
	+qbranch_fwd stod_1
	+token minusone, exit
stod_1:
	+token zero, exit

; Optional Double=number word set
+header ~dnegate, ~dnegate_n, "DNEGATE"
	+forth
	+token invert, swap, invert, swap, one, mplus, exit 

; Optional Double-numbler word set
+header ~dabs, ~dabs_n, "DABS"
	+forth
	+token dup, zerolt
	+qbranch_fwd dabs_1
	+token dnegate
dabs_1:
	+token exit

;
; : sm/rem 2dup xor >r ( Sign of the quotient) over >r ( Sign of the remainder)
;          abs >r dabs r> um/mod
;          swap r> 0< if negate then
;          swap r> 0< if negate then ;
;

+header ~smrem, ~smrem_n, "SM/REM"
	+forth
	+token twodup, xor, tor, over, tor
	+token abs, tor, dabs, rfrom, ummod
	+token swap, rfrom, zerolt
	+qbranch_fwd smrem_1
	+token negate
smrem_1:
	+token swap, rfrom, zerolt
	+qbranch_fwd smrem_2
	+token negate
smrem_2:
	+token exit

;
; code um/mod
;
; This is the "shift dividend left" algorithm, something like this
;
;      dividend to (_shigh, _slow)
;      repeat (bits per cell) times
;          (_shigh, _slow) <<= 1		(*)
;          if divisor <= _shigh			(*)
;              _shigh -= divisor
;              _slow++
;      _shigh to remainder
;      _slow to quotient
;
; (*) These two lines need to take in account the carry flag which essentially adds one extra bit
;

; As I suspected, the above algorithm is easier to implement on 6502 that it was on that RatVM "architecture". 6502 does
; not have hardware divide or multiply, so it has to be implemented this way.

_shigh		= _wscratch ; dpop_scratch_wscratch requires the first two items used to be assigned to _scratch and _wscratch
_slow		= _rscratch
_sdiv		= _scratch

!if NATIVE816 {
; NATIVE816: each 16-bit-wide zero-page pair (_slow/_shigh/_sdiv) is one native
; register now, so the 32-bit shift chain and the two-pass 8-bit compare both
; collapse to a single instruction each - same restoring-division algorithm,
; same carry-flow, just fusing byte-pairs that were only ever split because
; the 6502 has no wider register. No immediate operands are affected here,
; so no !al/!as bracketing is needed, only the runtime REP/SEP.
+header ~ummod, ~ummod_n, "UM/MOD"
	+code
	jsr dpop_scratch_wscratch_dtopto_rscratch ; note _sdiv and _shigh assignments
	rep #$20
	ldx #17
ummod_1:
	dex
	beq ummod_x
	asl _slow
	rol _shigh		; carry-out here = old top bit of the 32-bit (_shigh:_slow) pair
	bcs ummod_2		; overflow past bit 31 -> _shigh is unconditionally >= _sdiv
	lda _shigh
	cmp _sdiv		; one native 16-bit compare replaces the old high-then-low 8-bit pass
	bcc ummod_1
ummod_2:
	lda _shigh
	sec
	sbc _sdiv
	sta _shigh
	inc _slow		; sets the just-shifted-in bit 0 (quotient bit = 1)
	+bra ummod_1
ummod_x:
	sep #$20
	+ldax _shigh
	+stax _dtop
	+ldax _slow
	jmp dpush_and_next
} else {
+header ~ummod, ~ummod_n, "UM/MOD"
	+code
	jsr dpop_scratch_wscratch_dtopto_rscratch ; note _sdiv and _shigh assignments
;	+dpop
;	+stax _sdiv
;	+dpop
;	+stax _shigh
;	+ldax _dtop		; Note that we don't pull the last value from the stack!
;	+stax _slow
	ldx #17
ummod_1:
	dex
	beq ummod_x
	asl _slow
	rol _slow+1
	rol _shigh
	rol _shigh+1
	bcs ummod_2		; If the carry is set, _shigh is considered larger than _sdiv due to extra high bit
	lda _sdiv+1
	cmp _shigh+1
	bcc ummod_2
	bne ummod_1
	lda _shigh
	cmp _sdiv
	bcc ummod_1
ummod_2:
	lda _shigh
	sec
	sbc _sdiv
	sta _shigh
	lda _shigh+1
	sbc _sdiv+1
	sta _shigh+1
	inc _slow
	bne ummod_1
	inc _slow+1
ummod_3:
	+bra ummod_1
ummod_x:
	+ldax _shigh
	+stax _dtop
	+ldax _slow
	jmp dpush_and_next
}

;
; : ud/mod >r 0 r@ um/mod rot rot r> um/mod rot ;
;

+header ~udmod, ~udmod_n, "UD/MOD"
	+forth
	+token tor, zero, rat, ummod
	+token rot, rot, rfrom, ummod, rot, exit

;
; code um*
;
; Another complex algorithm, using "shift product right" version
;
;    multiplicand to (_shigh, _slow) (_shigh is 0 as multiplicand is only 16 bits)
;    clear carry
;    repeat (bits per cell + 1) times
;        (_shigh, _slow) >>= 1						(pulling in carry)
;        if (carry is set)
;            _shigh += multiplier 					(saving carry)
;    (_shigh, _slow) to product
;
; Again, don't forget the carry on addition that would apply to the next shift

_smult		= _scratch

!if NATIVE816 {
; NATIVE816: the 32-bit (_shigh:_slow) shift-right-through-carry and the
; 16-bit add both fuse to one native instruction per byte-pair, same as
; UM/MOD above - the two-instruction native rotate chain reproduces the old
; four-instruction 8-bit chain's carry threading exactly (verified bit by
; bit: ror _shigh's carry-out feeds ror _slow's carry-in, same as the old
; _shigh+1->_shigh->_slow+1->_slow chain), and the native ADC's carry-out is
; the same "18th bit" the algorithm relies on carrying into the next
; iteration's rotate.
+header ~ummult, ~ummult_n, "UM*"
	+code
	+dpop
	+stax _smult
	lda #0
	sta _shigh
	sta _shigh+1
	+ldax _dtop		; Note that we don't pull the last value from the stack!
	+stax _slow
	rep #$20
	clc
	ldx #18
ummult_1:
	dex
	beq ummult_x
	ror _shigh	; carry-out here feeds ror _slow's carry-in, same threading as
	ror _slow	; the old 4-step chain (verified: shigh+1->shigh->slow+1->slow)
	bcc ummult_1
	lda _shigh
	clc
	adc _smult
	sta _shigh
	+bra ummult_1
ummult_x:
	sep #$20
	+ldax _slow
	+stax _dtop
	+ldax _shigh
	jmp dpush_and_next
} else {
+header ~ummult, ~ummult_n, "UM*"
	+code
	+dpop
	+stax _smult
	lda #0
	sta _shigh
	sta _shigh+1
	+ldax _dtop		; Note that we don't pull the last value from the stack!
	+stax _slow
	clc
	ldx #18
ummult_1:
	dex
	beq ummult_x
	ror _shigh+1	; Note that the carry flag is preserved over the loop adding one extra bit
	ror _shigh
	ror _slow+1
	ror _slow
	bcc ummult_1
	lda _shigh
	clc
	adc _smult
	sta _shigh
	lda _shigh+1
	adc _smult+1
	sta _shigh+1
	+bra ummult_1
ummult_x:
	+ldax _slow
	+stax _dtop
	+ldax _shigh
	jmp dpush_and_next
}

; UD* is not part of the standard but it is very convenient to use in formatting words
;
; : m* 2dup xor >r abs swap abs um* r> 0< if dnegate then ;
; : ud* dup >r um* drop swap r> um* rot + ; nonstandard
;

+header ~mmult, ~mmult_n, "M*"
	+forth
	+token twodup, xor, tor, abs, swap
	+token abs, ummult, rfrom, zerolt
	+qbranch_fwd mmult_1
	+token dnegate
mmult_1:
	+token exit

+header ~udmult, ~udmult_n, "UD*"
	+forth
	+token dup, tor, ummult, drop, swap
	+token rfrom, ummult, rot, add, exit

;
; : m+ s>d d+ ;
;

; From the optional Double-number word set
+header ~mplus, ~mplus_n, "M+"
	+forth
	+token stod, dadd, exit

; ==============================================================================
; Logical operations. Note that all operations are performed bitwise

;
; code and
; code or
; code xor
; : invert -1 xor ;
;

+header ~and_op, ~and_n, "AND"
	+code
	+dpop
	and _dtop
	sta _dtop
	txa
	and _dtop+1
	jmp +			; Cross-word jump to save two bytes

+header ~or, ~or_n, "OR"
	+code
	+dpop
	ora _dtop
	sta _dtop
	txa
	ora _dtop+1
	jmp +			; Cross-word jump to save two bytes

+header ~xor, ~xor_n, "XOR"
	+code
	+dpop
	eor _dtop
	sta _dtop
	txa
	eor _dtop+1
+:
	sta _dtop+1
	jmp next

; Note that NOT has been removed from the standard.
+header ~invert, ~invert_n, "INVERT"
	+forth
	+token minusone, xor, exit

; Find lowest zero (free) bit index
!if NATIVE816 {
+header ~freebit, ~freebit_n
	+code
	ldx #0
	rep #$20
-:
	lsr _dtop
	bcc +
	inx
	bne -
+:
	sep #$20
	stx _dtop
	lda #0
	sta _dtop+1
	jmp next
} else {
+header ~freebit, ~freebit_n
	+code
	ldx #0
-:
	lsr _dtop+1
	ror _dtop
	bcc +
	inx
	bne -
+:
	stx _dtop
	lda #0
	sta _dtop+1
	jmp next
}


+header ~setbit, ~setbit_n
	+forth
	+token dup, peek, rot, one, swap
	+token lshift, or, swap, poke, exit

+header ~clearbit, ~clearbit_n
	+forth
	+token dup, peek, rot, one, swap, lshift
	+token invert, and_op, swap, poke, exit

+header ~getbit, ~getbit_n
	+forth
	+token peek, one, rot
	+token lshift, and_op, exit

; ==============================================================================
; Comparisons

;
; code 0=
; code 0<
;

+header ~zeroeq, ~zeroeq_n, "0="
	+code
	lda _dtop
	ora _dtop+1
	beq true_and_next
	bne false_and_next

+header ~zerolt, ~zerolt_n, "0<"
	+code
	lda _dtop+1
;	bmi true_and_next 	; fallthrough to the fragment, saving 2 bytes
	bpl false_and_next

true_and_next:
	lda #255
	bne +
false_and_next:
	lda #0
+:
	sta _dtop
	sta _dtop+1
	jmp next
;
;	: 0> 0 swap < ;
;	: 0<> 0= 0= ;
;	: = - 0= ;
;	: <> - 0<> ;
;

+header ~zerogt, ~zerogt_n, "0>"
	+forth
	+token zero, swap, less, exit
			
+header ~zerone, ~zerone_n, "0<>"
	+forth
	+token zeroeq, zeroeq, exit

+header ~equal, ~equal_n, "="
	+forth
	+token sub, zeroeq, exit

+header ~notequal, ~notequal_n, "<>"
	+forth
	+token sub, zerone, exit


;
; code <
;
; Careful here. Some implementations have it as ": < - 0< ;" and it works... sometimes.
; Signed comparison on 6502 is surprisingly non-trivial. Refer to http://www.6502.org/tutorials/compare_beyond.html
; for details and tutorial
+header ~less, ~less_n, "<"
	+code
	+dpop
	sta _scratch
	txa
	eor #$80
	sta _scratch+1
	lda _dtop+1
	eor #$80
	cmp _scratch+1
	bcc true_and_next
	bne false_and_next
	lda _dtop
	cmp _scratch
less_result:
	bcc true_and_next
	bcs false_and_next

;
;	: > swap < ;
;	: max 2dup < if swap then drop ;
;	: min 2dup > if swap then drop ;
;

+header ~greater, ~greater_n, ">"
	+forth
	+token swap, less, exit


;
;	code u<
;
+header ~uless, ~uless_n, "U<"
	+code
	+dpop
	+stax _scratch
	lda _dtop+1
	cmp _scratch+1
	bcc true_and_next
	bne false_and_next
	lda _dtop
	cmp _scratch
	+bra less_result

;
;	: u> swap u< ;
;

+header ~ugreater, ~ugreater_n, "U>"
	+forth
	+token swap, uless, exit

;
;	-1 constant true
;	0 constant false
;

+header ~true, ~true_n, "TRUE"
	+code doconst
	+value VAL_TRUE

+header ~false, ~false_n, "FALSE"
	+code doconst
	+value VAL_FALSE


; ==============================================================================
; Base stack operations.

;
;	code dup
;	code drop
;	code over
;	code swap
;

+header ~dup, ~dup_n, "DUP"
	+code
	+ldax _dtop
	jmp dpush_and_next

+header ~drop, ~drop_n, "DROP"
	+code
	+dpop
	jmp next

+header ~over, ~over_n, "OVER"
	+code
	ldy #3
	lda (_dstack),y
	tax
	dey
	lda (_dstack),y
	jmp dpush_and_next

+header ~swap, ~swap_n, "SWAP"
	+code
	+dpop
	ldy _dtop
	sta _dtop
	tya
	pha
	ldy _dtop+1
	stx _dtop+1
	tya
	tax
	pla
	jmp dpush_and_next

;
;	: nip swap drop ;
;	: tuck swap over ;
;

+header ~nip, ~nip_n, "NIP"
	+forth
	+token swap, drop, exit

+header ~tuck, ~tuck_n, "TUCK"
	+forth
	+token swap, over, exit

;
; : rot >r swap r> swap ;
;

+header ~rot, ~rot_n, "ROT"
	+forth
	+token tor, swap, rfrom, swap, exit

; -ROT ( a b c -- c a b )   rotate the top three the other way
+header ~nrot, ~nrot_n, "-ROT"
	+forth
	+token rot, rot, exit

;
;	code pick
;	code roll ; using reference implementation from forth-standard.org instead
;
+header ~pick, ~pick_n, "PICK"
	+code
	asl _dtop
	rol _dtop+1
	lda _dstack
	clc
	adc _dtop
	sta _rscratch
	lda _dstack+1
	adc _dtop+1
	sta _rscratch+1
	ldy #2
	lda (_rscratch),y
	sta _dtop
	iny
	lda (_rscratch),y
	sta _dtop+1
	jmp next

+header ~roll, ~roll_n, "ROLL"
	+forth
	+token qdup
	+qbranch_fwd roll_1
	+token swap, tor, oneminus, roll, rfrom, swap
roll_1:
	+token exit

;
;	code depth
;

+header ~depth, ~depth_n, "DEPTH"
	+code
	lda #<DSTACK_INIT
	sec
	sbc _dstack
	tay
	lda #>DSTACK_INIT
	sbc _dstack+1
	lsr
	tax
	tya
	ror
	jmp dpush_and_next

;
;	: 2drop drop drop ;
;	: 2dup over over ;
;	: 2swap rot >r rot r> ;
;	: 2over >r >r 2dup r> r> 2swap ;
;

+header ~twodrop, ~twodrop_n, "2DROP"
	+forth
	+token drop, drop, exit

+header ~twodup, ~twodup_n, "2DUP"
	+forth
	+token over, over, exit

+header ~twoswap, ~twoswap_n, "2SWAP"
	+forth
	+token rot, tor, rot, rfrom, exit

+header ~twoover, ~twoover_n, "2OVER"
	+forth
	+token tor, tor, twodup, rfrom, rfrom, twoswap, exit

;
;	: ?dup dup if dup then ;
;

+header ~qdup, ~qdup_n, "?DUP"
	+forth
	+token dup
	+qbranch_fwd qdup_1
	+token dup 
qdup_1:
	+token exit

; ==============================================================================
; Internal helpers for DO/LOOP words - these are essentially compiled in.
; (DO) stores on the return stack: leaveaddr, limit, current, (ret) 
+header ~xdo, ~xdo_n	; (DO)
	+forth
	+branch_fwd xqdo_1
;	+token rfrom, dup, peek, tor	; forward ref for LEAVE
;	+token rot, tor, swap, tor
;	+token twoplus, tor				; step over the actual forward ref
;	+token exit

+header ~xqdo, ~xqdo_n	; (?DO)
	+forth
	+token twodup, equal
	+qbranch_fwd xqdo_1
	+token twodrop, rfrom, peek, tor, exit
xqdo_1:
	+token rfrom, dup, peek, tor	; forward ref for LEAVE
	+token rot, tor, swap, tor
	+token twoplus, tor				; step over the actual forward ref
	+token exit
			
; and (LOOP) adjusts the values on rstack or just drops the top three values from it to exit
+header ~xloop, ~xloop_n	; (LOOP)
	+forth
	+token rfrom				; return address is only needed to get the backref
	+token rfrom, oneplus			; new value of current
	+token rat, over, equal
	+branch_fwd xloop_common
;	+qbranch_fwd xloop_1
;	+token twodrop, rdrop, exit	; exit the loop (leaveaddr on the rstack)
;xloop_1:
;	+token tor, peek, tor, exit		; continue the loop

+header ~xploop, ~xploop_n	; (+LOOP)
	+forth
	+token rfrom, swap		; return address is only needed to get the backref / addr, step
	+token dup, rat, add			; preserve step value and get new value of current / addr, step, newcur
	+token rfrom, rat, sub			; diff limit and new current / addr, step, newcur, olddiff
	+token rot, over, xor, zerolt, swap ; new diff and step have different signs? / addr, newcur, step^olddiff<0, olddiff
	+token two, pick, rat, sub		; diff limit and previous current / addr, newcur, s^d, olddiff, newdiff
	+token xor, zerolt, and_op
xloop_common:
	+qbranch_fwd xploop_1  ; or diffs before and after have different signs / newdiff^olddiff < 0
	+token twodrop, rdrop, exit	; exit the loop (leaveaddr on the rstack)
xploop_1:
	+token tor, peek, tor, exit		; continue the loop

; The following three may be a bit high-level, but they make writing other words easier
+header ~i, ~i_n, "I"
	+forth
	+token rfrom, rat, swap, tor, exit

+header ~j, ~j_n, "J"
	+forth
	+token rfrom, rfrom, rfrom, rfrom, rfrom, dup, tor
	+token swap, tor, swap, tor, swap, tor, swap, tor
	+token exit

+header ~leave, ~leave_n, "LEAVE"
	+forth
	+token rdrop, rdrop, rdrop, exit

; ==============================================================================
; Standard cell/char size words and alignment (which do nothing on this architecture)

;
; : cell+ 2+ ;
; : cells 2* ;
; : char+ 1+ ;
; : chars ;
; : align ;
; : aligned ;
;

+header ~cellplus, ~cellplus_n, "CELL+"
	+forth
	+token twoplus, exit
			
+header ~cells, ~cells_n, "CELLS"
	+forth
	+token twomult, exit
			
+header ~charplus, ~charplus_n, "CHAR+"
	+forth
	+token oneplus, exit
			
+header ~chars, ~chars_n, "CHARS"
	+forth
	+token exit	; that's correct, just do nothing

; ==============================================================================
; Words working with the return stack. These are probably among the most dangerous words in the language,
; any abuse would likely result in the system crash. An important aspect that all of these have to
; be implemented natively (don't try to implement RDROP as R> DROP - it won't work)

;
; code r>
; code >r
; code r@
; code rdrop nonstandard
; code 2>r
; code 2r>
; code 2r@
;

+header ~rfrom, ~rfrom_n, "R>"
	+code
	+rpop
	jmp dpush_and_next

+header ~tor, ~tor_n, ">R"
	+code
	+dpop
	+rpush
	jmp next

+header ~rat, ~rat_n, "R@"
	+code
rat_common:
	ldy #3
	lda (_rstack),y
	tax
	dey
	lda (_rstack),y
	jmp dpush_and_next

+header ~rdrop, ~rdrop_n, "RDROP"
	+code
	+rpop
	jmp next

!if WIDEDICT {
+header ~wdcolon, ~wdcolon_n	; ( -- ) start a colon body: claim a code
	+code			; bank, emit the [RTS][body:2][bank:1] stub at
!if WD_FARHDR {
	; far headers: xcreate already claimed the bank and built the record
	; at _chere's old position; the stub goes right after it IN the bank
	; (near space untouched). Repoint TOKENS/TOKBANK from the near HERE
	; (where a data word's CFA would have gone) to the far stub.
	lda _cbanks_ok
	bne wdcf_go
	jmp wdc0		; no code banks: classic near fallback below
wdcf_go:
	+ldax _hightoken	; TOKENS[_hightoken] = _chere
	asl
	sta _wscratch
	txa
	rol
	adc #>TOKENS
	sta _wscratch+1
	ldy #0
	lda _chere
	sta (_wscratch),y
	iny
	lda _chere+1
	sta (_wscratch),y
	clc			; TOKBANK[_hightoken] = _codebank
	lda _hightoken
	adc #<TOKBANK
	sta _wscratch
	lda _hightoken+1
	adc #>TOKBANK
	sta _wscratch+1
	lda _codebank
	ldy #0
	sta (_wscratch),y
	sta CBANKREG		; pin: the stub write and the body compile
				; target the code bank (v2 resting rule)
	lda _chere		; write [RTS][_chere+4][bank] at _chere
	sta _wscratch
	lda _chere+1
	sta _wscratch+1
	ldy #0
	lda #RTS_INSTR
	sta (_wscratch),y
	clc
	lda _chere
	adc #4
	sta _rscratch		; body start = stub end (also the new HERE)
	iny
	sta (_wscratch),y
	lda _chere+1
	adc #0
	sta _rscratch+1
	iny
	sta (_wscratch),y
	iny
	lda _codebank
	sta (_wscratch),y
	lda _here		; park the data-space pointers, swap HERE
	sta _dhere		; into the code bank
	lda _here+1
	sta _dhere+1
	lda _memtop
	sta _dmemtop
	lda _memtop+1
	sta _dmemtop+1
	lda _rscratch
	sta _here
	lda _rscratch+1
	sta _here+1
	lda #<CWIN_TOP
	sta _memtop
	lda #>CWIN_TOP
	sta _memtop+1
	lda #1
	sta _incode
	jmp next
wdc0:
}
	jsr ccw_claim		; the data HERE, then swap HERE to code space
	ldy #0
	lda #RTS_INSTR
	sta (_here),y
	lda _codebank
	bne wdc_far
	; no code banks (or none claimed): the body follows the stub in the
	; visible space - point the stub right past itself, bank 0, no swap
	clc
	lda _here
	adc #4
	pha
	iny
	sta (_here),y
	lda _here+1
	adc #0
	pha
	iny
	sta (_here),y
	lda #0
	iny
	sta (_here),y
	pla
	sta _here+1
	pla
	sta _here
	jmp next
wdc_far:
	iny
	lda _chere
	sta (_here),y
	iny
	lda _chere+1
	sta (_here),y
	iny
	lda _codebank
	sta (_here),y
	clc			; _here += 4 (past the stub)
	lda _here
	adc #4
	sta _here
	bcc wdc_nc
	inc _here+1
wdc_nc:
	lda _here
	sta _dhere
	lda _here+1
	sta _dhere+1
	lda _memtop
	sta _dmemtop
	lda _memtop+1
	sta _dmemtop+1
	lda _chere
	sta _here
	lda _chere+1
	sta _here+1
	lda #<CWIN_TOP
	sta _memtop
	lda #>CWIN_TOP
	sta _memtop+1
	lda #1
	sta _incode
	lda _codebank
	sta CBANKREG		; pin: compilation pokes go to the code bank
	jmp next
}

+header ~twotor, ~twotor_n, "2>R"
	+code
	+dpop
	+stax _rscratch
	+dpop
	+rpush
	+ldax _rscratch
	+rpush
	jmp next

+header ~tworfrom, ~tworfrom_n, "2R>"
	+code
	+rpop
	+stax _rscratch
	+rpop
	+dpush
	+ldax _rscratch
	jmp dpush_and_next

+header ~tworat, ~tworat_n, "2R@"
	+code
	ldy #5
	lda (_rstack),y
	tax
	dey
	lda (_rstack),y
	+dpush
	+bra rat_common
;	ldy #3
;	lda (_rstack),y
;	tax
;	dey
;	lda (_rstack),y
;	jmp dpush_and_next

; ==============================================================================
; Basic memory operations

;
; code @
; code c@
; code !
; code c!
; : 2! swap over ! cell+ ! ;
; : 2@ dup cell+ @ swap peek ;
;

+header ~peek, ~peek_n, "@"
	+code
fragment_peek:

	ldy #1
	lda (_dtop),y
	tax
	dey
	lda (_dtop),y
	+stax _dtop
	jmp next


+header ~cpeek, ~cpeek_n, "C@"
	+code

	ldy #0
	lda (_dtop),y
	sta _dtop
	sty _dtop+1
	jmp next


+header ~poke, ~poke_n, "!"
	+code
!if WIDEDICT {
	lda _dtop+1		; storing into the code-bank window? (happens
	cmp #>CWIN_BASE		; while compiling a far body) - pin the register
	bcs poke_win		; to _codebank around the store, then restore it
}
	ldy #3
	lda (_dstack),y
	tax
	dey
	lda (_dstack),y
	ldy #0
	sta (_dtop),y
	txa
	iny
	bne cpoke_continue
	
;	+dpop
;	+stax _wscratch
;	+dpop
;	ldy #0
;	sta (_wscratch),y
;	txa
;	iny
;	sta (_wscratch),y
;	jmp next

!if WIDEDICT {
poke_win:
	ldy #3
	lda (_dstack),y
	tax
	dey
	lda (_dstack),y
	sta _wscratch
	lda CBANKREG
	pha
	lda _codebank
	sta CBANKREG
	lda _wscratch
	ldy #0
	sta (_dtop),y
	txa
	iny
	sta (_dtop),y
	pla
	sta CBANKREG
	+dpop
	+dpop
	jmp next
cpoke_win:
	ldy #2
	lda (_dstack),y
	sta _wscratch
	lda CBANKREG
	pha
	lda _codebank
	sta CBANKREG
	lda _wscratch
	ldy #0
	sta (_dtop),y
	pla
	sta CBANKREG
	+dpop
	+dpop
	jmp next
}

+header ~cpoke, ~cpoke_n, "C!"
	+code
!if WIDEDICT {
	lda _dtop+1
	cmp #>CWIN_BASE
	bcs cpoke_win
}
	ldy #2
	lda (_dstack),y
	ldy #0
cpoke_continue:
	sta (_dtop),y
	+dpop
	+dpop
	jmp next

;	+dpop
;	+stax _wscratch
;	+dpop
;	ldy #0
;	sta (_wscratch),y
;	jmp next

+header ~twopoke, ~twopoke_n, "2!"
	+forth
	+token tuck, poke, cellplus, poke, exit

+header ~twopeek, ~twopeek_n, "2@"
	+forth
	+token dup, cellplus, peek, swap, peek, exit

; ==============================================================================
; Literal support
;
; code lit
; Alternative but slower: : lit r@ peek r> cell+ >r ; nonstandard
;

; This is being compiled by LITERAL - will take the next 16-bit value and put it
; on stack
+header ~lit, ~lit_n	; LIT
	+code
	ldy #1
	+ldri
	tax
	dey
	+ldri
	+dpush
fragment_2:
;	+ldax _ri
;	+incax 2
;	+stax _ri
	+incmem _ri, 2
	jmp next
; end of fragment 2

; This is a shortcut for core use only - will take the 8-bit value instead. LITERAL
; does not compile it yet, but it can in theory.
+header ~blit, ~blit_n
	+code
	ldy #0
	+ldri
	ldx #0
	+dpush
	inc _ri
	bne blit_1
	inc _ri+1
blit_1:
	jmp next

; ==============================================================================
; Numeric output. Forth approach is a bit odd but extremely powerful

;
; variable base
; : <@ _hldend _hld ! ;
; : # base @ ud/mod rot '0' + dup '9' > if 7 + then hold ; 
; : #s begin # 2dup or 0= until ; 
; : #> 2drop _hld @ _hldend over - ;
; : hold _hld @ 1 - dup _hld ! c! ;
; : holds begin dup while 1- 2dup + c@ hold again 2drop ;
; : sign 0< if '-' hold then ;
;

+header ~base, ~base_n, "BASE"
	+code doconst
	+value _base

+header ~bhash, ~bhash_n, "<#"
	+forth
	+literal _hldend
	+literal _hld
	+token poke, exit

+header ~hash, ~hash_n, "#"
	+forth
	+token base, peek, udmod, rot
	+literal '0'
	+token add
	+token dup
	+literal '9'
	+token greater
	+qbranch_fwd hash_1
	+literal 7
	+token add
hash_1:
	+token hold, exit

+header ~hashs, ~hashs_n, "#S"
	+forth
hashs_1:
	+token hash, twodup, or, zeroeq
	+qbranch hashs_1
	+token exit

+header ~hashb, ~hashb_n, "#>"
	+forth
	+token twodrop
	+literal _hld
	+token peek
	+literal _hldend
	+token over, sub, exit

+header ~hold, ~hold_n, "HOLD"
	+forth
	+literal _hld
	+token peek, one, sub, dup
	+literal _hld
	+token poke, cpoke, exit

+header ~sign, ~sign_n, "SIGN"
	+forth
	+token zerolt
	+qbranch_fwd sign_1
	+literal '-'
	+token hold
sign_1:
	+token exit

;
; : d.r >r dup >r dabs <# #s r> sign #> r> over - spaces type ;
; : d. 0 d.r space ;
; : .r swap s>d rot d.r ;
; : u. 0 d.
; : u.r 0 swap d.r ;
; : . s>d d. ;
;

+header ~ddotr, ~ddotr_n, "D.R"
	+forth
	+token tor, dup, tor, dabs, bhash, hashs, rfrom
	+token sign, hashb, rfrom, over, sub, spaces, type, exit

+header ~ddot, ~ddot_n, "D."
	+forth
	+token zero, ddotr, space, exit

+header ~dot, ~dot_n, "."
	+forth
	+token stod, ddot, exit

;
; : decimal 10 base ! ;
; : hex 16 base ! ;
;

+header ~decimal, ~decimal_n, "DECIMAL"
	+forth
	+literal 10
	+token base, poke, exit

+header ~hex, ~hex_n, "HEX"
	+forth
	+literal 16
	+token base, poke, exit

; ==============================================================================
; HERE, comma, C,, etc.

;
; : +! dup @ rot + swap ! ;
; : here _here @ ;
; : allot _here +!
; : , here 2 allot ! ;
; : c, here 1 allot c! ;
;

+header ~incpoke, ~incpoke_n, "+!"
	+forth
	+token dup, peek, rot, add, swap, poke, exit

+header ~here, ~here_n, "HERE"
	+forth
	+literal _here
	+token peek, exit


+header ~allot, ~allot_n, "ALLOT"
	+forth
	+token here, add, dup
!if WIDEDICT {
	+literal _memtop
	+token peek
} else {
	+literal MEMTOP
}
	+token ugreater
	+qbranch_fwd allot_ok
	+token xabortq
	+string "?MEM"
allot_ok:
	+literal _here
	+token poke, exit


+header ~unused, ~unused_n, "UNUSED"
	+forth
!if WIDEDICT {
	+literal _memtop
	+token peek
} else {
	+literal MEMTOP
}
	+token here, sub, exit


+header ~comma, ~comma_n, ","
	+forth
	+token here, two, allot, poke, exit

+header ~ccomma, ~ccomma_n, "C,"
	+forth
	+token here, one, allot, cpoke, exit

; ==============================================================================
; Support for branching. These are compiled by most control words
; There is an exotic way to implement BRANCH as
; : BRANCH R> @ >R ;
; This approach does not work for ?BRANCH due to chicken-and-egg problem

;
; code branch nonstandard
; code ?branch nonstandard
;

; Unconditional jump to the address following the token
+header ~branch, ~branch_n	; BRANCH
	+code
branch_c:
	ldy #1
	+ldri
	tax
	dey
	+ldri
	+stax _ri		; branch targets stay within the same body/bank
	jmp next

; Jump to the address if top of the stack is FALSE. Skip the address and
; continue otherwise
+header ~qbranch, ~qbranch_n	; ?BRANCH aka 0BRANCH
	+code
	+dpop
	stx _rscratch
	ora _rscratch
	beq branch_c
	jmp fragment_2
;	+ldax _ri
;	+incax 2
;	+stax _ri
;	jmp next

; Shorthand variety of BRANCH for core use - threat the next byte as a
; relative _forward only_ offset instead of address
+header ~bbranch, ~bbranch_n
	+code
bbranch_c:
	ldy #0
	+ldri
	clc
	adc _ri
	sta _ri
	bcc +
	inc _ri+1
+
	jmp next

; Similarly, shorthand for ?BRANCH
+header ~qbbranch, ~qbbranch_n
	+code
	+dpop
	stx _rscratch
	ora _rscratch
	beq bbranch_c
	inc _ri
	bne qbbranch_1
	inc _ri+1
qbbranch_1:
	jmp next

	
	
; ==============================================================================
; Line input support

+header ~tib, ~tib_n, "TIB"
	+forth
	+literal _source
	+token peek, twoplus, twoplus, twoplus, peek, exit

+header ~ptrin, ~ptrin_n, ">IN"
	+forth
	+literal _source
	+token peek, twoplus, twoplus, exit

+header ~numtib, ~numtib_n, "#TIB"
	+forth
	+literal _source
	+token peek, twoplus, twoplus, twoplus, twoplus, exit

+header ~source, ~source_n, "SOURCE"
	+forth
	+token tib, numtib, peek, exit

+header ~sourceid, ~sourceid_n, "SOURCE-ID"
	+forth
	+literal _source
	+token peek, twoplus, peek, exit

+header ~accept, ~accept_n, "ACCEPT"
	+code
	+dpop
!if C64 {
	sta _rscratch ; Note that this only works properly for small numbers, but this is platform-consistent anyway
!if X16 {
	; Reset the X16 KERNAL screen-editor line-input state before reading a
	; console line. After any device-8 file read (INCLUDED / EDIT) this state
	; can be left so the first RETURN is not accepted ("OPEN bug"): crsw!=0
	; leaves the editor replaying a stale screen line instead of taking input,
	; and a stuck qtsw/insrt makes control chars (incl. RETURN) insert literally.
	lda #0
	sta $037F	; crsw  - 0 = interactive input (not line-replay)
	sta $0381	; qtsw  - quote mode off
	sta $0385	; insrt - insert mode off
	sta $0377	; rvs   - reverse-video mode off
}
	ldy #0
accept_1:
	jsr CHRIN
	cmp #NEW_LINE
	beq accept_2
	sta (_dtop),y
	iny
	bne accept_1
	tya
	cmp _rscratch
	bmi accept_1
accept_2:
	sty _dtop
	lda #0
	sta _dtop+1
} else if F256 {
	tay
	+ldax _dtop
	jsr gets
	sty _dtop
	stz _dtop+1
	jsr newline
} else {
	!error "Not implemented"
}

	jmp next

; : refill source-id 0< if false exit then
;          source-id 0= if cr ." Ok" cr tib 80 accept #tib ! 0 >in ! true exit then
;          source-id file-position drop _source 10 + 2!
;          tib 98 source-id read-line 0= and
;          if #tib ! 0 >in ! true exit then
;          drop false ;

; Note that slightly longer lines are being read from file
+header ~refill, ~refill_n, "REFILL"
	+forth
	+token sourceid, zerolt
	+qbranch_fwd refill_1
	+token false, exit	; "EVALUATE" - no refill
refill_1:
	+token sourceid, zeroeq
	+qbranch_fwd refill_2
	+token cr
	+literal prompt
	+token count, type, cr, tib
	+literal 80
	+token accept, numtib, poke, zero, ptrin, poke, true, exit	; console
refill_2:
!if FASTLOAD = 0 {
	; save the pre-refill file position into the source frame (+10) for
	; RESTORE-INPUT. Dead weight on these platforms: FILE-POSITION and
	; REPOSITION-FILE are both stubs, so the value can never be used -
	; the FASTLOAD builds skip the whole dance (it ran once per line).
	+token sourceid, fileposition, drop
	+literal _source
	+token peek
	+literal 10
	+token add, twopoke
}
	+token tib
	+literal 98
	+token sourceid, readline, zeroeq, and_op
	+qbranch_fwd refill_3
	+token numtib, poke, zero, ptrin, poke, true, exit	 ; file (note that the position is saved _before_ the refill)
refill_3:
	+token drop, false, exit
prompt:
	+string "OK"

; ==============================================================================
; Some basic text output

; code emit

+header ~emit, ~emit_n, "EMIT"
	+code
	+dpop
!if C64 {
	jsr CHROUT
} else if F256 {
	cmp #13
	bne +
	jsr newline
	jmp next
+:	
	jsr putc
} else {
	!error "Not implemented"
}

	jmp next

; : cr 13 emit ;

+header ~cr, ~cr_n, "CR"
	+forth
	+literal NEW_LINE
	+token emit, exit

; ' ' constant bl

+header ~bl, ~bl_n, "BL"
	+code doconst
	+value ' '

; : space bl emit ;

+header ~space, ~space_n, "SPACE"
	+forth
	+token bl, emit, exit

; This one is a little bit weird, abusing the semantics of COUNT
; : type 0 ?do count emit loop drop ;
; 
+header ~type, ~type_n, "TYPE"
	+forth
	+token zero, xqdo
	+address type_out
type_loop:
	+token count, emit, xloop
	+address type_loop
type_out:
	+token drop, exit

; : count dup 1+ swap c@ ;

+header ~count, ~count_n, "COUNT"
	+forth
	+token dup, oneplus, swap, cpeek, exit

; ==============================================================================
; Word lookup. This is where the complex things begin.

!if FASTLOAD {
; Native source scanning. The interpreted loops these replace ran ~12-20
; tokens PER CHARACTER of source text (measured ~4800 cycles per skipped
; comment character) - the dominant per-character cost of INCLUDE after
; readgen went native. Both words read the source frame directly:
; (_source)+4 = >IN value, +6 = buffer address, +8 = buffer length
; (see TIB / >IN / #TIB just above).

; xskipdelim ( delim -- delim ): advance >IN past leading delimiters.
; Matches the old WORD skip loop: chars are masked with 127 (shift-space
; quirk) and TAB (9) is treated as a space before comparing to delim.
+header ~xskipdelim, ~xskipdelim_n
	+code
	lda _dtop		; the delimiter (left on the stack for PARSE)
	sta _scratch
	ldy #6
	lda (_source),y		; cur = buffer + >IN
	sta _rscratch
	iny
	lda (_source),y
	sta _rscratch+1
	ldy #4
	lda (_source),y
	clc
	adc _rscratch
	sta _rscratch
	iny
	lda (_source),y
	adc _rscratch+1
	sta _rscratch+1
	ldy #8			; rem = length - >IN
	lda (_source),y
	sta _wscratch
	iny
	lda (_source),y
	sta _wscratch+1
	ldy #4
	sec
	lda _wscratch
	sbc (_source),y
	sta _wscratch
	iny
	lda _wscratch+1
	sbc (_source),y
	sta _wscratch+1
	lda #0			; skipped-count
	sta _scratch_1
	sta _scratch_1+1
xskd_loop:
	lda _wscratch
	ora _wscratch+1
	beq xskd_done
	ldy #0
	lda (_rscratch),y
	and #127
	cmp #9			; TAB counts as a space
	bne xskd_notab
	lda #' '
xskd_notab:
	cmp _scratch
	bne xskd_done
	inc _rscratch
	bne xskd_nc
	inc _rscratch+1
xskd_nc:
	inc _scratch_1
	bne xskd_ns
	inc _scratch_1+1
xskd_ns:
	lda _wscratch
	bne xskd_nd
	dec _wscratch+1
xskd_nd:
	dec _wscratch
	jmp xskd_loop
xskd_done:
	ldy #4			; >IN += skipped
	clc
	lda (_source),y
	adc _scratch_1
	sta (_source),y
	iny
	lda (_source),y
	adc _scratch_1+1
	sta (_source),y
	jmp next

; ( char "ccc<char>" -- c-addr u ) - native scan to the delimiter. Same
; contract as the interpreted version: chars masked with 127 for the
; compare, u excludes the delimiter, >IN ends past the delimiter (or at
; the end of the source if none found).
+header ~parse, ~parse_n, "PARSE"
	+code
	+dpop
	sta _scratch		; the delimiter
	ldy #6
	lda (_source),y		; cur = buffer + >IN
	sta _rscratch
	iny
	lda (_source),y
	sta _rscratch+1
	ldy #4
	lda (_source),y
	clc
	adc _rscratch
	sta _rscratch
	iny
	lda (_source),y
	adc _rscratch+1
	sta _rscratch+1
	lda _rscratch		; c-addr result = starting cur
	sta _scratch_2
	lda _rscratch+1
	sta _scratch_2+1
	ldy #8			; rem = length - >IN
	lda (_source),y
	sta _wscratch
	iny
	lda (_source),y
	sta _wscratch+1
	ldy #4
	sec
	lda _wscratch
	sbc (_source),y
	sta _wscratch
	iny
	lda _wscratch+1
	sbc (_source),y
	sta _wscratch+1
parse_loop:
	lda _wscratch
	ora _wscratch+1
	beq parse_exh
	ldy #0
	lda (_rscratch),y
	and #127
	cmp _scratch
	beq parse_fnd
	inc _rscratch
	bne parse_nc
	inc _rscratch+1
parse_nc:
	lda _wscratch
	bne parse_nd
	dec _wscratch+1
parse_nd:
	dec _wscratch
	jmp parse_loop
parse_fnd:
	ldx #1			; consumed = u+1 (step past the delimiter)
	!byte $2c		; BIT abs: skip the next 2-byte instruction
parse_exh:
	ldx #0			; consumed = u (source exhausted)
	sec			; u = cur - start
	lda _rscratch
	sbc _scratch_2
	sta _scratch_1
	lda _rscratch+1
	sbc _scratch_2+1
	sta _scratch_1+1
	txa			; _wscratch = consumed = u + (0|1)
	clc
	adc _scratch_1
	sta _wscratch
	lda _scratch_1+1
	adc #0
	sta _wscratch+1
	ldy #4			; >IN += consumed
	clc
	lda (_source),y
	adc _wscratch
	sta (_source),y
	iny
	lda (_source),y
	adc _wscratch+1
	sta (_source),y
	+ldax _scratch_2	; push c-addr, u
	+dpush
	+ldax _scratch_1
	jmp dpush_and_next

+header ~word, ~word_n, "WORD"
	+forth
	+token xskipdelim, parse, dup
	+literal _wordbuf
	+token cpoke
	+literal _wordbuf
	+token oneplus, swap, cmove
	+literal _wordbuf
	+token exit

+header ~parsename, ~parsename_n, "PARSE-NAME"
	+forth
	+token bl, xskipdelim, parse, exit
} else {
+header ~word, ~word_n, "WORD"
	+forth
	+token tor, source, swap, ptrin, peek, add
word_1:
	+token over, ptrin, peek, greater
	+qbranch_fwd word_2
	+token dup, cpeek
!if C64 {
	+literal 127 ; a workaround for peculiar C64 annoyance (shift-space looking just like a regular space)
	+token and_op
}
	+token dup
	+literal 9		; treat TAB as space
	+token equal
	+qbranch word_3
	+token drop, bl
word_3:
	+token rat, equal
	+qbranch_fwd word_2
	+token ptrin, peek, oneplus, ptrin, poke, oneplus
	+branch word_1
word_2:
	+token twodrop, rfrom, parse, dup
	+literal _wordbuf
	+token cpoke
	+literal _wordbuf
	+token oneplus, swap, cmove
	+literal _wordbuf
	+token exit

+header ~parse, ~parse_n, "PARSE"
	+forth
	+token tor, source, ptrin, peek, sub
	+token oneplus, tor, ptrin, peek, add, dup, zero
parse_1:
	+token over, cpeek, rfrom, oneminus, qdup
	+qbranch_fwd parse_3
	+token swap
	+literal 127
	+token and_op, rat, equal
	+qbranch_fwd parse_2 ; SAME AS ABOVE
	+token drop, nip, rdrop, ptrin
	+token dup, peek, oneplus, swap, poke, exit
parse_2:
	+token tor, swap, oneplus, swap, oneplus, ptrin
	+token dup, peek, oneplus, swap, poke
	+branch parse_1
parse_3:
	+token drop, nip, rdrop, exit

+header ~parsename, ~parsename_n, "PARSE-NAME"
	+forth
	+token source, swap, ptrin, peek, add
parsename_1:
	+token over, ptrin, peek, greater
	+qbranch_fwd parsename_2
	+token dup, cpeek, bl, equal
	+qbranch_fwd parsename_2
	+token ptrin, peek, oneplus, ptrin, poke, oneplus
	+branch parsename_1
parsename_2:
	+token twodrop, bl, parse, exit
}


+header ~tobody, ~tobody_n, ">BODY"
	+forth
	+token xttocfa, twoplus, oneplus, exit	; offset for JMP CREATED

; ==============================================================================

+header ~context, ~context_n		; known in some dialectes as CONTEXT, obsolete with Search-Order
	+forth
	+literal _current
	+token cpeek, cells
	+literal _vocs
	+token add, exit

+header ~latest, ~latest_n		; known in some dialectes as LATEST, non-standard
	+forth
	+literal _latest
	+token peek, exit

; Search-order words
; GET-ORDER and SET-ORDER use the reference implementation with the exception that
; both #order and context are byte size

; : GET-ORDER ( -- wid1 ... widn n )
;   #order @ 0 ?DO
;     #order @ I - 1- CELLS context + @
;   LOOP
;   #order @
; ; 

+header ~get_order, ~get_order_n, "GET-ORDER"
	+forth
	+literal _numorder
	+token cpeek, zero, xqdo
	+address getorder_done
getorder_loop:
	+literal _numorder
	+token cpeek, i, sub, oneminus
	+literal _context
	+token add, cpeek, xloop
	+address getorder_loop
getorder_done:
	+literal _numorder
	+token cpeek, exit

; : SET-ORDER ( wid1 ... widn n -0 )
;   DUP -1 = IF
;     DROP <push system default word lists and n>
;   THEN
;   DUP #order !
;   0 ?DO I CELLS context + ! LOOP
; ;
 
+error_message ~setorder_error
+header ~set_order, ~set_order_n, "SET-ORDER"
	+forth
	+token dup
	+literal MAXORDER+1
	+token less
	+qbranch setorder_error
	+token dup, minusone, equal
	+qbranch_fwd setorder_cont
	+token drop, zero, one		; FORTH-WORDLIST wid is 0
setorder_cont:
	+token dup
	+literal _numorder
	+token cpoke, zero, xqdo
	+address setorder_exit
setorder_loop:
	+token i
	+literal _context
	+token add, cpoke, xloop
	+address setorder_loop
setorder_exit:
	+token exit

; Structure of wordlist word
; - header
; - JMP doconst (constant semantics)
; - xt of self, used as wid
; - NULL as there are no items in the list yet

+header ~xwordlist, ~xwordlist_n
	+forth
	+literal _numvocs
	+token cpeek
	+literal WORDLISTS
	+token less
	+qbranch_fwd xwordlist_error
	+token xcreate
	+literal JMP_INSTR
	+token ccomma
	+literal doconst
	+token comma
	+literal _numvocs
	+token cpeek
	+token dup, comma
	+token dup, cells
	+token dup
	+literal _vocs
	+token add, zero, swap, poke
	+literal _vocsref
!if WD_FARHDR {
	; _vocsref keeps the creator's TOKEN (tokens are definition-ordered;
	; window NFAs are not comparable across banks), and the new wordlist
	; starts with a near (empty) head bank
	+token add
	+literal _hightoken
	+token peek, swap, poke
	+token dup
	+literal _vocsbank
	+token add, zero, swap, cpoke
} else {
	+token add, latest, swap, poke
}
	+token dup, oneplus
	+literal _numvocs
	+token cpoke, exit
xwordlist_error:
	+token xabortq
	+string "?WLIST"

+header ~search_wordlist, ~search_wordlist_n, "SEARCH-WORDLIST"
	+forth
!if WD_FARHDR {
	; seed the walk with the head's bank; all header reads from here on go
	; through _scanbank (xfind keeps it in step as the chain hops banks)
	+token dup
	+literal _vocsbank
	+token add, cpeek
	+literal _scanbank
	+token cpoke
	+token cells
	+literal _vocs
	+token add, peek
	+token xfind, dup
	+qbranch_fwd swf_notfound
	+token dup, minusone, swap, wdhcpeek
	+literal $80
	+token and_op
	+qbranch_fwd swf_notimm
	+token negate
swf_notimm:
	+token swap, nfatolfa, lfatocfa, cfatoxt
	+token swap
swf_notfound:
	+token exit
} else {
	+token cells
	+literal _vocs
	+token add, peek
	+token xfind, dup
	+qbranch_fwd sw_notfound
	+token dup, minusone, swap, cpeek
	+literal $80
	+token and_op
	+qbranch_fwd sw_notimm
	+token negate
sw_notimm:
	+token swap, nfatolfa, lfatocfa, cfatoxt
	+token swap
sw_notfound:
	+token exit
}

;
; : (find) (;code) nonstandard
;
; : find dup >r count (find) dup
;        if rdrop dup count #namemask and + 2+
;           swap c@ #immflag and -1 swap if negate then
;        else >r swap then ;
;

; Performance of FIND is critical for the interpretation speed, so it is worth to rewrite it in assembly. (FIND) is scanning through
; the vocabulary, so it has much higher impact

+header ~xfind, ~xfind_n		; (FIND) ( caddr, start_NFA -> NFA | 0 )
	+code
	+dpop
	+stax _rscratch
	+dpop
!if FASTLOAD {
	cmp #0				; zero-length target: instant not-found
	bne xfp_lenok			; (long-form branch - the hash redirect
	jmp xfind_nomorewords		; below pushed the direct beq out of range)
xfp_lenok:
} else {
	cmp #0
	beq xfind_nomorewords
}
	sta _scratch
!if WIDEDICT {
	lda _rscratch		; NULL start NFA (empty wordlist): scanning
	ora _rscratch+1		; from address 0 would walk zero-page garbage
	bne xfp_nfaok		; (zp $00 = the bank register, nonzero now)
	jmp xfind_nomorewords
xfp_nfaok:
}

xfind_compare:
!if FASTLOAD {
; Hit the boundary into the (large, static) core dictionary? Skip the slow
; linear walk through it entirely and use the coldstart-built hash index
; instead. Covers both the plain-PRG case (reached via ordinary LFA-delta
; decrement) and the ROM/CART split-memory case (reached via the explicit
; xfind_linkcore "$FF alone" jump) - both funnel through here first.
; High byte compared first: for the common case (scanning user words above
; the core) it differs, so the check costs one cmp+branch per word scanned.
	lda _rscratch+1
	cmp #>forth_system_n
	bne xfc_noredirect
	lda _rscratch
	cmp #<forth_system_n
	bne xfc_noredirect
	lda hash_ok		; table unusable (core outgrew it)? stay linear
	beq xfc_noredirect	; (zero-length targets never get here - the
	jmp hash_lookup		; xfind prologue rejects them outright)
xfc_noredirect:
}
!if WD_FARHDR {
	lda _rscratch+1		; scanning a far header? pin its bank so the
	cmp #>CWIN_BASE		; name/length reads see the right window
	bcc xfc_nopin
	lda _scanbank
	sta CBANKREG
xfc_nopin:
}
	ldy #0				; compare the word length at the scan pointer to _scratch
	lda (_rscratch),y
	and #NAMEMASK
	tax
	cmp _scratch
	bne xfind_nextword	; nope, next. note that the length is already in X
	
	tay					; the result of the above is that A has the length which is also a proper offset to the last char in scanned word
xfind_cmpchar:
	lda (_rscratch),y
	dey					; and one past the last char in test word
	bmi xfind_found		; the last character has been compared already? good, that's the result
	eor (_dtop),y		; poor man's case insensitive compare ;)
	and #$5f
	beq xfind_cmpchar	; same char, continue. otherwise, next word

xfind_nextword:
!if WD_FARHDR {
	lda _rscratch+1		; far header: the link is absolute
	cmp #>CWIN_BASE		; [addr:2][bank:1] at NFA+len+5 (fixed form -
	bcc xfn_near		; never a diff, so the classic parse below
	txa			; would misread it). Bank still pinned from
	clc			; the loop top.
	adc #5			; len (in X) + 5
	tay
	lda (_rscratch),y
	sta _wscratch
	iny
	lda (_rscratch),y
	sta _wscratch+1
	iny
	lda (_rscratch),y
	sta _scanbank		; the next header's bank (repinned at the top)
	lda _wscratch
	sta _rscratch
	lda _wscratch+1
	sta _rscratch+1
	ora _rscratch		; end of chain? (A = 0 exactly when so, which
	beq xfind_nomorewords	; the exit stores into the result)
	jmp xfind_compare
xfn_near:
}
	lda #0
	sta _wscratch+1
	txa					; expect current length in X
	tay
	iny					; name + name byte, now pointing at the LFA
	lda (_rscratch),y
	beq xfind_nomorewords
	bpl xfind_offsetok
	cmp #$ff			; special case for link from compiled section to core (differential LFA may not be capable to do this one jump otherwise)
	beq xfind_linkcore
	and #$7f
	sta _wscratch+1
	iny
	lda (_rscratch),y
xfind_offsetok:
	sta _wscratch

	jsr rscratch_sub_wscratch
;	sec
;	lda _rscratch
;	sbc _wscratch
;	sta _rscratch
;	lda _rscratch+1
;	sbc _wscratch+1
;	sta _rscratch+1
	
	+bra xfind_compare

xfind_linkcore:
	lda #<forth_system_n
	sta _rscratch
	lda #>forth_system_n
	sta _rscratch+1
	+bra xfind_compare

xfind_nomorewords:
	sta _dtop
	sta _dtop+1
!if WD_FARHDR {
	lda _ribank		; un-drift: restore the resting bank
	sta CBANKREG
}
	jmp next

xfind_found:
	+ldax _rscratch
	+stax _dtop
!if WD_FARHDR {
	lda _ribank		; found: _scanbank = the word's bank; the
	sta CBANKREG		; register itself goes back to resting state
}
	jmp next


!if FASTLOAD {
; hash_lookup: reached from xfind_compare when the linear near-list scan hits
; forth_system_n, the boundary into the large static core dictionary. Uses
; the coldstart-built hash index (build_hashtable) instead of continuing a
; slow linear walk through core. On entry: _dtop = target char data
; (0-indexed, no length prefix - NOT an NFA), _scratch = target length
; (guaranteed >0 - the redirect keeps zero-length lookups linear). Exits
; through the shared xfind_found/xfind_nomorewords paths so the calling
; convention is identical either way.
hash_lookup:
	lda _scratch			; acc = len
	sta _wscratch
	ldx _scratch			; X = char countdown
	ldy #0
hl_hashloop:
	asl _wscratch			; acc = rotl8(acc) ...
	bcc hl_norot
	inc _wscratch			; (bit 0 is clear after asl; inc sets it)
hl_norot:
	lda (_dtop),y			; ... eor (char & $5f)
	and #$5f
	eor _wscratch
	sta _wscratch
	iny
	dex
	bne hl_hashloop

	lda _wscratch
	and #HASH_MASK
	asl				; bucket*2 = HASHIDX byte offset (0..254)
	tay
	lda HASHIDX,y			; _scratch_1 = slice start (lower bound)
	sta _scratch_1
	lda HASHIDX+1,y
	sta _scratch_1+1
	lda HASHIDX+2,y			; _wscratch = slice end = HASHIDX[b+1]
	sta _wscratch			; (y<=254 so +3 tops out at HASHIDX+257,
	lda HASHIDX+3,y			; the last byte of the sentinel entry)
	sta _wscratch+1

hl_slot:
	lda _wscratch			; p -= 2. Scanning from the slice's END
	sec				; downward visits newest-first, preserving
	sbc #2				; the linear scan's newest-shadows-oldest
	sta _wscratch			; semantics.
	bcs hl_nb
	dec _wscratch+1
hl_nb:
	lda _wscratch+1			; p < slice start? no match in this bucket
	cmp _scratch_1+1
	bcc hl_notfound
	bne hl_cand
	lda _wscratch
	cmp _scratch_1
	bcc hl_notfound
hl_cand:
	ldy #0
	lda (_wscratch),y		; candidate NFA from the slice
	sta _rscratch
	iny
	lda (_wscratch),y
	sta _rscratch+1
	ldy #0
	lda (_rscratch),y		; cheap pre-filter: length must match
	and #NAMEMASK
	cmp _scratch
	bne hl_slot
	tax				; X = length (>0, only named words here)
	lda _rscratch			; _scratch_2 = NFA+1 = candidate's chars
	clc
	adc #1
	sta _scratch_2
	lda _rscratch+1
	adc #0
	sta _scratch_2+1
	ldy #0
hl_cmploop:
	lda (_scratch_2),y
	eor (_dtop),y
	and #$5f			; same masked compare as the linear scan
	bne hl_slot
	iny
	dex
	bne hl_cmploop
	jmp xfind_found			; _rscratch = matched NFA
hl_notfound:
	lda #0				; xfind_nomorewords stores A to _dtop/+1
	jmp xfind_nomorewords

; build_hashtable: called once at coldstart (right after generate_token_table,
; before any user code runs, so all the scratch zero-page registers are free).
; Two passes over the static core chain (each walks newest-first from
; forth_system_n via the same LFA decode as xfind_nextword, factored into
; bh_advance): pass 1 counts named words per bucket, a prefix pass converts
; the counts into cumulative slice-END pointers, and pass 2 places each
; word's NFA by decrementing its bucket's pointer in place (counting-sort
; trick) - leaving HASHIDX[b] = slice start, HASHIDX[b+1] = slice end,
; exactly what hash_lookup consumes. Fill-downward + newest-first walk puts
; the newest word at each slice's end, where hash_lookup looks first.
build_hashtable:
	lda #0
	sta hash_ok			; invalid until fully built
	ldx #0				; zero HASHIDX (256 bytes + 2 sentinel)
bh_zeroidx:
	sta HASHIDX,x
	inx
	bne bh_zeroidx
	sta HASHIDX+256
	sta HASHIDX+257

; PASS 1: count named words per bucket (16-bit counts kept in HASHIDX[b])
	lda #<forth_system_n
	sta _rscratch
	lda #>forth_system_n
	sta _rscratch+1
bh1_loop:
	jsr bh_hashword			; A = bucket*2, or carry set = nameless
	bcs bh1_next
	tax
	inc HASHIDX,x
	bne bh1_next
	inc HASHIDX+1,x
bh1_next:
	ldx _scratch			; length, for the LFA decode
	jsr bh_advance
	bcc bh1_loop

; PREFIX: counts -> cumulative slice-END pointers, then the capacity check
	lda #<HASHNFA
	sta _scratch_1
	lda #>HASHNFA
	sta _scratch_1+1
	ldx #0
bh_prefix:
	lda HASHIDX,x			; _scratch_2 = 2*count
	sta _scratch_2
	lda HASHIDX+1,x
	sta _scratch_2+1
	asl _scratch_2
	rol _scratch_2+1
	lda _scratch_1			; p += 2*count
	clc
	adc _scratch_2
	sta _scratch_1
	lda _scratch_1+1
	adc _scratch_2+1
	sta _scratch_1+1
	lda _scratch_1			; HASHIDX[b] = p = END of slice b
	sta HASHIDX,x
	lda _scratch_1+1
	sta HASHIDX+1,x
	inx
	inx
	bne bh_prefix			; 128 entries: x = 0,2,..,254 then wraps
	lda _scratch_1			; sentinel = end of the populated array
	sta HASHIDX+256
	lda _scratch_1+1
	sta HASHIDX+257

	lda _scratch_1+1		; p_final > HASHNFA_END? core outgrew the
	cmp #>HASHNFA_END		; table: return with hash_ok still 0 and
	bcc bh_capok			; every lookup stays linear - degrades to
	bne bh_over			; slow, never to a memory stomp
	lda _scratch_1
	cmp #<HASHNFA_END
	bcc bh_capok
	beq bh_capok
bh_over:
	rts

bh_capok:
; PASS 2: place each named word's NFA, filling slices downward in place
	lda #<forth_system_n
	sta _rscratch
	lda #>forth_system_n
	sta _rscratch+1
bh2_loop:
	jsr bh_hashword
	bcs bh2_next
	tax
	lda HASHIDX,x			; HASHIDX[b] -= 2 (end -> next free slot,
	sec				; ends at slice start when the bucket is
	sbc #2				; fully placed)
	sta HASHIDX,x
	bcs bh2_nb
	dec HASHIDX+1,x
bh2_nb:
	lda HASHIDX,x			; write the NFA into the slot
	sta _scratch_2
	lda HASHIDX+1,x
	sta _scratch_2+1
	ldy #0
	lda _rscratch
	sta (_scratch_2),y
	iny
	lda _rscratch+1
	sta (_scratch_2),y
bh2_next:
	ldx _scratch
	jsr bh_advance
	bcc bh2_loop

	lda #1				; table complete and consistent
	sta hash_ok
	rts

; bh_hashword: hash the name of the word at _rscratch (an NFA). Returns
; A = bucket*2 with carry clear, or carry set for a nameless word (skip).
; Leaves the length in _scratch; clobbers X/Y/_wscratch. MUST compute the
; identical function to hash_lookup's inline version: acc = len, then per
; char in FORWARD order acc = rotl8(acc) eor (char & $5f). (Order matters
; because of the rotate - the chars sit at NFA offsets 1..len here vs
; 0..len-1 of the target string there.)
bh_hashword:
	ldy #0
	lda (_rscratch),y
	and #NAMEMASK
	sta _scratch
	beq bh_hw_skip
	sta _wscratch			; acc = len
	tax				; X = char countdown
	ldy #1
bh_hw_loop:
	asl _wscratch
	bcc bh_hw_nr
	inc _wscratch
bh_hw_nr:
	lda (_rscratch),y
	and #$5f
	eor _wscratch
	sta _wscratch
	iny
	dex
	bne bh_hw_loop
	lda _wscratch
	and #HASH_MASK
	asl				; bucket*2; asl of <=$7F leaves carry clear
	rts
bh_hw_skip:
	sec
	rts

; bh_advance: step _rscratch to the previous word via its LFA (identical
; decode to xfind_nextword). X = current word's length on entry. Returns
; carry set when the start of the chain is reached.
bh_advance:
	lda #0
	sta _wscratch+1
	txa
	tay
	iny
	lda (_rscratch),y
	beq bha_done			; LFA=0: first core word - end of chain
	bpl bha_ok
	cmp #$ff			; "$FF alone" never occurs inside core;
	beq bha_done			; bail safely if it ever does
	and #$7f
	sta _wscratch+1
	iny
	lda (_rscratch),y
bha_ok:
	sta _wscratch
	jsr rscratch_sub_wscratch
	clc
	rts
bha_done:
	sec
	rts
}


; Close to the reference implementation:
; : find 0 #order @ 0 ?do
;        over count i cells context + @ search-wordlist
;        ?dup if
;             2swap 2drop leave
;             then
;        loop ;

+header ~find, ~find_n, "FIND"
	+forth
	+token zero
	+literal _numorder
	+token cpeek, zero, xqdo			; note c@ instead of @ - we have much less than 256 items
	+address find_exit
find_loop:
	+token over, count, i
	+literal _context
	+token add, cpeek
	+token search_wordlist
	+token qdup
	+qbranch_fwd find_next
	+token twoswap, twodrop, leave
find_next:
	+token xloop
	+address find_loop
find_exit:
	+token exit

fragment_4:
	cmp #$40
	bcc +
	and #$5f
+:
	+sub '0'
	cmp #10
	rts

+header ~xdigit, ~xdigit_n	; (DIGIT)
	+code
	lda _dtop
	jsr fragment_4
;	cmp #$40
;	bcc +
;	and #$5f
;+:
;	+sub '0'
;	cmp #10
	bmi xdigit_1
	+sub 'A'-'0'-10
	cmp _base
	bpl xdigit_2
	cmp #0
	bpl xdigit_1
xdigit_2:
	lda #255
	sta _dtop+1
xdigit_1:
	sta _dtop
	jmp next

+header ~tonumber, ~tonumber_n, ">NUMBER"
	+forth
tonumber_1:
	+token dup, zerogt
	+qbranch_fwd tonumber_3									; no more digits left?
	+token over, cpeek, xdigit, dup, zerolt, zeroeq
	+qbranch_fwd tonumber_2	; not a possible digit?
	+token dup, base, peek, less
	+qbranch_fwd tonumber_2						; not a digit in current base?
	+token swap, oneminus, tor, swap, oneplus, tor, tor
	+token base, peek, udmult, rfrom, mplus, rfrom, rfrom
	+branch tonumber_1												; and repeat
tonumber_2:
	+token drop
tonumber_3:
	+token exit

!if FASTLOAD {
; xint ( c-addr -- n 1 | c-addr 0 ): native fast path for NUMBER. Converts a
; counted string of the form [-]digits in the current BASE, wrapping mod
; 65536 exactly like the interpreted path (which converts as a double and
; drops the high cell). ANYTHING else - #/$/% prefixes, 'c' quotes, a
; trailing '.', floats - fails cleanly with c-addr untouched and falls
; through to the original interpreted code below, so all edge semantics
; stay in the proven path. Measured ~14.5ms per numeric token before.
+header ~xint, ~xint_n
	+code
	lda _dtop		; the counted string (left on the stack in case
	sta _rscratch		; of failure)
	lda _dtop+1
	sta _rscratch+1
	ldy #0
	lda (_rscratch),y
	bne xint_notempty	; empty string is not a number (long-form
xint_failj:
	jmp xint_fail		; branch - xint_fail is out of beq range)
xint_notempty:
	sta _scratch_2+1	; length
	lda #0
	sta _scratch_2		; sign flag
	sta _wscratch		; accumulator
	sta _wscratch+1
	ldy #1
	lda (_rscratch),y
	cmp #'-'
	bne xint_digits
	inc _scratch_2		; negative
	iny
	lda _scratch_2+1
	cmp #1			; "-" alone is not a number
	beq xint_failj
xint_digits:
	sty _scratch		; current char index
xint_loop:
	ldy _scratch
	lda (_rscratch),y
	cmp #'0'		; raw digit first, then letters case-masked
	bcc xint_fail
	cmp #'9'+1
	bcs xint_letter
	sec
	sbc #'0'
	jmp xint_have
xint_letter:
	and #$5f
	cmp #'A'
	bcc xint_fail
	cmp #'Z'+1
	bcs xint_fail
	sec
	sbc #'A'-10
xint_have:
	cmp _base		; digit must be valid in the current BASE
	bcs xint_fail
	pha			; save the digit across the multiply
	lda #0			; _scratch_1 = accumulator * BASE (shift-add,
	sta _scratch_1		; wrapping mod 65536 like the original)
	sta _scratch_1+1
	lda _base
	ldx #8
xint_mul:
	asl _scratch_1
	rol _scratch_1+1
	asl
	bcc xint_mskip
	pha
	clc
	lda _scratch_1
	adc _wscratch
	sta _scratch_1
	lda _scratch_1+1
	adc _wscratch+1
	sta _scratch_1+1
	pla
xint_mskip:
	dex
	bne xint_mul
	pla			; accumulator = product + digit
	clc
	adc _scratch_1
	sta _wscratch
	lda _scratch_1+1
	adc #0
	sta _wscratch+1
	inc _scratch		; next char, until the length is consumed
	lda _scratch
	cmp _scratch_2+1
	bcc xint_loop
	beq xint_loop
	lda _scratch_2		; done - apply the sign
	beq xint_pos
	sec
	lda #0
	sbc _wscratch
	sta _wscratch
	lda #0
	sbc _wscratch+1
	sta _wscratch+1
xint_pos:
	+ldax _wscratch		; replace c-addr with the value, push true
	+stax _dtop
	lda #1
	ldx #0
	jmp dpush_and_next
xint_fail:
	lda #0			; c-addr untouched, push false
	tax
	jmp dpush_and_next
}

+header ~number, ~number_n	; NUMBER
	+forth
!if FASTLOAD {
	+token xint
	+qbranch_fwd number_slowpath
	+token state, peek		; same tail as the interpreted single-cell
	+qbranch_fwd number_fastexit	; exit (number_5/number_6 below)
	+token compile, lit, comma
number_fastexit:
	+token exit
number_slowpath:
}
	+token count, base, peek, tor
	+token dup
	+literal 3
	+token equal, two, pick, cpeek
	+literal 39
	+token equal, and_op			; character as 'c'
	+token two, pick, two, add, cpeek
	+literal 39
	+token equal, and_op
	+qbranch_fwd number_8
	+token drop, oneplus, cpeek
	+branch_fwd number_5
number_8:
	+token dup, one, greater
	+qbranch_fwd number_9
	+token over, cpeek
	+literal 35
	+token equal
	+qbranch_fwd number_11
	+token decimal
	+branch_fwd number_10
number_11:
	+token over, cpeek
	+literal 36
	+token equal
	+qbranch_fwd number_12
	+token hex
	+branch_fwd number_10
number_12:
	+token over, cpeek
	+literal 37
	+token equal
	+qbranch_fwd number_9
	+token two, base, poke
number_10:
	+token swap, oneplus, swap, oneminus
number_9:
	+token twodup, false, tor, over, cpeek
	+literal 45
	+token equal
	+qbranch_fwd number_1
	+token rdrop, true, tor, oneminus, swap, oneplus, swap
number_1:
	+token zero, dup, twoswap, tonumber, qdup
	+qbranch_fwd number_4
	+token one, equal, swap, cpeek
	+literal 46
	+token equal, and_op
	+qbranch_fwd number_7	; one unconverted char and it's '.'?
	+token rfrom
	+qbranch_fwd number_2
	+token dnegate
number_2:
	+token twoswap, twodrop, state, peek
	+qbranch_fwd number_3
	+token compile, lit, swap
	+token comma, compile, lit, comma
number_3:
	+branch_fwd number_6
number_4:
	+token drop, twoswap, twodrop, drop, rfrom
	+qbranch_fwd number_5
	+token negate
number_5:
	+token state, peek
	+qbranch_fwd number_6
	+token compile, lit, comma
number_6:
	+token rfrom, base, poke, exit
number_7:
	+token twodrop				; drop the partial value -> ( c-addr u )
!if X16 {
	+token state, peek
	+qbranch_fwd number_try		; interpret: try a float literal; compile: abort
}
number_7abort:
	+token type, xabortq
	+string " ?"
!if X16 {
number_try:
	+token twodup, tofloat		; ( c-addr u -- c-addr u flag ), pushes float if valid
	+qbranch number_7abort		; not a float -> abort with ( c-addr u )
	+token twodrop, rdrop, rfrom, base, poke, exit	; float pushed; clean up and done
}


; ==============================================================================

+header ~nextword, ~nextword_n
	+forth
!if WD_FARHDR {
	+token dup
	+literal CWIN_BASE
	+token uless
	+qbranch_fwd nextword_far
}
	+token dup, nfatolfa
; extract the offset from the LFA (this code may look verbose but the
; native 6502 code is actually about the same in size)
	+token dup, cpeek, dup
	+literal $7f
	+token greater
	+qbranch_fwd nextword_pass
	+token dup
	+literal $ff				; Special case - if the byte at LFA is $ff link to the last word in core
	+token notequal
	+qbranch_fwd nextword_core
	+literal $7f
	+token and_op
	+literal 8
	+token lshift, over, oneplus, cpeek, or
nextword_pass:
	+token nip

	+token qdup
	+qbranch_fwd nextword_done
	+token sub, exit
nextword_done:
	+token drop, zero, exit
nextword_core:
	+token twodrop, drop
	+literal forth_system_n
	+token exit
!if WD_FARHDR {
nextword_far:
	; far record: follow the absolute [addr:2][bank:1] link and keep
	; _scanbank in step (0 marks the end of the chain, like near)
	+token nfatolfa
	+token dup, wdhpeek		; ( lfa prev-nfa )
	+token swap, twoplus, wdhcpeek	; ( prev-nfa prev-bank )
	+literal _scanbank
	+token cpoke
	+token exit
}

; ==============================================================================
; Outer interpreter

+header ~state, ~state_n, "STATE"
	+code doconst
	+value _state

; A trick for check word to abort with the message
qcomp_abort:
	+token xabortq
+header ~qcomp, ~qcomp_n, "?COMP"
	+forth
	+token state, peek
	+qbranch qcomp_abort
	+token exit

qstack_abort:
	+token xabortq
+header ~qstack, ~qstack_n, "?STACK"
!if FASTLOAD {
; INTERPRET runs ?STACK before every token, so this is one of the hottest
; words during compilation. "0 <= DEPTH <= STACKLIMIT" is equivalent to a
; plain 16-bit range check on the _dstack pointer - no DEPTH arithmetic.
QSTACK_LO = DSTACK_INIT - 2*STACKLIMIT
	+code
	lda _dstack
	cmp #<QSTACK_LO
	lda _dstack+1
	sbc #>QSTACK_LO
	bcc qs_bad			; _dstack < LO: overflow (grew down too far)
	lda #<DSTACK_INIT
	cmp _dstack
	lda #>DSTACK_INIT
	sbc _dstack+1
	bcc qs_bad			; _dstack > INIT: underflow
	jmp next
qs_bad:
	lda #<qstack_abort		; run the classic abort fragment (xabortq
	sta _ri				; reads the "?STACK" name that follows it
	lda #>qstack_abort		; as its message)
	sta _ri+1
!if WIDEDICT {
	lda #0				; the fragment is near/core code
	sta _ribank
	sta CBANKREG
}
	jmp next
} else {
	+forth
	+token depth, dup, zerolt, swap
	+literal STACKLIMIT
	+token greater, or, zeroeq
	+qbranch qstack_abort
	+token exit
}

+header ~interpret, ~interpret_n
	+forth
interpret_1:
	+token qstack, bl, word, dup, cpeek
	+qbranch_fwd interpret_done	; get the next word if any
	+token state, peek
	+qbranch_fwd interpret_int
	+token find, qdup
	+qbranch_fwd comp_num
	+token zerolt
	+qbranch_fwd comp_imm		; compiling now
	+token compilecomma
	+branch interpret_1		; regular word in compile mode
comp_imm:
	+token execute
	+branch interpret_1		; immediate word in compile mode
comp_num:
	+token number
	+branch interpret_1
interpret_int:
	+token find
	+qbranch_fwd int_num			; interpreting now
	+token execute
	+branch interpret_1		; any word in interpreter mode
int_num:
	+token number
	+branch interpret_1
interpret_done:
	+token drop, refill, zeroeq
	+qbranch interpret_1
	+token closesource, exit

+header ~closesource, ~closesource_n, "CLOSE-SOURCE"
	+forth
	+token sourceid
	+qbranch_fwd closesource_2						; nothing to do with console source
	+token sourceid, zerogt
	+qbranch_fwd closesource_1
	+token sourceid, closefile, drop
	+literal _ibufcount
	+token dup, cpeek, oneminus, swap, cpoke		; close file and release the buffer
closesource_1:
	+literal _source
	+token dup, peek, dup, peek, oneplus
	+token cells, add, swap, poke	; this will close the last frame
closesource_2:
	+token exit

; ==============================================================================
; Colon definition and related words
; (CREATE) takes cstr,n and creates a raw header (NFA+LFA)
!if WIDEDICT {
; Ensure a code bank is claimed and has WD_HEADROOM left; claim/advance and
; (ROM-bank mode) install the new bank's IRQ-vector tail. Falls back to
; visible-space bodies when code banks are absent (_cbanks_ok=0): _codebank
; stays 0 and colon bodies compile at the data HERE like classic words.
ccw_claim:
	lda _cbanks_ok
	beq ccw_done		; no code banks: stub bank byte stays 0
	lda _codebank
	beq ccw_new		; nothing claimed yet: take the first bank
	sec			; enough room left in this bank?
	lda #<CWIN_TOP
	sbc _chere
	lda #>CWIN_TOP
	sbc _chere+1
	cmp #>WD_HEADROOM
	bcs ccw_done
!if WD_ROMBANKS {
	lda _codebank		; ROM mode: banks ascend 33,34,...
	cmp #CBANK_LAST
	bcs ccw_done		; out of banks: let ?MEM fire naturally
	inc _codebank
} else {
	lda _codebank		; RAM mode: banks descend MEMTOP-1, -2, ...
	cmp #CBANK_FLOOR + 1
	bcc ccw_done		; hit the floor: let ?MEM fire naturally
	dec _codebank
}
	+bra ccw_reset
ccw_new:
!if WD_ROMBANKS {
	lda #CBANK_FIRST
} else {
	lda _codetop		; top of RAM downward
}
	sta _codebank
ccw_reset:
	lda #<CWIN_BASE
	sta _chere
	lda #>CWIN_BASE
	sta _chere+1
!if WD_ROMBANKS {
	jsr ccw_tail		; write the IRQ-vector tail into the new bank
}
ccw_done:
	rts

!if WD_ROMBANKS {
; Write the IRQ tail into the newly claimed (RAM-backed) ROM bank:
;   $FE00: jmp wd_irqshim   $FE03: jmp wd_nmishim
;   native vectors $FFE4-$FFEF and emulation $FFF4-$FFFF -> the stubs.
; Runs with interrupts blocked while the bank register points at the new bank.
ccw_tail:
	php
	sei
	lda CBANKREG
	pha
	lda _codebank
	sta CBANKREG
	lda #$4C		; jmp wd_irqshim
	sta $FE00
	lda #<wd_irqshim
	sta $FE01
	lda #>wd_irqshim
	sta $FE02
	lda #$4C		; jmp wd_nmishim
	sta $FE03
	lda #<wd_nmishim
	sta $FE04
	lda #>wd_nmishim
	sta $FE05
	ldx #10			; native COP/BRK/ABORT/NMI/IRQ ($FFE4-$FFEF,
ccw_tv:				; every word -> $FE00; NMI gets $FE03 below)
	lda #$00
	sta $FFE4,x
	lda #$FE
	sta $FFE5,x
	dex
	dex
	bpl ccw_tv
	lda #$03		; native NMI ($FFEA) -> the NMI stub
	sta $FFEA
	ldx #10			; emulation vectors $FFF4-$FFFF likewise
ccw_ev:
	lda #$00
	sta $FFF4,x
	lda #$FE
	sta $FFF5,x
	dex
	dex
	bpl ccw_ev
	lda #$03		; emulation NMI ($FFFA) -> the NMI stub
	sta $FFFA
	pla
	sta CBANKREG
	plp
	rts

; RAM shims (in the PRG - visible regardless of $01): switch to the KERNAL
; bank, then enter the captured KERNAL handler with a FAKE return frame so
; its RTI lands in wd_irqret, which restores the bank and RTIs for real.
; Native-mode frames: entry pushed [PB PCH PCL P]; RTI pops [P PCL PCH PB].
; An interrupt INHERITS the interrupted code's register widths, and the fused
; 816 primitives run 16-bit-A sections (rep #$20) - so force 8-bit A before
; the first pha or `lda #0` eats the next opcode byte as an immediate. Only
; A: sep #$10 would zero XH/YH before the KERNAL handler could save them.
; The real P (and widths) come back via the final RTI's hardware frame.
wd_irqshim:
	sep #$20		; 8-bit A - this shim is 8-bit code
	pha
	lda $01
	pha			; saved bank (restored by wd_irqret)
	lda #0
	sta $01
	phk			; fake frame: PB=0
	lda #>wd_irqret
	pha
	lda #<wd_irqret
	pha
	php			; P (I is already set; M=1 so wd_irqret is 8-bit)
	jmp (kirq_vec)
wd_nmishim:
	sep #$20		; 8-bit A (same width trap as wd_irqshim)
	pha
	lda $01
	pha
	lda #0
	sta $01
	phk
	lda #>wd_irqret
	pha
	lda #<wd_irqret
	pha
	php
	jmp (knmi_vec)
wd_irqret:
	pla			; the saved bank
	sta $01
	pla			; the saved A
	rti			; pops the REAL interrupt frame
}

; near bank nearly full? move allocation to the far bank (one-time switch)
xcw_advcheck:
!if WD_ROMBANKS = 0 {
	rts			; RAM mode: no bank-2 data window (the $00
}				; register is the dynamic code-bank pin)
	lda _dictbank
	bne xcw_noadv
	sec
	lda _memtop
	sbc _here
	lda _memtop+1
	sbc _here+1
	cmp #>WD_HEADROOM
	bcs xcw_noadv
	lda _here		; remember where the near dictionary ends
	sta _nearhere
	lda _here+1
	sta _nearhere+1
	lda #FARBANK
	sta _dictbank
	lda #<FARBASE
	sta _here
	lda #>FARBASE
	sta _here+1
	lda #<FARTOP
	sta _memtop
	lda #>FARTOP
	sta _memtop+1
xcw_noadv:
	rts

; LFA diff, moved out of xcreate's body (the branch to create_error is
; byte-relative and ran out of range with the WIDEDICT additions). Window
; addresses are plain 16-bit, so the diff crosses the allocation switch
; numerically with no special form.
xcw_diffcalc:
	sec
	lda _here
	sbc _latest
	sta _wscratch
	lda _here+1
	sbc _latest+1
	sta _wscratch+1
	rts

!if WD_FARHDR {
; Far headers v3: build the ENTIRE header record in the code bank:
;   [len|flags][name][token:2][nearhere:2][link: addr:2 + bank:1]
; ( c-addr len ) -> pops len exactly like the classic path (name read via the
; same decrement trick), leaving c-addr for the shared tail's final +dpop.
; C=1: done - the record base is LATEST (_latestbank = its bank), _chere
; points past the record (where wdcolon puts a colon word's [RTS][body][bank]
; stub; data words keep their classic near CFA at the untouched HERE, so the
; created/does/dovalue/dodefer runtimes and DOES>/TO/DEFER stay near-classic).
; C=0: no writable code banks - the caller falls through to the classic
; near-header build. The link is always absolute (addr 0 = end of chain,
; bank 0 = a near/core NFA): no diff forms in far space.
xfh_create:
	lda _cbanks_ok
	bne xfh_go
	clc
	rts
xfh_go:
	jsr ccw_claim		; ensure a claimed bank with WD_HEADROOM left
	lda _codebank
	bne xfh_ok
	clc
	rts
xfh_ok:
	+dpop			; len
	and #NAMEMASK
	sta _scratch
	lda CBANKREG		; pin the code bank around the record build
	pha
	lda _codebank
	sta CBANKREG
	lda _chere
	sta _wscratch
	lda _chere+1
	sta _wscratch+1
	ldy #0
	lda _scratch
	sta (_wscratch),y	; len byte
	tax
	beq xfh_name0
	lda _dtop		; classic same-index copy from (c-addr - 1)
	bne xfh_nodec
	dec _dtop+1
xfh_nodec:
	dec _dtop
	iny
xfh_copy:
	lda (_dtop),y
	sta (_wscratch),y
	iny
	dex
	bne xfh_copy
xfh_name0:
	ldy _scratch
	iny			; y = len+1 -> the token field
	clc
	lda _hightoken		; token = _hightoken+1 (the tail increments)
	adc #1
	sta (_wscratch),y
	iny
	lda _hightoken+1
	adc #0
	sta (_wscratch),y
	iny
	lda _here		; nearhere = FORGET's near rewind point
	sta (_wscratch),y
	iny
	lda _here+1
	sta (_wscratch),y
	iny
	lda _current		; link = [voc head NFA:2][voc head bank:1]
	asl
	tax
	lda _vocs,x
	sta (_wscratch),y
	iny
	lda _vocs+1,x
	sta (_wscratch),y
	iny
	ldx _current
	lda _vocsbank,x
	sta (_wscratch),y
	iny			; y = len+8 = the record length
	pla
	sta CBANKREG		; unpin
	lda _chere		; LATEST = the record base, in _codebank
	sta _latest
	lda _chere+1
	sta _latest+1
	lda _codebank
	sta _latestbank
	sta _scanbank
	tya			; _chere += record length
	clc
	adc _chere
	sta _chere
	bcc xfh_done
	inc _chere+1
xfh_done:
	sec
	rts
}
}

+header ~xcreate, ~xcreate_n
	+code
!if WIDEDICT {
	jsr xcw_advcheck	; may switch allocation to the far bank
}

; check if we have available tokens
	lda _hightoken+1
	cmp #>TOKEN_COUNT
	bcc +

	+goforth
	+branch_fwd create_error
+:

!if WD_FARHDR {
	jsr xfh_create		; build the whole header in the code bank
	bcc +			; C=0: no code banks - classic near header
	jmp xcreate_join	; far done - skip to the token-table update
+:
}

; calculate contents for the new LFA
; Temporarily reloading _latest as it will be updated on the next step
; Special case to link to the core first
	lda _latest
	cmp #<forth_system_n
	bne +
	lda _latest+1
	cmp #>forth_system_n
	bne +
	lda #0
	sta _wscratch
	lda #$ff
	sta _wscratch+1
	bne ++
+
	lda _current
	asl
	tay
	lda _vocs,y
	sta _latest
	lda _vocs+1,y
	sta _latest+1

	ora _latest			; if _latest is NULL at this point, the LFA should be NULL as well, not a diff (TODO: validate)
	bne +
	sta _wscratch
	sta _wscratch+1
	beq ++
+:
!if WIDEDICT {
	jsr xcw_diffcalc	; LFA diff, or the $FE far-link marker
} else {
	sec
	lda _here
	sbc _latest
	sta _wscratch
	lda _here+1
	sbc _latest+1
	sta _wscratch+1
}
++:
	
	+ldax _here		; register the word as LATEST
	+stax _latest
	
	+dpop
	and #NAMEMASK
	ldy #0
	sta (_here),y
	iny
	tax
	beq xcreate_5
	lda _dtop
	bne xcreate_3
	dec _dtop+1
xcreate_3:
	dec _dtop
	
xcreate_1:			; copy name string
	lda (_dtop),y
	sta (_here),y
	iny
	dex
	bne xcreate_1
	
xcreate_5:
	lda _wscratch	; write LFA
	cmp #$ff
	beq xcreate_4
	and #$80
	ora _wscratch+1	; >= 128?
	beq xcreate_4
	lda _wscratch+1
	ora #$80
	sta (_here),y
	iny
xcreate_4:
	lda _wscratch
	sta (_here),y
	iny
	
xcreate_hupd:
	tya
	clc				; update HERE
	adc _here
	sta _here
	bcc +
	inc _here+1
+:

	; update token table
!if WD_FARHDR {
xcreate_join:			; far path: TOKENS[t] = the (untouched) near
}				; HERE = a data word's classic CFA; wdcolon
				; repoints colon words to the far stub
	inc _hightoken
	bne +
	inc _hightoken+1
+:
	+ldax _hightoken
	asl
	sta _wscratch
	txa
	rol
	adc #>TOKENS
	sta _wscratch+1
	ldy #0
	lda _here
	sta (_wscratch),y
	iny
	lda _here+1
	sta (_wscratch),y

!if WIDEDICT {
	clc			; TOKBANK[_hightoken] = current allocation bank
	lda _hightoken
	adc #<TOKBANK
	sta _wscratch
	lda _hightoken+1
	adc #>TOKBANK
	sta _wscratch+1
	lda _dictbank
	ldy #0
	sta (_wscratch),y
}

	+dpop
	jmp next


+error_message ~create_error
+header ~create, ~create_n, "CREATE"
	+forth
!if WD_FARHDR {
	; far header, classic near CFA; the reveal also records the header's bank
	+token bl, word, count, xcreate
	+literal JMP_INSTR
	+token ccomma
	+literal created
	+token comma, latest, context, poke
	+literal _latestbank
	+token cpeek
	+literal _current
	+token cpeek
	+literal _vocsbank
	+token add, cpoke, exit
} else if WIDEDICT {
	; the pre-xcreate HERE capture (= the new NFA) goes stale when xcreate
	; switches allocation banks - reveal via LATEST (xcreate sets it) instead
	+token bl, word, count, xcreate
	+literal JMP_INSTR
	+token ccomma
	+literal created
	+token comma, latest, context, poke, exit
} else {
	+token here, bl, word, count, xcreate
	+literal JMP_INSTR
	+token ccomma
	+literal created
	+token comma, context, poke, exit
}

; DOES> is a weird beast. It generates code that will modify the execution of the
; last defined word to jump to the definition word. It is also quite non-portable as it generates a low level instruction
+header ~xcode, ~xcode_n		; (;CODE)
	+forth
	+token rfrom								; which is the address of the "call xdoes" instruction
!if WIDEDICT {
	; Two callers: CONSTANT/VARIABLE/MARKER/etc are CORE (visible body) and
	; use the classic inline "xcode JSR does <does-body>" form - rfrom already
	; points at the visible JSR-does, use it directly. A user DOES> in a FAR
	; defining word can't put the DOES-code in the far body (the child's JMP
	; would miss the bank), so doesx stashed it VISIBLE and left an OPERAND
	; (the visible address) in the far body - deref that. Distinguish by
	; whether rfrom points into the code window.
	+token dup
	+literal CWIN_BASE
	+token uless
	+qbranch_fwd xcode_far
	+branch_fwd xcode_cfa			; near (visible defining word): as-is
xcode_far:
	+token peek				; far: deref the operand -> visible addr
xcode_cfa:
	+literal _bsp		; R> consumed the caller's frame - drop its
	+token cpeek, oneminus	; bank-stack entry too (_bsp C@ 1- _bsp C!)
	+literal _bsp
	+token cpoke
}
!if WD_FARHDR {
	; the child's CFA comes from the token table (its far header is not
	; adjacent to the near CFA anymore); the child is always LATEST
	+literal _hightoken
	+token peek, xttocfa
} else {
	+token latest, count
	+literal NAMEMASK
	+token and_op, add, lfatocfa ;twoplus		; CFA of the last defined word
}
	+token oneplus ; PFA (!)
	+token poke, exit							; and this will actually exit the defining word

qdefer_abort:
	+token xabortq
+header ~qdefer, ~qdefer_n	; ?DEFER
	+forth
	+token dup, tobody, twominus, peek
	+literal dodefer
	+token equal
	+qbranch qdefer_abort
	+token exit

+header ~deferpeek, ~deferpeek_n, "DEFER@"
	+forth
	+token qdefer, tobody, peek, exit

+header ~deferpoke, ~deferpoke_n, "DEFER!"
	+forth
	+token qdefer, tobody, poke, exit

+header ~comppoke, ~comppoke_n
	+forth
	+token compile, lit, comma, compile, poke, exit

+error_message ~tick_error
+header ~tick, ~tick_n, "'"
	+forth
	+token bl, word, find
	+qbranch tick_error
	+token exit

+header ~btick, ~btick_n, "[']", IMM_FLAG
	+forth
	+token qcomp, tick
	+token compile, lit, comma
	+token exit

; This will get the next parameter, compile it to the current definition and skip
+header ~compile, ~compile_n, "COMPILE"
	+forth
	+token rfrom, dup, oneplus, swap, cpeek, dup
	+literal 16
	+token less
	+qbranch_fwd compile_lastbyte
	+token ccomma, dup, oneplus, swap, cpeek
compile_lastbyte:
	+token ccomma, tor, exit

+header ~compilecomma, ~compilecomma_n, "COMPILE,"
	+forth
	+token dup
	+literal 255
	+token greater
	+qbranch_fwd compilecomma_1
	+token dup
	+literal 8
	+token rshift, ccomma
compilecomma_1:
	+token ccomma, exit

+header ~bracket, ~bracket_n, "[", IMM_FLAG
	+forth
	+token qcomp, false, state, poke, exit

+header ~bracketx, ~bracketx_n, "]"
	+forth
	+token true, state, poke, exit

+header ~commaquote, ~commaquote_n, ",\""
	+forth
	+literal '"'
	+token parse, dup, ccomma, here
	+token over, allot, swap, cmove, exit

+header ~cquote, ~cquote_n, "C\"", IMM_FLAG
	+forth
!if WIDEDICT {
	; A compiled counted string must be readable by the CALLER (C@/@ after
	; the word returns), so it can't live in the far body. Store it in
	; VISIBLE data space (the parked _dhere) and compile just LIT <vaddr>.
	+token qcomp
	+literal '"'
	+token parse				; ( ca u )
	+literal _dhere
	+token peek				; ( ca u dst )
	+token dup, tor				; R: dst(=vaddr)
	+token twodup, cpoke			; store length byte at dst
	+token charplus, swap			; ( ca dst+1 u )
	+token dup, tor				; R: dst u
	+token cmove				; copy chars (src near, dst visible)
	+token rfrom				; ( u )   R: dst
	+token rat, add, charplus		; new _dhere = dst + u + 1
	+literal _dhere
	+token poke
	+token rfrom				; ( vaddr )
	+token compile, lit, comma
	+token exit
} else {
	+token qcomp, compile, branch, fmark
	+token here, swap, commaquote, fresolve, compile, lit, comma
	+token exit
}

; In some cases (ABORT?) may be called when the data stack is in bad state. This would fix it
+header ~fixdstack, ~fixdstack_n
	+code
	jsr init_dstack
	jmp next

; Nominally (ABORT?) - will print the string following the word and call ABORT
+header ~xabortq, ~xabortq_n
	+forth
	+token fixdstack
	+token rat, count
	+literal NAMEMASK
	+token and_op, type, abort, exit

+header ~xquit, ~xquit_n
	+code
quit_c:
!if WIDEDICT {
	lda _incode		; an abort mid-definition leaves HERE swapped
	beq quit_nsw		; into code space - undo it
	lda _here
	sta _chere
	lda _here+1
	sta _chere+1
	lda _dhere
	sta _here
	lda _dhere+1
	sta _here+1
	lda _dmemtop
	sta _memtop
	lda _dmemtop+1
	sta _memtop+1
	lda #0
	sta _incode
quit_nsw:
	lda #0
	sta _ribank
	sta CBANKREG		; unpin
}
	jsr close_open_files
	jsr init_rstack
	lda #<forth_system_r		; don't show the banner
	ldx #>forth_system_r
	+stax _ri
	jmp next


+header ~xforget, ~xforget_n	; xt -> (delete all words from this address)
	+forth
!if WD_FARHDR {
; Far headers: window NFAs are not ordered across banks, but tokens are
; definition-ordered - so the walk compares each header's stored token with
; the boundary. The boundary word's record supplies the rewind state:
; _chere/_codebank = its own record base/bank (headers are the first thing
; a word allocates), _here = its stored nearhere breadcrumb.
	+token dup
	+literal forth_system
	+token greater
	+qbranch_fwd xfgf_fence
	+branch_fwd xfgf_go
xfgf_fence:
	+token xabortq
	+string "?FENCE"
xfgf_go:
; Reset the search order to default
	+token minusone, set_order, zero
	+literal _current
	+token cpoke
	+token oneminus			; new _hightoken = xt-1
	+literal _hightoken
	+token poke			; ( )
	+literal forth_system_n		; _latest defaults: the newest survivor
	+literal _latest		; is tracked during the walk below
	+token poke
	+token zero
	+literal _latestbank
	+token cpoke
	+literal forth_system		; ( maxtok ) running max survivor token
; Walk every wordlist: unlink far heads with token > xt-1, capture the
; boundary record, keep _vocs/_vocsbank and the LATEST tracking in step
	+literal _numvocs
	+token cpeek, zero, xqdo
	+address xfgf_wdone
xfgf_wloop:
	+token i
	+literal _vocsbank
	+token add, cpeek
	+literal _scanbank
	+token cpoke
	+token i, cells
	+literal _vocs
	+token add, peek		; ( maxtok nfa )
xfgf_scan:
	+token dup
	+literal CWIN_BASE
	+token uless
	+qbranch_fwd xfgf_far
	+branch_fwd xfgf_keep		; near head = core: keep
xfgf_far:
	+token dup, dup, wdhcpeek	; token field at NFA+len+1
	+literal NAMEMASK
	+token and_op, add, oneplus, wdhpeek	; ( maxtok nfa tok )
	+token dup
	+literal _hightoken
	+token peek, greater
	+qbranch_fwd xfgf_keepdrop	; tok <= xt-1: survivor
	+literal _hightoken
	+token peek, oneplus, equal	; ( maxtok nfa tok==xt ) consumes tok
	+qbranch_fwd xfgf_hop
	+token dup			; the boundary: capture the rewind state
	+literal _chere
	+token poke
	+literal _scanbank
	+token cpeek
	+literal _codebank
	+token cpoke
	+token dup, dup, wdhcpeek	; nearhere field at NFA+len+3
	+literal NAMEMASK
	+token and_op, add
	+literal 3
	+token add, wdhpeek
	+literal _here
	+token poke			; ( maxtok nfa )
xfgf_hop:
	+token nextword			; follow the link (updates _scanbank)
	+branch xfgf_scan
xfgf_keepdrop:
	+token drop			; ( maxtok nfa )
xfgf_keep:
	+token dup, i, cells		; store the surviving head + its bank
	+literal _vocs
	+token add, poke
	+literal _scanbank
	+token cpeek, i
	+literal _vocsbank
	+token add, cpoke		; ( maxtok nfa )
	+token dup
	+literal CWIN_BASE
	+token uless
	+qbranch_fwd xfgf_ftok
	+token drop			; near head: token = forth_system = the
	+branch_fwd xfgf_next		; seed - never a new max
xfgf_ftok:
	+token dup, dup, wdhcpeek	; ( maxtok nfa nfa len' )
	+literal NAMEMASK
	+token and_op, add, oneplus, wdhpeek	; ( maxtok nfa tok )
	+token rot			; ( nfa tok maxtok )
	+token twodup, greater		; ( nfa tok maxtok tok>maxtok )
	+qbranch_fwd xfgf_nomax
	+token drop, swap, dup		; ( tok nfa nfa ) new max: this head
	+literal _latest		; becomes LATEST
	+token poke
	+literal _scanbank
	+token cpeek
	+literal _latestbank
	+token cpoke
	+token drop			; ( tok ) = the new maxtok
	+branch_fwd xfgf_next
xfgf_nomax:
	+token nip, nip			; ( maxtok )
xfgf_next:
	+token xloop
	+address xfgf_wloop
xfgf_wdone:
	+token drop			; ( )
; Drop wordlists whose creator word is forgotten (creator tokens >= xt)
	+literal _numvocs
	+token cpeek, one, xqdo
	+address xfgf_vndone
xfgf_vn:
	+literal _hightoken
	+token peek, i, cells
	+literal _vocsref
	+token add, peek, less
	+qbranch_fwd xfgf_vnok
	+token i
	+literal _numvocs
	+token cpoke, leave
xfgf_vnok:
	+token xloop
	+address xfgf_vn
xfgf_vndone:
	+literal MEMTOP			; data space is near again in full
	+literal _memtop
	+token poke
	+token exit
} else {
; Protect the core
	+token dup
	+literal forth_system
	+token greater
	+qbranch_fwd xforget_error
!if WIDEDICT {
; boundary word is a colon stub with a far body? rewind the code space to it
	+token dup, xttocfa		; ( xt cfa )
	+token dup, cpeek
	+literal RTS_INSTR
	+token equal
	+qbranch_fwd xfg_nostub
	+token dup
	+literal 3
	+token add, cpeek, qdup		; ( xt cfa [bank] )
	+qbranch_fwd xfg_nostub
	+literal _codebank
	+token cpoke			; ( xt cfa )
	+token dup, oneplus, peek
	+literal _chere
	+token poke
xfg_nostub:
	+token drop			; ( xt )
}
; Reset the search order to default
	+token minusone, set_order, zero
	+literal _current
	+token cpoke

; Set HERE to the NFA of the specified word. Keep that NFA for further comparisons
	+token dup, xttocfa, cfatolfa, lfatonfa
	+literal _here
	+token poke
; Set hightoken to the previous one and get that NFA for LATEST
	+token oneminus, dup
	+literal _hightoken
	+token poke, xttocfa, cfatolfa, lfatonfa
	
	+token dup
	+literal _latest
	+token poke

; Delete all vocabularies above HERE, except voc 0 (may be in high ROM)
	+literal _numvocs
	+token cpeek, one, xqdo
	+address xforget_vndone
xforget_vn:
	+token dup, i, cells
	+literal _vocsref
!if WIDEDICT {
	+token add, peek, uless
} else {
	+token add, peek, less
}
	+qbranch_fwd xforget_vnok
	+token i
	+literal _numvocs
	+token cpoke, leave
xforget_vnok:
	+token xloop
	+address xforget_vn
xforget_vndone:

; In all remaining vocabularies, remove all words above here
	+literal _numvocs
	+token cpeek, zero, xqdo
	+address xforget_wdone
xforget_wloop:
	+token i, cells
	+literal _vocs
	+token add, peek
xforget_nw:
!if WIDEDICT {
	+token dup, tor, over, ugreater	; far NFAs are "negative" as signed
} else {
	+token dup, tor, over, greater
}
	+qbranch_fwd xforget_nwok
	+token rfrom, nextword
	+branch xforget_nw
xforget_nwok:
	+token rfrom, i, cells
	+literal _vocs
	+token add, poke
	+token xloop
	+address xforget_wloop
xforget_wdone:

!if WIDEDICT {
	+literal _here		; forgotten back into the near bank? undo the
	+token peek		; allocation switch
	+literal FARBASE
	+token uless
	+qbranch_fwd xforget_stillfar
	+token zero
	+literal _dictbank
	+token cpoke
	+literal MEMTOP
	+literal _memtop
	+token poke
xforget_stillfar:
}
	+token drop, exit

xforget_error:
	+token xabortq
	+string "?FENCE"
}

+header ~addfield, ~addfield_n, "+FIELD"
	+forth
	+token create, over, comma, add, xcode
	!byte JSR_INSTR
	+address does
	+token peek, add, exit
			

; ==============================================================================
; These are non-standard, but they are used to implement control words,
; basically, that's how forward and backward references are done.
; Not exposing in core, but they will be documented in the toolkit

+header ~fmark, ~fmark_n	; >MARK
	+forth
	+token here, zero, comma, exit

+header ~fresolve, ~fresolve_n	; >RESOLVE
	+forth
	+token here, swap, poke, exit

+header ~rmark, ~rmark_n	; <MARK
	+forth
	+token here, exit

+header ~rresolve, ~rresolve_n	; <RESOLVE
	+forth
	+token comma, exit

; ==============================================================================
; Some nice to have words

+header ~spaces, ~spaces_n, "SPACES"
	+forth
spaces_1:
	+token dup, zerogt
	+qbranch_fwd spaces_2
	+token oneminus, space
	+branch spaces_1
spaces_2:
	+token drop, exit

; In optional String word set
dpop_scratch_wscratch: ; used in quite a few places
	+dpop
	+stax _scratch
	+dpop
	+stax _wscratch
	rts

dpop_scratch_wscratch_rscratch:
	jsr dpop_scratch_wscratch
	+dpop
	+stax _rscratch
	rts
	
dpop_scratch_wscratch_dtopto_rscratch:
	jsr dpop_scratch_wscratch
	+ldax _dtop
	+stax _rscratch
	rts


; NATIVE816: MVN moves the whole (count) block in one CPU-microcoded pass
; instead of the 6502 nested-loop-with-page-carry above (kept unmodified for
; the other platforms/non-native build - see dpop_scratch_wscratch_rscratch
; for the _scratch=count/_wscratch=dest/_rscratch=source assignment). MVN
; walks addresses upward (matches CMOVE's low-to-high copy order); count==0
; must be special-cased since MVN's operand is (count-1) and would otherwise
; wrap into a 65536-byte copy.
!if NATIVE816 {
+header ~cmove, ~cmove_n, "CMOVE"
	+code
	jsr dpop_scratch_wscratch_rscratch
!if WIDEDICT {
	lda _wscratch+1		; destination in the code-bank window? (compile-
	cmp #>CWIN_BASE		; time string copies: commaquote/SLITERAL/PLACE)
	bcs cmove_win		; MVN uses flat banks that miss the window, so
}				; loop through the window with the register pinned
	lda _scratch
	ora _scratch+1
	beq cmove_done
	rep #$30
!al
!rl
	lda _scratch
	dec
	ldx _rscratch
	ldy _wscratch
	mvn 0, 0		; bank 0 -> bank 0 ($A000+ goes via the window)
!as
!rs
	sep #$30
cmove_done:
	jmp next

!if WIDEDICT {
cmove_win:
	lda CBANKREG
	pha
	lda _codebank
	sta CBANKREG
	ldy #0
cmw_loop:
	lda _scratch
	ora _scratch+1
	beq cmw_end
	lda (_rscratch),y	; source (near for compile-time copies)
	sta (_wscratch),y	; dest through the window
	inc _rscratch
	bne cmw_s
	inc _rscratch+1
cmw_s:
	inc _wscratch
	bne cmw_d
	inc _wscratch+1
cmw_d:
	lda _scratch
	bne cmw_dec
	dec _scratch+1
cmw_dec:
	dec _scratch
	jmp cmw_loop
cmw_end:
	pla
	sta CBANKREG
	jmp next
}

; In optional String word set
+header ~cmovex, ~cmovex_n, "CMOVE>"
	+code
	jsr dpop_scratch_wscratch_rscratch
!if WIDEDICT {
	lda _wscratch+1
	cmp #>CWIN_BASE
	bcs cmovex_win
}
	lda _scratch
	ora _scratch+1
	beq cmovex_done
	rep #$30
!al
!rl
	lda _scratch		; MVP walks addresses downward (matches CMOVE>'s
	dec			; high-to-low copy order) - X/Y must hold the LAST
	clc			; byte of each region, not the first.
	adc _rscratch
	tax
	lda _scratch
	dec
	clc
	adc _wscratch
	tay
	lda _scratch
	dec
	mvp 0, 0
!as
!rs
	sep #$30
cmovex_done:
	jmp next

!if WIDEDICT {
cmovex_win:
	; point both pointers at the LAST byte, copy downward through the window
	clc
	lda _rscratch
	adc _scratch
	sta _rscratch
	lda _rscratch+1
	adc _scratch+1
	sta _rscratch+1
	lda _rscratch		; -1 (MVP semantics: end at first byte)
	bne cmxw_r
	dec _rscratch+1
cmxw_r:
	dec _rscratch
	clc
	lda _wscratch
	adc _scratch
	sta _wscratch
	lda _wscratch+1
	adc _scratch+1
	sta _wscratch+1
	lda _wscratch
	bne cmxw_w
	dec _wscratch+1
cmxw_w:
	dec _wscratch
	lda CBANKREG
	pha
	lda _codebank
	sta CBANKREG
	ldy #0
cmxw_loop:
	lda _scratch
	ora _scratch+1
	beq cmxw_end
	lda (_rscratch),y
	sta (_wscratch),y
	lda _rscratch
	bne cmxw_rd
	dec _rscratch+1
cmxw_rd:
	dec _rscratch
	lda _wscratch
	bne cmxw_wd
	dec _wscratch+1
cmxw_wd:
	dec _wscratch
	lda _scratch
	bne cmxw_dec
	dec _scratch+1
cmxw_dec:
	dec _scratch
	jmp cmxw_loop
cmxw_end:
	pla
	sta CBANKREG
	jmp next
}
} else {
+header ~cmove, ~cmove_n, "CMOVE"
	+code
	jsr dpop_scratch_wscratch_rscratch

	ldy #0
	ldx _scratch+1
	beq movedown_2
movedown_1:
	lda (_rscratch),y
	sta (_wscratch),y
	iny
	bne movedown_1
	inc _rscratch+1
	inc _wscratch+1
	dex
	bne movedown_1
movedown_2:
	ldx _scratch
	beq movedown_4
movedown_3:
	lda (_rscratch),y
	sta (_wscratch),y
	iny
	dex
	bne movedown_3
movedown_4:

	jmp next

; In optional String word set
+header ~cmovex, ~cmovex_n, "CMOVE>"
	+code
	jsr dpop_scratch_wscratch_rscratch
;	+dpop
;	+stax _scratch
;	+dpop
;	+stax _wscratch
;	+dpop
;	+stax _rscratch

	ldx _scratch+1
	txa
	clc
	adc _rscratch+1
	sta _rscratch+1
	txa
	clc
	adc _wscratch+1
	sta _wscratch+1
	inx
	ldy _scratch
	beq moveup_3
	dey
	beq moveup_2
moveup_1:
	lda (_rscratch),y
	sta (_wscratch),y
	dey
	bne moveup_1
moveup_2:
	lda (_rscratch),y
	sta (_wscratch),y
moveup_3:
	dey
	dec _rscratch+1
	dec _wscratch+1
	dex
	bne moveup_1
	jmp next
}

+header ~move, ~move_n, "MOVE"
	+forth
	+token rot, rot, twodup, less
	+qbranch_fwd move_1
	+token rot, cmovex, exit
move_1:
	+token rot, cmove, exit

; Non-standard word, similar to CMOVE but does character conversions for S\". Returns number
; of characters processed and returned
; addr_from, addr_to, len_limit -> len_actual, let_result
; Note that this implementation is an overkill for S\" word - the string in that word cannot
; possibly be longer than 100 characters.
_sactual = _dtop
_sresult = _scratch_1
_stemp = _scratch_2

+header ~smove, ~smove_n	; SMOVE
	+code
	jsr dpop_scratch_wscratch_dtopto_rscratch
;	+dpop
;	+stax _scratch
;	+dpop
;	+stax _wscratch
;	+ldax _dtop
;	+stax _rscratch
	
	lda #0
	sta _sactual
	sta _sactual+1
	sta _sresult
	sta _sresult+1

	tay
	ldx _scratch+1
	beq smove_2
smove_1:
	jsr smove_char
	iny
	bne smove_1
	inc _rscratch+1
	inc _wscratch+1
	dex
	bne smove_1
smove_2:
	ldx _scratch
	beq smove_4
smove_3:
	jsr smove_char
	iny
	dex
	bne smove_3
smove_4:

	+ldax _sresult
	jmp dpush_and_next

smove_char:
	+inc16 _sactual		; increasing the actual count before any checks so it will include the quote
	lda (_rscratch),y
	cmp #'\"'
	beq smove_7			; end of the string
	cmp #'\\'
	bne smove_8			; is this an escaped character
	jsr smove_fragment
;	+inc16 _sactual
;	+inc16 _rscratch
;	lda (_rscratch),y
	and #$5f			; case insensitive
	cmp #'M'
	bne smove_9			; 'm' translated into two character
	lda #13
	sta (_wscratch),y
	+inc16 _wscratch
	+inc16 _sresult
	lda #10
	bne smove_8
smove_9:
	cmp #'X'			; 'x' is a hex sequence
	bne smove_10
	jsr smove_fragment
;	+inc16 _sactual
;	+inc16 _rscratch
;	lda (_rscratch),y
	jsr smove_hexdigit
	asl
	asl
	asl
	asl
	sta _stemp
	jsr smove_fragment
;	+inc16 _sactual
;	+inc16 _rscratch
;	lda (_rscratch),y
	jsr smove_hexdigit
	ora _stemp
	+bra smove_8
smove_10:
	cmp #'A'
	bmi smove_11
	cmp #'Z'+1
	bpl smove_11
	stx _stemp
	+sub 'A'
	tax
	lda smove_subst,x
	ldx _stemp
	+bra smove_8
smove_11:
	lda (_rscratch),y	; reload to restore case
smove_8:
	sta (_wscratch),y
	+inc16 _sresult		; increasing the result after the character is written to the destination
	rts
smove_7:
	ldx #0
	stx _scratch
	inx					; this will instantly terminate both loops in the caller
	rts

smove_hexdigit:
	jsr fragment_4
;	cmp #$40
;	bcc +
;	and #$5f
;+:
;	+sub '0'
;	cmp #10
	bmi smove_h1
	+sub 'A'-'0'-10
smove_h1:
	rts

smove_fragment:
	+inc16 _sactual
	+inc16 _rscratch
	lda (_rscratch),y
	rts

smove_subst:
	!byte 7,8,'C','D',27,12,'G','H','I','J','K'
	!byte 10,'M',NEW_LINE,'O','P',34,13,'S',9,'U',11
	!byte 'W','X','Y',0

+header ~fill, ~fill_n, "FILL"
	+forth
	+token swap, tor, swap
fill_1:
	+token rfrom, qdup
	+qbranch_fwd fill_2
	+token oneminus, tor, twodup, cpoke, oneplus
	+branch fill_1
fill_2:
	+token twodrop, exit


; The next two are non-standard but proposed for inclusion
+header ~place, ~place_n, "PLACE"
	+forth
	+token twodup, twotor, charplus, swap
	+token chars, move, tworfrom, cpoke, exit

+header ~plusplace, ~plusplace_n, "+PLACE"
	+forth
	+token dup, count, add, tor, twodup, cpeek
	+token add, swap, cpoke, rfrom, swap, move, exit

; ==============================================================================
; More words from the optional Double-Number word set

; For possible optimizations we assign scratch, wscratch, and rscratch in the order of use
wlow = _wscratch
whigh = _scratch

!if NATIVE816 {
; NATIVE816: the whole thing is really a 32-bit add across two 16-bit cells
; (sum.lo = d1.lo+d2.lo, sum.hi = d1.hi+d2.hi+carry) - the original's Y
; juggling only exists because a 6502 pop only hands back two registers
; (A:X), so d1.hi (fetched via +dpop, not yet in memory) needs a temp home
; before it can be added. Stash it in _rscratch (unused elsewhere here),
; then two chained native 16-bit ADCs (no CLC between them, so the carry
; from the low-cell add correctly flows into the high-cell add) replace the
; original's four 8-bit ADCs plus the Y shuffle. Verified by hand: this is
; the exact same two-stage 32-bit add, not a reordering of what it computes.
+header ~dadd, ~dadd_n, "D+"
	+code
	jsr dpop_scratch_wscratch ; see the note about scratch assignments above
	+dpop				; pops d1.hi into A:X - not yet in memory
	+stax _rscratch			; stash d1.hi as a 16-bit cell
	rep #$20
	!al
	clc
	lda _dtop			; d1.lo
	adc wlow			; + d2.lo
	sta _dtop			; sum.lo
	lda _rscratch			; d1.hi
	adc whigh			; + d2.hi + carry from the low-cell add
	sta _rscratch			; sum.hi
	sep #$20
	!as
	+ldax _rscratch
	jmp dpush_and_next
} else {
+header ~dadd, ~dadd_n, "D+"
	+code
	jsr dpop_scratch_wscratch ; see the note about scratch assignments above
;	+dpop
;	+stax whigh
;	+dpop
;	+stax wlow
	+dpop
	tay
	clc
	lda _dtop
	adc wlow
	sta _dtop
	lda _dtop+1
	adc wlow+1
	sta _dtop+1
	tya
	adc whigh
	tay
	txa
	adc whigh+1
	tax
	tya
	jmp dpush_and_next
}

; : d< rot > if 2drop true else < then ;
+header ~dless, ~dless_n, "D<"
	+forth
	+token rot, twodup, equal
	+qbranch_fwd dless_1
	+token twodrop, uless, exit
dless_1:
	+token greater
	+qbranch_fwd dless_2
	+token twodrop, true, exit
dless_2:
	+token twodrop, false, exit

+header ~dlit, ~dlit_n
	+forth
	+token rat, twopeek, rfrom, twoplus, twoplus, tor, exit


+header ~compdpoke, ~compdpoke_n
	+forth
	+token compile, lit, comma, compile, twopoke, exit


;
; M*/ is an unusual word that uses three-cell numbers. It is possible to build it from the existing words
; To make it more clear, using some internal helpers:
; : t* ( ud,u -- ut) 2>r r@ m* 0 2r> m* d+ ;
; : t/ ( ut,u -- ud) dup >r um/mod r> swap >r um/mod nip r> ;
; : normsign ( d,n -- ud,u,n ) 2dup xor >r abs rot rot dabs rot r> ;
;
+header ~tmult, ~tmult_n
	+forth
	+token twotor, rat, ummult, zero, tworfrom, ummult, dadd, exit

+header ~tdiv, ~tdiv_n
	+forth
	+token dup, tor, ummod, rfrom, swap
	+token tor, ummod, nip, rfrom, exit

+header ~normsign, ~normsign_n
	+forth
	+token twodup, xor, tor, abs
	+token rot, rot, dabs, rot, rfrom, exit

; ==============================================================================
; Optional File-Access word set

; Forth standard makes assumptions about I/O capabilities that are simply not true
; for most 8-bit systems. Implementing as much as possible to get the system going

!if C64 {
!source "fileio_c64.asm"
} else if F256 {
!source "fileio_f256.asm"
}

+header ~ro, ~ro_n, "R/O"
	+code doconst
!if C64 {
	+value ro_v
ro_v:
	+string ",S,R"
} else if F256 {
	+value kernel_args_file_open_READ
} else {
	!error "Not implemented"
}

+header ~openfile, ~openfile_n, "OPEN-FILE"
!if C64 {
	+forth
	+token tor
	+literal of_1
	+token prepfname
;	+token count
;	+literal _fnamebuf
;	+token place
;	+literal _fnamebuf
;	+token plusplace
	+token rfrom, count
	+literal _fnamebuf
	+token plusplace
	+literal _openfiles
	+token peek, freebit
	+token dup
	+qbranch_fwd of_2
	+literal 8
	+token over
	+literal _fnamebuf
	+token count, c64open
	+token c64iostatus, zeroeq
	+qbranch_fwd of_3
	+token dup, dup
	+literal _openfiles
	+token setbit
	+literal _eoffiles
	+token clearbit
	+token zero, exit
of_3:
	+token drop, zero, one
of_2:
	+token exit
of_1:
	+string "O0:"
} else if F256 {
	+code
	+dpop
	sta _scratch
	+dpop
	tay
	+ldax _dtop
	jsr f256open
	bcs +
	sta _dtop
	stz _dtop+1
	lda #0
-:	
	tax
	jmp dpush_and_next
+:
	lda #1
	bra -
} else {
	!error "Not implemented"
}


+header ~closefile, ~closefile_n, "CLOSE-FILE"
!if C64 {
	+forth
	+token dup
	+literal _openfiles
	+token clearbit, c64close, zero, exit
} else if F256 {
	+code
	ldy _dtop
	jsr f256close
	stz _dtop
	jmp next
} else {
	!error "Not implemented"
}


; Cannot be implemented on C64
; In theory, this can be implemented on F256 but I want to keep feature
; parity for now.
+header ~repositionfile, ~repositionfile_n, "REPOSITION-FILE"
	+forth
	+token drop, twodrop, minusone, exit

; Cannot be implemented on C64
+header ~fileposition, ~fileposition_n, "FILE-POSITION"
	+forth
	+token drop, zero, zero, minusone, exit

; A simplistic implementation to test for existence
+header ~filestatus, ~filestatus_n, "FILE-STATUS"
	+forth
	+token ro, openfile
	+qbranch_fwd filestatus_1
	+token true, exit
filestatus_1:
	+token closefile, zero, exit

+header ~readline, ~readline_n, "READ-LINE"
!if C64 {
	+forth
!if FASTLOAD {
	+token one, readgen, exit	; mode 1 = line (native readgen_native)
} else {
	+literal xreadcharchecked
	+token readgen, exit
}
} else if F256 {
;rl_stream = _scratch_1
;rl_limit = _scratch_1+1
	+code
	lda #255
	sta _rscratch
	jmp readfile_common
} else {
	!error "Not implemented"
}


+header ~writefile, ~writefile_n, "WRITE-FILE"
!if C64 {
	+forth
	+token setwrite, type, zero, setwrite, c64iostatus, exit
} else if F256 {
wf_limit = _scratch_1
	+code
	+dpop
	sta _scratch
	+dpop
	cmp #0			; writing 0 bytes is not an error
	bne +
	cpx #0
	beq wf_done
+:
	+stax wf_limit
-:
	ldy #64
	sec
	lda wf_limit
	sbc #64
	sta wf_limit
	bcs +
	dec wf_limit+1
	bpl +
	tya				; adjust the size of the last write
	clc
	adc wf_limit
	tay
	stz wf_limit
	stz wf_limit+1
+:
	+ldax _dtop
	jsr f256write
	bcs wf_error
	clc
	lda _dtop
	adc #64
	sta _dtop
	bcc +
	inc _dtop+1
+:
	lda wf_limit
	bne -
	lda wf_limit+1
	bne -
	
wf_done:
	lda #0
-:
	sta _dtop
	sta _dtop+1
	jmp next

wf_error:
	lda #255
	bne -
} else {
	!error "Not implemented"
}

+header ~writeline, ~writeline_n, "WRITE-LINE"
!if C64 {
	+forth
	+token setwrite, type, cr, zero, setwrite, c64iostatus, exit
} else if F256 {
	+forth
	+token dup, tor, writefile
	+literal lineend
	+token one, rfrom, writefile, or
	+token exit
lineend !byte NEW_LINE
} else {
	!error "Not implemented"
}

+error_message ~includefile_error
+header ~includefile, ~includefile_n, "INCLUDE-FILE"
	+forth
	+literal _ibufcount
	+token cpeek
	+literal 7
	+token greater
	+qbranch_fwd includefile_1
	+branch includefile_error
includefile_1:
	+literal _source
	+token peek
	+token twominus_zero_over_poke	; two more entries to keep fileposition before the last refill
	+token twominus_zero_over_poke
	+token twominus_zero_over_poke
	+token twominus
	+literal _ibuf
	+literal _ibufcount
	+token cpeek
	+literal 100
	+token mult, add, over, poke
	+token twominus_zero_over_poke
	+token twominus, tuck, poke
	+token twominus
	+literal 6
	+token over, poke
	+literal _source
	+token poke
	+literal _ibufcount
	+token dup, cpeek, oneplus, swap, cpoke
	+token state, peek
	+qbranch_fwd includefile_2
	+token interpret
includefile_2:
	+token exit

+header ~included, ~included_n, "INCLUDED"
	+forth
	+token twodup, filestatus, nip
	+qbranch_fwd included_1
!if CART = 0 {
	; missing file: report "<name> ?" (the word-not-found convention)
	; instead of vanishing silently - a typo'd INCLUDE showed nothing at all
	+token twodup, type
	+literal inc_msg_notfound
	+token count, type, cr
}
	+token twodrop, exit
included_1:
!if CART = 0 {
	+literal inc_msg_load			; progress: "Loading <name>, compiling"
	+token count, type			; (every build EXCEPT the 8K C64 cart,
	+token twodup, type			; which is full to the byte - a banner-
	+literal inc_msg_comp			; less file used to load with a blank
	+token count, type			; screen on the non-WIDEDICT builds)
}
!if WIDEDICT {
	; same stale-HERE hazard as CREATE: reveal the dummy via LATEST instead
	+token twodup, xcreate			; create a dummy word with the same name as the included file
	+literal RTS_INSTR
!if WD_FARHDR {
	+token ccomma, compile, exit, latest, context, poke
	+literal _latestbank
	+token cpeek
	+literal _current
	+token cpeek
	+literal _vocsbank
	+token add, cpoke
} else {
	+token ccomma, compile, exit, latest, context, poke
}
} else {
	+token twodup, here, tor, xcreate	; create a dummy word with the same name as the included file
	+literal RTS_INSTR
	+token ccomma, compile, exit, rfrom, context, poke
}
	+token ro, openfile
	+qbranch_fwd included_2
	+token drop, exit
included_2:
	+token includefile
!if CART = 0 {
	+token cr				; the compiling line completes when done
}
	+token exit

!if CART = 0 {
inc_msg_load:
	+string "Loading "
inc_msg_comp:
	+string ", compiling ..."
inc_msg_notfound:
	+string " ?"
}

+header ~required, ~required_n, "REQUIRED"
	+forth
	+token twodup, context, peek, find
	+qbranch_fwd required_1
	+token twodrop, exit
required_1:
	+token drop, included, exit

; Common code for S" and S\"
+header ~getstringbuf, ~getstringbuf_n
	+forth
	+literal _sbuf
	+literal _sflip
	+token cpeek
	+literal 100
	+token mult, add, exit

; ============================================================================
; Here lies an important boundary - all words above it are used in other core
; words, everythign below is unreferenced. The order is important, so smaller
; token values will fit in one byte making core smaller.
; The macro below will enforce references, any reference to words below will
; not compile even if otherwise legal. It will also check that the number of
; words above does not exceed single byte index.
; ============================================================================

; X16 VERA access primitives must sit above the boundary so the higher-level
; X16 words (in x16.asm, below the boundary) can reference them by token.
!if X16 {
!source "x16prims.asm"
}

+check_token_range

+header ~bin, ~bin_n, "BIN"
	+forth
	+token exit		; taking the recommendation and handling all files as binary

+header ~wo, ~wo_n, "W/O"
	+code doconst
!if C64 {
	+value wo_v
wo_v:
	+string ",S,W"
} else if F256 {
	+value kernel_args_file_open_WRITE
} else {
	!error "Not implemented"
}

; This may not be supported on C64, making it identical to W/O
+header ~rw, ~rw_n, "R/W"
	+code doconst
!if C64 {
	+value wo_v
} else if F256 {
	+value kernel_args_file_open_WRITE
} else {
	!error "Not implemented"
}

; For C64 OPEN-FILE and CREATE-FILE are identical
+header ~createfile, ~createfile_n, "CREATE-FILE"
	+forth
	+token openfile, exit

; C64 equivalent: PRINT#15,"S0:Name"
+header ~deletefile, ~deletefile_n, "DELETE-FILE"
!if C64 {
	+forth
	+literal df_1
	+token prepfname
	+literal _fnamebuf
	+token count
	+literal 15
	+token writeline, exit
df_1:
	+string "S0:"
} else if F256 {
	+code
	lda _drive
	sta kernel_args_file_delete_drive
	+dpop
	sta kernel_args_file_delete_fname_len
	+ldax _dtop
	+stax kernel_args_file_delete_fname
	jsr kernel_File_Delete
	lda #kernel_event_file_DELETED
df_continue:	; common code for DELETE-FILE and RENAME-FILE
	sta completion
	jsr waitforcompletion
	bcs df_error

	lda #0
-:
	sta _dtop
	sta _dtop+1
	jmp next

df_error:
	lda #255
	bra -
} else {
	!error "Not implemented"
}

; C64 equivalent: PRINT#15,"R0:NewName=OldName"
; Note that this is the only word that uses PAD
+header ~renamefile, ~renamefile_n, "RENAME-FILE"
!if C64 {
	+forth
	+literal rf_1
	+token prepfname
	+literal rf_2
	+token count
	+literal _fnamebuf
	+token plusplace
	+literal _fnamebuf
	+token plusplace
	+literal _fnamebuf
	+token count
	+literal 15
	+token writefile, exit
rf_1:
	+string "R0:"
rf_2:
	+string "="
} else if F256 {
	+code
	lda _drive
	sta kernel_args_file_rename_drive
	+dpop
	sta kernel_args_file_rename_new_len
	+dpop
	+stax kernel_args_file_rename_new
	+dpop
	sta kernel_args_file_rename_old_len
	+ldax _dtop
	+stax kernel_args_file_rename_old
	jsr kernel_File_Rename
	lda #kernel_event_file_RENAMED
	bra df_continue						; note jump to a different word (common fragment)
} else {
	!error "Not implemented"
}

; Cannot be implemented on C64
+header ~resizefile, ~resizefile_n, "RESIZE-FILE"
	+forth
	+token drop, twodrop, minusone, exit

; Cannot be implemented on C64
+header ~filesize, ~filesize_n, "FILE-SIZE"
	+forth
	+token drop, zero, zero, minusone, exit

+header ~readfile, ~readfile_n, "READ-FILE"
!if C64 {
	+forth
!if FASTLOAD {
	+token zero, readgen, nip, exit	; mode 0 = raw bytes (native readgen_native)
} else {
	+literal xreadbyte
	+token readgen, nip, exit
}
} else if F256 {
rf_stream = _scratch_1
rf_limit = _scratch_2
	+code
	stz _rscratch
readfile_common:
	+dpop
	sta rf_stream
	+dpop
	sta rf_limit

	ldy #0
	ldx #0
-:
	cpy rf_limit
	bne +
	cpx rf_limit+1
	beq rf_done
+:	
	phy
	phx
	ldy rf_stream
	jsr f256readchar
	plx
	ply
	bcs	rf_eos
	bit _rscratch	; of all things this opcode does we only care about it moving bit 7 to N
	bpl +			; if N is not set, it's READ-FILE, otherwise must be READ-LINE
	cmp #10
	beq rf_done
	cmp #13
	beq rf_done
+:	
	sta (_dtop),y
	iny
	bne -
	inc _dtop+1
	inx
	bra -

rf_eos:
	beq rf_fail		; some chars collected before eos - success
	
rf_done:
	stx _dtop+1
	sty _dtop
	lda #255	; success line returns count, true, 0
-:
	tax
	+dpush
	
	lda #0
	tax
	jmp dpush_and_next
rf_fail:
	lda #0		; failed line return 0, false, 0
	bra -
} else {
	!error "Not implemented"
}

; Not needed on C64
+header ~flushfile, ~flushfile_n, "FLUSH-FILE"
	+forth
	+token zero, exit

+header ~include, ~include_n, "INCLUDE"
	+forth
	+token parsename, included, exit

+header ~require, ~require_n, "REQUIRE"
	+forth
	+token parsename, required, exit


; ==============================================================================
; Some less commonly used (not used in core) math words
+header ~div, ~div_n, "/"
	+forth
	+token divmod, nip, exit

+header ~mod, ~mod_n, "MOD"
	+forth
	+token divmod, drop, exit

+header ~multdiv, ~multdiv_n, "*/"
	+forth
	+token multdivmod, nip, exit

;
; : fm/mod dup >r sm/rem
;          over dup 0<> swap 0< r@ 0< xor and
;          if 1- swap r> + swap else rdrop then ;
;

+header ~fmmod, ~fmmod_n, "FM/MOD"
	+forth
	+token dup, tor, smrem, over, dup, zerone
	+token swap, zerolt, rat, zerolt, xor, and_op
	+qbranch_fwd fmmod_1
	+token oneminus, swap, rfrom, add, swap
	+branch_fwd fmmod_2
fmmod_1:
	+token rdrop
fmmod_2:
	+token exit

+header ~max, ~max_n, "MAX"
	+forth
	+token twodup, less
	+qbranch_fwd max_1
	+token swap
max_1:
	+token drop, exit

+header ~min, ~min_n, "MIN"
	+forth
	+token twodup, greater
	+qbranch_fwd min_1
	+token swap
min_1:
	+token drop, exit

;
;	: within over - >r - r> u< ;
;
+header ~within, ~within_n, "WITHIN"
	+forth
	+token over, sub, tor, sub, rfrom, uless, exit

; ==============================================================================
; More words from the optional Double-Number word set

;
; : d= rot = >r = r> and ;
;
+header ~dequal, ~dequal_n, "D="
	+forth
	+token rot, equal, tor, equal, rfrom, and_op, exit

;
; : dmax 2over 2over d< if 2swap then 2drop ;
; : dmin 2over 2over d< invert if 2swap then 2drop ;
;

+header ~dmax, ~dmax_n, "DMAX"
	+forth
	+token twoover, twoover, dless
	+qbranch_fwd dmax_1
	+token twoswap
dmax_1:
	+token twodrop, exit

+header ~dmin, ~dmin_n, "DMIN"
	+forth
	+token twoover, twoover, dless, invert
	+qbranch_fwd dmin_1
	+token twoswap
dmin_1:
	+token twodrop, exit

;
; : d- dnegate d+ ;
; code d+
;
+header ~dsub, ~dsub_n, "D-"
	+forth
	+token dnegate, dadd, exit

+header ~dtwodiv, ~dtwodiv_n, "D2/"
	+forth
	+token dup, one, and_op
	+literal 15
	+token lshift, swap, twodiv, swap
	+token rot, twodiv, or, swap, exit

;
; : d2* 2dup d+ ;
;

+header ~dtwomul, ~dtwomul_n, "D2*"
	+forth
	+token twodup, dadd, exit

+header ~duless, ~duless_n, "DU<"
	+forth
	+token rot, twodup, equal
	+qbranch_fwd duless_1
	+token twodrop, uless, exit
duless_1:
	+token ugreater
	+qbranch_fwd duless_2
	+token twodrop, true, exit
duless_2:
	+token twodrop, false, exit

;
; : d0= or 0= ;
; : d0< nip 0< ;
;
+header ~dzeroeq, ~dzeroeq_n, "D0="
	+forth
	+token or, zeroeq, exit

+header ~dzeroless, ~dzeroless_n, "D0<"
	+forth
	+token nip, zerolt, exit

;
; : d>s drop ;
;
+header ~dtos, ~dtos_n, "D>S"
	+forth
	+token drop, exit

;
; : 2constant create , , does> 2@ ;
;

+header ~dconstant, ~dconstant_n, "2CONSTANT"
	+forth
	+token create, comma, comma, xcode
	!byte JSR_INSTR
	+address does
	+token twopeek, exit

;
; : 2lit r@ 2@ r> 2+ 2+ >r ; nonstandard
; : 2literal ?comp state @ if compile 2lit , , then ; immediate
;

+header ~dliteral, ~dliteral_n, "2LITERAL", IMM_FLAG
	+forth
	+token qcomp, state, peek
	+qbranch_fwd dliteral_1
	+token compile, dlit
	+token comma, comma
dliteral_1:
	+token exit

;
; : 2rot 5 roll 5 roll ;
;
+header ~drot, ~drot_n, "2ROT"
	+forth
	+literal 5
	+token roll
	+literal 5
	+token roll, exit

+header ~dvalue, ~dvalue_n, "2VALUE"
	+forth
	+token create
	+literal dovalue
	+token here, twominus, poke
	+literal dvalue_sem
	+token comma, comma, comma, exit
dvalue_sem:
	+value twopeek
	+value twopoke
	+value compdpoke

;
; : m*/ >r normsign r> swap >r >r t* r> t/ r> 0< if dnegate then ;
;

+header ~mmuldiv, ~mmuldiv_n, "M*/"
	+forth
	+token tor, normsign, rfrom, swap, tor, tor
	+token tmult, rfrom, tdiv, rfrom, zerolt
	+qbranch_fwd mmuldiv_1
	+token dnegate
mmuldiv_1:
	+token exit


; ==============================================================================
; Reset return stack, dispose of sources, close all open files, and reenter the system.
+header ~quit, ~quit_n, "QUIT"
	+forth
	+token xsst
	+token xquit ; this is an equivalent to ;CODE
	
; ==============================================================================
+header ~immediate, ~immediate_n, "IMMEDIATE"
	+forth
!if WD_FARHDR {
	; LATEST's header sits in a code bank (not necessarily _codebank after
	; FORGET/LOAD-IMAGE): read via _scanbank, and swing _codebank so the
	; windowed C! pins the right bank for the flag write
	+literal _latestbank
	+token cpeek
	+literal _scanbank
	+token cpoke
	+literal _codebank
	+token cpeek		; ( oldbank )
	+literal _latestbank
	+token cpeek
	+literal _codebank
	+token cpoke
	+token latest, dup, wdhcpeek
	+literal IMM_FLAG
	+token or, swap, cpoke	; far C! pins _codebank = the header's bank
	+literal _codebank
	+token cpoke, exit
} else {
	+token latest, dup, cpeek
	+literal IMM_FLAG
	+token or, swap, cpoke, exit
}

; Note that while DOES> looks like high-level word its implementation is depended on the opcode for native CALL/JSR
+header ~doesx, ~doesx_n, "DOES>", IMM_FLAG
	+forth
!if WIDEDICT {
	+token qcomp, compile, xcode
	+literal _incode		; ONLY when compiling far (a first DOES> in a
	+token cpeek			; far word) do the visible-move; a nested/2nd
	+qbranch_fwd doesx_novis	; DOES> is already in visible space (classic)
	+literal _dhere			; operand into the (far) defining body =
	+token peek, comma		; the visible address the DOES-code lands at
	+token here			; (child JMP <visible does-code> works from
	+literal _chere			; any bank - data rule); far body ends here
	+token poke
	+literal _dhere
	+token peek
	+literal _here
	+token poke
	+literal _dmemtop
	+token peek
	+literal _memtop
	+token poke
	+token zero
	+literal _incode
	+token cpoke
	+token zero
	+literal CBANKREG
	+token cpoke			; unpin: the DOES-code compiles near
doesx_novis:
	+literal JSR_INSTR
	+token ccomma
	+literal does
	+token comma, exit
} else {
	+token qcomp, compile, xcode
	+literal JSR_INSTR
	+token ccomma
	+literal does
	+token comma, exit	; compile (;CODE) followed by "call does_c"
}

; Note that colon will remove the word from the search order (to be restored by semicolon)
+header ~colon, ~colon_n, ":"
	+forth
	+token bl, word, count
	+token xcreate
!if WIDEDICT {
	+token wdcolon
} else {
	+literal RTS_INSTR
	+token ccomma
}
	+token bracketx, exit

; Words defined with :NONAME technically don't need to be linked in the vocabulary but if it is done that way RECURSE becomes harder
; to implement. It is easier just to link the word with emtpy name. In this implementation it has an unusual side effect that FIND
; will actually find the last :NONAME if searched for empty string and the test suite actually traps that (not an error though). But -
; standard does not specify it either way; and this is potentially useful.

;
; : :noname here 0 , latest , _latest ! here ' call , ] ;
;
 
+header ~colonnoname, ~colonnoname_n, ":NONAME"
	+forth
	+token zero, dup
	+token xcreate
!if WIDEDICT {
	+token wdcolon
} else {
	+literal RTS_INSTR
	+token ccomma
}
	+token bracketx
	+literal _hightoken
	+token peek, exit

+header ~bufferc, ~bufferc_n, "BUFFER:"
	+forth
	+token create, allot, exit

+header ~semicolon, ~semicolon_n, ";", IMM_FLAG
	+forth
!if WIDEDICT {
	+token qcomp, compile, exit
	+literal _incode
	+token cpeek
	+qbranch_fwd wds_noswap
	+token here			; _chere := HERE (end of the body)
	+literal _chere
	+token poke
	+literal _dhere			; restore the data-space pointers
	+token peek
	+literal _here
	+token poke
	+literal _dmemtop
	+token peek
	+literal _memtop
	+token poke
	+token zero
	+literal _incode
	+token cpoke
	+token zero			; unpin the code-bank register
	+literal CBANKREG
	+token cpoke
wds_noswap:
!if WD_FARHDR {
	+token bracket, latest, context, poke
	+literal _latestbank
	+token cpeek
	+literal _current
	+token cpeek
	+literal _vocsbank
	+token add, cpoke, exit
} else {
	+token bracket, latest, context, poke, exit
}
} else {
	+token qcomp, compile, exit, bracket, latest, context, poke, exit
}

+header ~variable, ~variable_n, "VARIABLE"
	+forth
	+token create, zero, comma, exit

+header ~twovariable, ~twovariable_n, "2VARIABLE"
	+forth
	+token create, zero, dup, comma, comma, exit

+header ~constant, ~constant_n, "CONSTANT"
	+forth
	+token create, comma, xcode
	!byte JSR_INSTR
	+address does
	+token peek, exit

+header ~defer, ~defer_n, "DEFER"
	+forth
	+token create
	+literal dodefer
	+token here, twominus, poke		; note that we cannot use "compile exit" here as that will reserve only one byte,
	+literal exit					; and some tokens may need two
	+token comma, exit

+header ~actionof, ~actionof_n, "ACTION-OF", IMM_FLAG
	+forth
	+token state, peek
	+qbranch_fwd actionof_1
	+token btick, compile, deferpeek, exit
actionof_1:
	+token tick, deferpeek, exit

+header ~is, ~is_n, "IS", IMM_FLAG
	+forth
	+token state, peek
	+qbranch_fwd is_1
	+token btick, compile, deferpoke, exit
is_1:
	+token tick, deferpoke, exit

; "value" has a special structure: three tokens for read semantics,
; write semantics, and compile semantics, followed by the value itself

+header ~value, ~value_n, "VALUE"
	+forth
	+token create
	+literal dovalue
	+token here, twominus, poke
	+literal value_sem
	+token comma, comma, exit
value_sem:
	; Note that the parameter block uses "value" instead of "token" - this is
	; intentional as the size of token is not known
	+value peek
	+value poke
	+value comppoke

+error_message ~to_error
+header ~to, ~to_n, "TO", IMM_FLAG
	+forth
	+token bl, word, find
	+qbranch to_error
	+token tobody, dup, twominus, peek
	+literal dovalue
	+token equal
	+qbranch to_error
	+token dup, twoplus, swap, peek, state, peek
	+qbranch_fwd to_1
	+token twoplus
to_1:
	+token twoplus, peek, execute, exit

+header ~squote, ~squote_n, "S\"", IMM_FLAG
	+forth
	+token state, peek
	+qbranch_fwd squote_1
	+token cquote, compile, count, exit
squote_1:
	+literal '"'
	+token parse
	+token getstringbuf
;	+literal _sbuf
;	+literal _sflip
;	+token cpeek
;	+literal 100
;	+token mult, add
	+token swap, twotor, tworat, cmove
	+token tworfrom
	+literal _sflip
	+token dup, cpeek, one, xor, swap, cpoke, exit 

+header ~ssquote, ~ssquote_n, "S\\\"", IMM_FLAG
	+forth
	+token tib, ptrin, peek, add
	+token getstringbuf
;	+literal _sbuf
;	+literal _sflip
;	+token cpeek
;	+literal 100
;	+token mult, add
	+token numtib, peek
	+token ptrin, peek, sub, over, tor
	+token smove, swap, ptrin, incpoke
	+token rfrom, swap
	+literal _sflip
	+token dup, cpeek, one, xor, swap, cpoke
	+token state, peek
	+qbranch_fwd ssquote_1
!if WIDEDICT {
	; ( ca u ) = the escape-translated string in SBUF (visible). Store it
	; permanently in VISIBLE data space so the returned pointer is readable
	; by the caller, then compile LIT <vaddr> COUNT (as cquote does).
	+literal _dhere
	+token peek				; ( ca u dst )
	+token dup, tor				; R: dst
	+token twodup, cpoke			; store length byte
	+token charplus, swap			; ( ca dst+1 u )
	+token dup, tor				; R: dst u
	+token cmove
	+token rfrom
	+token rat, add, charplus		; new _dhere = dst + u + 1
	+literal _dhere
	+token poke
	+token rfrom				; ( vaddr )
	+token compile, lit, comma
	+token compile, count
} else {
	+token compile, branch, fmark
	+token here, two, pick, dup, ccomma, allot, swap, fresolve
	+token compile, lit, dup
	+token comma, compile, count, oneplus, swap, cmove 
}
ssquote_1:
	+token exit

+header ~dotquote, ~dotquote_n, ".\"", IMM_FLAG
	+forth
	+token qcomp, cquote, compile, count, compile, type, exit

+header ~char, ~char_n, "CHAR"
	+forth
	+token bl, word, charplus, cpeek, exit

+header ~bcharb, ~bcharb_n, "[CHAR]", IMM_FLAG
	+forth
	+token compile, blit, bl
	+token word, charplus, cpeek, ccomma, exit

+header ~abortq, ~abortq_n, "ABORT\"", IMM_FLAG
	+forth
	+token qcomp, compile, qbranch, fmark
	+token compile, xabortq, commaquote, fresolve, exit

; In optional Programming-Tools word set
+error_message ~forget_error:
+header ~forget, ~forget_n, "FORGET"
	+forth
	+token bl, word, find
	+qbranch forget_error
	+token xforget
	+token exit

+header ~marker, ~marker_n, "MARKER"
	+forth
	+token create
	+literal _hightoken
	+token peek, comma, xcode
	!byte JSR_INSTR
	+address does
	+token peek, xforget, exit

+header ~recurse, ~recurse_n, "RECURSE", IMM_FLAG
	+forth
	+token qcomp
	+literal _hightoken
	+token peek, compilecomma, exit

+header ~bcompile, ~bcompile_n, "[COMPILE]", IMM_FLAG
	+forth
	+token qcomp, tick, compilecomma, exit

; Somehow I've managed to get this to pass the tests but I still don't completely understand what
; it is supposed to do
+error_message ~postpone_error:
+header ~postpone, ~postpone_n, "POSTPONE", IMM_FLAG
	+forth
	+token qcomp, bl, word, find, qdup
	+qbranch postpone_error
	+token one, equal
	+qbranch_fwd postpone_1
	+token compilecomma, exit
postpone_1:
	+token compile, compile, compilecomma, exit

; This word behaves differently depending on compilation state - in compilation it
; will emit LIT followed by the value from the stack
+header ~literal, ~literal_n, "LITERAL", IMM_FLAG
	+forth
	+token qcomp, state, peek
	+qbranch_fwd literal_1
	+token compile, lit, comma
literal_1:
	+token exit

+header ~holds, ~holds_n, "HOLDS"
	+forth
holds_1:
	+token qdup
	+qbranch_fwd holds_2
	+token oneminus, twodup, add, cpeek, hold
	+branch holds_1
holds_2:
	+token drop, exit

+header ~dotr, ~dotr_n, ".R"
	+forth
	+token swap, stod, rot, ddotr, exit

+header ~udot, ~udot_n, "U."
	+forth
	+token zero, ddot, exit

+header ~udotr, ~udotr_n, "U.R"
	+forth
	+token zero, swap, ddotr, exit

+header ~pad, ~pad_n, "PAD"
	+code doconst
	+value _pad

+header ~erase, ~erase_n, "ERASE"
	+forth
	+token zero, fill, exit

+header ~sstring, ~sstring_n, "/STRING"
	+forth
	+token rot, over, add, rot, rot, sub, exit

+header ~blank, ~blank_n, "BLANK"
	+forth
	+token bl, fill, exit

+header ~sliteral, ~sliteral_n, "SLITERAL", IMM_FLAG
	+forth
	+token state, peek
	+qbranch_fwd sliteral_1
	+token compile, branch, fmark
	+token rot, rot
	+token dup, tor, here, dup, tor
	+token swap, dup, allot, cmove, fresolve
	+token compile, lit, rfrom
	+token comma, compile, lit, rfrom
	+token comma
sliteral_1:
	+token exit

+header ~qmark, ~qmark_n, "?"
	+forth
	+token peek, dot, exit

+header ~dots, ~dots_n, ".S"
	+forth
	+token depth
dots_1:
	+token qdup
	+qbranch_fwd dots_2
	+token dup, pick, dot, oneminus
	+branch dots_1
dots_2:
	+token exit

+header ~ahead, ~ahead_n, "AHEAD"
	+forth
	+token fmark, exit

; See the note before "D+"
cstr1 = _dtop
clen1 = _rscratch
cstr2 = _wscratch
clen2 = _scratch

; COMPARE became standard in the later versions of the language.
; In optional String word set
; This one still can be optimized further
; (caddr1, u1, caddr2, u2 -> n)
+header ~compare, ~compare_n, "COMPARE"
	+code
	jsr dpop_scratch_wscratch_rscratch
;	+dpop
;	+stax clen2
;	+dpop
;	+stax cstr2
;	+dpop
;	+stax clen1
	; and cstr1 is already where it should be. No need to pop as the result will be written there

	ldy #0
	
compare_loop:
	lda clen1
	ora clen1+1
	bne compare_check2
	ora clen2
	ora clen2+1
	bne compare_gt	; clen1 < clen2
;	lda #$0
	sta _dtop
	beq compare_res	; reached the end of both strings and all characters match
compare_check2:
	lda clen2
	ora clen2+1
	beq compare_lt	; clen1 > clen2

	lda (cstr1),y
	cmp (cstr2),y
	bcc compare_gt
	beq compare_next
compare_lt:
	lda #$FF
	sta _dtop
compare_res:
	sta _dtop+1
	jmp next
compare_gt:
	lda #1
	sta _dtop
	lda #0
	beq compare_res
	
compare_next:
	iny
	bne compare_next1:
	inc cstr1+1
	inc cstr2+1

compare_next1:
	lda clen1
	bne compare_next2
	dec clen1+1
compare_next2:
	dec clen1
	
	lda clen2
	bne compare_next3
	dec clen2+1
compare_next3:
	dec clen2
	+bra compare_loop

; ==============================================================================
;
; : save-input _source @ dup >r @ begin dup while dup 2* r@ + @ swap 1- again drop r> @ ;
;
; : restore-input over source-id = if
;                 source-id 0> if 6 pick 6 pick source-id reposition-file refill 2drop then
;                 begin dup while dup roll over 2* _source @ + ! 1- again drop false
;                 else true then ;
;

+header ~saveinput, ~saveinput_n, "SAVE-INPUT"
	+forth
	+literal _source
	+token peek, dup, tor, peek
saveinput_1:
	+token qdup
	+qbranch_fwd saveinput_2
	+token dup, twomult, rat, add, peek, swap, oneminus
	+branch saveinput_1
saveinput_2:
	+token rfrom, peek, exit

+header ~restoreinput, ~restoreinput_n, "RESTORE-INPUT"
	+forth
	+token over, sourceid, equal
	+qbranch_fwd restoreinput_3
	+token sourceid, zerogt
	+qbranch_fwd restoreinput_1
	+literal 6
	+token pick
	+literal 6
	+token pick, sourceid, repositionfile, refill, twodrop
restoreinput_1:
	+token qdup
	+qbranch_fwd restoreinput_2
	+token dup, roll, over, twomult
	+literal _source
	+token peek, add, poke, oneminus
	+branch restoreinput_1
restoreinput_2:
	+token false, exit
restoreinput_3:
	+token true, exit

+header ~evaluate, ~evaluate_n, "EVALUATE"
	+forth
	+literal _source
	+token peek
	+token twominus, tuck, poke
	+token twominus, tuck, poke
	+token twominus_zero_over_poke
	+token twominus, minusone, over, poke
	+token twominus
	+literal 4
	+token over, poke
	+literal _source
	+token poke
	+token interpret
	+token exit



; ==============================================================================

+header ~align, ~align_n, "ALIGN"
	+forth
	+token exit

+header ~aligned, ~aligned_n, "ALIGNED"
	+forth
	+token exit


; ==============================================================================
; Control words. All of these are immediate and don't do anything useful
; in interpreter mode. There should be no code calling to CFA of these words.
; To understand the concept behind these words look at the BEGIN/AGAIN pair -
; BEGIN ends up just putting RI on the stack and AGAIN compiles BRANCH to that RI.
; Forward references are a bit trickier but follow the same pattern.

+header ~begin, ~begin_n, "BEGIN", IMM_FLAG
	+forth
	+token qcomp, rmark, exit

+header ~until, ~until_n, "UNTIL", IMM_FLAG
	+forth
	+token qcomp, compile, qbranch, rresolve
	+token exit

+header ~again, ~again_n, "AGAIN", IMM_FLAG
	+forth
	+token qcomp, compile, branch, rresolve
	+token exit

+header ~if, ~if_n, "IF", IMM_FLAG
	+forth
	+token qcomp, compile, qbranch, fmark
	+token exit

+header ~then, ~then_n, "THEN", IMM_FLAG
	+forth
	+token qcomp, fresolve, exit

+header ~else, ~else_n, "ELSE", IMM_FLAG
	+forth
	+token qcomp, compile, branch, fmark
	+token swap, fresolve, exit

+header ~while, ~while_n, "WHILE", IMM_FLAG
	+forth
	+token qcomp, compile, qbranch, fmark
	+token swap, exit

+header ~repeat, ~repeat_n, "REPEAT", IMM_FLAG
	+forth
	+token qcomp, compile, branch, rresolve
	+token fresolve, exit

+header ~do, ~do_n, "DO", IMM_FLAG
	+forth
	+token qcomp, compile, xdo, fmark, rmark, exit

+header ~qdo, ~qdo_n, "?DO", IMM_FLAG
	+forth
	+token qcomp, compile, xqdo, fmark, rmark, exit

+header ~loop, ~loop_n, "LOOP", IMM_FLAG
	+forth
	+token qcomp, compile, xloop, rresolve, fresolve, exit

+header ~ploop, ~ploop_n, "+LOOP", IMM_FLAG
	+forth
	+token qcomp, compile, xploop, rresolve, fresolve, exit

+header ~unloop, ~unloop_n, "UNLOOP"
	+forth
	+token rfrom, rdrop, rdrop, rdrop, tor, exit

+header ~case, ~case_n, "CASE", IMM_FLAG
	+forth
	+token qcomp, depth, rfrom, swap, tor, tor, exit

+header ~of, ~of_n, "OF", IMM_FLAG
	+forth
	+token qcomp, compile, over, compile, equal, compile, qbranch
	+token fmark, compile, drop, exit

+header ~endof, ~endof_n, "ENDOF", IMM_FLAG
	+forth
	+token qcomp, compile, branch, fmark
	+token swap, fresolve, exit

+header ~endcase, ~endcase_n, "ENDCASE", IMM_FLAG
	+forth
	+token qcomp, compile, drop, depth
	+token rfrom, rfrom, swap, tor, sub
endcase_1:
	+token qdup
	+qbranch_fwd endcase_2
	+token oneminus, swap, fresolve
	+branch endcase_1
endcase_2:
	+token exit

;
; : ( source-id 0< if
;     begin ')' parse 2drop >in @ #tib @ = tib #tib @ + 1- c@ ')' = and
;     while refill invert if exit then again
;     else ')' parse 2drop then ; immediate
;

+header ~brace, ~brace_n, "(", IMM_FLAG
	+forth
	+token sourceid, zerogt
	+qbranch_fwd brace_2
brace_1:
	+literal ')'
	+token parse, twodrop, ptrin, peek, numtib, peek, equal
	+token tib, numtib, peek, add, oneminus, cpeek
	+literal ')'
	+token notequal, and_op
	+qbranch_fwd brace_3
	+token refill, invert
	+qbranch brace_1
	+token exit
brace_2:
	+literal ')'
	+token parse, twodrop
brace_3:
	+token exit

+header ~backslash, ~backslash_n, "\\", IMM_FLAG
	+forth
	+token zero, parse, twodrop, exit

+header ~dotbrace, ~dotbrace_n, ".(", IMM_FLAG
	+forth
	+literal ')'
	+token parse, type, exit


; ==============================================================================
; Small subset from the optional Facility word set

+header ~beginstructure, ~beginstructure_n, "BEGIN-STRUCTURE"
	+forth
	+token create, here, zero, zero, comma, xcode
	!byte JSR_INSTR
	+address does
	+token peek, exit

+header ~endstructure, ~endstructure_n, "END-STRUCTURE"
	+forth
	+token swap, poke, exit
				
+header ~field, ~field_n, "FIELD:"
	+forth
	+token two, addfield, exit

+header ~cfield, ~cfield_n, "CFIELD:"
	+forth
	+token one, addfield, exit

; ==============================================================================
; Per discussion on forth-standard.org, it appears that this word does not
; have to provide any additional information. Given the overall bad specs and
; high memory use for little purpose, shortwiring it
+header ~environmentq, ~environmentq_n, "ENVIRONMENT?"
	+code doconst
	+value VAL_FALSE

; In optional Programming-Tools word set
!if WIDEDICT != 0 and WD_ROMBANKS = 0 {
; FREE ( -- )  report the two free pools: near (headers/stubs/data) and the
; far code-body space across the RAM banks (as a double, it can exceed 64K).
; Placed after +check_token_range so it takes a long token, not a short one.
; RAM-mode only (top-down banks); ROM-mode free math would differ.
+header ~free, ~free_n, "FREE"
	+forth
	+literal free_msg_near
	+token count, type
	+token unused, dot			; near is always < 32K, plain . is fine
	+literal free_msg_code
	+token count, type
	+literal _codebank
	+token cpeek, dup
	+qbranch_fwd free_none
	+literal CBANK_FLOOR
	+token sub
	+literal PER_BANK
	+token ummult
	+literal CWIN_TOP
	+literal _chere
	+token peek, sub, zero, dadd
	+branch_fwd free_show
free_none:
	+token drop
	+literal _codetop
	+token cpeek
	+literal CBANK_FLOOR
	+token sub, oneplus
	+literal PER_BANK
	+token ummult
free_show:
	+token ddot
	+literal free_msg_bytes
	+token count, type, cr, exit
free_msg_near:
	+string "near "
free_msg_code:
	+string "bytes  code "
free_msg_bytes:
	+string "bytes"
} else {
; FREE ( -- )  print the free low-RAM dictionary space. On builds without the
; RAM-bank far dictionary this is the single free pool (the UNUSED value).
+header ~free, ~free_n, "FREE"
	+forth
	+token unused, dot
	+literal free_msg_free
	+token count, type, cr, exit
free_msg_free:
	+string "bytes free"
}

+header ~words, ~words_n, "WORDS"
	+forth
!if WD_FARHDR {
	; header names live in the code banks: seed _scanbank per wordlist and
	; read length/characters through it (near/core headers read the same way)
	+token get_order, zero, tuck, xqdo
	+address words_done
words_looporder:
	+token swap, dup
	+literal _vocsbank
	+token add, cpeek
	+literal _scanbank
	+token cpoke
	+token cells
	+literal _vocs
	+token add, peek
words_loop:
	+token qdup
	+qbranch_fwd words_next
	+token dup, wdhcpeek
	+literal NAMEMASK
	+token and_op, qdup
	+qbranch_fwd words_continue	; nameless (:NONAME): just follow the link
	+token over, oneplus, swap	; ( cnt nfa a=nfa+1 len )
	+token zero, xqdo
	+address words_pdone
words_ploop:
	+token dup, i, add, wdhcpeek, emit, xloop
	+address words_ploop
words_pdone:
	+token drop, space, swap, oneplus, swap
words_continue:
	+token nextword
	+branch words_loop
words_next:
	+token xloop
	+address words_looporder
words_done:
	+token cr, dot
	+literal words_n
	+token count, type, exit
} else {
	+token get_order, zero, tuck, xqdo
	+address words_done
words_looporder:
	+token swap, cells
	+literal _vocs
	+token add, peek
words_loop:
	+token qdup
	+qbranch_fwd words_next
	+token dup, count
	+literal NAMEMASK
	+token and_op, qdup
	+qbranch_fwd words_noname
	+token type, space, swap, oneplus, swap
	+branch_fwd words_continue
words_noname:
	+token drop
words_continue:
	+token nextword
	+branch words_loop
words_next:
	+token xloop
	+address words_looporder
words_done:
	+token cr, dot
	+literal words_n
	+token count, type, exit
}

+header ~key, ~key_n, "KEY"
	+code
!if C64 {
	jsr GETIN
} else if F256 {
	jsr getch
} else {
	!error "Not implemented"
}
	ldx #0
	jmp dpush_and_next

; ==============================================================================
; This word became standard in ANS Forth, part of optional Programming-Tools word set. Quit the interpreter.
; code bye
+header ~bye, ~bye_n, "BYE"
	+code
!if C64 {
	!if CART or X16ROM {
	; Just reset the state in cartridge / ROM mode
		jmp coldstart
	} else {
	; This works fine on Commander X16 as Forth is only using the user area of the zero page. Unfortunately,
	; there is no such area on C64 - TODO here
		pla
		pla
		rts
	}
} else if F256 {
	jmp start_of_image
} else {
	!error "Not implemented"
}

; Search-Order words
;

; : also get-order over swap 1+ set-order ;

+header ~also, ~also_n, "ALSO"
	+forth
	+token get_order, over, swap, oneplus, set_order, exit


+header ~definitions, ~definitions_n, "DEFINITIONS"
	+code
	lda _context
	sta _current
	jmp next

+header ~get_current, ~get_current_n, "GET-CURRENT"
	+forth
	+literal _current
	+token cpeek, exit

; : only -1 set-order ;

+header ~only, ~only_n, "ONLY"
	+forth
	+token minusone, set_order, exit

+header ~order, ~order_n, "ORDER"
	+forth
	+token get_order, zero, xqdo
	+address order_done
order_loop:
	+token dup, cells
	+literal _vocsref
	+token add, peek, count
	+literal NAMEMASK
	+token and_op, type
	+literal '*'
	+token emit
	+token dot, xloop
	+address order_loop
order_done:
	+token exit

; : previous get-order nip 1- set-order ;

+header ~previous, ~previous_n, "PREVIOUS"
	+forth
	+token get_order, nip, oneminus, set_order, exit

+header ~set_current, ~set_current_n, "SET-CURRENT"
	+forth
	+literal _current
	+token cpoke, exit

+header ~wordlist, ~wordlist_n, "WORDLIST"
	+forth
!if WD_FARHDR {
	; the pre-xcreate HERE is not the nameless word's NFA anymore (the
	; header went far) - reveal via LATEST + its bank, like CREATE
	+token here, zero, dup, xwordlist
	+token latest, context, poke
	+literal _latestbank
	+token cpeek
	+literal _current
	+token cpeek
	+literal _vocsbank
	+token add, cpoke
	+token nip, exit
} else {
	+token here, zero, dup, xwordlist, swap, context, poke, exit
}

+header ~forth, ~forth_n, "FORTH"
	+forth
	+token get_order, nip, zero		; FORTH-WORDLIST wid is 0
	+token swap, set_order, exit

+header ~forth_wordlist, ~forth_wordlist_n, "FORTH-WORDLIST"
	+code doconst
	+value 0

+header ~ver, ~ver_n, "VER"
	+code doconst
	+value VERSION_HIGH_INT<<8 | VERSION_LOW_INT
	; System configuration parameters for assembler module,
	; to be accessed by ( ' VER >body 2+ 2xN + @ )
	+value _ri
	+value next
	+value pop_dstack
	+value push_dstack
	
!if X16 {
+header ~c64, ~c64_n, "X16"
	+forth
	+token exit
} else if C64 {
+header ~c64, ~c64_n, "C64"
	+forth
	+token exit
} else if F256 {
+header ~c64, ~c64_n, "F256"
	+forth
	+token exit
} else {
	!error "Not implemented"
}
	
; ==============================================================================
; Commander X16 hardware words - VERA video, sprites, audio, binary LOAD/SAVE.
; These are only present in the X16 target and mirror the X16 BASIC commands.
!if X16 {
!source "x16.asm"
}

; ==============================================================================
; The main system loop. This has to be the last word in the core

; Allow the next word to be referenced. It's not very likely that anybody will
; call it by mistake anyway.
+ignore_token_range

+header ~forth_system, ~forth_system_n
	+forth
forth_system_c:
; Switch the console to ISO mode ($0F) at cold start so ForthX16 is always in a
; consistent PC-style ASCII charset (true upper+lower case, real backslash; no
; PETSCII case inversion). Word lookup masks case, so any case is accepted.
!if X16 {
	+literal 15
	+token emit
}
	+literal banner_text
	+token count, type, cr
	+token decimal, false, state, poke, xsst
; BASIC-style free-memory report at boot ("NNNNN BYTES FREE"). UNUSED = MEMTOP -
; HERE; at cold start the dictionary is empty so this is the full free space.
	+token unused, dot
	+literal bytesfree_text
	+token count, type, cr
; Register the root Forth dictionary
; One wid with the value 0; one voc with head pointing at the NFA of the last word
; Current is also at 0
	+token one, dup
	+literal _numorder
	+token cpoke
	+literal _numvocs
	+token cpoke

	+token zero, dup
	+literal _context
	+token cpoke
	+literal _current
	+token cpoke

	+literal forth_system_n
	+literal _vocs
	+token poke
	+literal forth_wordlist_n
	+literal _vocsref
	+token poke
!if C64 {
; Check for drive presence and disable I/O if absent
	+token one
	+literal 8
	+token over, zero, zero, c64open, c64close, c64iseof
	+literal _nodrive
	+token cpoke
; Open command channel for I/O status monitoring
	+literal 15
	+literal 8
	+token over, zero, zero, c64open, drop
;
}
	+literal autorun
	+token count, included
	+branch_fwd forth_system_1
forth_system_r:
	+token decimal, false, state, poke, xsst
forth_system_1:
	+token interpret
	+branch forth_system_1
banner_text:
	+string "FORTH TX16 " + VERSION_HIGH + "." + VERSION_LOW
bytesfree_text:
	+string "BYTES FREE"
autorun:
	+string "AUTORUN.FTH"

; ==============================================================================

!if F256 {
!source "console_F256.asm"
}


!if C64 and CART {
* = $9fff
	!byte 0
}

!if X16ROM {
; ROM template of the KERNAL bridge trampolines, copied to brg_ram at cold start.
; Order must match the SETLFS.. = brg_ram + i*BRIDGE_LEN assignments above.
brg_template:
	+ktramp $FFBA		; 0  SETLFS
	+ktramp $FFBD		; 1  SETNAM
	+ktramp $FFC0		; 2  OPEN
	+ktramp $FFC3		; 3  CLOSE
	+ktramp $FFC6		; 4  CHKIN
	+ktramp $FFC9		; 5  CHKOUT
	+ktramp $FFCC		; 6  CLRCHN
	+ktramp $FFCF		; 7  CHRIN
	+ktramp $FFD2		; 8  CHROUT
	+ktramp $FFE4		; 9  GETIN
	+ktramp $FFB7		; 10 READST
	+ktramp $FFE1		; 11 STOP
	+ktramp $FFD5		; 12 LOAD
	+ktramp $FFD8		; 13 SAVE
	+ktramp $FFF0		; 14 PLOT
	+ktramp $FF5F		; 15 screen_mode
	+ktramp $FECF		; 16 entropy_get
	+ktramp $FFDE		; 17 rdtim (jiffy clock)
	; 18 IRQ trampoline (template for bridge_irq). Copied to RAM with the rest,
	; it must sit exactly at brg_template + 18*BRIDGE_LEN. The KERNAL reaches it
	; via jmp (CINV) with ROM bank 0 selected; it crosses into the Forth bank,
	; runs irq_handler (which rts's back), restores the entered bank, then chains
	; to the original IRQ handler. Absolute operands stay valid after the copy.
	lda $01			; save the ROM bank we were entered with (KERNAL = 0)
	pha
	lda #FORTH_BANK		; cross into the Forth bank so irq_handler can run
	sta $01
	jsr irq_handler
	pla
	sta $01			; restore the entered ROM bank before chaining
	jmp (irq_chain)		; chain to the original IRQ handler
brg_template_end:

; JSRFAR for bank-9 code (FP bank 4 / audio bank $0A). Ported ROM part of the
; KERNAL jsrfar (6502/65C02 path). Reads the inline target/bank after the
; caller's "jsr brg_jsrfar", then hands off to the KERNAL RAM part jsrfar3
; ($02C4) which crosses to the target bank, calls it, restores our bank, and
; returns past the 3 arg bytes.
brg_jsrfar:
	php			; reserve 1 byte on the stack (for the saved bank)
	php			; save registers & status
	clc			; 65C02: emulation path (carry clear for the adc #3)
	pha
	phx
	phy
	tsx
	lda $0106,x		; return address lo
	sta imparm
	adc #3			; skip the 3 inline arg bytes
	sta $0106,x
	lda $0107,x		; return address hi
	sta imparm+1
	adc #0
	sta $0107,x
	ldy #1
	lda (imparm),y		; target lo
	sta jmpfr+1
	iny
	lda (imparm),y		; target hi
	sta jmpfr+2
	cmp #$c0
	bcc brg_jf_ram		; target is in RAM
	lda $01			; target in ROM: save current ROM bank into reserved byte
	sta $0105,x
	iny
	lda (imparm),y		; target bank
	ply
	plx
	jmp jsrfar3		; KERNAL RAM part completes the ROM-bank call
brg_jf_ram:
	lda $00			; target in RAM: save current RAM bank
	sta $0105,x
	iny
	lda (imparm),y		; target RAM bank
	sta $00
	ply
	plx
	pla
	plp
	jsr jmpfr
	php
	pha
	phx
	tsx
	lda $0104,x
	sta $00			; restore RAM bank
	lda $0103,x
	sta $0104,x
	plx
	pla
	plp
	plp
	rts

; This bank's CPU vectors. Every X16 ROM bank points these at the KERNAL's
; low-RAM trampolines so an IRQ/NMI taken while the bank is selected is handled
; (bank saved, KERNAL entered, bank restored). See inc/banks.inc: irq=$038b,
; nmi=$03b7. Pad the image up to the 16K bank's vector table.
!if X16CART {
; BASIC ROM CHRGET routine (r49), copied to zp $E7 at cart coldstart (the cart
; boots before BASIC would install it). Cart-only: keeps bank-9 byte-identical.
chrget_template:
	!byte $E6,$EE,$D0,$02,$E6,$EF,$AD,$60,$EA,$C9,$3A,$B0,$0A,$C9
	!byte $20,$F0,$EF,$38,$E9,$30,$38,$E9,$D0,$60
chrget_template_end:
}
!if FPCORE = 0 {
; The official X16 convention places a jsrfar entry at $FF6E in EVERY ROM
; bank, so cross-bank callers (e.g. toolkit/FLOAT.FTH's CODE words doing
; "jsr $FF6E / !word target / !byte bank") work no matter which bank is
; active. Route it to our ported jsrfar - jmp preserves the caller's stack
; exactly as brg_jsrfar expects. Only emitted when FP lives in the toolkit
; (FPCORE=0): that's the only caller, and the FP-baked layout has no room.
	!fill $FF6E - *, $ff
	jmp brg_jsrfar
}
	!fill $FFFA - *, $ff
	!word $03b7		; NMI  -> KERNAL NMI RAM trampoline
	!word $ffff		; RESET (hardware forces ROM bank 0 on reset; unused here)
	!word $038b		; IRQ  -> KERNAL banked-IRQ RAM handler
}

end_of_image:


} ; pseudopc

!if F256 {
+STARTUP start_of_image
}

!symbollist "symbols.txt"
