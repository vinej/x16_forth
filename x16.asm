; ==============================================================================
; Commander X16 hardware words for Forth TX16
; ==============================================================================
; This file is sourced by fthtx16.asm only when building the X16 target
; (X16 = 1). It adds Forth words to drive the Commander X16 hardware that is
; not present on the plain C64: the VERA video chip, hardware sprites, the PSG
; and YM2151 (FM) audio, and binary LOAD/SAVE.
;
; The referenceable VERA primitives (VADDR, V!, V@, V!W) and all the VERA / YM /
; audio assembler symbols live in x16prims.asm, which is sourced earlier (above
; the token-range boundary). The words here are the user-facing "commands".
;
; Wherever it makes sense the words mirror the corresponding X16 BASIC commands
; (VPOKE, VPEEK, SCREEN, COLOR, VLOAD, SAVE, PSGFREQ, FMNOTE, ...) but follow
; Forth stack conventions. Arguments are pushed in the same left-to-right order
; as the BASIC command, e.g. BASIC "VPOKE bank,addr,value" becomes Forth
; "bank addr value VPOKE".
;
; Implementation notes:
; * VERA registers are simple memory-mapped I/O at $9F20, so most video words
;   just poke them directly.
; * KERNAL calls in the $FFxx page (LOAD, SAVE, SETLFS, SETNAM, PLOT, ...) work
;   directly because Forth runs with the default ROM bank 0 (KERNAL).
; * The FM words reach the audio API in banked ROM (BANK_AUDIO) through the
;   KERNAL jsrfar gate. The PSG words write VERA's PSG registers directly, which
;   needs no banking.

; ==============================================================================
; VERA video
; ==============================================================================

; VPOKE ( bank addr value -- )   ( = BASIC: VPOKE bank,addr,value )
+header ~vpoke, ~vpoke_n, "VPOKE"
	+forth
	+token tor, vaddr, rfrom, vstore, exit

; VPEEK ( bank addr -- value )   ( = BASIC: VPEEK(bank,addr) )
+header ~vpeek, ~vpeek_n, "VPEEK"
	+forth
	+token vaddr, vfetch, exit

; ==============================================================================
; Text screen
; ==============================================================================

; SCREEN ( mode -- )   ( = BASIC: SCREEN mode )
; Common modes: 0 = 80x60, 1 = 80x30, 2 = 40x60, 3 = 40x30, 128 = 320x240 @256c
+header ~screen, ~screen_n, "SCREEN"
	+code
	lda _dtop
	clc					; carry clear = set mode (set = query)
	jsr SCREENMODE			; KERNAL screen_mode
	+dpop
	jmp next

; COLOR ( fg bg -- )   ( = BASIC: COLOR fg,bg )   colors 0-15
+header ~color, ~color_n, "COLOR"
	+code
	ldy #2
	lda (_dstack),y		; fg
	and #15
	tax
	lda x16_coltab,x
	jsr CHROUT
	lda #1				; swap fg/bg
	jsr CHROUT
	lda _dtop			; bg
	and #15
	tax
	lda x16_coltab,x
	jsr CHROUT
	lda #1				; swap fg/bg back
	jsr CHROUT
	+dpop
	+dpop
	jmp next
x16_coltab:
	!byte $90,$05,$1c,$9f,$9c,$1e,$1f,$9e
	!byte $81,$95,$96,$97,$98,$99,$9a,$9b

; BORDER ( color -- )   set the display border color (0-15)
+header ~border, ~border_n, "BORDER"
	+code
	lda VERA_CTRL		; make sure DCSEL = 0
	and #$fd
	sta VERA_CTRL
	lda _dtop
	sta VERA_DC_BORDER
	+dpop
	jmp next

; CLS ( -- )   clear the text screen
+header ~cls, ~cls_n, "CLS"
	+forth
	+literal $93		; PETSCII clear-screen
	+token emit, exit

; LOCATE ( row col -- )   ( = BASIC: LOCATE row,col )   move the text cursor
+header ~locate, ~locate_n, "LOCATE"
	+code
	ldy #2
	lda (_dstack),y		; row
	tax
	lda _dtop			; col
	tay
	clc					; carry clear = set cursor
	jsr PLOT			; KERNAL PLOT
	+dpop
	+dpop
	jmp next

; CURSOR ( -- row col )   read the text cursor position (inverse of LOCATE)
+header ~cursor, ~cursor_n, "CURSOR"
	+code
	sec					; carry set = read cursor
	jsr PLOT			; KERNAL PLOT -> X = row, Y = col
	stx _scratch
	sty _scratch+1
	lda _scratch		; push row
	ldx #0
	jsr push_dstack
	lda _scratch+1		; then col on top
	ldx #0
	jmp dpush_and_next

; ==============================================================================
; Sprites (VERA sprite attributes at bank 1, offset VRAM_SPRITES; 8 bytes each)
;   byte 0-1: graphics address >> 5, and mode (bit 15 = 8bpp)
;   byte 2-3: X position (12-bit)
;   byte 4-5: Y position (12-bit)
;   byte 6  : [7:4] collision mask [3:2] Z-depth [1] V-flip [0] H-flip
;   byte 7  : [7:6] height [5:4] width [3:0] palette offset  (sizes: 0=8 1=16 2=32 3=64)
; ==============================================================================

; SPRITES-ON ( -- )   enable the sprite layer
+header ~sprites_on, ~sprites_on_n, "SPRITES-ON"
	+code
	lda VERA_CTRL		; DCSEL = 0 so $9F29 is DC_VIDEO
	and #$fd
	sta VERA_CTRL
	lda VERA_DC_VIDEO
	ora #$40			; sprites enable
	sta VERA_DC_VIDEO
	jmp next

; SPRITES-OFF ( -- )   disable the sprite layer
+header ~sprites_off, ~sprites_off_n, "SPRITES-OFF"
	+code
	lda VERA_CTRL
	and #$fd
	sta VERA_CTRL
	lda VERA_DC_VIDEO
	and #$bf
	sta VERA_DC_VIDEO
	jmp next

; SPRITE-IMAGE ( graphaddr sprite -- )
; Point sprite's image at VRAM graphaddr (4bpp). graphaddr must be 32-aligned.
+header ~sprite_image, ~sprite_image_n, "SPRITE-IMAGE"
	+forth
	+literal 8
	+token mult
	+literal VRAM_SPRITES
	+token add, one, swap, vaddr		; VERA -> attr byte 0
	+literal 5
	+token rshift, dup					; graphaddr >> 5
	+literal 255
	+token and_op, vstore				; byte 0
	+literal 8
	+token rshift
	+literal 15
	+token and_op, vstore				; byte 1 (mode = 0 -> 4bpp)
	+token exit

; SPRITE-POS ( x y sprite -- )
+header ~sprite_pos, ~sprite_pos_n, "SPRITE-POS"
	+forth
	+literal 8
	+token mult
	+token lit
	+value VRAM_SPRITES+2
	+token add, one, swap, vaddr		; VERA -> attr byte 2 (X)
	+token swap, vwstore, vwstore, exit	; write X then Y as words

; GETSPR ( sprite -- x y )   read a sprite's 12-bit X and Y position (inverse of
; SPRITE-POS). Reads attr bytes 2-5 back through the auto-incrementing data port.
+header ~getspr, ~getspr_n, "GETSPR"
	+forth
	+literal 8
	+token mult
	+token lit
	+value VRAM_SPRITES+2
	+token add, one, swap, vaddr		; VERA -> attr byte 2 (X low), auto-inc
	+token vfetch, vfetch			; ( xlo xhi )
	+literal 8
	+token lshift, or			; ( x )      x = xhi<<8 | xlo
	+token vfetch, vfetch			; ( x ylo yhi )
	+literal 8
	+token lshift, or, exit			; ( x y )

; SPRITE-SIZE ( width height sprite -- )   width/height codes 0-3 (8/16/32/64)
+header ~sprite_size, ~sprite_size_n, "SPRITE-SIZE"
	+forth
	+literal 8
	+token mult
	+token lit
	+value VRAM_SPRITES+7
	+token add, one, swap, vaddr		; VERA -> attr byte 7
	+literal 64
	+token mult, swap					; height << 6
	+literal 16
	+token mult, or, vstore, exit		; | width << 4

; SPRITE-Z ( z sprite -- )   Z-depth 0=off 1=behind-layers 2=between 3=front
+header ~sprite_z, ~sprite_z_n, "SPRITE-Z"
	+forth
	+literal 8
	+token mult
	+token lit
	+value VRAM_SPRITES+6
	+token add, one, swap, vaddr		; VERA -> attr byte 6
	+literal 4
	+token mult, vstore, exit			; z << 2

; --- BASIC-compatible sprite commands ----------------------------------------

; MOVSPR ( num x y -- )   ( = BASIC: MOVSPR num,x,y )   set sprite position
+header ~movspr, ~movspr_n, "MOVSPR"
	+forth
	+token rot							; ( x y num )
	+literal 8
	+token mult
	+token lit
	+value VRAM_SPRITES+2
	+token add, one, swap, vaddr		; VERA -> attr byte 2 (X)
	+token swap, vwstore, vwstore, exit	; write X then Y

; SPRMEM ( num bank addr -- )   ( = BASIC: SPRMEM num,bank,addr )
; Point sprite's image at VRAM (bank:addr), 4bpp. addr should be 32-aligned.
+header ~sprmem, ~sprmem_n, "SPRMEM"
	+forth
	+literal 5
	+token rshift, swap					; ( num addr>>5 bank )
	+literal 2048
	+token mult, add, swap				; ( a num )  a = bank*2048 + addr>>5
	+literal 8
	+token mult
	+token lit
	+value VRAM_SPRITES
	+token add, one, swap, vaddr		; VERA -> attr byte 0
	+token dup
	+literal 255
	+token and_op, vstore				; byte 0 = a low
	+literal 8
	+token rshift
	+literal 15
	+token and_op, vstore, exit			; byte 1 = a high nibble (mode 0 = 4bpp)

; SPRITE ( num zdepth -- )   ( = BASIC: SPRITE num,zdepth )
; Set Z-depth (0=off 1-3) in attr byte 6 and enable the sprite layer.
+header ~sprite, ~sprite_n, "SPRITE"
	+forth
	+token swap							; ( zdepth num )
	+literal 8
	+token mult
	+token lit
	+value VRAM_SPRITES+6
	+token add, dup, tor				; ( zdepth addr )  R: addr
	+token one, swap, vaddr				; point to byte 6
	+token vfetch						; ( zdepth old )
	+literal 243
	+token and_op, swap					; clear Z bits (%11110011)
	+literal 4
	+token mult, or						; ( new )  | zdepth<<2
	+token one, rfrom, vaddr, vstore	; rewrite byte 6
	; enable the sprite layer: DCSEL=0, then DC_VIDEO bit 6
	+token lit
	+value $9F25
	+token dup, cpeek
	+literal 253
	+token and_op, swap, cpoke
	+token lit
	+value $9F29
	+token dup, cpeek
	+literal 64
	+token or, swap, cpoke, exit

; ==============================================================================
; PSG audio (VERA PSG registers, bank 1 offset VRAM_PSG; 4 bytes per voice)
;   byte 0-1: frequency word
;   byte 2  : [7] right [6] left [5:0] volume
;   byte 3  : [7:6] waveform (0=pulse 1=saw 2=tri 3=noise) [5:0] pulse width
; ==============================================================================

