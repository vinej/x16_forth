\ FORTHX16 - LOAD / SAVE SELF-TEST
\ SAVE + BLOAD round-trip, VLOAD/BVLOAD into VRAM, and BVERIFY match/mismatch.
\ REQUIRES THE X16 BUILD and the host files RAW.BIN (bytes 10,20,30,40) present.
\ RUN WITH:  INCLUDE X16LDSV.FTH   (device 8 = host filesystem)

DECIMAL
VARIABLE #FAIL
CREATE SVBUF 8 ALLOT
CREATE LDBUF 8 ALLOT
CREATE VBUF  8 ALLOT

: CHECK
   2DUP = IF 2DROP ."  OK" CR
   ELSE ."  FAIL GOT=" SWAP . ." WANT=" . 1 #FAIL +! CR THEN ;

: SVFILL 8 0 DO 65 I + SVBUF I + C! LOOP ;
: VBFILL 10 VBUF C! 20 VBUF 1 + C! 30 VBUF 2 + C! 40 VBUF 3 + C! ;

: RUN-LDSV
   0 #FAIL !
   CR ." == X16 LOAD/SAVE TESTS ==" CR

   \ SAVE a headered PRG, then BLOAD (relocate) it back into LDBUF
   SVFILL
   S" SV.BIN" 8 SVBUF SVBUF 8 + SAVE
   S" SV.BIN" 8 LDBUF BLOAD
   ." BLOAD   " LDBUF C@ 65 CHECK

   \ VLOAD the headered file into VRAM bank 0 at $5000 (header skipped)
   S" SV.BIN" 8 0 20480 VLOAD
   ." VLOAD   " 0 20480 VPEEK 65 CHECK

   \ BVLOAD the raw file into VRAM bank 0 at $6000 (no header)
   S" RAW.BIN" 8 0 24576 BVLOAD
   ." BVLOAD  " 0 24576 VPEEK 10 CHECK
   ." BVLOAD2 " 0 24577 VPEEK 20 CHECK

   \ BVERIFY the raw file against matching then mismatching memory
   VBFILL
   ." BVRFY+  " S" RAW.BIN" 8 VBUF BVERIFY -1 CHECK
   99 VBUF C!
   ." BVRFY-  " S" RAW.BIN" 8 VBUF BVERIFY 0 CHECK

   ." ALIVE   " 12345 12345 CHECK
   CR #FAIL @ 0= IF ." ALL LOAD/SAVE TESTS PASSED" ELSE ." LDSV FAILURES: " #FAIL @ . THEN CR ;

RUN-LDSV
