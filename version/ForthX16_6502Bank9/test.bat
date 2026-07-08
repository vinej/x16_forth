@echo off
rem === Build + launch ForthX16_6502Bank9 (Forth in ROM bank 9) ===
rem make.bat produces the ready-to-run 256K ROM (r49.bin base + bank 9 replaced
rem by the assembled image); this just launches the emulator with it. At the
rem BASIC READY prompt type TEST to start Forth in place from bank 9.
call "%~dp0make.bat"
if errorlevel 1 exit /b 1
pushd "%~dp0..\.."
echo.
echo At the BASIC READY prompt type:   TEST     (starts Forth in ROM bank 9)
echo.
.\emulator\x16emu.exe -rom "version\ForthX16_6502Bank9\ForthX16_6502Bank9.bin" -run -sdcard "sdcard\sdcard.img"
popd
