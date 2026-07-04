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
\ Needs only the built-in floating-point words.  Its display text is all
\ UPPERCASE, which renders correctly in ForthX16's default ISO charset (and in
\ the old upper/graphics set); do not switch to `14 EMIT` upper/lower PETSCII.
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
\ 2. THE OBJECT STACK   (12-byte cells: [tag][re:5][im:5][spare])
\ ===========================================================================
16 CONSTANT MAXLVL
12 CONSTANT OCELL
0  CONSTANT T-REAL              \ real   : 5-byte float in bytes 1..5
1  CONSTANT T-INT               \ integer: 32-bit (double) in bytes 1..4
2  CONSTANT T-CPLX              \ complex: real part 1..5, imaginary part 6..10
3  CONSTANT T-LIST              \ list   : 16-bit pointer (bytes 1..2) into LARENA
4  CONSTANT T-MARK              \ internal: "{" open-list marker (no payload)

CREATE OSTK   MAXLVL OCELL * ALLOT
VARIABLE OSP   0 OSP !          \ number of items on the stack
CREATE OTMP   OCELL ALLOT

: OIDX@  ( index -- addr )  OCELL *  OSTK + ;
: OLVL   ( level -- addr )  OSP @ SWAP -  OIDX@ ;        \ level 1 = top
: OTAG   ( level -- tag )   OLVL C@ ;
: OINT?  ( level -- f )     OTAG T-INT = ;
: OCPLX? ( level -- f )     OTAG T-CPLX = ;
: OCP    ( src dest -- )    OCELL CMOVE ;
: R@F    ( level -- ) ( F: -- r )   OLVL 1+ F@ ;         \ fetch a level's float / re
: R@IM   ( level -- ) ( F: -- r )   OLVL 6 + F@ ;        \ fetch a complex level's im
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
: ANYCPLX  ( -- f )                1 OCPLX?  2 OCPLX?  OR ;

\ ---- complex support: fetch a level as (re im), promoting real/int to (r,0) --
: PUSHC ( F: re im -- )
   OROOM 0= IF FDROP FDROP OVFERR EXIT THEN
   OSP @ OIDX@   T-CPLX OVER C!            ( addr )   ( F: re im )
   DUP 6 + F!   1+ F!                      \ im at +6, re at +1
   1 OSP +! ;
: OL>C ( level -- ) ( F: -- re im )
   DUP OCPLX? IF  DUP R@F  R@IM
   ELSE  OL>F 0 S>F  THEN ;
\ complex operands staged in variables so the 4-float juggling stays readable
FVARIABLE CAR  FVARIABLE CAI  FVARIABLE CBR  FVARIABLE CBI  FVARIABLE CDEN
: CUNPREP  ( -- )   1 OL>C  CAI F! CAR F!  ODROP ;             \ level1 -> CA
: CBINPREP ( -- )   2 OL>C CAI F! CAR F!  1 OL>C CBI F! CBR F!  ODROP ODROP ;

\ ---- lists: a bump-allocated heap (arena).  A list block is [count:cell][elem:OCELL]* .
\ The arena is freed only by CLEAR (no GC); "LIST FULL" if it overflows - then CLEAR.
1024 CONSTANT LARENASZ
CREATE LARENA LARENASZ ALLOT
VARIABLE LHP    0 LHP !
: LALLOC ( n -- addr | 0 )
   LHP @  TUCK +  DUP LARENASZ > IF 2DROP 0 ELSE LHP !  LARENA + THEN ;
: OLIST? ( level -- f )  OTAG T-LIST = ;
: R@P    ( level -- ptr ) OLVL 1+ @ ;             \ a list level's block pointer
: PUSHL ( ptr -- )
   OROOM 0= IF DROP OVFERR EXIT THEN
   OSP @ OIDX@  T-LIST OVER C!  1+ !  1 OSP +! ;
: BOTHLIST ( -- f )  1 OLIST?  2 OLIST?  AND ;
VARIABLE LC1  VARIABLE LC2  VARIABLE LCP1  VARIABLE LCP2  VARIABLE LCB
: LCAT ( -- )                                  \ level2 ++ level1  ( + on two lists )
   1 R@P LCP1 !  LCP1 @ @ LC1 !
   2 R@P LCP2 !  LCP2 @ @ LC2 !
   LC1 @ LC2 @ + OCELL * 2 + LALLOC ?DUP 0= IF S" LIST FULL" ERRMSG EXIT THEN
   LCB !
   LC1 @ LC2 @ + LCB @ !
   LCP2 @ 2 +  LCB @ 2 +                    LC2 @ OCELL * CMOVE
   LCP1 @ 2 +  LCB @ 2 + LC2 @ OCELL * +    LC1 @ OCELL * CMOVE
   ODROP ODROP  LCB @ PUSHL ;

