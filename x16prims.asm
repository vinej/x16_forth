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

; KERNAL routines called by name. In X16ROM mode these become RAM bridge
; trampolines (defined in fthtx16.asm); otherwise they are the direct $FFxx /
; jsrfar entries. JSRFAR routes FP/audio far-calls; the rest replace hard-coded
; jsr $FFxx sites so they bridge too.
!if X16ROM {
JSRFAR = brg_jsrfar
} else {
JSRFAR     = $FF6E
KLOAD      = $FFD5
KSAVE      = $FFD8
PLOT       = $FFF0
SCREENMODE = $FF5F
ENTROPY    = $FECF
}
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
	jsr ENTROPY			; entropy_get -> A,X,Y random bits
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

; F! and F@ live here (above the token boundary) rather than with the other FP
; words in x16.asm, so that FCONSTANT (a baked-in toolkit word) can reference
; them by token. fsp is a forward reference resolved from x16.asm.

; F! ( f-addr -- ) ( F: r -- )   store the top float at f-addr (5 bytes)
+header ~fstoremem, ~fstoremem_n, "F!"
	+code
	lda fsp				; src = top float
	sta $02
	lda fsp+1
	sta $03
	lda _dtop			; dest = f-addr
	sta $04
	lda _dtop+1
	sta $05
	ldy #4
-	lda ($02),y
	sta ($04),y
	dey
	bpl -
	clc					; pop the float
	lda fsp
	adc #5
	sta fsp
	lda fsp+1
	adc #0
	sta fsp+1
	+dpop				; pop f-addr
	jmp next

; F@ ( f-addr -- ) ( F: -- r )   push the float stored at f-addr
+header ~ffetchmem, ~ffetchmem_n, "F@"
	+code
	lda _dtop			; src = f-addr
	sta $02
	lda _dtop+1
	sta $03
	sec					; dst = fsp - 5 (new top)
	lda fsp
	sbc #5
	sta fsp
	sta $04
	lda fsp+1
	sbc #0
	sta fsp+1
	sta $05
	ldy #4
-	lda ($02),y
	sta ($04),y
	dey
	bpl -
	+dpop				; pop f-addr
	jmp next

; IRQPAUSE - hidden, nameless word used to end an IRQ Forth callback. It must
; be above the token boundary so its token can be emitted as a literal byte in
; irqpause_list (see x16.asm). The body just jumps to the handler tail.
+header ~irqpause, ~irqpause_n
	+code
	jmp irqpause_impl

; V>FILE ( len -- )   stream 'len' bytes from the VERA data port to the current
; output channel (set with CHKOUT). Used by VSAVE; above the boundary so the
; below-boundary VSAVE can reference it. VERA address must be set first (VADDR).
+header ~vtofile, ~vtofile_n
	+code
	+dpop
	sta _rscratch
	stx _rscratch+1
vtf_loop:
	lda _rscratch
	ora _rscratch+1
	beq vtf_done
	lda VERA_DATA0
	jsr CHROUT
	lda _rscratch
	bne +
	dec _rscratch+1
+:
	dec _rscratch
	jmp vtf_loop
vtf_done:
	jmp next

; DOVSAVE ( c-addr u bank vaddr len -- )   shared VRAM->disk save core (device 8,
; headerless). Above the boundary so VSAVE and the sprite/tile save words can
; reference it. See VSAVE in x16.asm for the user-facing wrapper.
+header ~dovsave, ~dovsave_n
	+forth
	+token tor				; R: len   ( c-addr u bank vaddr )
	+token vaddr				; ( c-addr u )   point VERA at bank:vaddr
	+literal wo_v				; write mode ( ",S,W" )
	+token openfile				; ( fileid ior )
	+qbranch_fwd dovsave_ok
	+token drop, rfrom, drop, exit		; open failed: drop fileid, drop len
dovsave_ok:
	+token dup, setwrite			; ( fileid )   CHKOUT fileid
	+token rfrom, vtofile			; ( fileid )   stream len bytes to the file
	+token zero, setwrite			; ( fileid )   CLRCHN
	+token closefile, drop, exit

