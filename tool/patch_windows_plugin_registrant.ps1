# Removes unused Windows plugins from generated CMake/registrant (after flutter tool regenerates them).
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$registrant = Join-Path $RepoRoot "windows\flutter\generated_plugin_registrant.cc"
$genPlugins = Join-Path $RepoRoot "windows\flutter\generated_plugins.cmake"
$omitPatterns = @(
    "zego_express_engine",
    "ZegoExpress",
    "speech_to_text_windows",
    "SpeechToText"
)
$omitPluginIds = @(
    "zego_express_engine",
    "speech_to_text_windows"
)

# generated_plugins.cmake runs add_subdirectory for every plugin at configure time;
# list(REMOVE_ITEM ...) in windows/CMakeLists.txt runs too late. Strip omitted plugins here.
if (Test-Path $genPlugins) {
    $pluginLines = Get-Content $genPlugins
    $filteredPlugins = $pluginLines | Where-Object {
        $line = $_.Trim()
        foreach ($id in $omitPluginIds) {
            if ($line -eq $id) { return $false }
        }
        return $true
    }
    if ($filteredPlugins.Count -ne $pluginLines.Count) {
        Set-Content -Path $genPlugins -Value $filteredPlugins
        Write-Host "Patched generated_plugins.cmake (omitted Zego + speech_to_text)"
    }
}

if (-not (Test-Path $registrant)) {
    Write-Warning "Missing: $registrant"
    exit 0
}

$lines = Get-Content $registrant
$filtered = $lines | Where-Object {
    $line = $_
    foreach ($pat in $omitPatterns) {
        if ($line -match [regex]::Escape($pat)) {
            return $false
        }
    }
    return $true
}

if ($filtered.Count -ne $lines.Count) {
    Set-Content -Path $registrant -Value $filtered
    Write-Host "Patched plugin registrant (omitted Zego + speech_to_text)"
}
