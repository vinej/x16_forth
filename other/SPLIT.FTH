\ SPLIT.FTH - "Method A" split screen for the Commander X16 (ForthX16 / TX16)
\ ---------------------------------------------------------------------------
\ VERA composites two independent layers, so a bitmap and the text console can
\ share the screen with no raster interrupt. This library puts a 320x240
\ 256-colour bitmap on LAYER 0 and confines the KERNAL text console to a few
\ rows at the BOTTOM of the screen (LAYER 1, composited on top). Graphics fill
\ the area above; the text window scrolls only within itself and the cursor
\ stays inside it.
\
\   INCLUDE SPLIT.FTH
\   SPLIT-DEMO          \ see it in action
\   SPLITOFF            \ back to the normal 80x60 text screen
\
\ This library redefines the standard graphics words to draw straight to the
\ 320x240 8bpp bitmap, so the SAME vocabulary works after SPLITON (split) AND
\ after GINIT (full screen) - both use that bitmap. (The ROM GRAPH versions only
\ worked in full-screen mode 128, which has no text layer, so plain PSET crashed
\ under the split.) Colours 0..255; 0 = transparent.
\   GCLS                           clear the bitmap
\   x y color PSET                 plot one pixel
\   x1 y1 x2 y2 color LINE         line between two points
\   x1 y1 x2 y2 color FRAME        rectangle outline
\   x1 y1 x2 y2 color RECT         filled rectangle
\   x1 y1 x2 y2 color RING         ellipse outline (in the bounding box)
\   x1 y1 x2 y2 color OVAL         filled ellipse
\   x y color c-addr u GTEXT       draw a string into the bitmap
\   x y r color CIRCLE             circle outline (centre x,y radius r)
\   x y r color FCIRCLE            filled circle
\ Or set a pen colour once and drop the colour argument:
\   n GCOLOR                       set the pen colour
\   x y PLOT | x1 y1 x2 y2 DRAW | x y r DISC | x y r CIRC
\   x1 y1 x2 y2 BOX/FBOX (rect) | ELL/FELL (ellipse) | x y c-addr u SAY (text)
\ Low-level helpers are also available: BPSET BHLINE BVLINE BLINE BFILL BRECT BCLS.
\ Text: the normal words work, confined to the bottom window. LOCATE uses
\ window rows 0..(text rows-1). Change the window height before SPLITON with
\ e.g.  8 TO SPLIT-ROWS .
\ ---------------------------------------------------------------------------

DECIMAL

\ Height of the bottom text window, in text rows (screen is 40x30 while split).
6 VALUE SPLIT-ROWS

\ --- VERA / editor registers (byte-wide, C! to write, C@ to read) -----------
$9F25 CONSTANT VERA-CTRL          \ bit1 = DCSEL
$9F29 CONSTANT VERA-DCVIDEO       \ DCSEL=0: bit4 L0 enable, bit5 L1 enable
$9F2D CONSTANT VERA-L0CONFIG
$9F2F CONSTANT VERA-L0TILEBASE
$9F30 CONSTANT VERA-L0HSCROLL_L
$9F39 CONSTANT VERA-L1VSCROLL_L
$9F3A CONSTANT VERA-L1VSCROLL_H
$0387 CONSTANT ED-NLINES          \ editor: number of console rows
$0388 CONSTANT ED-NLINESP1        \   nlines + 1
$0389 CONSTANT ED-NLINESM1        \   nlines - 1

: DCSEL0 ( -- )  VERA-CTRL C@ $FD AND VERA-CTRL C! ;

\ --- bitmap addressing (bitmap at VRAM $00000; pixel = y*320 + x, 17-bit) ----
: BXY>BA ( x y -- bank addr )  320 UM* ROT 0 D+ SWAP ;
: BSEEK  ( x y -- )  BXY>BA VADDR ;

\ --- drawing ----------------------------------------------------------------
: BPSET ( x y color -- )  >R BSEEK R> V! ;
: BHLINE ( x y len color -- )  >R >R BSEEK R> R> SWAP 0 ?DO DUP V! LOOP DROP ;

VARIABLE bf-x   VARIABLE bf-w   VARIABLE bf-c
: BFILL ( x y w h color -- )          \ filled rectangle
   bf-c ! >R bf-w ! SWAP bf-x ! R> OVER + SWAP
   ?DO  bf-x @ I bf-w @ bf-c @ BHLINE  LOOP ;