; DOVBLOAD ( c-addr u dev bank vaddr -- )   shared headerless VRAM load core
; (same as BVLOAD). Above the boundary so the sprite/tile load words can use it.
+header ~dovbload, ~dovbload_n
	+code
	+ldax _dtop			; VRAM offset
	+stax _rscratch
	+dpop
	lda _dtop			; VRAM bank
	sta _scratch
	+dpop
	lda _dtop			; device
	sta _wscratch
	+dpop
	lda _dtop			; name length
	sta _wscratch+1
	+dpop
	+ldax _dtop			; name address
	pha
	txa
	tay
	pla
	tax
	lda _wscratch+1
	jsr SETNAM
	lda #1				; logical 1, device, secondary 2 (headerless)
	ldx _wscratch
	ldy #2
	jsr SETLFS
	lda _scratch			; A = VRAM bank + 2 selects the VRAM load target
	clc
	adc #2
	ldx _rscratch
	ldy _rscratch+1
	jsr KLOAD			; KERNAL LOAD
	+dpop
	jmp next

; SPRINFO ( sprite -- bank vaddr len )   from a sprite's attribute bytes, compute
; its image data VRAM address (17-bit -> bank + 16-bit vaddr) and byte count.
; addr17 = (b0 | (b1&0F)<<8) << 5 ; bank = bit16 = (b1&8)>>3 ; vaddr = addr17 & $FFFF
; bytes = (4bpp?32:64) << (widthcode+heightcode)
+header ~sprinfo, ~sprinfo_n
	+code
	lda _dtop			; sprite * 8 -> _rscratch
	sta _rscratch
	lda _dtop+1
	sta _rscratch+1
	asl _rscratch
	rol _rscratch+1
	asl _rscratch
	rol _rscratch+1
	asl _rscratch
	rol _rscratch+1
	clc				; VERA -> attr byte 0 (bank 1, auto-inc)
	lda _rscratch
	adc #<VRAM_SPRITES
	sta VERA_ADDR_L
	lda _rscratch+1
	adc #>VRAM_SPRITES
	sta VERA_ADDR_M
	lda #$11
	sta VERA_ADDR_H
	lda VERA_DATA0			; b0
	sta _scratch
	lda VERA_DATA0			; b1
	sta _scratch+1
	lda _scratch			; image addr = (b0 | (b1&0F)<<8) << 5
	sta _wscratch
	lda _scratch+1
	and #$0f
	sta _wscratch+1
	ldx #5
sprinfo_shl:
	asl _wscratch
	rol _wscratch+1
	dex
	bne sprinfo_shl
	clc				; VERA -> attr byte 7 for the size codes
	lda _rscratch
	adc #<(VRAM_SPRITES+7)
	sta VERA_ADDR_L
	lda _rscratch+1
	adc #>(VRAM_SPRITES+7)
	sta VERA_ADDR_M
	lda #$11
	sta VERA_ADDR_H
	lda VERA_DATA0			; b7
	pha
	and #$30			; width code (bits 5:4)
	lsr
	lsr
	lsr
	lsr
	sta _scratch			; widthcode
	pla
	and #$c0			; height code (bits 7:6)
	lsr
	lsr
	lsr
	lsr
	lsr
	lsr
	clc
	adc _scratch			; shift = widthcode + heightcode (0..6)
	tax
	lda _scratch+1			; bpp: b1 bit7 (0=4bpp, 1=8bpp)
	bmi sprinfo_8bpp
	lda #32
	bne sprinfo_base
sprinfo_8bpp:
	lda #64
sprinfo_base:
	sta _rscratch			; bytes = base << shift
	lda #0
	sta _rscratch+1
	cpx #0
	beq sprinfo_done
sprinfo_shl2:
	asl _rscratch
	rol _rscratch+1
	dex
	bne sprinfo_shl2
sprinfo_done:
	lda _scratch+1			; bank = (b1 & 8) >> 3  (image address bit 16)
	and #$08
	lsr
	lsr
	lsr
	sta _dtop
	lda #0
	sta _dtop+1			; _dtop = bank
	lda _wscratch			; push bank, _dtop = vaddr
	ldx _wscratch+1
	jsr push_dstack
	lda _rscratch			; push vaddr, _dtop = len
	ldx _rscratch+1
	jmp dpush_and_next
