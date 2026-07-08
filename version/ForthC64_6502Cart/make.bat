@echo off
rem === Build ForthC64_6502Cart -> ForthC64_6502Cart.crt (C64 cartridge) ===
rem Two steps: ACME -> raw 8K .rom image, then VICE cartconv -> .crt.
setlocal
pushd "%~dp0..\.."
if exist "version\ForthC64_6502Cart\ForthC64_6502Cart.crt" del "version\ForthC64_6502Cart\ForthC64_6502Cart.crt"
.\asm\acme --cpu 6502 --outfile "version\ForthC64_6502Cart\ForthC64_6502Cart.rom" --format plain "version\ForthC64_6502Cart\build.asm"
if errorlevel 1 (echo *** BUILD FAILED *** & popd & endlocal & exit /b 1)
.\vice\bin\cartconv -t normal -n "Forth T for C64" -i "version\ForthC64_6502Cart\ForthC64_6502Cart.rom" -o "version\ForthC64_6502Cart\ForthC64_6502Cart.crt"
if errorlevel 1 (echo *** cartconv FAILED - is VICE in .\vice\ ? *** & popd & endlocal & exit /b 1)
del "version\ForthC64_6502Cart\ForthC64_6502Cart.rom"
echo Built version\ForthC64_6502Cart\ForthC64_6502Cart.crt
popd
endlocal
