\ ASMSPLIT.FTH - "Method A" split screen, on top of the ASMGFX toolkit.
\ ---------------------------------------------------------------------------
\ Same idea as SPLIT.FTH: VERA composites two layers, so a 320x240 256-colour
\ bitmap (LAYER 0) and the KERNAL text console (LAYER 1, confined to a few
\ bottom rows) share the screen with no raster interrupt. The difference is
\ that ASMSPLIT does NOT carry its own graphics words - it uses the
\ toolkit/ASMGFX.FTH vocabulary, whose primitives are inline-assembler CODE
\ words and whose fills use the VERA FX 32-bit write cache. So the same
\ GCLS/PSET/LINE/RECT/OVAL/RING/GTEXT + pen API work here, only faster, and
\ (unlike SPLIT.FTH's RING) with NO floating point required.
\
\ LOAD ORDER:   ASSEMBLER.FTH  ->  ASMGFX.FTH  ->  ASMSPLIT.FTH
\     S" ASSEMBLER.FTH" INCLUDED
\     S" ASMGFX.FTH"    INCLUDED
\     S" ASMSPLIT.FTH"  INCLUDED
\ Then:
\     SPLIT-DEMO          \ see it in action
\     SPLITON / SPLITOFF  \ enter / leave the split
\
\ The graphics target the 320x240 8bpp bitmap at VRAM $00000 - exactly the
\ geometry ASMGFX defaults to - so ASMGFX's GINIT (full screen) and this
\ library's SPLITON both drive the same bitmap with the same words. Change the
\ text-window height before SPLITON with e.g.  8 TO SPLIT-ROWS .
\ ---------------------------------------------------------------------------

DECIMAL

\ Height of the bottom text window, in text rows (screen is 40x30 while split).
6 VALUE SPLIT-ROWS

\ --- extra VERA / editor registers (ASMGFX already defines VERA-CTRL,
\ VERA-DCVIDEO, VERA-L0CONFIG, VERA-L0TILEBASE, VERA-L0HSCROLL_L, DCSEL0) ------
$9F39 CONSTANT VERA-L1VSCROLL_L
$9F3A CONSTANT VERA-L1VSCROLL_H
$0387 CONSTANT ED-NLINES           \ editor: number of console rows
$0388 CONSTANT ED-NLINESP1         \   nlines + 1
$0389 CONSTANT ED-NLINESM1         \   nlines - 1

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
   $9F35 C@ 512 UM* SWAP VADDR        \ point VERA at L1 map base (bank addr)
   8192 0 DO  32 V!  0 V!  LOOP ;      \ 8192 cells: space + colour 0

\ --- turning the split on / off ---------------------------------------------
: SPLITON ( -- )
   3 SCREEN                          \ 40x30 text -> 320x240 scale (matches bitmap)
   0 0 320 240 GMODE                 \ ASMGFX draws to the $0000 320x240 bitmap
   $07 VERA-L0CONFIG C!              \ layer 0 = bitmap, 8bpp
   $00 VERA-L0TILEBASE C!            \ bitmap data at $00000, 320 wide
   $00 VERA-L0HSCROLL_L C!           \ palette offset 0
   DCSEL0
   VERA-DCVIDEO C@ $10 OR VERA-DCVIDEO C!   \ enable layer 0 (keep layer 1)
   1 0 COLOR                         \ white text on transparent (index 0)
   CLRTEXT                           \ wipe the whole text map (not just nlines)
   SPLIT-ROWS TEXT-WINDOW            \ console = bottom N rows only
   272 SPLIT-ROWS 8 * + L1VSCROLL    \ scroll those rows to the bottom
   0 0 LOCATE ;                      \ cursor to top-left of the window

: SPLITOFF ( -- )
   FULL-WINDOW
   DCSEL0
   VERA-DCVIDEO C@ $EF AND VERA-DCVIDEO C!   \ disable layer 0
   0 SCREEN ;                        \ back to 80x60 text

\ --- demo -------------------------------------------------------------------
: SPLIT-DEMO ( -- )
   SPLITON  GCLS
   10 10 309 150 3 FRAME             \ green rectangle outline
   20 20 150 90 2 RECT               \ red filled box   (VERA FX fill)
   170 15 309 145 6 OVAL             \ blue filled ellipse (VERA FX fill)
   170 15 309 145 1 RING             \ white ellipse outline around it
   10 160 309 10 7 LINE              \ a yellow line
   30 40 4 S" HELLO" GTEXT           \ text drawn INTO the bitmap
   0 192 320 48 6 BFILL              \ blue panel behind the text window
   1 0 COLOR
   0 0 LOCATE ." ForthX16 split screen - ASMGFX + VERA FX"
   2 0 LOCATE ." same PSET LINE RECT RING OVAL GTEXT"
   4 0 LOCATE ." type here - scrolls only in this window" ;

CR .( ASMSPLIT loaded: SPLITON SPLITOFF SPLIT-DEMO  -- graphics via ASMGFX ) CR
