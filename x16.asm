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

; SPRITE-GET ( sprite -- x y )   read a sprite's 12-bit X and Y position (inverse
; of SPRITE-POS). Reads attr bytes 2-5 back through the auto-incrementing data port.
+header ~getspr, ~getspr_n, "SPRITE-GET"
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

; SPRITE-MOV ( num x y -- )   ( = BASIC: MOVSPR num,x,y )   set sprite position
+header ~movspr, ~movspr_n, "SPRITE-MOV"
	+forth
	+token rot							; ( x y num )
	+literal 8
	+token mult
	+token lit
	+value VRAM_SPRITES+2
	+token add, one, swap, vaddr		; VERA -> attr byte 2 (X)
	+token swap, vwstore, vwstore, exit	; write X then Y

; SPRITE-MEM ( num bank addr -- )   ( = BASIC: SPRMEM num,bank,addr )
; Point sprite's image at VRAM (bank:addr), 4bpp. addr should be 32-aligned.
+header ~sprmem, ~sprmem_n, "SPRITE-MEM"
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
	clc				; C clear = retrigger (re-attack) the note, like BASIC
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
; Save the compiled dictionary once, reload it in ~1s instead of recompiling the
; source. A base name is given on the stack ( c-addr u -- ); three files are
; written/read using it, e.g.  S" JYV" SAVE-IMAGE  ->  JYV.DIC JYV.TOK JYV.VAR :
;   <name>.DIC = dictionary bytes   [dict-start .. HERE)
;   <name>.TOK = user token table   [core+1 .. hightoken)  (core tokens already valid)
;   <name>.VAR = dictionary-state zero-page block (HERE/LATEST/HIGHTOKEN/wordlists)
; LOAD-IMAGE is native so it can overwrite the dictionary safely (the core, from
; which it runs, lives below the dictionary).  Works in every build (PRG, C64 cart,
; and the bank-9 ROM): the name is copied to RAM (imgnam) and the suffix appended
; there, so the bridged KERNAL (which runs with bank 0 mapped) can read it.
; ===========================================================================
!if CART or X16ROM {
IMG_DICT_START = $0801
} else {
IMG_DICT_START = end_of_image
}
IMG_TOKUSER = TOKENS + ((forth_system + 1) << 1)
!if FPCORE = 0 {
; .VAR also carries the >FLOAT hook (tofloat_vec): FLOAT.FTH installs it, and
; a reloaded image must keep float literals alive - it lives in an hmbuffer,
; not in the saved zp block, so it needs its own slot after the per-build
; fields (the image format is tied to the exact build anyway).
!if WD_FARHDR {
IMG_TFV = 72 + WORDLISTS
} else if WIDEDICT {
IMG_TFV = 71
} else {
IMG_TFV = 61
}
}

imgsfx_dic: !text ".DIC"
imgsfx_tok: !text ".TOK"
imgsfx_var: !text ".VAR"
!if WD_FARHDR {
imgsfx_tkb: !text ".TKB"	; TOKBANK user slice (far dispatch needs it)
IMG_TOKBUSER = TOKBANK + forth_system + 1
}
!if WIDEDICT {
imgsfx_di2: !text ".DI2"	; dictionary-extension slice [$A000..HERE)
!if WD_ROMBANKS = 0 {
imgsfx_cod: !text ".C00"	; RAM code-bank slice; last 2 chars patched per bank
}
}

!if X16ROM = 0 {
!source "imgvars.asm"
}

; Copy the base name (data stack ( c-addr u )) into imgnam and remember its
; length in imgbaselen.  Reads _dtop (u = length) and NOS (c-addr = source addr);
; runs with the Forth bank mapped so the source string is readable.  The length
; is clamped to 16 (CBM filename limit; imgnam has room for 16 + a 4-char suffix).
img_setbase:
	lda _dtop
	cmp #17
	bcc isb_len
	lda #16
isb_len:
	sta imgbaselen
	ldy #2				; NOS = (_dstack),y -> source pointer
	lda (_dstack),y
	sta _scratch
	ldy #3
	lda (_dstack),y
	sta _scratch+1
	ldy #0
isb_cp:
	cpy imgbaselen
	beq isb_done
	lda (_scratch),y
	sta imgnam,y
	iny
	bne isb_cp
isb_done:
	rts

; Append the 4-char suffix at (_rscratch) to imgnam after the base name, then
; SETNAM(imgnam, imgbaselen+4).  The suffix is a code literal (ROM in the bank-9 /
; cart builds), read here with the Forth bank mapped; the KERNAL later reads the
; assembled name from RAM (imgnam), which is visible in every bank.
img_name:
	ldx imgbaselen
	ldy #0
imn_cp:	lda (_rscratch),y
	sta imgnam,x
	inx
	iny
	cpy #4
	bne imn_cp
	txa				; A = total length (base + 4)
	ldx #<imgnam
	ldy #>imgnam
	jmp SETNAM

img_name_var:				; helpers: point _rscratch at a suffix, build the name
	lda #<imgsfx_var
	sta _rscratch
	lda #>imgsfx_var
	sta _rscratch+1
	jmp img_name
img_name_dic:
	lda #<imgsfx_dic
	sta _rscratch
	lda #>imgsfx_dic
	sta _rscratch+1
	jmp img_name
img_name_tok:
	lda #<imgsfx_tok
	sta _rscratch
	lda #>imgsfx_tok
	sta _rscratch+1
	jmp img_name
!if WD_FARHDR {
img_name_tkb:
	lda #<imgsfx_tkb
	sta _rscratch
	lda #>imgsfx_tkb
	sta _rscratch+1
	jmp img_name
}
!if WIDEDICT {
img_name_di2:
	lda #<imgsfx_di2
	sta _rscratch
	lda #>imgsfx_di2
	sta _rscratch+1
	jmp img_name
}
!if WD_ROMBANKS = 0 {
; --- RAM code-bank snapshot: one <name>.Cxx file per used bank ($A000..$BF00
; through the $00 window). xx = a running hex index from the top bank down. ---
img_cod_suffix:				; A = index -> imgsfx_cod = ".Cxx"
	pha
	lda #'.'
	sta imgsfx_cod
	lda #'C'
	sta imgsfx_cod+1
	pla
	pha
	lsr
	lsr
	lsr
	lsr
	jsr img_hexdigit
	sta imgsfx_cod+2
	pla
	and #$0f
	jsr img_hexdigit
	sta imgsfx_cod+3
	rts
img_hexdigit:
	cmp #10
	bcc ihd_num
	clc
	adc #'A'-10
	rts
ihd_num:
	clc
	adc #'0'
	rts
img_name_cod:				; suffix already built in imgsfx_cod
	lda #<imgsfx_cod
	sta _rscratch
	lda #>imgsfx_cod
	sta _rscratch+1
	jmp img_name

; iterate banks _codetop..._codebank, calling (via _wscratch) KSAVE or KLOAD
; on $A000..$BF00 with the window pointed at each. _wscratch=bank, _wscratch+1=index
img_cod_setup:
	lda _codetop
	sta _wscratch
	lda #0
	sta _wscratch+1
	rts
img_cod_name:				; build the name for the current bank/index
	lda _wscratch+1
	jsr img_cod_suffix
	jmp img_name_cod
img_cod_range:				; _scratch = $A000, X/Y = $BF00 for K(SAVE/LOAD)
	lda #<$A000
	sta _scratch
	lda #>$A000
	sta _scratch+1
	rts

img_save_codebanks:
	lda _codebank
	beq iscb_done
	jsr img_cod_setup
iscb_loop:
	jsr img_cod_name
	jsr img_setlfs_save
	lda _wscratch			; window -> bank B
	sta $00
	jsr img_cod_range
	lda #<_scratch
	ldx #<$BF00
	ldy #>$BF00
	jsr KSAVE
	lda _wscratch			; B == _codebank -> done
	cmp _codebank
	beq iscb_end
	dec _wscratch
	inc _wscratch+1
	jmp iscb_loop
iscb_end:
	lda #0
	sta $00
iscb_done:
	rts

img_load_codebanks:
	lda _codebank
	beq ilcb_done
	jsr img_cod_setup
ilcb_loop:
	jsr img_cod_name
	jsr img_setlfs_load
	lda _wscratch			; window -> bank B
	sta $00
	lda #0				; load to the file-header address ($A000)
	jsr KLOAD
	lda _wscratch
	cmp _codebank
	beq ilcb_end
	dec _wscratch
	inc _wscratch+1
	jmp ilcb_loop
ilcb_end:
	lda #0
	sta $00
ilcb_done:
	rts
}

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

+header ~saveimage, ~saveimage_n, "SAVE-IMAGE"		; ( c-addr u -- )
	+code
	jsr img_setbase				; imgnam/imgbaselen = the base name
	jsr img_vars_save
	; ---- <name>.VAR : [IMGBUF .. IMGBUF+61) ----
	jsr img_name_var
	jsr img_setlfs_save
	lda #<IMGBUF
	sta _scratch
	lda #>IMGBUF
	sta _scratch+1
	lda #<_scratch
