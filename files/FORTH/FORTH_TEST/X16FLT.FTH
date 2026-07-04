\ FORTHX16 - FLOATING-POINT SELF-TEST (wraps the BASIC ROM FP unit)
\ Uses integer-valued results checked via F>S so it is deterministic.
\ REQUIRES THE X16 BUILD. RUN WITH:  INCLUDE X16FLT.FTH

DECIMAL
VARIABLE #FAIL

: CHECK
   2DUP = IF 2DROP ."  OK" CR
   ELSE ."  FAIL GOT=" SWAP . ." WANT=" . 1 #FAIL +! CR THEN ;

: RUN-FLT
   0 #FAIL !
   CR ." == X16 FLOAT TESTS ==" CR

   ." F+      " 3 S>F 4 S>F F+ F>S 7 CHECK
   ." F-      " 10 S>F 3 S>F F- F>S 7 CHECK
   ." F*      " 6 S>F 7 S>F F* F>S 42 CHECK
   ." F/      " 100 S>F 4 S>F F/ F>S 25 CHECK
   ." FSQRT   " 10000 S>F FSQRT F>S 100 CHECK
   ." FDUP    " 5 S>F FDUP F* F>S 25 CHECK
   ." FSWAP   " 2 S>F 9 S>F FSWAP F- F>S 7 CHECK
   ." FOVER   " 7 S>F 2 S>F FOVER F+ F+ F>S 16 CHECK
   ." FNEGATE " -5 S>F FNEGATE F>S 5 CHECK
   ." FEXP    " 0 S>F FEXP F>S 1 CHECK
   ." FLN     " 1 S>F FLN F>S 0 CHECK
   \ cos(0) is ~0.9999997 from the ROM; add 0.5 so F>S rounds instead of truncating
   ." FCOS    " 0 S>F FCOS 1 S>F 2 S>F F/ F+ F>S 1 CHECK
   ." FSIN    " 0 S>F FSIN F>S 0 CHECK
   ." FATAN   " 0 S>F FATAN F>S 0 CHECK
   ." FTAN    " 0 S>F FTAN F>S 0 CHECK
   ." ISQRT   " 625 ISQRT 25 CHECK
   ." F@ F!   " 7 S>F PAD F! PAD F@ F>S 7 CHECK
   ." F< lt   " 3 S>F 4 S>F F< -1 CHECK
   ." F< ge   " 4 S>F 3 S>F F< 0 CHECK
   ." F0<     " -3 S>F F0< -1 CHECK
   ." F0=     " 0 S>F F0= -1 CHECK

   ." ALIVE   " 12345 12345 CHECK
   CR #FAIL @ 0= IF ." ALL FLOAT TESTS PASSED" ELSE ." FLOAT FAILURES: " #FAIL @ . THEN CR ;

RUN-FLT

\ Float literals work in interpret mode (typed directly), not inside : definitions,
\ so these run at the top level:
CR S" LITERAL 1.5+2.5 " TYPE 1.5E0 2.5E0 F+ F>S 4 CHECK
S" LITERAL 3*4     " TYPE 3E0 4E0 F* F>S 12 CHECK
S" LITERAL -2.5    " TYPE -2.5E0 FNEGATE F>S 2 CHECK
