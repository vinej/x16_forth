@echo off
rem === Build + launch ForthC64_6502Cart in VICE (C64 cartridge) ===
call "%~dp0make.bat"
if errorlevel 1 exit /b 1
pushd "%~dp0..\.."
.\vice\bin\x64sc.exe -cartcrt "version\ForthC64_6502Cart\ForthC64_6502Cart.crt"
popd
