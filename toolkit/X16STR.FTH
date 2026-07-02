\ FORTHX16 - BASIC string / number-conversion functions
\ Forth equivalents of the X16 BASIC string functions, using Forth's addr/len
\ string model and pictured numeric output. INCLUDE this file to use them.
\ Note: results of HEX$/BIN$/STR$ share the pictured-output buffer; CHR$/RPT$
\ share PAD - use each result before calling another string-building word.

\ HEX$  u -- c-addr u        unsigned number as hex digits
: HEX$ BASE @ >R HEX 0 <# #S #> R> BASE ! ;

\ BIN$  u -- c-addr u        unsigned number as binary digits
: BIN$ BASE @ >R 2 BASE ! 0 <# #S #> R> BASE ! ;

\ STR$  n -- c-addr u        signed number as a string (current base)
: STR$ DUP ABS 0 <# #S ROT SIGN #> ;

\ VAL   c-addr u -- n        string to number (unsigned, current base)
: VAL 0 0 2SWAP >NUMBER 2DROP DROP ;

\ ASC   c-addr u -- code     code of the first character
: ASC DROP C@ ;

\ CHR$  code -- c-addr 1     one-character string (in PAD)
: CHR$ PAD C! PAD 1 ;

\ LEN   c-addr u -- u        string length
: LEN NIP ;

\ LEFT$  c-addr u n -- c-addr n2       first n characters
: LEFT$ MIN ;

\ RIGHT$ c-addr u n -- c-addr2 n2      last n characters
: RIGHT$ OVER MIN >R R@ - + R> ;

\ MID$   c-addr u start len -- c-addr2 len2   substring, start is 1-based
: MID$ >R 1- /STRING R> MIN ;

\ RPT$   char n -- c-addr u            char repeated n times (in PAD)
: RPT$ >R PAD R@ ROT FILL PAD R> ;
