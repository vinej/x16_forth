\ FORTHX16 - SCROLL / IRQ SELF-TEST
\ Checks the VERA layer-1 hardware scroll words (SCROLLX SCROLLY) by reading
\ the registers back, and the IRQ Forth-callback word (IRQ) by arming a counter
\ callback and confirming it runs and then stops when disarmed.
\ RUN WITH:  INCLUDE X16IRQ.FTH

DECIMAL
VARIABLE #FAIL

: CHECK
   2DUP = IF 2DROP ."  OK" CR
   ELSE ."  FAIL GOT=" SWAP . ." WANT=" . 1 #FAIL +! CR THEN ;

\ VERA layer-1 scroll registers (decimal): L1_HSCROLL_L/H, L1_VSCROLL_L/H
40759 CONSTANT HSCROLL-L   40760 CONSTANT HSCROLL-H
40761 CONSTANT VSCROLL-L   40762 CONSTANT VSCROLL-H

\ A short busy wait so several 60 Hz IRQs can fire.
: WAIT 12000 0 DO LOOP ;

VARIABLE TICKS
: ONTICK 1 TICKS +! ;

: RUN-IRQ
   0 #FAIL !
   CR ." == X16 SCROLL / IRQ TESTS ==" CR

   \ SCROLLX low byte and 12-bit split
   ." SCROLLX lo " 100 SCROLLX  HSCROLL-L C@  100 CHECK
   ." SCROLLX hi " 300 SCROLLX  HSCROLL-L C@   44 CHECK   \ 300 AND 255
   ." SCROLLX nib" HSCROLL-H C@   1 CHECK                 \ 300 >> 8
   \ SCROLLY low byte and 12-bit split
   ." SCROLLY lo " 7 SCROLLY    VSCROLL-L C@    7 CHECK
   ." SCROLLY hi " 258 SCROLLY  VSCROLL-L C@    2 CHECK   \ 258 AND 255
   ." SCROLLY nib" VSCROLL-H C@   1 CHECK                 \ 258 >> 8
   0 SCROLLX 0 SCROLLY                                    \ restore the screen

   \ IRQ callback: arm, confirm it runs, disarm, confirm it stops
   0 TICKS !
   ['] ONTICK IRQ
   WAIT
   ." IRQ runs  " TICKS @ 0>   -1 CHECK                   \ callback fired
   0 IRQ
   ." IRQ stops " TICKS @  WAIT  TICKS @  -   0 CHECK     \ no change while disarmed

   ." ALIVE     " 12345 12345 CHECK
   CR #FAIL @ 0= IF ." ALL SCROLL/IRQ TESTS PASSED" ELSE ." IRQ FAILURES: " #FAIL @ . THEN CR ;

RUN-IRQ
