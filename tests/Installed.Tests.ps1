$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$library = Join-Path $root 'plugins/ps-ai/bin/lib/installed.ps1'
Assert-True (Test-Path -LiteralPath $library) 'Installed-version library exists'
. $library
. (Join-Path $root 'plugins/ps-ai/bin/lib/tools.ps1')

function Write-InstalledTestManifest {
    param([string]$Folder, [string]$Name = 'ps-ai', [string]$Version = '0.6.0')
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    @{ name = $Name; version = $Version } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Folder 'plugin.json')
}

$scratch = Join-Path $root ('.agents/temp/installed-' + [guid]::NewGuid().ToString('N'))
$claude = Get-PsAiTool -Tool claude
$copilot = Get-PsAiTool -Tool copilot
Assert-Equal $null (Get-PsAiInstalledVersion -ConfigDir $scratch -Tool $claude) 'No installed version'
$cache = Join-Path $scratch $claude.plugin.installedRoot
Write-InstalledTestManifest -Folder (Join-Path $cache '0.6.0')
Assert-Equal '0.6.0' (Get-PsAiInstalledVersion -ConfigDir $scratch -Tool $claude) 'One installed version'
Write-InstalledTestManifest -Folder (Join-Path $cache '0.10.0') -Version '0.10.0'
Assert-Equal '0.10.0' (Get-PsAiInstalledVersion -ConfigDir $scratch -Tool $claude) 'Highest version uses version ordering'
Write-InstalledTestManifest -Folder (Join-Path $cache 'other/ps-ai') -Name other-plugin -Version '99.0.0'
Assert-Equal '0.10.0' (Get-PsAiInstalledVersion -ConfigDir $scratch -Tool $claude) 'Same-named folder with another plugin is ignored'
Write-InstalledTestManifest -Folder (Join-Path $cache 'unversioned') -Version ''
New-Item -ItemType Directory -Path (Join-Path $cache 'broken') -Force | Out-Null
'not JSON' | Set-Content -LiteralPath (Join-Path $cache 'broken/plugin.json')
Assert-Equal '0.10.0' (Get-PsAiInstalledVersion -ConfigDir $scratch -Tool $claude) 'Incomplete manifests do not hide valid installs'
$copilotCache = Join-Path $scratch $copilot.plugin.installedRoot
Write-InstalledTestManifest -Folder (Join-Path $copilotCache 'ps-ai-marketplace/ps-ai')
Write-InstalledTestManifest -Folder (Join-Path $copilotCache 'other-marketplace/ps-ai') -Name other-plugin -Version '99.0.0'
Assert-Equal '0.6.0' (Get-PsAiInstalledVersion -ConfigDir $scratch -Tool $copilot) 'Copilot installed-plugins layout'

# Copilot loads directory marketplaces live; no installed-plugins copy is created.
$localConfig = Join-Path $scratch 'local-account'
$marketplace = Join-Path $scratch 'local-marketplace'
$localPlugin = Join-Path $marketplace 'extensions/orchestration'
New-Item -ItemType Directory -Path $localConfig, (Join-Path $marketplace '.claude-plugin') -Force | Out-Null
Write-InstalledTestManifest -Folder $localPlugin -Version '0.7.0'
@{ plugins = @(@{ name = 'ps-ai'; source = './extensions/orchestration' }) } | ConvertTo-Json -Depth 10 |
    Set-Content -LiteralPath (Join-Path $marketplace '.claude-plugin/marketplace.json')
$settings = @{
    extraKnownMarketplaces = @{ 'ps-ai-marketplace' = @{ source = @{ source = 'directory'; path = $marketplace } } }
    enabledPlugins = @{ 'ps-ai@ps-ai-marketplace' = $true }
}
$settingsPath = Join-Path $localConfig 'settings.json'
$settings | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $settingsPath
Assert-Equal '0.7.0' (Get-PsAiInstalledVersion -ConfigDir $localConfig -Tool $copilot) 'Copilot live plugin version comes from the registered marketplace source'
Assert-Equal $null (Get-PsAiInstalledVersion -ConfigDir $localConfig -Tool $claude) 'Other tools do not use Copilot settings'
Write-InstalledTestManifest -Folder (Join-Path $localConfig 'installed-plugins/old/ps-ai') -Version '0.9.0'
Assert-Equal '0.7.0' (Get-PsAiInstalledVersion -ConfigDir $localConfig -Tool $copilot) 'Live source takes precedence over old copied installs'
$settings.enabledPlugins.Clear()
$settings | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $settingsPath
Remove-Item -LiteralPath (Join-Path $localConfig 'installed-plugins') -Recurse -Force
Assert-Equal $null (Get-PsAiInstalledVersion -ConfigDir $localConfig -Tool $copilot) 'A registered marketplace alone is not an installed plugin'
$settings.enabledPlugins['ps-ai@ps-ai-marketplace'] = $false
$settings | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $settingsPath
Assert-Equal '0.7.0' (Get-PsAiInstalledVersion -ConfigDir $localConfig -Tool $copilot) 'Disabled live plugins remain installed'
'invalid JSON' | Set-Content -LiteralPath $settingsPath
Assert-Equal $null (Get-PsAiInstalledVersion -ConfigDir $localConfig -Tool $copilot) 'Incomplete Copilot settings do not break version detection'
