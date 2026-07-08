\ ASMGFX.FTH - Commander X16 bitmap graphics, assembler + VERA FX edition.
\ ---------------------------------------------------------------------------
\ A faster, mode-agnostic companion to GFX.FTH. The hot primitives are inline-
\ assembler CODE words and every horizontal fill runs through VERA FX's 32-bit
\ write cache (4 bytes per VERA-port write, ~4x fewer writes than a byte loop).
\
\ COMPATIBLE WITH ANY 8bpp BITMAP MODE. Nothing is hardwired to 320x240: the
\ pixel address is  base + y*stride + x  with base/width/height/stride held in
\ variables and computed by a general multiply, so the toolkit works for any
\ 8bpp bitmap geometry (position in VRAM, width, height) - e.g. 320x240,
\ 640x200, or a small off-screen buffer. GINIT selects the standard
\ 320x240x256 mode; for any other mode set VERA up yourself and declare the
\ geometry with GMODE. Coordinates are clipped to the active width/height.
\   ( NOTE: packed 1/2/4-bpp modes store several pixels per byte and are not
\     directly pixel-addressable here - this toolkit targets 8bpp bitmaps. )
\
\ REQUIRES  toolkit/ASSEMBLER.FTH first (this file is built from CODE words):
\     S" ASSEMBLER.FTH" INCLUDED
\     S" ASMGFX.FTH"    INCLUDED
\ X16 only. Don't load GFX.FTH and ASMGFX.FTH both (same word names).
\
\   GINIT                          enter the standard 320x240x256 mode + GMODE
\   bank addr w h GMODE            declare the active 8bpp bitmap geometry
\   GCLS                           clear the bitmap (VERA FX fast fill)
\   x y color PSET                 plot one pixel (clipped)
\   x1 y1 x2 y2 color LINE         line between two points
\   x1 y1 x2 y2 color FRAME/RECT   rectangle outline / filled
\   x1 y1 x2 y2 color RING/OVAL    ellipse outline / filled
\   x y color c-addr u GTEXT       draw a string into the bitmap
\   x y r color CIRCLE / FCIRCLE   circle outline / filled
\ Pen API:  n GCOLOR then PLOT DRAW BOX FBOX ELL FELL CIRC DISC SAY
\ Low-level (CODE): BSEEK BPSET VFILLR.  Forth: BHLINE BVLINE BLINE BFILL BRECT.
\ Geometry vars:    GBASE (3 bytes) GSTRIDE GWIDTH GHEIGHT.
\ ---------------------------------------------------------------------------

DECIMAL

\ --- VERA registers ---------------------------------------------------------
$9F20 CONSTANT VERA-ADDRL
$9F21 CONSTANT VERA-ADDRM
$9F22 CONSTANT VERA-ADDRH          \ bits7-4 increment, bit0 = VRAM A16
$9F23 CONSTANT VERA-DATA0
$9F25 CONSTANT VERA-CTRL           \ bit0 ADDRSEL, bits1-6 DCSEL
$9F29 CONSTANT VERA-DCVIDEO        \ DCSEL=0: bit4 layer0 enable
$9F2D CONSTANT VERA-L0CONFIG
$9F2F CONSTANT VERA-L0TILEBASE
$9F30 CONSTANT VERA-L0HSCROLL_L
: DCSEL0 ( -- )  VERA-CTRL C@ $FD AND VERA-CTRL C! ;

\ --- active bitmap geometry (8bpp) ------------------------------------------
VARIABLE GSTRIDE                   \ bytes per row (= width for 8bpp)
VARIABLE GWIDTH                    \ clip width  (pixels)
VARIABLE GHEIGHT                   \ clip height (pixels)
CREATE   GBASE 3 ALLOT             \ 17-bit VRAM base: lo, mid, hi(bit0=bank)
CREATE   gpad 14 ALLOT             \ CODE scratch (see (SEEK) below)

gpad    CONSTANT 'P
GSTRIDE CONSTANT 'STRIDE
GBASE   CONSTANT 'BASE
GWIDTH  CONSTANT 'WIDTH
GHEIGHT CONSTANT 'HEIGHT

: GMODE ( bank addr width height -- )   \ declare the active 8bpp geometry
   GHEIGHT !
   DUP GWIDTH ! GSTRIDE !               \ 8bpp: stride = width bytes
   DUP $FF AND GBASE C!                 \ base addr lo
   8 RSHIFT $FF AND GBASE 1+ C!         \ base addr hi
   1 AND GBASE 2 + C! ;                 \ base bank bit (VRAM A16)

