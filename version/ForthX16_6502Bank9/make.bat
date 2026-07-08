@echo off
rem === Build ForthX16_6502Bank9 -> ForthX16_6502Bank9.bin ===
rem Two steps:
rem   1. assemble the 16 KB bank-9 image (--cpu 65c02) into _bank9image.bin
rem   2. splice it into a pristine 256 KB ROM at bank 9 (offset 147456) to make
rem      the ready-to-run 256 KB ROM ForthX16_6502Bank9.bin.
rem Patch base, in order: this folder's r49.bin, else emulator\rom.bin.orig,
rem else emulator\rom.bin. (r49.bin is git-ignored - it must not go to GitHub.)
setlocal
pushd "%~dp0..\.."
set FOLDER=version\ForthX16_6502Bank9
if exist "%FOLDER%\ForthX16_6502Bank9.bin" del "%FOLDER%\ForthX16_6502Bank9.bin"
.\asm\acme --cpu 65c02 --outfile "%FOLDER%\_bank9image.bin" --format plain "%FOLDER%\build.asm"
if errorlevel 1 (echo *** BUILD FAILED *** & popd & endlocal & exit /b 1)
set BASE=%FOLDER%\r49.bin
if not exist "%BASE%" set BASE=emulator\rom.bin.orig
if not exist "%BASE%" set BASE=emulator\rom.bin
if not exist "%BASE%" (echo *** No pristine 256K ROM base - put r49.bin in %FOLDER% *** & popd & endlocal & exit /b 1)
copy /Y "%BASE%" "%FOLDER%\ForthX16_6502Bank9.bin" >nul
powershell -NoProfile -Command "$r=[IO.File]::ReadAllBytes('%FOLDER%\ForthX16_6502Bank9.bin'); $f=[IO.File]::ReadAllBytes('%FOLDER%\_bank9image.bin'); if ($f.Length -ne 16384) { Write-Error 'bank image is not 16384 bytes'; exit 1 }; if ($r.Length -ne 262144) { Write-Error 'base ROM is not 262144 bytes'; exit 1 }; [Array]::Copy($f,0,$r,147456,16384); [IO.File]::WriteAllBytes('%FOLDER%\ForthX16_6502Bank9.bin',$r)"
if errorlevel 1 (echo *** PATCH FAILED *** & del "%FOLDER%\ForthX16_6502Bank9.bin" & popd & endlocal & exit /b 1)
del "%FOLDER%\_bank9image.bin"
echo Built %FOLDER%\ForthX16_6502Bank9.bin  (256K ROM, Forth in bank 9 - boot and type TEST)
popd
endlocal
