\ FORTHX16 - MEMORY / BANKING / SYSTEM SELF-TEST
\ Tests SETBANK, SLEEP, KEYMAP. (RESET/REBOOT/POWEROFF are not exercised here -
\ they change hardware state or reset the machine.)
\ REQUIRES THE X16 BUILD. RUN WITH:  INCLUDE X16MEM.FTH

DECIMAL
VARIABLE #FAIL

: CHECK
   2DUP = IF 2DROP ."  OK" CR
   ELSE ."  FAIL GOT=" SWAP . ." WANT=" . 1 #FAIL +! CR THEN ;

: RUN-MEM
   0 #FAIL !
   CR ." == X16 MEM TESTS ==" CR

   \ SETBANK sets the RAM bank register at $00; read it back
   5 SETBANK
   ." SETBANK " 0 C@ 5 CHECK
   0 SETBANK

   \ SLEEP a few jiffies and return
   3 SLEEP
   ." SLEEP   " 111 111 CHECK

   \ set the default keyboard layout
   S" en-us" KEYMAP
   ." KEYMAP  " 111 111 CHECK

   ." ALIVE   " 12345 12345 CHECK
   CR #FAIL @ 0= IF ." ALL MEM TESTS PASSED" ELSE ." MEM FAILURES: " #FAIL @ . THEN CR ;

RUN-MEM
