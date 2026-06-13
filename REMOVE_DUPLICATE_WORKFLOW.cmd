@echo off
setlocal
cd /d "%~dp0"
if exist ".github\workflows\main.yml" (
  del /f /q ".github\workflows\main.yml"
  echo [AURA] Removed duplicate workflow: .github\workflows\main.yml
) else (
  echo [AURA] Duplicate main.yml was not found.
)
echo [AURA] Keep only .github\workflows\release.yml
pause
