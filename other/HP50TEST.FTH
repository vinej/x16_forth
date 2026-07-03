\ HP50TEST.FTH - self-checking tests for HP50.FTH  (INCLUDE this, runs itself).
\ Exercises the calculator end to end: parser, object stack, FP + integer math,
\ bases and bitwise ops, and formatting.
S" HP50.FTH" INCLUDED
DECIMAL
VARIABLE #FAIL   0 #FAIL !
: L1F ( -- ) ( F: -- r )   1 OL>F ;                   \ level-1 value as a float
: CK  ( F: expected -- )                              \ compare value to level 1
   L1F F-  FABS   1 S>F 1000 S>F F/ FDUP F*  F<        \ |diff| < 1e-6 ?
   IF ."  OK" ELSE ."  **FAIL**"  1 #FAIL +! THEN  CR ;
: SCK ( a u -- )                                      \ compare level-1 DISPLAY string
   1 OBJ$ COMPARE 0= IF ."  OK" ELSE ."  **FAIL**" 1 #FAIL +! THEN CR ;

CR .( HP50 SELF-TEST - REALS) CR
.( 3 4 +      ) RUN" CLEAR 3 4 +"          7 S>F CK
.( 3 4 -      ) RUN" CLEAR 3 4 -"          -1 S>F CK
.( 12 4 /     ) RUN" CLEAR 12 4 /"         3 S>F CK
.( 2 10 ^     ) RUN" CLEAR 2 10 ^"         1024 S>F CK
.( 9 SQRT     ) RUN" CLEAR 9 SQRT"         3 S>F CK
.( PI         ) RUN" CLEAR PI"             3.14159265E0 CK
.( 30 SIN DEG ) RUN" CLEAR DEG 30 SIN"     0.5E0 CK
.( .5 ASIN    ) RUN" CLEAR DEG 0.5 ASIN"   30 S>F CK
.( 100 LN     ) RUN" CLEAR 100 LN"         4.605170186E0 CK
.( 2 ALOG     ) RUN" CLEAR 2 ALOG"         100 S>F CK
.( 3.5 ->I    ) RUN" CLEAR 3.5 ->I"        3 S>F CK

CR .( HP50 SELF-TEST - INTEGERS) CR
.( 100000 3 * ) RUN" CLEAR 100000 3 *"     300000. D>F CK
.( 7 3 -      ) RUN" CLEAR 7 3 -"          4 S>F CK
.( 6 7 *      ) RUN" CLEAR 6 7 *"          42 S>F CK
.( 5 NEG      ) RUN" CLEAR 5 NEG"          -5 S>F CK
.( -8 ABS     ) RUN" CLEAR -8 ABS"         8 S>F CK
.( 5 ->R      ) RUN" CLEAR 5 ->R"          5 S>F CK

CR .( HP50 SELF-TEST - BITWISE / BASE) CR
.( 255 15 AND ) RUN" CLEAR 255 15 AND"     15 S>F CK
.( 12 10 OR   ) RUN" CLEAR 12 10 OR"       14 S>F CK
.( 12 10 XOR  ) RUN" CLEAR 12 10 XOR"      6 S>F CK
.( 5 NOT      ) RUN" CLEAR 5 NOT"          -6 S>F CK
.( HEX FF DEC ) RUN" CLEAR HEX FF DEC"     255 S>F CK
.( BIN 1010   ) RUN" CLEAR BIN 1010"       10 S>F CK
.( 255->HEX $ ) RUN" CLEAR DEC 255 HEX"    S" FFH" SCK
.( 10->BIN  $ ) RUN" CLEAR DEC 10 BIN"     S" 1010B" SCK
.( 64->OCT  $ ) RUN" CLEAR DEC 64 OCT"     S" 100O" SCK
RUN" DEC"                                  \ base is a persistent mode - back to decimal

CR .( HP50 SELF-TEST - COMPLEX) CR
.( ABS       ) RUN" CLEAR (3,4) ABS"          5 S>F CK
.( ADDRE     ) RUN" CLEAR (1,2) (3,4) + RE"   4 S>F CK
.( ADDIM     ) RUN" CLEAR (1,2) (3,4) + IM"   6 S>F CK
.( SUBIM     ) RUN" CLEAR (5,9) (1,2) - IM"   7 S>F CK
.( MULRE     ) RUN" CLEAR (1,2) (3,4) * RE"   -5 S>F CK
.( MULIM     ) RUN" CLEAR (1,2) (3,4) * IM"   10 S>F CK
.( DIVRE     ) RUN" CLEAR (5,10) (1,2) / RE"  5 S>F CK
.( DIVIM     ) RUN" CLEAR (5,10) (1,2) / IM"  0 S>F CK
.( I*I RE    ) RUN" CLEAR (0,1) SQ RE"        -1 S>F CK
.( CONJIM    ) RUN" CLEAR (3,4) CONJ IM"      -4 S>F CK
.( INVRE     ) RUN" CLEAR (2,0) INV RE"       0.5E0 CK
.( NEGIM     ) RUN" CLEAR (3,4) NEG IM"       -4 S>F CK
.( RE        ) RUN" CLEAR (7,8) RE"           7 S>F CK
.( IM        ) RUN" CLEAR (7,8) IM"           8 S>F CK
.( R->C ABS  ) RUN" CLEAR 3 4 R->C ABS"       5 S>F CK
.( ARG I DEG ) RUN" CLEAR DEG (0,1) ARG"      90 S>F CK
.( C->R LVL1 ) RUN" CLEAR (7,8) C->R"         8 S>F CK
.( DISPLAY $ ) RUN" CLEAR (3,4)"              S" (3,4)" SCK

CR .( HP50 SELF-TEST - LISTS) CR
.( SIZE 3    ) RUN" CLEAR [ 1 2 3 ] SIZE"        3 S>F CK
.( SIZE 0    ) RUN" CLEAR [ ] SIZE"              0 S>F CK
.( GET 2     ) RUN" CLEAR [ 10 20 30 ] 2 GET"    20 S>F CK
.( GET 1     ) RUN" CLEAR [ 10 20 30 ] 1 GET"    10 S>F CK
.( CONCAT SZ ) RUN" CLEAR [ 1 2 ] [ 3 4 5 ] + SIZE" 5 S>F CK
.( CONCAT EL ) RUN" CLEAR [ 1 2 ] [ 3 4 5 ] + 4 GET" 4 S>F CK
.( DISPLAY $ ) RUN" CLEAR [ 1 2 3 ]"             S" [ 1 2 3 ]" SCK
.( MIXED $   ) RUN" CLEAR [ 1 3.5 (2,3) ]"       S" [ 1 3.5 (2,3) ]" SCK

CR .( FAILURES: ) #FAIL @ . CR
