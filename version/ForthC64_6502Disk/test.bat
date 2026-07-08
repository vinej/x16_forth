@echo off
rem === Build + launch ForthC64_6502Disk in VICE (C64) ===
call "%~dp0make.bat"
if errorlevel 1 exit /b 1
pushd "%~dp0..\.."
.\vice\bin\x64sc.exe -autostart "version\ForthC64_6502Disk\ForthC64_6502Disk.d64"
popd
