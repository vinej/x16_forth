@echo off
rem === Build + launch ForthX16_6502Bank32 (ROM bank 32, no autoboot) ===
rem This cart has NO CX16 signature, so the machine boots to BASIC. Start Forth
rem from the READY prompt with:   LOAD"LOADER32",8 : RUN     (or SYS 2064)
rem LOADER32 is on the SD-card image (-sdcard below), so LOAD"LOADER32",8 finds it.
call "%~dp0make.bat"
if errorlevel 1 exit /b 1
pushd "%~dp0..\.."
echo.
echo At the BASIC READY prompt type:   LOAD"LOADER32",8 : RUN   (or SYS 2064)
echo.
.\emulator\x16emu.exe -rom .\emulator\rom.bin -cartbin "version\ForthX16_6502Bank32\ForthX16_6502Bank32.bin" -sdcard "sdcard\sdcard.img"
popd
