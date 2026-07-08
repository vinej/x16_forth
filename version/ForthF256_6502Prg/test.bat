@echo off
rem === Build ForthF256_6502Prg; no F256 emulator ships with this repo ===
rem The Foenix F256 is not scriptable here. Build the .pgz, then test it with the
rem Foenix IDE (https://github.com/Trinity-11/FoenixIDE): install it yourself and
rem point its "SD card" folder at this directory so the .pgz is visible, or copy
rem the .pgz onto a real F256 SD card.
call "%~dp0make.bat"
if errorlevel 1 exit /b 1
echo.
echo Built ForthF256_6502Prg.pgz. No F256 emulator is bundled.
echo Test with the Foenix IDE: point its SD-card folder at:
echo   %~dp0
echo then run ForthF256_6502Prg.pgz from the IDE, or copy it to a real F256 card.
echo.
