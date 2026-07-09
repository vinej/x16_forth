; SAVE-IMAGE/LOAD-IMAGE dictionary-state <-> IMGBUF copy routines.
; Sourced from x16.asm normally; the ROM-bank builds source it into the
; padding gap between the $FF6E jsrfar entry and the $FFFA vectors instead
; (fthtx16.asm), reclaiming ~114 bytes of the 16K bank for real code.

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
!if WIDEDICT {
	lda _dictbank		; +61: allocation bank, +62/63: current limit
	sta IMGBUF+61
	lda _memtop
	sta IMGBUF+62
	lda _memtop+1
	sta IMGBUF+63
	lda _nearhere		; +64/65: near-dict end (see SAVE-IMAGE)
	sta IMGBUF+64
	lda _nearhere+1
	sta IMGBUF+65
	lda _codetop		; +66: top code bank the image was built on
	sta IMGBUF+66
	lda _codebank		; +67: lowest code bank used (0 = none)
	sta IMGBUF+67
	lda _chere		; +68/69: code allocation pointer
	sta IMGBUF+68
	lda _chere+1
	sta IMGBUF+69
	lda _incode		; +70: mid-definition flag (normally 0)
	sta IMGBUF+70
!if WD_FARHDR {
	lda _latestbank		; +71: bank of LATEST's header
	sta IMGBUF+71
	ldx #WORDLISTS-1	; +72..: per-wordlist head banks
ivs3:	lda _vocsbank,x
	sta IMGBUF+72,x
	dex
	bpl ivs3
}
}
!if FPCORE = 0 {
	lda tofloat_vec			; the >FLOAT hook (see IMG_TFV above)
	sta IMGBUF+IMG_TFV
	lda tofloat_vec+1
	sta IMGBUF+IMG_TFV+1
}
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
!if WIDEDICT {
	lda IMGBUF+61
	sta _dictbank
	lda IMGBUF+62
	sta _memtop
	lda IMGBUF+63
	sta _memtop+1
	lda IMGBUF+64
	sta _nearhere
	lda IMGBUF+65
	sta _nearhere+1
	lda IMGBUF+66
	sta _codetop
	lda IMGBUF+67
	sta _codebank
	lda IMGBUF+68
	sta _chere
	lda IMGBUF+69
	sta _chere+1
	lda IMGBUF+70
	sta _incode
!if WD_FARHDR {
	lda IMGBUF+71
	sta _latestbank
	sta _scanbank
	ldx #WORDLISTS-1
ivl3:	lda IMGBUF+72,x
	sta _vocsbank,x
	dex
	bpl ivl3
}
}
!if FPCORE = 0 {
	lda IMGBUF+IMG_TFV		; restore the >FLOAT hook
	sta tofloat_vec
	lda IMGBUF+IMG_TFV+1
	sta tofloat_vec+1
}
	rts


; ';' balance-check abort fragment (see the ?PAIRS guard in fthtx16.asm) -
; position-independent token data, parked here so the ROM builds keep it in
; the vector-gap padding.
csp_abort:
	+token xabortq
	+string "?PAIRS"
