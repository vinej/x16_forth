\ HP50.FTH - an HP-50g-STYLE RPN calculator for ForthX16 / Commander X16.
\ ===========================================================================
\ Phase 1: real numbers.  A typed object stack (like the HP stack, which holds
\ objects rather than raw cells), an HP-style stack display with angle and
\ number-format modes, the everyday scientific-calculator command set, and an
\ RPN command-line parser.
\
\   INCLUDE HP50.FTH
\   HP                       \ start the interactive calculator (OFF to quit)
\   RUN" 3 4 + 5 *"          \ or run a line non-interactively (for scripts/tests)
\
\ Numbers push onto the stack; commands act on it, RPN-style:
\   RUN" 45 SIN"    RUN" 2 10 ^"    RUN" PI 2 /"    RUN" 100 LN"
\ Modes:  DEG RAD  |  STD  |  n FIX      Stack: DUP DROP SWAP OVER ROT CLEAR DEPTH
\
\ Needs only the built-in floating-point words.  Uses the X16's default
\ UPPERCASE character set (do not `14 EMIT` first, or PETSCII inverts case).
\ Reals carry ~9 significant digits (BASIC ROM floats); no CAS / symbolics.
\ ===========================================================================

DECIMAL

\ ===========================================================================
\ 1. FLOAT UTILITIES  (constants + double<->float, borrowed from MORTGAGE.FTH)
\ ===========================================================================
256 S>F FDUP F*   FCONSTANT F65536
1 S>F 2 S>F F/    FCONSTANT FHALF
1 S>F FATAN 4 S>F F*   FCONSTANT FPI      \ pi = 4*atan(1)
10 S>F FLN        FCONSTANT FLN10         \ ln 10
FVARIABLE FP10                            \ scratch: 10^n for the formatter

: -ROT   ROT ROT ;
: FABS   ( F: r -- |r| )   FDUP F0< IF FNEGATE THEN ;
: FPOW   ( F: x y -- x^y ) FSWAP FLN F* FEXP ;           \ x>0

\ signed double -> float (logical shift keeps the low word unsigned)
: D>F ( d -- ) ( F: -- r )
   S>F  F65536 F*
   DUP 8 RSHIFT S>F  256 S>F F*
   255 AND S>F  F+  F+ ;

\ non-negative float ( < 2^31 ) -> unsigned double ( lo hi )
: F>UD ( F: r -- ) ( -- ud )
   FDUP  F65536 F/  F>S
   DUP >R  S>F  F65536 F*  F-
   F>S  R> ;

: FFLOOR ( F: x -- floor )   F>UD D>F ;                  \ x >= 0
: TEN**  ( n -- ) ( F: -- 10^n )   1 S>F  0 ?DO 10 S>F F* LOOP ;

\ ---- 32-bit integer (double-cell) helpers --------------------------------
VARIABLE ML1  VARIABLE MH1  VARIABLE ML2  VARIABLE MH2
: D* ( d1 d2 -- d3 )                       \ low 32 bits of the product
   MH2 ! ML2 !  MH1 ! ML1 !
   ML1 @ ML2 @ UM*                         ( lo3 hi3 )
   ML1 @ MH2 @ *  +                        ( lo1*hi2 into hi3 )
   MH1 @ ML2 @ *  + ;                      ( hi1*lo2 into hi3 )
