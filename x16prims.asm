; ==============================================================================
; Commander X16 hardware words - referenceable primitives
; ==============================================================================
; Sourced by fthtx16.asm (X16 target only) just before the token-range boundary,
; so these words receive single-byte tokens and can be referenced by the
; higher-level X16 words in x16.asm (which live below the boundary).
;
; This file also defines the VERA/YM/audio assembler symbols and the audiocall
; macro used by both this file and x16.asm.

; ---- VERA register map (see X16 ROM inc/io.inc) ------------------------------
VERA_ADDR_L   = $9F20
VERA_ADDR_M   = $9F21
VERA_ADDR_H   = $9F22
VERA_DATA0    = $9F23
VERA_DATA1    = $9F24
VERA_CTRL     = $9F25
VERA_DC_VIDEO = $9F29		; valid when CTRL.DCSEL = 0
VERA_DC_BORDER= $9F2C		; valid when CTRL.DCSEL = 0

; VERA VRAM addresses of the internal register blocks (17-bit; the top bit is
; the "bank" passed to VADDR, the low 16 bits are the offset used below)
VRAM_PSG      = $F9C0		; bank 1: 16 voices * 4 bytes
VRAM_SPRITES  = $FC00		; bank 1: 128 sprites * 8 bytes

; YM2151 FM synthesizer registers
YM_REG        = $9F40
YM_DATA       = $9F41

; ---- Banked audio API (BANK_AUDIO = $0A), entry points in inc/audio.inc ------
BANK_AUDIO         = $0A
JSRFAR             = $FF6E
bas_fmnote          = $C003
ym_loadpatch        = $C069
ym_setatten         = $C075
ym_init             = $C063
ym_loaddefpatches   = $C066
psg_init            = $C04B
bas_psgnote         = $C012
psg_setpan          = $C05A
bas_playstringvoice = $C00C
bas_psgplaystring   = $C018
bas_psgchordstring  = $C090
bas_fmfreq          = $C000
bas_fmvib           = $C009
bas_fmplaystring    = $C006
bas_fmchordstring   = $C08D
ym_playdrum         = $C06F
ym_setpan           = $C07E
ym_write            = $C08A

; Call a routine in the audio ROM bank. A/X/Y and carry pass through to the
; callee and back (per the jsrfar convention).
!macro audiocall .addr {
	jsr JSRFAR
	!word .addr
	!byte BANK_AUDIO
}

; ==============================================================================
; VERA low-level access primitives
; ==============================================================================

; VADDR ( bank addr -- )
; Point the VERA data port at VRAM address (bank:addr) with auto-increment of 1,
; so successive V! / V@ walk through consecutive VRAM bytes. 'bank' is the 17th
; address bit (0 or 1); 'addr' is the low 16 bits.
+header ~vaddr, ~vaddr_n, "VADDR"
	+code
	lda _dtop			; addr low
	sta VERA_ADDR_L
	lda _dtop+1			; addr high
	sta VERA_ADDR_M
	ldy #2
	lda (_dstack),y		; bank (only bit 0 is used)
	and #1
	ora #$10			; increment select = 1 (add 1 after each access)
	sta VERA_ADDR_H
	+dpop				; drop addr
	+dpop				; drop bank
	jmp next

; V! ( byte -- )
; Store a byte through the VERA data port (address auto-increments).
+header ~vstore, ~vstore_n, "V!"
	+code
	lda _dtop
	sta VERA_DATA0
	+dpop
	jmp next

; V@ ( -- byte )
; Read a byte through the VERA data port (address auto-increments).
+header ~vfetch, ~vfetch_n, "V@"
	+code
	lda VERA_DATA0
	ldx #0
	jmp dpush_and_next

; V!W ( w -- )
; Store a 16-bit word through the VERA data port, low byte first.
+header ~vwstore, ~vwstore_n, "V!W"
	+forth
	+token dup
	+literal 255
	+token and_op, vstore
	+literal 8
	+token rshift, vstore, exit

; RANDOM ( -- u )   a 16-bit pseudo-random number from the KERNAL entropy source.
; Referenceable primitive so RND (and user code) can build on it.
+header ~random, ~random_n, "RANDOM"
	+code
	jsr $FECF			; entropy_get -> A,X,Y random bits
	jmp dpush_and_next

; >FLOAT ( c-addr u -- flag )   parse a string as a float; if valid push it (F: -- r).
; Referenceable (above the token boundary) so NUMBER can recognize float literals.
; Uses the ROM's fin parser (bank 4); valid only if the whole string is consumed.
; (fpush_fac lives in x16.asm - a forward reference the assembler resolves.)
FP_fin = $E039			; ROM: parse a float from the CHRGET stream into FAC
CHRGET = $E7			; zero-page CHRGET routine
TXTPTR = $EE			; CHRGET text pointer

+header ~tofloat, ~tofloat_n, ">FLOAT"
	+code
	lda _dtop			; u (length; float strings are short)
	sta $02
	ldy #2
	lda (_dstack),y		; c-addr low
	sta $04
	ldy #3
	lda (_dstack),y		; c-addr high
	sta $05
	ldy #0
tof_copy:
	cpy $02
	beq tof_done
	lda ($04),y
	sta _fnamebuf,y
	iny
	bne tof_copy
tof_done:
	lda #0
	sta _fnamebuf,y		; zero-terminate
	lda #<(_fnamebuf-1)	; txtptr = buffer-1; chrget advances to the first char
	sta TXTPTR
	lda #>(_fnamebuf-1)
	sta TXTPTR+1
	jsr CHRGET
	jsr JSRFAR			; fin (bank 4): FAC = value, txtptr advanced
	!word FP_fin
	!byte $04
	lda $02				; require a non-empty string
	beq tof_bad
	clc					; expected end = buffer + len
	lda #<_fnamebuf
	adc $02
	sta $06
	lda #>_fnamebuf
	adc #0
	sta $07
	lda TXTPTR			; was the whole string consumed?
	cmp $06
	bne tof_bad
	lda TXTPTR+1
	cmp $07
	bne tof_bad
	jsr fpush_fac		; valid: push the float
	+dpop				; drop u; _dtop = c-addr
	lda #$ff
	sta _dtop
	sta _dtop+1
	jmp next
tof_bad:
	+dpop
	lda #0
	sta _dtop
	sta _dtop+1
	jmp next
