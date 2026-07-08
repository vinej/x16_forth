\ GFX.FTH - Commander X16 bitmap graphics toolkit for ForthX16 / TX16
\ ---------------------------------------------------------------------------
\ With GFXTOOLKIT=1 the bitmap-graphics words are no longer baked into the
\ core (that frees ~513 bytes of ROM/image for every X16 build); INCLUDE this
\ file to get them back. They draw straight to a 320x240 8bpp bitmap at VRAM
\ $00000, over the native VERA primitives that STAY in the core (VADDR V! V@
\ VFILL ISQRT), so they are fast and need no floating point.
\
\   GINIT                          enter full-screen 320x240x256 bitmap mode
\   GCLS                           clear the bitmap
\   x y color PSET                 plot one pixel
\   x1 y1 x2 y2 color LINE         line between two points
\   x1 y1 x2 y2 color FRAME        rectangle outline
\   x1 y1 x2 y2 color RECT         filled rectangle
\   x1 y1 x2 y2 color RING         ellipse outline (in the bounding box)
\   x1 y1 x2 y2 color OVAL         filled ellipse
\   x y color c-addr u GTEXT       draw a string into the bitmap
\   x y r color CIRCLE / FCIRCLE   circle outline / filled circle
\ Pen API (set the colour once, drop the colour argument):
\   n GCOLOR  then  x y PLOT | x1 y1 x2 y2 DRAW/BOX/FBOX/ELL/FELL |
\             x y r CIRC/DISC | x y c-addr u SAY
\ Low-level: BPSET BHLINE BVLINE BLINE BFILL BRECT BCLS BSEEK.
\ Colours 0..255; 0 = transparent. This is the standalone full-screen bitmap;
\ for a graphics-over-text split screen use SPLIT.FTH instead (same vocabulary).
\ ---------------------------------------------------------------------------

DECIMAL

\ --- VERA registers ---------------------------------------------------------
$9F25 CONSTANT VERA-CTRL          \ bit1 = DCSEL
$9F29 CONSTANT VERA-DCVIDEO       \ DCSEL=0: bit4 L0 enable, bit5 L1 enable
$9F2D CONSTANT VERA-L0CONFIG
$9F2F CONSTANT VERA-L0TILEBASE
$9F30 CONSTANT VERA-L0HSCROLL_L
: DCSEL0 ( -- )  VERA-CTRL C@ $FD AND VERA-CTRL C! ;

\ GINIT: full-screen 320x240x256 bitmap on VERA layer 0 at VRAM $0000.
: GINIT ( -- )
   128 SCREEN                       \ KERNAL screen mode 128 = 320x240 @ 256
   $07 VERA-L0CONFIG C!             \ layer 0 = bitmap, 8bpp
   $00 VERA-L0TILEBASE C!           \ bitmap data at $00000, 320 wide
   $00 VERA-L0HSCROLL_L C!          \ palette offset 0
   DCSEL0
   VERA-DCVIDEO C@ $10 OR VERA-DCVIDEO C! ;   \ enable layer 0

\ --- bitmap addressing (pixel = y*320 + x, 17-bit VRAM address) --------------
: BXY>BA ( x y -- bank addr )  320 UM* ROT 0 D+ SWAP ;
: BSEEK  ( x y -- )  BXY>BA VADDR ;

\ --- low-level drawing ------------------------------------------------------
: BPSET ( x y color -- )  >R BSEEK R> V! ;
\ BHLINE streams the row through the native VFILL (a tight sta VERA_DATA0 loop
\ with hardware auto-increment) - this is what makes every filled shape fast.
: BHLINE ( x y len color -- )  >R >R BSEEK R> R> SWAP VFILL ;

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

: BCLS ( color -- )                   \ 76800 bytes = 2 x 38400 (VFILL count is 16-bit)
   0 0 VADDR  DUP 38400 VFILL  38400 VFILL ;

\ --- full drawing vocabulary (KERNAL GRAPH names/signatures) -----------------
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

