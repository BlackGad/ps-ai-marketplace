param(
    [ValidateSet('text', 'context-json')][string]$Format = 'text',
    [string]$Repo = (Get-Location).Path,
    [hashtable]$Environment,
    [switch]$NoRun
)

. (Join-Path $PSScriptRoot '../bin/PsAi.Common.ps1')

function Get-PsAiHandoffLine {
    param([string]$Content, [string]$Heading)
    $match = [regex]::Match($Content, "(?m)^## $([regex]::Escape($Heading))\s*\r?\n([^\r\n]*)")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ''
}

function Find-PsAiRepoRoot {
    param([string]$Path)
    $current = $Path
    while ($current) {
        if (Test-Path -LiteralPath (Join-Path $current '.agents/state')) { return $current }
        if (Test-Path -LiteralPath (Join-Path $current '.git')) { return $current }
        $current = Split-Path $current -Parent
    }
    return $Path
}

function Get-PsAiMode {
    param([string]$Repo, [hashtable]$Environment)
    if ($null -eq $Environment) {
        $Environment = @{ PS_AI_ROLE = $env:PS_AI_ROLE; PS_AI_TASK = $env:PS_AI_TASK }
    }
    if ($Environment.PS_AI_ROLE -eq 'legion') {
        if (-not $Environment.PS_AI_TASK) {
            return [pscustomobject]@{
                Mode = 'none'; Task = $null; Lease = 'free'
                Text = 'ps-ai: PS_AI_ROLE=legion without PS_AI_TASK; ignored.'
            }
        }
        $task = [string]$Environment.PS_AI_TASK
        $message = "ps-ai: you are a legion member. Your task: $task. Load the ps-ai-legion skill and follow it. "
        $message += 'Do not load ps-ai-overseer. A summoned unit cannot summon: never start other agents.'
        return [pscustomobject]@{ Mode = 'legion'; Task = $task; Lease = 'free'; Text = $message }
    }
    $Repo = Find-PsAiRepoRoot -Path $Repo
    $handoff = Join-Path $Repo '.agents/state/handoff.md'
    if (-not (Test-Path -LiteralPath $handoff)) {
        return [pscustomobject]@{ Mode = 'none'; Task = $null; Lease = 'free'; Text = '' }
    }
    $content = Get-Content -Raw -LiteralPath $handoff
    $milestone = Get-PsAiHandoffLine -Content $content -Heading 'Milestone'
    $task = Get-PsAiHandoffLine -Content $content -Heading 'Current task'
    $lease = Get-PsAiLease -Repo $Repo
    $message = "ps-ai: this repo is orchestrated ($milestone; $task). Say continue to act as the overseer."
    if ($lease.State -eq 'held') {
        $message += " Another overseer is active ($($lease.Data.tool), $($lease.Data.account), since $($lease.Data.startedAt))."
    } elseif ($lease.State -eq 'foreign') {
        $message += " An overseer lease from host $($lease.Data.host) exists; ask the owner before taking over."
    }
    try {
        . (Join-Path $PSScriptRoot '../bin/ps-ai-update.ps1') -NoRun
        $update = Get-PsAiUpdate
        if ($update.Newer) {
            $message += "`nps-ai $($update.Available) is available (installed $($update.Installed)); say `"update ps-ai`" to update."
        }
    } catch { } # Update failures must preserve the existing mode context.
    return [pscustomobject]@{ Mode = 'orchestrated'; Task = $null; Lease = $lease.State; Text = $message }
}

function Get-PsAiHookCwd {
    # Hook runners pass the session as JSON on stdin; its cwd is the session folder, which may differ from ours.
    param([string]$InputText)
    if (-not $InputText) { return $null }
    try { return (ConvertFrom-Json -InputObject $InputText -ErrorAction Stop).cwd } catch { return $null }
}

if (-not $NoRun) {
    try {
        if (-not $PSBoundParameters.ContainsKey('Repo') -and [Console]::IsInputRedirected) {
            $hookCwd = Get-PsAiHookCwd -InputText ([Console]::In.ReadToEnd())
            if ($hookCwd -and (Test-Path -LiteralPath $hookCwd)) { $Repo = $hookCwd }
        }
        $mode = Get-PsAiMode -Repo $Repo -Environment $Environment
        if ($Format -eq 'context-json') {
            if ($mode.Text) { @{ additionalContext = $mode.Text } | ConvertTo-Json -Compress }
            else { '{}' }
        } elseif ($mode.Text) { $mode.Text }
    } catch {
        $warning = 'ps-ai: mode detection failed; continuing without mode context.'
        if ($Format -eq 'context-json') { @{ additionalContext = $warning } | ConvertTo-Json -Compress }
        else { $warning }
    }
}
