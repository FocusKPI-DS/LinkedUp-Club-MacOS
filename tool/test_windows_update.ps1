# Debug the silent Windows updater outside the Flutter app.
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\tool\test_windows_update.ps1
#   powershell -ExecutionPolicy Bypass -File .\tool\test_windows_update.ps1 -MsiPath ".\dist\Lona-1-9-26-62.msi"
#   powershell -ExecutionPolicy Bypass -File .\tool\test_windows_update.ps1 -DownloadFromRelease "v1.9.252"
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

function Get-LonaDesktopDirs {
  @(
    (New-Object -ComObject WScript.Shell).SpecialFolders('Desktop'),
    [Environment]::GetFolderPath('CommonDesktopDirectory')
  ) | Select-Object -Unique
}

function Get-LonaDesktopShortcutDirs {
  $found = @()
  foreach ($desktopDir in Get-LonaDesktopDirs) {
    if (Test-Path (Join-Path $desktopDir 'Lona.lnk')) {
      $found += $desktopDir
    }
  }
  return ,$found
}

function Restore-LonaDesktopShortcut {
  param(
    [string]$ExePath,
    [string[]]$DesktopDirs
  )
  if (-not (Test-Path $ExePath)) { return }
  foreach ($desktopDir in $DesktopDirs) {
    $lnk = Join-Path $desktopDir 'Lona.lnk'
    if (-not (Test-Path $lnk)) {
      Write-UpdateLog "Recreating desktop shortcut: $lnk"
      $wsh = New-Object -ComObject WScript.Shell
      $shortcut = $wsh.CreateShortcut($lnk)
      $shortcut.TargetPath = $ExePath
      $shortcut.WorkingDirectory = Split-Path $ExePath -Parent
      $shortcut.Description = 'Lona'
      $shortcut.Save()
    }
  }
}

function Test-LonaDesktopShortcut {
  return (Get-LonaDesktopShortcutDirs).Count -gt 0
}

function Get-MsiFromRelease {
  param([string]$Tag)
  Write-UpdateLog "Fetching release $Tag from $Repo (GitHub API, same as app updater)"

  $tagName = if ($Tag -match '^v') { $Tag } else { "v$Tag" }
  $apiUrl = "https://api.github.com/repos/$Repo/releases?per_page=20"
  $releases = Invoke-RestMethod -Uri $apiUrl -Headers @{ Accept = "application/vnd.github.v3+json" }
  $release = $releases | Where-Object { $_.tag_name -eq $tagName } | Select-Object -First 1
  if (-not $release) {
    throw "Release $tagName not found on $Repo"
  }

  $manifestAsset = $release.assets | Where-Object { $_.name -eq "lona-windows.json" } | Select-Object -First 1
  if (-not $manifestAsset) {
    throw "Release $tagName is missing lona-windows.json"
  }

  Write-UpdateLog "Manifest URL: $($manifestAsset.browser_download_url)"
  $manifestBody = (Invoke-WebRequest -Uri $manifestAsset.browser_download_url -UseBasicParsing).Content
  if ($manifestBody.Length -gt 0 -and [int][char]$manifestBody[0] -eq 0xFEFF) {
    $manifestBody = $manifestBody.Substring(1)
  }
  $manifest = $manifestBody | ConvertFrom-Json
  Write-UpdateLog "Manifest version: $($manifest.version) build $($manifest.buildNumber)"

  $msiFileName = $manifest.msiFileName
  $msiAsset = $release.assets | Where-Object { $_.name -ieq $msiFileName } | Select-Object -First 1
  if (-not $msiAsset) {
    $msiAsset = $release.assets | Where-Object { $_.name -like "Lona-*.msi" } | Select-Object -First 1
  }
  if (-not $msiAsset) {
    throw "Release $tagName is missing $($msiFileName) (or any Lona-*.msi)"
  }

  Write-UpdateLog "MSI: $($msiAsset.name) ($([math]::Round($msiAsset.size / 1MB, 1)) MB)"
  Write-UpdateLog "Download URL: $($msiAsset.browser_download_url)"

  $dest = Join-Path $env:TEMP $msiAsset.name
  Write-UpdateLog "Downloading MSI to $dest"
  Invoke-WebRequest -Uri $msiAsset.browser_download_url -OutFile $dest -Headers @{
    Accept         = "application/octet-stream"
    "User-Agent"   = "Lona-Updater-Test"
  }
  $size = (Get-Item $dest).Length
  Write-UpdateLog "Downloaded $size bytes"
  if ($size -lt 1024) {
    throw "MSI download looks too small ($size bytes)"
  }
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

$desktopShortcutDirs = Get-LonaDesktopShortcutDirs
$hadDesktopShortcut = $desktopShortcutDirs.Count -gt 0
$desktopShortcutFlag = if ($hadDesktopShortcut) { "1" } else { "0" }
Write-UpdateLog "Had desktop shortcut before update: $hadDesktopShortcut"
if ($hadDesktopShortcut) {
  Write-UpdateLog "Shortcut location(s): $($desktopShortcutDirs -join ', ')"
}

$stagedMsi = Join-Path $env:ProgramData "Lona\lona-update.msi"
$stageDir = Split-Path -Parent $stagedMsi
New-Item -ItemType Directory -Force -Path $stageDir | Out-Null
Copy-Item -Path $MsiPath -Destination $stagedMsi -Force
Write-UpdateLog "Staged MSI: $stagedMsi ($((Get-Item $stagedMsi).Length) bytes)"

Write-UpdateLog "Running msiexec elevated (/quiet + verbose log)..."
Write-UpdateLog "MSI log: $msiLogPath"

try {
  $p = Start-Process -FilePath "msiexec.exe" -ArgumentList @(
    "/i", $stagedMsi,
    "/quiet",
    "/norestart",
    "/L*v", $msiLogPath,
    "INSTALLDESKTOPSHORTCUT=$desktopShortcutFlag"
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

if ($hadDesktopShortcut -and (Test-Path $launch)) {
  Restore-LonaDesktopShortcut -ExePath $launch -DesktopDirs $desktopShortcutDirs
}

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