!if FPCORE = 0 {
	ldx #<(IMGBUF+IMG_TFV+2)	; per-build fields + the >FLOAT hook
	ldy #>(IMGBUF+IMG_TFV+2)
} else if WD_FARHDR {
	ldx #<(IMGBUF+72+WORDLISTS)
	ldy #>(IMGBUF+72+WORDLISTS)
} else if WIDEDICT {
	ldx #<(IMGBUF+71)
	ldy #>(IMGBUF+71)
} else {
	ldx #<(IMGBUF+61)
	ldy #>(IMGBUF+61)
}
	jsr KSAVE
	; ---- <name>.DIC : [IMG_DICT_START .. near dict end) ----
	jsr img_name_dic
	jsr img_setlfs_save
	lda #<IMG_DICT_START
	sta _scratch
	lda #>IMG_DICT_START
	sta _scratch+1
!if WIDEDICT {
	lda _dictbank		; split dictionary: the near part stops at the
	beq svi_dicnear		; recorded switch point, HERE is in the window
	lda #<_scratch
	ldx _nearhere
	ldy _nearhere+1
	jsr KSAVE
	jmp svi_dicdone
svi_dicnear:
}
	lda #<_scratch
	ldx _here
	ldy _here+1
	jsr KSAVE
!if WIDEDICT {
svi_dicdone:
}
	; ---- <name>.TOK : [IMG_TOKUSER .. TOKENS + 2*hightoken) ----
	jsr img_name_tok
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
!if WD_FARHDR {
	; ---- <name>.TKB : [IMG_TOKBUSER .. TOKBANK + hightoken + 1) - the
	; per-token bank bytes; far dispatch is dead without them ----
	jsr img_name_tkb
	jsr img_setlfs_save
	lda #<IMG_TOKBUSER
	sta _scratch
	lda #>IMG_TOKBUSER
	sta _scratch+1
	clc
	lda _hightoken
	adc #<(TOKBANK+1)
	tax
	lda _hightoken+1
	adc #>(TOKBANK+1)
	tay
	lda #<_scratch
	jsr KSAVE
}
!if WIDEDICT {
	; ---- <name>.DI2 : [FARBASE .. HERE) - only when the dictionary has
	; crossed into the extension bank (KSAVE reads it through the window,
	; which rests on FARBANK) ----
	lda _dictbank
	beq svi_nodi2
	jsr img_name_di2
	jsr img_setlfs_save
	lda #<FARBASE
	sta _scratch
	lda #>FARBASE
	sta _scratch+1
	lda #<_scratch
	ldx _here
	ldy _here+1
	jsr KSAVE
svi_nodi2:
}
!if WD_ROMBANKS = 0 {
	jsr img_save_codebanks		; RAM code banks -> <name>.Cxx files
}
	jsr CLRCHN			; restore keyboard-in/screen-out after the file writes
	+dpop				; drop ( c-addr u )
	+dpop
	jmp next

; LOAD-IMAGE ( c-addr u -- flag )   flag = -1 if the image loaded, 0 if <name>.DIC
; was missing.  c-addr/u is the base name (same as SAVE-IMAGE).
+header ~loadimage, ~loadimage_n, "LOAD-IMAGE"
	+code
	jsr img_setbase			; imgnam/imgbaselen = base name
	+dpop				; drop ( c-addr u ) - the name is copied to RAM now
	+dpop
	; <name>.DIC -> IMG_DICT_START (file header address)
	jsr img_name_dic
	jsr img_setlfs_load
	lda #0
	jsr KLOAD
	bcc li_have
	jsr CLRCHN			; no image: leave the dictionary untouched, return false
	lda #0
	tax
	jmp dpush_and_next
li_have:
	; <name>.TOK -> IMG_TOKUSER (file header address)
	jsr img_name_tok
	jsr img_setlfs_load
	lda #0
	jsr KLOAD
!if WD_FARHDR {
	; <name>.TKB -> IMG_TOKBUSER (file header address)
	jsr img_name_tkb
	jsr img_setlfs_load
	lda #0
	jsr KLOAD
}
	; <name>.VAR -> IMGBUF (file header address)
!if WIDEDICT {
	lda #0			; defaults for images saved before the .DI2
	sta IMGBUF+61		; format (61-byte .VAR): near-bank state
	sta IMGBUF+64
	sta IMGBUF+65
	sta IMGBUF+67		; +67 _codebank = 0 (no code banks)
	sta IMGBUF+70		; +70 _incode = 0
	sta _ribank
!if WD_FARHDR {
	sta IMGBUF+71		; +71.. far-header banks default to near
	ldx #WORDLISTS-1
ivd3:	sta IMGBUF+72,x
	dex
	bpl ivd3
}
	lda #<MEMTOP
	sta IMGBUF+62
	lda #>MEMTOP
	sta IMGBUF+63
}
	jsr img_name_var
	jsr img_setlfs_load
	lda #0
	jsr KLOAD
	jsr img_vars_load
!if WIDEDICT {
	; the image used the extension bank? pull the window slice back in
	lda _dictbank
	beq li_nodi2
	jsr img_name_di2
	jsr img_setlfs_load
	lda #0
	jsr KLOAD
	bcc li_nodi2
	jsr CLRCHN		; .DI2 missing: incomplete image -> false
	lda #0
	tax
	jmp dpush_and_next
li_nodi2:
}
!if WD_ROMBANKS = 0 {
	jsr img_load_codebanks		; RAM code banks <- <name>.Cxx files
}
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

; --- X16 bitmap graphics (GINIT GCLS PSET LINE FRAME RECT RING OVAL GTEXT).
; With GFXTOOLKIT=1 these move to a loadable toolkit (GFX.FTH / SPLIT.FTH),
; freeing ~513 bytes of core. VERA primitives they build on (VADDR/V!/VFILL/
; ISQRT) stay in the core, so the toolkit versions can reuse them.
!if GFXTOOLKIT = 0 {
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

; RECT ( x1 y1 x2 y2 color -- )   filled rectangle.
; Fast path: the 320x240 @ 256c bitmap (after GINIT) is a flat 320-byte-pitch,
; 8bpp buffer at VRAM $0:0000, so a fill is just, per row, "set the VERA address
; to y*320+x and stream the colour byte width times" with hardware auto-increment
; (which carries through the 17th VRAM address bit). This is dramatically faster
; than the KERNAL GRAPH_draw_rect per-pixel fill. Coordinates are normalised and
; clipped to the 320x240 screen (colour is the low byte = an 8bpp index).
+header ~rect, ~rect_n, "RECT"
	+code
	jsr pop_dstack		; colour
	sta r14L
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
	jsr g_convps		; r0=x r1=y r2=width r3=height
	; --- clip X / width to [0,320) ---
	lda r0L			; x >= 320 ($140) ?  -> nothing visible
	cmp #$40
	lda r0H
	sbc #$01
	bcc rect_xok
	jmp rect_skip
rect_xok:
	clc			; right = x + width
	lda r0L
	adc r2L
	sta _scratch
	lda r0H
	adc r2H
	sta _scratch+1
	sec			; right > 320 ?  -> width = 320 - x
	lda #$40
	sbc _scratch
	lda #$01
	sbc _scratch+1
	bcs rect_xrok
	sec
	lda #$40
	sbc r0L
	sta r2L
	lda #$01
	sbc r0H
	sta r2H
rect_xrok:
	; --- clip Y / height to [0,240) ---
	lda r1L			; y >= 240 ($F0) ?
	cmp #$f0
	lda r1H
	sbc #$00
	bcc rect_yok
	jmp rect_skip
rect_yok:
	clc			; bottom = y + height
	lda r1L
	adc r3L
	sta _scratch
	lda r1H
	adc r3H
	sta _scratch+1
	sec			; bottom > 240 ?  -> height = 240 - y
	lda #$f0
	sbc _scratch
	lda #$00
	sbc _scratch+1
	bcs rect_yrok
	sec
	lda #$f0
	sbc r1L
	sta r3L
	lda #$00
	sbc r1H
	sta r3H
rect_yrok:
	; --- offset o (r4:r5, 17-bit) = y*320 + x   (y = r1L, now < 240) ---
	lda r1L
	sta r4L
	lda #0
	sta r4H
	ldx #6			; r4 = y << 6  (y*64)
rect_m64:
	asl r4L
	rol r4H
	dex
	bne rect_m64
	clc			; o = y*64 + x
	lda r4L
	adc r0L
	sta r4L
	lda r4H
	adc r0H
	sta r4H
	lda #0
	sta _scratch_2
	clc			; o += y*256  (add y to o1, carry to o2)
	lda r4H
	adc r1L
	sta r4H
	lda _scratch_2
	adc #0
	sta _scratch_2
	; --- fill height rows ---
rect_row:
	lda r4L
	sta VERA_ADDR_L
	lda r4H
	sta VERA_ADDR_M
	lda _scratch_2
	and #1			; 17th address bit -> bank
	ora #$10		; auto-increment 1
	sta VERA_ADDR_H
	lda r14L		; colour (kept in A across the inner loop)
	ldy r2H			; width = 256*Y + X
	ldx r2L
	cpx #0
	beq rect_pages
rect_rem:
	sta VERA_DATA0
	dex
	bne rect_rem
rect_pages:
	cpy #0
	beq rect_next
rect_page:
	sta VERA_DATA0
	dex
	bne rect_page
	dey
	bne rect_pages
rect_next:
	clc			; o += 320
	lda r4L
	adc #$40
	sta r4L
	lda r4H
	adc #$01
	sta r4H
	lda _scratch_2
	adc #0
	sta _scratch_2
	dec r3L			; height-- (<= 240, so the byte counter suffices)
	bne rect_row
rect_skip:
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
}	; GFXTOOLKIT = 0

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
	+kcall joystick_get	; A=byte0, X=byte1, Y=$00 present / $FF absent (ROM-safe)
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
	+kcall mouse_config	; A = mode, X = cols, Y = rows (ROM-safe)
	+dpop
	jmp next

