@echo off
rem === Build + launch ForthX16_6502Prg in the X16 emulator ===
call "%~dp0make.bat"
if errorlevel 1 exit /b 1
pushd "%~dp0..\.."
.\emulator\x16emu.exe -rom .\emulator\rom.bin -prg "version\ForthX16_6502Prg\ForthX16_6502Prg.prg" -run -sdcard "sdcard\sdcard.img"
popd
