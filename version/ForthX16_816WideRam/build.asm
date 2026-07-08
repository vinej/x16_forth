; ForthX16 PRG, 65816 native + WIDEDICT wide dictionary, RAM-bank code space
; (8K banks 2-9 via the $A000 window; for stock X16 / no writable ROM banks)
PRG = 1
X16 = 1
NATIVE816 = 1
WIDEDICT = 1
WD_ROMBANKS = 0
!source "fthtx16.asm"
