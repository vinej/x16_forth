\ GAMEMS.FTH - "catch the dots" + a MOUSE mini-game (joystick + mouse test).
\ ===========================================================================
\ Two ways to score, to 10:
\   * steer the GREEN player with the joystick/keyboard, touch RED dots  (JOY)
\   * click a BLUE square with the mouse (left or right button)          (MOUSE)
\ Also: the mouse WHEEL changes the player's speed.
\
\   input -> logic -> audio-step -> VSYNC -> draw          (one pass = one frame)
\
\ Uses: hardware sprites, VSYNC, COLLIDE?, VFILL, RND, the VERA PSG, and the
\ input words JOY / MOUSE / MX / MY / MB / MWHEEL.  The X16 mouse pointer is
\ hardware sprite 0, so the game's own sprites start at 1.
\
\   INCLUDE GAMEMS.FTH   PLAY      \ arrows/gamepad move, mouse clicks blue squares
\   SELFTEST                       \ non-interactive frame (for testing)
\
\ Runs in SCREEN 0 (80x60 = 640x480) so the mouse coordinates match the sprite
\ coordinates (0..639 x 0..479).  The KERNAL's own hardware mouse pointer (sprite 0)
\ is the cursor.  Launch the emulator with -capture so the mouse range stays correct
\ at any window scale/size, and -nokeyboardcapture so OS keys (Alt+Tab) still work
\ and releasing focus frees the mouse.  Add -joy1 for a gamepad on port 1:
\   x16emu -prg forthx16.prg -run -scale 2 -capture -nokeyboardcapture -joy1
\ ===========================================================================

DECIMAL

\ ===========================================================================
\ 1. CONFIG - tweak these for your game
\ ===========================================================================
\ SCREEN 0 (80x60 = 640x480): the KERNAL does NOT scale the mouse in this mode,
\ so MX/MY match the sprite coordinates (in SCREEN 3 the mouse is halved).
640 CONSTANT WORLD-W    480 CONSTANT WORLD-H
16  CONSTANT SPR-W      1   CONSTANT SPR-SZ      \ 16x16, SPRITE-SIZE code 1
4   CONSTANT NDOTS      3   CONSTANT NBLUE
10  CONSTANT WIN-SCORE

\ hardware-sprite numbers: 0 = mouse pointer (KERNAL), then ours:
1 CONSTANT PLR-SPR                       \ player sprite
: DOT-SPR ( i -- n )  2 + ;              \ red dots at 2 .. 1+NDOTS
: BLU-SPR ( i -- n )  2 NDOTS + + ;      \ blue squares after the dots

\ joystick-0 button bits (retune live if a build maps the d-pad differently)
1 VALUE J-RIGHT   2 VALUE J-LEFT   4 VALUE J-DOWN   8 VALUE J-UP   16 VALUE J-START

\ ===========================================================================
\ 2. SPRITE IMAGES  (16x16 4bpp = 128 bytes, built with VFILL) in free VRAM
\ ===========================================================================
0 CONSTANT PLR-IMG   128 CONSTANT DOT-IMG   256 CONSTANT BLU-IMG
: MK-IMG ( color vaddr -- )  0 SWAP VADDR  17 * 128 VFILL ;   \ solid 16x16 square

