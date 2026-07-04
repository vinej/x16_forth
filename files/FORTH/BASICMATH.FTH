\ BASICMATH.FTH - BASIC-style floating-point function names for ForthX16.
\ ===========================================================================
\ These are convenience aliases for the built-in F* words. They were once baked
\ into the ROM but were moved here to save space (they only duplicated the
\ FSQRT/FSIN/FCOS/FTAN/FATAN/FLN/FEXP words). Load with:
\     INCLUDE BASICMATH.FTH
\ Each takes and returns a float on the floating-point stack ( F: r -- f(r) ):
\     2 S>F SQR F.        \ 1.41421356
\     30 S>F PI F* 180 S>F F/ SIN F.   \ sin(30 degrees)

: SQR   FSQRT  ;     \ square root
: SIN   FSIN   ;     \ sine (radians)
: COS   FCOS   ;     \ cosine (radians)
: TAN   FTAN   ;     \ tangent (radians)
: ATN   FATAN  ;     \ arctangent
: LOG   FLN    ;     \ natural logarithm (BASIC LOG = natural log)
: EXP   FEXP   ;     \ e^r
