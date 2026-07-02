; ---------------------------------------------------------------------------
; Commander X16 cartridge image for Forth TX16
; ---------------------------------------------------------------------------
; Wraps the X16 PRG build (forthx16.prg) into a ROM bank 32 cartridge image.
; The KERNAL boot ROM checks ROM bank 32 for the PETSCII signature "CX16" at
; $C000 and, if present, calls the entry point at $C004 (with bank 32 selected
; and IRQs masked).
;
; ROM bank 32 occupies $C000-$FFFF - the same window as the KERNAL - so a
; program that uses the KERNAL (as Forth does, heavily) cannot execute in place.
; This loader therefore copies the Forth image down to its normal run address
; ($0801) in low RAM, switches back to ROM bank 0 (KERNAL), and jumps to the
; Forth cold-start entry.
;
; Build with makex16crt.bat (which first builds forthx16.prg, then this).
; Test with testx16crt.bat, or run:  x16emu -cartbin forthcart.bin
; The image is padded to a full 16K bank.

* = $C000
	!text "CX16"			; cartridge signature at $C000

cart_start:					; entry point at $C004
	sei

	; copy the small bank-switch trampoline into low RAM ($0400, "golden RAM")
	ldx #tramp_len-1
-	lda tramp,x
	sta $0400,x
	dex
	bpl -

	; copy the Forth image from bank-32 ROM down to $0801
	lda #<payload
	sta $fb
	lda #>payload
	sta $fc
	lda #$01
	sta $fd
	lda #$08
	sta $fe
	ldx #>payload_len
	inx						; round up the partial final page
	ldy #0
-	lda ($fb),y
	sta ($fd),y
	iny
	bne -
	inc $fc
	inc $fe
	dex
	bne -

	jmp $0400				; run the trampoline from RAM

; This runs from RAM so it survives switching bank 32 out from under it.
tramp:
	lda #0
	sta $01					; ROM bank 0 = KERNAL/BASIC
	cli
	jmp $080d				; Forth cold-start (CODESTART of the PRG build)
tramp_end:
tramp_len = tramp_end - tramp

payload:
	!binary "forthx16.prg", , 2	; embed the PRG image, skipping its 2-byte load address
payload_end:
payload_len = payload_end - payload

; pad out to a full 16K ROM bank
!fill $10000 - *, $ff
