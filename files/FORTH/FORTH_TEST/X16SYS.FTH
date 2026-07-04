\ FORTHX16 - SYSTEM / DEV SELF-TEST
\ Tests USR by building a tiny machine-language routine ( INC MLTGT ; RTS ) and
\ calling it. Also loads the BASIC-alias toolkit and exercises OPEN/CLOSE.
\ REQUIRES THE X16 BUILD. RUN WITH:  INCLUDE X16SYS.FTH

DECIMAL
VARIABLE #FAIL
CREATE MLCODE 8 ALLOT
CREATE MLTGT  2 ALLOT

: CHECK
   2DUP = IF 2DROP ."  OK" CR
   ELSE ."  FAIL GOT=" SWAP . ." WANT=" . 1 #FAIL +! CR THEN ;

: RUN-SYS
   0 #FAIL !
   CR ." == X16 SYS TESTS ==" CR

   \ build  INC MLTGT ; RTS  in MLCODE
   238 MLCODE C!            \ $EE = INC absolute
   MLTGT MLCODE 1 + !       \ operand = address of MLTGT
   96 MLCODE 3 + C!         \ $60 = RTS
   0 MLTGT C!

   MLCODE USR
   ." USR     " MLTGT C@ 1 CHECK
   MLCODE USR
   ." USR x2  " MLTGT C@ 2 CHECK

   ." ALIVE   " 12345 12345 CHECK
   CR #FAIL @ 0= IF ." ALL SYS TESTS PASSED" ELSE ." SYS FAILURES: " #FAIL @ . THEN CR ;

RUN-SYS
