\ VERAFX.FTH - Commander X16 "VERA FX" toolkit for ForthX16 / TX16
\ ---------------------------------------------------------------------------
\ VERA FX (the r47+ VERA firmware update) adds hardware "helpers" that offload
\ the 65(C02/816) CPU: a signed 16x16->32 multiplier, a 32-bit write cache
\ (fast 4-byte-at-a-time VRAM fills/blits), transparent writes, and line /
\ polygon / affine address helpers. This toolkit wraps the two most useful,
\ turnkey features as inline-assembler CODE words, plus the low-level DCSEL
\ plumbing so you can reach the other FX modes yourself.
\
\ REQUIRES  toolkit/ASSEMBLER.FTH first (this file is built from CODE words):
\     S" ASSEMBLER.FTH" INCLUDED
\     S" VERAFX.FTH"     INCLUDED
\ X16 only. Works in every X16 build (PRG / bank9 / bank32 / cart / 816).
\
\ Words:
\   n1 n2 FX*            ( n1 n2 -- d )   signed 16x16 -> 32-bit product (a double)
\   byte vbank vaddr count FX-FILL       fast-fill count VRAM bytes with byte
\   vbank vaddr count FX-CLEAR           = 0 ... FX-FILL  (zero a VRAM region)
\   n FX-DCSEL           ( n -- )        select DCSEL bank 0-63 (bits 1-6 of CTRL)
\   FX-OFF               ( -- )          disable FX, reset DCSEL/ADDRSEL to 0
\
\ Notes
\ * FX* mirrors the built-in native FX-MULT; it is provided here as a self-
\   contained CODE-word example and to keep the toolkit standalone. Both use a
\   scratch VRAM cell at $1:F800 and restore VERA's CTRL + ADDR0 registers.
\ * FX-FILL uses the 32-bit cache: each DATA0 write flushes 4 bytes, so a fill
\   needs ~1/4 the port writes of a byte loop. vaddr should be 4-byte aligned
\   (low 2 bits 0); any count is fine (the 0..3 leftover bytes are written
\   singly). It preserves VERA's CTRL + ADDR0.
\ * The FX registers $9F29-$9F2C change meaning with DCSEL (set via CTRL). Once
\   FX-DCSEL selects a bank you can C!/C@ them directly, e.g. to set up the line
\   or polygon helper - see the VERA FX Reference. Call FX-OFF when done.
\ ---------------------------------------------------------------------------

DECIMAL

\ --- VERA fixed registers (independent of DCSEL) ----------------------------
$9F20 CONSTANT VERA-ADDRL          \ ADDRx_L
$9F21 CONSTANT VERA-ADDRM          \ ADDRx_M
$9F22 CONSTANT VERA-ADDRH          \ ADDRx_H (bits7-4 increment, bit0 = VRAM A16)
$9F23 CONSTANT VERA-DATA0          \ DATA0 port
$9F25 CONSTANT VERA-CTRL           \ bit0 ADDRSEL, bits1-6 DCSEL, bit7 reset
\ FX registers live at $9F29-$9F2C; their meaning depends on DCSEL:
\   DCSEL=2 : $9F29 FX_CTRL   $9F2C FX_MULT
\   DCSEL=6 : $9F29..$9F2C FX_CACHE_L/M/H/U (= multiplicand/multiplier)

\ ===========================================================================
\ FX-DCSEL ( n -- )   put n into CTRL's DCSEL field (bits 1-6), preserving the
\ reset bit (7) and ADDRSEL (0). After this, $9F29-$9F2C carry the FX meaning
\ for bank n and can be reached with ordinary C! / C@.
CODE FX-DCSEL
   DTOP LDA,  .A ASL,  $7E # AND,  N STA,      \ (n<<1) & %01111110
   VERA-CTRL LDA,  $81 # AND,  N ORA,  VERA-CTRL STA,
   POP JSR,                                    \ drop n
   NEXT JMP,
END-CODE

\ ===========================================================================
\ FX* ( n1 n2 -- d )   signed 16x16 -> 32-bit multiply via VERA's hardware
\ multiplier. Leaves the product as a double ( low-cell high-cell ). Uses a
\ scratch VRAM cell at $1:F800 and saves/restores VERA CTRL + ADDR0.
CODE FX*
   VERA-CTRL  LDA,  PHA,                       \ save VERA state
   VERA-ADDRL LDA,  PHA,
   VERA-ADDRM LDA,  PHA,
   VERA-ADDRH LDA,  PHA,
   POP JSR,  N STA,  N 1+ STX,                 \ n2 -> N/N+1 ; DTOP is now n1
   $0C # LDA,  VERA-CTRL STA,                  \ DCSEL = 6 (load 32-bit cache)
   DTOP    LDA,  $9F29 STA,                    \ multiplicand lo = n1 lo
   DTOP 1+ LDA,  $9F2A STA,                    \ multiplicand hi
   N       LDA,  $9F2B STA,                    \ multiplier  lo = n2 lo
   N 1+    LDA,  $9F2C STA,                    \ multiplier  hi
   $04 # LDA,  VERA-CTRL STA,                  \ DCSEL = 2
   $10 # LDA,  $9F2C STA,                      \ FX_MULT: Multiplier Enable
   $40 # LDA,  $9F29 STA,                      \ FX_CTRL: Cache Write Enable
   $00 # LDA,  VERA-ADDRL STA,                 \ ADDR0 = $1:F800, no increment
   $F8 # LDA,  VERA-ADDRM STA,
   $01 # LDA,  VERA-ADDRH STA,
   $00 # LDA,  VERA-DATA0 STA,                 \ trigger multiply + 32-bit write
   $11 # LDA,  VERA-ADDRH STA,                 \ increment 1 to read result back
   VERA-DATA0 LDA,  N 2 + STA,                 \ result byte 0
   VERA-DATA0 LDA,  N 3 + STA,                 \ byte 1
   VERA-DATA0 LDA,  N 4 + STA,                 \ byte 2
   VERA-DATA0 LDA,  N 5 + STA,                 \ byte 3
   $04 # LDA,  VERA-CTRL STA,                  \ DCSEL = 2, disable FX
   $00 # LDA,  $9F29 STA,                      \ FX_CTRL off
   $00 # LDA,  $9F2C STA,                      \ FX_MULT off
   PLA,  VERA-ADDRH STA,                       \ restore VERA state
   PLA,  VERA-ADDRM STA,
   PLA,  VERA-ADDRL STA,
   PLA,  VERA-CTRL STA,
   N 2 + LDA,  DTOP STA,                       \ low cell -> DTOP (overwrites n1)
   N 3 + LDA,  DTOP 1+ STA,
   N 4 + LDA,                                  \ A = high cell lo
   N 5 + LDX,                                  \ X = high cell hi
   PUSH JSR,                                   \ push high cell on top
   NEXT JMP,
