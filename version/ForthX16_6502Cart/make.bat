@echo off
rem === Build ForthX16_6502Cart -> ForthX16_6502Cart.bin (X16 autoboot cartridge) ===
rem Two steps: build the X16 6502 PRG into _forthx16prg.tmp, then wrap it with
rem build.asm (the CX16-signature cart stub that copies the PRG to RAM and runs).
setlocal
pushd "%~dp0..\.."
if exist "version\ForthX16_6502Cart\ForthX16_6502Cart.bin" del "version\ForthX16_6502Cart\ForthX16_6502Cart.bin"
.\asm\acme --cpu 6502 --outfile "version\ForthX16_6502Cart\_forthx16prg.tmp" --format cbm "version\ForthX16_6502Prg\build.asm"
if errorlevel 1 (echo *** PRG BUILD FAILED *** & popd & endlocal & exit /b 1)
.\asm\acme --cpu 6502 --outfile "version\ForthX16_6502Cart\ForthX16_6502Cart.bin" --format plain "version\ForthX16_6502Cart\build.asm"
if errorlevel 1 (echo *** CART WRAP FAILED *** & popd & endlocal & exit /b 1)
del "version\ForthX16_6502Cart\_forthx16prg.tmp"
echo Built version\ForthX16_6502Cart\ForthX16_6502Cart.bin
popd
endlocal