\ ---- vector element access (treat a list of reals/ints as a vector) --------
: A>F ( addr -- ) ( F: -- r )   DUP C@ T-INT = IF 1+ 2@ D>F ELSE 1+ F@ THEN ;
: VEL ( ptr i -- ) ( F: -- r )  OCELL * + 2 + A>F ;         \ element i (0-based) as float
: VST ( blk i -- ) ( F: r -- )  OCELL * + 2 +  DUP T-REAL SWAP C!  1+ F! ;
\ matrix = a list of row-lists.  MROW i -> row block pointer; MEL i j -> M[i][j].
: MROW ( mptr i -- rowptr )      OCELL * + 2 + 1+ @ ;
: MEL  ( mptr i j -- ) ( F: -- r )  >R MROW R> VEL ;

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
CREATE CBUF 44 ALLOT   VARIABLE CP           \ complex "(re,im)" is built here
: CBC ( c -- )   CBUF CP @ + C!  1 CP +! ;
: CBS ( a u -- ) 0 ?DO DUP I + C@ CBC LOOP DROP ;
CREATE LBUF 80 ALLOT   VARIABLE LP           \ outer list "[ ... ]" is built here
: LBC ( c -- )   LBUF LP @ + C!  1 LP +! ;
: LBS ( a u -- ) 0 ?DO DUP I + C@ LBC LOOP DROP ;
CREATE LBUF2 80 ALLOT  VARIABLE LP2          \ one nested level (matrix rows) here
: LBC2 ( c -- )  LBUF2 LP2 @ + C!  1 LP2 +! ;
: LBS2 ( a u -- ) 0 ?DO DUP I + C@ LBC2 LOOP DROP ;

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

\ format a complex object AT AN ADDRESS as "(re,im)" into CBUF
: CPLXA$ ( addr -- a u )
   0 CP !  [CHAR] ( CBC
   DUP 1+ F@ FSTR CBS  [CHAR] , CBC
   6 + F@ FSTR CBS  [CHAR] ) CBC  CBUF CP @ ;

\ scalar formatter for the deepest level (a list here shows as [..])
: SCALAR$ ( addr -- a u )
   DUP C@
   DUP T-REAL = IF DROP 1+ F@ FSTR EXIT THEN
   DUP T-INT  = IF DROP 1+ 2@ INT$ EXIT THEN
   DUP T-CPLX = IF DROP CPLXA$ EXIT THEN
   DUP T-MARK = IF 2DROP S" [" EXIT THEN
   T-LIST = IF DROP S" [..]" EXIT THEN  DROP S" ?" ;
\ format a nested list (e.g. a matrix row) into LBUF2, elements via SCALAR$
: LIST2$ ( ptr -- a u )
   0 LP2 !  [CHAR] [ LBC2  BL LBC2
   DUP @  SWAP 2 +  SWAP
   0 ?DO  DUP SCALAR$ LBS2  BL LBC2  OCELL +  LOOP
   DROP  [CHAR] ] LBC2  LBUF2 LP2 @ ;
\ format the object at an address; a nested list is expanded one level (LIST2$)
: CELL$ ( addr -- a u )
   DUP C@
   DUP T-REAL = IF DROP 1+ F@ FSTR EXIT THEN
   DUP T-INT  = IF DROP 1+ 2@ INT$ EXIT THEN
   DUP T-CPLX = IF DROP CPLXA$ EXIT THEN
   DUP T-MARK = IF 2DROP S" [" EXIT THEN
   T-LIST = IF 1+ @ LIST2$ EXIT THEN  DROP S" ?" ;

\ format a whole (outer) list block "[ e0 e1 ... ]" into LBUF
: LIST$ ( ptr -- a u )
   0 LP !  [CHAR] [ LBC  BL LBC
   DUP @  SWAP 2 +  SWAP                     ( elem0addr count )
   0 ?DO  DUP CELL$ LBS  BL LBC  OCELL +  LOOP
   DROP  [CHAR] ] LBC  LBUF LP @ ;

\ format the object at a stack level ( top-level lists shown in full )
: OBJ$ ( level -- a u )
   DUP OLIST? IF R@P LIST$ ELSE OLVL CELL$ THEN ;
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

