@echo off
setlocal EnableExtensions
cd /d "%~dp0"

where py >nul 2>&1
if not errorlevel 1 (
  py -3 tools\configure_updates.py
  goto end
)
where python >nul 2>&1
if not errorlevel 1 (
  python tools\configure_updates.py
  goto end
)
echo [ERROR] Python was not found.
:end
pause
