\ ASMDEMO.FTH - practical "assembly inside Forth" examples for the X16.
\ ===========================================================================
\ Load the assembler first:   S" ASSEMBLER.FTH" INCLUDED   S" ASMDEMO.FTH" INCLUDED
\
\ Why drop to assembly?  A CODE word runs at raw 6502 speed with no token /
\ inner-interpreter overhead, so tight inner loops over memory (fills, blits,
\ checksums, decompressors, collision scans) are far faster than the equivalent
\ Forth DO..LOOP.  Two workhorse examples follow, each with a correctness self
\ test and a speed comparison against the pure-Forth version.
\
\ Model reminder (see ASMTEST.FTH):
\   DTOP = 16-bit top of stack (zero page).  POP -> A=lo X=hi and drops one cell.
\   PUSH pushes A=lo X=hi.  N..N+7 = scratch bytes usable within one CODE word.
\   Addressing: n # (immediate)  addr (absolute/zp)  addr ,X  addr ,Y
\               addr )Y (indirect,Y)  addr X) (indexed,X).  End with NEXT JMP,.

DECIMAL

\ ---------------------------------------------------------------------------
\ tiny self-test helper
\ ---------------------------------------------------------------------------
VARIABLE D#OK   VARIABLE D#BAD   0 D#OK !   0 D#BAD !
: DCHECK ( got expect -- )
   2DUP = IF 1 D#OK +! ."   [OK]  " ELSE 1 D#BAD +! ."   [FAIL] " THEN
   ." want " . ." got " . CR ;

\ ===========================================================================
\ 1. AFILLB ( c-addr u byte -- )   fill u bytes of memory with a byte value.
\    Same stack picture as the standard FILL, but hand-written in 6502.
\ ===========================================================================
CODE AFILLB ( c-addr u byte -- )
   POP JSR, N 4 + STA,                     \ N+4 = byte
   POP JSR, N 2 + STA, TXA, N 3 + STA,     \ N+2/N+3 = count (u)
   DTOP LDA, N STA, DTOP 1+ LDA, N 1+ STA, \ N/N+1 = destination pointer
   POP JSR,                                 \ drop c-addr from the stack
   0 # LDY,
   N 2 + LDA, N 3 + ORA,                    \ count == 0 ?  (skip loop if so)
   BNE: IF,
      BEGIN,
         N 4 + LDA, N )Y STA,               \ *ptr = byte
         N INC, BEQ: IF, N 1+ INC, THEN,    \ ptr++  (16-bit)
         N 2 + LDA, BEQ: IF, N 3 + DEC, THEN, N 2 + DEC,   \ count--
         N 2 + LDA, N 3 + ORA,              \ count == 0 ?
      BEQ: UNTIL,
   THEN,
   NEXT JMP,
END-CODE

\ pure-Forth equivalent, for the speed comparison
: FFILLB ( c-addr u byte -- )
   ROT ROT OVER + SWAP ?DO DUP I C! LOOP DROP ;

\ ===========================================================================
\ 2. AXOR ( c-addr u -- x )   XOR checksum of a memory block.
\ ===========================================================================
CODE AXOR ( c-addr u -- x )
   POP JSR, N 2 + STA, TXA, N 3 + STA,      \ N+2/N+3 = count (u)
   DTOP LDA, N STA, DTOP 1+ LDA, N 1+ STA,  \ N/N+1 = source pointer (DTOP kept)
   0 # LDY,
   0 # LDA, N 4 + STA,                       \ acc = 0
   N 2 + LDA, N 3 + ORA,
   BNE: IF,
      BEGIN,
         N )Y LDA, N 4 + EOR, N 4 + STA,     \ acc ^= *ptr
         N INC, BEQ: IF, N 1+ INC, THEN,
         N 2 + LDA, BEQ: IF, N 3 + DEC, THEN, N 2 + DEC,
         N 2 + LDA, N 3 + ORA,
      BEQ: UNTIL,
   THEN,
   N 4 + LDA, DTOP STA, 0 # LDA, DTOP 1+ STA, \ DTOP = acc  (result replaces c-addr)
   NEXT JMP,
END-CODE

: FXOR ( c-addr u -- x )
   0 ROT ROT OVER + SWAP ?DO I C@ XOR LOOP ;

\ ===========================================================================
\ Buffers + demo
\ ===========================================================================
CREATE BIGBUF 4096 ALLOT
CREATE DBUF 1 C, 2 C, 4 C, 8 C, 16 C, 32 C, 64 C, 128 C,

: ASMDEMO-TEST ( -- )
   CR .( -- correctness --) CR
   BIGBUF 4096 0 AFILLB                       \ clear
   BIGBUF 100 55 AFILLB                       \ fill first 100 with 55
   .( AFILLB[0]  )  BIGBUF C@         55 DCHECK
   .( AFILLB[99] )  BIGBUF 99 + C@    55 DCHECK
   .( AFILLB[100])  BIGBUF 100 + C@   0  DCHECK
   .( AXOR DBUF  )  DBUF 8 AXOR       255 DCHECK    \ 1^2^4^..^128 = 255
   .( AXOR==FXOR )  DBUF 8 AXOR  DBUF 8 FXOR DCHECK
   CR ." Demo: " D#OK @ . ." ok, " D#BAD @ . ." failed" CR ;

: JIF ( -- n )  TICKS DROP ;   \ low 16 bits of the jiffy clock (60 Hz)

: ASMDEMO-BENCH ( -- )
   CR .( -- speed: fill 4096 bytes x40 --) CR
   JIF  40 0 DO BIGBUF 4096 0  FFILLB LOOP  JIF SWAP -
   ." Forth FFILLB: " . ." jiffies" CR
   JIF  40 0 DO BIGBUF 4096 0  AFILLB LOOP  JIF SWAP -
   ." Asm   AFILLB: " . ." jiffies" CR
   .( -- speed: xor 4096 bytes x40 --) CR
   JIF  40 0 DO BIGBUF 4096 FXOR DROP LOOP  JIF SWAP -
   ." Forth FXOR:   " . ." jiffies" CR
   JIF  40 0 DO BIGBUF 4096 AXOR DROP LOOP  JIF SWAP -
   ." Asm   AXOR:   " . ." jiffies" CR ;

: ASMDEMO ( -- )  ASMDEMO-TEST ASMDEMO-BENCH ;
