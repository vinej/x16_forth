; Loader: BASIC stub SYS 2064 -> jsrfar into ForthX16 ROM bank 9 coldstart
* = $0801
   !word basic_end
   !word 10
   !byte $9e            ; SYS
   !text "2064"
   !byte 0
basic_end:
   !word 0
* = $0810              ; 2064
   jsr $ff6e            ; KERNAL jsrfar (inline addr+bank follow)
   !word $c00f          ; coldstart
   !byte $09            ; bank 9
   rts
