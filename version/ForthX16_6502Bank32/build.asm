; Bank-32 cart build for launch-FROM-BASIC testing (2026-07-05).
; Identical to the bank-9 ROM build (buildx16rom.asm) except it lives in ROM
; bank 32 (where the MiSTer maps a cartridge). It has NO "CX16" autoboot
; signature, so boot_cartridge ignores it and the machine boots to BASIC
; normally; you then launch it from BASIC with loader32.prg (SYS 2064 ->
; jsrfar $C00F bank 32). Because it enters from a running BASIC (like bank-9),
; BASIC's CHRGET / FP state is already set up, so NO chrget fix is needed.
; Produces a 16K plain binary -> boot2.rom. Does NOT touch the bank-9 build.
FORTH_BANK = 32
X16CART = 1
X16ROM = 1
X16 = 1
!source "fthtx16.asm"
