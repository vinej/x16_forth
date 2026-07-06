; Loader: BASIC stub SYS 2064 -> jsrfar into ForthX16 ROM bank 32 coldstart.
; Same as loader.asm but targets bank 32 (the cart bank) instead of bank 9.
; Boot the machine with boot2.rom in bank 32 (no autoboot), then at the BASIC
; READY prompt: LOAD"LOADER32",8 : RUN  (or SYS 2064).
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
   !word $c004          ; coldstart (directly after the 4-byte CX16 signature)
   !byte $20            ; bank 32
   rts