\ ---- complex arithmetic (CBINPREP/CUNPREP stage the operands in CA/CB) ------
: CADD  CBINPREP  CAR F@ CBR F@ F+   CAI F@ CBI F@ F+   PUSHC ;
: CSUB  CBINPREP  CAR F@ CBR F@ F-   CAI F@ CBI F@ F-   PUSHC ;
: CMUL  CBINPREP
   CAR F@ CBR F@ F*  CAI F@ CBI F@ F*  F-               \ re = ar*br - ai*bi
   CAR F@ CBI F@ F*  CAI F@ CBR F@ F*  F+  PUSHC ;      \ im = ar*bi + ai*br
: CDIV  CBINPREP
   CBR F@ FDUP F*  CBI F@ FDUP F*  F+  CDEN F!          \ den = br^2 + bi^2
   CAR F@ CBR F@ F*  CAI F@ CBI F@ F*  F+  CDEN F@ F/   \ re
   CAI F@ CBR F@ F*  CAR F@ CBI F@ F*  F-  CDEN F@ F/   \ im
   PUSHC ;
: CNEG  CUNPREP  CAR F@ FNEGATE  CAI F@ FNEGATE  PUSHC ;
: CCONJ CUNPREP  CAR F@          CAI F@ FNEGATE  PUSHC ;
: CINV  CUNPREP
   CAR F@ FDUP F*  CAI F@ FDUP F*  F+  CDEN F!          \ den = ar^2 + ai^2
   CAR F@ CDEN F@ F/   CAI F@ FNEGATE CDEN F@ F/  PUSHC ;
: CSQ   CUNPREP
   CAR F@ FDUP F*  CAI F@ FDUP F*  F-                   \ re = ar^2 - ai^2
   CAR F@ CAI F@ F*  2 S>F F*  PUSHC ;                  \ im = 2*ar*ai
: CABS  CUNPREP  CAR F@ FDUP F*  CAI F@ FDUP F*  F+ FSQRT  PUSHR ;   \ magnitude -> real
: CRE   CUNPREP  CAR F@ PUSHR ;
: CIM   CUNPREP  CAI F@ PUSHR ;
: CARG  CUNPREP                                          \ atan2(im,re) in the angle mode
   CAR F@ F0= IF
      CAI F@ F0< IF FPI 2 S>F F/ FNEGATE ELSE FPI 2 S>F F/ THEN
   ELSE
      CAI F@ CAR F@ F/ FATAN
      CAR F@ F0< IF CAI F@ F0< IF FPI F- ELSE FPI F+ THEN THEN
   THEN
   RAD> PUSHR ;

\ ---- arithmetic (complex if either is complex; else exact-int; else real) --
: RADD  NEED2 IF BOTHLIST IF LCAT ELSE ANYCPLX IF CADD ELSE
        BOTHINT IF IBINPREP D+ PUSHI ELSE RBINPREP F+ PUSHR THEN THEN THEN ELSE UNDERR THEN ;
: RSUB  NEED2 IF ANYCPLX IF CSUB ELSE
        BOTHINT IF IBINPREP D- PUSHI ELSE RBINPREP F- PUSHR THEN THEN ELSE UNDERR THEN ;
: RMUL  NEED2 IF ANYCPLX IF CMUL ELSE
        BOTHINT IF IBINPREP D* PUSHI ELSE RBINPREP F* PUSHR THEN THEN ELSE UNDERR THEN ;
: RDIV  NEED2 IF ANYCPLX IF CDIV ELSE
        1 OL>F F0= IF DERR ELSE RBINPREP F/ PUSHR THEN THEN ELSE UNDERR THEN ;
: RNEG  NEED1 IF 1 OCPLX? IF CNEG ELSE 1 OINT? IF IUNPREP DNEGATE PUSHI
        ELSE RUNPREP FNEGATE PUSHR THEN THEN ELSE UNDERR THEN ;
: RINV  NEED1 IF 1 OCPLX? IF CINV ELSE 1 OL>F F0= IF DERR
        ELSE RUNPREP 1 S>F FSWAP F/ PUSHR THEN THEN ELSE UNDERR THEN ;
: RSQ   NEED1 IF 1 OCPLX? IF CSQ ELSE 1 OINT? IF IUNPREP 2DUP D* PUSHI
        ELSE RUNPREP FDUP F* PUSHR THEN THEN ELSE UNDERR THEN ;
: RABS  NEED1 IF 1 OCPLX? IF CABS ELSE 1 OINT? IF IUNPREP DABS PUSHI
        ELSE RUNPREP FABS PUSHR THEN THEN ELSE UNDERR THEN ;
: RSQRT NEED1 IF 1 OCPLX? IF DERR ELSE 1 OL>F F0< IF DERR
        ELSE RUNPREP FSQRT PUSHR THEN THEN ELSE UNDERR THEN ;
