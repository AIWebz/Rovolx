# One-step install for Windows: creates .venv, installs the app, adds a
# Start Menu shortcut and runs a launch smoke test.
#   powershell -ExecutionPolicy Bypass -File setup.ps1        install
#   powershell -ExecutionPolicy Bypass -File setup.ps1 -Dev   also install test/build tools
param([switch]$Dev)
# Native tools report failure through exit codes, which are checked below.
$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

$check = "import sys, tkinter; sys.exit(sys.version_info < (3, 10))"
$python = $null
$candidates = @(@("py", "-3.13"), @("py", "-3.12"), @("py", "-3.11"), @("py", "-3.10"), @("python"))
foreach ($c in $candidates) {
    if (Get-Command $c[0] -ErrorAction SilentlyContinue) {
        $args_ = @($c | Select-Object -Skip 1) + @("-c", $check)
        try { & $c[0] @args_ 2>$null | Out-Null } catch { continue }
        if ($LASTEXITCODE -eq 0) { $python = $c; break }
    }
}
if (-not $python) {
    Fail ("Python 3.10+ with Tkinter not found. Install it with:`n" +
          "  winget install Python.Python.3.12`n" +
          "or from https://www.python.org/downloads/ (keep 'tcl/tk and IDLE' checked), then re-run.")
}
$pyArgs = @($python | Select-Object -Skip 1)
Write-Host "Using $(& $python[0] @pyArgs --version)"

& $python[0] @pyArgs -m venv .venv
if ($LASTEXITCODE -ne 0) { Fail "could not create virtual environment" }
$venvPy = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
& $venvPy -m pip install --upgrade pip | Out-Null
& $venvPy -m pip install .
if ($LASTEXITCODE -ne 0) { Fail "installing the app failed" }
if ($Dev) {
    & $venvPy -m pip install -r requirements-dev.txt
    if ($LASTEXITCODE -ne 0) { Fail "installing dev tools failed" }
}

$programs = [Environment]::GetFolderPath("Programs")
# Shortcut name used by version 1 (Speed & Strength).
Remove-Item -Force (Join-Path $programs "Steal And Break Eggs - Speed & Strength.lnk") -ErrorAction SilentlyContinue
$shortcutPath = Join-Path $programs "Steal And Break Eggs - Speed & Money.lnk"
try {
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($shortcutPath)
    $link.TargetPath = Join-Path $PSScriptRoot ".venv\Scripts\pythonw.exe"
    $link.Arguments = "-m sbe_modifier"
    $link.WorkingDirectory = $PSScriptRoot
    $link.Save()
    Write-Host "Added Start Menu shortcut: $shortcutPath"
} catch {
    Write-Host "WARNING: could not create Start Menu shortcut ($_). Use run.bat instead." -ForegroundColor Yellow
}

& $venvPy -m sbe_modifier --smoke-test
if ($LASTEXITCODE -ne 0) { Fail "launch smoke test failed (log: %APPDATA%\SBESpeedStrength\logs\app.log)" }
Write-Host "Installed. Start it from the Start Menu or with run.bat" -ForegroundColor Green
