@echo off
setlocal EnableExtensions
cd /d "%~dp0"

py -3 -c "import sys; assert sys.version_info >= (3,10)" >nul 2>&1
if not errorlevel 1 goto use_py

python -c "import sys; assert sys.version_info >= (3,10)" >nul 2>&1
if not errorlevel 1 goto use_python

python3 -c "import sys; assert sys.version_info >= (3,10)" >nul 2>&1
if not errorlevel 1 goto use_python3

echo.
echo [ERROR] Python 3.10 or newer was not found.
echo Install 64-bit Python and enable Add Python to PATH.
start "" "https://www.python.org/downloads/windows/"
pause
exit /b 10

:use_py
py -3 bootstrap.py %*
goto done

:use_python
python bootstrap.py %*
goto done

:use_python3
python3 bootstrap.py %*

:done
set "AURA_EXIT=%ERRORLEVEL%"
if not "%AURA_EXIT%"=="0" pause
exit /b %AURA_EXIT%
