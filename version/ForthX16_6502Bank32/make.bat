@echo off
rem === Build ForthX16_6502Bank32 -> ForthX16_6502Bank32.rom (X16 ROM bank 32 cart) ===
rem 16 KB bank-32 image, no CX16 autoboot signature; launched from BASIC via
rem loader32.prg (SYS 2064). Assembled with --cpu 65c02.
setlocal
pushd "%~dp0..\.."
if exist "version\ForthX16_6502Bank32\ForthX16_6502Bank32.bin" del "version\ForthX16_6502Bank32\ForthX16_6502Bank32.bin"
.\asm\acme --cpu 65c02 --outfile "version\ForthX16_6502Bank32\ForthX16_6502Bank32.bin" --format plain "version\ForthX16_6502Bank32\build.asm"
if errorlevel 1 (echo *** BUILD FAILED *** & popd & endlocal & exit /b 1)
echo Built version\ForthX16_6502Bank32\ForthX16_6502Bank32.bin
popd
endlocal
