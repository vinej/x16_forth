@echo off
rem === Build + launch ForthX16_6502Cart (autoboot cartridge) in the X16 emulator ===
rem The cart has a CX16 signature, so the emulator boots straight into Forth.
call "%~dp0make.bat"
if errorlevel 1 exit /b 1
pushd "%~dp0..\.."
.\emulator\x16emu.exe -rom .\emulator\rom.bin -cartbin "version\ForthX16_6502Cart\ForthX16_6502Cart.bin" -sdcard "sdcard\sdcard.img"
popd
