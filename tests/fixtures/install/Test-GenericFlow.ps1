param([string]$Installer, [string]$Catalog, [ValidateSet('fresh','cached','update','registered')][string]$Mode)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MarketplaceListing.ps1')
. ([scriptblock]::Create((Get-Content -LiteralPath $Installer -Raw))) -NoRun
$catalogText = Get-Content -LiteralPath $Catalog -Raw
$entries = ($catalogText | ConvertFrom-Json).tools
$fixtureHome = Split-Path $Catalog
$states = @{}
foreach ($entry in $entries) { $states[$entry.command] = @{Added=$false; Refreshed=$false; Installed=$false} }
. (Join-Path $PSScriptRoot 'InstallerSandbox.ps1') -InstallFixtureHome ($fixtureHome)
$fixturePlugin = New-InstallFixturePlugin -Path (Join-Path $fixtureHome 'installed')
function Get-InstallSourceText {
    param($Url)
    if ($Url -ne 'https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/stable/plugins/ps-ai/tools.json') { throw 'Unexpected catalog URL' }
    $catalogText
}
function Test-InstallCommandAvailable { param($Name) $Name -in @('claude','codex','copilot') }
function Invoke-InstallRefresh { 'fixture artifacts refreshed' }
function Invoke-ClosedInput {
    param($Command)
    $entry = $entries | Where-Object command -EQ $Command[0]
    if (-not $entry) { throw 'Unexpected fixture executable' }
    $state = $states[$entry.command]
    $line = $Command -join '|'
    if ($line -eq ((@($entry.command) + $entry.plugin.marketplaceList) -join '|')) {
        $source = if ($Mode -eq 'registered') { 'https://github.com/example/old-source' } else { '' }
        $output = @(Get-FixtureMarketplaceListing -Tool $entry.id -Source $source)
        return @{ExitCode=0; Output=$output}
    }
    if ($line -eq ((@($entry.command) + $entry.plugin.list) -join '|')) {
        $output = @()
        if ($Mode -in @('cached','update')) {
            if ($entry.id -eq 'claude') {
                $output = @'
[
  {
    "id": "ps-ai@ps-ai-marketplace",
    "version": "0.3.0",
    "scope": "user",
    "enabled": true
  }
]
'@ -split "`r?`n"
                $plugins = ($output -join "`n") | ConvertFrom-Json
                $plugins[0] | Add-Member installPath $fixturePlugin
                $output = @(ConvertTo-Json -InputObject @($plugins) -Depth 10)
            } else { $output = @("ps-ai@ps-ai-marketplace installed, enabled $fixturePlugin") }
        } elseif ($entry.id -eq 'claude') { $output = @('[]') }
        return @{ExitCode=0; Output=$output}
    }
    if ($line -eq ((Get-InstallCommands -Tool $entry.id -Source 'BlackGad/ps-ai-marketplace')[0] -join '|')) {
        $state.Added=$true
        return @{ExitCode=0; Output=@()}
    }
    if ($line -eq ((@($entry.command) + $entry.plugin.marketplaceUpdate) -join '|')) {
        if ($Mode -notin @('update','registered') -and -not $state.Added) { throw 'Refresh ran before add' }
        $state.Refreshed=$true
        return @{ExitCode=0; Output=@()}
    }
    $pluginArguments = if ($Mode -eq 'update') { $entry.plugin.update } else { $entry.plugin.install }
    if ($line -eq ((@($entry.command) + $pluginArguments) -join '|')) {
        if (-not $state.Refreshed) { throw 'Plugin install ran without marketplace refresh' }
        $state.Installed=$true
        return @{ExitCode=0; Output=@("fixture installed: $($entry.id)")}
    }
    throw "Unexpected fake command: $line"
}
# Reused registrations still refresh before plugin installation.
Invoke-PsAiInstaller -Yes -Update:($Mode -eq 'update')
foreach ($entry in $entries) {
    if (-not $states[$entry.command].Installed) { throw "Fixture plugin was skipped: $($entry.id)" }
}
"generic $Mode passed"
