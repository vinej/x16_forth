; 65816 native-mode build (MiSTer core, flat 16MB RAM). Isolated from buildx16prg.asm
; so the stock 6502 PRG build is never at risk while this is under development.
PRG = 1
X16 = 1
NATIVE816 = 1
!source "fthtx16.asm"
