@echo off
setlocal
REM Little Mega People build: assemble the program and pack the D81.
REM Graphics in assets\ and src\gen\ are produced by "python tools\build_assets.py"
REM (only needed after changing art or tools\). Run "build.bat assets" to do both.
if not exist target mkdir target
if not exist target\userprofile\AppData\Roaming mkdir target\userprofile\AppData\Roaming
set "USERPROFILE=%CD%\target\userprofile"
set "APPDATA=%USERPROFILE%\AppData\Roaming"

if /I "%1"=="assets" (
    python tools\build_assets.py
    if errorlevel 1 exit /b 1
)

del target\*.d81 2>nul
del target\littlemegapeople 2>nul

.\64tass.exe --cbm-prg -B -a src\main.asm -l target\lmp.lbl -L target\lmp.lst -o target\littlemegapeople --output-section=lo
if errorlevel 1 exit /b 1
REM The high part ($C000-$CFFF), copied into place at boot.
.\64tass.exe --cbm-prg -B -a src\main.asm -o target\lmp-hi.prg --output-section=hi -q
if errorlevel 1 exit /b 1
REM The overlays for the $C000 window: the card games and the letters.
.\64tass.exe --cbm-prg -B -a src\main.asm -o target\lmp-cards.prg --output-section=ovc -q
if errorlevel 1 exit /b 1
.\64tass.exe --cbm-prg -B -a src\main.asm -o target\lmp-letters.prg --output-section=ovl -q
if errorlevel 1 exit /b 1
REM The game's text (far strings), copied to Attic RAM at boot.
.\64tass.exe --cbm-prg -B -a src\main.asm -o target\lmp-text.prg --output-section=ftext -q
if errorlevel 1 exit /b 1

cd target
..\c1541.exe -format "little mega people,lm" d81 littlemegapeople.d81
if errorlevel 1 exit /b 1
REM The program must be the first file so autoboot / RUN"*" picks it.
..\c1541.exe -attach littlemegapeople.d81 -write littlemegapeople littlemegapeople
if errorlevel 1 exit /b 1
..\c1541.exe -attach littlemegapeople.d81 -write ..\assets\bg.prg lmp-bg
if errorlevel 1 exit /b 1
..\c1541.exe -attach littlemegapeople.d81 -write ..\assets\title.prg lmp-title
if errorlevel 1 exit /b 1
..\c1541.exe -attach littlemegapeople.d81 -write ..\assets\gfx.prg lmp-gfx
if errorlevel 1 exit /b 1
..\c1541.exe -attach littlemegapeople.d81 -write ..\assets\sounds.prg lmp-sounds
if errorlevel 1 exit /b 1
..\c1541.exe -attach littlemegapeople.d81 -write ..\assets\sounds2.prg lmp-sounds2
if errorlevel 1 exit /b 1
..\c1541.exe -attach littlemegapeople.d81 -write ..\assets\patches.prg lmp-patches
if errorlevel 1 exit /b 1
..\c1541.exe -attach littlemegapeople.d81 -write lmp-hi.prg lmp-hi
if errorlevel 1 exit /b 1
..\c1541.exe -attach littlemegapeople.d81 -write lmp-text.prg lmp-text
if errorlevel 1 exit /b 1
..\c1541.exe -attach littlemegapeople.d81 -write lmp-cards.prg lmp-cards
if errorlevel 1 exit /b 1
..\c1541.exe -attach littlemegapeople.d81 -write lmp-letters.prg lmp-letters
if errorlevel 1 exit /b 1
cd ..

echo Built target\littlemegapeople.d81