; MX ( -- x )   mouse X position
+header ~mx, ~mx_n, "MX"
	+code
	ldx #2				; mouse_get buffer at $02..$05
	+kcall mouse_get
	lda $02
	ldx $03
	jmp dpush_and_next

; MY ( -- y )   mouse Y position
+header ~my, ~my_n, "MY"
	+code
	ldx #2
	+kcall mouse_get
	lda $04
	ldx $05
	jmp dpush_and_next

; MB ( -- buttons )   mouse button bitmask (bit0 left, bit1 right, bit2 middle)
+header ~mb, ~mb_n, "MB"
	+code
	ldx #2
	+kcall mouse_get		; A = buttons
	ldx #0
	jmp dpush_and_next

; MWHEEL ( -- delta )   mouse wheel movement since last read (signed)
+header ~mwheel, ~mwheel_n, "MWHEEL"
	+code
	ldx #2
	+kcall mouse_get		; X = wheel delta
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
; EDIT ( c-addr u -- )   launch the X16 full-screen text editor on the named file
; (u = 0 opens a new empty buffer). Edit, save (Ctrl+S), and quit (Ctrl+Q) to
; return to Forth; then INCLUDE the file to compile it.
; The editor uses Forth's zero page ($22-$7F), so we save and restore it around
; the call. It keeps its document in RAM banks 10+ and its code in golden RAM
; and the top (unused) part of the token table, leaving Forth's state intact.
!ifdef EDIT_DEBUG {
; Debug instrumentation (assemble with acme -DEDIT_DEBUG=1): snapshot the
; KERNAL console state around the editor call so the two copies can be
; diffed from Forth.  Layout at the destination base page (A = $60 / $64):
;   +$000-$1FF : $0200-$03FF (KERNAL vectors + screen-editor variables)
;   +$200-$27F : zero page $80-$FF (KERNAL zp)
;   +$280-$28F : $AC00-$AC0F of RAM bank 0 (editor keystroke vectors area)
edit_snap:
	sta esn_d1+2		; patch the store high bytes
	clc
	adc #1
	sta esn_d2+2
	adc #1
	sta esn_d3+2
	sta esn_d4+2
	sta esn_d5+2
	adc #1
	sta esn_d6+2		; bank0 $A800 copy: 4 pages at base+3..+6
	ldx #0
esn_l1:	lda $0200,x
esn_d1:	sta $6000,x
	lda $0300,x
esn_d2:	sta $6100,x
	inx
	bne esn_l1
	ldx #$7F		; zero page $80-$FF (KERNAL zp)
esn_l2:	lda $80,x
esn_d3:	sta $6200,x
	dex
	bpl esn_l2
	lda $00			; force RAM bank 0 for the $Axxx reads
	pha
	lda #0
	sta $00
	ldx #15
esn_l3:	lda $AC00,x	; editor keystroke vectors area
esn_d4:	sta $6280,x
	dex
	bpl esn_l3
	ldx #$1F		; VERA $9F20-$9F3F (skip the data ports:
esn_l4:	cpx #3			; reading them advances ADDR)
	beq esn_v0
	cpx #4
	beq esn_v0
	lda $9F20,x
	bne esn_v1
esn_v0:	lda #0
esn_v1:
esn_d5:	sta $6290,x
	dex
	bpl esn_l4
	ldy #0			; bank0 $A800-$ABFF (keyboard/editor state)
esn_l5:
	lda $A800,y
esn_d6:	sta $6300,y
	iny
	bne esn_l5
	inc esn_l5+2		; walk the 4 source pages
	inc esn_d6+2
	lda esn_l5+2
	cmp #$AC
	bne esn_l5
	lda #$A8		; restore the patched source page
	sta esn_l5+2
	lda esn_d6+2		; bank0 $A000-$A6FF (the loaded KEYMAP tables:
	clc			; keymap_data/caps/deadkeys/kbdnam) -> base+7..+13
	adc #0			; (esn_d6+2 is already base+7 after the walk)
	sta esn_d7+2
	ldy #0
esn_l6:
	lda $A000,y
esn_d7:	sta $6700,y
	iny
	bne esn_l6
	inc esn_l6+2
	inc esn_d7+2
	lda esn_l6+2
	cmp #$A7
	bne esn_l6
	lda #$A0		; restore the patched source page
	sta esn_l6+2
	pla
	sta $00
	rts
}

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
!if NATIVE816 {
; NATIVE816: a fixed 94-byte memory-to-memory copy, non-overlapping regions -
; exactly the CMOVE/MVN shape (see fthtx16.asm). A fixed count needs no
; zero-length guard here (94 is a compile-time constant, never 0).
	rep #$30
	!al
	!rl
	lda #$5d			; count-1 = 93 (94 bytes)
	ldx #$22			; source = zero page $22
	ldy #edit_zpsave		; dest
	mvn 0, 0
	sep #$30
	!as
	!rs
} else {
	ldx #0				; save Forth zero page $22-$7F (94 bytes)
edit_save:
	lda $22,x
	sta edit_zpsave,x
	inx
	cpx #$5e
	bne edit_save
}
!ifdef EDIT_DEBUG {
	lda #$50			; "before" snapshot -> $5000
	jsr edit_snap
}
	ldx #10				; first RAM bank for the editor
	ldy #255			; last RAM bank
!if WIDEDICT = 1 {
!if WD_ROMBANKS = 0 {
	lda _codebank		; RAM-mode wide dict claims banks from the top
	beq edit_capdone	; down; cap x16edit just below Forth's lowest
	tay			; used bank so it can never overwrite the dict
	dey
edit_capdone:
}
}
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
!if NATIVE816 {
	rep #$30
	!al
	!rl
	lda #$5d			; count-1 = 93 (94 bytes)
	ldx #edit_zpsave		; source
	ldy #$22			; dest = zero page $22
	mvn 0, 0
	sep #$30
	!as
	!rs
} else {
	ldx #0				; restore Forth zero page
edit_restore:
	lda edit_zpsave,x
	sta $22,x
	inx
	cpx #$5e
	bne edit_restore
}
	; Reselect RAM bank 0 (the editor leaves the bank register at 10; Forth's later
	; KERNAL calls - RDTIM etc. - need 0). Then CLALL: close all KERNAL logical
	; files and reset the default I/O channels. x16edit does file I/O and can leave
	; a logical file open / the channels redirected, which breaks Forth's next
	; console read (?STACK) and file OPEN/INCLUDED. (BASIC's own EDIT does nothing
	; after the editor, but its main loop and READY path effectively reset I/O.)
!if WIDEDICT {
!if WD_ROMBANKS {
	lda #FARBANK			; $00 window = the data extension
} else {
	lda #0				; RAM mode: $00 is the (unpinned) code reg
}
} else {
	lda #0
}
	sta $00
	+kcall $FFE7			; CLALL - close all files + restore default I/O (ROM-safe)
	; CLALL also closed Forth's persistent DOS command channel (logical file
	; 15, opened at coldstart for the I/O-status reads). Without it the next
	; OPEN-FILE status read (c64iostatus: CHKIN 15 + CHRIN-until-newline)
	; falls back to the KEYBOARD - eating RETURNs and hanging INCLUDE after
	; EDIT (the long-standing bug). Reopen it exactly like coldstart does.
	lda #0
	ldx #0
	ldy #0
	jsr SETNAM			; zero-length name
	lda #15
	ldx #8
	ldy #15				; secondary 15 = the command channel
	jsr SETLFS
	jsr OPEN
	lda #0				; x16edit enables the mouse and leaves it on:
	ldx #0				; pointer sprite visible + PS/2 routing changed.
	ldy #0				; MOUSE_CONFIG(0) hides it and restores the
	+kcall $FF68			; keyboard-only data path.