: R^    NEED2 IF ANYCPLX IF DERR EXIT THEN
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

\ ---- transcendental (real only; integers promoted, complex rejected) -------
: NEED1R ( -- f )  NEED1 IF 1 OCPLX? 0= ELSE FALSE THEN ;   \ 1 real/int operand?
: RSIN  NEED1R IF RUNPREP >RAD FSIN PUSHR ELSE
        NEED1 IF DERR ELSE UNDERR THEN THEN ;
: RCOS  NEED1R IF RUNPREP >RAD FCOS PUSHR ELSE
        NEED1 IF DERR ELSE UNDERR THEN THEN ;
: RTAN  NEED1R IF RUNPREP >RAD FTAN PUSHR ELSE
        NEED1 IF DERR ELSE UNDERR THEN THEN ;
: RATAN NEED1R IF RUNPREP FATAN RAD> PUSHR ELSE
        NEED1 IF DERR ELSE UNDERR THEN THEN ;
: RASIN NEED1R IF RUNPREP FDUP FDUP F* FNEGATE 1 S>F F+ FSQRT F/ FATAN RAD> PUSHR ELSE
        NEED1 IF DERR ELSE UNDERR THEN THEN ;
: RACOS NEED1R IF RUNPREP FDUP FDUP F* FNEGATE 1 S>F F+ FSQRT F/ FATAN RAD>
                QUARTER FSWAP F- PUSHR ELSE
        NEED1 IF DERR ELSE UNDERR THEN THEN ;
: RLN   NEED1R IF 1 OL>F F<=0 IF DERR ELSE RUNPREP FLN PUSHR THEN ELSE
        NEED1 IF DERR ELSE UNDERR THEN THEN ;
: REXP  NEED1R IF RUNPREP FEXP PUSHR ELSE
        NEED1 IF DERR ELSE UNDERR THEN THEN ;
: RLOG  NEED1R IF 1 OL>F F<=0 IF DERR ELSE RUNPREP FLN FLN10 F/ PUSHR THEN ELSE
        NEED1 IF DERR ELSE UNDERR THEN THEN ;
: RALOG NEED1R IF RUNPREP FLN10 F* FEXP PUSHR ELSE
        NEED1 IF DERR ELSE UNDERR THEN THEN ;
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
: HCLEAR 0 OSP !  0 LHP ! ;                 \ CLEAR also frees the list arena
: HDEPTH OROOM IF OSP @ S>D PUSHI ELSE OVFERR THEN ;

\ ---- modes ----
: cDEG  -1 ANGDEG ! ;
: cRAD   0 ANGDEG ! ;
: cSTD   0 DISPMODE ! ;
: cFIX   NEED1 IF RUNPREP F>S 0 MAX 9 MIN DISPDEC !  1 DISPMODE ! ELSE UNDERR THEN ;
VARIABLE QUITF
: cOFF  -1 QUITF ! ;

\ ---- complex commands (CONJ/RE/IM/ARG act on a complex; ->C / C-> build/split) --
: cCONJ NEED1 IF 1 OCPLX? IF CCONJ ELSE THEN ELSE UNDERR THEN ;   \ conj of a real = itself
: cRE   NEED1 IF 1 OCPLX? IF CRE  ELSE THEN ELSE UNDERR THEN ;    \ RE of a real = itself
: cIM   NEED1 IF 1 OCPLX? IF CIM  ELSE ODROP 0 S>F PUSHR THEN ELSE UNDERR THEN ;  \ IM of real = 0
: cARG  NEED1 IF 1 OCPLX? IF CARG ELSE
        1 OL>F F0< ODROP IF FPI RAD> ELSE 0 S>F THEN PUSHR THEN ELSE UNDERR THEN ;
: cR>C  NEED2 IF 2 OL>F 1 OL>F ODROP ODROP PUSHC ELSE UNDERR THEN ;
: cC>R  NEED1 IF 1 OCPLX? IF 1 OL>C ODROP FSWAP PUSHR PUSHR ELSE DERR THEN
        ELSE UNDERR THEN ;

\ ---- list commands --------------------------------------------------------
VARIABLE MKL   VARIABLE LCNT   VARIABLE LBLK
VARIABLE GN    VARIABLE GCNT   VARIABLE GPTR   VARIABLE GSRC
: FIND-MARK ( -- level | 0 )                   \ nearest "{" marker, 0 if none
   0 MKL !
   OSP @ 1+ 1 DO  MKL @ 0=  I OTAG T-MARK = AND IF I MKL ! THEN  LOOP  MKL @ ;
