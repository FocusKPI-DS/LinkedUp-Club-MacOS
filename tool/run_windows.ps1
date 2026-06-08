# Run Lona on Windows without LNK1168 (lona.exe file lock).
# Usage: powershell -ExecutionPolicy Bypass -File .\tool\run_windows.ps1

$ErrorActionPreference = "Continue"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

Get-Process -Name "lona" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300

$envFile = Join-Path $RepoRoot "env.json"
$args = @("run", "-d", "windows")
if (Test-Path $envFile) {
  $args += @("--dart-define-from-file=env.json")
}

Write-Host "Starting: flutter $($args -join ' ')"
flutter @args
