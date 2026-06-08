# Build Lona Windows Release and package as MSI (WiX Toolset v3).
# Prerequisites: Flutter SDK, WiX 3.14+ (winget install WiXToolset.WiXToolset), env.json for OAuth defines.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\tool\build_msi.ps1
#   powershell -ExecutionPolicy Bypass -File .\tool\build_msi.ps1 -SkipFlutterBuild

param(
  [switch]$SkipFlutterBuild
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Find-WixBin {
  $candidates = @(
    (Join-Path ${env:ProgramFiles(x86)} "WiX Toolset v3.14\bin"),
    (Join-Path ${env:ProgramFiles(x86)} "WiX Toolset v3.11\bin"),
    (Join-Path $env:ProgramFiles "WiX Toolset v3.14\bin"),
    (Join-Path $env:ProgramFiles "WiX Toolset v3.11\bin")
  )
  foreach ($dir in $candidates) {
    if (Test-Path (Join-Path $dir "candle.exe")) {
      return $dir
    }
  }
  $heat = Get-Command heat.exe -ErrorAction SilentlyContinue
  if ($heat) { return Split-Path -Parent $heat.Source }
  return $null
}

function Get-PubspecAppVersion {
  $line = Select-String -Path (Join-Path $RepoRoot "pubspec.yaml") -Pattern "^version:" | Select-Object -First 1
  if (-not $line) { throw "Could not read version from pubspec.yaml" }
  $raw = ($line.Line -replace "^version:\s*", "").Trim()
  if ($raw -match "^([^+]+)") {
    return $Matches[1].Trim()
  }
  return $raw
}

function Get-PubspecBuildNumber {
  $line = Select-String -Path (Join-Path $RepoRoot "pubspec.yaml") -Pattern "^version:" | Select-Object -First 1
  $raw = ($line.Line -replace "^version:\s*", "").Trim()
  if ($raw -match "\+(\d+)$") {
    return $Matches[1]
  }
  return "0"
}

function Get-PubspecMsiVersion {
  $line = Select-String -Path (Join-Path $RepoRoot "pubspec.yaml") -Pattern "^version:" | Select-Object -First 1
  if (-not $line) { throw "Could not read version from pubspec.yaml" }
  # 1.9.24+60 -> MSI 1.9.24.60
  $raw = ($line.Line -replace "^version:\s*", "").Trim()
  if ($raw -match "^(\d+)\.(\d+)\.(\d+)\+(\d+)$") {
    return "$($Matches[1]).$($Matches[2]).$($Matches[3]).$($Matches[4])"
  }
  if ($raw -match "^(\d+)\.(\d+)\.(\d+)$") {
    return "$($Matches[1]).$($Matches[2]).$($Matches[3]).0"
  }
  throw "Unexpected pubspec version format: $raw"
}

$wixBin = Find-WixBin
if (-not $wixBin) {
  Write-Host ""
  Write-Host "WiX Toolset not found. Install it, then open a NEW terminal:" -ForegroundColor Yellow
  Write-Host "  winget install WiXToolset.WiXToolset" -ForegroundColor Cyan
  Write-Host ""
  exit 1
}
$env:PATH = "$wixBin;$env:PATH"
Write-Host "Using WiX from: $wixBin"

$productVersion = Get-PubspecMsiVersion
Write-Host "Product version: $productVersion"

$releaseDir = Join-Path $RepoRoot "build\windows\x64\runner\Release"
$installerDir = Join-Path $RepoRoot "installer"
$distDir = Join-Path $RepoRoot "dist"
$harvestWxs = Join-Path $installerDir "Harvest.wxs"
$wixObjDir = Join-Path $installerDir "obj"

if (-not $SkipFlutterBuild) {
  $envFile = Join-Path $RepoRoot "env.json"
  $flutterArgs = @("build", "windows", "--release")
  if (Test-Path $envFile) {
    $flutterArgs += @("--dart-define-from-file=env.json")
  } else {
    Write-Warning "env.json not found - build may miss Google OAuth defines."
  }
  Write-Host "Running: flutter $($flutterArgs -join ' ')"
  flutter @flutterArgs
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if (-not (Test-Path (Join-Path $releaseDir "linkedup.exe"))) {
  throw "Release build not found at $releaseDir - run flutter build windows --release first."
}

New-Item -ItemType Directory -Force -Path $distDir, $wixObjDir | Out-Null

Write-Host "Harvesting Release folder into MSI components..."
if (Test-Path $harvestWxs) { Remove-Item $harvestWxs -Force }

$heatArgs = @(
  "dir", $releaseDir,
  "-cg", "AppHarvest",
  "-dr", "INSTALLFOLDER",
  "-var", "var.ReleaseDir",
  "-out", $harvestWxs,
  "-scom", "-sreg", "-sfrag",
  "-gg", "-suid",
  "-keptachments",
  "-platform", "x64"
)
& heat.exe @heatArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$msiName = "Lona-$($productVersion -replace '\.','-').msi"
$msiPath = Join-Path $distDir $msiName

Write-Host "Compiling WiX..."
$candleArgs = @(
  (Join-Path $installerDir "Product.wxs"),
  $harvestWxs,
  "-out", ($wixObjDir + '\'),
  "-ext", "WixUIExtension",
  "-ext", "WixUtilExtension",
  "-dReleaseDir=$releaseDir",
  "-dProductVersion=$productVersion",
  "-dRepoRoot=$RepoRoot"
)
& candle.exe @candleArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Linking MSI..."
$wixObjs = Get-ChildItem -Path $wixObjDir -Filter "*.wixobj" | ForEach-Object { $_.FullName }
$lightArgs = @(
  $wixObjs
  "-out", $msiPath,
  "-ext", "WixUIExtension",
  "-ext", "WixUtilExtension",
  "-sice:ICE61",
  "-sice:ICE80"
)
& light.exe @lightArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$appVersion = Get-PubspecAppVersion
$buildNumber = Get-PubspecBuildNumber
$manifestPath = Join-Path $distDir "lona-windows.json"
$manifest = @{
  version      = $appVersion
  buildNumber  = $buildNumber
  msiFileName  = $msiName
  releaseNotes = "Lona Windows $appVersion (build $buildNumber)"
} | ConvertTo-Json -Compress
Set-Content -Path $manifestPath -Value $manifest -Encoding UTF8

Write-Host ""
Write-Host "MSI ready:" -ForegroundColor Green
Write-Host "  $msiPath"
Write-Host "Manifest:" -ForegroundColor Green
Write-Host "  $manifestPath"
Write-Host ""
Write-Host "Test install (close Lona first):" -ForegroundColor Cyan
Write-Host "  Start-Process '$msiPath'"
Write-Host ""
Write-Host "Uninstall later: Settings -> Apps -> Lona -> Uninstall"