; PSGFREQ ( freq voice -- )   ( ~ BASIC: PSGFREQ voice,freq )   voice 0-15
+header ~psgfreq, ~psgfreq_n, "PSGFREQ"
	+forth
	+literal 4
	+token mult
	+literal VRAM_PSG
	+token add, one, swap, vaddr		; VERA -> voice byte 0
	+token vwstore, exit

; PSGVOL ( vol voice -- )   ( ~ BASIC: PSGVOL voice,vol )   vol 0-63, L+R on
+header ~psgvol, ~psgvol_n, "PSGVOL"
	+forth
	+literal 4
	+token mult
	+token lit
	+value VRAM_PSG+2
	+token add, one, swap, vaddr		; VERA -> voice byte 2
	+literal 63
	+token and_op
	+literal 192
	+token or, vstore, exit				; L+R panning bits set

; PSGWAV ( waveform voice -- )   ( ~ BASIC: PSGWAV voice,wave )   waveform 0-3
+header ~psgwav, ~psgwav_n, "PSGWAV"
	+forth
	+literal 4
	+token mult
	+token lit
	+value VRAM_PSG+3
	+token add, one, swap, vaddr		; VERA -> voice byte 3
	+literal 64
	+token mult
	+literal 32
	+token or, vstore, exit				; waveform<<6, mid pulse width

; PSGINIT ( -- )   reset/initialize all PSG voices
+header ~psginit, ~psginit_n, "PSGINIT"
	+code
	+audiocall psg_init
	jmp next

; PSGNOTE ( note voice -- )   play a note; note = octave<<4 | (1..12), 0 = release
+header ~psgnote, ~psgnote_n, "PSGNOTE"
	+code
	ldy #2
	lda (_dstack),y		; packed note
	tax
	ldy #0				; no extra semitones
	lda _dtop			; voice
	+audiocall bas_psgnote
	+dpop
	+dpop
	jmp next

; PSGPAN ( pan voice -- )   set stereo pan (1=left 2=right 3=both)
+header ~psgpan, ~psgpan_n, "PSGPAN"
	+code
	ldy #2
	lda (_dstack),y		; pan
	tax
	lda _dtop			; voice
	+audiocall psg_setpan
	+dpop
	+dpop
	jmp next

; PSGPLAY ( c-addr u voice -- )   play a note/play-string on a voice (blocking)
+header ~psgplay, ~psgplay_n, "PSGPLAY"
	+code
	jsr pop_dstack		; voice
	sta _scratch
	jsr pop_dstack		; u (length)
	sta _scratch+1
	jsr pop_dstack		; c-addr
	sta _wscratch
	stx _wscratch+1
	lda _scratch		; select the voice
	+audiocall bas_playstringvoice
	lda _scratch+1		; length
	ldx _wscratch		; string addr lo
	ldy _wscratch+1		; string addr hi
	+audiocall bas_psgplaystring
	jmp next

; PSGCHORD ( c-addr u voice -- )   play a chord string on a voice (blocking)
+header ~psgchord, ~psgchord_n, "PSGCHORD"
	+code
	jsr pop_dstack		; voice
	sta _scratch
	jsr pop_dstack		; u (length)
	sta _scratch+1
	jsr pop_dstack		; c-addr
	sta _wscratch
	stx _wscratch+1
	lda _scratch
	+audiocall bas_playstringvoice
	lda _scratch+1
	ldx _wscratch
	ldy _wscratch+1
	+audiocall bas_psgchordstring
	jmp next

; ==============================================================================
; FM audio (YM2151). YM! writes registers directly; the higher-level words use
; the banked audio ROM API.
; ==============================================================================

