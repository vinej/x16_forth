\ FPX.FTH - extra floating-point words for ForthX16 (Forth 2012 FLOATING /
\ FLOATING-EXT). They all compose the built-in FP primitives, so they live in
\ this toolkit rather than the ROM core.  INCLUDE FPX.FTH
\ Floats are the 5-byte packed BASIC format; ~9 significant digits.

\ --- constants -------------------------------------------------------------
1 S>F FATAN 4 S>F F*  FCONSTANT FPI      \ pi   = 4*atan(1)
1 S>F FATAN 2 S>F F*  FCONSTANT FPI2     \ pi/2 = 2*atan(1)
10 S>F FLN            FCONSTANT FLN10    \ ln(10), for base-10 log/antilog

\ --- float memory / sizing (packed floats are 5 bytes; no alignment here) ---
: FLOAT+   ( f-addr -- f-addr' )  5 + ;
: FLOATS   ( n -- n*5 )           5 * ;
: FALIGN   ( -- ) ;                       \ no-op: floats are byte-addressed
: FALIGNED ( addr -- addr ) ;             \ no-op

\ --- float-stack shuffles --------------------------------------------------
FVARIABLE FRTMP
: FROT ( r1 r2 r3 -- r2 r3 r1 )  FRTMP F! FSWAP FRTMP F@ FSWAP ;
: FSINCOS ( r -- sin cos )       FDUP FSIN FSWAP FCOS ;

\ --- log / exponential family ----------------------------------------------
: FLOG   ( r -- log10 )   FLN FLN10 F/ ;
: FALOG  ( r -- 10^r )    FLN10 F* FEXP ;
: FLNP1  ( r -- ln 1+r )  1 S>F F+ FLN ;
: FEXPM1 ( r -- e^r - 1 ) FEXP 1 S>F F- ;

\ --- hyperbolic ------------------------------------------------------------
: FSINH ( r -- sinh )  FDUP FEXP FSWAP FNEGATE FEXP F- 2 S>F F/ ;
: FCOSH ( r -- cosh )  FDUP FEXP FSWAP FNEGATE FEXP F+ 2 S>F F/ ;
: FTANH ( r -- tanh )  FDUP FSINH FSWAP FCOSH F/ ;

\ --- inverse trig (built on FATAN) -----------------------------------------
\ FASIN/FACOS via atan; both are undefined at |r| = 1 (division by zero there).
: FASIN ( r -- asin )  FDUP FDUP F* 1 S>F FSWAP F- FSQRT F/ FATAN ;
: FACOS ( r -- acos )  FASIN FPI2 FSWAP F- ;

FVARIABLE FT2Y   FVARIABLE FT2X
: FATAN2 ( y x -- angle )   \ full-quadrant, result in (-pi, pi]
   FT2X F! FT2Y F!
   FT2X F@ F0= IF                       \ x = 0 : straight up / down
      FT2Y F@ F0< IF FPI2 FNEGATE ELSE FPI2 THEN EXIT
   THEN
   FT2Y F@ FT2X F@ F/ FATAN             \ base = atan(y/x)
   FT2X F@ F0< IF                       \ x < 0 : shift into the correct quadrant
      FT2Y F@ F0< IF FPI F- ELSE FPI F+ THEN
   THEN ;

\ --- approximate comparison (mainly a test aid) ----------------------------
\ F~ ( r1 r2 r3 -- flag ) : r3>0 absolute |r1-r2|<r3 ; r3=0 exact ;
\                          r3<0 relative |r1-r2| < |r3|*(|r1|+|r2|)
FVARIABLE F~TOL
: F~ ( r1 r2 r3 -- flag )
   FDUP F0= IF  FDROP  F- F0=  EXIT THEN
   FDUP F0< IF
      FABS F~TOL F!
      FOVER FOVER FABS FSWAP FABS F+
      F~TOL F@ F* F~TOL F!
   ELSE
      F~TOL F!
   THEN
   F- FABS  F~TOL F@  F< ;

\ --- BASIC-style function names (merged from the former BASICMATH.FTH) --------
\ Convenience aliases for the built-in FP words ( F: r -- f(r) ):
\     2 S>F SQR F.        \ 1.41421356
: SQR   FSQRT  ;     \ square root
: SIN   FSIN   ;     \ sine (radians)
: COS   FCOS   ;     \ cosine (radians)
: TAN   FTAN   ;     \ tangent (radians)
: ATN   FATAN  ;     \ arctangent
: LOG   FLN    ;     \ natural logarithm (BASIC LOG = natural log)
: EXP   FEXP   ;     \ e^r
