\ FORTHX16 - VRAM / SPRITE / TILE SAVE-LOAD SELF-TEST
\ Checks VSAVE (with the existing BVLOAD), SPRSAVE/SPRLOAD, TILESAVE/TILELOAD
\ and TMAPSAVE/TMAPLOAD by round-tripping data through device-8 files.
\ RUN WITH:  INCLUDE X16SAV.FTH   (writes TSAV*.BIN in the current directory)
\ Note: read VRAM back into the stack BEFORE printing - console output uses the
\ VERA data port and would disturb an address set by VADDR.

DECIMAL
VARIABLE #FAIL

: CHECK
   2DUP = IF 2DROP ."  OK" CR
   ELSE ."  FAIL GOT=" SWAP . ." WANT=" . 1 #FAIL +! CR THEN ;

: RUN-SAV
   0 #FAIL !
   CR ." == X16 SAVE/LOAD TESTS ==" CR

   \ VSAVE + BVLOAD (general VRAM save/load), bank 1 offset 8192
   1 8192 VADDR 11 V! 22 V! 33 V!
   S" TSAV1.BIN" 1 8192 3 VSAVE
   1 8192 VADDR 0 V! 0 V! 0 V!
   S" TSAV1.BIN" 8 1 8192 BVLOAD
   1 8192 VADDR V@ V@ V@ + +
   ." VSAVE/BVLOAD " 66 CHECK

   \ SPRSAVE + SPRLOAD (sprite 0: image at $8000, 16x16 4bpp -> self-sized 128 B)
   32768 0 SPRITE-IMAGE   1 1 0 SPRITE-SIZE
   0 32768 VADDR 40 V! 50 V!
   S" TSAV2.BIN" 0 SPRSAVE
   0 32768 VADDR 0 V! 0 V!
   S" TSAV2.BIN" 0 SPRLOAD
   0 32768 VADDR V@ V@ +
   ." SPRSAVE/LOAD " 90 CHECK

   \ TILESAVE + TILELOAD (bank-1 tileset, explicit address + size)
   1 16384 VADDR 77 V! 88 V!
   S" TSAV3.BIN" 16384 2 TILESAVE
   1 16384 VADDR 0 V! 0 V!
   S" TSAV3.BIN" 16384 TILELOAD
   1 16384 VADDR V@ V@ +
   ." TILESAVE/LOAD " 165 CHECK

   \ TMAPSAVE + TMAPLOAD (layer-1 tilemap, self-sizing): round-trip cell (0,0)
   0 0 65 1 TILE
   S" TSAV4.BIN" TMAPSAVE
   0 0 99 1 TILE
   S" TSAV4.BIN" TMAPLOAD
   0 0 TDATA
   ." TMAPSAVE/LOAD " 65 CHECK

   ." ALIVE       " 12345 12345 CHECK
   CR #FAIL @ 0= IF ." ALL SAVE/LOAD TESTS PASSED" ELSE ." SAV FAILURES: " #FAIL @ . THEN CR ;

RUN-SAV
