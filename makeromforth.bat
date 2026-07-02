@echo off
REM ==========================================================================
REM makeromforth.bat - build a Forth-enabled Commander X16 ROM image.
REM
REM Takes the pristine 256 KB / 16-bank ROM (emulator\rom.bin.orig) and writes
REM a copy (emulator\rom.bin) with bank $09 (the old DEMO bank, at byte offset
REM 9*16384 = 147456) replaced by the ForthX16 ROM image (forthx16rom.bin).
REM Booting that ROM and typing TEST at the BASIC prompt launches Forth in
REM place from bank 9.
REM
REM Run makex16rom.bat first to (re)build forthx16rom.bin.
REM ==========================================================================
setlocal
set FORTH=forthx16rom.bin
set ORIG=emulator\rom.bin.orig
set OUT=emulator\rom.bin

if not exist "%FORTH%" (
    echo ERROR: %FORTH% not found. Run makex16rom.bat first.
    exit /b 1
)
if not exist "%ORIG%" (
    echo ERROR: %ORIG% not found ^(pristine 16-bank ROM backup^).
    exit /b 1
)

copy /Y "%ORIG%" "%OUT%" >nul
powershell -NoProfile -Command ^
  "$rom=[IO.File]::ReadAllBytes('%OUT%');" ^
  "$f=[IO.File]::ReadAllBytes('%FORTH%');" ^
  "if ($f.Length -ne 16384) { Write-Error ('forthx16rom.bin is '+$f.Length+' bytes, expected 16384'); exit 1 }" ^
  "[Array]::Copy($f,0,$rom,147456,16384);" ^
  "[IO.File]::WriteAllBytes('%OUT%',$rom)"
if errorlevel 1 exit /b 1

echo Patched bank 9 of %OUT% with %FORTH% ^(boot + type TEST to launch Forth^).
endlocal
