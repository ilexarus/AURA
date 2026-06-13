@echo off
setlocal EnableExtensions
cd /d "%~dp0"

if exist "%~dp0.venv\Scripts\python.exe" goto use_venv

py -3 -c "import sys; assert sys.version_info >= (3,10)" >nul 2>&1
if not errorlevel 1 goto use_py

python -c "import sys; assert sys.version_info >= (3,10)" >nul 2>&1
if not errorlevel 1 goto use_python

python3 -c "import sys; assert sys.version_info >= (3,10)" >nul 2>&1
if not errorlevel 1 goto use_python3

echo [ERROR] Python 3.10 or newer was not found.
pause
exit /b 10

:use_venv
"%~dp0.venv\Scripts\python.exe" tools\download_wake_model.py
goto done

:use_py
py -3 tools\download_wake_model.py
goto done

:use_python
python tools\download_wake_model.py
goto done

:use_python3
python3 tools\download_wake_model.py

:done
if errorlevel 1 goto failed

echo.
echo [AURA] Voice activation model is ready.
echo Restart AURA and say: Aura
pause
exit /b 0

:failed
echo.
echo [ERROR] Voice activation repair failed.
echo Check launcher.log or use the manual ZIP method shown above.
pause
exit /b 1