!if FASTLOAD {
	jsr build_hashtable		; x16edit uses golden RAM ($0400-$07FF) where
					; HASHNFA lives - rebuild (idempotent)
}
!ifdef EDIT_DEBUG {
	lda #$60			; "after" snapshot -> $6000 (post-cleanup)
	jsr edit_snap
	; write both snapshots ($6000-$6EFF) to DFDUMP.BIN on device 8 right
	; here, BEFORE any console read - so the data reaches the host even
	; if the post-editor console is completely stuck.
	lda #esn_namlen
	ldx #<esn_nam
	ldy #>esn_nam
	jsr $FFBD			; SETNAM
	lda #1
	ldx #8
	ldy #0
	jsr $FFBA			; SETLFS
	lda #<$5000
	sta $02
	lda #>$5000
	sta $03
	lda #$02			; A = zp address of the start pointer
	ldx #<$6E00
	ldy #>$6E00
	jsr $FFD8			; SAVE
	jmp esn_saved
esn_nam: !text "@:DFDUMP.BIN"
esn_namlen = * - esn_nam
esn_hexd:				; print A as two hex digits + space
	pha
	lsr
	lsr
	lsr
	lsr
	jsr esn_hex1
	pla
	and #$0F
	jsr esn_hex1
	lda #' '
	jmp $FFD2
esn_hex1:
	cmp #10
	bcc +
	adc #6				; carry set: +6+1 -> 'A'-10
+:	adc #'0'
	jmp $FFD2
esn_saved:
	; probe: poll GETIN for a while and echo every received key code as
	; hex - shows whether keyboard data still ARRIVES after the editor
	lda #'<'
	jsr $FFD2
	lda #0
	sta esn_cnt
	sta esn_cnt+1
	sta esn_cnt+2
esn_gl:	jsr $FFE4			; GETIN
	cmp #0
	beq esn_gnone
	jsr esn_hexd
	jmp esn_gl
esn_gnone:
	inc esn_cnt
	bne esn_gl
	inc esn_cnt+1
	bne esn_gl
	inc esn_cnt+2
	lda esn_cnt+2
	cmp #6				; ~0.4M polls (~15 s real)
	bne esn_gl
	lda #'>'
	jsr $FFD2
	jmp esn_probed
esn_cnt: !byte 0,0,0
esn_probed:
}
	+dpop
	+dpop
	jmp next

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
!if WIDEDICT {
	lda $00			; the window normally shows the dictionary
	pha			; extension bank - restore it after
}
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
!if WIDEDICT {
	pla
	sta $00
}
	lda #0
	sta _dtop+1
	jmp next

; B! ( byte bank off -- )   store a byte into banked RAM (off is 0..8191)
+header ~bstore, ~bstore_n, "B!"
	+code
!if WIDEDICT {
	lda $00
	pha
}
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
!if WIDEDICT {
	pla
	sta $00
}
	+dpop
	+dpop
	+dpop
	jmp next

; DATABANK ( -- bank )   the highest RAM bank NOT yet used by the dictionary,
; which grows top-down - a safe place to start putting your own data with
; B@/B!. Returns 0 if none is free (the dictionary has reached the floor).
; NOTE: the dictionary keeps growing downward, so grab your data banks early
; and don't let it grow down into them. (WIDEDICT RAM-bank builds only.)
!if WIDEDICT {
!if WD_ROMBANKS = 0 {
+header ~databank, ~databank_n, "DATABANK"
	+code
	lda _codebank		; dict's lowest claimed bank (0 = none claimed yet)
	beq db_top
	sec
	sbc #1			; highest free = _codebank - 1
	bcs db_floor		; carry set (no borrow) - skip the _codetop load
db_top:
	lda _codetop		; nothing far yet -> the top usable RAM bank
db_floor:
	cmp #CBANK_FLOOR
	bcs db_ok
	lda #0			; below the floor -> no free data bank
db_ok:
	ldx #0
	jmp dpush_and_next
}
}

; --- Bulk RAM-bank I/O (all X16 builds) ------------------------------------
; Stream files straight into RAM banks and copy between a bank and low RAM.
; Ideal for game data: BANKLOAD all your levels into banks once, then BANK>MEM
; the active one into low RAM when needed. All four save/restore the $00 window
; register, so they are safe alongside the dictionary window. 'off' is 0..8191
; into the $A000 window; BANKLOAD and the two copies auto-advance across bank ends.
; Plain 6502 (the $A000 window + KERNAL work on every X16 CPU), so all X16 builds.
!if X16 {

; BANKLOAD ( c-addr u dev bank -- )   load a PRG file into RAM starting at
; bank:$A000; the KERNAL auto-advances the RAM bank across $BFFF, so a file
; bigger than 8K spills into bank+1, bank+2, ...
+header ~bankload, ~bankload_n, "BANKLOAD"
	+code
	lda _dtop			; bank
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
	lda #1
	ldx _wscratch
	ldy #0				; secondary 0 -> load to X/Y (skip 2-byte header)
	jsr SETLFS
	lda $00
	pha				; save the window register (dict resting bank)
	lda _scratch
	sta $00				; select the target RAM bank
	lda #0				; 0 = load
	ldx #<$A000
	ldy #>$A000			; load into the $A000 window
	jsr KLOAD
	pla
	sta $00				; restore the window register
	+dpop
	jmp next

; BANKSAVE ( c-addr u dev bank off len -- )   save len bytes from bank:off
; ($A000+off) to a PRG file. One bank per call: off+len must be <= 8192.
+header ~banksave, ~banksave_n, "BANKSAVE"
	+code
	ldy #2
	lda (_dstack),y			; off lo
	sta _scratch			; start = $A000 + off  (SAVE reads start via this zp ptr)
	iny
	lda (_dstack),y			; off hi
	clc
	adc #$A0
	sta _scratch+1
	clc
	lda _dtop			; len lo (top of stack is in _dtop)
	adc _scratch
	sta _rscratch			; end = start + len
	lda _dtop+1			; len hi
	adc _scratch+1
	sta _rscratch+1
	lda $00
	pha				; save the window register
	ldy #4
	lda (_dstack),y			; bank
	sta $00
	ldy #6
	lda (_dstack),y			; device
	sta _wscratch
	ldy #8
	lda (_dstack),y			; name length
	sta _wscratch+1
	ldy #10
	lda (_dstack),y			; name address lo
	tax
	ldy #11
	lda (_dstack),y			; name address hi
	tay
	lda _wscratch+1
	jsr SETNAM
	lda #1
	ldx _wscratch
	ldy #0
	jsr SETLFS
	lda #<_scratch			; A = zp ptr to the start address
	ldx _rscratch			; end low
	ldy _rscratch+1			; end high
	jsr KSAVE
	pla
	sta $00				; restore the window register
	+dpop
	+dpop
	+dpop
	+dpop
	+dpop
	+dpop
	jmp next

; BANK>MEM ( bank boff addr u -- )   fast copy u bytes from bank:boff (through
; the $A000 window) to low-RAM addr, auto-advancing across bank boundaries.
+header ~banktomem, ~banktomem_n, "BANK>MEM"
	+code
	ldy #4
	lda (_dstack),y			; boff lo -> src
	sta $02
	iny
	lda (_dstack),y			; boff hi
	clc
	adc #$A0			; src = $A000 + boff
	sta $03
	ldy #2
	lda (_dstack),y			; addr lo -> dest
	sta $04
	iny
	lda (_dstack),y			; addr hi
	sta $05
	lda _dtop			; u lo -> count (top of stack is in _dtop)
	sta _wscratch
	lda _dtop+1			; u hi
	sta _wscratch+1
	lda $00
	pha				; save the window register
	ldy #6
	lda (_dstack),y			; bank -> select
	sta $00
	ldy #0
btm_loop:
	lda _wscratch
	ora _wscratch+1
	beq btm_done
	lda ($02),y			; src byte (window)
	sta ($04),y			; dest byte (low RAM)
	inc $02
	bne btm_s2
	inc $03
	lda $03
	cmp #$C0			; crossed $BFFF? -> next bank, wrap to $A000
	bne btm_s2
	lda #$A0
	sta $03
	inc $00
btm_s2:
	inc $04
	bne btm_d2
	inc $05
btm_d2:
	lda _wscratch
	bne btm_dec
	dec _wscratch+1
btm_dec:
	dec _wscratch
	jmp btm_loop
btm_done:
	pla
	sta $00				; restore the window register
	+dpop
	+dpop
	+dpop
	+dpop
	jmp next

; MEM>BANK ( addr bank boff u -- )   fast copy u bytes from low-RAM addr to
; bank:boff (through the $A000 window), auto-advancing across bank boundaries.
+header ~memtobank, ~memtobank_n, "MEM>BANK"
	+code
	ldy #6
	lda (_dstack),y			; addr lo -> src (low RAM)
	sta $02
	iny
	lda (_dstack),y			; addr hi
	sta $03
	ldy #2
	lda (_dstack),y			; boff lo -> dest
	sta $04
	iny
	lda (_dstack),y			; boff hi
	clc
	adc #$A0			; dest = $A000 + boff
	sta $05
	lda _dtop			; u lo -> count (top of stack is in _dtop)
	sta _wscratch
	lda _dtop+1			; u hi
	sta _wscratch+1
	lda $00
	pha				; save the window register
	ldy #4
	lda (_dstack),y			; bank -> select
	sta $00
	ldy #0
mtb_loop:
	lda _wscratch
	ora _wscratch+1
	beq mtb_done
	lda ($02),y			; src byte (low RAM)
	sta ($04),y			; dest byte (window)
	inc $02
	bne mtb_s2
	inc $03
mtb_s2:
	inc $04
	bne mtb_d2
	inc $05
	lda $05
	cmp #$C0			; crossed $BFFF? -> next bank, wrap to $A000
	bne mtb_d2
	lda #$A0
	sta $05
	inc $00
mtb_d2:
	lda _wscratch
	bne mtb_dec
	dec _wscratch+1
mtb_dec:
	dec _wscratch
	jmp mtb_loop
mtb_done:
	pla
	sta $00				; restore the window register
	+dpop
	+dpop
	+dpop
	+dpop
	jmp next
}

