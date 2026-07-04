\ GAME.FTH - a small 2D game FRAMEWORK for ForthX16 / Commander X16.
\ ===========================================================================
\ "Catch the dots": steer the green player, touch red dots to score; reach 10
\ to win. Demonstrates a reusable structure for your own games:
\
\   input -> logic -> audio-step -> VSYNC -> draw          (one pass = one frame)
\
\ Uses: hardware sprites, VSYNC (frame-locked 60 Hz), FRAMES, COLLIDE?, VFILL,
\ JOY, RND, and the VERA PSG for non-blocking music + sound effects.
\
\   INCLUDE GAME.FTH   PLAY        \ arrow keys move; Start (Enter) quits
\   SELFTEST                       \ non-interactive frame (for testing)
\
\ Runs in SCREEN 3 (320x240); sprite coordinates are 0..319 x 0..239.
\ ===========================================================================

DECIMAL

\ ===========================================================================
\ 1. CONFIG - tweak these for your game
\ ===========================================================================
320 CONSTANT WORLD-W    240 CONSTANT WORLD-H
16  CONSTANT SPR-W      1   CONSTANT SPR-SZ      \ 16x16, SPRITE-SIZE code 1
4   CONSTANT NDOTS      3   CONSTANT SPEED
10  CONSTANT WIN-SCORE

\ joystick-0 button bits (retune live if a build maps the d-pad differently)
1 VALUE J-RIGHT   2 VALUE J-LEFT   4 VALUE J-DOWN   8 VALUE J-UP   16 VALUE J-START

\ ===========================================================================
\ 2. SPRITE IMAGES  (16x16 4bpp = 128 bytes, built with VFILL) in free VRAM
\ ===========================================================================
0   CONSTANT PLR-IMG    128 CONSTANT DOT-IMG
: MK-IMG ( color vaddr -- )  0 SWAP VADDR  17 * 128 VFILL ;   \ solid square

\ ===========================================================================
\ 3. STATE
\ ===========================================================================
VARIABLE PX   VARIABLE PY   VARIABLE SCORE
CREATE DXS NDOTS CELLS ALLOT     CREATE DYS NDOTS CELLS ALLOT
: DX ( i -- a )  CELLS DXS + ;   : DY ( i -- a )  CELLS DYS + ;

\ ===========================================================================
\ 4. AUDIO  (VERA PSG - non-blocking; stepped once per frame)
\ Notes for PSGNOTE are  octave<<4 | semitone(1..12) ; 0 = release/rest.
\ ===========================================================================
0 CONSTANT MVOICE                \ voice 0 = background music
1 CONSTANT SVOICE                \ voice 1 = sound effects
: WAITF ( n -- )  0 ?DO VSYNC LOOP ;

\ Use the KERNAL PSG API. It updates a RAM shadow that VERA is fed from on the
\ audio IRQ (so it makes sound; writing the VERA PSG registers directly does
\ not - the shadow flush overwrites them). PSGNOTE takes  octave<<4 | 1..12,
\ with 0 = release; PSGVOL 0..63; PSGWAV 0=pulse 1=saw 2=triangle 3=noise.

\ background melody: pairs ( note , frames ).  0 note = rest.
CREATE TUNE
   $41 , 20 ,   $45 , 20 ,   $48 , 20 ,   $45 , 20 ,      \ C  E  G  E
   $46 , 20 ,   $43 , 20 ,   $48 , 40 ,   0   , 20 ,      \ F  D  G  rest
HERE TUNE - CONSTANT TUNE-LEN
VARIABLE M-IDX   VARIABLE M-TIMER

: MUSIC-START ( -- )
   PSGINIT
   0 MVOICE PSGWAV   28 MVOICE PSGVOL
   0 M-IDX !   1 M-TIMER ! ;       \ 1 -> play first note next step
: MUSIC-STEP ( -- )                \ call once per frame
   -1 M-TIMER +!
   M-TIMER @ 0> IF EXIT THEN
   28 MVOICE PSGVOL                \ (re)assert volume in case a rest cleared it
   M-IDX @ TUNE +  DUP @ MVOICE PSGNOTE  CELL+ @ M-TIMER !
   M-IDX @ 2 CELLS + TUNE-LEN MOD M-IDX ! ;

VARIABLE S-TIMER
: SFX-HIT ( -- )   50 SVOICE PSGVOL  $61 SVOICE PSGNOTE  6 S-TIMER ! ;
: SFX-STEP ( -- )                  \ call once per frame
   S-TIMER @ 0> IF  -1 S-TIMER +!  S-TIMER @ 0= IF 0 SVOICE PSGNOTE THEN  THEN ;

