# Patches pub-cache plugin CMake for Windows (VS 2026 / CMake 4.x, cargokit symlinks, NuGet).
# Run after `flutter pub get`:  powershell -ExecutionPolicy Bypass -File .\tool\patch_windows_cmake.ps1

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Patch-FileLine {
    param([string]$Path, [string]$Old, [string]$New)
    if (-not (Test-Path $Path)) {
        Write-Warning "Skip (missing): $Path"
        return $false
    }
    $content = Get-Content -Raw -Path $Path
    if ($content -notlike "*$Old*") {
        if ($content -like "*$New*") {
            Write-Host "Already patched: $Path"
            return $true
        }
        Write-Warning "Pattern not found in: $Path"
        return $false
    }
    Set-Content -Path $Path -Value ($content.Replace($Old, $New)) -NoNewline
    Write-Host "Patched: $Path"
    return $true
}

function Copy-FileForce {
    param([string]$Source, [string]$Dest)
    if (-not (Test-Path $Source)) {
        Write-Warning "Skip copy (missing source): $Source"
        return
    }
    $destDir = Split-Path -Parent $Dest
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
    Copy-Item -Force $Source $Dest
    Write-Host "Copied: $Dest"
}

$pubCache = if ($env:PUB_CACHE) { $env:PUB_CACHE } else { Join-Path $env:LOCALAPPDATA "Pub\Cache" }

# --- pdfx: CMake 4.x + old cmake_minimum_required in DownloadProject ---
$pdfxDirs = Get-ChildItem -Path (Join-Path $pubCache "hosted\pub.dev") -Filter "pdfx-*" -Directory -ErrorAction SilentlyContinue
foreach ($pdfxDir in $pdfxDirs) {
    $pdfxRoot = Join-Path $pdfxDir.FullName "windows"
    if (-not (Test-Path $pdfxRoot)) { continue }

    Patch-FileLine (Join-Path $pdfxRoot "DownloadProject.cmake") `
        '-D "CMAKE_MAKE_PROGRAM:FILE=${CMAKE_MAKE_PROGRAM}"' `
        '-D "CMAKE_MAKE_PROGRAM:FILE=${CMAKE_MAKE_PROGRAM}"
                        -D "CMAKE_POLICY_VERSION_MINIMUM:STRING=3.5"' | Out-Null

    Patch-FileLine (Join-Path $pdfxRoot "DownloadProject.CMakeLists.cmake.in") `
        "cmake_minimum_required(VERSION 2.8.12)" `
        "cmake_minimum_required(VERSION 3.5)" | Out-Null
}

# --- cargokit: symlink resolver (super_native_extensions, irondash_engine_context, etc.) ---
$resolveSrc = Join-Path $RepoRoot "tool\resolve_symlinks.ps1"
Get-ChildItem -Path (Join-Path $pubCache "hosted\pub.dev") -Recurse -Filter "resolve_symlinks.ps1" -ErrorAction SilentlyContinue |
    ForEach-Object { Copy-FileForce $resolveSrc $_.FullName }

