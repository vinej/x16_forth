\ DIRNAV.FTH - directory-navigation words for ForthX16 (X16 SD card).
\ ===========================================================================
\ Convenience wrappers over the native (CD) worker. Load with: INCLUDE DIRNAV.FTH
\   CD FORTH      change into directory FORTH  (parses the name, like INCLUDE)
\   CD..          go up to the parent directory
\   CD/           go to the root directory
\ DIR (native) lists the current directory.
\ (CD) itself takes a string:  S" NAME" (CD)  - handy inside your own words.

: CD    ( "name" -- )  PARSE-NAME (CD) ;    \ CD FORTH
: CD..  ( -- )         S" .." (CD) ;         \ up one level
: CD/   ( -- )         S" /"  (CD) ;         \ root