: GINIT ( -- )                          \ standard 320x240x256 bitmap mode
   128 SCREEN
   $07 VERA-L0CONFIG C!                 \ layer 0 = bitmap, 8bpp
   $00 VERA-L0TILEBASE C!               \ bitmap data at $00000
   $00 VERA-L0HSCROLL_L C!
   DCSEL0
   VERA-DCVIDEO C@ $10 OR VERA-DCVIDEO C!
   0 0 320 240 GMODE ;                  \ bank 0, addr $0000, 320x240

\ --- raw helper: point VERA ADDR0 at pixel (x,y) ----------------------------
\ Inputs in scratch: 'P+7/8 = x (16-bit), 'P+10 = y (low byte). Computes
\ addr = GBASE + y*GSTRIDE + x by an 8x16 shift-add multiply and programs
\ ADDR0 (increment +1, ADDRSEL 0). Scratch map: 'P+0..2 addr/product,
\ 'P+3..5 stride copy, 'P+6 y bit-work.
ALSO ASSEMBLER
HERE
  'STRIDE LDA, 'P 3 + STA,  'STRIDE 1+ LDA, 'P 4 + STA,  0 # LDA, 'P 5 + STA,
  'P 10 + LDA, 'P 6 + STA,                 \ y bit-work
  0 # LDA, 'P STA, 'P 1+ STA, 'P 2 + STA,  \ product = 0
  8 # LDX,
  BEGIN,
    'P 6 + LSR,                            \ next bit of y -> carry
    BCS: IF,                               \ if set: product += stride
       CLC,
       'P LDA,    'P 3 + ADC, 'P STA,
       'P 1+ LDA, 'P 4 + ADC, 'P 1+ STA,
       'P 2 + LDA, 'P 5 + ADC, 'P 2 + STA,
    THEN,
    'P 3 + ASL, 'P 4 + ROL, 'P 5 + ROL,    \ stride <<= 1
    DEX,
  BEQ: UNTIL,
  CLC,                                     \ product += x
  'P LDA,    'P 7 + ADC, 'P STA,
  'P 1+ LDA, 'P 8 + ADC, 'P 1+ STA,
  'P 2 + LDA, 0 # ADC, 'P 2 + STA,
  CLC,                                     \ product += GBASE
  'P LDA,    'BASE ADC,    'P STA,
  'P 1+ LDA, 'BASE 1+ ADC, 'P 1+ STA,
  'P 2 + LDA, 'BASE 2 + ADC, 'P 2 + STA,
  VERA-CTRL LDA, $FE # AND, VERA-CTRL STA, \ ADDRSEL = 0
  'P LDA, VERA-ADDRL STA,
  'P 1+ LDA, VERA-ADDRM STA,
  'P 2 + LDA, $01 # AND, $10 # ORA, VERA-ADDRH STA,   \ increment +1 | bank
  RTS,
CONSTANT (SEEK)
PREVIOUS

\ --- CODE primitives --------------------------------------------------------
CODE BSEEK ( x y -- )   \ point VERA ADDR0 at bitmap pixel (x,y) (no clip)
  POP JSR, 'P 10 + STA,                    \ y -> scratch
  POP JSR, 'P 7 + STA, TXA, 'P 8 + STA,    \ x -> scratch
  (SEEK) JSR,
  NEXT JMP,
END-CODE

CODE BPSET ( x y color -- )   \ plot one pixel, clipped to GWIDTH x GHEIGHT
  POP JSR, 'P 9 + STA,                          \ color
  POP JSR, 'P 10 + STA, TXA, 'P 11 + STA,       \ y (16-bit)
  POP JSR, 'P 7 + STA, TXA, 'P 8 + STA,         \ x (16-bit)
  SEC, 'P 7 + LDA, 'WIDTH SBC, 'P 8 + LDA, 'WIDTH 1+ SBC,   \ x - width
  BCS: IF, NEXT JMP, THEN,                       \ x >= width (or <0) -> off
  SEC, 'P 10 + LDA, 'HEIGHT SBC, 'P 11 + LDA, 'HEIGHT 1+ SBC,  \ y - height
  BCS: IF, NEXT JMP, THEN,                       \ y >= height (or <0) -> off
  (SEEK) JSR,
  'P 9 + LDA, VERA-DATA0 STA,                    \ write the pixel
  NEXT JMP,
END-CODE