; --- BASIC system words re-added (2026-07-07). Room reclaimed by moving the
; bitmap graphics to GFX.FTH (GFXTOOLKIT). All reach the KERNAL through
; +kcall / jsrfar (via the $FF6E stub), so they work in the bank-9/32 ROM
; builds too - a direct "jsr $FExx" there would land in the Forth bank.

; I2CPEEK ( dev reg -- byte )   read a byte from an I2C device register
+header ~i2cpeek, ~i2cpeek_n, "I2CPEEK"
	+code
	ldy #2
	lda (_dstack),y		; device
	tax
	lda _dtop			; register
	tay
	+kcall i2c_read_byte	; A = value
	+dpop				; drop register; _dtop now holds device
	sta _dtop			; overwrite with the result
	lda #0
	sta _dtop+1
	jmp next

; I2CPOKE ( dev reg val -- )   write a byte to an I2C device register
+header ~i2cpoke, ~i2cpoke_n, "I2CPOKE"
	+code
	ldy #4
	lda (_dstack),y		; device
	tax
	ldy #2
	lda (_dstack),y		; register
	tay
	lda _dtop			; value
	+kcall i2c_write_byte
	+dpop
	+dpop
	+dpop
	jmp next

; MONITOR ( -- )   enter the built-in machine-language monitor. Exit with X;
; note exiting does NOT cleanly return to Forth - reset afterward.
+header ~monitor, ~monitor_n, "MONITOR"
	+code
	jsr JSRFAR
	!word $C000
	!byte $05			; BANK_MONITOR
	jmp next

; RESET ( -- )   hardware reset via the SMC
+header ~reset, ~reset_n, "RESET"
	+code
	lda #0
	ldx #SMC_I2C_ADDR
	ldy #2				; SMC register 2 = reset
	+kcall i2c_write_byte
	jmp next

; POWEROFF ( -- )   power off via the SMC
+header ~poweroff, ~poweroff_n, "POWEROFF"
	+code
	lda #0
	ldx #SMC_I2C_ADDR
	ldy #1				; SMC register 1 = power off
	+kcall i2c_write_byte
	jmp next

; SLEEP ( jiffies -- )   wait 'jiffies' 1/60-second ticks
+header ~sleep, ~sleep_n, "SLEEP"
	+code
	jsr RDTIM			; A=LSB, X=mid, Y=MSB (X16 order - opposite of C64)
	sta $02				; start low
	stx $03				; start high
sleep_loop:
	jsr RDTIM			; A already = LSB
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

; MS ( u -- )   wait ~u milliseconds. A calibrated busy loop (the jiffy clock
; that SLEEP uses is only 1/60 s = 16.67 ms, too coarse for real ms). Tuned to
; the X16's 8 MHz clock (~8000 cycles per ms); approximate - the VSYNC IRQ adds
; a little, and a slower CPU speed would stretch it, but it honours "at least".
MS_OUTER = 7				; outer/inner passes tuned to ~8 MHz, ~1 ms
MS_INNER = 224
+header ~ms, ~ms_n, "MS"
	+code
ms_loop:
	lda _dtop			; u == 0 ?  done
	ora _dtop+1
	beq ms_done
	ldx #MS_OUTER			; ~1 ms delay
ms_o:
	ldy #MS_INNER
ms_i:
	dey
	bne ms_i
	dex
	bne ms_o
	lda _dtop			; u--  (16-bit)
	bne ms_dec
	dec _dtop+1
ms_dec:
	dec _dtop
	jmp ms_loop
ms_done:
	+dpop
	jmp next