: cLBRACE ( -- )                               \ {
   OROOM 0= IF OVFERR EXIT THEN
   OSP @ OIDX@  T-MARK SWAP C!  1 OSP +! ;
: cRBRACE ( -- )                               \ }  collect items above "{" into a list
   FIND-MARK ?DUP 0= IF S" NO MATCHING [" ERRMSG EXIT THEN
   1- LCNT !                                   \ element count = levels above the marker
   LCNT @ OCELL * 2 + LALLOC ?DUP 0= IF S" LIST FULL" ERRMSG EXIT THEN
   LBLK !
   LCNT @ LBLK @ !                             \ store count in the block
   LCNT @ 0 ?DO
      LCNT @ I - OLVL                          \ src = level (count - i)  (elem i, in order)
      LBLK @ 2 + I OCELL * +                   \ dest
      OCELL CMOVE
   LOOP
   LCNT @ 1+ NEGATE OSP +!                     \ drop the elements and the marker
   LBLK @ PUSHL ;
: cSIZE  NEED1 IF 1 OLIST? IF 1 R@P @ ODROP S>D PUSHI ELSE DERR THEN
         ELSE UNDERR THEN ;
: cGET   NEED2 IF 2 OLIST? IF
            1 OL>I DROP GN !                   \ index (1-based; drop high cell)
            2 R@P GPTR !   GPTR @ @ GCNT !
            GN @ 1 <  GN @ GCNT @ >  OR IF DERR EXIT THEN
            GPTR @ 2 + GN @ 1- OCELL * + GSRC !
            ODROP ODROP
            OROOM 0= IF OVFERR EXIT THEN
            GSRC @ OSP @ OIDX@ OCELL CMOVE  1 OSP +!
         ELSE DERR THEN ELSE UNDERR THEN ;

\ ---- vector commands (a vector is a list [ ] of reals/ints) ----------------
VARIABLE VP1  VARIABLE VP2  VARIABLE VN  VARIABLE VB
: VSAMELEN ( -- f )  2 R@P VP1 !  1 R@P VP2 !  VP1 @ @ VP2 @ @ = ;
: VNEWBLK  ( -- f )  \ allocate an N-element result block in VB (VN must be set); f=ok
   VN @ OCELL * 2 + LALLOC ?DUP IF VB !  VN @ VB @ !  TRUE ELSE FALSE THEN ;
: cDOT  NEED2 IF BOTHLIST IF VSAMELEN IF
           VP1 @ @ VN !  0 S>F
           VN @ 0 ?DO  VP1 @ I VEL  VP2 @ I VEL  F*  F+  LOOP
           ODROP ODROP PUSHR
        ELSE DERR THEN ELSE DERR THEN ELSE UNDERR THEN ;
: cVADD NEED2 IF BOTHLIST IF VSAMELEN IF
           VP1 @ @ VN !  VNEWBLK 0= IF S" LIST FULL" ERRMSG EXIT THEN
           VN @ 0 ?DO  VP1 @ I VEL  VP2 @ I VEL  F+  VB @ I VST  LOOP
           ODROP ODROP VB @ PUSHL
        ELSE DERR THEN ELSE DERR THEN ELSE UNDERR THEN ;
: cVSUB NEED2 IF BOTHLIST IF VSAMELEN IF
           VP1 @ @ VN !  VNEWBLK 0= IF S" LIST FULL" ERRMSG EXIT THEN
           VN @ 0 ?DO  VP1 @ I VEL  VP2 @ I VEL  F-  VB @ I VST  LOOP
           ODROP ODROP VB @ PUSHL
        ELSE DERR THEN ELSE DERR THEN ELSE UNDERR THEN ;
: cNORM NEED1 IF 1 OLIST? IF
           1 R@P VP1 !  VP1 @ @ VN !  0 S>F
           VN @ 0 ?DO  VP1 @ I VEL  FDUP F*  F+  LOOP
           FSQRT ODROP PUSHR
        ELSE DERR THEN ELSE UNDERR THEN ;
: cCROSS NEED2 IF BOTHLIST IF
           2 R@P VP1 !  1 R@P VP2 !
           VP1 @ @ 3 = VP2 @ @ 3 = AND 0= IF DERR EXIT THEN
           3 VN !  VNEWBLK 0= IF S" LIST FULL" ERRMSG EXIT THEN
           VP1 @ 1 VEL VP2 @ 2 VEL F*  VP1 @ 2 VEL VP2 @ 1 VEL F* F-  VB @ 0 VST
           VP1 @ 2 VEL VP2 @ 0 VEL F*  VP1 @ 0 VEL VP2 @ 2 VEL F* F-  VB @ 1 VST
           VP1 @ 0 VEL VP2 @ 1 VEL F*  VP1 @ 1 VEL VP2 @ 0 VEL F* F-  VB @ 2 VST
           ODROP ODROP VB @ PUSHL
        ELSE DERR THEN ELSE UNDERR THEN ;

