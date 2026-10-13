@echo off
rem Client side of the two-network tests. Unzip spike-client.zip, run
rem "Get-ChildItem -Recurse | Unblock-File" in it (PowerShell), then:
rem   client.bat <host-ip> [move|drift] [clients]
rem The host must already be running: bash run_remote.sh move|drift
setlocal
if "%~1"=="" (
	echo usage: client.bat ^<host-ip^> [move^|drift] [clients]
	exit /b 1
)
set "HOST=%~1"
set "TEST=%~2"
if "%TEST%"=="" set "TEST=move"
set "N=%~3"
if "%N%"=="" set "N=6"
set "DUR=60"
if "%TEST%"=="drift" set "DUR=540"
set "GODOT=%~dp0Godot_v4.7.2-stable_win64_console.exe"
cd /d "%~dp0"
rem One import first so the clients do not race on the .godot cache.
"%GODOT%" --headless --path . --import >nul 2>&1
for /L %%i in (1,1,%N%) do start "" /b "%GODOT%" --headless --path . -- --role=client --mode=move --host=%HOST% --duration=%DUR% --seed=%%i --tag=wan-%TEST%-c%%i
echo Started %N% clients against %HOST%. Results print on the host when the run ends.
