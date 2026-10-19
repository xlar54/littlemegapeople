@echo off
call build.bat %1
if errorlevel 1 exit /b 1

C:\Emulation\Mega65\xmega65.exe -8 "%~dp0target\littlemegapeople.d81" -hdosvirt true -autoload true
