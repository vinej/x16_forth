fileio_module_start = *

; Full equivalent to C64 OPEN, not exposed to dictionary yet
; Note that it requires 5 stack parameters as the string is enchoded as (c_addr,u)
; Top of data stack will have filenum or 0 on error
+header ~c64open, ~c64open_n
	+code
	+dpop
	; Note that A is set exactly to what we need there
	ldx _dtop
	ldy _dtop+1
	jsr SETNAM
	+dpop
	lda _dtop
	pha
	+dpop
	lda _dtop
	pha
	+dpop
	pla
	tax
	pla
	tay
	lda _dtop
	pha
	jsr SETLFS
	jsr OPEN
	pla
	ldx #0
	jmp next

; Corresponding equivalent to CLOSE
+header ~c64close, ~c64close_n
	+code
	+dpop
	jsr CLOSE
	jmp next

; This is used to check the drive status which is a rather
; complex process on C64. Ignoring responses starting with 0 (no responses start with 1)
; Note that this would hang if there is no drive attached, requiring an extra check for drive
; on startup
+header ~c64iostatus, ~c64iostatus_n
	+code
	lda _nodrive
	bne +
	ldx #15
	jsr CHKIN
	jsr CHRIN
	pha
-:
	jsr CHRIN
	cmp #NEW_LINE
	bne -
	jsr CLRCHN
	pla
	cmp #'2'
	bcs +
	lda #0
+:
	tax
	jmp dpush_and_next

; This will actually report other I/O errors, but this should be fine
+header ~c64iseof, ~c64iseof_n
	+code
	jsr READST
	tax
	jmp dpush_and_next

+header ~prepfname, ~prepfname_n
	+forth
	+token count
	+literal _fnamebuf
	+token place
	+literal _fnamebuf
	+token plusplace
	+token exit

; Set/unset channel for read and write, these need to follow after each other to
; save on common code
+header ~setread, ~setread_n
	+code
	+dpop
	tax
	beq +
	jsr CHKIN
	jmp next

+header ~setwrite, ~setwrite_n
	+code
	+dpop
	tax
	beq +
	jsr CHKOUT
	jmp next
+:
	jsr CLRCHN
	jmp next

; This is the common code of READ-LINE and READ-FILE. There are only two differences between them -
; that READ-LINE stops on NL and there is one extra return value. The callers pass a mode flag:
; 0 = raw bytes (READ-FILE), 1 = line mode (READ-LINE: LF->CR substitution, stop at NL).

