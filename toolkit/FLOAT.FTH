\ FLOAT.FTH - floating point for ForthX16 builds without baked FP (FPCORE=0,
\ the PRG builds). CODE words over the BASIC ROM FP package (bank 4) - the
\ same routines the baked version used. Self-contained: brings its own float
\ stack and references only fixed addresses (KERNAL jsrfar $FF6E, bank-4 ROM
\ entries, the FAC zero-page cells, CHRGET at $E7).
\ Loads ASSEMBLER.FTH itself. After loading, float literals (1.5 etc.) work:
\ the core's DEFERred >FLOAT hook is pointed at the parser defined here.
\ Works on all default builds (PRG, bank-9 ROM, cart) - the ROM images embed
\ the conventional jsrfar stub at $FF6E so the bank-4 calls here work with
\ the Forth bank active. Only a custom FPCORE=1 build (FP baked in) must NOT
\ load this file: its >FLOAT is not deferred and IS >FLOAT would corrupt it.

S" ASSEMBLER.FTH" INCLUDED

ONLY FORTH DEFINITIONS
HEX

\ --- the float stack: 16 x 5-byte MFLPT floats, growing downward ------------
50 BUFFER: (FSTK)
(FSTK) 50 + CONSTANT (FSTK0)
VARIABLE FSP
: FCLEAR (FSTK0) FSP ! ;
FCLEAR

\ --- shared helper subroutines (plain machine code, not words) --------------
ALSO ASSEMBLER

\ emit: jsr $FF6E (KERNAL jsrfar) / !word addr / !byte 4 (BASIC bank)
: BANK4, ( addr -- ) FF6E JSR, , 04 C, ;

HERE \ FAC = the top float (movfm wants A=lo Y=hi of the source)
  FSP LDA, FSP 1+ LDY, F0BD BANK4, RTS,
CONSTANT (FACTOP)

HERE \ N+2/N+3 = FSP+5 (address of the second float)
  CLC, FSP LDA, 5 # ADC, N 2 + STA,
  FSP 1+ LDA, 0 # ADC, N 3 + STA, RTS,
CONSTANT (FSP5N)

HERE \ FAC = the second float
  (FSP5N) JSR, N 2 + LDA, N 3 + LDY, F0BD BANK4, RTS,
CONSTANT (FACDEEP)

HERE \ drop the top float (FSP += 5)
  CLC, FSP LDA, 5 # ADC, FSP STA,
  FSP 1+ LDA, 0 # ADC, FSP 1+ STA, RTS,
CONSTANT (FDROP5)

HERE \ drop 2 floats, push FAC as the result (movmf wants X=lo Y=hi)
  (FDROP5) JSR, FSP LDX, FSP 1+ LDY, F0EC BANK4, RTS,
CONSTANT (FBINST)

HERE \ overwrite the top float with FAC (unary result)
  FSP LDX, FSP 1+ LDY, F0EC BANK4, RTS,
CONSTANT (FSTORETOP)

HERE \ push FAC as a new top float
  SEC, FSP LDA, 5 # SBC, FSP STA,
  FSP 1+ LDA, 0 # SBC, FSP 1+ STA,
  FSP LDX, FSP 1+ LDY, F0EC BANK4, RTS,
CONSTANT (FPUSHFAC)

HERE \ N/N+1 = FSP value (zero-page pointer to the top float)
  FSP LDA, N STA, FSP 1+ LDA, N 1+ STA, RTS,
CONSTANT (FSPN)

PREVIOUS

\ --- conversion and arithmetic ----------------------------------------------
CODE S>F ( n -- ) ( F: -- r )
  DTOP 1+ LDA, DTOP LDY, F511 BANK4,
  POP JSR, (FPUSHFAC) JSR, NEXT JMP,
END-CODE

CODE F>S ( -- n ) ( F: r -- )
  (FACTOP) JSR, (FDROP5) JSR, F51A BANK4,
  TAX, TYA, PUSH JSR, NEXT JMP,
END-CODE

CODE F+ ( F: r1 r2 -- r1+r2 )
  (FACDEEP) JSR, FSP LDA, FSP 1+ LDY, F66F BANK4,
  (FBINST) JSR, NEXT JMP,
END-CODE