\ ===========================================================================
\ 3. STATE
\ ===========================================================================
VARIABLE PX   VARIABLE PY   VARIABLE SCORE
VARIABLE SPEEDV   3 SPEEDV !             \ player speed (mouse wheel changes it)
CREATE DXS NDOTS CELLS ALLOT     CREATE DYS NDOTS CELLS ALLOT
: DX ( i -- a )  CELLS DXS + ;   : DY ( i -- a )  CELLS DYS + ;
CREATE BXS NBLUE CELLS ALLOT     CREATE BYS NBLUE CELLS ALLOT
: BX ( i -- a )  CELLS BXS + ;   : BY ( i -- a )  CELLS BYS + ;
\ mouse state, sampled ONCE per frame (each mouse_get clears the wheel, so read
\ the wheel first): MXV/MYV position, MBV buttons, MWV wheel delta.
VARIABLE MXV  VARIABLE MYV  VARIABLE MBV  VARIABLE MWV
VARIABLE MB-PREV                         \ previous mouse buttons (click-edge detect)

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
: PUTDOT  ( i -- )  DUP DX RX SWAP !  DY RY SWAP ! ;
\ Blue squares are MOUSE targets. The KERNAL keeps the 16x16 mouse pointer sprite
\ fully on-screen and its hotspot is the TOP-LEFT tip, so the tip cannot be pushed
\ to the far right/bottom edge. Keep the blue squares one pointer-size in from the
\ right and bottom, and below BTOP (top reach + clear of the score/debug text), so
\ the pointer tip can always land inside every square.
16 CONSTANT MPTR                 \ mouse pointer sprite size
48 CONSTANT BTOP                 \ top margin (pointer reach + score text)
: RXB ( -- x )  WORLD-W SPR-W - MPTR 2* -  RND  MPTR + ;
: RYB ( -- y )  WORLD-H SPR-W - MPTR -  BTOP -  RND  BTOP + ;
: PUTBLUE ( i -- )  DUP BX RXB SWAP !  BY RYB SWAP ! ;
: CLAMP ( v lo hi -- v' )  >R MAX R> MIN ;

\ ---- joystick: move the player, catch red dots ----
\ Read joystick 0 (keyboard d-pad) OR gamepad on SNES port 1, so either works.
\ JOY returns 0 for an absent controller, so OR-ing is safe.
: JOYIN ( -- buttons )  0 JOY  1 JOY  OR ;
: HIT? ( i -- flag )              \ player box vs dot i box
   >R  PX @ PY @ SPR-W SPR-W   R@ DX @ R> DY @ SPR-W SPR-W   COLLIDE? ;
: MOVE-PLAYER ( -- )
   JOYIN
   DUP J-LEFT  AND IF  PX @ SPEEDV @ - PX !  THEN
   DUP J-RIGHT AND IF  PX @ SPEEDV @ + PX !  THEN
   DUP J-UP    AND IF  PY @ SPEEDV @ - PY !  THEN
   DUP J-DOWN  AND IF  PY @ SPEEDV @ + PY !  THEN
   DROP
   PX @ 0 WORLD-W SPR-W - CLAMP PX !
   PY @ 0 WORLD-H SPR-W - CLAMP PY ! ;
: CHECK-HITS ( -- )
   NDOTS 0 DO  I HIT? IF  1 SCORE +!  I PUTDOT  SFX-HIT  THEN  LOOP ;

\ ---- mouse: click a blue square (left or right button) to score ----
: MOUSE-READ ( -- )              \ sample the mouse once (wheel FIRST - it self-clears)
   MWHEEL MWV !   MX MXV !   MY MYV !   MB MBV ! ;
: BHIT? ( i -- flag )            \ is the mouse pointer over blue square i ?
   >R  MXV @  R@ BX @  DUP SPR-W +  WITHIN
       MYV @  R> BY @  DUP SPR-W +  WITHIN  AND ;
: MOUSE-CHECK ( -- )
   MBV @  DUP 3 AND                          \ 3 = left|right button mask
   MB-PREV @ 3 AND 0=  AND                   \ true only on a fresh press (edge)
   IF  NBLUE 0 DO  I BHIT? IF  1 SCORE +!  I PUTBLUE  SFX-HIT  LEAVE  THEN  LOOP  THEN
   MB-PREV ! ;
: WHEEL-CHECK ( -- )             \ mouse wheel adjusts player speed (1..10)
   MWV @ ?DUP IF  SPEEDV @ +  1 MAX  10 MIN  SPEEDV !  THEN ;

\ ===========================================================================
\ 6. RENDER
\ ===========================================================================
: DRAW ( -- )
   PLR-SPR PX @ PY @ MOVSPR
   NDOTS 0 DO  I DOT-SPR  I DX @  I DY @  MOVSPR  LOOP
   NBLUE 0 DO  I BLU-SPR  I BX @  I BY @  MOVSPR  LOOP ;
: SHOW-SCORE ( -- )
   0 0 LOCATE ." SCORE: " SCORE @ .  ."     "
   1 0 LOCATE ." MX " MXV @ .  ." MY " MYV @ .  ." MB " MBV @ .  ." SPD " SPEEDV @ .  ."     "
   2 0 LOCATE ." JOY " JOYIN .  ."     " ;

\ ===========================================================================
\ 7. SETUP + MAIN LOOP  (input -> logic -> audio -> VSYNC -> draw)
\ ===========================================================================
: MKSPR ( sprite vaddr -- )      \ define one 16x16 sprite from a VRAM image
   OVER >R  0 SWAP SPRMEM   SPR-SZ SPR-SZ R@ SPRITE-SIZE   R> 3 SPRITE ;
: SETUP ( -- )
   0 SCREEN                         \ 640x480 - mouse coords match sprite coords here
   5 PLR-IMG MK-IMG   2 DOT-IMG MK-IMG   6 BLU-IMG MK-IMG
   PLR-SPR PLR-IMG MKSPR
   NDOTS 0 DO  I DOT-SPR DOT-IMG MKSPR  I PUTDOT   LOOP
   NBLUE 0 DO  I BLU-SPR BLU-IMG MKSPR  I PUTBLUE  LOOP
   SPRITES-ON
   1 MOUSE   0 MB-PREV !            \ enable the mouse pointer (hardware sprite 0)
   3 SPEEDV !
   WORLD-W 2/ PX !   WORLD-H 2/ PY !   0 SCORE !
   1 0 COLOR CLS ;                  \ white on BLACK so the blue squares show

\ Quit on Start, but only once Start has been released at least once - so the
\ Enter you pressed to launch PLAY (whenever the keyboard driver registers it)
\ can never trigger an instant quit, regardless of timing.
VARIABLE Q-ARMED
: PLAY ( -- )
   SETUP  MUSIC-START  0 Q-ARMED !
   BEGIN
      MOVE-PLAYER  CHECK-HITS          \ joystick: move + catch red dots
      MOUSE-READ                       \ sample mouse once this frame
      MOUSE-CHECK  WHEEL-CHECK         \ mouse: click blue squares + wheel speed
      MUSIC-STEP   SFX-STEP            \ advance non-blocking audio
      VSYNC                            \ lock to the frame
      DRAW  SHOW-SCORE                 \ update the display at the boundary
      JOYIN                            ( buttons )
      DUP J-START AND 0= IF  -1 Q-ARMED !  THEN     \ Start released -> arm quit
      J-START AND  Q-ARMED @  AND                    \ quit only if pressed AND armed
      SCORE @ WIN-SCORE < 0=  OR
   UNTIL
   AUDIO-OFF  0 MOUSE                   \ mouse pointer off
   SCORE @ WIN-SCORE < 0= IF  8 8 LOCATE ." *** YOU WIN! ***"  WIN-TUNE  THEN
   SPRITES-OFF  0 SCREEN ;

\ Non-interactive check: place the player on a dot, register the catch (+sound),
\ step the audio a few times, render one frame.
: SELFTEST ( -- )
   SETUP  MUSIC-START
   0 DX @ PX !  0 DY @ PY !
   CHECK-HITS                       \ catch a red dot (joystick path)
   MOUSE-READ  MOUSE-CHECK  WHEEL-CHECK   \ exercise mouse/wheel code (no click headless)
   8 0 DO MUSIC-STEP SFX-STEP LOOP
   DRAW SHOW-SCORE  0 MOUSE ;
