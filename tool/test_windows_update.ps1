# Debug the silent Windows updater outside the Flutter app.
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\tool\test_windows_update.ps1
#   powershell -ExecutionPolicy Bypass -File .\tool\test_windows_update.ps1 -MsiPath ".\dist\Lona-1-9-26-62.msi"
#   powershell -ExecutionPolicy Bypass -File .\tool\test_windows_update.ps1 -DownloadFromRelease "v1.9.26-test"
#
# Logs:
#   %TEMP%\lona-update.log
#   %TEMP%\lona-update-msi.log

param(
  [string]$MsiPath = "",
  [string]$DownloadFromRelease = "",
  [string]$Repo = "FocusKPI-DS/LinkedUp-Club-MacOS",
  [switch]$NoInstall,
  [switch]$NoRelaunch
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$logPath = Join-Path $env:TEMP "lona-update.log"
$msiLogPath = Join-Path $env:TEMP "lona-update-msi.log"

function Write-UpdateLog {
  param([string]$Message)
  $line = "$(Get-Date -Format o) $Message"
  Add-Content -Path $logPath -Value $line
  Write-Host $line
}

function Stop-LonaProcesses {
  foreach ($name in @("lona", "linkedup")) {
    $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
    if ($procs) {
      Write-UpdateLog "Stopping $name ($($procs.Count) process(es))"
      $procs | Stop-Process -Force
    }
  }
  Start-Sleep -Seconds 2
}

function Resolve-LonaExe {
  $candidates = @(
    "${env:ProgramFiles}\Lona\Release\lona.exe",
    "${env:ProgramFiles}\Lona\lona.exe",
    "${env:ProgramFiles}\Lona\Release\linkedup.exe",
    "${env:ProgramFiles}\Lona\linkedup.exe"
  )
  foreach ($path in $candidates) {
    if (Test-Path $path) { return $path }
  }
  return $candidates[0]
}

function Get-MsiFromRelease {
  param([string]$Tag)
  Write-UpdateLog "Fetching release $Tag from $Repo"
  $release = gh release view $Tag --repo $Repo --json assets,tagName 2>$null | ConvertFrom-Json
  if (-not $release) {
    throw "Could not read release $Tag. Install gh CLI and ensure the release exists."
  }
  $manifestAsset = $release.assets | Where-Object { $_.name -eq "lona-windows.json" } | Select-Object -First 1
  $msiAsset = $release.assets | Where-Object { $_.name -like "Lona-*.msi" } | Select-Object -First 1
  if (-not $manifestAsset -or -not $msiAsset) {
    throw "Release $Tag is missing lona-windows.json or Lona-*.msi"
  }
  Write-UpdateLog "Manifest: $($manifestAsset.name)"
  Write-UpdateLog "MSI: $($msiAsset.name) ($([math]::Round($msiAsset.size / 1MB, 1)) MB)"
  $dest = Join-Path $env:TEMP $msiAsset.name
  Write-UpdateLog "Downloading MSI to $dest"
  Invoke-WebRequest -Uri $msiAsset.url -OutFile $dest -Headers @{ Accept = "application/octet-stream" }
  return $dest
}

"" | Set-Content -Path $logPath
Write-UpdateLog "=== test_windows_update.ps1 started ==="
Write-UpdateLog "User: $env:USERNAME"
Write-UpdateLog "IsAdmin: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"

if ($DownloadFromRelease) {
  $MsiPath = Get-MsiFromRelease -Tag $DownloadFromRelease
} elseif (-not $MsiPath) {
  $candidates = Get-ChildItem -Path (Join-Path $RepoRoot "dist") -Filter "Lona-*.msi" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending
  if ($candidates) {
    $MsiPath = $candidates[0].FullName
    Write-UpdateLog "Using newest dist MSI: $MsiPath"
  } else {
    throw "Pass -MsiPath, -DownloadFromRelease, or build an MSI under dist\"
  }
}

$MsiPath = (Resolve-Path $MsiPath).Path
if (-not (Test-Path $MsiPath)) { throw "MSI not found: $MsiPath" }
Write-UpdateLog "MSI path: $MsiPath ($((Get-Item $MsiPath).Length) bytes)"

if ($NoInstall) {
  Write-UpdateLog "NoInstall set - done."
  exit 0
}

Stop-LonaProcesses

Write-UpdateLog "Running msiexec elevated (/quiet + verbose log)..."
Write-UpdateLog "MSI log: $msiLogPath"

try {
  $p = Start-Process -FilePath "msiexec.exe" -ArgumentList @(
    "/i", $MsiPath,
    "/quiet",
    "/norestart",
    "/L*v", $msiLogPath,
    "INSTALLDESKTOPSHORTCUT=0"
  ) -Verb RunAs -PassThru -Wait
} catch {
  Write-UpdateLog "Start-Process failed: $($_.Exception.Message)"
  Write-Host ""
  Write-Host "Could not start elevated msiexec (UAC denied or blocked)." -ForegroundColor Red
  Write-Host "  Update log: $logPath"
  exit 1
}

$code = $p.ExitCode
Write-UpdateLog "msiexec exit code: $code"

$ok = ($code -eq 0 -or $code -eq 3010)
if (-not $ok) {
  Write-Host ""
  Write-Host "INSTALL FAILED (exit $code)" -ForegroundColor Red
  Write-Host "  Update log:  $logPath"
  Write-Host "  MSI log:     $msiLogPath"
  Write-Host ""
  Write-Host "Common codes: 1603=fatal, 1618=another install running, 1638=same version, 1625=admin required"
  exit $code
}

Write-UpdateLog "Install succeeded"
$launch = Resolve-LonaExe
Write-UpdateLog "Resolved exe: $launch (exists=$(Test-Path $launch))"

if (-not $NoRelaunch -and (Test-Path $launch)) {
  Write-UpdateLog "Relaunching Lona"
  Start-Process -FilePath $launch
} elseif (-not $NoRelaunch) {
  Write-UpdateLog "WARNING: exe not found - not relaunching"
}

Write-Host ""
Write-Host "Update test completed successfully." -ForegroundColor Green
Write-Host "  Log: $logPath"
Write-Host "  MSI log: $msiLogPath"
Write-Host "  Exe:   $launch"