VARIABLE bv-x   VARIABLE bv-c
: BVLINE ( x y len color -- )         \ vertical run of pixels
   bv-c ! >R SWAP bv-x ! R> OVER + SWAP
   ?DO  bv-x @ I bv-c @ BPSET  LOOP ;

\ Bresenham line between two points.
VARIABLE ln-dx  VARIABLE ln-dy  VARIABLE ln-sx  VARIABLE ln-sy
VARIABLE ln-err VARIABLE ln-x   VARIABLE ln-y
VARIABLE ln-x2  VARIABLE ln-y2  VARIABLE ln-c
: BLINE ( x1 y1 x2 y2 color -- )
   ln-c ! ln-y2 ! ln-x2 ! ln-y ! ln-x !
   ln-x2 @ ln-x @ - ABS ln-dx !
   ln-x @ ln-x2 @ < IF 1 ELSE -1 THEN ln-sx !
   ln-y2 @ ln-y @ - ABS ln-dy !
   ln-y @ ln-y2 @ < IF 1 ELSE -1 THEN ln-sy !
   ln-dx @ ln-dy @ - ln-err !
   BEGIN
      ln-x @ ln-y @ ln-c @ BPSET
      ln-x @ ln-x2 @ <>  ln-y @ ln-y2 @ <>  OR
   WHILE
      ln-err @ 2*
      DUP ln-dy @ NEGATE > IF  ln-dy @ NEGATE ln-err +!  ln-sx @ ln-x +!  THEN
      ln-dx @ < IF  ln-dx @ ln-err +!  ln-sy @ ln-y +!  THEN
   REPEAT ;

VARIABLE br-x VARIABLE br-y VARIABLE br-w VARIABLE br-h VARIABLE br-c
: BRECT ( x y w h color -- )          \ rectangle outline
   br-c ! br-h ! br-w ! br-y ! br-x !
   br-x @ br-y @ br-w @ br-c @ BHLINE
   br-x @  br-y @ br-h @ 1- +  br-w @ br-c @ BHLINE
   br-x @ br-y @ br-h @ br-c @ BVLINE
   br-x @ br-w @ 1- +  br-y @ br-h @ br-c @ BVLINE ;

: BCLS ( color -- )
   0 0 VADDR  240 0 DO  320 0 DO  DUP V!  LOOP  LOOP  DROP ;

\ ===========================================================================
\ Full drawing vocabulary with the SAME names/signatures as the KERNAL GRAPH
\ words (PSET LINE FRAME RECT RING OVAL GTEXT GCLS), but drawing straight to the
\ 320x240 8bpp bitmap at VRAM $0000. That bitmap is what BOTH modes use, so
\ these work after GINIT (full screen) OR after SPLITON (split). They redefine
\ the ROM GRAPH words; the ROM versions were mode-128 only. Two-corner shapes
\ accept the corners in any order (like BASIC).
\ ===========================================================================
: GCLS  ( -- )                 0 BCLS ;
: PSET  ( x y color -- )       BPSET ;
: LINE  ( x1 y1 x2 y2 color -- ) BLINE ;

VARIABLE gx1  VARIABLE gy1  VARIABLE gx2  VARIABLE gy2
: >XYWH ( x1 y1 x2 y2 -- x y w h )        \ sort corners -> x,y,width,height
   gy2 ! gx2 ! gy1 ! gx1 !
   gx1 @ gx2 @ 2DUP > IF SWAP THEN OVER - 1+
   gy1 @ gy2 @ 2DUP > IF SWAP THEN OVER - 1+
   >R SWAP R> ;
: FRAME ( x1 y1 x2 y2 color -- )  >R >XYWH R> BRECT ;   \ rectangle outline
: RECT  ( x1 y1 x2 y2 color -- )  >R >XYWH R> BFILL ;   \ filled rectangle

1 S>F FATAN 2 S>F F* FCONSTANT PIHALF                   \ pi/2

