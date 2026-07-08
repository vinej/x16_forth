@echo off
rem === Build + launch ForthX16_816WideFar in the X16 emulator (65816 mode) ===
call "%~dp0make.bat"
if errorlevel 1 exit /b 1
pushd "%~dp0..\.."
.\emulator\x16emu.exe -rom .\emulator\rom.bin -prg "version\ForthX16_816WideFar\ForthX16_816WideFar.prg" -run -c816
popd