; REBOOT ( -- )   soft reboot through the reset vector
+header ~reboot, ~reboot_n, "REBOOT"
	+code
	; Reset via the ROM-bank-0 reset vector. The bank switch + jump must run from
	; RAM: in the bank-9 ROM this word's own code is at $C000+, so selecting ROM
	; bank 0 would unmap it mid-instruction (-> crash to monitor). Copy a 7-byte
	; stub (LDA #0 / STA $01 / JMP ($FFFC)) into RAM and jump to it.
	ldx #6
reboot_copy:
	lda reboot_stub,x
	sta syscall_stub,x
	dex
	bpl reboot_copy
	jmp syscall_stub
reboot_stub:
	!byte $A9,$00		; LDA #0
	!byte $85,$01		; STA $01   (ROM bank 0 = KERNAL)
	!byte $6C,$FC,$FF	; JMP ($FFFC)  (reset vector, now bank 0's)

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
	+kcall keymap
	jmp next

!if FPCORE {
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

; FABS ( F: r -- |r| )   absolute value: clear the sign bit of the packed float
; (equivalent to  FDUP F0< IF FNEGATE THEN ). FP words live in a no-symbol token
; zone, so this is native rather than a token-threaded colon word.
+header ~fabs, ~fabs_n, "FABS"
	+code
	lda fsp
	sta $02
	lda fsp+1
	sta $03
	ldy #1
	lda ($02),y			; sign+mantissa byte; bit 7 = sign
	and #$7f			; force non-negative
	sta ($02),y
	jmp next

; FPOW ( F: x y -- x^y )   power via  exp(y * ln x)   (requires x > 0)
; Same result as  FSWAP FLN F* FEXP , done natively.
+header ~fpow, ~fpow_n, "FPOW"
	+code
fpow_impl:
	jsr fac_deep			; FAC = x  (the second float)
	+basiccall FP_log		; FAC = ln(x)
	jsr fsp5_to_02			; $02/$03 = address of the second float
	ldx $02
	ldy $03
	+basiccall FP_movmf		; second float = ln(x)
	jsr fac_deep			; FAC = ln(x)
	lda fsp
	ldy fsp+1
	+basiccall FP_fmult		; FAC = ln(x) * y   (top float)
	jsr fbin_store			; drop both, push FAC = y*ln(x)
	jsr fac_top			; FAC = y*ln(x)
	+basiccall FP_exp		; FAC = exp(y*ln x)
	jsr fstore_top			; top float = x^y
	jmp next

; F** ( F: x y -- x^y )   the standard name for FPOW (shares its body)
+header ~fstarstar, ~fstarstar_n, "F**"
	+code
	jmp fpow_impl

; --- FMAX / FMIN ( F: r1 r2 -- r ) -----------------------------------------
; fcmp leaves FAC = r1 - r2 without popping; facexp ($C3)=0 means r1=r2,
; facsgn ($C8) bit7 set means r1<r2. Then keep one float: fdrop_top drops the
; top (r2, keeping r1); fnip drops the second (r1, keeping r2).
fcmp:
	jsr fac_top			; FAC = r2 (top)
	jsr fsp5_to_02			; $02/$03 = &r1 (second)
	lda $02
	ldy $03
	+basiccall FP_fsub		; FAC = r1 - r2
	rts
fnip:					; drop the SECOND float, keep the top
	jsr fsp5_to_02			; $02/$03 = second slot (dest)
	lda fsp
	sta $04
	lda fsp+1
	sta $05				; $04/$05 = top slot (src)
	ldy #4
-	lda ($04),y
	sta ($02),y
	dey
	bpl -
fdrop_top:				; drop the top float (fsp += 5)
	clc
	lda fsp
	adc #5
	sta fsp
	lda fsp+1
	adc #0
	sta fsp+1
	jmp next

+header ~fmax, ~fmax_n, "FMAX"
	+code
	jsr fcmp
	lda $C3				; r1 = r2 ?  -> keep r1
	beq fdrop_top
	lda $C8				; r1 < r2 ?  -> keep r2
	bmi fnip
	jmp fdrop_top			; r1 > r2    -> keep r1

+header ~fmin, ~fmin_n, "FMIN"
	+code
	jsr fcmp
	lda $C3				; r1 = r2 ?  -> keep r1
	beq fdrop_top
	lda $C8				; r1 < r2 ?  -> keep r1 (the smaller)
	bmi fdrop_top
	jmp fnip			; r1 > r2    -> keep r2

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
} ; FPCORE

; ISQRT ( u -- m )   integer floor square root of an unsigned 16-bit value.
; Native binary digit-by-digit algorithm (no floating point): keeps c (result),
; d (a power of four), and x (the running remainder). ~10x faster than the old
; FP path and frees the FP stack, which matters when it is called per scanline
; (e.g. SPLIT.FTH's filled OVAL/DISC/FCIRCLE/FELL).
;   c=0; d=$4000; while d: t=c+d; if x>=t {x-=t; c=c>>1+d} else {c>>=1}; d>>=2
; NATIVE816 note: a fused-16-bit version of this was attempted and, despite
; extensive isolated verification (single-instruction tests, 1/2/4/8-iteration
; loop tests all passing), proved unreliable - an instruction-for-instruction
; identical rewrite gave correct results in one test session and incorrect
; results in another, with no root cause pinned down despite ruling out
; algorithm logic, zero-page overlap, byte encoding, interrupts, and specific
; instruction choice. Not safe to ship - left as the plain 8-bit version
; unconditionally. See [[x16-forth-65c816-phase1-progress]] for the full
; debugging writeup if this is revisited.
+header ~isqrt, ~isqrt_n, "ISQRT"
	+code
	lda _dtop			; x = n
	sta _scratch
	lda _dtop+1
	sta _scratch+1
	lda #0
	sta _scratch_2			; c = 0
	sta _scratch_2+1
	sta _scratch_1			; d = $4000
	lda #$40
	sta _scratch_1+1
isqrt_lp:
	lda _scratch_1			; while d != 0
	ora _scratch_1+1
	beq isqrt_dn
	clc				; t = c + d
	lda _scratch_2
	adc _scratch_1
	sta _rscratch
	lda _scratch_2+1
	adc _scratch_1+1
	sta _rscratch+1
	sec				; x - t  (borrow => x < t)
	lda _scratch
	sbc _rscratch
	tay				; keep low diff
	lda _scratch+1
	sbc _rscratch+1
	bcc isqrt_less
	sty _scratch			; x >= t : x -= t
	sta _scratch+1
	lsr _scratch_2+1		; c = (c >> 1) + d
	ror _scratch_2
	clc
	lda _scratch_2
	adc _scratch_1
	sta _scratch_2
	lda _scratch_2+1
	adc _scratch_1+1
	sta _scratch_2+1
	jmp isqrt_dsh
isqrt_less:
	lsr _scratch_2+1		; c = c >> 1
	ror _scratch_2
isqrt_dsh:
	lsr _scratch_1+1		; d >>= 2
	ror _scratch_1
	lsr _scratch_1+1
	ror _scratch_1
	jmp isqrt_lp
isqrt_dn:
	lda _scratch_2
	ldx _scratch_2+1
	sta _dtop
	stx _dtop+1
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
!if NATIVE816 {
; Defensive: this handler's body assumes 8-bit A/X throughout (it was written
; for 6502/emulation-mode and never does its own SEP/REP). Under NATIVE816 an
; IRQ can fire asynchronously while a converted +code word is mid-REP #$20
; (A=16-bit) - without this, irq_handler's own lda/beq checks would silently
; misread. Safe to force here: the INTERRUPTED code's original P (including
; M/X) was already auto-saved by the hardware interrupt entry and is restored
; by the eventual RTI further down the chain, unaffected by what we do to the
; live register here.
	sep #$30
}
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
!if WIDEDICT {
	lda _ribank		; the IRQ can fire mid-far-word; the callback
	sta irq_save_ribank	; itself starts on a home-bank token list
	lda #0
	sta _ribank
	lda _bsp		; IRQPAUSE unwinds the callback's frames by
	sta irq_save_bsp	; restoring pointers - the bank stack too
	lda CBANKREG		; the callback starts unpinned (its own CALL
	sta irq_save_bank	; re-pins per stub); the interrupted code's
	lda #0			; pin is restored on exit
	sta CBANKREG
!if WD_ROMBANKS {
	lda $00			; ROM mode: the $00 window is the static data
	sta irq_save_bank2	; extension - the IRQ may interrupt B!/KERNAL
	lda #FARBANK		; code that switched it
	sta $00
}
}
!if FPCORE {
	lda fsp
	sta irq_save_fsp
	lda fsp+1
	sta irq_save_fsp+1
}
	rts

irq_restorevm:
	ldx #19
-	lda irq_save,x
	sta _ri,x
	dex
	bpl -
!if WIDEDICT {
	lda irq_save_ribank
	sta _ribank
	lda irq_save_bsp
	sta _bsp
	lda irq_save_bank
	sta CBANKREG
!if WD_ROMBANKS {
	lda irq_save_bank2
	sta $00
}
}
!if FPCORE {
	lda irq_save_fsp
	sta fsp
	lda irq_save_fsp+1
	sta fsp+1
}
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
	ldy #2
	lda (_dstack),y			; value (low byte) -> A (kept across the loop)
	pha
	ldx _dtop			; count lo -> X (remainder)
	ldy _dtop+1			; count hi -> Y (number of 256-byte pages)
	pla				; A = value
	cpx #0				; tight fill: X remainder bytes, then Y pages
	beq vfill_pages
vfill_rem:
	sta VERA_DATA0
	dex
	bne vfill_rem
vfill_pages:
	cpy #0
	beq vfill_dn
vfill_page:
	sta VERA_DATA0
	dex				; X = 0 here -> wraps, 256 stores per page
	bne vfill_page
	dey
	bne vfill_pages
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

; CD ( c-addr u -- )   change directory: send "CD:<name>" to the device-8 DOS
; command channel (logical file 15, secondary 15).  S" DR1" CD  enters DR1;
; S" .." CD  goes up;  S" /" CD  goes to the root.  (name up to ~16 chars)
+header ~cd, ~cd_n, "CD"
	+code
	lda #'C'
	sta imgnam
	lda #'D'
	sta imgnam+1
	lda #':'
	sta imgnam+2
	ldy #2			; NOS = c-addr -> source pointer
	lda (_dstack),y
	sta _scratch
	ldy #3
	lda (_dstack),y
	sta _scratch+1
	ldy #0
cd_copy:
	cpy _dtop		; u bytes
	beq cd_setnam
	lda (_scratch),y
	cmp #'a'		; uppercase a-z (FAT32 names are upper case), leave the rest
	bcc cd_put
	cmp #'z'+1
	bcs cd_put
	and #$df		; 'a'..'z' -> 'A'..'Z'
cd_put:
	sta imgnam+3,y
	iny
	cpy #17			; clamp to the 20-byte imgnam ("CD:" + 17)
	bne cd_copy
cd_setnam:
	tya			; A = copied length
	clc
	adc #3			; + "CD:"
	ldx #<imgnam
	ldy #>imgnam
	jsr SETNAM
	lda #15			; logical file 15, device 8, secondary 15 = command channel
	ldx #8
	ldy #15
	jsr SETLFS
	jsr OPEN		; opening the command executes the DOS CD
	lda #15
	jsr CLOSE
	jsr CLRCHN
	+dpop
	+dpop
	jmp next

; DIR ( -- )   list the current directory (reads the "$" pseudo-file on device 8
; and prints each entry line: filename + type; block counts are omitted).
+header ~dir, ~dir_n, "DIR"
	+code
	lda #'$'		; name = "$" - built in RAM (imgnam); the bridged KERNAL runs
	sta imgnam		; with bank 0 mapped and cannot read a ROM $Cxxx literal
	lda #1
	ldx #<imgnam
	ldy #>imgnam
	jsr SETNAM
	lda #2			; logical file 2, device 8, secondary 0 (read)
	ldx #8
	ldy #0
	jsr SETLFS
	jsr OPEN
	ldx #2
	jsr CHKIN		; take input from file 2
	bcs dir_done		; channel not open (e.g. no "$" support) -> bail, no hang
	jsr CHRIN		; skip the 2-byte load address
	jsr CHRIN
dir_line:
	jsr CHRIN		; link low
	sta _scratch
	jsr CHRIN		; link high
	ora _scratch
	beq dir_done		; link = 0 -> end of directory
	jsr CHRIN		; block count low
	sta _rscratch
	jsr CHRIN		; block count high
	sta _rscratch+1
	jsr dir_pnum		; print it (the DOS padded the text to align after it)
dir_text:
	jsr CHRIN
	beq dir_eol		; 0 -> end of this entry's text
	jsr CHROUT
	jmp dir_text
dir_eol:
	lda #13
	jsr CHROUT		; newline
	lda #$92
	jsr CHROUT		; RVS OFF - else the header line's $12 bleeds into every row
	jsr READST
	beq dir_line		; status 0 -> another entry; else EOF/error
dir_done:
	jsr CLRCHN
	lda #2
	jsr CLOSE
	jmp next

; print _rscratch (16-bit unsigned) as decimal, no leading zeros (destroys it)
dir_pnum:
	lda #0
	sta _scratch_2		; 0 = still suppressing leading zeros
	ldx #0
dpn_pow:
	ldy #'0'-1
dpn_sub:
	iny
	lda _rscratch
	sec
	sbc dpn_tab,x
	sta _rscratch
	lda _rscratch+1
	sbc dpn_tab+4,x
	sta _rscratch+1
	bcs dpn_sub
	lda _rscratch		; overshot by one -> add the power back
	adc dpn_tab,x
	sta _rscratch
	lda _rscratch+1
	adc dpn_tab+4,x
	sta _rscratch+1
	cpy #'0'
	bne dpn_pr		; non-zero digit -> print
	lda _scratch_2
	beq dpn_nx		; leading zero -> skip
dpn_pr:
	tya
	jsr CHROUT
	lda #1
	sta _scratch_2
dpn_nx:
	inx
	cpx #4
	bne dpn_pow
	lda _rscratch		; final units digit (always printed)
	ora #'0'
	jmp CHROUT
dpn_tab:
	!byte <10000, <1000, <100, <10
	!byte >10000, >1000, >100, >10

; LINPUT ( c-addr +n -- +n2 )   read a line from the keyboard
+header ~linput, ~linput_n, "LINPUT"
	+forth
	+token accept, exit

; BASIC floating-point function names (SQR SIN COS TAN ATN LOG EXP) were moved
; out of the core to save ROM space - they only duplicated FSQRT/FSIN/FCOS/FTAN/
; FATAN/FLN/FEXP. Load them on demand with  INCLUDE BASICMATH.FTH  (toolkit/).

; The BASIC string / number-conversion words (HEX$ BIN$ STR$ VAL ASC CHR$ LEN
; LEFT$ RIGHT$ MID$ RPT$) were moved out of the core to make room for CD/DIR etc.
; They are all pure-Forth (built on <# #S #> >NUMBER /STRING FILL MIN ...), so
; they live in toolkit/BASICSTR.FTH now - load with  INCLUDE BASICSTR.FTH .

; --- X16FP.FTH : Forth-2012 floating-point defining words ------------------
; (FPCORE=0: FVARIABLE/FCONSTANT live in toolkit/FLOAT.FTH instead)

!if FPCORE {
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
} ; FPCORE

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

; ==============================================================================
; Extended X16 access (added to reach the last reference-guide gaps).
; Phases 1-7: clock, palette, PCM, layers, VERA FX, generic KERNAL call, keys.
; All native. KERNAL routines not in the RAM bridge are reached with +kcall
; (jsrfar into bank 0), so every word works in both the PRG and bank-9 ROM build.
; ==============================================================================

; ---- Phase 1: clock / date / time -------------------------------------------
; The system clock is seeded from the battery-backed RTC at boot and advanced by
; the jiffy IRQ. clock_get/set_date_time (r0..r3) handle the BCD conversion.

; TICKS ( -- ud )   the 24-bit jiffy counter (1/60 s) as an unsigned double.
+header ~ticks, ~ticks_n, "TICKS"
	+code
	jsr RDTIM		; A = LSB, X = mid, Y = MSB
	sty _scratch		; keep MSB across the push
	jsr push_dstack		; low cell = mid:LSB
	lda _scratch		; high cell = MSB
	ldx #0
	jmp dpush_and_next

; TIME@ ( -- hour min sec )
+header ~timefetch, ~timefetch_n, "TIME@"
	+code
	+kcall CLOCK_GET
	lda R1H			; hours
	ldx #0
	jsr push_dstack
	lda R2L			; minutes
	ldx #0
	jsr push_dstack
	lda R2H			; seconds
	ldx #0
	jmp dpush_and_next

; DATE@ ( -- year month day )   year is the full 4-digit year (1900 + RTC value)
+header ~datefetch, ~datefetch_n, "DATE@"
	+code
	+kcall CLOCK_GET
	lda R0L			; year - 1900
	clc
	adc #$6c		; + 1900 ($076C)
	sta _scratch
	lda #$07
	adc #0
	sta _scratch+1
	lda _scratch
	ldx _scratch+1
	jsr push_dstack		; year
	lda R0H			; month
	ldx #0
	jsr push_dstack
	lda R1L			; day
	ldx #0
	jmp dpush_and_next

; SETTIME ( year month day hour min sec -- )   set the clock (weekday = 1)
+header ~settime, ~settime_n, "SETTIME"
	+code
	lda _dtop		; sec
	sta R2H
	ldy #2			; min
	lda (_dstack),y
	sta R2L
	ldy #4			; hour
	lda (_dstack),y
	sta R1H
	ldy #6			; day
	lda (_dstack),y
	sta R1L
	ldy #8			; month
	lda (_dstack),y
	sta R0H
	ldy #10			; year (low), subtract 1900
	lda (_dstack),y
	sec
	sbc #$6c
	sta R0L
	lda #0
	sta R3L			; jiffies = 0
	lda #1
	sta R3H			; weekday = 1
	+kcall CLOCK_SET
	+dpop
	+dpop
	+dpop
	+dpop
	+dpop
	+dpop
	jmp next

; ---- Phase 2: palette -------------------------------------------------------
; The 256-entry palette lives at VRAM $1:FA00, 2 bytes/entry little-endian:
;   byte 0 = green<<4 | blue,  byte 1 = 0000 red.  So a 12-bit $0RGB value's low
;   byte is written first and its high nibble second.

; PAL! ( rgb index -- )   set palette entry (index 0-255) to a 12-bit $RGB colour
+header ~palstore, ~palstore_n, "PAL!"
	+code
	lda _dtop		; index
	asl			; index*2, carry = bit 8
	sta VERA_ADDR_L
	lda #$fa
	adc #0			; $FA00 high byte + carry
	sta VERA_ADDR_M
	lda #$11		; bank 1, auto-increment 1
	sta VERA_ADDR_H
	ldy #2
	lda (_dstack),y		; rgb low (green<<4 | blue)
	sta VERA_DATA0
	iny
	lda (_dstack),y		; rgb high
	and #$0f		; red nibble only
	sta VERA_DATA0
	+dpop			; drop index
	+dpop			; drop rgb
	jmp next

; ---- Phase 3: PCM audio -----------------------------------------------------
; VERA PCM FIFO. AUDIO_CTRL packs volume(0-3) / 16-bit(5) / stereo(4) and, on
; write, bit 7 resets the FIFO. Feed 8/16-bit signed sample bytes to PCM!.

; The one-shot PCM register accessors are native in every build (the audio regs
; at $9F3B-$9F3D are in the always-visible I/O page, so they work in PRG and the
; ROM/bank builds alike). ~86 bytes total; the old toolkit/PCMAUDIO.FTH is gone.

; PCMCTRL ( n -- )   write AUDIO_CTRL (volume 0-15, format bits, bit7 = FIFO reset)
+header ~pcmctrl, ~pcmctrl_n, "PCMCTRL"
	+code
	lda _dtop
	sta VERA_AUDIO_CTRL
	+dpop
	jmp next

; PCMRATE ( n -- )   write AUDIO_RATE (0 = stop .. 128 = 48 kHz)
+header ~pcmrate, ~pcmrate_n, "PCMRATE"
	+code
	lda _dtop
	sta VERA_AUDIO_RATE
	+dpop
	jmp next

; PCM! ( byte -- )   push one sample byte into the FIFO (dropped if full)
+header ~pcmstore, ~pcmstore_n, "PCM!"
	+code
	lda _dtop
	sta VERA_AUDIO_DATA
	+dpop
	jmp next

; PCMFULL? ( -- flag )   true when the FIFO cannot accept more data (CTRL bit 7)
+header ~pcmfull, ~pcmfull_n, "PCMFULL?"
	+code
	lda VERA_AUDIO_CTRL
	and #$80
	beq pcmfull_no
	lda #$ff
	tax
	jmp dpush_and_next
pcmfull_no:
	lda #0
	tax
	jmp dpush_and_next

; PCM-WRITE ( addr count -- )   blast count bytes from RAM into the FIFO. Meant
; for priming an (empty) 4 KB FIFO; it does not throttle, so excess bytes past a
; full FIFO are dropped by VERA - poll PCMFULL? for a paced feeder.
+header ~pcmwrite, ~pcmwrite_n, "PCM-WRITE"
	+code
	ldy #2
	lda (_dstack),y
	sta _scratch		; source addr
	iny
	lda (_dstack),y
	sta _scratch+1
	lda _dtop		; count
	sta _wscratch
	lda _dtop+1
	sta _wscratch+1
	ldy #0
pcmw_loop:
	lda _wscratch
	ora _wscratch+1
	beq pcmw_done
	lda (_scratch),y
	sta VERA_AUDIO_DATA
	inc _scratch
	bne pcmw_c1
	inc _scratch+1
pcmw_c1:
	lda _wscratch
	bne pcmw_c2
	dec _wscratch+1
pcmw_c2:
	dec _wscratch
	jmp pcmw_loop
pcmw_done:
	+dpop			; drop count
	+dpop			; drop addr
	jmp next

; ---- Phase 4: VERA layer configuration --------------------------------------
; Enable/disable the two display layers and relocate their map / tile bases and
; config byte. MAPBASE/TILEBASE take a (bank addr) VRAM address like VADDR.

; LAYER-ON ( layer -- )   enable layer 0 or 1
+header ~layer_on, ~layer_on_n, "LAYER-ON"
	+code
	lda VERA_CTRL
	and #$81		; DCSEL = 0 (keep reset + ADDRSEL)
	sta VERA_CTRL
	lda _dtop
	beq layon0
	lda #$20		; layer 1 enable
	jmp layon_go
layon0:
	lda #$10		; layer 0 enable
layon_go:
	ora VERA_DC_VIDEO
	sta VERA_DC_VIDEO
	+dpop
	jmp next

; LAYER-OFF ( layer -- )   disable layer 0 or 1
+header ~layer_off, ~layer_off_n, "LAYER-OFF"
	+code
	lda VERA_CTRL
	and #$81
	sta VERA_CTRL
	lda _dtop
	beq layoff0
	lda #$20
	jmp layoff_go
layoff0:
	lda #$10
layoff_go:
	eor #$ff
	and VERA_DC_VIDEO
	sta VERA_DC_VIDEO
	+dpop
	jmp next

; MAPBASE ( layer bank addr -- )   set the tile-map base (aligned to 512 bytes)
+header ~mapbase, ~mapbase_n, "MAPBASE"
	+code
	lda _dtop+1		; addr high byte
	lsr			; -> bits 15:9 in bits 6:0 (= addr>>9)
	sta _scratch
	ldy #2
	lda (_dstack),y		; bank (0/1) -> bit 7
	lsr
	lda _scratch
	bcc mapb_nb
	ora #$80
mapb_nb:
	sta _scratch
	ldy #4
	lda (_dstack),y		; layer
	beq mapb_l0
	lda _scratch
	sta VERA_L1_MAPBASE
	jmp mapb_done
mapb_l0:
	lda _scratch
	sta VERA_L0_MAPBASE
mapb_done:
	+dpop
	+dpop
	+dpop
	jmp next

; TILEBASE ( layer bank addr -- )   set the tile-data base (aligned to 2 KB),
; preserving the register's low 2 bits (tile width/height).
+header ~tilebase, ~tilebase_n, "TILEBASE"
	+code
	lda _dtop+1
	lsr
	sta _scratch
	ldy #2
	lda (_dstack),y
	lsr
	lda _scratch
	bcc tileb_nb
	ora #$80
tileb_nb:
	and #$fc		; bits 16:11 -> register bits 7:2
	sta _scratch
	ldy #4
	lda (_dstack),y		; layer
	beq tileb_l0
	lda VERA_L1_TILEBASE
	and #$03
	ora _scratch
	sta VERA_L1_TILEBASE
	jmp tileb_done
tileb_l0:
	lda VERA_L0_TILEBASE
	and #$03
	ora _scratch
	sta VERA_L0_TILEBASE
tileb_done:
	+dpop
	+dpop
	+dpop
	jmp next

; LAYER-MODE ( layer cfg -- )   write Lx_CONFIG (map size, T256C, bitmap, depth)
+header ~layer_mode, ~layer_mode_n, "LAYER-MODE"
	+code
	lda _dtop		; cfg
	pha
	ldy #2
	lda (_dstack),y		; layer
	beq laym_l0
	pla
	sta VERA_L1_CONFIG
	jmp laym_done
laym_l0:
	pla
	sta VERA_L0_CONFIG
laym_done:
	+dpop
	+dpop
	jmp next

; ---- Phase 5: VERA FX -------------------------------------------------------

; DCSEL ( n -- )   select the DCSEL register bank (0-63) so FX registers at
; $9F29-$9F2C can be reached with ordinary C!/C@.
+header ~dcsel, ~dcsel_n, "DCSEL"
	+code
	lda _dtop
	asl
	and #$7e		; DCSEL occupies CTRL bits 1-6
	sta _scratch
	lda VERA_CTRL
	and #$81		; keep reset + ADDRSEL
	ora _scratch
	sta VERA_CTRL
	+dpop
	jmp next

; FX-MULT ( a b -- lo hi )   signed 16x16 -> 32-bit product using VERA's hardware
; multiplier. Returns the 32-bit result as ( low-cell high-cell ). Saves and
; restores VERA CTRL/ADDR0 and uses scratch VRAM at $1:F800.
+header ~fxmult, ~fxmult_n, "FX-MULT"
	+code
	lda VERA_CTRL		; save clobbered VERA state on the CPU stack
	pha
	lda VERA_ADDR_L
	pha
	lda VERA_ADDR_M
	pha
	lda VERA_ADDR_H
	pha
	lda #$0c		; DCSEL = 6 : load the 32-bit cache
	sta VERA_CTRL
	ldy #2
	lda (_dstack),y		; a low  -> multiplicand
	sta $9f29
	iny
	lda (_dstack),y		; a high
	sta $9f2a
	lda _dtop		; b low  -> multiplier
	sta $9f2b
	lda _dtop+1		; b high
	sta $9f2c
	lda #$04		; DCSEL = 2
	sta VERA_CTRL
	lda #$10		; FX_MULT: Multiplier Enable
	sta $9f2c
	lda #$40		; FX_CTRL: Cache Write Enable
	sta $9f29
	lda #0
	sta VERA_ADDR_L		; ADDR0 = $1:F800, no increment
	lda #$f8
	sta VERA_ADDR_M
	lda #$01
	sta VERA_ADDR_H
	lda #0
	sta VERA_DATA0		; trigger the multiply + 32-bit VRAM write
	lda #$11		; increment 1 to read the 4 result bytes back
	sta VERA_ADDR_H
	lda VERA_DATA0
	sta _scratch		; result byte 0
	lda VERA_DATA0
	sta _scratch+1		; byte 1
	lda VERA_DATA0
	sta _scratch_1		; byte 2
	lda VERA_DATA0
	sta _scratch_1+1	; byte 3
	lda #$04		; disable FX
	sta VERA_CTRL
	lda #0
	sta $9f29
	lda #0
	sta $9f2c
	pla			; restore VERA state
	sta VERA_ADDR_H
	pla
	sta VERA_ADDR_M
	pla
	sta VERA_ADDR_L
	pla
	sta VERA_CTRL
	+dpop			; drop b; a becomes _dtop
	lda _scratch		; low result cell overwrites a
	sta _dtop
	lda _scratch+1
	sta _dtop+1
	lda _scratch_1		; high result cell on top
	ldx _scratch_1+1
	jmp dpush_and_next

; ---- Phase 6: generic KERNAL call -------------------------------------------

; SYSCALL ( a x y addr -- a' x' y' )   call the routine at addr in KERNAL bank 0
; with A/X/Y loaded, returning the callee's A/X/Y. Unlocks the whole KERNAL API
; (GRAPH_*, console_*, screen_set_charset, MEMTOP, ...) from Forth. ROM-safe: it
; routes through jsrfar via a small RAM trampoline.
+header ~syscall, ~syscall_n, "SYSCALL"
	+code
	lda #$20		; build:  JSR JSRFAR
	sta syscall_stub
	lda #<JSRFAR
	sta syscall_stub+1
	lda #>JSRFAR
	sta syscall_stub+2
	lda _dtop		; .word target
	sta syscall_stub+3
	lda _dtop+1
	sta syscall_stub+4
	lda #0
	sta syscall_stub+5	; .byte 0  (KERNAL bank)
	lda #$60		; RTS
	sta syscall_stub+6
	ldy #6			; marshal A/X/Y from the stack
	lda (_dstack),y		; a-arg
	pha
	ldy #4
	lda (_dstack),y		; x-arg
	pha
	ldy #2
	lda (_dstack),y		; y-arg
	tay
	pla
	tax			; x-arg
	pla			; a-arg
	jsr syscall_stub	; A/X/Y in, A/X/Y (and carry) out
	pha			; stash returns on the CPU stack
	txa
	pha
	tya
	pha
	+dpop			; drop addr; stack now = a x y (y on top)
	pla			; y'
	sta _dtop
	lda #0
	sta _dtop+1
	pla			; x'
	ldy #2
	sta (_dstack),y
	iny
	lda #0
	sta (_dstack),y
	pla			; a'
	ldy #4
	sta (_dstack),y
	iny
	lda #0
	sta (_dstack),y
	jmp next

; CHARSET ( n -- )   activate a built-in 8x8 charset (1=ISO 2=PET-upper/graph
; 3=PET-upper/lower .. 12=Katakana; see Appendix I). screen_set_charset.
+header ~charset, ~charset_n, "CHARSET"
	+code
	lda _dtop
	+kcall SETCHARSET
	+dpop
	jmp next

; ---- Phase 7: keyboard -------------------------------------------------------

; KEY? ( -- flag )   true if a key is waiting (peeks the queue, non-destructive)
+header ~keyq, ~keyq_n, "KEY?"
	+code
	+kcall KBDPEEK		; A = char, X = queue length
	cpx #0
	beq keyq_no
	lda #$ff
	tax
	jmp dpush_and_next
keyq_no:
	lda #0
	tax
	jmp dpush_and_next

; GETKEY ( -- char )   block until a key is pressed, then return its PETSCII code
+header ~getkey, ~getkey_n, "GETKEY"
	+code
getkey_wait:
	jsr GETIN		; non-blocking; 0 = nothing yet
	beq getkey_wait
	ldx #0
	jmp dpush_and_next
