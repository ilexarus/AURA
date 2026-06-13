@echo off
setlocal EnableExtensions
cd /d "%~dp0"

where gh >nul 2>&1
if errorlevel 1 (
  echo [ERROR] GitHub CLI was not found. Install it and run gh auth login.
  pause
  exit /b 2
)

call "%~dp0BUILD_INSTALLER.cmd" --no-pause
if errorlevel 1 exit /b 1

set /p AURA_VERSION=<VERSION.txt
set "PY=%~dp0.venv\Scripts\python.exe"
set "ASSET=%~dp0dist\installer\AURA-Setup-%AURA_VERSION%.exe"
"%PY%" tools\make_checksum.py "%ASSET%"
if errorlevel 1 exit /b 3

set "CHECKSUM=%ASSET%.sha256"
gh release view "v%AURA_VERSION%" >nul 2>&1
if errorlevel 1 (
  gh release create "v%AURA_VERSION%" "%ASSET%" "%CHECKSUM%" --title "AURA %AURA_VERSION%" --generate-notes
) else (
  gh release upload "v%AURA_VERSION%" "%ASSET%" "%CHECKSUM%" --clobber
)
if errorlevel 1 exit /b 4

echo.
echo Release v%AURA_VERSION% published. Installed AURA copies will detect it automatically.
pause
exit /b 0
