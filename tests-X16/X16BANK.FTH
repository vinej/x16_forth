\ FORTHX16 - BULK RAM-BANK I/O SELF-TEST (all X16 builds)
\ Tests MEM>BANK / BANK>MEM / B@ / B! (RAM only, non-destructive scratch bank).
\ REQUIRES THE X16 BUILD. RUN WITH:  INCLUDE X16BANK.FTH
DECIMAL
VARIABLE #FAIL
: CHECK 2DUP = IF 2DROP ."  OK" CR
   ELSE ."  FAIL GOT=" SWAP . ." WANT=" . 1 #FAIL +! CR THEN ;
CREATE BSRC 260 ALLOT
CREATE BDST 260 ALLOT
: RUN-BANK
   0 #FAIL !
   CR ." == X16 BANK I/O TESTS ==" CR
   BSRC 256 65 FILL                    \ 256 bytes of 'A' (65)
   BSRC 12 0 256 MEM>BANK              \ ( addr bank boff u ) -> bank 12:0
   ." B@ off 0    " 12 0 B@   65 CHECK
   ." B@ off 128  " 12 128 B@ 65 CHECK
   ." B@ off 255  " 12 255 B@ 65 CHECK
   BDST 256 0 FILL
   12 0 BDST 256 BANK>MEM              \ ( bank boff addr u ) -> low RAM
   ." roundtrip 0 " BDST C@       65 CHECK
   ." roundtrip255" BDST 255 + C@ 65 CHECK
   99 12 5 B!  ." B! / B@     " 12 5 B@ 99 CHECK   \ single-byte store/fetch
   ." ALIVE       " 12345 12345 CHECK
   CR #FAIL @ 0= IF ." ALL BANK TESTS PASSED" ELSE ." BANK FAILURES: " #FAIL @ . THEN CR ;
RUN-BANK
