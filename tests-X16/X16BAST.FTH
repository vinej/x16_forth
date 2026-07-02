\ FORTHX16 - BASIC-STYLE ALIAS SELF-TEST
\ Checks the BASIC-named aliases baked into the X16 build (formerly
\ toolkit/X16BASIC.FTH): OPEN CLOSE LINPUT and the FP names
\ SQR SIN COS TAN ATN LOG EXP. FP results are integer-valued (via F>S)
\ so they are deterministic. RUN WITH:  INCLUDE X16BAST.FTH
\ (The OPEN/CLOSE check opens this file itself, so it must be in the cwd.)

DECIMAL
VARIABLE #FAIL

: CHECK
   2DUP = IF 2DROP ."  OK" CR
   ELSE ."  FAIL GOT=" SWAP . ." WANT=" . 1 #FAIL +! CR THEN ;

: RUN-BAS
   0 #FAIL !
   CR ." == X16 BASIC-ALIAS TESTS ==" CR

   \ File-access aliases: open this source file read-only, then close it.
   ." OPEN    " S" X16BAST.FTH" R/O OPEN SWAP >R 0 CHECK   ( keep fileid on R )
   ." CLOSE   " R> CLOSE 0 CHECK

   \ Input alias: cannot be exercised headless; just confirm it is defined.
   ." LINPUT  " ['] LINPUT 0<> -1 CHECK

   \ Floating-point name aliases ( F: r -- f(r) ), checked via F>S.
   ." SQR     " 10000 S>F SQR F>S 100 CHECK
   ." SIN     " 0 S>F SIN F>S 0 CHECK
   \ cos(0) is ~0.9999997 from the ROM; add 0.5 so F>S rounds instead of truncating
   ." COS     " 0 S>F COS 1 S>F 2 S>F F/ F+ F>S 1 CHECK
   ." TAN     " 0 S>F TAN F>S 0 CHECK
   ." ATN     " 0 S>F ATN F>S 0 CHECK
   ." LOG     " 1 S>F LOG F>S 0 CHECK
   ." EXP     " 0 S>F EXP F>S 1 CHECK

   ." ALIVE   " 12345 12345 CHECK
   CR #FAIL @ 0= IF ." ALL BASIC-ALIAS TESTS PASSED" ELSE ." BAS FAILURES: " #FAIL @ . THEN CR ;

RUN-BAS
