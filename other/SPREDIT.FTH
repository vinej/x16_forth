\ SPREDIT.FTH - a sprite read / modify / create utility for the Commander X16.
\ ===========================================================================
\ Edits a 4bpp VERA sprite (2 pixels per byte, high nibble = left pixel, colours
\ 0-15; colour 0 = transparent). The image lives in the KERNAL's designated
\ sprite-image area (VRAM bank 1, $3000) so it is safe in text mode, and is shown
\ live on hardware sprite 1 while you edit.
\
\ Load:   INCLUDE SPREDIT.FTH
\
\ Quick start
\   16 16 SPNEW          \ new blank 16x16 sprite (also 8/32/64)
\   SPDEMO               \ draw a sample (border + diagonal) and show it
\   SPED                 \ interactive editor (arrows, 0-F, SPACE, Q)
\   SPDUMP               \ print the sprite as a grid of colour nibbles
\
\ Pixel words
\   c x y SPSET          \ set pixel (x,y) to colour c
\   x y SPGET  ( -- c )  \ read the colour of pixel (x,y)
\   c SPFILL             \ fill the whole sprite with colour c
\   SPCLR                \ clear to colour 0 (transparent)
\   SPSHOW / SPHIDE      \ show / hide the live preview sprite
\
\ Disk (device 8)
\   S" MY.SPR" SPR-SAVE  \ save the raw image bytes
\   S" MY.SPR" SPR-LOAD  \ load them back (then SPSHOW)

DECIMAL

\ --- configuration (change before SPNEW if you like) -----------------------
1     VALUE SPR-BANK      \ VRAM bank of the image (1 = designated sprite area)
$3000 VALUE SPR-ADDR      \ VRAM address in that bank; must stay 32-aligned
16    VALUE SPR-W         \ pixel width   (8 / 16 / 32 / 64)
16    VALUE SPR-H         \ pixel height  (8 / 16 / 32 / 64)
1     VALUE SPR#          \ hardware sprite used for the live preview (0 = mouse)
280   VALUE SPR-X         \ live-preview sprite position on screen, X
40    VALUE SPR-Y         \ live-preview sprite position on screen, Y

\ --- helpers ---------------------------------------------------------------
: SPR-BYTES ( -- n )      SPR-W 2/ SPR-H * ;          \ image size in bytes (4bpp)
: SPVADDR   ( off -- )    SPR-BANK SWAP SPR-ADDR + VADDR ;   \ point VERA at a byte
: SPOFF     ( x y -- o )  SPR-W 2/ *  SWAP 2/  + ;    \ pixel -> byte offset
: .NIB      ( n -- )      DUP 9 > IF 7 + THEN [CHAR] 0 + EMIT ;
: .PIX      ( c -- )      DUP 0= IF DROP [CHAR] . EMIT ELSE .NIB THEN ;

VARIABLE SP-PAR           \ x parity of the pixel being touched (1 = odd = low nibble)
VARIABLE SP-OFF           \ byte offset being written

\ --- read / write a single pixel -------------------------------------------
: SPGET ( x y -- c )
   OVER 1 AND SP-PAR !
   SPOFF SPVADDR V@
   SP-PAR @ IF $0F AND ELSE 4 RSHIFT THEN ;

: SPSET ( c x y -- )
   OVER 1 AND SP-PAR !
   SPOFF SP-OFF !
   SP-OFF @ SPVADDR V@                         \ current byte
   SP-PAR @ IF  $F0 AND SWAP $0F AND OR        \ odd x  -> replace low nibble
            ELSE $0F AND SWAP 4 LSHIFT OR THEN \ even x -> replace high nibble
   SP-OFF @ SPVADDR V! ;

\ --- whole-sprite operations -----------------------------------------------
: SPCLR  ( -- )     0 SPVADDR  0 SPR-BYTES VFILL ;
: SPFILL ( c -- )   DUP 4 LSHIFT OR  0 SPVADDR  SPR-BYTES VFILL ;
: SPNEW  ( w h -- ) TO SPR-H  TO SPR-W  SPCLR ;

\ --- grid dump (colour nibble per pixel, '.' = transparent) ----------------
: SPDUMP ( -- )
   CR SPR-H 0 DO
      SPR-W 0 DO  I J SPGET .PIX  LOOP  CR
   LOOP ;

\ --- live hardware preview -------------------------------------------------
: SPSIZECODE ( px -- code )   \ 8/16/32/64 -> 0/1/2/3
   DUP 64 = IF DROP 3 EXIT THEN
   DUP 32 = IF DROP 2 EXIT THEN
   16 = IF 1 ELSE 0 THEN ;
: SPSHOW ( -- )
   SPR# SPR-BANK SPR-ADDR SPRITE-MEM               \ point sprite at the image (4bpp)
   SPR-W SPSIZECODE SPR-H SPSIZECODE SPR# SPRITE-SIZE
   SPR-X SPR-Y SPR# SPRITE-POS
   3 SPR# SPRITE-Z                                 \ in front of everything
   SPRITES-ON ;
: SPHIDE ( -- )  0 SPR# SPRITE-Z ;

\ --- disk (raw image bytes on device 8) ------------------------------------
: SPR-SAVE ( c-addr u -- )  SPR-BANK SPR-ADDR SPR-BYTES VSAVE ;
: SPR-LOAD ( c-addr u -- )  8 SPR-BANK SPR-ADDR BVLOAD ;

