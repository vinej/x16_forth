\ FORTHX16 - STRING / NUMBER-CONVERSION SELF-TEST
\ Checks each string word with COMPARE. These words live in toolkit/BASICSTR.FTH,
\ which this test loads first.
\ RUN WITH:  INCLUDE X16STRT.FTH

DECIMAL
S" BASICSTR.FTH" INCLUDED

VARIABLE #FAIL

: CHECK
   2DUP = IF 2DROP ."  OK" CR
   ELSE ."  FAIL GOT=" SWAP . ." WANT=" . 1 #FAIL +! CR THEN ;

: RUN-STR
   0 #FAIL !
   CR ." == X16 STRING TESTS ==" CR

   ." NHEX   " 255 NHEX S" FF" COMPARE 0 CHECK
   ." NBIN   " 5 NBIN S" 101" COMPARE 0 CHECK
   ." STR    " -42 STR S" -42" COMPARE 0 CHECK
   ." VAL    " S" 1234" VAL 1234 CHECK
   ." ASC    " S" ABC" ASC 65 CHECK
   ." CHR    " 65 CHR S" A" COMPARE 0 CHECK
   ." LEN    " S" HELLO" LEN 5 CHECK
   ." LEFT   " S" HELLO" 3 LEFT S" HEL" COMPARE 0 CHECK
   ." RIGHT  " S" HELLO" 3 RIGHT S" LLO" COMPARE 0 CHECK
   ." MID    " S" HELLO" 2 3 MID S" ELL" COMPARE 0 CHECK
   ." RPT    " 65 3 RPT S" AAA" COMPARE 0 CHECK

   \ edge cases exercising the inlined MIN / /STRING clamping
   ." LEFT>  " S" HI" 9 LEFT S" HI" COMPARE 0 CHECK   \ n > length -> whole string
   ." RIGHT> " S" HI" 9 RIGHT S" HI" COMPARE 0 CHECK
   ." MIDend " S" HELLO" 3 9 MID S" LLO" COMPARE 0 CHECK  \ len past end -> to end
   ." MID1   " S" HELLO" 1 5 MID S" HELLO" COMPARE 0 CHECK \ start=1 -> from head
   ." VALhex " HEX S" FF" VAL DECIMAL 255 CHECK
   ." STR+   " 42 STR S" 42" COMPARE 0 CHECK

   ." ALIVE  " 12345 12345 CHECK
   CR #FAIL @ 0= IF ." ALL STRING TESTS PASSED" ELSE ." STR FAILURES: " #FAIL @ . THEN CR ;

RUN-STR
