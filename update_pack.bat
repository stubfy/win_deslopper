@echo off
setlocal
pushd "%TEMP%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update_pack.ps1"
set "exit_code=%errorlevel%"
popd >nul 2>&1

if "%exit_code%"=="10" exit /b 0

pause
exit /b %exit_code%
