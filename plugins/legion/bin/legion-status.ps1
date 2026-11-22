param(
    [string]$Repo = (Get-Location).Path,
    [string]$HomeRoot = $HOME,
    [switch]$NoRun
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/settings.ps1')
. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/installed.ps1')
. (Join-Path $PSScriptRoot 'lib/commands.ps1')

function Write-StatusAccounts {
    param($Settings, [string]$HomeRoot)

    'accounts'
    foreach ($agent in $Settings.agents) {
        $folder = Resolve-LegionHomePath -Path $agent.configDir -HomeRoot $HomeRoot
        $tool = Get-LegionTool -Tool $agent.tool
        $version = Get-LegionInstalledVersion -ConfigDir $folder -Tool $tool
        if (-not $version) { $version = 'missing' }
        "  $($agent.id)  $($agent.tool)  $($agent.configDir)  legion $version"
    }
}

function Write-StatusCommands {
    param([string]$Bin, [string]$HomeRoot)

    $rows = @(Get-LegionCommandState -Bin $Bin -HomeRoot $HomeRoot)
    $labels = [ordered]@{ blocked = 'blocked'; missing = 'missing'; permission = 'not executable' }
    # Each command is reported once, under its most serious state.
    $worst = @{}
    foreach ($name in ($rows.Name | Select-Object -Unique)) {
        $worst[$name] = @($labels.Keys | Where-Object { $_ -in @($rows | Where-Object Name -EQ $name).State })[0]
    }
    $reported = $false
    foreach ($state in $labels.Keys) {
        $names = @($worst.Keys | Where-Object { $worst[$_] -eq $state })
        if ($names.Count) { 'commands: ' + $labels[$state] + ' ' + ($names -join ', '); $reported = $true }
    }
    if (-not $reported) { 'commands: yes' }
}

function Write-StatusRepository {
    param([string]$Repo)

    $legion = Get-LegionRepoPath -Repo $Repo -Path ''
    $required = @('configuration/project.json', 'configuration/workflow.md', 'scripts/index.md')
    foreach ($file in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $legion $file) -PathType Leaf)) { 'repo none'; return }
    }
    # Private orchestration owns an inner Git history; Shared uses the code repository's history.
    $mode = if (Test-Path -LiteralPath (Join-Path $legion '.git')) { 'Private' } else { 'Shared' }
    $gitRoot = if ($mode -eq 'Private') { $legion } else { $Repo }
    $paths = if ($mode -eq 'Private') { $required } else { @($required | ForEach-Object { ".legion/$_" }) }
    $previousExit = $global:LASTEXITCODE
    try {
        & git -C $gitRoot ls-files --error-unmatch -- @paths 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { 'repo none'; return }
    } catch { 'repo none'; return }
    finally { $global:LASTEXITCODE = $previousExit }
    $lease = Get-LegionLease -Repo $Repo
    $handoff = if (Test-Path -LiteralPath (Join-Path $legion 'state/handoff.md') -PathType Leaf) { 'yes' } else { 'no' }
    "repo $mode   lease: $($lease.State)   handoff: $handoff"
}

# Main: inspect settings, commands and repository without starting a CLI or changing files.
if (-not $NoRun) {
    $file = Get-LegionOwnerPath -HomeRoot $HomeRoot -Name Settings
    $settings = $null
    if (Test-Path -LiteralPath $file -PathType Leaf) {
        $settings = Read-LegionJson -Path $file
        Write-StatusAccounts -Settings $settings -HomeRoot $HomeRoot
    } else { 'no legion settings yet' }
    $bin = Get-LegionHomePath -HomeRoot $HomeRoot -Path 'bin'
    $onPath = if (Test-LegionPathEntry -Path $env:PATH -Folder $bin) { 'yes' } else { 'no' }
    "path ~/.legion/bin on PATH: $onPath"
    Write-StatusCommands -Bin $bin -HomeRoot $HomeRoot
    foreach ($channel in $settings.channels) {
        "channels $($channel.id) ($($channel.kind)) -> $($channel.accounts -join ', ')"
    }
    Write-StatusRepository -Repo $Repo
}
