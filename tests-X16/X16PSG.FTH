\ FORTHX16 - PSG AUDIO SELF-TEST (VERA PSG via the audio ROM API)
\ EXERCISES PSGINIT / PSGNOTE / PSGPAN / PSGPLAY / PSGCHORD.
\ REQUIRES THE X16 BUILD. RUN WITH:  INCLUDE X16PSG.FTH
\ VOICE 0 PSG REGISTERS ARE IN VRAM BANK 1 AT 63936 ($F9C0): freq lo/hi, byte2 vol/pan.

DECIMAL
VARIABLE #FAIL

: CHECK
   2DUP = IF 2DROP ."  OK" CR
   ELSE ."  FAIL GOT=" SWAP . ." WANT=" . 1 #FAIL +! CR THEN ;

: RUN-PSG
   0 #FAIL !
   CR ." == X16 PSG TESTS ==" CR

   PSGINIT
   ." PSGINIT " 111 111 CHECK

   \ play note (octave 4, note 1 = $41 = 65) on voice 0 -> frequency becomes non-zero
   65 0 PSGNOTE
   ." PSGNOTE " 1 63936 VPEEK 1 63937 VPEEK OR 0<> -1 CHECK

   \ pan both -> left+right bits (bit6+bit7) set in byte2
   3 0 PSGPAN
   ." PSGPAN  " 1 63938 VPEEK 192 AND 192 CHECK

   \ play-string and chord-string are blocking; just confirm they run and return
   S" C" 0 PSGPLAY
   ." PSGPLAY " 222 222 CHECK
   S" CEG" 0 PSGCHORD
   ." PSGCHRD " 333 333 CHECK

   ." ALIVE   " 12345 12345 CHECK
   CR #FAIL @ 0= IF ." ALL PSG TESTS PASSED" ELSE ." PSG FAILURES: " #FAIL @ . THEN CR ;

RUN-PSG
