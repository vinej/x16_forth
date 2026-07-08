\ ASMTEST.FTH - test suite for toolkit/ASSEMBLER.FTH (Ragsdale FIG 6502 asm)
\ ===========================================================================
\ USAGE (load the assembler first, then this file):
\     S" ASSEMBLER.FTH" INCLUDED
\     S" ASMTEST.FTH"   INCLUDED
\ Prints [OK]/[FAIL] per case and a final summary. Exercises: implied opcodes,
\ immediate / absolute / zero-page / ,X / ,Y / (zp),Y / (zp,X) addressing,
\ 16-bit ALU on DTOP, the PUSH/POP stack glue, N scratch, and the structured
\ control words IF, ELSE, THEN, BEGIN, UNTIL,.  Notes on the model:
\   DTOP = 16-bit top-of-stack (zero page).  POP -> A=lo X=hi and drops.
\   PUSH pushes A=lo X=hi as new top.  N..N+7 = scratch usable in one word.
\   Every CODE word ends with  NEXT JMP,  then  END-CODE .

DECIMAL

VARIABLE ASM#OK   VARIABLE ASM#BAD
0 ASM#OK !   0 ASM#BAD !

: CHECK ( got expect -- )        \ compare, tally, report
   2DUP = IF 1 ASM#OK +! ."   [OK]  " ELSE 1 ASM#BAD +! ."   [FAIL] " THEN
   ." want " . ." got " . CR ;

: ASM-SUMMARY ( -- )
   CR ." ===== ASSEMBLER TEST SUMMARY =====" CR
   ASM#OK @ . ." passed, " ASM#BAD @ . ." failed" CR
   ASM#BAD @ 0= IF ." *** ALL PASS ***" ELSE ." *** FAILURES ***" THEN CR ;

\ --- 1. implied + 16-bit shift (ASL/ROL on DTOP) --------------------------
CODE A2* ( n -- 2n )
   DTOP ASL, DTOP 1+ ROL,
   NEXT JMP,
END-CODE

\ --- 2. 16-bit increment with carry into the high byte --------------------
CODE A1+ ( n -- n+1 )
   DTOP INC,
   BEQ: IF, DTOP 1+ INC, THEN,
   NEXT JMP,
END-CODE

\ --- 3. 16-bit decrement with borrow -------------------------------------
CODE A1- ( n -- n-1 )
   DTOP LDA,
   BEQ: IF, DTOP 1+ DEC, THEN,
   DTOP DEC,
   NEXT JMP,
END-CODE

\ --- 4. negate: 0 - n (SEC/SBC, immediate + zero page) -------------------
CODE ANEG ( n -- -n )
   SEC,
   0 # LDA, DTOP SBC, DTOP STA,
   0 # LDA, DTOP 1+ SBC, DTOP 1+ STA,
   NEXT JMP,
END-CODE

\ --- 5. byte swap of the two halves of DTOP (uses N scratch) -------------
CODE ASWAPB ( n -- byteswapped )
   DTOP LDA, N STA,
   DTOP 1+ LDA, DTOP STA,
   N LDA, DTOP 1+ STA,
   NEXT JMP,
END-CODE

\ --- 6. mask low nibble (immediate AND, clear high byte) -----------------
CODE AAND15 ( n -- n&15 )
   15 # LDA, DTOP AND, DTOP STA,
   0 # LDA, DTOP 1+ STA,
   NEXT JMP,
END-CODE

\ --- 7. constant via PUSH ( -- 7 ) ---------------------------------------
CODE ALIT7 ( -- 7 )
   7 # LDA, 0 # LDX, PUSH JSR,
   NEXT JMP,
END-CODE

\ --- 8. binary add: POP second operand, add to DTOP ----------------------
CODE AADD ( a b -- a+b )
   POP JSR,  N STA, TXA, N 1+ STA,
   CLC,
   DTOP LDA, N ADC, DTOP STA,
   DTOP 1+ LDA, N 1+ ADC, DTOP 1+ STA,
   NEXT JMP,
END-CODE

\ --- 9. binary subtract --------------------------------------------------
CODE ASUB ( a b -- a-b )
   POP JSR,  N STA, TXA, N 1+ STA,
   SEC,
   DTOP LDA, N SBC, DTOP STA,
   DTOP 1+ LDA, N 1+ SBC, DTOP 1+ STA,
   NEXT JMP,
END-CODE

