\ FORTHX16 - PCM AUDIO FIFO SELF-TEST (native PCMCTRL/PCMRATE/PCM!/PCMFULL?/PCM-WRITE)
\ REQUIRES THE X16 BUILD. RUN WITH:  INCLUDE X16PCM.FTH
DECIMAL
VARIABLE #FAIL
: CHECK 2DUP = IF 2DROP ."  OK" CR
   ELSE ."  FAIL GOT=" SWAP . ." WANT=" . 1 #FAIL +! CR THEN ;
CREATE PBUF 300 ALLOT
: FILLFIFO 5000 0 DO 0 PCM! LOOP ;      \ push >4K bytes into the 4K FIFO
: RUN-PCM
   0 #FAIL !
   CR ." == X16 PCM TESTS ==" CR
   144 PCMCTRL  0 PCMRATE               \ reset the FIFO (bit7), rate 0 = no drain
   ." empty full? " PCMFULL? 0 CHECK
   FILLFIFO
   ." after 5000   " PCMFULL? -1 CHECK   \ FIFO full -> true (-1)
   144 PCMCTRL                          \ reset -> empties the FIFO
   ." after reset  " PCMFULL? 0 CHECK
   144 PCMCTRL  PBUF 200 PCM-WRITE      \ blast 200 bytes (< 4K, not full)
   ." PCM-WRITE    " PCMFULL? 0 CHECK
   128 PCMRATE  0 PCMRATE               \ set/clear the sample rate (exercise)
   ." PCMRATE      " 111 111 CHECK
   ." ALIVE        " 12345 12345 CHECK
   CR #FAIL @ 0= IF ." ALL PCM TESTS PASSED" ELSE ." PCM FAILURES: " #FAIL @ . THEN CR ;
RUN-PCM
