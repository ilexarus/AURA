@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "NO_PAUSE=0"
if /i "%~1"=="--no-pause" set "NO_PAUSE=1"

call "%~dp0BUILD_PORTABLE.cmd"
if errorlevel 1 exit /b 1

set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" (
  echo.
  echo [ERROR] Inno Setup 6 was not found.
  echo Install Inno Setup 6 and run this file again.
  start "" "https://jrsoftware.org/isdl.php"
  if "%NO_PAUSE%"=="0" pause
  exit /b 2
)

set /p AURA_VERSION=<VERSION.txt
"%ISCC%" /DMyAppVersion=%AURA_VERSION% installer\AURA.iss
if errorlevel 1 exit /b 3

echo.
echo Installer created in dist\installer
if "%NO_PAUSE%"=="0" pause
exit /b 0