CODE F- ( F: r1 r2 -- r1-r2 )
  (FACTOP) JSR, (FSP5N) JSR, N 2 + LDA, N 3 + LDY, EE47 BANK4,
  (FBINST) JSR, NEXT JMP,
END-CODE

CODE F* ( F: r1 r2 -- r1*r2 )
  (FACDEEP) JSR, FSP LDA, FSP 1+ LDY, F7DE BANK4,
  (FBINST) JSR, NEXT JMP,
END-CODE

CODE F/ ( F: r1 r2 -- r1/r2 )
  (FACTOP) JSR, (FSP5N) JSR, N 2 + LDA, N 3 + LDY, F028 BANK4,
  (FBINST) JSR, NEXT JMP,
END-CODE

CODE FSQRT ( F: r -- sqrt )
  (FACTOP) JSR, F9F5 BANK4, (FSTORETOP) JSR, NEXT JMP,
END-CODE

CODE FSIN (FACTOP) JSR, F557 BANK4, (FSTORETOP) JSR, NEXT JMP, END-CODE
CODE FCOS (FACTOP) JSR, F550 BANK4, (FSTORETOP) JSR, NEXT JMP, END-CODE
CODE FTAN (FACTOP) JSR, F5A2 BANK4, (FSTORETOP) JSR, NEXT JMP, END-CODE
CODE FATAN (FACTOP) JSR, F5FE BANK4, (FSTORETOP) JSR, NEXT JMP, END-CODE
CODE FLN (FACTOP) JSR, EF7A BANK4, (FSTORETOP) JSR, NEXT JMP, END-CODE
CODE FEXP (FACTOP) JSR, F403 BANK4, (FSTORETOP) JSR, NEXT JMP, END-CODE

\ --- float-stack manipulation -----------------------------------------------
CODE FDROP ( F: r -- )
  (FDROP5) JSR, NEXT JMP,
END-CODE

CODE FNEGATE ( F: r -- -r )
  (FSPN) JSR, 1 # LDY, N )Y LDA, 80 # EOR, N )Y STA, NEXT JMP,
END-CODE

CODE FABS ( F: r -- |r| )
  (FSPN) JSR, 1 # LDY, N )Y LDA, 7F # AND, N )Y STA, NEXT JMP,
END-CODE

CODE FDUP ( F: r -- r r )
  (FSPN) JSR,
  SEC, FSP LDA, 5 # SBC, FSP STA, N 2 + STA,
  FSP 1+ LDA, 0 # SBC, FSP 1+ STA, N 3 + STA,
  4 # LDY,
  BEGIN, N )Y LDA, N 2 + )Y STA, DEY, BMI: UNTIL,
  NEXT JMP,
END-CODE

CODE FSWAP ( F: r1 r2 -- r2 r1 )
  (FSPN) JSR, (FSP5N) JSR,
  4 # LDY,
  BEGIN,
    N )Y LDA, PHA, N 2 + )Y LDA, N )Y STA, PLA, N 2 + )Y STA,
    DEY,
  BMI: UNTIL,
  NEXT JMP,
END-CODE

CODE FOVER ( F: r1 r2 -- r1 r2 r1 )
  (FSP5N) JSR,
  SEC, FSP LDA, 5 # SBC, FSP STA, N STA,
  FSP 1+ LDA, 0 # SBC, FSP 1+ STA, N 1+ STA,
  4 # LDY,
  BEGIN, N 2 + )Y LDA, N )Y STA, DEY, BMI: UNTIL,
  NEXT JMP,
END-CODE

\ --- tests and comparison -----------------------------------------------------
CODE F0= ( -- flag ) ( F: r -- )
  (FSPN) JSR, (FDROP5) JSR,
  0 # LDY, N )Y LDA,
  BNE: IF, 0 # LDA, ELSE, FF # LDA, THEN,
  TAX, PUSH JSR, NEXT JMP,
END-CODE

CODE F0< ( -- flag ) ( F: r -- )
  (FSPN) JSR, (FDROP5) JSR,
  0 # LDY, N )Y LDA,
  BNE: IF,
    1 # LDY, N )Y LDA,
    BMI: IF, FF # LDA, ELSE, 0 # LDA, THEN,
  ELSE, 0 # LDA, THEN,
  TAX, PUSH JSR, NEXT JMP,