\ Filled ellipse (OVAL): scan every row, half-width = rx*sqrt(1-(dy/ry)^2).
VARIABLE ov-cx VARIABLE ov-cy VARIABLE ov-rx VARIABLE ov-ry VARIABLE ov-c
: OVAL ( x1 y1 x2 y2 color -- )
   >R >XYWH R> ov-c !
   1- 2/ ov-ry !  1- 2/ ov-rx !
   ov-ry @ + ov-cy !  ov-rx @ + ov-cx !
   ov-ry @ 1+  ov-ry @ NEGATE  ?DO
      I S>F  ov-ry @ 1 MAX S>F  F/  FDUP F*  1 S>F FSWAP F-  FSQRT
      ov-rx @ S>F F*  F>S                 ( hw )
      DUP 2* 1+  SWAP  ov-cx @ SWAP -  ov-cy @ I +  ROT  ov-c @ BHLINE
   LOOP ;

\ Ellipse outline (RING): parametric, quarter arc mirrored 4 ways.
VARIABLE ri-cx VARIABLE ri-cy VARIABLE ri-rx VARIABLE ri-ry VARIABLE ri-c VARIABLE ri-n
: RI-PLOT ( px py -- )  ri-cy @ + SWAP ri-cx @ + SWAP ri-c @ BPSET ;
: RI-4 ( px py -- )
   2DUP RI-PLOT
   2DUP SWAP NEGATE SWAP RI-PLOT
   2DUP NEGATE RI-PLOT
   SWAP NEGATE SWAP NEGATE RI-PLOT ;
: RING ( x1 y1 x2 y2 color -- )
   >R >XYWH R> ri-c !
   1- 2/ ri-ry !  1- 2/ ri-rx !
   ri-ry @ + ri-cy !  ri-rx @ + ri-cx !
   ri-rx @ ri-ry @ MAX 1 MAX ri-n !
   ri-n @ 1+ 0 ?DO
      I S>F ri-n @ S>F F/ PIHALF F*        ( F: a )
      FDUP FCOS ri-rx @ S>F F* F>S         ( px )    ( F: a )
      FSIN ri-ry @ S>F F* F>S              ( px py )
      RI-4
   LOOP ;

\ GTEXT: draw a string into the bitmap using the 8x8 ROM charset at VRAM $1F000
\ (indexed by screen code). Assumes the mixed-case set (after 14 EMIT).
VARIABLE gt-x  VARIABLE gt-y  VARIABLE gt-c  VARIABLE gt-x0
CREATE gt-rows 8 ALLOT
: >SCR ( c -- sc )                          \ PETSCII/ASCII -> screen code
   DUP $61 $7B WITHIN IF  $60 -  EXIT THEN   \ a-z -> $01..$1A
   DUP $20 $60 WITHIN IF          EXIT THEN   \ $20..$5F (incl. A-Z) -> same
   DROP $20 ;                                 \ else space
: GLYPH ( sc -- )  8 * $F000 +  1 SWAP VADDR ;   \ VERA -> glyph (bank 1)
: GTEXT ( x y color c-addr u -- )
   >R >R  gt-c ! gt-y ! gt-x !  R> R>
   0 ?DO
      DUP I + C@ >SCR GLYPH                   \ point VERA at glyph
      8 0 DO  V@ gt-rows I + C!  LOOP          \ copy its 8 rows out
      gt-x @ I 8 * + gt-x0 !
      8 0 DO                                   \ I = row
         gt-rows I + C@
         8 0 DO                                \ inner I = column, J = row
            DUP $80 I RSHIFT AND IF
               gt-x0 @ I +  gt-y @ J +  gt-c @ BPSET
            THEN
         LOOP
         DROP
      LOOP
   LOOP DROP ;

\ Circles by centre + radius, built on the ellipse words.
VARIABLE ci-x  VARIABLE ci-y  VARIABLE ci-r
: CIRCLE  ( x y r color -- )      \ outline circle
   >R ci-r ! ci-y ! ci-x !
   ci-x @ ci-r @ -  ci-y @ ci-r @ -  ci-x @ ci-r @ +  ci-y @ ci-r @ +  R> RING ;
: FCIRCLE ( x y r color -- )      \ filled circle
   >R ci-r ! ci-y ! ci-x !
   ci-x @ ci-r @ -  ci-y @ ci-r @ -  ci-x @ ci-r @ +  ci-y @ ci-r @ +  R> OVAL ;