\ ---- matrix commands (a matrix is a list [ ] of equal-length row lists) -----
VARIABLE MR  VARIABLE MC  VARIABLE MP  VARIABLE MOUT  VARIABLE MROWB
: cDET NEED1 IF 1 OLIST? IF
     1 R@P MP !  MP @ @ MR !
     MR @ 2 = IF
        MP @ 0 0 MEL  MP @ 1 1 MEL  F*
        MP @ 0 1 MEL  MP @ 1 0 MEL  F*  F-  ODROP PUSHR
     ELSE MR @ 3 = IF
        MP @ 0 0 MEL  MP @ 1 1 MEL MP @ 2 2 MEL F*  MP @ 1 2 MEL MP @ 2 1 MEL F* F-  F*
        MP @ 0 1 MEL  MP @ 1 0 MEL MP @ 2 2 MEL F*  MP @ 1 2 MEL MP @ 2 0 MEL F* F-  F*  F-
        MP @ 0 2 MEL  MP @ 1 0 MEL MP @ 2 1 MEL F*  MP @ 1 1 MEL MP @ 2 0 MEL F* F-  F*  F+
        ODROP PUSHR
     ELSE DERR THEN THEN
   ELSE DERR THEN ELSE UNDERR THEN ;
: cTRN NEED1 IF 1 OLIST? IF
     1 R@P MP !  MP @ @ MR !
     MR @ 0= IF DERR EXIT THEN
     MP @ 0 MROW @ MC !                         \ columns = length of row 0
     MC @ OCELL * 2 + LALLOC ?DUP 0= IF S" LIST FULL" ERRMSG EXIT THEN  MOUT !
     MC @ MOUT @ !
     MC @ 0 DO                                  \ J = output row = original column
        MR @ OCELL * 2 + LALLOC ?DUP 0= IF S" LIST FULL" ERRMSG EXIT THEN  MROWB !
        MR @ MROWB @ !
        MR @ 0 DO  MP @ I J MEL  MROWB @ I VST  LOOP
        MROWB @  MOUT @ 2 + I OCELL * +  T-LIST OVER C!  1+ !
     LOOP
     ODROP  MOUT @ PUSHL
   ELSE DERR THEN ELSE UNDERR THEN ;

