@echo off
setlocal
cd /d "%~dp0"
echo Windows Repair Toolkit v1.0
echo 1. Check only
echo 2. Targeted service repair
echo 3. DISM and SFC
choice /c 123 /n /m "Select mode: "
if errorlevel 3 (set "MODE=Integrity") else if errorlevel 2 (set "MODE=Repair") else (set "MODE=Check")
powershell.exe -NoProfile -Command "Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -Verb RunAs -Wait -ArgumentList ('-NoProfile -NoExit -File ""'+(Join-Path (Get-Location) 'Repair.ps1')+'"" -Mode %MODE%')"
pause
