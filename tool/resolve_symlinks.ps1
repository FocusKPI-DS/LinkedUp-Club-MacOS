# Fixed symlink resolver for cargokit on Windows (replaces pub-cache copy).
# Handles backslash paths and avoids splitting on "/" only (which breaks under AppData).

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path
)

$ErrorActionPreference = "Stop"

function Resolve-SymlinksFinal {
    param([string]$InputPath)

    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        throw "Path is empty"
    }

    $current = $InputPath.Trim().Trim('"')
    if (-not [System.IO.Path]::IsPathRooted($current)) {
        $current = Join-Path (Get-Location) $current
    }
    $current = [System.IO.Path]::GetFullPath($current)

    $seen = @{}
    for ($i = 0; $i -lt 32; $i++) {
        if ($seen.ContainsKey($current.ToLowerInvariant())) {
            break
        }
        $seen[$current.ToLowerInvariant()] = $true

        if (-not (Test-Path -LiteralPath $current)) {
            throw "Path does not exist: $current"
        }

        $item = Get-Item -LiteralPath $current -Force
        if (-not $item.LinkTarget) {
            break
        }

        $link = $item.LinkTarget
        if (-not [System.IO.Path]::IsPathRooted($link)) {
            $link = Join-Path (Split-Path -Parent $current) $link
        }
        $current = [System.IO.Path]::GetFullPath($link)
    }

    return ($current -replace '\\', '/')
}

Write-Output (Resolve-SymlinksFinal -InputPath $Path)
