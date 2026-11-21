param(
    [string]$Repo = (Get-Location).Path,
    [string]$HomeRoot = $HOME,
    [switch]$NoRun
)

$ErrorActionPreference = 'Stop'
# Dot-sourcing the validator with -NoRun overwrites $NoRun, so preserve the caller's choice.
$statusNoRun = $NoRun
. (Join-Path $PSScriptRoot 'ps-ai-validate.ps1') -NoRun
. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/installed.ps1')
. (Join-Path $PSScriptRoot 'lib/commands.ps1')

function Write-StatusAccounts {
    param($Settings, [string]$HomeRoot)

    'accounts'
    foreach ($agent in $Settings.agents) {
        $folder = $agent.configDir
        if ($folder.StartsWith('~/') -or $folder.StartsWith('~\')) { $folder = Join-Path $HomeRoot $folder.Substring(2) }
        $tool = Get-LegionTool -Tool $agent.tool
        $version = Get-LegionInstalledVersion -ConfigDir $folder -Tool $tool
        if (-not $version) { $version = 'missing' }
        "  $($agent.id)  $($agent.tool)  $($agent.configDir)  ps-ai $version"
    }
}

function Write-StatusCommands {
    param([string]$Bin)

    $commands = Get-LegionOwnerCommands
    $missing = @()
    $blocked = @()
    $stale = @()
    $permissions = @()
    foreach ($name in $commands.Keys) {
        $files = @($name)
        if ($IsWindows) { $files += "$name.cmd" }
        $states = @($files | ForEach-Object { Get-LegionOwnerCommandState -Path (Join-Path $Bin $_) -Script $commands[$name] })
        if ($states -contains 'blocked') { $blocked += $name }
        elseif ($states -contains 'missing') { $missing += $name }
        elseif ($states -contains 'stale') { $stale += $name }
        elseif (@($files | Where-Object { -not (Test-LegionLauncherExecutable -Path (Join-Path $Bin $_)) }).Count) { $permissions += $name }
    }
    if ($blocked.Count) { 'commands: blocked ' + ($blocked -join ', ') }
    if ($missing.Count) { 'commands: missing ' + ($missing -join ', ') }
    if ($stale.Count) { 'commands: stale ' + ($stale -join ', ') }
    if ($permissions.Count) { 'commands: not executable ' + ($permissions -join ', ') }
    if (-not $blocked.Count -and -not $missing.Count -and -not $stale.Count -and -not $permissions.Count) { 'commands: yes' }
}

function Write-StatusRepository {
    param([string]$Repo)

    $legion = Get-LegionRepoPath -Repo $Repo -Path ''
    foreach ($file in @('configuration/project.json', 'configuration/workflow.md', 'scripts/index.md')) {
        if (-not (Test-Path -LiteralPath (Join-Path $legion $file) -PathType Leaf)) { 'repo none'; return }
    }
    # Private orchestration owns an inner Git history; Shared uses the code repository's history.
    $mode = if (Test-Path -LiteralPath (Join-Path $legion '.git')) { 'Private' } else { 'Shared' }
    $gitRoot = if ($mode -eq 'Private') { $legion } else { $Repo }
    $required = @('configuration/project.json', 'configuration/workflow.md', 'scripts/index.md')
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
if (-not $statusNoRun) {
    $file = Get-LegionHomePath -HomeRoot $HomeRoot -Path 'configuration/ps-ai-personalisation.json'
    $settings = $null
    if (Test-Path -LiteralPath $file -PathType Leaf) {
        $settings = Read-LegionJson -Path $file
        Write-StatusAccounts -Settings $settings -HomeRoot $HomeRoot
    } else { 'no ps-ai settings yet' }
    $bin = Get-LegionHomePath -HomeRoot $HomeRoot -Path 'bin'
    $onPath = if (Test-LegionPathEntry -Path $env:PATH -Folder $bin) { 'yes' } else { 'no' }
    "path ~/.legion/bin on PATH: $onPath"
    Write-StatusCommands -Bin $bin
    foreach ($channel in $settings.channels) {
        "channels $($channel.id) ($($channel.kind)) -> $($channel.accounts -join ', ')"
    }
    Write-StatusRepository -Repo $Repo
}