\ --- 10. loop: sum 1..n with BEGIN, / UNTIL, -----------------------------
CODE ASUM ( n -- 1+2+..+n )
   0 # LDA, N STA, N 1+ STA,          \ acc = 0 in N/N+1
   BEGIN,
      CLC,
      N LDA, DTOP ADC, N STA,          \ acc += DTOP  (16-bit)
      N 1+ LDA, DTOP 1+ ADC, N 1+ STA,
      DTOP LDA,                         \ DTOP-- (16-bit)
      BEQ: IF, DTOP 1+ DEC, THEN,
      DTOP DEC,
      DTOP LDA, DTOP 1+ ORA,            \ Z = (DTOP == 0)
   BEQ: UNTIL,
   N LDA, DTOP STA, N 1+ LDA, DTOP 1+ STA,
   NEXT JMP,
END-CODE

\ --- 11. IF, THEN, on the sign bit: absolute value -----------------------
CODE AABS ( n -- |n| )
   DTOP 1+ LDA,
   BMI: IF,
      SEC,
      0 # LDA, DTOP SBC, DTOP STA,
      0 # LDA, DTOP 1+ SBC, DTOP 1+ STA,
   THEN,
   NEXT JMP,
END-CODE

\ --- 12. IF, ELSE, THEN, : max of two -----------------------------------
CODE AMAX ( a b -- max )
   POP JSR,  N STA, TXA, N 1+ STA,      \ N = b, DTOP = a
   SEC,                                  \ compare a - b (unsigned high first)
   DTOP 1+ LDA, N 1+ CMP,
   BEQ: IF,                              \ high bytes equal -> compare low
      DTOP LDA, N CMP,
   THEN,
   BCC: IF,                              \ a < b : result = b
      N LDA, DTOP STA, N 1+ LDA, DTOP 1+ STA,
   THEN,
   NEXT JMP,
END-CODE

\ --- 13-15. buffer + indexed / indirect addressing -----------------------
CREATE TBUF 8 ALLOT

CODE AFILL ( -- )                        \ TBUF[i] = i for i = 0..7 (STA abs,X)
   0 # LDX,
   BEGIN,
      TXA, TBUF ,X STA,
      INX, 8 # CPX,
   BEQ: UNTIL,
   NEXT JMP,
END-CODE

CODE AGETY ( -- TBUF[4] )                \ LDA (N),Y  indirect indexed
   TBUF 255 AND # LDA, N STA,
   TBUF 256 / # LDA, N 1+ STA,
   4 # LDY,  N )Y LDA,
   0 # LDX, PUSH JSR,
   NEXT JMP,
END-CODE

CODE AGETX ( -- TBUF[6] )                \ LDA (N,X)  indexed indirect
   TBUF 6 + 255 AND # LDA, N STA,
   TBUF 6 + 256 / # LDA, N 1+ STA,
   0 # LDX,  N X) LDA,
   0 # LDX, PUSH JSR,
   NEXT JMP,
END-CODE

\ ===========================================================================
\ Run them
\ ===========================================================================
.( Running ASSEMBLER.FTH tests...) CR

.( A2* 21)      21    A2*     42    CHECK
.( A2* 5000)    5000  A2*     10000 CHECK
.( A1+ 41)      41    A1+     42    CHECK
.( A1+ 255)     255   A1+     256   CHECK
.( A1+ 65535)   65535 A1+     0     CHECK
.( A1- 256)     256   A1-     255   CHECK
.( A1- 1)       1     A1-     0     CHECK
.( ANEG 5)      5     ANEG    -5    CHECK
.( ANEG -5)     -5    ANEG    5     CHECK
.( ASWAPB)      4660  ASWAPB  13330 CHECK
.( AAND15)      43981 AAND15  13    CHECK
.( ALIT7)             ALIT7   7     CHECK
.( AADD)        100 23 AADD   123   CHECK
.( AADD big)    30000 4000 AADD 34000 CHECK
.( ASUB)        100 23 ASUB   77    CHECK
.( ASUM 5)      5     ASUM    15    CHECK
.( ASUM 10)     10    ASUM    55    CHECK
.( ASUM 100)    100   ASUM    5050  CHECK
.( AABS -7)     -7    AABS    7     CHECK
.( AABS 7)      7     AABS    7     CHECK
.( AMAX a>b)    99 12 AMAX    99    CHECK
.( AMAX a<b)    12 99 AMAX    99    CHECK
.( AMAX eq)     40 40 AMAX    40    CHECK

AFILL
.( AFILL[0])    TBUF C@       0     CHECK
.( AFILL[5])    TBUF 5 + C@   5     CHECK
.( AFILL[7])    TBUF 7 + C@   7     CHECK
.( AGETY[4])          AGETY   4     CHECK
.( AGETX[6])          AGETX   6     CHECK

ASM-SUMMARY
