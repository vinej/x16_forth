\ FORTHX16 - FLOATING-POINT DEFINING-WORD SELF-TEST
\ Checks the FP defining words baked into the X16 build (formerly
\ toolkit/X16FP.FTH): FVARIABLE and FCONSTANT. Results are integer-valued
\ (via F>S) so they are deterministic. RUN WITH:  INCLUDE X16FPT.FTH

DECIMAL
VARIABLE #FAIL

: CHECK
   2DUP = IF 2DROP ."  OK" CR
   ELSE ."  FAIL GOT=" SWAP . ." WANT=" . 1 #FAIL +! CR THEN ;

\ Defining words must run in interpret mode, so create the words up front.
FVARIABLE FV1
FVARIABLE FV2
7   S>F FCONSTANT SEVEN
100 S>F FCONSTANT HUNDRED

: RUN-FP
   0 #FAIL !
   CR ." == X16 FP DEFINING-WORD TESTS ==" CR

   \ FVARIABLE: 5-byte float cell, store / fetch round trip
   ." FVAR set " 42 S>F FV1 F! FV1 F@ F>S 42 CHECK
   ." FVAR upd " 99 S>F FV1 F! FV1 F@ F>S 99 CHECK
   ." FVAR 2nd " 7 S>F FV2 F! FV2 F@ F>S 7 CHECK
   ." FVAR sep " FV1 F@ F>S 99 CHECK        \ FV1 unaffected by FV2 store
   ." FVAR adr " FV1 FV2 <> -1 CHECK        \ two variables get distinct cells

   \ FCONSTANT: pushes its stored float on every invocation
   ." FCON     " SEVEN F>S 7 CHECK
   ." FCON x2  " SEVEN SEVEN F* F>S 49 CHECK \ usable more than once
   ." FCON 100 " HUNDRED F>S 100 CHECK
   ." FCON mix " HUNDRED SEVEN F- F>S 93 CHECK

   ." ALIVE   " 12345 12345 CHECK
   CR #FAIL @ 0= IF ." ALL FP-DEFINING TESTS PASSED" ELSE ." FP FAILURES: " #FAIL @ . THEN CR ;

RUN-FP
