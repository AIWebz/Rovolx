# Run the tests and build dist\SBESpeedMoney.exe with PyInstaller.
$ErrorActionPreference = "Continue"  # exit codes are checked explicitly
Set-Location $PSScriptRoot
function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

$venvPy = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPy)) { & (Join-Path $PSScriptRoot "setup.ps1") -Dev; if ($LASTEXITCODE -ne 0) { exit 1 } }
& $venvPy -m pip install -q -r requirements-dev.txt
if ($LASTEXITCODE -ne 0) { Fail "installing build tools failed" }

& $venvPy -m pytest -q -rs
if ($LASTEXITCODE -ne 0) { Fail "tests failed; not building" }

Remove-Item -Recurse -Force build, dist -ErrorAction SilentlyContinue
& $venvPy -m PyInstaller --noconfirm --distpath dist --workpath build packaging\sbe_speed_strength.spec
if ($LASTEXITCODE -ne 0) { Fail "PyInstaller build failed" }
Write-Host "Built: $(Join-Path $PSScriptRoot 'dist\SBESpeedMoney.exe')" -ForegroundColor Green