\ ---- matrix multiply   ( A B M* -> A*B ;  A is m x n, B is n x p ) ----------
VARIABLE MMA  VARIABLE MMB  VARIABLE MMM  VARIABLE MMN  VARIABLE MMP
VARIABLE MMOUT  VARIABLE MMROW  VARIABLE MMI  VARIABLE MMJ
: cMMUL NEED2 IF BOTHLIST IF
     2 R@P MMA !  1 R@P MMB !
     MMA @ @ MMM !                              \ m = rows of A
     MMB @ @ MMN !                              \ n = rows of B
     MMA @ 0 MROW @  MMN @ <> IF DERR EXIT THEN \ inner dims must match (A cols = B rows)
     MMB @ 0 MROW @ MMP !                       \ p = columns of B (length of B's row 0)
     MMM @ OCELL * 2 + LALLOC ?DUP 0= IF S" LIST FULL" ERRMSG EXIT THEN  MMOUT !
     MMM @ MMOUT @ !
     MMM @ 0 DO                                 \ I stored in MMI (shadowed by inner loops)
        I MMI !
        MMP @ OCELL * 2 + LALLOC ?DUP 0= IF S" LIST FULL" ERRMSG EXIT THEN  MMROW !
        MMP @ MMROW @ !
        MMP @ 0 DO
           I MMJ !
           0 S>F
           MMN @ 0 DO                           \ I = k here
              MMA @ MMI @ I MEL   MMB @ I MMJ @ MEL   F*  F+
           LOOP
           MMROW @ MMJ @ VST                    \ C[i][j]
        LOOP
        MMROW @  MMOUT @ 2 + MMI @ OCELL * +  T-LIST OVER C!  1+ !
     LOOP
     ODROP ODROP  MMOUT @ PUSHL
   ELSE DERR THEN ELSE UNDERR THEN ;

\ ===========================================================================
\ 5b. USER VARIABLES  (STO / RCL / PURGE)  -  a persistent name -> object store
\ ===========================================================================
\ Variables SURVIVE CLEAR (unlike stack lists).  List/matrix values are DEEP-COPIED
\ into a separate persistent arena (VARENA) so CLEAR (which frees LARENA) can't
\ dangle them.  Deep copy handles two levels (vectors and matrices).
2048 CONSTANT VARENASZ
CREATE VARENA VARENASZ ALLOT
VARIABLE VHP   0 VHP !
: VALLOC ( n -- addr | 0 )
   VHP @ TUCK +  DUP VARENASZ > IF 2DROP 0 ELSE VHP !  VARENA + THEN ;

VARIABLE LCS  VARIABLE LCN  VARIABLE LCD
: LCOPY1 ( srcptr -- dstptr | 0 )              \ copy one list block verbatim into VARENA
   LCS !
   LCS @ @ LCN !
   LCN @ OCELL * 2 + VALLOC ?DUP 0= IF DROP 0 EXIT THEN  LCD !
   LCS @ LCD @  LCN @ OCELL * 2 +  CMOVE
   LCD @ ;
VARIABLE LMD  VARIABLE LMN
: LCOPYD ( srcptr -- dstptr | 0 )              \ deep copy: outer block + any row lists
   DUP LCOPY1 ?DUP 0= IF DROP 0 EXIT THEN  LMD !   ( srcptr )
   @ LMN !                                    \ element count
   LMN @ 0 DO
      LMD @ 2 + I OCELL * +                    ( cell )
      DUP C@ T-LIST = IF
         DUP 1+ @ LCOPY1 ?DUP 0= IF DROP 0 UNLOOP EXIT THEN  ( cell newrow )
         SWAP 1+ !
      ELSE DROP THEN
   LOOP
   LMD @ ;

8 CONSTANT VNAMEMAX
16 CONSTANT MAXVAR
VNAMEMAX 1+ OCELL +  CONSTANT VREC             \ record = [namelen:1][name:8][value:OCELL]
CREATE VARS  MAXVAR VREC * ALLOT
VARS  MAXVAR VREC *  0 FILL                    \ namelen 0 = free slot
: VREC@ ( i -- addr )  VREC *  VARS + ;
VARIABLE VFA  VARIABLE VFU  VARIABLE VFR
: VFIND ( a u -- rec | 0 )                     \ find a variable by exact name
   VFU !  VFA !  0 VFR !
   MAXVAR 0 DO
      I VREC@
      DUP C@ VFU @ =   OVER 1+ VFU @ VFA @ VFU @ COMPARE 0=  AND
      IF VFR ! ELSE DROP THEN
   LOOP  VFR @ ;
VARIABLE VNR
: VNEWREC ( -- rec | 0 )                       \ first free slot, else 0
   0 VNR !
   MAXVAR 0 DO  VNR @ 0=  I VREC@ C@ 0=  AND IF I VREC@ VNR ! THEN  LOOP  VNR @ ;
: VPUSH ( rec -- )                             \ push a variable's stored value
   OROOM 0= IF DROP OVFERR EXIT THEN
   1+ VNAMEMAX +  OSP @ OIDX@  OCELL CMOVE  1 OSP +! ;
: cCLVAR  VARS MAXVAR VREC * 0 FILL  0 VHP ! ; \ delete all variables
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
' cCONJ DEFCMD CONJ
' cRE   DEFCMD RE
' cIM   DEFCMD IM
' cARG  DEFCMD ARG
' cR>C  DEFCMD R->C
' cC>R  DEFCMD C->R
' cLBRACE DEFCMD [
' cRBRACE DEFCMD ]
' cSIZE DEFCMD SIZE
' cGET  DEFCMD GET
' cDOT  DEFCMD DOT
' cVADD DEFCMD V+
' cVSUB DEFCMD V-
' cNORM DEFCMD NORM
' cCROSS DEFCMD CROSS
' cDET  DEFCMD DET
' cTRN  DEFCMD TRN
' cMMUL DEFCMD M*

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

\ complex literal:  (re,im)   e.g.  (3,4)   (1.5,-2)
VARIABLE CMX   VARIABLE IA   VARIABLE IU   VARIABLE CIDX
: FINDCOMMA ( a u -- idx | -1 )
   -1 CMX !
   0 ?DO  DUP I + C@ [CHAR] , = IF CMX @ 0< IF I CMX ! THEN THEN  LOOP  DROP
   CMX @ ;
: PARSE-CPLX ( a u -- )                 \ token = "(re,im)"
   2DUP + 1- C@ [CHAR] ) <> IF 2DROP TKA @ TKU @ UNKNOWN EXIT THEN
   1 /STRING 1-                         ( ia iu -- strip parens )
   OVER IA !  DUP IU !
   IA @ IU @ FINDCOMMA                  ( ia iu c )
   DUP 0< IF DROP 2DROP TKA @ TKU @ UNKNOWN EXIT THEN
   CIDX !  2DROP
   IA @ CIDX @ >FLOAT 0= IF TKA @ TKU @ UNKNOWN EXIT THEN            ( F: re )
   IA @ CIDX @ + 1+   IU @ CIDX @ - 1-   >FLOAT 0= IF
      FDROP TKA @ TKU @ UNKNOWN EXIT THEN                            ( F: re im )
   PUSHC ;

