@call makex16.bat

del forthcart.bin
.\asm\acme --cpu 6502 --format plain --outfile forthcart.bin x16cart.asm
