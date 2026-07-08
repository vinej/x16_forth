\ FORTHX16 - VERA FX SELF-TEST (native DCSEL + FX-MULT hardware multiplier)
\ REQUIRES THE X16 BUILD. RUN WITH:  INCLUDE X16FX.FTH
DECIMAL
VARIABLE #FAIL
: CHECK ( actual expected -- )
   2DUP = IF 2DROP ."  OK" CR
   ELSE ."  FAIL GOT=" SWAP . ." WANT=" . 1 #FAIL +! CR THEN ;
: RUN-FX
   0 #FAIL !
   CR ." == X16 VERA FX TESTS ==" CR
   \ FX-MULT ( a b -- lo hi ) signed 16x16 -> 32-bit via VERA's multiplier
   1000 1000 FX-MULT  ." FX-MULT +hi " 15 CHECK  ." FX-MULT +lo " 16960 CHECK
   -2 3 FX-MULT       ." FX-MULT -hi " -1 CHECK  ." FX-MULT -lo " -6 CHECK
   12345 6789 FX-MULT ." FX-MULT big " 1278 CHECK  ." (lo) " 55197 CHECK
   \ DCSEL selects the FX register bank (0-63); exercise + restore to 0
   6 DCSEL  0 DCSEL   ." DCSEL       " 111 111 CHECK
   ." ALIVE       " 12345 12345 CHECK
   CR #FAIL @ 0= IF ." ALL VERA FX TESTS PASSED" ELSE ." VERA FX FAILURES: " #FAIL @ . THEN CR ;
RUN-FX
