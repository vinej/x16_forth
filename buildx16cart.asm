; Cart build: ForthX16 as a self-booting X16 cartridge (MiSTer boot2.rom).
; Like the bank-9 ROM build, but lives in / crosses into ROM bank 32 (where the
; MiSTer maps a cartridge) and carries the "CX16" boot signature at $C000 with the
; entry point at $C004, per the KERNAL's boot_cartridge. Produces a 16K plain
; binary -> boot2.rom.  The bank-9 build (buildx16rom.asm) keeps its own $C000
; TEST-vector layout and is entered by loader.prg.
X16ROM = 1
X16 = 1
FORTH_BANK = 32
X16CART = 1
!source "fthtx16.asm"