\ Filled ellipse (OVAL): each row's half-width = rx*isqrt(ry^2-dy^2)/ry (native
\ ISQRT), drawn with the fast BHLINE. All integer - no floating point.
VARIABLE ov-cx VARIABLE ov-cy VARIABLE ov-rx VARIABLE ov-ry VARIABLE ov-c
: OVAL ( x1 y1 x2 y2 color -- )
   >R >XYWH R> ov-c !
   1- 2/ ov-ry !  1- 2/ ov-rx !
   ov-ry @ + ov-cy !  ov-rx @ + ov-cx !
   ov-ry @ 1+  ov-ry @ NEGATE  ?DO
      ov-ry @ DUP *  I I *  -  ISQRT                      \ isqrt(ry^2-dy^2)
      ov-rx @ *  ov-ry @ ?DUP IF / ELSE DROP ov-rx @ THEN  ( hw )
      DUP 2* 1+  SWAP  ov-cx @ SWAP -  ov-cy @ I +  ROT  ov-c @ BHLINE
   LOOP ;

\ Ellipse outline (RING): integer, no floating point. Two scans - rows give the
\ left/right edges, columns give the top/bottom edges - each using the same
\ half-extent = ro*isqrt(rr^2-d^2)/rr (native ISQRT) as OVAL. Their union is a
\ connected outline.
VARIABLE ri-cx VARIABLE ri-cy VARIABLE ri-rx VARIABLE ri-ry VARIABLE ri-c
: RING ( x1 y1 x2 y2 color -- )
   >R >XYWH R> ri-c !
   1- 2/ ri-ry !  1- 2/ ri-rx !
   ri-ry @ + ri-cy !  ri-rx @ + ri-cx !
   ri-ry @ 1+  ri-ry @ NEGATE  ?DO                        \ rows: left/right edge
      ri-ry @ DUP *  I I *  -  ISQRT
      ri-rx @ *  ri-ry @ ?DUP IF / ELSE DROP ri-rx @ THEN  ( hw )
      DUP  ri-cx @ SWAP -  ri-cy @ I +  ri-c @ BPSET       ( hw )  \ (cx-hw, cy+dy)
          ri-cx @ +  ri-cy @ I +  ri-c @ BPSET                     \ (cx+hw, cy+dy)
   LOOP
   ri-rx @ 1+  ri-rx @ NEGATE  ?DO                        \ cols: top/bottom edge
      ri-rx @ DUP *  I I *  -  ISQRT
      ri-ry @ *  ri-rx @ ?DUP IF / ELSE DROP ri-ry @ THEN  ( hh )
      DUP  ri-cx @ I +  SWAP  ri-cy @ SWAP -  ri-c @ BPSET  ( hh )  \ (cx+dx, cy-hh)
          ri-cx @ I +  SWAP  ri-cy @ +  ri-c @ BPSET                \ (cx+dx, cy+hh)
   LOOP ;

\ GTEXT: draw a string into the bitmap using the 8x8 ROM charset at VRAM $1F000.
\ ForthX16 boots in ISO mode, so the glyph index is the raw byte (ASCII).
VARIABLE gt-x  VARIABLE gt-y  VARIABLE gt-c  VARIABLE gt-x0
CREATE gt-rows 8 ALLOT
: >SCR ( c -- sc )                          \ ISO charset: glyph index = raw byte
   DUP $20 $7F WITHIN IF          EXIT THEN   \ printable ASCII -> same index
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

\ --- "pen" API: set the colour once, then draw without repeating it ----------
VARIABLE PEN   1 PEN !
: GCOLOR ( n -- )            PEN ! ;
: PLOT  ( x y -- )           PEN @ BPSET ;
: DRAW  ( x1 y1 x2 y2 -- )   PEN @ LINE ;
: BOX   ( x1 y1 x2 y2 -- )   PEN @ FRAME ;
: FBOX  ( x1 y1 x2 y2 -- )   PEN @ RECT ;
: ELL   ( x1 y1 x2 y2 -- )   PEN @ RING ;
: FELL  ( x1 y1 x2 y2 -- )   PEN @ OVAL ;
: CIRC  ( x y r -- )         PEN @ CIRCLE ;
: DISC  ( x y r -- )         PEN @ FCIRCLE ;
: SAY   ( x y c-addr u -- )  2>R PEN @ 2R> GTEXT ;
