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

function Test-StatusPathEntry {
    param([string]$Folder)

    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    $separators = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $folderPath = $Folder.TrimEnd($separators)
    foreach ($entry in ($env:PATH -split [IO.Path]::PathSeparator)) {
        if ($entry -and [string]::Equals($folderPath, $entry.TrimEnd($separators), $comparison)) { return $true }
    }
    return $false
}

function Write-StatusAccounts {
    param($Settings, [string]$HomeRoot)

    'accounts'
    foreach ($agent in $Settings.agents) {
        $folder = $agent.configDir
        if ($folder.StartsWith('~/') -or $folder.StartsWith('~\')) { $folder = Join-Path $HomeRoot $folder.Substring(2) }
        $tool = Get-PsAiTool -Tool $agent.tool
        $version = Get-PsAiInstalledVersion -ConfigDir $folder -Tool $tool
        if (-not $version) { $version = 'missing' }
        "  $($agent.id)  $($agent.tool)  $($agent.configDir)  ps-ai $version"
    }
}

function Write-StatusCommands {
    param([string]$Bin)

    $commands = Get-PsAiOwnerCommands
    $missing = @()
    $blocked = @()
    foreach ($name in $commands.Keys) {
        $absent = $false
        $conflict = $false
        $files = @($name)
        if ($IsWindows) { $files += "$name.cmd" }
        foreach ($file in $files) {
            $path = Join-Path $Bin $file
            if (-not (Test-Path -LiteralPath $path)) { $absent = $true }
            elseif (-not (Test-PsAiOwnerCommandFile -Path $path -Script $commands[$name])) { $conflict = $true }
        }
        if ($conflict) { $blocked += $name }
        elseif ($absent) { $missing += $name }
    }
    if ($blocked.Count) { 'commands: blocked ' + ($blocked -join ', ') }
    if ($missing.Count) { 'commands: missing ' + ($missing -join ', ') }
    if (-not $blocked.Count -and -not $missing.Count) { 'commands: yes' }
}

function Write-StatusRepository {
    param([string]$Repo)

    $legion = Get-PsAiRepoPath -Repo $Repo -Path ''
    if (-not (Test-Path -LiteralPath $legion -PathType Container)) { 'repo none'; return }
    # Private orchestration owns an inner Git history; Shared uses the code repository's history.
    $mode = if (Test-Path -LiteralPath (Join-Path $legion '.git')) { 'Private' } else { 'Shared' }
    $lease = Get-PsAiLease -Repo $Repo
    $handoff = if (Test-Path -LiteralPath (Join-Path $legion 'state/handoff.md') -PathType Leaf) { 'yes' } else { 'no' }
    "repo $mode   lease: $($lease.State)   handoff: $handoff"
}

# Main: inspect settings, commands and repository without starting a CLI or changing files.
if (-not $statusNoRun) {
    $file = Get-PsAiHomePath -HomeRoot $HomeRoot -Path 'configuration/ps-ai-personalisation.json'
    $settings = $null
    if (Test-Path -LiteralPath $file -PathType Leaf) {
        $settings = Read-PsAiJson -Path $file
        Write-StatusAccounts -Settings $settings -HomeRoot $HomeRoot
    } else { 'no ps-ai settings yet' }
    $bin = Get-PsAiHomePath -HomeRoot $HomeRoot -Path 'bin'
    $onPath = if (Test-StatusPathEntry -Folder $bin) { 'yes' } else { 'no' }
    "path ~/.legion/bin on PATH: $onPath"
    Write-StatusCommands -Bin $bin
    foreach ($channel in $settings.channels) {
        "channels $($channel.id) ($($channel.kind)) -> $($channel.accounts -join ', ')"
    }
    Write-StatusRepository -Repo $Repo
}
