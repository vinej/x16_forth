\ HP50TEST.FTH - self-checking tests for HP50.FTH  (INCLUDE this, runs itself).
\ Exercises the calculator end to end: parser, object stack, FP math, formatting.
S" HP50.FTH" INCLUDED
DECIMAL
VARIABLE #FAIL   0 #FAIL !
: L1F ( -- ) ( F: -- r )   1 OLVL 1+ F@ ;             \ level-1 float
: CK  ( F: expected -- )                              \ compare to level 1
   L1F F-  FABS   1 S>F 1000 S>F F/ FDUP F*  F<        \ |diff| < 1e-6 ?
   IF ."  OK" ELSE ."  **FAIL**"  1 #FAIL +! THEN  CR ;

CR .( HP50 SELF-TEST) CR
.( 3 4 +      ) RUN" CLEAR 3 4 +"          7 S>F CK
.( 3 4 -      ) RUN" CLEAR 3 4 -"          -1 S>F CK
.( 3 4 *      ) RUN" CLEAR 3 4 *"          12 S>F CK
.( 12 4 /     ) RUN" CLEAR 12 4 /"         3 S>F CK
.( 2 10 ^     ) RUN" CLEAR 2 10 ^"         1024 S>F CK
.( 9 SQRT     ) RUN" CLEAR 9 SQRT"         3 S>F CK
.( 5 SQ       ) RUN" CLEAR 5 SQ"           25 S>F CK
.( 4 INV      ) RUN" CLEAR 4 INV"          0.25E0 CK
.( 7 NEG      ) RUN" CLEAR 7 NEG"          -7 S>F CK
.( PI         ) RUN" CLEAR PI"             3.14159265E0 CK
.( 30 SIN DEG ) RUN" CLEAR DEG 30 SIN"     0.5E0 CK
.( 60 COS DEG ) RUN" CLEAR 60 COS"         0.5E0 CK
.( 45 TAN DEG ) RUN" CLEAR 45 TAN"         1 S>F CK
.( .5 ASIN    ) RUN" CLEAR DEG 0.5 ASIN"   30 S>F CK
.( 1 ATAN DEG ) RUN" CLEAR 1 ATAN"         45 S>F CK
.( 100 LN     ) RUN" CLEAR 100 LN"         4.605170186E0 CK
.( 0 EXP      ) RUN" CLEAR 0 EXP"          1 S>F CK
.( 1000 LOG   ) RUN" CLEAR 1000 LOG"       3 S>F CK
.( 2 ALOG     ) RUN" CLEAR 2 ALOG"         100 S>F CK
.( RAD PI SIN ) RUN" CLEAR RAD PI SIN"     0 S>F CK
.( SWAP       ) RUN" CLEAR 1 2 3 SWAP"     2 S>F CK
.( OVER       ) RUN" CLEAR 1 2 OVER"       1 S>F CK
.( ROT        ) RUN" CLEAR 1 2 3 ROT"      1 S>F CK
.( DROP       ) RUN" CLEAR 1 2 3 DROP"     2 S>F CK
.( DUP +      ) RUN" CLEAR 5 DUP +"        10 S>F CK
.( DEPTH      ) RUN" CLEAR 1 2 3 DEPTH"    3 S>F CK
.( EXPRESSION ) RUN" CLEAR 3 4 + 5 * 2 -" 33 S>F CK
CR .( FAILURES: ) #FAIL @ . CR