!if FASTLOAD {
; Native inner loop ( c-addr u1 fileid mode -- u2 true ). The interpreted
; per-character loop it replaces (see the !else branch) executed ~25 tokens
; plus a colon-word EXECUTE per character - measured at ~616K cycles per
; source line, which made INCLUDE ~75% line-reading overhead. This does the
; same work in a tight loop: CHKIN once, then CHRIN + READST per character.
+header ~readgen_native, ~readgen_native_n
	+code
	+dpop
	sta _scratch			; mode (0 = bytes, 1 = line)
	+dpop
	sta _scratch_1			; fileid
	tax
	beq rgn_nochkin			; 0 = keyboard, already the default input
	jsr CHKIN
rgn_nochkin:
	+dpop				; u1
	+stax _scratch_2
	lda _dtop			; cur = c-addr (c-addr itself stays on the
	sta _rscratch			; stack; it is replaced by u2 at the end)
	clc
	adc _scratch_2
	sta _wscratch			; limit = c-addr + u1
	lda _dtop+1
	sta _rscratch+1
	adc _scratch_2+1
	sta _wscratch+1
rgn_loop:
	lda _rscratch			; cur >= limit? buffer full - done
	cmp _wscratch
	lda _rscratch+1
	sbc _wscratch+1
	bcs rgn_done
	jsr CHRIN			; next char from the file
	ldx _scratch			; line mode: LF -> CR (PC-style text files,
	beq rgn_store			; same substitution the old xreadchar did)
	cmp #10
	bne rgn_store
	lda #NEW_LINE
rgn_store:
	ldy #0
	sta (_rscratch),y		; append to the buffer
	pha
	inc _rscratch
	bne rgn_nc
	inc _rscratch+1
rgn_nc:
	jsr READST			; CBM protocol: status after every byte;
	tax				; the byte just read is still valid
	pla				; the char, for the NL check
	cpx #0
	beq rgn_noeof
	pha				; EOF: latch the per-file flag (blocks the
	jsr rgn_seteof			; next read attempt via readgen's pre-check),
	pla				; then still handle a simultaneous final NL
	ldy _scratch
	beq rgn_done
	cmp #NEW_LINE
	bne rgn_done
	jsr rgn_uncount
	jmp rgn_done
rgn_noeof:
	ldy _scratch			; line mode: stop at NEW_LINE (stored in the
	beq rgn_loop			; buffer but excluded from the count, exactly
	cmp #NEW_LINE			; like the interpreted version's ONEMINUS)
	bne rgn_loop
	jsr rgn_uncount
rgn_done:
	jsr CLRCHN
	sec				; u2 = cur - c-addr, replacing c-addr on the
	lda _rscratch			; stack
	sbc _dtop
	pha
	lda _rscratch+1
	sbc _dtop+1
	tax
	pla
	+stax _dtop
	lda #$ff			; flag = true (the EOF-before-anything false
	tax				; case is readgen's pre-check, not ours)
	jmp dpush_and_next

rgn_uncount:				; NL: cur--
	lda _rscratch
	bne rgn_nd
	dec _rscratch+1
rgn_nd:
	dec _rscratch
	rts

rgn_seteof:				; _eoffiles |= (1 << fileid)
	lda #1
	sta _scratch_2
	lda #0
	sta _scratch_2+1
	ldx _scratch_1
	beq rgn_se_or
rgn_se_sh:
	asl _scratch_2
	rol _scratch_2+1
	dex
	bne rgn_se_sh
rgn_se_or:
	lda _eoffiles
	ora _scratch_2
	sta _eoffiles
	lda _eoffiles+1
	ora _scratch_2+1
	sta _eoffiles+1
	rts

; ( c-addr u1 fileid mode -- u2 flag ior ) - the pre-check and the status
; read stay at the Forth level; only the per-character loop went native.
+header ~readgen, ~readgen_n
	+forth
	+token tor, dup			; mode to the rstack; check the EOF flag
	+literal _eoffiles
	+token getbit
	+qbranch_fwd readgen_good
	+token twodrop, drop, rdrop, zero, false, zero, exit	; three 0s, flag false
readgen_good:
	+token rfrom, readgen_native, c64iostatus, exit
} else {
; The per-character reader words, used only by the interpreted readgen below
; (the FASTLOAD builds read characters inline in readgen_native instead).
+header ~xreadchar, ~xreadchar_n
	+code
	jsr CHRIN
	ldx #0
;	and #$7F		; Ignore high bit (so Shift-Space is not a problem)
	cmp #10			; Do two substitutions: \n -> \r and \t -> ' ' (actually, everything until \t)
	bne +
	lda #NEW_LINE
+:
;	bcs +
;	lda #32
;+:
	jmp dpush_and_next

+header ~xreadcharchecked, ~xreadcharchecked_n
	+forth
	+token xreadchar, dup
	+literal NEW_LINE
	+token equal, exit

+header ~xreadbyte, ~xreadbyte_n
	+code
	jsr CHRIN
	ldx #0
	+dpush
	lda #0
	tax
	jmp dpush_and_next

_bytereader = _scratch_1

+header ~readgen, ~readgen_n
	+forth
	+literal _bytereader
	+token cpoke
	+token dup
	+literal _eoffiles
	+token getbit
	+qbranch_fwd readgen_good
	+token twodrop, drop, zero, false, zero, exit	; remove three parameters and put three 0s
readgen_good:
	+token dup, tor, setread, swap, dup, rot, add, over	; c-addr, c-addr-limit, current; fileid is accessible on the rstack
readgen_loop:
	+token twodup, swap, uless			; compare current < c-addr-limit
	+qbranch_fwd readgen_done			; finished?
	+literal _bytereader
	+token cpeek, execute
	+token tor, over, cpoke, oneplus, rfrom	; append to buffer
	+token c64iseof, twodup, or	; top of the stack: NL, EOF, true if either is set
	+qbranch_fwd readgen_continue
	+qbranch_fwd readgen_noteof
	+token rat
	+literal _eoffiles
	+token setbit						; just set the flag, it will block the following attempts
readgen_noteof:
	+qbranch_fwd readgen_done
	+token oneminus						; NL is not supposed to be included in the count
readgen_done:
	+token nip, swap, sub				; drop c-addr-limit; current - c-addr
	+token zero, setread
	+token rdrop, true, c64iostatus, exit
readgen_continue:
	+token twodrop
	+branch readgen_loop					; remove both NL and EOF flags and proceed to the next char
}

; Close file handles 3-14, this is used in ABORT to reset the error state
close_open_files:
	lda #3
	sta _scratch
-:
	lda _scratch
	cmp #15
	beq +
	jsr CLOSE
	inc _scratch
	bne -
+:
	lda #7		; protect channels 0-2 and 15
	ldx #128
	+stax _openfiles
	rts

; !warn "fileio_c64 module compiled to ", *-fileio_module_start, " bytes"