: DAND ( d1 d2 -- d3 )  ROT AND -ROT AND SWAP ;
: DOR  ( d1 d2 -- d3 )  ROT OR  -ROT OR  SWAP ;
: DXOR ( d1 d2 -- d3 )  ROT XOR -ROT XOR SWAP ;
: DNOT ( d -- d' )      INVERT SWAP INVERT SWAP ;
: F>SD ( F: r -- ) ( -- d )                \ signed float -> double (trunc toward 0)
   FDUP F0< IF FNEGATE F>UD DNEGATE ELSE F>UD THEN ;

\ ===========================================================================
\ 2. THE OBJECT STACK   (8-byte cells: [tag][5-byte float][spare])
\ ===========================================================================
16 CONSTANT MAXLVL
8  CONSTANT OCELL
0  CONSTANT T-REAL              \ real   : 5-byte float in bytes 1..5
1  CONSTANT T-INT               \ integer: 32-bit (double) in bytes 1..4

CREATE OSTK   MAXLVL OCELL * ALLOT
VARIABLE OSP   0 OSP !          \ number of items on the stack
CREATE OTMP   OCELL ALLOT

: OIDX@  ( index -- addr )  OCELL *  OSTK + ;
: OLVL   ( level -- addr )  OSP @ SWAP -  OIDX@ ;        \ level 1 = top
: OTAG   ( level -- tag )   OLVL C@ ;
: OINT?  ( level -- f )     OTAG T-INT = ;
: OCP    ( src dest -- )    OCELL CMOVE ;
: R@F    ( level -- ) ( F: -- r )   OLVL 1+ F@ ;         \ fetch a level's float
: R@D    ( level -- d )     OLVL 1+ 2@ ;                 \ fetch a level's int
: ODROP  ( -- )   OSP @ 1- 0 MAX OSP ! ;

: NEED1 ( -- f )  OSP @ 0 > ;
: NEED2 ( -- f )  OSP @ 1 > ;
: NEED3 ( -- f )  OSP @ 2 > ;
: OROOM ( -- f )  OSP @ MAXLVL < ;

\ ---- errors (shown once on the next redraw) --------------------------------
CREATE ENAME 32 ALLOT   VARIABLE ELEN   VARIABLE ERRF   0 ERRF !
: ERRMSG ( a u -- )   32 MIN DUP ELEN !  ENAME SWAP CMOVE  -1 ERRF ! ;
: UNDERR   S" TOO FEW ARGUMENTS" ERRMSG ;
: OVFERR   S" STACK FULL" ERRMSG ;
: DERR     S" BAD ARGUMENT VALUE" ERRMSG ;

: PUSHR ( F: r -- )
   OROOM 0= IF FDROP OVFERR EXIT THEN
   OSP @ OIDX@   T-REAL OVER C!   1+ F!   1 OSP +! ;
: PUSHI ( d -- )
   OROOM 0= IF 2DROP OVFERR EXIT THEN
   OSP @ OIDX@   T-INT OVER C!   1+ 2!   1 OSP +! ;

\ type-aware operand fetch: a level's value as a float, or as an integer
: OL>F ( level -- ) ( F: -- r )   DUP OINT? IF R@D D>F ELSE R@F THEN ;
: OL>I ( level -- d )             DUP OINT? IF R@D    ELSE R@F F>SD THEN ;

\ pop operands (they leave the object stack); ints are promoted to reals
: RUNPREP  ( -- ) ( F: -- r )      1 OL>F  ODROP ;
: RBINPREP ( -- ) ( F: -- r2 r1 )  2 OL>F 1 OL>F  ODROP ODROP ;
\ pop operands as 32-bit integers (reals truncated toward zero)
: IUNPREP  ( -- d )                1 OL>I  ODROP ;
: IBINPREP ( -- d2 d1 )            2 OL>I 1 OL>I  ODROP ODROP ;
: BOTHINT  ( -- f )                1 OINT?  2 OINT?  AND ;

\ ===========================================================================
\ 3. NUMBER FORMATTING  (right-justified STD / FIX, ~9 significant digits)
\ ===========================================================================
VARIABLE DISPMODE   0 DISPMODE !     \ 0 = STD, 1 = FIX
VARIABLE DISPDEC    4 DISPDEC !      \ decimals for FIX
VARIABLE ANGDEG    -1 ANGDEG !       \ -1 = degrees, 0 = radians
VARIABLE CBASE     10 CBASE !        \ integer base: 2 / 8 / 10 / 16

VARIABLE NDEC
VARIABLE NEGF
2VARIABLE IPD
CREATE NBUF 32 ALLOT   VARIABLE NP
CREATE FRB  16 ALLOT
: NBC ( c -- )   NBUF NP @ + C!  1 NP +! ;
: NBS ( a u -- ) 0 ?DO DUP I + C@ NBC LOOP DROP ;

\ format r to NDEC decimals into NBUF; returns ( a u ).  Integer and fraction
\ are digitized separately so  r*10^n  never overflows a 32-bit double.
: (F$) ( n -- a u ) ( F: r -- )
   0 NP !  NDEC !
   NDEC @ TEN** FP10 F!
   FDUP F0< DUP NEGF !  IF FNEGATE THEN          ( ) ( F: |r| )
   FHALF FP10 F@ F/ F+                            ( F: xr = |r| + 0.5/10^n )
   FDUP FFLOOR                                    ( F: xr ip )
   FDUP F>UD IPD 2!                               ( F: xr ip  -- ip saved )
   F-  FP10 F@ F*  F>UD                           ( fraclo frachi )
   <# NDEC @ ?DUP IF 0 DO # LOOP THEN #>          ( fa fu  -- n frac digits )
   DUP >R  FRB SWAP CMOVE  R>                     ( fu  -- frac now in FRB )
   NEGF @ IF [CHAR] - NBC THEN
   IPD 2@ <# #S #> NBS                            ( fu  -- integer part )
   NDEC @ IF [CHAR] . NBC  FRB SWAP NBS ELSE DROP THEN
   NBUF NP @ ;

VARIABLE DOTF
: HAS. ( a u -- f )                                \ does the string contain '.'?
   FALSE DOTF !
   0 ?DO  DUP I + C@ [CHAR] . = IF TRUE DOTF ! THEN  LOOP  DROP
   DOTF @ ;
: TRIMZ ( a u -- a u' )                            \ trim trailing 0s and a '.'
   2DUP HAS. 0= IF EXIT THEN
   BEGIN  DUP 0> IF 2DUP + 1- C@ [CHAR] 0 = ELSE FALSE THEN
   WHILE  1- REPEAT
   DUP 0> IF 2DUP + 1- C@ [CHAR] . = IF 1- THEN THEN ;

: FSTR ( -- a u ) ( F: r -- )
   DISPMODE @ IF DISPDEC @ (F$) ELSE 9 (F$) TRIMZ THEN ;

\ format a 32-bit integer d in the current base into NBUF; returns ( a u ).
\ Decimal is signed; other bases are unsigned with a trailing base letter.
: INT$ ( d -- a u )
   0 NP !
   BASE @ >R   CBASE @ BASE !
   CBASE @ 10 = IF  DUP >R DABS <# #S R> SIGN #>  ELSE  <# #S #>  THEN
   R> BASE !   NBS
   CBASE @ 10 <> IF
      CBASE @ 16 = IF [CHAR] H ELSE CBASE @ 8 = IF [CHAR] O ELSE [CHAR] B THEN THEN NBC
   THEN
   NBUF NP @ ;

\ format the object at a level into a string ( real or integer )
: OBJ$ ( level -- a u )
   DUP OINT? IF  R@D INT$  ELSE  R@F FSTR  THEN ;
: RJ$  ( a u width -- )   OVER - SPACES TYPE ;
: .LVL ( level width -- )   >R OBJ$ R> RJ$ ;

\ ===========================================================================
\ 4. THE DISPLAY
\ ===========================================================================
8 CONSTANT SHOWN
: STATUS ( -- )
   ." [ " ANGDEG @ IF ." DEG" ELSE ." RAD" THEN
   ."   " DISPMODE @ IF ." FIX " DISPDEC @ 0 .R ELSE ." STD" THEN
   CBASE @ 10 <> IF
      ."   " CBASE @ 16 = IF ." HEX" ELSE CBASE @ 8 = IF ." OCT" ELSE ." BIN" THEN THEN
   THEN
   ."   DEPTH " OSP @ 0 .R ."  ]" ;
: .STACK ( -- )
   CLS  STATUS CR
   ERRF @ IF ." *** " ENAME ELEN @ TYPE ."  ***"  0 ERRF !  CR THEN
   OSP @ 0= IF ." (EMPTY STACK)" CR EXIT THEN
   OSP @ SHOWN MIN
   BEGIN DUP 0> WHILE
      DUP 3 .R ." : "
      DUP 30 .LVL  CR
      1-
   REPEAT DROP ;

\ ===========================================================================
\ 5. COMMANDS  (each acts on the object stack)
\ ===========================================================================
\ ---- angle helpers ----
: >RAD ( F: a -- r )  ANGDEG @ IF FPI F* 180 S>F F/ THEN ;
: RAD> ( F: r -- a )  ANGDEG @ IF 180 S>F F* FPI F/ THEN ;
: QUARTER ( F: -- q ) ANGDEG @ IF 90 S>F ELSE FPI 2 S>F F/ THEN ;
: F<=0 ( F: x -- flag )  FDUP F0< F0= OR ;

\ ---- arithmetic (exact when both operands are integers, else real) ----
: RADD  NEED2 IF BOTHINT IF IBINPREP D+ PUSHI ELSE RBINPREP F+ PUSHR THEN ELSE UNDERR THEN ;
: RSUB  NEED2 IF BOTHINT IF IBINPREP D- PUSHI ELSE RBINPREP F- PUSHR THEN ELSE UNDERR THEN ;
: RMUL  NEED2 IF BOTHINT IF IBINPREP D* PUSHI ELSE RBINPREP F* PUSHR THEN ELSE UNDERR THEN ;
: RDIV  NEED2 IF 1 OL>F F0= IF DERR ELSE RBINPREP F/ PUSHR THEN ELSE UNDERR THEN ;
: RNEG  NEED1 IF 1 OINT? IF IUNPREP DNEGATE PUSHI ELSE RUNPREP FNEGATE PUSHR THEN
        ELSE UNDERR THEN ;
: RINV  NEED1 IF 1 OL>F F0= IF DERR ELSE RUNPREP 1 S>F FSWAP F/ PUSHR THEN ELSE UNDERR THEN ;
: RSQ   NEED1 IF 1 OINT? IF IUNPREP 2DUP D* PUSHI ELSE RUNPREP FDUP F* PUSHR THEN
        ELSE UNDERR THEN ;
: RABS  NEED1 IF 1 OINT? IF IUNPREP DABS PUSHI ELSE RUNPREP FABS PUSHR THEN
        ELSE UNDERR THEN ;
: RSQRT NEED1 IF 1 OL>F F0< IF DERR ELSE RUNPREP FSQRT PUSHR THEN ELSE UNDERR THEN ;
: R^    NEED2 IF
           2 OL>F F0< IF DERR EXIT THEN
           2 OL>F F0= IF RBINPREP FDROP FDROP 0 S>F PUSHR EXIT THEN
           RBINPREP FPOW PUSHR
        ELSE UNDERR THEN ;

\ ---- integer / bitwise / base (operands taken as 32-bit; reals truncated) ----
: cAND  NEED2 IF IBINPREP DAND PUSHI ELSE UNDERR THEN ;
: cOR   NEED2 IF IBINPREP DOR  PUSHI ELSE UNDERR THEN ;
: cXOR  NEED2 IF IBINPREP DXOR PUSHI ELSE UNDERR THEN ;
: cNOT  NEED1 IF IUNPREP DNOT PUSHI ELSE UNDERR THEN ;
: c->I  NEED1 IF 1 OINT? 0= IF RUNPREP F>SD PUSHI THEN ELSE UNDERR THEN ;
: c->R  NEED1 IF 1 OINT?    IF IUNPREP D>F  PUSHR THEN ELSE UNDERR THEN ;
: cBIN  2 CBASE ! ;   : cOCT  8 CBASE ! ;   : cDECB 10 CBASE ! ;   : cHEX 16 CBASE ! ;

\ ---- transcendental (always real; integers are promoted) ----
: RSIN  NEED1 IF RUNPREP >RAD FSIN PUSHR ELSE UNDERR THEN ;
: RCOS  NEED1 IF RUNPREP >RAD FCOS PUSHR ELSE UNDERR THEN ;
: RTAN  NEED1 IF RUNPREP >RAD FTAN PUSHR ELSE UNDERR THEN ;
: RATAN NEED1 IF RUNPREP FATAN RAD> PUSHR ELSE UNDERR THEN ;
: RASIN NEED1 IF RUNPREP FDUP FDUP F* FNEGATE 1 S>F F+ FSQRT F/ FATAN RAD> PUSHR
        ELSE UNDERR THEN ;
: RACOS NEED1 IF RUNPREP FDUP FDUP F* FNEGATE 1 S>F F+ FSQRT F/ FATAN RAD>
                QUARTER FSWAP F- PUSHR ELSE UNDERR THEN ;
: RLN   NEED1 IF 1 OL>F F<=0 IF DERR ELSE RUNPREP FLN PUSHR THEN ELSE UNDERR THEN ;
: REXP  NEED1 IF RUNPREP FEXP PUSHR ELSE UNDERR THEN ;
: RLOG  NEED1 IF 1 OL>F F<=0 IF DERR ELSE RUNPREP FLN FLN10 F/ PUSHR THEN ELSE UNDERR THEN ;
: RALOG NEED1 IF RUNPREP FLN10 F* FEXP PUSHR ELSE UNDERR THEN ;
: RPI   OROOM IF FPI PUSHR ELSE OVFERR THEN ;

\ ---- stack manipulation (generic cell moves, so future types work too) ----
: HDROP  NEED1 IF ODROP ELSE UNDERR THEN ;
: HDUP   NEED1 IF OROOM IF 1 OLVL  OSP @ OIDX@ OCP  1 OSP +! ELSE OVFERR THEN
         ELSE UNDERR THEN ;
: HOVER  NEED2 IF OROOM IF 2 OLVL  OSP @ OIDX@ OCP  1 OSP +! ELSE OVFERR THEN
         ELSE UNDERR THEN ;
: HSWAP  NEED2 IF
            1 OLVL 2 OLVL          ( a1 a2 )
            OVER OTMP OCP          \ tmp <- a1
            DUP >R  SWAP OCP       \ a1 <- a2
            OTMP R> OCP            \ a2 <- tmp
         ELSE UNDERR THEN ;
: HROT   NEED3 IF
            3 OLVL OTMP OCP        \ tmp <- L3
            2 OLVL 3 OLVL OCP      \ L3 <- L2
            1 OLVL 2 OLVL OCP      \ L2 <- L1
            OTMP 1 OLVL OCP        \ L1 <- tmp
         ELSE UNDERR THEN ;
: HCLEAR 0 OSP ! ;
: HDEPTH OROOM IF OSP @ S>D PUSHI ELSE OVFERR THEN ;

\ ---- modes ----
: cDEG  -1 ANGDEG ! ;
: cRAD   0 ANGDEG ! ;
: cSTD   0 DISPMODE ! ;
: cFIX   NEED1 IF RUNPREP F>S 0 MAX 9 MIN DISPDEC !  1 DISPMODE ! ELSE UNDERR THEN ;
VARIABLE QUITF
: cOFF  -1 QUITF ! ;

\ ===========================================================================
\ 6. COMMAND TABLE  (name -> xt, a simple linked list)
\ ===========================================================================
VARIABLE CMDLIST   0 CMDLIST !
: ,STR ( a u -- )  DUP C,  0 ?DO DUP C@ C, 1+ LOOP DROP ;
: DEFCMD ( xt -- )                         \ ' RSIN DEFCMD SIN
   HERE >R
   CMDLIST @ ,                             \ link
   ,                                       \ xt
   BL WORD COUNT ,STR                      \ name
   R> CMDLIST ! ;
: E>NEXT ( e -- e' )  @ ;
: E>XT   ( e -- xt )  2 + @ ;
: E>NAME ( e -- a u ) 4 + COUNT ;
: FIND-CMD ( a u -- xt|0 )
   CMDLIST @
   BEGIN DUP WHILE
      >R  2DUP  R@ E>NAME COMPARE 0=
      IF 2DROP R> E>XT EXIT THEN
      R> E>NEXT
   REPEAT
   DROP 2DROP 0 ;

' RADD  DEFCMD +
' RSUB  DEFCMD -
' RMUL  DEFCMD *
' RDIV  DEFCMD /
' RNEG  DEFCMD NEG
' RINV  DEFCMD INV
' RSQ   DEFCMD SQ
' RSQRT DEFCMD SQRT
' R^    DEFCMD ^
' RSIN  DEFCMD SIN
' RCOS  DEFCMD COS
' RTAN  DEFCMD TAN
' RASIN DEFCMD ASIN
' RACOS DEFCMD ACOS
' RATAN DEFCMD ATAN
' RLN   DEFCMD LN
' REXP  DEFCMD EXP
' RLOG  DEFCMD LOG
' RALOG DEFCMD ALOG
' RPI   DEFCMD PI
' HDROP DEFCMD DROP
' HDUP  DEFCMD DUP
' HSWAP DEFCMD SWAP
' HOVER DEFCMD OVER
' HROT  DEFCMD ROT
' HCLEAR DEFCMD CLEAR
' HDEPTH DEFCMD DEPTH
' RABS  DEFCMD ABS
' cAND  DEFCMD AND
' cOR   DEFCMD OR
' cXOR  DEFCMD XOR
' cNOT  DEFCMD NOT
' c->I  DEFCMD ->I
' c->R  DEFCMD ->R
' cBIN  DEFCMD BIN
' cOCT  DEFCMD OCT
' cDECB DEFCMD DEC
' cHEX  DEFCMD HEX
' cDEG  DEFCMD DEG
' cRAD  DEFCMD RAD
' cSTD  DEFCMD STD
' cFIX  DEFCMD FIX
' cOFF  DEFCMD OFF

\ ===========================================================================
\ 7. THE PARSER / EVALUATOR
\ ===========================================================================
VARIABLE TKA   VARIABLE TKU
: SKIPBL ( a u -- a u )
   BEGIN DUP 0> WHILE OVER C@ BL = IF 1 /STRING ELSE EXIT THEN REPEAT ;
: TOKEN ( a u -- rem-a rem-u )                 \ next token -> TKA/TKU
   SKIPBL  OVER TKA !  0 TKU !
   BEGIN DUP 0> IF OVER C@ BL <> ELSE FALSE THEN
   WHILE 1 /STRING  1 TKU +! REPEAT ;
CREATE UBUF 34 ALLOT
: UNKNOWN ( a u -- )
   [CHAR] ? UBUF C!
   DUP >R  UBUF 1+ SWAP CMOVE  R> 1+  UBUF SWAP  ERRMSG ;

VARIABLE RLF   VARIABLE INEG
: REALISH? ( a u -- f )                 \ contains '.', 'E' or 'e'  (decimal reals)
   FALSE RLF !
   0 ?DO  DUP I + C@
        DUP [CHAR] . =  OVER [CHAR] E = OR  SWAP [CHAR] e = OR
        IF TRUE RLF ! THEN
   LOOP DROP  RLF @ ;
: >CINT ( a u -- d -1 | 0 )             \ parse an integer in CBASE (opt. leading -)
   OVER C@ [CHAR] - =  DUP INEG !
   IF 1 /STRING THEN
   DUP 0= IF 2DROP 0 EXIT THEN
   0 0 2SWAP  BASE @ >R  CBASE @ BASE !  >NUMBER  R> BASE !
   IF DROP 2DROP 0 EXIT THEN            \ leftover chars: not a valid integer
   DROP  INEG @ IF DNEGATE THEN  -1 ;

\ push a numeric token: a real if it looks like one (only in DEC mode), else an
\ integer in the current base; otherwise report it as unknown.
: NUMTOKEN ( a u -- )
   CBASE @ 10 = IF
      2DUP REALISH? IF
         2DUP >FLOAT IF  2DROP PUSHR EXIT  THEN
      THEN
   THEN
   >CINT IF PUSHI ELSE TKA @ TKU @ UNKNOWN THEN ;

: EVAL$ ( a u -- )
   \ Look up commands FIRST: the BASIC number parser treats "+"/"-" as 0, so a
   \ number-first order would swallow those operators as the value zero.
   BEGIN SKIPBL DUP 0> WHILE
      TOKEN
      TKA @ TKU @ FIND-CMD ?DUP
      IF   EXECUTE
      ELSE TKA @ TKU @ NUMTOKEN
      THEN
   REPEAT 2DROP ;

\ ===========================================================================
\ 8. USER ENTRY POINTS
\ ===========================================================================
: RUN" ( "text"<"> -- )   [CHAR] " PARSE EVAL$ ;     \ non-interactive (tests)
CREATE TIB2 84 ALLOT
: HP ( -- )                                          \ interactive calculator
   0 QUITF !
   BEGIN
      .STACK  CR ." > "
      TIB2 80 ACCEPT  TIB2 SWAP  EVAL$
      QUITF @
   UNTIL
   CLS ." BYE." CR ;

CR .( HP50 CALCULATOR LOADED.  TYPE  HP  TO START  -- OFF QUITS.) CR
