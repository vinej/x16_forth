@echo off
rem === Build + launch ForthC64_6502Prg in VICE (C64) ===
call "%~dp0make.bat"
if errorlevel 1 exit /b 1
pushd "%~dp0..\.."
.\vice\bin\x64sc.exe -autostart "version\ForthC64_6502Prg\ForthC64_6502Prg.prg"
popd