\ VFILLR ( color count -- )  fill `count` bytes from the CURRENT VERA address
\ with the VERA FX 32-bit cache: unaligned head + <4 tail bytes written singly,
\ the 4-byte-aligned middle blasted 4 bytes per write. Stride-independent (a
\ row is contiguous bytes in any width). count is 16-bit. Leaves VERA normal.
\ 'P+0/1 count, 'P+2 color, 'P+3 head, 'P+4 tail.
CODE VFILLR ( color count -- )
  POP JSR, 'P STA, 'P 1+ STX,             \ count
  POP JSR, 'P 2 + STA,                    \ color
  VERA-ADDRL LDA, $03 # AND, 'P 3 + STA,          \ a = addr & 3
  SEC, $04 # LDA, 'P 3 + SBC, $03 # AND, 'P 3 + STA,   \ head = (4-a)&3
  'P 1+ LDA,
  BEQ: IF,                                \ count < 256 -> clamp head to count
     'P LDA, 'P 3 + CMP,
     BCC: IF, 'P LDA, 'P 3 + STA, THEN,
  THEN,
  SEC, 'P LDA, 'P 3 + SBC, 'P STA,        \ count -= head
  'P 1+ LDA, 0 # SBC, 'P 1+ STA,
  $04 # LDA, VERA-CTRL STA, 0 # LDA, $9F29 STA,   \ DCSEL2, FX_CTRL off
  0 # LDA, VERA-CTRL STA,                         \ DCSEL0
  VERA-ADDRH LDA, $01 # AND, $10 # ORA, VERA-ADDRH STA,   \ increment +1
  'P 3 + LDX,
  BNE: IF,
     'P 2 + LDA,
     BEGIN, VERA-DATA0 STA, DEX, BEQ: UNTIL,      \ head bytes
  THEN,
  'P LDA, $03 # AND, 'P 4 + STA,          \ tail = count & 3
  'P 1+ LSR, 'P ROR, 'P 1+ LSR, 'P ROR,   \ count >>= 2  (4-byte groups)
  'P LDA, 'P 1+ ORA,
  BNE: IF,
     $04 # LDA, VERA-CTRL STA,            \ DCSEL2
     0 # LDA, $9F2C STA,                  \ FX_MULT off
     $40 # LDA, $9F29 STA,                \ FX_CTRL: Cache Write Enable
     $0C # LDA, VERA-CTRL STA,            \ DCSEL6
     'P 2 + LDA, $9F29 STA, $9F2A STA, $9F2B STA, $9F2C STA,   \ cache = 4x color
     VERA-ADDRH LDA, $01 # AND, $30 # ORA, VERA-ADDRH STA,     \ increment +4
     BEGIN,
        0 # LDA, VERA-DATA0 STA,          \ flush cache -> 4 bytes
        'P LDA, BEQ: IF, 'P 1+ DEC, THEN, 'P DEC,   \ 16-bit decrement
        'P LDA, 'P 1+ ORA,
     BEQ: UNTIL,
     $04 # LDA, VERA-CTRL STA, 0 # LDA, $9F29 STA,  \ FX off
  THEN,
  VERA-ADDRH LDA, $01 # AND, $10 # ORA, VERA-ADDRH STA,   \ increment +1
  'P 4 + LDX,
  BNE: IF,
     'P 2 + LDA,
     BEGIN, VERA-DATA0 STA, DEX, BEQ: UNTIL,      \ tail bytes
  THEN,
  0 # LDA, VERA-CTRL STA,                 \ leave DCSEL 0
  NEXT JMP,
END-CODE

\ --- horizontal fill (clipped) / clear over the CODE primitives -------------
VARIABLE hl-x  VARIABLE hl-y  VARIABLE hl-len  VARIABLE hl-c
: BHLINE ( x y len color -- )
   hl-c ! hl-len ! hl-y ! hl-x !
   hl-y @ 0 GHEIGHT @ WITHIN 0= IF EXIT THEN         \ row off-screen
   hl-x @ 0< IF hl-x @ hl-len +!  0 hl-x ! THEN      \ clip left
   hl-x @ hl-len @ + GWIDTH @ > IF                   \ clip right
      GWIDTH @ hl-x @ - hl-len ! THEN
   hl-len @ 0 > IF
      hl-x @ hl-y @ BSEEK  hl-c @ hl-len @ VFILLR
   THEN ;

VARIABLE bv-x  VARIABLE bv-c
: BVLINE ( x y len color -- )                        \ vertical run (per pixel)
   bv-c ! >R SWAP bv-x ! R> OVER + SWAP
   ?DO  bv-x @ I bv-c @ BPSET  LOOP ;

VARIABLE cl-c
: BCLS ( color -- )                                  \ clear the whole bitmap
   cl-c !  GHEIGHT @ 0 ?DO  0 I GWIDTH @ cl-c @ BHLINE  LOOP ;

VARIABLE bf-x   VARIABLE bf-w   VARIABLE bf-c
: BFILL ( x y w h color -- )                         \ filled rectangle
   bf-c ! >R bf-w ! SWAP bf-x ! R> OVER + SWAP
   ?DO  bf-x @ I bf-w @ bf-c @ BHLINE  LOOP ;

