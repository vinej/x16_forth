\ FORTHX16 - BASIC-style aliases for existing Forth words
\ These simply rename Forth's own File-Access and input words to their BASIC
\ command names. They do NOT touch the BASIC ROM. INCLUDE this file to use them.
\   INCLUDE X16BASIC.FTH   (or FORTH/X16BASIC.FTH depending on the system)

\ OPEN / CLOSE map to the Forth File-Access words:
\   OPEN  ( c-addr u fam -- fileid ior )
\   CLOSE ( fileid -- ior )
: OPEN  OPEN-FILE ;
: CLOSE CLOSE-FILE ;

\ LINPUT reads a line from the keyboard into a buffer (Forth ACCEPT):
\   LINPUT ( c-addr +n -- +n2 )
: LINPUT ACCEPT ;

\ BASIC floating-point function names (require the X16 build's native FP words).
\ Each operates on the top of the float stack: ( F: r -- f(r) )
: SQR FSQRT ;
: SIN FSIN ;
: COS FCOS ;
: TAN FTAN ;
: ATN FATAN ;
: LOG FLN ;
: EXP FEXP ;
