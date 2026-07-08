@echo off
rem === Build ForthX16_816WideRam -> ForthX16_816WideRam.prg ===
rem 65816 + WIDEDICT, code banks stored in 8K RAM banks (WD_ROMBANKS=0) via the
rem $A000 window - stock X16 hardware. Colon word bodies live far, headers near.
setlocal
pushd "%~dp0..\.."
if exist "version\ForthX16_816WideRam\ForthX16_816WideRam.prg" del "version\ForthX16_816WideRam\ForthX16_816WideRam.prg"
.\asm\acme --cpu 65816 --outfile "version\ForthX16_816WideRam\ForthX16_816WideRam.prg" --format cbm "version\ForthX16_816WideRam\build.asm"
if errorlevel 1 (echo *** BUILD FAILED *** & popd & endlocal & exit /b 1)
echo Built version\ForthX16_816WideRam\ForthX16_816WideRam.prg
popd
endlocal