\ push a numeric token: complex "(re,im)", else a real if it looks like one (only
\ in DEC mode), else an integer in the current base; otherwise unknown.
\ push a numeric token, else recall a user variable of that name, else unknown.
: NUMTOKEN ( a u -- )
   OVER C@ [CHAR] ( = IF PARSE-CPLX EXIT THEN
   CBASE @ 10 = IF
      2DUP REALISH? IF
         2DUP >FLOAT IF  2DROP PUSHR EXIT  THEN
      THEN
   THEN
   >CINT IF PUSHI EXIT THEN
   TKA @ TKU @ VFIND ?DUP IF VPUSH EXIT THEN      \ a bare variable name recalls it
   TKA @ TKU @ UNKNOWN ;

\ The remaining input line lives in REMA/REMU so a command (STO/RCL/PURGE) can
\ pull the NEXT token itself (the variable name).
VARIABLE REMA   VARIABLE REMU
: NEXT-TOKEN ( -- ta tu )                        \ next token; advances REMA/REMU
   REMA @ REMU @ TOKEN  REMU !  REMA !  TKA @ TKU @ ;
: EVAL$ ( a u -- )
   \ Look up commands FIRST: the BASIC number parser treats "+"/"-" as 0, so a
   \ number-first order would swallow those operators as the value zero.
   REMU !  REMA !
   BEGIN
      REMA @ REMU @ SKIPBL  REMU !  REMA !
      REMU @ 0>
   WHILE
      NEXT-TOKEN                                  ( ta tu )
      2DUP FIND-CMD ?DUP
      IF   NIP NIP EXECUTE
      ELSE NUMTOKEN
      THEN
   REPEAT ;

\ ---- STO / RCL / PURGE : take the variable NAME from the next token ---------
VARIABLE STR
: cSTO ( -- )                                    \ e.g.  5 STO A     [ 1 2 ] STO V
   NEED1 0= IF UNDERR EXIT THEN
   NEXT-TOKEN
   DUP 0= IF 2DROP S" STO NEEDS A NAME" ERRMSG EXIT THEN
   DUP VNAMEMAX > IF 2DROP S" NAME TOO LONG" ERRMSG EXIT THEN
   2DUP VFIND ?DUP IF STR !
      ELSE VNEWREC ?DUP IF STR ! ELSE 2DROP S" TOO MANY VARS" ERRMSG EXIT THEN THEN
   ( a u )
   DUP STR @ C!  STR @ 1+ SWAP CMOVE             \ store namelen + name
   1 OLIST? IF
      1 R@P LCOPYD ?DUP 0= IF S" VAR MEM FULL" ERRMSG EXIT THEN
      STR @ 1+ VNAMEMAX +  T-LIST OVER C!  1+ !  \ store T-LIST cell -> VARENA copy
   ELSE
      1 OLVL  STR @ 1+ VNAMEMAX +  OCELL CMOVE   \ scalar/complex: copy the cell
   THEN
   ODROP ;
: cRCL ( -- )                                    \ e.g.  RCL A
   NEXT-TOKEN
   DUP 0= IF 2DROP S" RCL NEEDS A NAME" ERRMSG EXIT THEN
   VFIND ?DUP 0= IF S" UNKNOWN VAR" ERRMSG EXIT THEN
   VPUSH ;
: cPURGE ( -- )                                  \ e.g.  PURGE A
   NEXT-TOKEN
   DUP 0= IF 2DROP S" PURGE NEEDS A NAME" ERRMSG EXIT THEN
   VFIND ?DUP IF 0 SWAP C! ELSE S" UNKNOWN VAR" ERRMSG THEN ;
' cSTO   DEFCMD STO
' cRCL   DEFCMD RCL
' cPURGE DEFCMD PURGE
' cCLVAR DEFCMD CLVAR

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
