@echo off
setlocal EnableExtensions
cd /d "%~dp0"

call "%~dp0START_AURA.cmd" --setup-only
if errorlevel 1 exit /b 1

set "PY=%~dp0.venv\Scripts\python.exe"
"%PY%" -m pip install --disable-pip-version-check pyinstaller
if errorlevel 1 goto error

if exist build rmdir /s /q build
if exist dist\AURA rmdir /s /q dist\AURA
if exist dist\updater rmdir /s /q dist\updater

"%PY%" -m PyInstaller --noconfirm --clean --windowed ^
  --name AURA ^
  --icon assets\icon.ico ^
  --add-data "ui;ui" ^
  --add-data "assets;assets" ^
  --add-data "update_config.json;." ^
  --add-data "VERSION.txt;." ^
  --collect-all speech_recognition ^
  app.py
if errorlevel 1 goto error

"%PY%" -m PyInstaller --noconfirm --clean --onefile --windowed ^
  --name AURAUpdater ^
  --icon assets\icon.ico ^
  --distpath dist\updater ^
  --workpath build\updater ^
  updater_launcher.py
if errorlevel 1 goto error

copy /y "dist\updater\AURAUpdater.exe" "dist\AURA\AURAUpdater.exe" >nul
if errorlevel 1 goto error

echo.
echo Portable build created in dist\AURA
exit /b 0

:error
echo.
echo [ERROR] Portable build failed. See launcher.log and the console output.
exit /b 1
