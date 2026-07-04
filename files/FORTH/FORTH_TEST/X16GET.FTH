\ FORTHX16 - CURSOR / SPRITE-POSITION GETTER SELF-TEST
\ Checks CURSOR (read text cursor, inverse of LOCATE) and SPRITE-GET (read a
\ sprite's position, inverse of SPRITE-POS). RUN WITH:  INCLUDE X16GET.FTH

DECIMAL
VARIABLE #FAIL
VARIABLE RR  VARIABLE CC
VARIABLE SX  VARIABLE SY

: CHECK
   2DUP = IF 2DROP ."  OK" CR
   ELSE ."  FAIL GOT=" SWAP . ." WANT=" . 1 #FAIL +! CR THEN ;

: RUN-GET
   0 #FAIL !
   \ read the cursor back immediately after positioning it (no output between)
   15 40 LOCATE  CURSOR  CC !  RR !
   0 0 LOCATE
   CR ." == X16 CURSOR / SPRITE-GET TESTS ==" CR
   ." CURSOR row " RR @  15 CHECK
   ." CURSOR col " CC @  40 CHECK

   100 200 3 SPRITE-POS   3 SPRITE-GET  SY !  SX !
   ." SPRITE-GET 3 x " SX @  100 CHECK
   ." SPRITE-GET 3 y " SY @  200 CHECK
   300 400 5 SPRITE-POS   5 SPRITE-GET  SY !  SX !
   ." SPRITE-GET 5 x " SX @  300 CHECK
   ." SPRITE-GET 5 y " SY @  400 CHECK

   ." ALIVE     " 12345 12345 CHECK
   CR #FAIL @ 0= IF ." ALL CURSOR/SPRITE-GET TESTS PASSED" ELSE ." GET FAILURES: " #FAIL @ . THEN CR ;

RUN-GET