\ Bresenham line (Forth, over the clipped CODE BPSET).
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
: BRECT ( x y w h color -- )                         \ rectangle outline
   br-c ! br-h ! br-w ! br-y ! br-x !
   br-x @ br-y @ br-w @ br-c @ BHLINE
   br-x @  br-y @ br-h @ 1- +  br-w @ br-c @ BHLINE
   br-x @ br-y @ br-h @ br-c @ BVLINE
   br-x @ br-w @ 1- +  br-y @ br-h @ br-c @ BVLINE ;

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
: FRAME ( x1 y1 x2 y2 color -- )  >R >XYWH R> BRECT ;
: RECT  ( x1 y1 x2 y2 color -- )  >R >XYWH R> BFILL ;

\ Filled ellipse (OVAL): each row's half-width = rx*isqrt(ry^2-dy^2)/ry (native
\ ISQRT), drawn with the fast FX BHLINE. All integer - no floating point.
VARIABLE ov-cx VARIABLE ov-cy VARIABLE ov-rx VARIABLE ov-ry VARIABLE ov-c
: OVAL ( x1 y1 x2 y2 color -- )
   >R >XYWH R> ov-c !
   1- 2/ ov-ry !  1- 2/ ov-rx !
   ov-ry @ + ov-cy !  ov-rx @ + ov-cx !
   ov-ry @ 1+  ov-ry @ NEGATE  ?DO
      ov-ry @ DUP *  I I *  -  ISQRT
      ov-rx @ *  ov-ry @ ?DUP IF / ELSE DROP ov-rx @ THEN  ( hw )
      DUP 2* 1+  SWAP  ov-cx @ SWAP -  ov-cy @ I +  ROT  ov-c @ BHLINE
   LOOP ;

\ Ellipse outline (RING): integer, no floating point (same half-extent as OVAL).
VARIABLE ri-cx VARIABLE ri-cy VARIABLE ri-rx VARIABLE ri-ry VARIABLE ri-c
: RING ( x1 y1 x2 y2 color -- )
   >R >XYWH R> ri-c !
   1- 2/ ri-ry !  1- 2/ ri-rx !
   ri-ry @ + ri-cy !  ri-rx @ + ri-cx !
   ri-ry @ 1+  ri-ry @ NEGATE  ?DO                        \ rows: left/right edge
      ri-ry @ DUP *  I I *  -  ISQRT
      ri-rx @ *  ri-ry @ ?DUP IF / ELSE DROP ri-rx @ THEN  ( hw )
      DUP  ri-cx @ SWAP -  ri-cy @ I +  ri-c @ BPSET       ( hw )
          ri-cx @ +  ri-cy @ I +  ri-c @ BPSET
   LOOP
   ri-rx @ 1+  ri-rx @ NEGATE  ?DO                        \ cols: top/bottom edge
      ri-rx @ DUP *  I I *  -  ISQRT
      ri-ry @ *  ri-rx @ ?DUP IF / ELSE DROP ri-ry @ THEN  ( hh )
      DUP  ri-cx @ I +  SWAP  ri-cy @ SWAP -  ri-c @ BPSET  ( hh )
          ri-cx @ I +  SWAP  ri-cy @ +  ri-c @ BPSET
   LOOP ;

\ GTEXT: draw a string into the bitmap using the 8x8 ROM charset at VRAM $1F000.
VARIABLE gt-x  VARIABLE gt-y  VARIABLE gt-c  VARIABLE gt-x0
CREATE gt-rows 8 ALLOT
: >SCR ( c -- sc )                          \ ISO charset: glyph index = raw byte
   DUP $20 $7F WITHIN IF          EXIT THEN
   DROP $20 ;
: GLYPH ( sc -- )  8 * $F000 +  1 SWAP VADDR ;   \ point core VERA at glyph
: GTEXT ( x y color c-addr u -- )
   >R >R  gt-c ! gt-y ! gt-x !  R> R>
   0 ?DO
      DUP I + C@ >SCR GLYPH
      8 0 DO  V@ gt-rows I + C!  LOOP
      gt-x @ I 8 * + gt-x0 !
      8 0 DO
         gt-rows I + C@
         8 0 DO
            DUP $80 I RSHIFT AND IF
               gt-x0 @ I +  gt-y @ J +  gt-c @ BPSET
            THEN
         LOOP
         DROP
      LOOP
   LOOP DROP ;

\ Circles by centre + radius, built on the ellipse words.
VARIABLE ci-x  VARIABLE ci-y  VARIABLE ci-r
: CIRCLE  ( x y r color -- )
   >R ci-r ! ci-y ! ci-x !
   ci-x @ ci-r @ -  ci-y @ ci-r @ -  ci-x @ ci-r @ +  ci-y @ ci-r @ +  R> RING ;
: FCIRCLE ( x y r color -- )
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

\ default geometry so the words are usable even before GINIT (320x240 @ $0000)
0 0 320 240 GMODE

CR .( ASMGFX loaded: GINIT GMODE GCLS PSET LINE FRAME RECT RING OVAL GTEXT + pen ) CR
