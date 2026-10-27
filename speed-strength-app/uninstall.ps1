# Remove the virtual environment, build output and Start Menu shortcut.
#   powershell -ExecutionPolicy Bypass -File uninstall.ps1                  keep settings and logs
#   powershell -ExecutionPolicy Bypass -File uninstall.ps1 -RemoveUserData  also delete them
param([switch]$RemoveUserData)
Set-Location $PSScriptRoot
Remove-Item -Recurse -Force .venv, build, dist, .pytest_cache -ErrorAction SilentlyContinue
Get-ChildItem -Filter *.egg-info -Directory | Remove-Item -Recurse -Force
foreach ($name in "Steal And Break Eggs - Speed & Money.lnk", "Steal And Break Eggs - Speed & Strength.lnk") {
    Remove-Item -Force (Join-Path ([Environment]::GetFolderPath("Programs")) $name) -ErrorAction SilentlyContinue
}
if ($RemoveUserData) {
    $data = Join-Path $env:APPDATA "SBESpeedStrength"
    Remove-Item -Recurse -Force $data -ErrorAction SilentlyContinue
    Write-Host "Deleted $data"
}
Write-Host "Uninstalled. You can now delete this folder."
