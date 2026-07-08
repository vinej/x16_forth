@echo off
rem === Build ForthC64_6502Disk -> ForthC64_6502Disk.d64 (C64 1541 disk image) ===
rem Builds the C64 PRG, then packages it onto a .d64 together with the ANS test
rem suite, the inline assembler, the dynamic-memory library, and a few examples.
rem Requires VICE (c1541) in .\vice\.
setlocal
pushd "%~dp0..\.."
set FOLDER=version\ForthC64_6502Disk
set D64=%FOLDER%\ForthC64_6502Disk.d64
if exist "%FOLDER%\ForthC64_6502Disk.prg" del "%FOLDER%\ForthC64_6502Disk.prg"
if exist "%D64%" del "%D64%"
.\asm\acme --cpu 6502 --outfile "%FOLDER%\ForthC64_6502Disk.prg" --format cbm "%FOLDER%\build.asm"
if errorlevel 1 (echo *** PRG BUILD FAILED *** & popd & endlocal & exit /b 1)
.\vice\bin\c1541 -format "forth tx16,01" d64 "%D64%" -attach "%D64%" -write "%FOLDER%\ForthC64_6502Disk.prg" forth
if errorlevel 1 (echo *** c1541 FAILED - is VICE in .\vice\ ? *** & popd & endlocal & exit /b 1)
.\vice\bin\c1541 -attach "%D64%" -write tests\RUNTESTS.FTH runtests.fth,s -write tests\PRELIM.FTH prelim.fth,s -write tests\TESTER.FR tester.fr,s -write tests\CORE.FR core.fr,s -write tests\COREPLUS.FTH coreplus.fth,s -write tests\UTIL.FTH util.fth,s -write tests\ERRORREP.FTH errorrep.fth,s -write tests\COREEXT.FTH coreext.fth,s -write tests\DOUBLE.FTH double.fth,s -write tests\FACILITY.FTH facility.fth,s -write tests\SEARCH.FTH search.fth,s
.\vice\bin\c1541 -attach "%D64%" -write toolkit\ASSEMBLER.FTH assembler.fth,s -write dynamic\DYNAMIC.FS dynamic.fs,s -write other\BENCH.FTH bench.fth,s -write other\ERASTO.FTH erasto.fth,s -write other\RC4TEST.FTH rc4test.fth,s
del "%FOLDER%\ForthC64_6502Disk.prg"
echo Built %D64%
popd
endlocal
