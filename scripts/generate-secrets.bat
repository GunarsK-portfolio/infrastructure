@echo off
REM Wrapper script for generate-secrets.py on Windows
REM Checks for Python 3 and executes the Python script

setlocal

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"

REM Check if Python 3 is available
where python3 >nul 2>&1
if %ERRORLEVEL% equ 0 (
    set "PYTHON_CMD=python3"
    goto :run_script
)

where python >nul 2>&1
if %ERRORLEVEL% equ 0 (
    REM Check if 'python' is Python 3
    for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
    for /f "tokens=1 delims=." %%a in ("%PYTHON_VERSION%") do set PYTHON_MAJOR=%%a
    if "%PYTHON_MAJOR%"=="3" (
        set "PYTHON_CMD=python"
        goto :run_script
    )
)

echo Error: Python 3 is required but not found.
echo Please install Python 3 and ensure it's in your PATH.
echo Download from: https://www.python.org/downloads/
exit /b 1

:run_script
"%PYTHON_CMD%" "%SCRIPT_DIR%generate-secrets.py" %*
exit /b %ERRORLEVEL%
