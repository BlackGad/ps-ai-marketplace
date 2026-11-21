param()

$ErrorActionPreference = 'Stop'

function Get-LegionCopilotLocalManifest {
    param([string]$ConfigDir)

    try {
        $settings = [IO.File]::ReadAllText((Join-Path $ConfigDir 'settings.json')) | ConvertFrom-Json
        if ($settings.enabledPlugins.PSObject.Properties.Name -cnotcontains 'ps-ai@ps-ai-marketplace') { return $null }
        $source = $settings.extraKnownMarketplaces.'ps-ai-marketplace'.source
        if ($source.source -cne 'directory' -or -not $source.path) { return $null }
        $marketplace = [IO.File]::ReadAllText((Join-Path $source.path '.claude-plugin/marketplace.json')) | ConvertFrom-Json
        foreach ($plugin in $marketplace.plugins) {
            if ($plugin.name -ceq 'ps-ai' -and $plugin.source -is [string]) {
                return Join-Path (Join-Path $source.path $plugin.source) 'plugin.json'
            }
        }
    } catch {
        # Missing or incomplete directory registrations are not installed copies.
    }
    return $null
}

function Get-LegionInstalledVersion {
    param([string]$ConfigDir, $Tool)

    $cache = Join-Path $ConfigDir $Tool.plugin.installedRoot
    $files = @()
    if (Test-Path -LiteralPath $cache -PathType Container) {
        $files = @(Get-ChildItem -LiteralPath $cache -Filter plugin.json -File -Recurse | ForEach-Object FullName)
    }
    if ($Tool.id -ceq 'copilot') {
        $localManifest = Get-LegionCopilotLocalManifest -ConfigDir $ConfigDir
        if ($localManifest) { $files = @($localManifest) }
    }
    $highest = $null
    $versionText = $null
    foreach ($file in $files) {
        try {
            $manifest = [IO.File]::ReadAllText($file) | ConvertFrom-Json
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
