\ FORTHX16 - INPUT DEVICE SELF-TEST (JOYSTICK / MOUSE)
\ EXERCISES JOY / MOUSE / MX / MY / MB / MWHEEL. WITH NOTHING PRESSED THE
\ BUTTON/WHEEL/JOY READINGS SHOULD BE 0; MX/MY ARE JUST EXERCISED.
\ REQUIRES THE X16 BUILD. RUN WITH:  INCLUDE X16INP.FTH

DECIMAL
VARIABLE #FAIL

: CHECK
   2DUP = IF 2DROP ."  OK" CR
   ELSE ."  FAIL GOT=" SWAP . ." WANT=" . 1 #FAIL +! CR THEN ;

: RUN-INP
   0 #FAIL !
   CR ." == X16 INPUT TESTS ==" CR

   \ keyboard joystick and absent gamepad, nothing pressed -> 0
   ." JOY0   " 0 JOY 0 CHECK
   ." JOY1   " 1 JOY 0 CHECK

   1 MOUSE
   \ no buttons and no wheel movement
   ." MB     " MB 0 CHECK
   ." MWHEEL " MWHEEL 0 CHECK
   \ exercise the position reads (values not asserted)
   MX DROP MY DROP
   0 MOUSE

   ." ALIVE  " 12345 12345 CHECK
   CR #FAIL @ 0= IF ." ALL INPUT TESTS PASSED" ELSE ." INP FAILURES: " #FAIL @ . THEN CR ;

RUN-INP
