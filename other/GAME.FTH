\ GAME.FTH - proof-of-concept 2D game for ForthX16 / Commander X16.
\ ---------------------------------------------------------------------------
\ "Catch the dots": steer the green player square and touch the red dots to
\ score. Each dot you catch jumps to a new random spot. A compact demo of the
\ native game primitives and the X16 hardware:
\   hardware sprites (SPRMEM/SPRITE-SIZE/MOVSPR/SPRITE/SPRITES-ON)
\   VSYNC   - 60 fps frame pacing
\   COLLIDE? - bounding-box collision
\   VFILL   - builds the 16x16 sprite images
\   JOY     - input (joystick 0 = keyboard arrows, or a gamepad)
\   RND     - random dot placement
\
\   INCLUDE GAME.FTH   PLAY        \ arrow keys to move; Start to quit
\   SELFTEST                       \ non-interactive: forces one catch (for testing)
\
\ Runs in SCREEN 3 (320x240), so sprite coordinates are 0..319 x 0..239.
\ ---------------------------------------------------------------------------

DECIMAL

\ ---- tunables ----
320 CONSTANT WORLD-W
240 CONSTANT WORLD-H
16  CONSTANT SPR-W                 \ sprite is 16x16 px
1   CONSTANT SPR-SZ                \ SPRITE-SIZE code: 0=8 1=16 2=32 3=64
4   CONSTANT NDOTS
3   CONSTANT SPEED                 \ player pixels per frame

\ joystick-0 button bits (active-high). VALUEs so you can retune if a build maps
\ the d-pad differently:  e.g.  8 TO J-UP .
1  VALUE J-RIGHT
2  VALUE J-LEFT
4  VALUE J-DOWN
8  VALUE J-UP
16 VALUE J-START

\ ---- sprite images: 16x16 4bpp = 128 bytes, in free low VRAM ----
0   CONSTANT PLR-IMG
128 CONSTANT DOT-IMG
: MK-IMG ( color vaddr -- )  0 SWAP VADDR  17 * 128 VFILL ;   \ solid colour square

\ ---- state ----
VARIABLE PX   VARIABLE PY   VARIABLE SCORE
CREATE DXS NDOTS CELLS ALLOT       \ dot X array
CREATE DYS NDOTS CELLS ALLOT       \ dot Y array
: DX ( i -- addr )  CELLS DXS + ;
: DY ( i -- addr )  CELLS DYS + ;

\ ---- helpers ----
: RX ( -- x )  WORLD-W SPR-W - RND ;
: RY ( -- y )  WORLD-H SPR-W - RND ;
: PUTDOT ( i -- )  DUP DX RX SWAP !  DY RY SWAP ! ;         \ random-place dot i
: CLAMP ( v lo hi -- v' )  >R MAX R> MIN ;

\ collision: player box vs dot i box (both SPR-W square)
: HIT? ( i -- flag )
   >R
   PX @ PY @ SPR-W SPR-W                    \ box A = player
   R@ DX @  R> DY @  SPR-W SPR-W            \ box B = dot i
   COLLIDE? ;

: MOVE-PLAYER ( -- )
   0 JOY                                    ( buttons )
   DUP J-LEFT  AND IF  PX @ SPEED - PX !  THEN
   DUP J-RIGHT AND IF  PX @ SPEED + PX !  THEN
   DUP J-UP    AND IF  PY @ SPEED - PY !  THEN
   DUP J-DOWN  AND IF  PY @ SPEED + PY !  THEN
   DROP
   PX @ 0 WORLD-W SPR-W - CLAMP PX !
   PY @ 0 WORLD-H SPR-W - CLAMP PY ! ;

: CHECK-HITS ( -- )
   NDOTS 0 DO
      I HIT? IF  1 SCORE +!  I PUTDOT  THEN
   LOOP ;

: DRAW ( -- )
   0 PX @ PY @ MOVSPR                       \ player = sprite 0
   NDOTS 0 DO  I 1+  I DX @  I DY @  MOVSPR  LOOP ;  \ dots = sprites 1..NDOTS
: SHOW-SCORE ( -- )  0 0 LOCATE ." Score: " SCORE @ . ."    " ;

\ ---- one-time setup ----
: SETUP ( -- )
   3 SCREEN
   5 PLR-IMG MK-IMG                         \ green player
   2 DOT-IMG MK-IMG                         \ red dots
   0 0 PLR-IMG SPRMEM  SPR-SZ SPR-SZ 0 SPRITE-SIZE  0 3 SPRITE
   NDOTS 0 DO
      I 1+ 0 DOT-IMG SPRMEM
      SPR-SZ SPR-SZ I 1+ SPRITE-SIZE
      I 1+ 3 SPRITE
      I PUTDOT
   LOOP
   SPRITES-ON
   WORLD-W 2/ PX !  WORLD-H 2/ PY !
   0 SCORE !
   1 6 COLOR CLS ;

\ ---- the game loop ----
: WAIT-NOSTART ( -- )  BEGIN  0 JOY J-START AND 0=  UNTIL ;  \ let go of Start/Enter

: PLAY ( -- )
   SETUP
   WAIT-NOSTART                     \ ignore the Enter you pressed to launch PLAY
   BEGIN
      MOVE-PLAYER
      CHECK-HITS
      DRAW
      SHOW-SCORE
      VSYNC
      0 JOY J-START AND
   UNTIL
   SPRITES-OFF  0 SCREEN ;

\ ---- non-interactive self-test: place the player on dot 0, register the catch,
\ ---- render one frame. Verifies sprites + COLLIDE? + score without input/VSYNC.
: SELFTEST ( -- )
   SETUP
   0 DX @ PX !  0 DY @ PY !                 \ move player onto dot 0
   CHECK-HITS                               \ -> score 1, dot 0 relocates
   DRAW SHOW-SCORE ;
