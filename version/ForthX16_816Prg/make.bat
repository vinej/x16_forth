@echo off
rem === Build ForthX16_816Prg -> ForthX16_816Prg.prg (X16, 65816 native) ===
setlocal
pushd "%~dp0..\.."
if exist "version\ForthX16_816Prg\ForthX16_816Prg.prg" del "version\ForthX16_816Prg\ForthX16_816Prg.prg"
.\asm\acme --cpu 65816 --outfile "version\ForthX16_816Prg\ForthX16_816Prg.prg" --format cbm "version\ForthX16_816Prg\build.asm"
if errorlevel 1 (echo *** BUILD FAILED *** & popd & endlocal & exit /b 1)
echo Built version\ForthX16_816Prg\ForthX16_816Prg.prg
popd
endlocal
