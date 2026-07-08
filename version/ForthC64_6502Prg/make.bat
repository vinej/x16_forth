@echo off
rem === Build ForthC64_6502Prg -> ForthC64_6502Prg.prg ===
rem Runs ACME from the repo root so !source "fthtx16.asm" resolves.
setlocal
pushd "%~dp0..\.."
if exist "version\ForthC64_6502Prg\ForthC64_6502Prg.prg" del "version\ForthC64_6502Prg\ForthC64_6502Prg.prg"
.\asm\acme --cpu 6502 --outfile "version\ForthC64_6502Prg\ForthC64_6502Prg.prg" --format cbm "version\ForthC64_6502Prg\build.asm"
if errorlevel 1 (echo *** BUILD FAILED *** & popd & endlocal & exit /b 1)
echo Built version\ForthC64_6502Prg\ForthC64_6502Prg.prg
popd
endlocal
