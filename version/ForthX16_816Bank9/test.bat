@echo off
rem === Build + launch ForthX16_816Bank9 (65816 Forth in ROM bank 9) ===
rem make.bat produces the ready-to-run 256K ROM; this launches the emulator in
rem 65816 mode with it. At the BASIC READY prompt type TEST to start Forth.
call "%~dp0make.bat"
if errorlevel 1 exit /b 1
pushd "%~dp0..\.."
echo.
echo At the BASIC READY prompt type:   TEST     (starts 65816 Forth in ROM bank 9)
echo.
.\emulator\x16emu.exe -c816 -rom "version\ForthX16_816Bank9\ForthX16_816Bank9.bin" -run -sdcard "sdcard\sdcard.img"
popd
