param(
    [ValidateSet('text', 'context-json')][string]$Format = 'text',
    [string]$Repo = (Get-Location).Path,
    [hashtable]$Environment,
    [switch]$NoRun
)

. (Join-Path $PSScriptRoot '../bin/lib/common.ps1')

function Find-LegionRepoRoot {
    param([string]$Path)
    $current = $Path
    while ($current) {
        if (Test-Path -LiteralPath (Get-LegionRepoPath -Repo $current -Path 'state')) { return $current }
        if (Test-Path -LiteralPath (Join-Path $current '.git')) { return $current }
        $current = Split-Path $current -Parent
    }
    return $Path
}

function Get-LegionMode {
    param([string]$Repo, [hashtable]$Environment)
    if ($null -eq $Environment) {
        $Environment = @{ LEGION_ROLE = $env:LEGION_ROLE; LEGION_TASK = $env:LEGION_TASK }
    }
    if ($Environment.LEGION_ROLE -eq 'member') {
        if (-not $Environment.LEGION_TASK) {
            return [pscustomobject]@{
                Mode = 'none'; Task = $null; Lease = 'free'
                Text = 'legion: LEGION_ROLE=member without LEGION_TASK; ignored.'
            }
        }
        $task = [string]$Environment.LEGION_TASK
        $message = 'legion: you are a legion member. Load the legion-member skill to read your task from LEGION_TASK and follow it. '
        $message += 'Do not load legion-overseer. A summoned unit cannot summon: never start other agents.'
        return [pscustomobject]@{ Mode = 'member'; Task = $task; Lease = 'free'; Text = $message }
    }
    $Repo = Find-LegionRepoRoot -Path $Repo
    $handoff = Get-LegionRepoPath -Repo $Repo -Path 'state/handoff.md'
    if (-not (Test-Path -LiteralPath $handoff)) {
        return [pscustomobject]@{ Mode = 'none'; Task = $null; Lease = 'free'; Text = '' }
    }
    $lease = Get-LegionLease -Repo $Repo
    $message = 'legion: this repo is orchestrated. Say continue to act as the overseer.'
    if ($lease.State -eq 'held') {
        $message += ' Another overseer is active.'
    } elseif ($lease.State -eq 'foreign') {
        $message += ' An overseer lease from another host exists; ask the owner before taking over.'
    }
    try {
        . (Join-Path $PSScriptRoot '../bin/legion-update.ps1') -NoRun
        $update = Get-LegionUpdate
        if ($update.Newer) {
            $message += "`nlegion $($update.Available) is available (installed $($update.Installed)); say `"update legion`" to update."
        }
    } catch { } # Update failures must preserve the existing mode context.
    return [pscustomobject]@{ Mode = 'orchestrated'; Task = $null; Lease = $lease.State; Text = $message }
}

function Get-LegionHookCwd {
    # Hook runners pass the session as JSON on stdin; its cwd is the session folder, which may differ from ours.
    param([string]$InputText)
    if (-not $InputText) { return $null }
    try { return (ConvertFrom-Json -InputObject $InputText -ErrorAction Stop).cwd } catch { return $null }
}

if (-not $NoRun) {
    try {
        if (-not $PSBoundParameters.ContainsKey('Repo') -and [Console]::IsInputRedirected) {
            $hookCwd = Get-LegionHookCwd -InputText ([Console]::In.ReadToEnd())
            if ($hookCwd -and (Test-Path -LiteralPath $hookCwd)) { $Repo = $hookCwd }
        }
        $mode = Get-LegionMode -Repo $Repo -Environment $Environment
        if ($Format -eq 'context-json') {
            if ($mode.Text) { @{ additionalContext = $mode.Text } | ConvertTo-Json -Compress }
            else { '{}' }
        } elseif ($mode.Text) { $mode.Text }
    } catch {
        $warning = 'legion: mode detection failed; continuing without mode context.'
        if ($Format -eq 'context-json') { @{ additionalContext = $warning } | ConvertTo-Json -Compress }
        else { $warning }
    }
}
