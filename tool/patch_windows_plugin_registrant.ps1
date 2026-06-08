# Removes unused Windows plugins from generated_plugin_registrant.cc (after flutter tool regenerates it).
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$registrant = Join-Path $RepoRoot "windows\flutter\generated_plugin_registrant.cc"
$omitPatterns = @(
    "zego_express_engine",
    "ZegoExpress",
    "speech_to_text_windows",
    "SpeechToText"
)

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