: AUDIO-OFF ( -- )  0 MVOICE PSGNOTE  0 SVOICE PSGNOTE ;
: WIN-TUNE ( -- )                  \ short rising jingle (blocking; game is over)
   45 MVOICE PSGVOL
   $48 MVOICE PSGNOTE  8 WAITF   $4C MVOICE PSGNOTE  8 WAITF
   $51 MVOICE PSGNOTE  8 WAITF   $58 MVOICE PSGNOTE  26 WAITF
   0 MVOICE PSGNOTE ;

\ ===========================================================================
\ 5. HELPERS / INPUT / LOGIC
\ ===========================================================================
: RX ( -- x )  WORLD-W SPR-W - RND ;
: RY ( -- y )  WORLD-H SPR-W - RND ;
: PUTDOT ( i -- )  DUP DX RX SWAP !  DY RY SWAP ! ;
: CLAMP ( v lo hi -- v' )  >R MAX R> MIN ;

: HIT? ( i -- flag )              \ player box vs dot i box
   >R  PX @ PY @ SPR-W SPR-W   R@ DX @ R> DY @ SPR-W SPR-W   COLLIDE? ;

: MOVE-PLAYER ( -- )
   0 JOY
   DUP J-LEFT  AND IF  PX @ SPEED - PX !  THEN
   DUP J-RIGHT AND IF  PX @ SPEED + PX !  THEN
   DUP J-UP    AND IF  PY @ SPEED - PY !  THEN
   DUP J-DOWN  AND IF  PY @ SPEED + PY !  THEN
   DROP
   PX @ 0 WORLD-W SPR-W - CLAMP PX !
   PY @ 0 WORLD-H SPR-W - CLAMP PY ! ;

: CHECK-HITS ( -- )
   NDOTS 0 DO  I HIT? IF  1 SCORE +!  I PUTDOT  SFX-HIT  THEN  LOOP ;

\ ===========================================================================
\ 6. RENDER
\ ===========================================================================
: DRAW ( -- )
   0 PX @ PY @ SPRITE-MOV
   NDOTS 0 DO  I 1+  I DX @  I DY @  SPRITE-MOV  LOOP ;
: SHOW-SCORE ( -- )  0 0 LOCATE ." Score: " SCORE @ .  ."     " ;

\ ===========================================================================
\ 7. SETUP + MAIN LOOP  (input -> logic -> audio -> VSYNC -> draw)
\ ===========================================================================
: SETUP ( -- )
   3 SCREEN
   5 PLR-IMG MK-IMG   2 DOT-IMG MK-IMG
   0 0 PLR-IMG SPRITE-MEM   SPR-SZ SPR-SZ 0 SPRITE-SIZE   0 3 SPRITE
   NDOTS 0 DO
      I 1+ 0 DOT-IMG SPRITE-MEM   SPR-SZ SPR-SZ I 1+ SPRITE-SIZE   I 1+ 3 SPRITE   I PUTDOT
   LOOP
   SPRITES-ON
   WORLD-W 2/ PX !   WORLD-H 2/ PY !   0 SCORE !
   1 6 COLOR CLS ;

\ Quit on Start, but only once Start has been released at least once - so the
\ Enter you pressed to launch PLAY (whenever the keyboard driver registers it)
\ can never trigger an instant quit, regardless of timing.
VARIABLE Q-ARMED
: PLAY ( -- )
   SETUP  MUSIC-START  0 Q-ARMED !
   BEGIN
      MOVE-PLAYER  CHECK-HITS          \ logic (any time in the frame)
      MUSIC-STEP   SFX-STEP            \ advance non-blocking audio
      VSYNC                            \ lock to the frame
      DRAW  SHOW-SCORE                 \ update the display at the boundary
      0 JOY                            ( buttons )
      DUP J-START AND 0= IF  -1 Q-ARMED !  THEN     \ Start released -> arm quit
      J-START AND  Q-ARMED @  AND                    \ quit only if pressed AND armed
      SCORE @ WIN-SCORE < 0=  OR
   UNTIL
   AUDIO-OFF
   SCORE @ WIN-SCORE < 0= IF  8 8 LOCATE ." *** YOU WIN! ***"  WIN-TUNE  THEN
   SPRITES-OFF  0 SCREEN ;

\ Non-interactive check: place the player on a dot, register the catch (+sound),
\ step the audio a few times, render one frame.
: SELFTEST ( -- )
   SETUP  MUSIC-START
   0 DX @ PX !  0 DY @ PY !
   CHECK-HITS
   8 0 DO MUSIC-STEP SFX-STEP LOOP
   DRAW SHOW-SCORE ;
