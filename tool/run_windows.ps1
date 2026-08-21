# Run Lona on Windows without LNK1168 (lona.exe file lock).
# Usage: powershell -ExecutionPolicy Bypass -File .\tool\run_windows.ps1

$ErrorActionPreference = "Continue"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

Get-Process -Name "lona" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300

Write-Host "Fetching dependencies..."
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Apply pub-cache CMake fixes and omit unused Windows native plugins before configure.
& (Join-Path $PSScriptRoot "patch_windows_cmake.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "patch_windows_plugin_registrant.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$envFile = Join-Path $RepoRoot "env.json"
$args = @("run", "-d", "windows", "--no-pub")
if (Test-Path $envFile) {
  $args += @("--dart-define-from-file=env.json")
}

Write-Host "Starting: flutter $($args -join ' ')"
flutter @args
