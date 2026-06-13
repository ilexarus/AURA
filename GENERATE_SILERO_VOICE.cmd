@echo off
setlocal EnableExtensions
cd /d "%~dp0"

call "%~dp0START_AURA.cmd" --setup-only
if errorlevel 1 goto error

set "PY=%~dp0.venv\Scripts\python.exe"

echo [AURA] Installing the offline Silero voice builder...
"%PY%" -m pip install --disable-pip-version-check --upgrade numpy
if errorlevel 1 goto error
"%PY%" -m pip install --disable-pip-version-check torch --index-url https://download.pytorch.org/whl/cpu
if errorlevel 1 goto error

echo [AURA] Generating the high-quality Russian voice pack...
"%PY%" tools\generate_silero_voice.py --profile quality --speaker eugene
if errorlevel 1 goto error

echo.
echo [AURA] Voice pack generated successfully.
echo [AURA] Restart AURA to use the new voice.
pause
exit /b 0

:error
echo.
echo [ERROR] Voice generation failed.
echo [ERROR] Check the console output and launcher.log.
pause
exit /b 1
