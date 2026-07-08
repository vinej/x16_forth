@echo off
rem === Build ForthX16_6502Prg -> ForthX16_6502Prg.prg (X16, 6502) ===
setlocal
pushd "%~dp0..\.."
if exist "version\ForthX16_6502Prg\ForthX16_6502Prg.prg" del "version\ForthX16_6502Prg\ForthX16_6502Prg.prg"
.\asm\acme --cpu 6502 --outfile "version\ForthX16_6502Prg\ForthX16_6502Prg.prg" --format cbm "version\ForthX16_6502Prg\build.asm"
if errorlevel 1 (echo *** BUILD FAILED *** & popd & endlocal & exit /b 1)
echo Built version\ForthX16_6502Prg\ForthX16_6502Prg.prg
popd
endlocal
