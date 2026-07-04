\ ASMIRQ.FTH - running assembly in an interrupt (VSYNC) on the X16.
\ ===========================================================================
\ Load the assembler first:   S" ASSEMBLER.FTH" INCLUDED   S" ASMIRQ.FTH" INCLUDED
\
\ In a game the interrupt is usually the ONE place you truly want assembly: the
\ per-frame handler (music tick, sprite multiplexer, scroll register, timers)
\ must be short and run every single frame no matter what the main loop is doing.
\
\ ForthX16 already provides safe interrupt plumbing so you do NOT have to touch
\ CINV by hand:
\     xt IRQ      arm  : run execution-token xt once per interrupt (~60 Hz VSYNC)
\     0  IRQ      disarm
\     VSYNC       block until the next video frame  ( -- )
\     FRAMES      free-running 0..255 frame counter  ( -- n )
\ The dispatcher saves/restores the whole Forth VM around the callback, runs it
\ on its own private stacks, and chains to the KERNAL handler - so the callback
\ can be ANY word.  Installing a CODE word makes it a pure-assembly ISR.
\
\ Rules for an interrupt callback:
\   * stack effect ( -- ): it starts on an empty private stack, so take nothing.
\   * keep it SHORT - it runs inside the frame interrupt.
\   * touch only memory/registers you own; if you use VERA's address ports, save
\     and restore them (the foreground may be mid-transfer).  The example below
\     only touches its own RAM, so it is always safe.

DECIMAL

VARIABLE GTICK        \ our own 16-bit frame counter, bumped by the asm ISR
VARIABLE HB           \ heartbeat: low byte mirrored so a game could poll a flag

\ ---------------------------------------------------------------------------
\ The assembly interrupt callback: increment a 16-bit counter, stash its low
\ byte.  Pure 6502, no stack use, returns to the dispatcher via NEXT JMP,.
\ ---------------------------------------------------------------------------
CODE IRQ-TICK ( -- )
   GTICK INC,
   BEQ: IF, GTICK 1+ INC, THEN,      \ 16-bit increment (carry into high byte)
   GTICK LDA, HB STA,                 \ mirror low byte into HB
   NEXT JMP,
END-CODE

: TICK-ON  ( -- )   0 GTICK !  0 HB !  ['] IRQ-TICK IRQ ;
: TICK-OFF ( -- )   0 IRQ ;

\ ---------------------------------------------------------------------------
\ Demo: arm the assembly ISR, watch GTICK climb (paced by VSYNC), disarm.
\ GTICK is advanced entirely by the interrupt; the main loop just samples it.
\ ---------------------------------------------------------------------------
: IRQ-DEMO ( -- )
   TICK-ON
   CR ." Assembly VSYNC ISR armed. GTICK is bumped in the interrupt:" CR
   8 0 DO
      VSYNC VSYNC VSYNC VSYNC VSYNC   \ let 5 frames pass
      ." GTICK=" GTICK @ .  ." HB=" HB @ .  ." FRAMES=" FRAMES . CR
   LOOP
   TICK-OFF
   CR ." Disarmed.  GTICK stops now." CR ;

\ ---------------------------------------------------------------------------
\ Headless self-test: GTICK must advance while armed and freeze after disarm.
\ ---------------------------------------------------------------------------
VARIABLE I#OK   VARIABLE I#BAD   0 I#OK !   0 I#BAD !
: ICHECK ( flag -- )
   IF 1 I#OK +! ."   [OK]  " ELSE 1 I#BAD +! ."   [FAIL] " THEN ;

: IRQ-TEST ( -- )
   TICK-ON
   30 0 DO VSYNC LOOP                 \ ~30 frames should pass
   GTICK @ ( n )
   .( GTICK advanced )  DUP 0> ICHECK  ." GTICK=" . CR
   .( GTICK tracks FRAMES ) GTICK @ 20 > ICHECK CR
   TICK-OFF
   GTICK @                            \ snapshot after disarm
   20 0 DO VSYNC LOOP                 \ frames keep coming, ISR must NOT run
   GTICK @ ( snap now )
   .( frozen after disarm ) = ICHECK CR
   CR ." IRQ test: " I#OK @ . ." ok, " I#BAD @ . ." failed" CR ;
