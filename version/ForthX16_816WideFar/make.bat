@echo off
rem === Build ForthX16_816WideFar -> ForthX16_816WideFar.prg ===
rem 65816 + WIDEDICT + FAR HEADERS (WD_ROMBANKS=0, WD_FARHDR=1): word headers AND
rem bodies live in the 8K RAM banks, so near RAM holds ~only data. Latest wide build.
setlocal
pushd "%~dp0..\.."
if exist "version\ForthX16_816WideFar\ForthX16_816WideFar.prg" del "version\ForthX16_816WideFar\ForthX16_816WideFar.prg"
.\asm\acme --cpu 65816 --outfile "version\ForthX16_816WideFar\ForthX16_816WideFar.prg" --format cbm "version\ForthX16_816WideFar\build.asm"
if errorlevel 1 (echo *** BUILD FAILED *** & popd & endlocal & exit /b 1)
echo Built version\ForthX16_816WideFar\ForthX16_816WideFar.prg
popd
endlocal
