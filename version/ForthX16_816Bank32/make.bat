@echo off
rem === Build ForthX16_816Bank32 -> ForthX16_816Bank32.bin (65816 ROM bank 32) ===
rem 16 KB bank-32 image, 65816-native, no CX16 autoboot signature; launched from
rem BASIC via loader32.prg (SYS 2064). Graphics are a toolkit (GFXTOOLKIT
rem default); bank-I/O words built in. Assembled with --cpu 65816.
setlocal
pushd "%~dp0..\.."
if exist "version\ForthX16_816Bank32\ForthX16_816Bank32.bin" del "version\ForthX16_816Bank32\ForthX16_816Bank32.bin"
.\asm\acme --cpu 65816 --outfile "version\ForthX16_816Bank32\ForthX16_816Bank32.bin" --format plain "version\ForthX16_816Bank32\build.asm"
if errorlevel 1 (echo *** BUILD FAILED *** & popd & endlocal & exit /b 1)
echo Built version\ForthX16_816Bank32\ForthX16_816Bank32.bin
popd
endlocal
