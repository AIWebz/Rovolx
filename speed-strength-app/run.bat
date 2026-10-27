@echo off
rem Launch the app installed by setup.bat / setup.ps1.
if not exist "%~dp0.venv\Scripts\pythonw.exe" (
  echo ERROR: not installed. Run setup.bat first.
  pause
  exit /b 1
)
start "" "%~dp0.venv\Scripts\pythonw.exe" -m sbe_modifier %*