\ --- interactive editor (incremental redraw - only changed cells repaint) ---
VARIABLE CUR-X  VARIABLE CUR-Y  VARIABLE ED-DONE
4 VALUE GRID-ROW0     \ screen row of the top grid line
2 VALUE GRID-COL0     \ screen column of the left grid edge

: HEXVAL ( key -- n true | false )    \ decode a colour key 0-9 / A-F
   DUP [CHAR] 0 [CHAR] 9 1+ WITHIN IF [CHAR] 0 - TRUE EXIT THEN
   DUP [CHAR] A [CHAR] F 1+ WITHIN IF [CHAR] A - 10 + TRUE EXIT THEN
   DROP FALSE ;
: STEP-X ( d -- )  CUR-X @ + 0 MAX SPR-W 1- MIN CUR-X ! ;
: STEP-Y ( d -- )  CUR-Y @ + 0 MAX SPR-H 1- MIN CUR-Y ! ;
: >UPPER ( c -- c )  DUP [CHAR] a [CHAR] z 1+ WITHIN IF 32 - THEN ;  \ a-z -> A-Z

: AT-CELL   ( x y -- )      GRID-ROW0 + SWAP GRID-COL0 + LOCATE ;  \ LOCATE ( row col -- )
: DRAW-CELL ( x y hl -- )   \ repaint one grid cell; hl<>0 = cursor (black on yellow)
   >R 2DUP AT-CELL
   R> IF 0 7 COLOR THEN     \ cursor cell: black on yellow (clearly visible)
   SPGET .PIX
   1 6 COLOR ;             \ restore the normal white-on-blue
: DRAW-GRID ( -- )          \ full grid, drawn once
   SPR-H 0 DO  0 I AT-CELL  SPR-W 0 DO  I J SPGET .PIX  LOOP  LOOP ;
: DRAW-HEADER ( -- )
   0 0 LOCATE ." SPRITE EDITOR  " SPR-W . [CHAR] x EMIT SPR-H . ;
: DRAW-STATUS ( -- )        \ one line, repainted on every key
   1 0 LOCATE ." cursor " CUR-X @ 2 .R [CHAR] , EMIT CUR-Y @ 2 .R
   ."   colour=" CUR-X @ CUR-Y @ SPGET .NIB ."    " ;
: DRAW-HELP ( -- )
   GRID-ROW0 SPR-H + 1+ 0 LOCATE
   ." arrows move   0-9 A-F colour   SPACE erase   Q quit " ;
: DRAW-PAL ( -- )      \ colour legend: each key 0-F followed by a swatch of its colour
   GRID-ROW0 SPR-H + 2 + 0 LOCATE  ." colours: "
   16 0 DO
      I .NIB  0 I COLOR SPACE SPACE  1 6 COLOR  SPACE
   LOOP ;

: MOVE-CUR ( dx dy -- )     \ only two cells change: old cursor and new cursor
   CUR-X @ CUR-Y @ 0 DRAW-CELL      \ un-highlight the old cell
   SWAP STEP-X STEP-Y               \ apply the clamped move
   CUR-X @ CUR-Y @ 1 DRAW-CELL      \ highlight the new cell
   DRAW-STATUS ;
: PAINT ( c -- )            \ one cell changes
   CUR-X @ CUR-Y @ SPSET
   CUR-X @ CUR-Y @ 1 DRAW-CELL  DRAW-STATUS ;
: ED-KEY ( key -- )
   >UPPER CASE                        \ fold a-f/q to A-F/Q so either case works
      145 OF  0 -1 MOVE-CUR ENDOF     \ cursor up
      17  OF  0  1 MOVE-CUR ENDOF     \ cursor down
      157 OF -1  0 MOVE-CUR ENDOF     \ cursor left
      29  OF  1  0 MOVE-CUR ENDOF     \ cursor right
      32  OF  0 PAINT ENDOF           \ SPACE erases (colour 0)
      [CHAR] Q OF 1 ED-DONE ! ENDOF
      DUP HEXVAL IF PAINT THEN        \ colour key -> paint current cell
   ENDCASE ;
: SPED ( -- )               \ best for 8/16/32 sizes (64 is taller than the screen)
   0 CUR-X ! 0 CUR-Y ! 0 ED-DONE !
   SPSHOW  CLS  1 6 COLOR
   DRAW-HEADER DRAW-GRID DRAW-HELP DRAW-PAL
   3 34 LOCATE ." live sprite:"          \ labels the real hardware sprite at right
   CUR-X @ CUR-Y @ 1 DRAW-CELL  DRAW-STATUS
   BEGIN  KEY ED-KEY  ED-DONE @  UNTIL
   1 6 COLOR
   GRID-ROW0 SPR-H + 3 + 0 LOCATE
   ." Sprite kept in VRAM.  SPDUMP to view, SPR-SAVE to keep it." CR ;

\ --- sample -----------------------------------------------------------------
: SPDEMO ( -- )
   16 16 SPNEW
   SPR-W 0 DO  6 I 0 SPSET  6 I SPR-H 1- SPSET  LOOP   \ top & bottom edges
   SPR-H 0 DO  6 0 I SPSET  6 SPR-W 1- I SPSET  LOOP   \ left & right edges
   SPR-W 0 DO  2 I I SPSET  LOOP                       \ red diagonal
   SPSHOW ;

CR .( SPREDIT loaded.  16 16 SPNEW | SPDEMO | SPED | SPDUMP ) CR
