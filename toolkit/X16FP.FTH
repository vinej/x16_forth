\ FORTHX16 - Forth-2012 floating-point defining words
\ Built on the X16 build's native float words (F@ F! etc.). INCLUDE this file.
\   INCLUDE X16FP.FTH

\ FVARIABLE name   -- creates a word that returns the address of 5 float bytes
: FVARIABLE CREATE 5 ALLOT ;

\ FCONSTANT name   ( F: r -- )   creates a word that pushes the float r
: FCONSTANT CREATE HERE F! 5 ALLOT DOES> F@ ;