; YM! ( value reg -- )   write a value to a YM2151 register
; The chip's busy flag is bit 7 of YM_DATA ($9F41), not YM_REG. Poll it with a
; bounded timeout (like the ROM's ym_write) so a wedged chip can never hang us.
+header ~ymstore, ~ymstore_n, "YM!"
	+code
	ldy #$ff
-	dey
	beq +				; timed out - write anyway rather than hang
	bit YM_DATA			; wait while the chip is busy (bit 7 set)
	bmi -
+	lda _dtop			; register number
	sta YM_REG
	ldy #2
	lda (_dstack),y		; value
	sta YM_DATA
	+dpop
	+dpop
	jmp next

; FMINIT ( -- )   initialize the YM2151 and load the default instrument patches
+header ~fminit, ~fminit_n, "FMINIT"
	+code
	+audiocall ym_init
	+audiocall ym_loaddefpatches
	jmp next

; FMINST ( inst channel -- )   ( = BASIC: FMINST channel,inst )   channel 0-7
+header ~fminst, ~fminst_n, "FMINST"
	+code
	ldy #2
	lda (_dstack),y		; instrument
	tax
	lda _dtop			; channel
	sec					; load patch from ROM
	+audiocall ym_loadpatch
	+dpop
	+dpop
	jmp next

; FMVOL ( vol channel -- )   ( = BASIC: FMVOL channel,vol )   vol 0-63
+header ~fmvol, ~fmvol_n, "FMVOL"
	+code
	ldy #2
	lda (_dstack),y		; volume
	bne +
	lda #$40
+	eor #$3f			; convert volume to attenuation
	tax
	lda _dtop			; channel
	+audiocall ym_setatten
	+dpop
	+dpop
	jmp next

; FMNOTE ( note channel -- )   ( = BASIC: FMNOTE channel,note )
; 'note' is packed: high nibble = octave (0-7), low nibble = note (1-12, 0=off)
+header ~fmnote, ~fmnote_n, "FMNOTE"
	+code
	ldy #2
	lda (_dstack),y		; packed note
	tax
	ldy #0				; no extra semitones
	lda _dtop			; channel
	+audiocall bas_fmnote
	+dpop
	+dpop
	jmp next

; FMFREQ ( freq channel -- )   play a raw frequency in Hz (17..4434) on a channel
+header ~fmfreq, ~fmfreq_n, "FMFREQ"
	+code
	ldy #2
	lda (_dstack),y		; freq low
	tax
	ldy #3
	lda (_dstack),y		; freq high
	tay
	lda _dtop			; channel
	clc
	+audiocall bas_fmfreq
	+dpop
	+dpop
	jmp next

; FMDRUM ( drum channel -- )   play a drum sound (drum 25..87, 0 = none)
+header ~fmdrum, ~fmdrum_n, "FMDRUM"
	+code
	ldy #2
	lda (_dstack),y		; drum
	tax
	lda _dtop			; channel
	+audiocall ym_playdrum
	+dpop
	+dpop
	jmp next

; FMVIB ( speed depth -- )   set the global FM vibrato (speed, depth 0..127)
+header ~fmvib, ~fmvib_n, "FMVIB"
	+code
	lda _dtop			; depth
	tax
	ldy #2
	lda (_dstack),y		; speed
	+audiocall bas_fmvib
	+dpop
	+dpop
	jmp next

; FMPAN ( pan channel -- )   set stereo pan (1=left 2=right 3=both)
+header ~fmpan, ~fmpan_n, "FMPAN"
	+code
	ldy #2
	lda (_dstack),y		; pan
	tax
	lda _dtop			; channel
	+audiocall ym_setpan
	+dpop
	+dpop
	jmp next

; FMPOKE ( value reg -- )   write a YM2151 register through the audio API
; (like YM! but the API also maintains its register shadows for FMVOL)
+header ~fmpoke, ~fmpoke_n, "FMPOKE"
	+code
	lda _dtop			; register
	tax
	ldy #2
	lda (_dstack),y		; value
	+audiocall ym_write
	+dpop
	+dpop
	jmp next

; FMPLAY ( c-addr u channel -- )   play a play-string on an FM channel (blocking)
+header ~fmplay, ~fmplay_n, "FMPLAY"
	+code
	jsr pop_dstack		; channel
	sta _scratch
	jsr pop_dstack		; u (length)
	sta _scratch+1
	jsr pop_dstack		; c-addr
	sta _wscratch
	stx _wscratch+1
	lda _scratch		; select the voice
	+audiocall bas_playstringvoice
	lda _scratch+1		; length
	ldx _wscratch		; addr lo
	ldy _wscratch+1		; addr hi
	+audiocall bas_fmplaystring
	jmp next

; FMCHORD ( c-addr u channel -- )   play a chord string on an FM channel (blocking)
+header ~fmchord, ~fmchord_n, "FMCHORD"
	+code
	jsr pop_dstack		; channel
	sta _scratch
	jsr pop_dstack		; u (length)
	sta _scratch+1
	jsr pop_dstack		; c-addr
	sta _wscratch
	stx _wscratch+1
	lda _scratch
	+audiocall bas_playstringvoice
	lda _scratch+1
	ldx _wscratch
	ldy _wscratch+1
	+audiocall bas_fmchordstring
	jmp next

; ==============================================================================
; Binary LOAD / SAVE (KERNAL). Filenames are ( c-addr u ) Forth strings.
; ==============================================================================

; LOAD ( c-addr u dev -- )   load a PRG file to the address in its 2-byte header
+header ~xload, ~xload_n, "LOAD"
	+code
	lda _dtop			; device
	sta _wscratch
	+dpop
	lda _dtop			; name length
	sta _wscratch+1
	+dpop
	+ldax _dtop			; name address (A=lo, X=hi)
	pha
	txa
	tay					; Y = name hi
	pla
	tax					; X = name lo
	lda _wscratch+1		; A = length
	jsr SETNAM
	lda #1				; logical file number
	ldx _wscratch		; device
	ldy #1				; secondary 1 -> use header address
	jsr SETLFS
	lda #0				; 0 = load (1 = verify)
	jsr KLOAD			; KERNAL LOAD
	+dpop
	jmp next

; BLOAD ( c-addr u dev addr -- )   load a PRG file, relocating it to 'addr'
+header ~xbload, ~xbload_n, "BLOAD"
	+code
	+ldax _dtop			; load address
	+stax _rscratch
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
	lda #1
	ldx _wscratch
	ldy #0				; secondary 0 -> load to address in X/Y
	jsr SETLFS
	lda #0
	ldx _rscratch		; load address low
	ldy _rscratch+1		; load address high
	jsr KLOAD			; KERNAL LOAD
	+dpop
	jmp next

; VLOAD ( c-addr u dev bank vaddr -- )   ( = BASIC: VLOAD name,dev,bank,addr )
; Load a file into VERA VRAM. 'bank' is the VRAM bank (0 or 1), 'vaddr' the offset.
+header ~xvload, ~xvload_n, "VLOAD"
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
	lda #1				; SETLFS: logical 1, device, secondary 0 (headered)
	ldx _wscratch
	ldy #0
	jsr SETLFS
	lda _scratch		; A = VRAM bank + 2 selects the VRAM load target
	clc
	adc #2
	ldx _rscratch		; VRAM offset low
	ldy _rscratch+1		; VRAM offset high
	jsr KLOAD			; KERNAL LOAD
	+dpop
	jmp next

; SAVE ( c-addr u dev start end -- )   ( = BASIC: BSAVE name,dev,start,end )
; Save memory from 'start' up to (but not including) 'end' as a PRG file.
+header ~xsave, ~xsave_n, "SAVE"
	+code
	+ldax _dtop			; end address (exclusive)
	+stax _rscratch
	+dpop
	+ldax _dtop			; start address
	+stax _scratch		; SAVE reads the start address through this pointer
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
	lda #1
	ldx _wscratch
	ldy #0
	jsr SETLFS
	lda #<_scratch		; zero-page offset of the start-address pointer
	ldx _rscratch		; end address low
	ldy _rscratch+1		; end address high
	jsr KSAVE			; KERNAL SAVE
	+dpop
	jmp next

; BVLOAD ( c-addr u dev bank vaddr -- )   ( = BASIC: BVLOAD name,dev,bank,addr )
; Load a headerless file straight into VERA VRAM (bank:vaddr).
+header ~xbvload, ~xbvload_n, "BVLOAD"
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
	lda #1				; SETLFS: logical 1, device, secondary 2 (headerless)
	ldx _wscratch
	ldy #2
	jsr SETLFS
	lda _scratch		; A = VRAM bank + 2
	clc
	adc #2
	ldx _rscratch		; VRAM offset low
	ldy _rscratch+1		; VRAM offset high
	jsr KLOAD			; KERNAL LOAD
	+dpop
	jmp next

; BVERIFY ( c-addr u dev addr -- flag )   ( = BASIC: BVERIFY name,dev,addr )
; Verify a headerless file against memory at addr. flag = -1 match, 0 mismatch.
+header ~xbverify, ~xbverify_n, "BVERIFY"
	+code
	+ldax _dtop			; address
	+stax _rscratch
	+dpop
	lda _dtop			; device
	sta _wscratch
	+dpop
	lda _dtop			; name length
	sta _wscratch+1
	+dpop
	+ldax _dtop			; name address (this cell becomes the result flag)
	pha
	txa
	tay
	pla
	tax
	lda _wscratch+1
	jsr SETNAM
	lda #1				; SETLFS: logical 1, device, secondary 2 (headerless)
	ldx _wscratch
	ldy #2
	jsr SETLFS
	lda #1				; A = 1 -> verify
	ldx _rscratch		; address low
	ldy _rscratch+1		; address high
	jsr KLOAD			; KERNAL LOAD (verify)
	jsr READST			; status: bit $10 set = mismatch
	and #$10
	beq bv_ok
	lda #0				; mismatch -> false
	tax
	jmp bv_store
bv_ok:
	lda #$ff			; match -> true
	tax
bv_store:
	sta _dtop
	stx _dtop+1
	jmp next

; ===========================================================================
; SAVE-IMAGE / LOAD-IMAGE - turnkey compiled-dictionary snapshot (device 8).
; Save the compiled dictionary once, reload it in ~1s instead of recompiling
; the source. Three files:
;   F.DIC = dictionary bytes   [dict-start .. HERE)
;   F.TOK = user token table   [core+1 .. hightoken)  (core tokens already valid)
;   F.VAR = dictionary-state zero-page block (HERE/LATEST/HIGHTOKEN/wordlists)
; LOAD-IMAGE is native so it can overwrite the dictionary safely (the core, from
; which it runs, lives below the dictionary).  PRG/C64 builds only - in the ROM
; build the KERNAL (bank 0) cannot read a filename stored in the bank-9 ROM.
; ===========================================================================
!if CART or X16ROM {
IMG_DICT_START = $0801
} else {
IMG_DICT_START = end_of_image
}
IMG_TOKUSER = TOKENS + ((forth_system + 1) << 1)

imgn_dic: !text "F.DIC"
imgn_tok: !text "F.TOK"
imgn_var: !text "F.VAR"

; copy the 61-byte dictionary-state zp block  (_here..7, _hightoken..54) <-> IMGBUF
img_vars_save:
	ldx #6
ivs1:	lda _here,x
	sta IMGBUF,x
	dex
	bpl ivs1
	ldx #53
ivs2:	lda _hightoken,x
	sta IMGBUF+7,x
	dex
	bpl ivs2
	rts
img_vars_load:
	ldx #6
ivl1:	lda IMGBUF,x
	sta _here,x
	dex
	bpl ivl1
	ldx #53
ivl2:	lda IMGBUF+7,x
	sta _hightoken,x
	dex
	bpl ivl2
	rts

img_setlfs_save:			; logical 1, device 8, secondary 0 (header = start addr)
	lda #1
	ldx #8
	ldy #0
	jmp SETLFS
img_setlfs_load:			; logical 1, device 8, secondary 1 (load to header addr)
	lda #1
	ldx #8
	ldy #1
	jmp SETLFS

+header ~saveimage, ~saveimage_n, "SAVE-IMAGE"
	+code
	jsr img_vars_save
	; ---- F.VAR : [IMGBUF .. IMGBUF+61) ----
	lda #5
	ldx #<imgn_var
	ldy #>imgn_var
	jsr SETNAM
	jsr img_setlfs_save
	lda #<IMGBUF
	sta _scratch
	lda #>IMGBUF
	sta _scratch+1
	lda #<_scratch
	ldx #<(IMGBUF+61)
	ldy #>(IMGBUF+61)
	jsr KSAVE
	; ---- F.DIC : [IMG_DICT_START .. HERE) ----
	lda #5
	ldx #<imgn_dic
	ldy #>imgn_dic
	jsr SETNAM
	jsr img_setlfs_save
	lda #<IMG_DICT_START
	sta _scratch
	lda #>IMG_DICT_START
	sta _scratch+1
	lda #<_scratch
	ldx _here
	ldy _here+1
	jsr KSAVE
	; ---- F.TOK : [IMG_TOKUSER .. TOKENS + 2*hightoken) ----
	lda #5
	ldx #<imgn_tok
	ldy #>imgn_tok
	jsr SETNAM
	jsr img_setlfs_save
	lda #<IMG_TOKUSER
	sta _scratch
	lda #>IMG_TOKUSER
	sta _scratch+1
	; end = TOKENS + 2*(hightoken+1)   (hightoken is the highest USED token,
	; so the last-defined word's entry must be included)
	clc
	lda _hightoken
	adc #1
	sta _rscratch
	lda _hightoken+1
	adc #0
	sta _rscratch+1			; _rscratch = hightoken+1
	asl _rscratch			; _rscratch = 2*(hightoken+1)
	rol _rscratch+1
	clc
	lda _rscratch
	adc #<TOKENS			; <TOKENS = 0
	tax
	lda _rscratch+1
	adc #>TOKENS
	tay
	lda #<_scratch
	jsr KSAVE
	jsr CLRCHN			; restore keyboard-in/screen-out after the file writes
	jmp next

; LOAD-IMAGE ( -- flag )   flag = -1 if the image loaded, 0 if F.DIC was missing
+header ~loadimage, ~loadimage_n, "LOAD-IMAGE"
	+code
	; F.DIC -> IMG_DICT_START (file header address)
	lda #5
	ldx #<imgn_dic
	ldy #>imgn_dic
	jsr SETNAM
	jsr img_setlfs_load
	lda #0
	jsr KLOAD
	bcc li_have
	jsr CLRCHN			; no image: leave the dictionary untouched, return false
	lda #0
	tax
	jmp dpush_and_next
li_have:
	; F.TOK -> IMG_TOKUSER (file header address)
	lda #5
	ldx #<imgn_tok
	ldy #>imgn_tok
	jsr SETNAM
	jsr img_setlfs_load
	lda #0
	jsr KLOAD
	; F.VAR -> IMGBUF (file header address)
	lda #5
	ldx #<imgn_var
	ldy #>imgn_var
	jsr SETNAM
	jsr img_setlfs_load
	lda #0
	jsr KLOAD
	jsr img_vars_load
	jsr CLRCHN			; restore keyboard-in/screen-out (KLOAD leaves it broken
					; for the next console read - the "OPEN bug")
	lda #$ff			; success -> true
	tax
	jmp dpush_and_next

; VSAVE ( c-addr u bank vaddr len -- )   save 'len' bytes of VRAM at bank:vaddr
; to a headerless file on device 8. The inverse of BVLOAD - what VSAVE writes,
; BVLOAD reads straight back into VRAM. (The KERNAL SAVE cannot read VRAM, so
; the bytes are streamed through the VERA data port to an open file.)
+header ~vsave, ~vsave_n, "VSAVE"
	+forth
	+token dovsave, exit

; --- sprite / tile definition save & load (all on device 8) -----------------

; SPRSAVE ( c-addr u sprite -- )   save a sprite's image pixel data. The image
; address and byte count are taken from the sprite's own attribute bytes.
+header ~sprsave, ~sprsave_n, "SPRSAVE"
	+forth
	+token sprinfo				; ( c-addr u bank vaddr len )
	+token dovsave, exit

; SPRLOAD ( c-addr u sprite -- )   load pixel data into a sprite's image area.
+header ~sprload, ~sprload_n, "SPRLOAD"
	+forth
	+token sprinfo, drop			; ( c-addr u bank vaddr )
	+token tor, tor				; R: vaddr bank   ( c-addr u )
	+literal 8				; device 8
	+token rfrom, rfrom			; ( c-addr u 8 bank vaddr )
	+token dovbload, exit

; TILESAVE ( c-addr u vaddr len -- )   save 'len' bytes of a bank-1 tileset.
+header ~tilesave, ~tilesave_n, "TILESAVE"
	+forth
	+token tor, tor				; R: len vaddr   ( c-addr u )
	+token one				; bank 1
	+token rfrom, rfrom			; ( c-addr u 1 vaddr len )
	+token dovsave, exit

; TILELOAD ( c-addr u vaddr -- )   load a tileset into bank-1 VRAM at vaddr.
+header ~tileload, ~tileload_n, "TILELOAD"
	+forth
	+token tor				; R: vaddr
	+literal 8
	+token one
	+token rfrom				; ( c-addr u 8 1 vaddr )
	+token dovbload, exit

; The layer-1 tilemap address (bank, vaddr) is derived from VERA_L1_MAPBASE:
;   vaddr = (reg & $7F) << 9 ,  bank = reg >> 7
; and its byte size from VERA_L1_CONFIG map width/height fields:
;   mapw = 32 << ((cfg>>4)&3) , maph = 32 << ((cfg>>6)&3) , len = mapw*maph*2

; TMAPSAVE ( c-addr u -- )   save the layer-1 tilemap (self-sizing).
+header ~tmapsave, ~tmapsave_n, "TMAPSAVE"
	+forth
	+token lit
	+value VERA_L1_MAPBASE
	+token cpeek, dup			; ( c-addr u reg reg )
	+literal 7
	+token rshift, swap			; ( c-addr u bank reg )
	+literal 127
	+token and_op
	+literal 9
	+token lshift				; ( c-addr u bank vaddr )
	+token lit
	+value VERA_L1_CONFIG
	+token cpeek, dup			; ( ... cfg cfg )
	+literal 4
	+token rshift
	+literal 3
	+token and_op
	+literal 32
	+token swap, lshift, swap		; ( ... mapw cfg )
	+literal 6
	+token rshift
	+literal 3
	+token and_op
	+literal 32
	+token swap, lshift			; ( ... mapw maph )
	+token mult
	+literal 2
	+token mult				; ( c-addr u bank vaddr len )
	+token dovsave, exit

; TMAPLOAD ( c-addr u -- )   load the layer-1 tilemap back to its VRAM address.
+header ~tmapload, ~tmapload_n, "TMAPLOAD"
	+forth
	+token lit
	+value VERA_L1_MAPBASE
	+token cpeek, dup			; ( c-addr u reg reg )
	+literal 7
	+token rshift, swap			; ( c-addr u bank reg )
	+literal 127
	+token and_op
	+literal 9
	+token lshift				; ( c-addr u bank vaddr )
	+token tor, tor				; R: vaddr bank   ( c-addr u )
	+literal 8				; device 8
	+token rfrom, rfrom			; ( c-addr u 8 bank vaddr )
	+token dovbload, exit

; ==============================================================================
; Bitmap graphics (KERNAL GRAPH API). Call GINIT once to enter 320x240 graphics
; mode; coordinates are 0..319 (x) by 0..239 (y). The rectangle/oval words take
; two corner points like BASIC and sort/convert them internally.
; GRAPH passes 16-bit arguments in the r0..r15 pseudo-registers at $02..$21,
; which are outside Forth's zero page ($22..$7F).
; ==============================================================================

GRAPH_init       = $FF20
GRAPH_clear      = $FF23
GRAPH_set_colors = $FF29
GRAPH_draw_line  = $FF2C
GRAPH_draw_rect  = $FF2F
GRAPH_draw_oval  = $FF35
GRAPH_put_char   = $FF41

; KERNAL API pseudo-registers (zero page, outside Forth's $22..$7F)
r0L = $02
r0H = $03
r1L = $04
r1H = $05
r2L = $06
r2H = $07
r3L = $08
r3H = $09
r4L = $0A
r4H = $0B
r14L = $1E
r15L = $20
r15H = $21

; Pop x1 y1 x2 y2 color (color on top) into r0,r1,r2,r3 and set the draw color.
; Tail-calls GRAPH_set_colors so it returns to the caller of g_args4.
g_args4:
	jsr pop_dstack		; color
	pha
	jsr pop_dstack		; y2 -> r3
	sta r3L
	stx r3H
	jsr pop_dstack		; x2 -> r2
	sta r2L
	stx r2H
	jsr pop_dstack		; y1 -> r1
	sta r1L
	stx r1H
	jsr pop_dstack		; x1 -> r0
	sta r0L
	stx r0H
	pla					; color -> stroke and fill
	tax
	ldy #0				; background 0
	jmp GRAPH_set_colors

; Convert corner points r0..r3 (x1,y1,x2,y2) into x,y,width,height like BASIC's
; convert_point_size: sorts the corners, then width = dx+1, height = dy+1.
g_convps:
	lda r0L				; if r0 > r2 swap (sort X)
	cmp r2L
	lda r0H
	sbc r2H
	bcc +
	ldy r0L
	lda r2L
	sta r0L
	sty r2L
	ldy r0H
	lda r2H
	sta r0H
	sty r2H
+
	lda r1L				; if r1 > r3 swap (sort Y)
	cmp r3L
	lda r1H
	sbc r3H
	bcc +
	ldy r1L
	lda r3L
	sta r1L
	sty r3L
	ldy r1H
	lda r3H
	sta r1H
	sty r3H
+
	sec					; width = r2 - r0 + 1
	lda r2L
	sbc r0L
	sta r2L
	lda r2H
	sbc r0H
	sta r2H
	inc r2L
	bne +
	inc r2H
+
	sec					; height = r3 - r1 + 1
	lda r3L
	sbc r1L
	sta r3L
	lda r3H
	sbc r1H
	sta r3H
	inc r3L
	bne +
	inc r3H
+
	rts

; GINIT ( -- )   enter 320x240x256 bitmap graphics mode
+header ~ginit, ~ginit_n, "GINIT"
	+code
	lda #128			; screen mode 320x240 @ 256 colors
	clc
	jsr SCREENMODE			; screen_mode
	lda #0
	sta r0L
	sta r0H				; r0 = 0 -> default graphics mode
	jsr GRAPH_init
	lda #1				; default colors: stroke 1, fill 1, background 0
	ldx #1
	ldy #0
	jsr GRAPH_set_colors
	jmp next

; GCLS ( -- )   clear the graphics screen to the background color
+header ~gcls, ~gcls_n, "GCLS"
	+code
	jsr GRAPH_clear
	jmp next

; PSET ( x y color -- )   set one pixel
+header ~pset, ~pset_n, "PSET"
	+code
	jsr pop_dstack		; color
	pha
	jsr pop_dstack		; y -> r1 and r3
	sta r1L
	stx r1H
	sta r3L
	stx r3H
	jsr pop_dstack		; x -> r0 and r2
	sta r0L
	stx r0H
	sta r2L
	stx r2H
	pla
	tax
	ldy #0
	jsr GRAPH_set_colors
	lda #0
	jsr GRAPH_draw_line	; a zero-length line is a single pixel
	jmp next

; LINE ( x1 y1 x2 y2 color -- )   draw a line
+header ~line, ~line_n, "LINE"
	+code
	jsr g_args4
	lda #0
	jsr GRAPH_draw_line
	jmp next

; FRAME ( x1 y1 x2 y2 color -- )   rectangle outline
+header ~frame, ~frame_n, "FRAME"
	+code
	jsr g_args4
	jsr g_convps
	lda #0
	sta r4L
	sta r4H				; corner radius 0
	clc					; outline
	jsr GRAPH_draw_rect
	jmp next

; RECT ( x1 y1 x2 y2 color -- )   filled rectangle
+header ~rect, ~rect_n, "RECT"
	+code
	jsr g_args4
	jsr g_convps
	lda #0
	sta r4L
	sta r4H
	sec					; filled
	jsr GRAPH_draw_rect
	jmp next

; RING ( x1 y1 x2 y2 color -- )   ellipse outline
+header ~ring, ~ring_n, "RING"
	+code
	jsr g_args4
	jsr g_convps
	clc					; outline
	jsr GRAPH_draw_oval
	jmp next

; OVAL ( x1 y1 x2 y2 color -- )   filled ellipse
+header ~oval, ~oval_n, "OVAL"
	+code
	jsr g_args4
	jsr g_convps
	sec					; filled
	jsr GRAPH_draw_oval
	jmp next

; GTEXT ( x y color c-addr u -- )   ( = BASIC: CHAR x,y,color,string$ )
; Draw a string into the bitmap at (x,y). Named GTEXT because CHAR is a core word.
+header ~gtext, ~gtext_n, "GTEXT"
	+code
	jsr pop_dstack		; u (length)
	sta r14L
	jsr pop_dstack		; c-addr -> r15
	sta r15L
	stx r15H
	jsr pop_dstack		; color
	pha
	jsr pop_dstack		; y -> r1
	sta r1L
	stx r1H
	jsr pop_dstack		; x -> r0
	sta r0L
	stx r0H
	pla					; color = stroke
	ldx #15				; secondary color
	ldy #1				; background
	jsr GRAPH_set_colors
	lda #$92			; reset text attributes
	jsr GRAPH_put_char
	lda #0
	sta _scratch		; loop index (GRAPH_put_char leaves $22+ alone)
gtext_loop:
	lda _scratch
	cmp r14L
	bcs gtext_done
	ldy _scratch
	lda (r15L),y
	jsr GRAPH_put_char
	inc _scratch
	bne gtext_loop
gtext_done:
	jmp next

; ==============================================================================
; Input devices - joystick/gamepad and mouse (KERNAL)
; ==============================================================================
joystick_get = $FF56
mouse_config = $FF68
mouse_get    = $FF6B

; JOY ( n -- buttons )   read joystick/gamepad n (0 = keyboard, 1-4 = gamepads).
; Returns button bits active-high (low byte = SNES buttons, high byte = A/X/L/R
; in the upper nibble), or 0 if that controller is not present.
+header ~joy, ~joy_n, "JOY"
	+code
	lda _dtop			; joystick number
	jsr joystick_get	; A=byte0, X=byte1, Y=$00 present / $FF absent
	cpy #0
	bne joy_absent
	eor #$ff			; invert -> active high (low result byte)
	sta _dtop
	txa
	eor #$ff			; high result byte
	sta _dtop+1
	jmp next
joy_absent:
	lda #0
	sta _dtop
	sta _dtop+1
	jmp next

; MOUSE ( mode -- )   configure the mouse pointer (0 = off, 1 = on, -1 = auto-scale)
+header ~mouse, ~mouse_n, "MOUSE"
	+code
	lda _dtop			; mode (low byte)
	pha
	sec
	jsr SCREENMODE			; screen_mode query -> X = columns, Y = rows
	pla
	jsr mouse_config	; A = mode, X = cols, Y = rows
	+dpop
	jmp next

; MX ( -- x )   mouse X position
+header ~mx, ~mx_n, "MX"
	+code
	ldx #2				; mouse_get buffer at $02..$05
	jsr mouse_get
	lda $02
	ldx $03
	jmp dpush_and_next

; MY ( -- y )   mouse Y position
+header ~my, ~my_n, "MY"
	+code
	ldx #2
	jsr mouse_get
	lda $04
	ldx $05
	jmp dpush_and_next

; MB ( -- buttons )   mouse button bitmask (bit0 left, bit1 right, bit2 middle)
+header ~mb, ~mb_n, "MB"
	+code
	ldx #2
	jsr mouse_get		; A = buttons
	ldx #0
	jmp dpush_and_next

; MWHEEL ( -- delta )   mouse wheel movement since last read (signed)
+header ~mwheel, ~mwheel_n, "MWHEEL"
	+code
	ldx #2
	jsr mouse_get		; X = wheel delta
	txa
	ldx #0
	cmp #$80
	bcc +
	ldx #$ff			; sign-extend a negative delta
+
	jmp dpush_and_next

; ==============================================================================
; Math helpers (integer). ABS, MIN, MAX, MOD already exist in the core; FRE maps
; to UNUSED; INT is a no-op for 16-bit integers.
; ==============================================================================

; SGN ( n -- -1|0|1 )   sign of a signed number
+header ~sgn, ~sgn_n, "SGN"
	+code
	lda _dtop+1
	bmi sgn_neg			; negative
	lda _dtop
	ora _dtop+1
	beq sgn_store0		; zero (A already 0)
	ldx #0
	lda #1				; positive -> 1
	bne sgn_store
sgn_neg:
	ldx #$ff
	lda #$ff			; -> -1
	bne sgn_store
sgn_store0:
	tax					; A=0 -> X=0
sgn_store:
	sta _dtop
	stx _dtop+1
	jmp next

; RND ( u -- n )   pseudo-random number in 0..u-1 (u > 0)
+header ~rnd, ~rnd_n, "RND"
	+forth
	+token random, swap, tor, zero, rfrom, ummod, drop, exit

; POS ( -- col )   current text cursor column
+header ~pos, ~pos_n, "POS"
	+code
	sec
	jsr PLOT			; PLOT read: X = row, Y = column
	tya
	ldx #0
	jmp dpush_and_next

; ==============================================================================
; Tiles - read/write the layer-1 tilemap (the text screen). Each tile cell is
; two VRAM bytes: a screen/tile code and a colour attribute. The cell address is
; computed from VERA_L1_MAPBASE and the map width in VERA_L1_CONFIG, so these
; adapt to whatever screen mode is active.
; ==============================================================================

VERA_L1_CONFIG  = $9F34
VERA_L1_MAPBASE = $9F35

; scratch in the KERNAL API register area ($02..$09), free here (no GRAPH calls)
ta_res = $02		; 3-byte VRAM address accumulator
ta_tmp = $05		; 3-byte temporary
ta_x   = $08		; input column
ta_y   = $09		; input row

; Point VERA_ADDR at the tile cell (ta_x, ta_y) of layer 1, autoincrement 1.
; address = MAPBASE*512 + y*stride + x*2, stride = 64 << (L1 width code).
tile_addr:
	lda #0
	sta ta_res
	lda VERA_L1_MAPBASE		; res = MAPBASE << 9
	asl
	sta ta_res+1
	lda #0
	rol
	sta ta_res+2
	lda ta_y				; tmp = y, shifted left (widthcode+6) = y*stride
	sta ta_tmp
	lda #0
	sta ta_tmp+1
	sta ta_tmp+2
	lda VERA_L1_CONFIG
	lsr
	lsr
	lsr
	lsr
	and #3
	clc
	adc #6
	tax
ta_shift:
	asl ta_tmp
	rol ta_tmp+1
	rol ta_tmp+2
	dex
	bne ta_shift
	clc						; res += tmp
	lda ta_res
	adc ta_tmp
	sta ta_res
	lda ta_res+1
	adc ta_tmp+1
	sta ta_res+1
	lda ta_res+2
	adc ta_tmp+2
	sta ta_res+2
	lda ta_x				; tmp = x*2 (two bytes per cell)
	asl
	sta ta_tmp
	lda #0
	rol
	sta ta_tmp+1
	clc						; res += x*2
	lda ta_res
	adc ta_tmp
	sta ta_res
	lda ta_res+1
	adc ta_tmp+1
	sta ta_res+1
	lda ta_res+2
	adc #0
	sta ta_res+2
	lda ta_res				; program VERA_ADDR
	sta VERA_ADDR_L
	lda ta_res+1
	sta VERA_ADDR_M
	lda ta_res+2
	and #1
	ora #$10				; bit16 + autoincrement 1
	sta VERA_ADDR_H
	rts

; TILE ( x y code attr -- )   ( ~ BASIC: TILE x,y,code,attr )   set a tile cell
+header ~tile, ~tile_n, "TILE"
	+code
	jsr pop_dstack			; attr
	pha
	jsr pop_dstack			; code
	pha
	jsr pop_dstack			; y
	sta ta_y
	jsr pop_dstack			; x
	sta ta_x
	jsr tile_addr
	pla						; code -> char byte
	sta VERA_DATA0
	pla						; attr -> next byte
	sta VERA_DATA0
	jmp next

; TDATA ( x y -- code )   ( = BASIC: TDATA(x,y) )   read a tile's code
+header ~tdata, ~tdata_n, "TDATA"
	+code
	jsr pop_dstack			; y
	sta ta_y
	jsr pop_dstack			; x
	sta ta_x
	jsr tile_addr
	lda VERA_DATA0
	ldx #0
	jmp dpush_and_next

; TATTR ( x y -- attr )   ( = BASIC: TATTR(x,y) )   read a tile's attribute
+header ~tattr, ~tattr_n, "TATTR"
	+code
	jsr pop_dstack			; y
	sta ta_y
	jsr pop_dstack			; x
	sta ta_x
	jsr tile_addr
	lda VERA_DATA0			; code byte (skip)
	lda VERA_DATA0			; attribute byte
	ldx #0
	jmp dpush_and_next

; ==============================================================================
; System / dev
; ==============================================================================

; USR ( addr -- )   call a machine-language routine at addr; the routine must RTS.
; (The X16 BASIC USR passes an argument in the FP accumulator; here it is simply
; a direct call, the Forth equivalent of "call this ML address".)
+header ~usr, ~usr_n, "USR"
	+code
	lda _dtop
	sta usr_call+1
	lda _dtop+1
	sta usr_call+2
	+dpop
	jsr usr_call			; the routine returns here, then we continue
	jmp next
usr_call:
	jmp $ffff				; operand patched above to the target address

; MONITOR ( -- )   enter the built-in machine-language monitor (exit with X).
; The monitor lives in its own ROM bank and uses zero page outside Forth's area,
; so it returns cleanly. It does not require BASIC.
+header ~monitor, ~monitor_n, "MONITOR"
	+code
	jsr JSRFAR
	!word $C000
	!byte $05				; BANK_MONITOR
	jmp next

; EDIT ( c-addr u -- )   launch the X16 full-screen text editor on the named file
; (u = 0 opens a new empty buffer). Edit, save (Ctrl+S), and quit (Ctrl+Q) to
; return to Forth; then INCLUDE the file to compile it.
; The editor uses Forth's zero page ($22-$7F), so we save and restore it around
; the call. It keeps its document in RAM banks 10+ and its code in golden RAM
; and the top (unused) part of the token table, leaving Forth's state intact.
+header ~edit, ~edit_n, "EDIT"
	+code
	lda _dtop			; filename length -> r1L
	sta $04
	ldy #2
	lda (_dstack),y		; filename address -> r0
	sta $02
	ldy #3
	lda (_dstack),y
	sta $03
	ldx #0				; save Forth zero page $22-$7F (94 bytes)
edit_save:
	lda $22,x
	sta edit_zpsave,x
	inx
	cpx #$5e
	bne edit_save
	ldx #10				; first RAM bank for the editor
	ldy #255			; last RAM bank
	lda #0
	sta $05				; auto-indent (default)
	sta $06				; tab width
	sta $07				; word wrap
	sta $09				; colours (defaults)
	sta $0a
	sta $0b
	lda #8
	sta $08				; device number
	jsr JSRFAR
	!word $C006			; main_loadfile_with_options_entry
	!byte $0D			; BANK_X16EDIT
	ldx #0				; restore Forth zero page
edit_restore:
	lda edit_zpsave,x
	sta $22,x
	inx
	cpx #$5e
	bne edit_restore
	; Fully re-initialize the console after x16edit, since it leaves both the
	; screen-editor state and the I/O channels in a way that breaks Forth's first
	; operation afterward (first RETURN swallowed; immediate file OPEN fails).
	; CINT rebuilds the whole screen editor (screen, cursor, line-link table,
	; mode flags, dimensions); CLRCHN restores default keyboard-in / screen-out;
	; then flush the KERNAL keyboard buffer and clear stuck modifier/dead-key state.
	lda #0
	sta $00				; reselect RAM bank 0 (editor leaves the bank register at 10)
	jsr $FF81			; CINT / SCINIT: full screen-editor re-initialization
	jsr CLRCHN			; restore default I/O channels (editor left them redirected)
	lda #0
	sta $A80A			; ndx      = 0 : flush the KERNAL keyboard buffer
	sta $A80C			; shflag   = 0 : clear stuck Shift/Ctrl/Alt modifier state
	sta $A881			; dk_shift = 0
	sta $A882			; dk_scan  = 0 : clear pending dead-key
	+dpop
	+dpop
	jmp next
edit_zpsave:
	!fill $5e, 0

; ==============================================================================
; Memory banking / system
; ==============================================================================
i2c_read_byte  = $FEC6
i2c_write_byte = $FEC9
keymap         = $FED2
!if X16ROM = 0 {
RDTIM          = $FFDE			; ROM build defines RDTIM as a RAM bridge trampoline
}
SMC_I2C_ADDR   = $42

; SETBANK ( bank -- )   select the RAM bank visible at $A000-$BFFF (register $00).
; (The ROM bank is deliberately not exposed: Forth needs ROM bank 0 for KERNAL.)
+header ~setbank, ~setbank_n, "SETBANK"
	+forth
	+token zero, cpoke, exit

; B@ ( bank off -- byte )   read a byte from banked RAM (off is 0..8191 into $A000)
+header ~bfetch, ~bfetch_n, "B@"
	+code
	ldy #2
	lda (_dstack),y		; bank
	sta $00				; select RAM bank
	lda _dtop			; off low -> pointer
	sta $02
	lda _dtop+1
	clc
	adc #$A0			; window base $A000
	sta $03
	ldy #0
	lda ($02),y			; the byte
	pha
	+dpop				; drop off; _dtop is now the bank slot
	pla
	sta _dtop			; result
	lda #0
	sta _dtop+1
	jmp next

; B! ( byte bank off -- )   store a byte into banked RAM (off is 0..8191)
+header ~bstore, ~bstore_n, "B!"
	+code
	ldy #2
	lda (_dstack),y		; bank
	sta $00
	lda _dtop			; off low -> pointer
	sta $02
	lda _dtop+1
	clc
	adc #$A0
	sta $03
	ldy #4
	lda (_dstack),y		; byte
	ldy #0
	sta ($02),y
	+dpop
	+dpop
	+dpop
	jmp next

; I2CPOKE ( device register value -- )   write a byte to an I2C register
+header ~i2cpoke, ~i2cpoke_n, "I2CPOKE"
	+code
	ldy #4
	lda (_dstack),y		; device
	tax
	ldy #2
	lda (_dstack),y		; register
	tay
	lda _dtop			; value
	jsr i2c_write_byte
	+dpop
	+dpop
	+dpop
	jmp next

; I2CPEEK ( device register -- value )   read a byte from an I2C register
+header ~i2cpeek, ~i2cpeek_n, "I2CPEEK"
	+code
	ldy #2
	lda (_dstack),y		; device
	tax
	lda _dtop			; register
	tay
	jsr i2c_read_byte	; A = value
	+dpop				; drop register; _dtop now holds device
	sta _dtop			; overwrite with the result
	lda #0
	sta _dtop+1
	jmp next

; SLEEP ( jiffies -- )   wait 'jiffies' 1/60-second ticks
+header ~sleep, ~sleep_n, "SLEEP"
	+code
	jsr RDTIM			; A=msb, X=mid, Y=lsb
	sty $02				; start low
	stx $03				; start high
sleep_loop:
	jsr RDTIM
	tya
	sec
	sbc $02
	sta $04				; elapsed low
	txa
	sbc $03
	sta $05				; elapsed high
	lda $04				; elapsed - jiffies >= 0 ?
	cmp _dtop
	lda $05
	sbc _dtop+1
	bcc sleep_loop		; elapsed < jiffies, keep waiting
	+dpop
	jmp next

; RESET ( -- )   hardware reset via the SMC
+header ~reset, ~reset_n, "RESET"
	+code
	lda #0
	ldx #SMC_I2C_ADDR
	ldy #2				; SMC register 2 = reset
	jsr i2c_write_byte
	jmp next

; POWEROFF ( -- )   power off via the SMC
+header ~poweroff, ~poweroff_n, "POWEROFF"
	+code
	lda #0
	ldx #SMC_I2C_ADDR
	ldy #1				; SMC register 1 = power off
	jsr i2c_write_byte
	jmp next

; REBOOT ( -- )   soft reboot through the reset vector
+header ~reboot, ~reboot_n, "REBOOT"
	+code
	lda #0
	sta $01				; ROM bank 0 (KERNAL)
	jmp ($fffc)			; reset vector

; KEYMAP ( c-addr u -- )   set the keyboard layout by name, e.g. S" en-us" KEYMAP
+header ~xkeymap, ~xkeymap_n, "KEYMAP"
	+code
	jsr pop_dstack		; u (length)
	sta $02
	jsr pop_dstack		; c-addr -> source pointer
	sta _wscratch
	stx _wscratch+1
	ldy #0
km_copy:
	cpy $02
	beq km_done
	lda (_wscratch),y
	sta _fnamebuf,y
	iny
	bne km_copy
km_done:
	lda #0
	sta _fnamebuf,y		; zero-terminate the name
	ldx #<_fnamebuf
	ldy #>_fnamebuf
	clc					; carry clear = set the keymap
	jsr keymap
	jmp next

; ==============================================================================
; Floating point - proof of concept (calls the BASIC ROM FP package in bank 4).
; The X16 keeps FAC/ARG and FP temporaries in $A9-$D2, clear of Forth's $22-$7F,
; so the ROM math routines can be called safely via jsrfar.
; ==============================================================================
; Call a routine in the BASIC ROM (bank 4). A/X/Y and result registers pass through.
!macro basiccall .addr {
	jsr JSRFAR
	!word .addr
	!byte $04			; BANK_BASIC
}

; BASIC ROM FP routine addresses (bank 4)
FP_movfm  = $F0BD		; mem -> FAC     (A=lo, Y=hi of source)
FP_movmf  = $F0EC		; FAC -> mem     (X=lo, Y=hi of dest)
FP_givayf = $F511		; signed int (A=hi, Y=lo) -> FAC
FP_getadr = $F51A		; FAC -> unsigned int (A=hi, Y=lo)
FP_fadd   = $F66F		; FAC = FAC + (mem)
FP_fsub   = $EE47		; FAC = (mem) - FAC
FP_fmult  = $F7DE		; FAC = FAC * (mem)
FP_fdiv   = $F028		; FAC = (mem) / FAC
FP_sqr    = $F9F5		; FAC = sqrt(FAC)
FP_fout   = $F234		; FAC -> null-terminated string (A=lo, Y=hi)
FP_sin    = $F557
FP_cos    = $F550
FP_tan    = $F5A2
FP_atn    = $F5FE
FP_log    = $EF7A		; natural log
FP_exp    = $F403

; The float-stack pointer (fsp) points at the top 5-byte float; the stack grows
; downward from FSTACK_TOP. It now lives in a RAM hmbuffer (declared in
; fthtx16.asm) instead of an inline !byte here - the inline version is read-only
; in the ROM (bank-9) build, which left fsp = $0000 so FP wrote over the bank
; registers. Set at cold start.

; --- helper subroutines (not Forth words) ------------------------------------

fsp5_to_02:				; $02/$03 = fsp + 5 (address of the second float)
	clc
	lda fsp
	adc #5
	sta $02
	lda fsp+1
	adc #0
	sta $03
	rts

fac_top:				; FAC = the top float
	lda fsp
	ldy fsp+1
	+basiccall FP_movfm
	rts

fac_deep:				; FAC = the second float
	jsr fsp5_to_02
	lda $02
	ldy $03
	+basiccall FP_movfm
	rts

fbin_store:				; drop 2 floats, push FAC as the result
	clc
	lda fsp
	adc #5
	sta fsp
	lda fsp+1
	adc #0
	sta fsp+1
	ldx fsp
	ldy fsp+1
	+basiccall FP_movmf
	rts

fstore_top:				; overwrite the top float with FAC (unary result)
	ldx fsp
	ldy fsp+1
	+basiccall FP_movmf
	rts

fpush_fac:				; push FAC as a new top float
	sec
	lda fsp
	sbc #5
	sta fsp
	lda fsp+1
	sbc #0
	sta fsp+1
	ldx fsp
	ldy fsp+1
	+basiccall FP_movmf
	rts

; --- words -------------------------------------------------------------------

; S>F ( n -- ) ( F: -- r )   convert a signed single to a float
+header ~stof, ~stof_n, "S>F"
	+code
	lda _dtop+1			; n high
	ldy _dtop			; n low
	+basiccall FP_givayf
	+dpop
	jsr fpush_fac
	jmp next

; F>S ( -- n ) ( F: r -- )   convert a non-negative float to a single
+header ~ftos, ~ftos_n, "F>S"
	+code
	jsr fac_top
	clc					; pop the float
	lda fsp
	adc #5
	sta fsp
	lda fsp+1
	adc #0
	sta fsp+1
	+basiccall FP_getadr	; A=high, Y=low
	sty _scratch
	tax					; X = high
	lda _scratch		; A = low
	jmp dpush_and_next

; F+ ( F: r1 r2 -- r1+r2 )
+header ~fplus, ~fplus_n, "F+"
	+code
	jsr fac_deep
	lda fsp
	ldy fsp+1
	+basiccall FP_fadd
	jsr fbin_store
	jmp next

; F- ( F: r1 r2 -- r1-r2 )
+header ~fminus, ~fminus_n, "F-"
	+code
	jsr fac_top
	jsr fsp5_to_02
	lda $02
	ldy $03
	+basiccall FP_fsub	; (mem=r1) - (FAC=r2)
	jsr fbin_store
	jmp next

; F* ( F: r1 r2 -- r1*r2 )
+header ~fstar, ~fstar_n, "F*"
	+code
	jsr fac_deep
	lda fsp
	ldy fsp+1
	+basiccall FP_fmult
	jsr fbin_store
	jmp next

; F/ ( F: r1 r2 -- r1/r2 )
+header ~fslash, ~fslash_n, "F/"
	+code
	jsr fac_top
	jsr fsp5_to_02
	lda $02
	ldy $03
	+basiccall FP_fdiv	; (mem=r1) / (FAC=r2)
	jsr fbin_store
	jmp next

; FSQRT ( F: r -- sqrt )
+header ~fsqrt, ~fsqrt_n, "FSQRT"
	+code
	jsr fac_top
	+basiccall FP_sqr
	jsr fstore_top
	jmp next

; FNEGATE ( F: r -- -r )   flips the sign bit of the packed float
+header ~fnegate, ~fnegate_n, "FNEGATE"
	+code
	lda fsp
	sta $02
	lda fsp+1
	sta $03
	ldy #1
	lda ($02),y
	eor #$80
	sta ($02),y
	jmp next

; FDROP ( F: r -- )
+header ~fdrop, ~fdrop_n, "FDROP"
	+code
	clc
	lda fsp
	adc #5
	sta fsp
	lda fsp+1
	adc #0
	sta fsp+1
	jmp next

; FDUP ( F: r -- r r )
+header ~fdup, ~fdup_n, "FDUP"
	+code
	lda fsp				; src = old top
	sta $02
	lda fsp+1
	sta $03
	sec					; dst = fsp - 5 (new top)
	lda fsp
	sbc #5
	sta $04
	sta fsp
	lda fsp+1
	sbc #0
	sta $05
	sta fsp+1
	ldy #4
-	lda ($02),y
	sta ($04),y
	dey
	bpl -
	jmp next

; FSWAP ( F: r1 r2 -- r2 r1 )
+header ~fswap, ~fswap_n, "FSWAP"
	+code
	lda fsp
	sta $02
	lda fsp+1
	sta $03
	clc
	lda fsp
	adc #5
	sta $04
	lda fsp+1
	adc #0
	sta $05
	ldy #4
-	lda ($02),y
	pha
	lda ($04),y
	sta ($02),y
	pla
	sta ($04),y
	dey
	bpl -
	jmp next

; FOVER ( F: r1 r2 -- r1 r2 r1 )
+header ~fover, ~fover_n, "FOVER"
	+code
	clc					; src = second float (fsp + 5)
	lda fsp
	adc #5
	sta $02
	lda fsp+1
	adc #0
	sta $03
	sec					; dst = fsp - 5 (new top)
	lda fsp
	sbc #5
	sta $04
	sta fsp
	lda fsp+1
	sbc #0
	sta $05
	sta fsp+1
	ldy #4
-	lda ($02),y
	sta ($04),y
	dey
	bpl -
	jmp next

; F. ( F: r -- )   print the top float followed by a space
+header ~fdot, ~fdot_n, "F."
	+code
	jsr fac_top
	clc
	lda fsp
	adc #5
	sta fsp
	lda fsp+1
	adc #0
	sta fsp+1
	+basiccall FP_fout		; A=lo, Y=hi -> null-terminated string
	sta $02
	sty $03
	ldy #0
-	lda ($02),y
	beq +
	sty _scratch
	jsr CHROUT
	ldy _scratch
	iny
	bne -
+	lda #32
	jsr CHROUT
	jmp next

; FSIN ( F: r -- sin )
+header ~fsin, ~fsin_n, "FSIN"
	+code
	jsr fac_top
	+basiccall FP_sin
	jsr fstore_top
	jmp next

; FCOS ( F: r -- cos )
+header ~fcos, ~fcos_n, "FCOS"
	+code
	jsr fac_top
	+basiccall FP_cos
	jsr fstore_top
	jmp next

; FTAN ( F: r -- tan )
+header ~ftan, ~ftan_n, "FTAN"
	+code
	jsr fac_top
	+basiccall FP_tan
	jsr fstore_top
	jmp next

; FATAN ( F: r -- atan )
+header ~fatan, ~fatan_n, "FATAN"
	+code
	jsr fac_top
	+basiccall FP_atn
	jsr fstore_top
	jmp next

; FLN ( F: r -- ln )   natural logarithm
+header ~fln, ~fln_n, "FLN"
	+code
	jsr fac_top
	+basiccall FP_log
	jsr fstore_top
	jmp next

; FEXP ( F: r -- e^r )
+header ~fexp, ~fexp_n, "FEXP"
	+code
	jsr fac_top
	+basiccall FP_exp
	jsr fstore_top
	jmp next

; F! and F@ are defined in x16prims.asm (above the token boundary) so the
; baked-in toolkit word FCONSTANT can reference them by token.

; F0= ( F: r -- ) ( -- flag )   true if r = 0
+header ~fzeroeq, ~fzeroeq_n, "F0="
	+code
	lda fsp
	sta $02
	lda fsp+1
	sta $03
	clc					; pop the float
	lda fsp
	adc #5
	sta fsp
	lda fsp+1
	adc #0
	sta fsp+1
	ldy #0
	lda ($02),y			; exponent byte: 0 means the value is 0.0
	beq f0eq_t
	lda #0
	tax
	jmp dpush_and_next
f0eq_t:
	lda #$ff
	tax
	jmp dpush_and_next

; F0< ( F: r -- ) ( -- flag )   true if r < 0
+header ~fzerolt, ~fzerolt_n, "F0<"
	+code
	lda fsp
	sta $02
	lda fsp+1
	sta $03
	clc
	lda fsp
	adc #5
	sta fsp
	lda fsp+1
	adc #0
	sta fsp+1
	ldy #0
	lda ($02),y			; exponent
	beq f0lt_f			; zero -> not negative
	ldy #1
	lda ($02),y			; sign+mantissa byte; bit 7 = sign
	bpl f0lt_f
	lda #$ff
	tax
	jmp dpush_and_next
f0lt_f:
	lda #0
	tax
	jmp dpush_and_next

; F< ( F: r1 r2 -- ) ( -- flag )   true if r1 < r2
+header ~flt, ~flt_n, "F<"
	+code
	jsr fac_top			; FAC = r2
	jsr fsp5_to_02
	lda $02
	ldy $03
	+basiccall FP_fsub	; FAC = r1 - r2
	clc					; pop both floats
	lda fsp
	adc #10
	sta fsp
	lda fsp+1
	adc #0
	sta fsp+1
	lda $C3				; FAC exponent (facexp): 0 => result is 0
	beq flt_f
	lda $C8				; FAC sign (facsgn); bit 7 set => negative
	bmi flt_t
flt_f:
	lda #0
	tax
	jmp dpush_and_next
flt_t:
	lda #$ff
	tax
	jmp dpush_and_next

; ISQRT ( n -- m )   integer square root via the ROM FP unit
+header ~isqrt, ~isqrt_n, "ISQRT"
	+code
	lda _dtop+1
	ldy _dtop
	+basiccall FP_givayf
	+basiccall FP_sqr
	+basiccall FP_getadr
	sta _dtop+1
	sty _dtop
	jmp next

; ============================================================================
; VERA layer-1 hardware scroll (the default text/tile layer). SCROLLX/SCROLLY
; set the 12-bit horizontal / vertical scroll offset of layer 1, shifting the
; whole displayed screen. Values wrap modulo the tile-map size.
; ============================================================================

VERA_L1_HSCROLL_L = $9F37
VERA_L1_HSCROLL_H = $9F38		; only low 4 bits are used
VERA_L1_VSCROLL_L = $9F39
VERA_L1_VSCROLL_H = $9F3A		; only low 4 bits are used

; SCROLLX ( n -- )   set layer-1 horizontal scroll (0..4095)
+header ~scrollx, ~scrollx_n, "SCROLLX"
	+code
	lda _dtop
	sta VERA_L1_HSCROLL_L
	lda _dtop+1
	and #$0f
	sta VERA_L1_HSCROLL_H
	+dpop
	jmp next

; SCROLLY ( n -- )   set layer-1 vertical scroll (0..4095)
+header ~scrolly, ~scrolly_n, "SCROLLY"
	+code
	lda _dtop
	sta VERA_L1_VSCROLL_L
	lda _dtop+1
	and #$0f
	sta VERA_L1_VSCROLL_H
	+dpop
	jmp next

; ============================================================================
; IRQ callback: run a Forth word from the 60 Hz VSYNC interrupt.
;   xt IRQ   arm  - the word (given as an execution token from ') is called
;                   once per frame in interrupt context.
;   0  IRQ   disarm - remove the handler.
; The callback must be short and stack-neutral ( -- ). It runs with the
; interpreter's VM registers and stacks saved and restored around it, so it
; cannot corrupt the interrupted foreground Forth code.
;
; Implementation notes:
; - We hook CINV ($0314), the KERNAL RAM IRQ vector (A/X/Y are already saved
;   by the KERNAL at this point), and chain to the original handler afterwards.
; - The callback is dispatched through the normal token machinery (invokeax),
;   after pushing "call-1" exactly like cold start so colon words route through
;   CALL, and with _ri pointing at a one-token list that runs the hidden
;   IRQPAUSE word when the callback returns.
; - IRQPAUSE restores the 6502 stack pointer (captured on entry) which cleanly
;   absorbs the call/rts bookkeeping regardless of whether the callback was a
;   colon or a code word, then restores the VM state and chains.
; ============================================================================

CINV = $0314		; KERNAL RAM IRQ vector
!if X16ROM {
; Run-from-ROM: the KERNAL's jmp (CINV) fires with ROM bank 0 selected, so CINV
; cannot point straight at irq_handler (that address is KERNAL ROM in bank 0).
; It points at the RAM trampoline bridge_irq, which crosses to the Forth bank,
; calls irq_handler (which rts's back), restores the bank, and chains.
IRQ_VECTOR = bridge_irq
} else {
IRQ_VECTOR = irq_handler
}

; IRQ ( xt -- )   arm (xt<>0) or disarm (xt=0) the per-frame Forth callback
+header ~irq, ~irq_n, "IRQ"
	+code
	lda _dtop
	ora _dtop+1
	bne irq_arm

	; --- disarm: restore the original vector if we installed ours ---
	lda irq_armed
	beq irq_ret
	sei
	lda irq_chain
	sta CINV
	lda irq_chain+1
	sta CINV+1
	lda #0
	sta irq_armed
	cli
irq_ret:
	+dpop
	jmp next

irq_arm:
	; store the callback token
	lda _dtop
	sta irq_cb_token
	lda _dtop+1
	sta irq_cb_token+1
	; install our handler once (leave it chained while armed)
	lda irq_armed
	bne irq_arm_done
	sei
	lda #0
	sta irq_busy
	lda CINV
	sta irq_chain
	lda CINV+1
	sta irq_chain+1
	lda #<IRQ_VECTOR
	sta CINV
	lda #>IRQ_VECTOR
	sta CINV+1
	cli
irq_arm_done:
	lda #1
	sta irq_armed
	+dpop
	jmp next

; The interrupt handler, reached via jmp (CINV) from the KERNAL.
irq_handler:
	lda irq_armed
	beq irq_chainj
	lda irq_busy			; do not re-enter if a callback is still running
	bne irq_chainj
	inc irq_busy

	tsx					; remember the stack pointer for a clean return
	stx irq_saved_sp
	jsr irq_savevm			; save the foreground VM state

	lda _stopcheck			; suppress CALL's STOP-key check inside the callback:
	sta irq_save_sc			; running the KERNAL STOP / ABORT from the IRQ would
	lda #0				; corrupt everything. (Callbacks must be short anyway.)
	sta _stopcheck

	lda #<IRQ_RSTACK_TOP		; run the callback on its own stacks so it cannot
	sta _rstack			; corrupt a half-finished foreground stack operation
	lda #>IRQ_RSTACK_TOP
	sta _rstack+1
	lda #<IRQ_DSTACK_TOP
	sta _dstack
	lda #>IRQ_DSTACK_TOP
	sta _dstack+1
	lda #0
	sta _dtop
	sta _dtop+1

	lda #<irqpause_list		; when the callback returns, run IRQPAUSE
	sta _ri
	lda #>irqpause_list
	sta _ri+1

	lda #>call-1			; harness so colon callbacks route through CALL
	pha
	lda #<call-1
	pha

	lda irq_cb_token		; dispatch the callback by token
	ldx irq_cb_token+1
	jmp invokeax

irq_chainj:
!if X16ROM {
	rts				; return to bridge_irq (restores bank, then chains)
} else {
	jmp (irq_chain)
}

; Tail of the interrupt: restore everything and chain. Entered as the hidden
; IRQPAUSE word once the callback has run to completion.
irqpause_impl:
	ldx irq_saved_sp		; discard callback's call/rts leftovers
	txs
	jsr irq_restorevm
	lda irq_save_sc			; restore the foreground STOP-key counter
	sta _stopcheck
	lda #0
	sta irq_busy
!if X16ROM {
	rts				; SP was restored above via txs; return to bridge_irq
} else {
	jmp (irq_chain)
}

irqpause_list:
	!byte irqpause			; one-token list: the hidden IRQPAUSE word

; Save/restore the contiguous VM zero-page registers (_ri.._scratch_2 = 20
; bytes) plus the float-stack pointer.
irq_savevm:
	ldx #19
-	lda _ri,x
	sta irq_save,x
	dex
	bpl -
	lda fsp
	sta irq_save_fsp
	lda fsp+1
	sta irq_save_fsp+1
	rts

irq_restorevm:
	ldx #19
-	lda irq_save,x
	sta _ri,x
	dex
	bpl -
	lda irq_save_fsp
	sta fsp
	lda irq_save_fsp+1
	sta fsp+1
	rts

; ============================================================================
; Game-support primitives (fast paths for 2D games).
; ============================================================================

; VSYNC ( -- )   wait for the next video frame. Spins until the KERNAL 60 Hz
; jiffy timer (read via RDTIM) advances - the jiffy is bumped once per VSYNC
; IRQ, so this returns at the start of the next frame. Use it to pace a game
; loop and to update VRAM tear-free. (RDTIM is bridged in the ROM build.)
; Install the frame-tick IRQ stub into RAM and hook CINV, once. A 6-byte stub
; (frame_isr) bumps frame_tick every VSYNC IRQ and chains to the previous
; handler; it is pure RAM (increment + indirect jump) so it also works from the
; ROM bank - no bank switch. Shared by VSYNC and FRAMES.
vsync_arm:
	lda CINV+1			; already installed?  (CINV == frame_isr)
	cmp #>frame_isr
	bne varm_do
	lda CINV
	cmp #<frame_isr
	beq varm_ok
varm_do:
	ldx #5				; copy the stub template into RAM
varm_cp:
	lda frame_isr_tmpl,x
	sta frame_isr,x
	dex
	bpl varm_cp
	sei
	lda CINV			; save the current vector to chain to
	sta frame_chain
	lda CINV+1
	sta frame_chain+1
	lda #<frame_isr			; point CINV at our RAM stub
	sta CINV
	lda #>frame_isr
	sta CINV+1
	cli
varm_ok:
	rts

; VSYNC ( -- )   wait for exactly one video frame (frame-locked 60 Hz).
+header ~vsync, ~vsync_n, "VSYNC"
	+code
	jsr vsync_arm
	lda frame_tick
vsync_w2:
	cmp frame_tick			; spin until the IRQ bumps the tick
	beq vsync_w2
	jmp next

; FRAMES ( -- n )   the frame counter (0..255), bumped once per video frame.
; Take deltas (byte subtraction wraps correctly) for elapsed-frame timing,
; fixed-timestep catch-up, or an FPS/dropped-frame check.
+header ~frames, ~frames_n, "FRAMES"
	+code
	jsr vsync_arm
	lda frame_tick
	ldx #0
	jmp dpush_and_next

; Template for frame_isr, copied to RAM (above). Position-independent: it only
; touches the fixed RAM addresses frame_tick and frame_chain.
frame_isr_tmpl:
	inc frame_tick
	jmp (frame_chain)

; VFILL ( value count -- )   write the byte 'value' to the VERA data port
; 'count' times (count is 16-bit). Set the start address first with VADDR; the
; port auto-increments, so this fills 'count' consecutive VRAM bytes in a tight
; native loop - far faster than a Forth V! loop for clearing bitmaps/tilemaps.
+header ~vfill, ~vfill_n, "VFILL"
	+code
	+ldax _dtop			; count -> _rscratch
	+stax _rscratch
	ldy #2
	lda (_dstack),y			; value (low byte) -> X
	tax
vfill_lp:
	lda _rscratch
	ora _rscratch+1
	beq vfill_dn
	stx VERA_DATA0
	lda _rscratch
	bne vfill_nb
	dec _rscratch+1
vfill_nb:
	dec _rscratch
	jmp vfill_lp
vfill_dn:
	+dpop				; drop count
	+dpop				; drop value
	jmp next

; *. ( n1 n2 -- n3 )   signed 8.8 fixed-point multiply: n3 = (n1*n2) >> 8.
; Lets you move sprites at fractional speeds. n1,n2 and n3 are 8.8 (8 integer
; bits, 8 fraction bits) held in one cell. Takes bits 8..23 of the 32-bit
; product (M* gives the full signed product; the shift/OR extracts the middle).
+header ~fixmul, ~fixmul_n, "*."
	+forth
	+token mmult
	+literal 8
	+token lshift, swap
	+literal 8
	+token rshift, or, exit

; COLLIDE? ( ax ay aw ah bx by bw bh -- flag )
; Axis-aligned bounding-box overlap test for two boxes (x,y = top-left,
; w,h = size). Returns TRUE if they overlap, else FALSE. Coordinates are
; compared unsigned (screen/sprite coordinates are non-negative). Boxes that
; only touch at an edge do NOT count as overlapping. Stack items (16-bit) are
; read in place: bh=_dtop, and below it at (_dstack)+2,+4,... bw by bx ah aw ay ax.
+header ~collide, ~collide_n, "COLLIDE?"
	+code
	clc				; t = bx + bw
	ldy #6
	lda (_dstack),y			; bx lo
	ldy #2
	adc (_dstack),y			; + bw lo
	sta _scratch
	ldy #7
	lda (_dstack),y			; bx hi
	ldy #3
	adc (_dstack),y			; + bw hi
	sta _scratch+1
	ldy #14				; ax < bx+bw ?
	lda (_dstack),y
	cmp _scratch
	ldy #15
	lda (_dstack),y
	sbc _scratch+1
	bcs collide_no
	clc				; t = ax + aw
	ldy #14
	lda (_dstack),y
	ldy #10
	adc (_dstack),y
	sta _scratch
	ldy #15
	lda (_dstack),y
	ldy #11
	adc (_dstack),y
	sta _scratch+1
	ldy #6				; bx < ax+aw ?
	lda (_dstack),y
	cmp _scratch
	ldy #7
	lda (_dstack),y
	sbc _scratch+1
	bcs collide_no
	clc				; t = by + bh   (bh = _dtop)
	ldy #4
	lda (_dstack),y			; by lo
	adc _dtop
	sta _scratch
	ldy #5
	lda (_dstack),y			; by hi
	adc _dtop+1
	sta _scratch+1
	ldy #12				; ay < by+bh ?
	lda (_dstack),y
	cmp _scratch
	ldy #13
	lda (_dstack),y
	sbc _scratch+1
	bcs collide_no
	clc				; t = ay + ah
	ldy #12
	lda (_dstack),y
	ldy #8
	adc (_dstack),y
	sta _scratch
	ldy #13
	lda (_dstack),y
	ldy #9
	adc (_dstack),y
	sta _scratch+1
	ldy #4				; by < ay+ah ?
	lda (_dstack),y
	cmp _scratch
	ldy #5
	lda (_dstack),y
	sbc _scratch+1
	bcs collide_no
	lda #$ff			; all four overlap conditions hold
	bne collide_set
collide_no:
	lda #0
collide_set:
	sta _scratch			; save flag; collapse 8 stack cells to 1
	jsr pop_dstack
	jsr pop_dstack
	jsr pop_dstack
	jsr pop_dstack
	jsr pop_dstack
	jsr pop_dstack
	jsr pop_dstack
	lda _scratch
	sta _dtop
	sta _dtop+1
	jmp next

; ============================================================================
; Baked-in toolkit words (formerly the X16BASIC.FTH / X16STR.FTH / X16FP.FTH
; INCLUDE files). Kept here in x16.asm so they compile into the X16 image and
; are available without a disk INCLUDE. They sit below the token boundary
; (leaf words), so they reference only words defined above the boundary; where
; a needed helper lives below the boundary (MIN, /STRING) its body is inlined,
; and PAD is reached via its buffer address _pad.
; ============================================================================

; --- X16BASIC.FTH : BASIC-style aliases ------------------------------------

; OPEN ( c-addr u fam -- fileid ior )
+header ~open, ~open_n, "OPEN"
	+forth
	+token openfile, exit

; CLOSE ( fileid -- ior )
+header ~close, ~close_n, "CLOSE"
	+forth
	+token closefile, exit

; LINPUT ( c-addr +n -- +n2 )   read a line from the keyboard
+header ~linput, ~linput_n, "LINPUT"
	+forth
	+token accept, exit

; BASIC floating-point function names ( F: r -- f(r) ). Each duplicates the
; corresponding FP word's body rather than adding a code label to it.

; SQR ( F: r -- sqrt )
+header ~sqr, ~sqr_n, "SQR"
	+code
	jsr fac_top
	+basiccall FP_sqr
	jsr fstore_top
	jmp next

; SIN ( F: r -- sin )
+header ~sin, ~sin_n, "SIN"
	+code
	jsr fac_top
	+basiccall FP_sin
	jsr fstore_top
	jmp next

; COS ( F: r -- cos )
+header ~cos, ~cos_n, "COS"
	+code
	jsr fac_top
	+basiccall FP_cos
	jsr fstore_top
	jmp next

; TAN ( F: r -- tan )
+header ~tan, ~tan_n, "TAN"
	+code
	jsr fac_top
	+basiccall FP_tan
	jsr fstore_top
	jmp next

; ATN ( F: r -- atan )
+header ~atn, ~atn_n, "ATN"
	+code
	jsr fac_top
	+basiccall FP_atn
	jsr fstore_top
	jmp next

; LOG ( F: r -- ln )
+header ~log, ~log_n, "LOG"
	+code
	jsr fac_top
	+basiccall FP_log
	jsr fstore_top
	jmp next

; EXP ( F: r -- e^r )
+header ~exp, ~exp_n, "EXP"
	+code
	jsr fac_top
	+basiccall FP_exp
	jsr fstore_top
	jmp next

; --- X16STR.FTH : BASIC string / number-conversion words -------------------

; HEX$ ( u -- c-addr u )   unsigned number as hex digits
+header ~hexstr, ~hexstr_n, "HEX$"
	+forth
	+token base, peek, tor, hex, zero, bhash, hashs
	+token hashb, rfrom, base, poke, exit

; BIN$ ( u -- c-addr u )   unsigned number as binary digits
+header ~binstr, ~binstr_n, "BIN$"
	+forth
	+token base, peek, tor
	+literal 2
	+token base, poke, zero, bhash, hashs, hashb
	+token rfrom, base, poke, exit

; STR$ ( n -- c-addr u )   signed number as a string (current base)
+header ~strstr, ~strstr_n, "STR$"
	+forth
	+token dup, abs, zero, bhash, hashs, rot, sign
	+token hashb, exit

; VAL ( c-addr u -- n )   string to number (unsigned, current base)
+header ~valstr, ~valstr_n, "VAL"
	+forth
	+token zero, zero, twoswap, tonumber, twodrop, drop, exit

; ASC ( c-addr u -- code )   code of the first character
+header ~ascstr, ~ascstr_n, "ASC"
	+forth
	+token drop, cpeek, exit

; CHR$ ( code -- c-addr 1 )   one-character string (in PAD)
+header ~chrstr, ~chrstr_n, "CHR$"
	+forth
	+literal _pad
	+token cpoke
	+literal _pad
	+token one, exit

; LEN ( c-addr u -- u )   string length
+header ~lenstr, ~lenstr_n, "LEN"
	+forth
	+token nip, exit

; LEFT$ ( c-addr u n -- c-addr n2 )   first n characters (n2 = MIN(u,n))
+header ~leftstr, ~leftstr_n, "LEFT$"
	+forth
	+token twodup, greater		; inline MIN
	+qbranch_fwd leftstr_1
	+token swap
leftstr_1:
	+token drop, exit

; RIGHT$ ( c-addr u n -- c-addr2 n2 )   last n characters
+header ~rightstr, ~rightstr_n, "RIGHT$"
	+forth
	+token over
	+token twodup, greater		; inline MIN
	+qbranch_fwd rightstr_1
	+token swap
rightstr_1:
	+token drop
	+token tor, rat, sub, add, rfrom, exit

; MID$ ( c-addr u start len -- c-addr2 len2 )   substring, start is 1-based
+header ~midstr, ~midstr_n, "MID$"
	+forth
	+token tor, oneminus
	+token rot, over, add, rot, rot, sub	; inline /STRING
	+token rfrom
	+token twodup, greater		; inline MIN
	+qbranch_fwd midstr_1
	+token swap
midstr_1:
	+token drop, exit

; RPT$ ( char n -- c-addr u )   char repeated n times (in PAD)
+header ~rptstr, ~rptstr_n, "RPT$"
	+forth
	+token tor
	+literal _pad
	+token rat, rot, fill
	+literal _pad
	+token rfrom, exit

; --- X16FP.FTH : Forth-2012 floating-point defining words ------------------

; FVARIABLE name   -- creates a word returning the address of 5 float bytes
+header ~fvariable, ~fvariable_n, "FVARIABLE"
	+forth
	+token create
	+literal 5
	+token allot, exit

; FCONSTANT name ( F: r -- )   creates a word that pushes the float r
+header ~fconstant, ~fconstant_n, "FCONSTANT"
	+forth
	+token create, here, fstoremem
	+literal 5
	+token allot, xcode
	!byte JSR_INSTR
	+address does
	+token ffetchmem, exit

; ============================================================================
; Bit / byte manipulation words. (LSHIFT and RSHIFT already exist in the core.)
; Native code, self-contained leaf words.
; ============================================================================

; SPLIT ( n -- bh bl )   split a cell into its high and low bytes
+header ~split, ~split_n, "SPLIT"
	+code
	lda _dtop			; bl = low byte
	pha
	lda _dtop+1			; bh = high byte
	sta _dtop
	lda #0
	sta _dtop+1			; _dtop = bh (as a cell)
	pla				; a = bl
	ldx #0
	jmp dpush_and_next		; push bh, leave bl on top

; CATNIB ( nh nl -- byte )   concatenate two nibbles: byte = (nh<<4) | nl
+header ~catnib, ~catnib_n, "CATNIB"
	+code
	+dpop				; a = nl, _dtop = nh
	and #$0f
	sta _scratch			; low nibble
	lda _dtop
	and #$0f
	asl
	asl
	asl
	asl
	ora _scratch
	sta _dtop
	lda #0
	sta _dtop+1
	jmp next

; SBIT ( addr mask -- )   set the masked bits of the byte at addr
+header ~sbit, ~sbit_n, "SBIT"
	+code
	+dpop				; a = mask, _dtop = addr
	ldy #0
	ora (_dtop),y
	sta (_dtop),y
	+dpop				; drop addr
	jmp next

; CBIT ( addr mask -- )   clear the masked bits of the byte at addr
+header ~cbit, ~cbit_n, "CBIT"
	+code
	+dpop				; a = mask, _dtop = addr
	eor #$ff			; ~mask
	ldy #0
	and (_dtop),y
	sta (_dtop),y
	+dpop				; drop addr
	jmp next

; FBIT ( flag addr mask -- )   set the masked bits if flag is true, else clear
+header ~fbit, ~fbit_n, "FBIT"
	+code
	lda _dtop			; mask (byte op: low byte only)
	sta _scratch
	ldy #2				; addr = 2nd stack cell
	lda (_dstack),y
	sta _wscratch
	iny
	lda (_dstack),y
	sta _wscratch+1
	ldy #4				; flag = 3rd stack cell
	lda (_dstack),y
	iny
	ora (_dstack),y
	beq fbit_clear
	ldy #0				; flag true -> set
	lda _scratch
	ora (_wscratch),y
	sta (_wscratch),y
	jmp fbit_done
fbit_clear:				; flag false -> clear
	ldy #0
	lda _scratch
	eor #$ff
	and (_wscratch),y
	sta (_wscratch),y
fbit_done:
	+dpop				; drop mask, addr, flag
	+dpop
	+dpop
	jmp next
