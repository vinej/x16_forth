\ FORTHX16 - BIT / BYTE MANIPULATION SELF-TEST
\ Checks CATNIB SPLIT SBIT CBIT FBIT (and the core LSHIFT RSHIFT).
\ RUN WITH:  INCLUDE X16BITS.FTH

DECIMAL
VARIABLE #FAIL
\ scratch byte for the *BIT words
VARIABLE TB

: CHECK
   2DUP = IF 2DROP ."  OK" CR
   ELSE ."  FAIL GOT=" SWAP . ." WANT=" . 1 #FAIL +! CR THEN ;

\ HEX so the literals below are compiled in base 16 (number conversion happens
\ at compile time, so an inner HEX would be too late).
HEX
: RUN-BITS
   0 #FAIL !
   CR ." == X16 BIT / BYTE TESTS ==" CR
   ." CATNIB   " 8 9 CATNIB    89 CHECK
   ." CATNIB0  " F 0 CATNIB    F0 CHECK
   ." CATNIBm  " 1F 2A CATNIB  FA CHECK        \ only low nibbles used
   ." SPLIT lo " 89AB SPLIT NIP   AB CHECK     \ ( -> 89 AB ) keep low
   ." SPLIT hi " 89AB SPLIT DROP  89 CHECK     \ keep high
   ." SBIT     " 55 TB C!  TB 0F SBIT  TB C@  5F CHECK   \ 55 OR 0F
   ." CBIT     " 55 TB C!  TB 0F CBIT  TB C@  50 CHECK   \ 55 AND not 0F
   ." FBIT set " 55 TB C!  1 TB 88 FBIT  TB C@  DD CHECK \ flag true -> set
   ." FBIT clr " 55 TB C!  0 TB 05 FBIT  TB C@  50 CHECK \ flag false -> clear
   ." LSHIFT   " 1 8 LSHIFT   100 CHECK        \ 1<<8 = $100
   ." RSHIFT   " 8000 F RSHIFT  1 CHECK        \ $8000>>15 = 1
   ." ALIVE    " 3039 3039 CHECK
   CR #FAIL @ 0= IF ." ALL BIT/BYTE TESTS PASSED" ELSE ." BIT FAILURES: " #FAIL @ . THEN CR ;
DECIMAL

RUN-BITS
