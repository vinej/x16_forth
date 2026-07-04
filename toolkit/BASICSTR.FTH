\ BASICSTR.FTH - BASIC-style string / number-conversion words for ForthX16.
\ ===========================================================================
\ Moved out of the ROM core (to make room for CD/DIR etc.); all are plain Forth
\ built on the core's pictured-numeric-output, >NUMBER, /STRING, FILL, MIN.
\ Load with:  INCLUDE BASICSTR.FTH
\   255 HEX$ TYPE            -> FF
\   255 BIN$ TYPE            -> 11111111
\   -12 STR$ TYPE            -> -12
\   S" 100" VAL .            -> 100
\   S" HELLO" ASC .          -> 72   (code of 'H')
\   65 CHR$ TYPE             -> A
\   S" HELLO" LEN .          -> 5
\   S" HELLO" 3 LEFT$ TYPE   -> HEL
\   S" HELLO" 3 RIGHT$ TYPE  -> LLO
\   S" HELLO" 2 3 MID$ TYPE  -> ELL   (start is 1-based)
\   42 5 RPT$ TYPE           -> *****

: HEX$   ( u -- c-addr u )   BASE @ >R HEX  0 <# #S #>  R> BASE ! ;
: BIN$   ( u -- c-addr u )   BASE @ >R 2 BASE !  0 <# #S #>  R> BASE ! ;
: STR$   ( n -- c-addr u )   DUP ABS 0 <# #S ROT SIGN #> ;
: VAL    ( c-addr u -- n )   0 0 2SWAP >NUMBER 2DROP DROP ;
: ASC    ( c-addr u -- code ) DROP C@ ;
: CHR$   ( code -- c-addr 1 ) PAD C! PAD 1 ;
: LEN    ( c-addr u -- u )    NIP ;
: LEFT$  ( c-addr u n -- c-addr n2 )   MIN ;
: RIGHT$ ( c-addr u n -- c-addr2 n2 )  OVER MIN >R R@ - + R> ;
: MID$   ( c-addr u start len -- c-addr2 len2 )  >R 1- /STRING R> MIN ;
: RPT$   ( char n -- c-addr u )  >R PAD R@ ROT FILL PAD R> ;
