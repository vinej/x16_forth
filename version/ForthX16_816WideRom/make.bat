@echo off
rem === Build ForthX16_816WideRom -> ForthX16_816WideRom.prg ===
rem 65816 + WIDEDICT, code banks stored in 16K ROM banks (WD_ROMBANKS=1) via the
rem $C000 window - the MiSTer / writable-ROM-bank target.
setlocal
pushd "%~dp0..\.."
if exist "version\ForthX16_816WideRom\ForthX16_816WideRom.prg" del "version\ForthX16_816WideRom\ForthX16_816WideRom.prg"
.\asm\acme --cpu 65816 --outfile "version\ForthX16_816WideRom\ForthX16_816WideRom.prg" --format cbm "version\ForthX16_816WideRom\build.asm"
if errorlevel 1 (echo *** BUILD FAILED *** & popd & endlocal & exit /b 1)
echo Built version\ForthX16_816WideRom\ForthX16_816WideRom.prg
popd
endlocal
