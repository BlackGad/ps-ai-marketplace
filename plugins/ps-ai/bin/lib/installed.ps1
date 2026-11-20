param()

$ErrorActionPreference = 'Stop'

function Get-PsAiInstalledVersion {
    param([string]$ConfigDir, $Tool)

    $cache = Join-Path $ConfigDir $Tool.plugin.installedRoot
    if (-not (Test-Path -LiteralPath $cache -PathType Container)) { return $null }
    $highest = $null
    $versionText = $null
    foreach ($file in Get-ChildItem -LiteralPath $cache -Filter plugin.json -File -Recurse) {
        try {
            $manifest = [IO.File]::ReadAllText($file.FullName) | ConvertFrom-Json
            if ($manifest.name -cne 'ps-ai' -or -not $manifest.version) { continue }
            $version = [System.Management.Automation.SemanticVersion]$manifest.version
        } catch {
            # An interrupted install can leave an incomplete manifest beside a working version.
            continue
        }
        if ($null -eq $highest -or $version -gt $highest) {
            $highest = $version
            $versionText = [string]$manifest.version
        }
    }
    return $versionText
}