END-CODE

CODE (FCMP) \ FAC = r1 - r2; both floats stay on the stack
  (FACTOP) JSR, (FSP5N) JSR, N 2 + LDA, N 3 + LDY, EE47 BANK4, NEXT JMP,
END-CODE

: FNIP ( F: r1 r2 -- r2 ) FSWAP FDROP ;
: F< ( -- flag ) ( F: r1 r2 -- )
  (FCMP) FDROP FDROP
  C3 C@ IF C8 C@ 80 AND 0<> ELSE FALSE THEN ;
: FMAX ( F: r1 r2 -- max ) (FCMP)
  C3 C@ 0= IF FDROP EXIT THEN
  C8 C@ 80 AND IF FNIP ELSE FDROP THEN ;
: FMIN ( F: r1 r2 -- min ) (FCMP)
  C3 C@ 0= IF FDROP EXIT THEN
  C8 C@ 80 AND IF FDROP ELSE FNIP THEN ;

\ --- memory access and defining words ----------------------------------------
CODE F! ( f-addr -- ) ( F: r -- )
  (FSPN) JSR,
  DTOP LDA, N 2 + STA, DTOP 1+ LDA, N 3 + STA,
  4 # LDY,
  BEGIN, N )Y LDA, N 2 + )Y STA, DEY, BMI: UNTIL,
  (FDROP5) JSR, POP JSR, NEXT JMP,
END-CODE

CODE F@ ( f-addr -- ) ( F: -- r )
  DTOP LDA, N STA, DTOP 1+ LDA, N 1+ STA,
  SEC, FSP LDA, 5 # SBC, FSP STA, N 2 + STA,
  FSP 1+ LDA, 0 # SBC, FSP 1+ STA, N 3 + STA,
  4 # LDY,
  BEGIN, N )Y LDA, N 2 + )Y STA, DEY, BMI: UNTIL,
  POP JSR, NEXT JMP,
END-CODE

: FVARIABLE ( "name" -- ) CREATE 5 ALLOT ;
: FCONSTANT ( "name" -- ) ( F: r -- ) CREATE HERE F! 5 ALLOT DOES> F@ ;

\ --- output and input ---------------------------------------------------------
CODE (F$) ( -- z-addr ) \ pop the top float, render via ROM fout
  (FACTOP) JSR, (FDROP5) JSR, F234 BANK4,
  N STA, TYA, TAX, N LDA,
  PUSH JSR, NEXT JMP,
END-CODE

: F. ( F: r -- ) (F$) BEGIN DUP C@ ?DUP WHILE EMIT 1+ REPEAT DROP SPACE ;

CODE (FIN) ( u -- flag ) \ parse the z-string at PAD via ROM fin; u = length
  PAD 1- FF AND # LDA, EE STA,
  PAD 1- 8 RSHIFT # LDA, EF STA,
  20 C, 00E7 ,          \ jsr $00E7 - CHRGET (raw bytes: JSR takes no zp mode)
  FF6E JSR, E039 , 04 C,
  CLC, DTOP LDA, PAD FF AND # ADC, N STA,
  DTOP 1+ LDA, PAD 8 RSHIFT # ADC, N 1+ STA,
  EE LDA, N EOR, N 2 + STA,
  EF LDA, N 1+ EOR, N 2 + ORA,
  BEQ: IF, (FPUSHFAC) JSR, FF # LDA, ELSE, 0 # LDA, THEN,
  DTOP STA, DTOP 1+ STA, NEXT JMP,
END-CODE

: (>FLT) ( c-addr u -- flag )
  DUP 0= IF 2DROP FALSE EXIT THEN
  OVER C@ DUP 2B 2F WITHIN SWAP 30 3A WITHIN OR
  0= IF 2DROP FALSE EXIT THEN
  TUCK PAD SWAP CMOVE
  0 OVER PAD + C!
  (FIN) ;

' (>FLT) IS >FLOAT

\ --- power (same construction the baked version used) -------------------------
: FPOW ( F: x y -- x^y ) FSWAP FLN F* FEXP ;
: F** FPOW ;

ONLY FORTH DEFINITIONS
DECIMAL
.( FLOAT TOOLKIT LOADED ) CR