\ --- "pen" API: set the colour once with GCOLOR, then draw without repeating it
VARIABLE PEN   1 PEN !
: GCOLOR ( n -- )            PEN ! ;
: PLOT  ( x y -- )           PEN @ BPSET ;    \ pixel
: DRAW  ( x1 y1 x2 y2 -- )   PEN @ LINE ;     \ line
: BOX   ( x1 y1 x2 y2 -- )   PEN @ FRAME ;    \ rectangle outline
: FBOX  ( x1 y1 x2 y2 -- )   PEN @ RECT ;     \ filled rectangle
: ELL   ( x1 y1 x2 y2 -- )   PEN @ RING ;     \ ellipse outline
: FELL  ( x1 y1 x2 y2 -- )   PEN @ OVAL ;     \ filled ellipse
: CIRC  ( x y r -- )         PEN @ CIRCLE ;   \ circle outline
: DISC  ( x y r -- )         PEN @ FCIRCLE ;  \ filled circle
: SAY   ( x y c-addr u -- )  2>R PEN @ 2R> GTEXT ;   \ text

\ --- text window ------------------------------------------------------------
\ Confine the KERNAL console to the bottom 'n' rows (of 30) and scroll the text
\ layer so those rows render at the bottom of the screen. Layer-1 map is 512 px
\ tall (config $60 as set by SCREEN 3); to put console row 0 at screen row 30-n
\ we scroll by 512-(30-n)*8 = 272+8n pixels.
: L1VSCROLL ( px -- )  DUP VERA-L1VSCROLL_L C!  8 RSHIFT VERA-L1VSCROLL_H C! ;
: TEXT-WINDOW ( n -- )
   DUP ED-NLINES C!  DUP 1+ ED-NLINESP1 C!  1- ED-NLINESM1 C! ;
: FULL-WINDOW ( -- )  30 TEXT-WINDOW  0 L1VSCROLL ;

\ Clear the WHOLE layer-1 tile map to transparent spaces. CLS only clears the
\ nlines console rows, but vertical scroll can expose the other map rows over
\ the graphics, so wipe them all. Map is 128x64 cells ($1B000, config $60).
: CLRTEXT ( -- )
   $9F35 C@ 512 UM* SWAP VADDR       \ point VERA at L1 map base (bank addr)
   8192 0 DO  32 V!  0 V!  LOOP ;     \ 8192 cells: space + colour 0

\ --- turning the split on / off ---------------------------------------------
: SPLITON ( -- )
   3 SCREEN                         \ 40x30 text -> 320x240 scale (matches bitmap)
   $07 VERA-L0CONFIG C!             \ layer 0 = bitmap, 8bpp
   $00 VERA-L0TILEBASE C!           \ bitmap data at $00000, 320 wide
   $00 VERA-L0HSCROLL_L C!          \ palette offset 0
   DCSEL0
   VERA-DCVIDEO C@ $10 OR VERA-DCVIDEO C!   \ enable layer 0 (keep layer 1)
   1 0 COLOR                        \ white text on transparent (index 0)
   CLRTEXT                          \ wipe the whole text map (not just nlines)
   SPLIT-ROWS TEXT-WINDOW           \ console = bottom N rows only
   272 SPLIT-ROWS 8 * + L1VSCROLL   \ scroll those rows to the bottom
   0 0 LOCATE ;                     \ cursor to top-left of the window

: SPLITOFF ( -- )
   FULL-WINDOW
   DCSEL0
   VERA-DCVIDEO C@ $EF AND VERA-DCVIDEO C!   \ disable layer 0
   0 SCREEN ;                       \ back to 80x60 text

\ --- demo -------------------------------------------------------------------
: SPLIT-DEMO ( -- )
   SPLITON  GCLS
   10 10 309 150 3 FRAME             \ green rectangle outline
   20 20 150 90 2 RECT               \ red filled box
   170 15 309 145 6 OVAL            \ blue filled ellipse
   170 15 309 145 1 RING            \ white ellipse outline around it
   10 160 309 10 7 LINE            \ a yellow line
   30 40 4 S" HELLO" GTEXT          \ text drawn INTO the bitmap
   0 192 320 48 6 BFILL             \ blue panel behind the text window
   1 0 COLOR
   0 0 LOCATE ." ForthX16 split screen - Method A"
   2 0 LOCATE ." same PSET LINE RECT RING OVAL GTEXT"
   4 0 LOCATE ." type here - scrolls only in this window" ;
