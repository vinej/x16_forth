@echo off
rem === Build + launch ForthX16_816Bank32 (65816 ROM bank 32, no autoboot) ===
rem Boots to BASIC; start Forth from the READY prompt with:
rem   LOAD"LOADER32",8 : RUN     (or:  SYS 2064)
call "%~dp0make.bat"
if errorlevel 1 exit /b 1
pushd "%~dp0..\.."
echo.
echo At the BASIC READY prompt type:   LOAD"LOADER32",8 : RUN   (or SYS 2064)
echo.
.\emulator\x16emu.exe -c816 -rom .\emulator\rom.bin -cartbin "version\ForthX16_816Bank32\ForthX16_816Bank32.bin"
popd