END-CODE

\ ===========================================================================
\ FX-FILL ( byte vbank vaddr count -- )   fill count VRAM bytes at vbank:vaddr
\ with byte, using the 32-bit cache (4 bytes per DATA0 write). vaddr should be
\ 4-byte aligned. Saves/restores VERA CTRL + ADDR0.
\ N-area use: N/N+1 group count (count>>2), N+2/N+3 vaddr, N+4 vbank,
\             N+5 byte, N+6 leftover count (count and 3).
CODE FX-FILL
   VERA-CTRL  LDA,  PHA,                       \ save VERA state
   VERA-ADDRL LDA,  PHA,
   VERA-ADDRM LDA,  PHA,
   VERA-ADDRH LDA,  PHA,
   POP JSR,  N STA,      N 1+ STX,             \ count -> N/N+1
   POP JSR,  N 2 + STA,  N 3 + STX,            \ vaddr -> N+2/N+3
   POP JSR,  N 4 + STA,                        \ vbank -> N+4
   POP JSR,  N 5 + STA,                        \ byte  -> N+5
   N LDA,  $03 # AND,  N 6 + STA,              \ leftover = count and 3 -> N+6
   N 1+ LSR,  N ROR,                           \ count >>= 1
   N 1+ LSR,  N ROR,                           \ count >>= 1   (now group count)
   $04 # LDA,  VERA-CTRL STA,                  \ DCSEL = 2
   $00 # LDA,  $9F2C STA,                      \ FX_MULT off (no multiply)
   $40 # LDA,  $9F29 STA,                      \ FX_CTRL: Cache Write Enable
   $0C # LDA,  VERA-CTRL STA,                  \ DCSEL = 6 (load cache)
   N 5 + LDA,                                  \ fill byte -> all 4 cache bytes
   $9F29 STA,  $9F2A STA,  $9F2B STA,  $9F2C STA,
   N 2 + LDA,  VERA-ADDRL STA,                 \ ADDR0 = vaddr
   N 3 + LDA,  VERA-ADDRM STA,
   N 4 + LDA,  $01 # AND,  $30 # ORA,          \ ADDR_H = increment +4 | bank
   VERA-ADDRH STA,
   N LDA,  N 1+ ORA,                           \ any full 4-byte groups?
   BNE: IF,
      BEGIN,
         $00 # LDA,  VERA-DATA0 STA,           \ flush cache -> write 4 bytes
         N LDA,  BEQ: IF,  N 1+ DEC,  THEN,    \ 16-bit decrement of group count
         N DEC,
         N LDA,  N 1+ ORA,
      BEQ: UNTIL,                              \ until group count = 0
   THEN,
   $04 # LDA,  VERA-CTRL STA,                  \ DCSEL = 2
   $00 # LDA,  $9F29 STA,                      \ FX_CTRL off (plain writes now)
   N 4 + LDA,  $01 # AND,  $10 # ORA,          \ ADDR_H = increment +1 | bank
   VERA-ADDRH STA,
   N 6 + LDX,                                  \ leftover bytes (0..3)
   BNE: IF,
      BEGIN,
         N 5 + LDA,  VERA-DATA0 STA,
         DEX,
      BEQ: UNTIL,
   THEN,
   PLA,  VERA-ADDRH STA,                       \ restore VERA state
   PLA,  VERA-ADDRM STA,
   PLA,  VERA-ADDRL STA,
   PLA,  VERA-CTRL STA,
   NEXT JMP,
END-CODE

\ ===========================================================================
\ FX-CLEAR ( vbank vaddr count -- )   zero a VRAM region (fast).
: FX-CLEAR  ( vbank vaddr count -- )   2>R  0 SWAP  2R>  FX-FILL ;

\ FX-OFF ( -- )   return VERA to non-FX state: FX_CTRL and FX_MULT cleared,
\ DCSEL and ADDRSEL back to 0. Call after using the low-level FX registers.
: FX-OFF  ( -- )
   $04 VERA-CTRL C!   0 $9F29 C!   0 $9F2C C!   0 VERA-CTRL C! ;

CR .( VERAFX loaded: FX* FX-FILL FX-CLEAR FX-DCSEL FX-OFF ) CR
