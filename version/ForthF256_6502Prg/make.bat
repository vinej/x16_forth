@echo off
rem === Build ForthF256_6502Prg -> ForthF256_6502Prg.pgz (Foenix F256) ===
setlocal
pushd "%~dp0..\.."
if exist "version\ForthF256_6502Prg\ForthF256_6502Prg.pgz" del "version\ForthF256_6502Prg\ForthF256_6502Prg.pgz"
.\asm\acme --cpu 65c02 --outfile "version\ForthF256_6502Prg\ForthF256_6502Prg.pgz" --format plain "version\ForthF256_6502Prg\build.asm"
if errorlevel 1 (echo *** BUILD FAILED *** & popd & endlocal & exit /b 1)
echo Built version\ForthF256_6502Prg\ForthF256_6502Prg.pgz
popd
endlocal
