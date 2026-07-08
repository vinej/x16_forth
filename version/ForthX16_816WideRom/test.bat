@echo off
rem === Build + launch ForthX16_816WideRom in the X16 emulator (65816 mode) ===
rem NOTE: ROM-bank code storage needs WRITABLE ROM banks (real MiSTer core). On
rem the stock emulator the banks are not writable, so the wide dictionary falls
rem back to visible-space bodies; the build still boots and runs. For a true test
rem of the ROM-bank wide dictionary, run this .prg on the MiSTer X16 core.
call "%~dp0make.bat"
if errorlevel 1 exit /b 1
pushd "%~dp0..\.."
.\emulator\x16emu.exe -rom .\emulator\rom.bin -prg "version\ForthX16_816WideRom\ForthX16_816WideRom.prg" -run -c816 -sdcard "sdcard\sdcard.img"
popd
