\ MORTGAGE.FTH - Canadian (Quebec / Canada) mortgage calculator for ForthX16.
\ ===========================================================================
\ In Canada, fixed-rate mortgages are compounded SEMI-ANNUALLY (twice a year),
\ not monthly - this is set by the Interest Act and is the main thing that
\ makes a "Canadian" mortgage differ from a US one.  So the effective monthly
\ rate is derived from a half-yearly rate:
\
\     i = (1 + j/2) ^ (1/6) - 1          j = nominal annual rate (a fraction)
\
\ (1/6 because 2 compoundings/year spread over 12 months = 2/12 = 1/6.)
\ The level monthly payment for a loan L amortized over n monthly payments:
\
\     M = L * i / (1 - (1+i)^-n)
\
\ Uses the floating-point word set (S>F F+ F- F* F/ FLN FEXP ...).
\
\ USAGE  ( principal has a TRAILING DOT - it is a double, so it may exceed
\         65535; rate is in hundredths of a percent: 550 = 5.50%, 1025 = 10.25% )
\
\   100000. 25 550  MTG       \ $100,000, 25 yr, 5.50% -> summary + yearly grid
\   SCHEDULE                  \ then: full month-by-month table (capital+interest)
\   YEARLY                    \ or: one line per year
\
\ Note the dot: 100000. is a 32-bit double; plain 100000 would overflow a
\ 16-bit cell.  Money is shown to the cent - F>S tops out at 65535, so amounts
\ are printed via a 32-bit double + pictured numeric output (<# # #S #>).
\ ===========================================================================

DECIMAL

\ --- floating-point helpers ------------------------------------------------
256 S>F FDUP F*    FCONSTANT F65536     \ 65536.0  (can't write as a 16-bit literal)
1 S>F 2 S>F F/     FCONSTANT FHALF      \ 0.5      (for rounding to the cent)
1 S>F 6 S>F F/     FCONSTANT F1/6       \ 1/6      (semi-annual -> monthly exponent)

: FPOW ( F: x y -- x^y )   FSWAP FLN F* FEXP ;   \ x^y = exp(y * ln x)

\ Signed double -> float.  RSHIFT is logical, so the low word stays unsigned
\ (S>F alone would read a low word >= 32768 as a negative number).
: D>F ( d -- ) ( F: -- r )
   S>F  F65536 F*                 ( lo ; F: hi*65536 )
   DUP 8 RSHIFT S>F  256 S>F F*   ( lo ; F: hi65536  hibyte*256 )
   255 AND S>F  F+                ( ; F: hi65536  lo )
   F+ ;

\ Non-negative integer-valued float ( < 2^32 ) -> unsigned double ( lo hi ).
: F>UD ( F: r -- ) ( -- ud )
   FDUP  F65536 F/  F>S            ( hi ; F: r )
   DUP >R  S>F  F65536 F*  F-      ( ; F: r - hi*65536 )
   F>S  R>                         ( lo hi )
;

\ Float dollars -> double of CENTS, rounded to nearest, clamped at 0.
: F>CENTS ( F: r -- ) ( -- ud )
   100 S>F F*  FHALF F+
   FDUP F0< IF  FDROP  0 0  ELSE  F>UD  THEN ;

\ Print a double number of cents as  dddd.cc  (optionally right-justified).
: (.$) ( ud -- c-addr u )   <# # # [CHAR] . HOLD #S #> ;
: .$   ( ud -- )            (.$) TYPE ;
: .$R  ( ud width -- )      >R (.$) R> OVER - SPACES TYPE ;

\ --- model state -----------------------------------------------------------
FVARIABLE LOANAMT      \ original principal
FVARIABLE MRATE        \ monthly periodic rate i
FVARIABLE PAY          \ level monthly payment M
FVARIABLE BAL          \ running balance
FVARIABLE FINT         \ interest portion this period
FVARIABLE FPRN         \ principal portion this period
FVARIABLE PAYX         \ payment actually applied this period (last one differs)
FVARIABLE YINT         \ interest accumulator (yearly view)
FVARIABLE YPRN         \ principal accumulator (yearly view)
VARIABLE  NPER         \ number of monthly payments
VARIABLE  RATEBP       \ annual nominal rate, in hundredths of a percent

\ --- set up a loan ---------------------------------------------------------
\ ( d.principal years -- )  ( F: j -- )   j = annual nominal rate as a fraction.
: SET-LOAN
   2 S>F F/  1 S>F F+  F1/6 FPOW  1 S>F F-   MRATE F!    \ i (Canada rule)
   12 *  NPER !                                 ( d.principal )
   D>F  FDUP LOANAMT F!  FDUP BAL F!            ( ; F: L )
   MRATE F@ F*                                  ( ; F: L*i )
   MRATE F@ 1 S>F F+                            ( ; F: L*i  1+i )
   NPER @ NEGATE S>F  FPOW                      ( ; F: L*i  w=[1+i]^-n )
   1 S>F FSWAP F-                               ( ; F: L*i  1-w )
   F/  PAY F! ;

\ --- reporting -------------------------------------------------------------
: .RATE ( -- )   RATEBP @ 0 <# # # [CHAR] . HOLD #S #> TYPE ;   \ 550 -> 5.50

: SUMMARY ( -- )
   CR ." === CANADIAN MORTGAGE (SEMI-ANNUAL COMPOUNDING) ===" CR
   ." LOAN AMOUNT:       $" LOANAMT F@ F>CENTS .$ CR
   ." ANNUAL RATE:        " .RATE ." %" CR
   ." AMORTIZATION:       " NPER @ 12 / 0 .R ."  YR  ("
                            NPER @ 0 .R ."  PAYMENTS)" CR
   ." MONTHLY PAYMENT:   $" PAY F@ F>CENTS .$ CR
   ." TOTAL OF PAYMENTS: $" PAY F@ NPER @ S>F F* FDUP F>CENTS .$ CR
   ." TOTAL INTEREST:    $" LOANAMT F@ F- F>CENTS .$ CR ;

: .HEAD ( -- )
   CR ."  PMT      PAYMENT    PRINCIPAL     INTEREST      BALANCE" CR ;

: STEP-ROW ( period -- )
   BAL F@ MRATE F@ F*  FINT F!                  \ interest = balance * i
   DUP NPER @ = IF
      BAL  F@ FPRN F!                            \ last payment clears the balance
      FPRN F@ FINT F@ F+  PAYX F!
   ELSE
      PAY F@ FINT F@ F-  FPRN F!                 \ principal = payment - interest
      PAY F@ PAYX F!
   THEN
   BAL F@ FPRN F@ F-  BAL F!                     \ balance -= principal
   4 .R
   PAYX F@ F>CENTS 13 .$R
   FPRN F@ F>CENTS 13 .$R
   FINT F@ F>CENTS 13 .$R
   BAL  F@ F>CENTS 13 .$R
   CR ;

: SCHEDULE ( -- )   \ full month-by-month grid for the loan set by MTG/SET-LOAN
   LOANAMT F@ BAL F!  .HEAD
   NPER @ 1+ 1 DO  I STEP-ROW  LOOP ;

: YEAR-ROW ( year -- )
   0 S>F YPRN F!   0 S>F YINT F!
   12 0 DO
      BAL F@ MRATE F@ F*  FINT F!
      PAY F@ FINT F@ F-   FPRN F!
      BAL F@ FPRN F@ F-   BAL F!
      YPRN F@ FPRN F@ F+  YPRN F!
      YINT F@ FINT F@ F+  YINT F!
   LOOP
   4 .R
   YPRN F@ F>CENTS 13 .$R
   YINT F@ F>CENTS 13 .$R
   BAL  F@ F>CENTS 13 .$R
   CR ;

: YEARLY ( -- )     \ one aggregated line per year
   LOANAMT F@ BAL F!
   CR ." YEAR    PRINCIPAL     INTEREST      BALANCE" CR
   NPER @ 12 /  1+ 1 DO  I YEAR-ROW  LOOP ;

\ --- main entry ------------------------------------------------------------
\ ( d.principal years rate-bp -- )  rate-bp = annual rate * 100  (550 = 5.50%)
: MTG
   DUP RATEBP !                       ( d.principal years rate-bp )
   S>F  10000 S>F F/                  ( d.principal years ; F: j )
   SET-LOAN  SUMMARY  YEARLY
   CR ." (TYPE  SCHEDULE  FOR THE FULL MONTHLY TABLE.)" CR ;