# --- flutter_inappwebview_windows: shorten NuGet custom target paths (MSB3491 / MAX_PATH) ---
$inappDirs = Get-ChildItem -Path (Join-Path $pubCache "hosted\pub.dev") -Filter "flutter_inappwebview_windows-*" -Directory -ErrorAction SilentlyContinue
$inappOldTarget = @"
add_custom_target(`${PROJECT_NAME}_DEPENDENCIES_DOWNLOAD ALL)
add_custom_command(
  TARGET `${PROJECT_NAME}_DEPENDENCIES_DOWNLOAD PRE_BUILD
  COMMAND `${NUGET} install Microsoft.Windows.ImplementationLibrary -Version `${WIL_VERSION} -ExcludeVersion -OutputDirectory `${CMAKE_BINARY_DIR}/packages
  COMMAND `${NUGET} install Microsoft.Web.WebView2 -Version `${WEBVIEW_VERSION} -ExcludeVersion -OutputDirectory `${CMAKE_BINARY_DIR}/packages
  COMMAND `${NUGET} install nlohmann.json -Version `${NLOHMANN_JSON} -ExcludeVersion -OutputDirectory `${CMAKE_BINARY_DIR}/packages
  DEPENDS `${NUGET}
)
"@
$inappNewTarget = @"
# Short target/dir names avoid MSB3491 (MAX_PATH) under deep Flutter build trees.
set(FIW_NUGET_DIR "`${CMAKE_BINARY_DIR}/nuget")
set(FIW_NUGET_TARGET "fiw_nuget_fetch")
add_custom_target(`${FIW_NUGET_TARGET} ALL)
add_custom_command(
  TARGET `${FIW_NUGET_TARGET} PRE_BUILD
  COMMAND `${NUGET} install Microsoft.Windows.ImplementationLibrary -Version `${WIL_VERSION} -ExcludeVersion -OutputDirectory `${FIW_NUGET_DIR}
  COMMAND `${NUGET} install Microsoft.Web.WebView2 -Version `${WEBVIEW_VERSION} -ExcludeVersion -OutputDirectory `${FIW_NUGET_DIR}
  COMMAND `${NUGET} install nlohmann.json -Version `${NLOHMANN_JSON} -ExcludeVersion -OutputDirectory `${FIW_NUGET_DIR}
  DEPENDS `${NUGET}
)
"@
foreach ($inappDir in $inappDirs) {
    $cmake = Join-Path $inappDir.FullName "windows\CMakeLists.txt"
    if (-not (Test-Path $cmake)) { continue }
    Patch-FileLine $cmake $inappOldTarget $inappNewTarget | Out-Null
    Patch-FileLine $cmake '${CMAKE_BINARY_DIR}/packages/Microsoft.Web.WebView2' '${FIW_NUGET_DIR}/Microsoft.Web.WebView2' | Out-Null
    Patch-FileLine $cmake '${CMAKE_BINARY_DIR}/packages/Microsoft.Windows.ImplementationLibrary' '${FIW_NUGET_DIR}/Microsoft.Windows.ImplementationLibrary' | Out-Null
    Patch-FileLine $cmake '${CMAKE_BINARY_DIR}/packages/nlohmann.json' '${FIW_NUGET_DIR}/nlohmann.json' | Out-Null
    $depLine = "add_dependencies(`${PLUGIN_NAME} `${FIW_NUGET_TARGET})"
    $content = Get-Content -Raw $cmake
    if ($content -notlike "*$depLine*") {
        $content = $content.Replace(
            "add_library(`${PLUGIN_NAME} SHARED`r`n  `"include/flutter_inappwebview_windows/flutter_inappwebview_windows_plugin_c_api.h`"`r`n  `"flutter_inappwebview_windows_plugin_c_api.cpp`"`r`n  `${PLUGIN_SOURCES}`r`n)",
            "add_library(`${PLUGIN_NAME} SHARED`r`n  `"include/flutter_inappwebview_windows/flutter_inappwebview_windows_plugin_c_api.h`"`r`n  `"flutter_inappwebview_windows_plugin_c_api.cpp`"`r`n  `${PLUGIN_SOURCES}`r`n)`r`nadd_dependencies(`${PLUGIN_NAME} `${FIW_NUGET_TARGET})"
        )
        if ($content -notlike "*add_dependencies(`${PLUGIN_NAME} `${FIW_NUGET_TARGET})*") {
            $content = $content.Replace(
                "add_library(`${PLUGIN_NAME} SHARED`n  `"include/flutter_inappwebview_windows/flutter_inappwebview_windows_plugin_c_api.h`"`n  `"flutter_inappwebview_windows_plugin_c_api.cpp`"`n  `${PLUGIN_SOURCES}`n)",
                "add_library(`${PLUGIN_NAME} SHARED`n  `"include/flutter_inappwebview_windows/flutter_inappwebview_windows_plugin_c_api.h`"`n  `"flutter_inappwebview_windows_plugin_c_api.cpp`"`n  `${PLUGIN_SOURCES}`n)`nadd_dependencies(`${PLUGIN_NAME} `${FIW_NUGET_TARGET})"
            )
        }
        Set-Content -Path $cmake -Value $content -NoNewline
        Write-Host "Patched add_dependencies: $cmake"
    }
}

# --- liquid_glass_renderer: strip shader assets (SkSL-incompatible on Windows; package is mobile-only) ---
Get-ChildItem -Path (Join-Path $pubCache "hosted\pub.dev") -Filter "liquid_glass_renderer-*" -Directory -ErrorAction SilentlyContinue |
    ForEach-Object {
        $lgPubspec = Join-Path $_.FullName "pubspec.yaml"
        if (-not (Test-Path $lgPubspec)) { return }
        $yaml = Get-Content -Raw $lgPubspec
        if ($yaml -match "# patched-windows-no-shaders") { Write-Host "Already patched: $lgPubspec"; return }
        $yaml = $yaml -replace '(?ms)^flutter:\s*\r?\n\s*shaders:\s*\r?\n(?:\s*- .*\r?\n)+', @"
flutter:
  # patched-windows-no-shaders
  shaders: []
"@
        Set-Content -Path $lgPubspec -Value $yaml -NoNewline
        Write-Host "Stripped liquid_glass shader assets: $lgPubspec"
    }

# --- Bundled nuget.exe for CMake find_program (if not on PATH yet) ---
$nugetDest = Join-Path $RepoRoot "tool\nuget.exe"
if (-not (Test-Path $nugetDest)) {
    $nugetCmd = Get-Command nuget -ErrorAction SilentlyContinue
    if ($nugetCmd) {
        Copy-Item -Force $nugetCmd.Source $nugetDest
        Write-Host "Copied nuget.exe to tool\nuget.exe"
    } else {
        Write-Warning "nuget not on PATH. Install: winget install Microsoft.NuGet"
        Write-Warning "Or download from https://dist.nuget.org/win-x86-commandline/latest/nuget.exe to tool\nuget.exe"
    }
}

# Plugin omit is handled in windows/CMakeLists.txt + patch_windows_plugin_registrant.ps1 at build time.

Write-Host ""
Write-Host "Done. Restart terminal if nuget was just installed, then:"
Write-Host "  flutter clean"
Write-Host "  flutter pub get"
Write-Host "  flutter build windows --release"
