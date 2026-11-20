# Static checks for GitHub workflow files, read as plain text (no YAML module).
# Assumes two-space indent: jobs at 2 spaces under `jobs:`, job keys at 4.

function Get-WorkflowJobBlocks {
    param([string]$Path)
    $blocks = @()
    $inJobs = $false
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^jobs:\s*$') { $inJobs = $true; continue }
        if (-not $inJobs) { continue }
        if ($line -match '^\S' -and $line -notmatch '^#') { $inJobs = $false; continue }
        if ($line -match '^  ([A-Za-z0-9_-]+):\s*$') {
            $blocks += [pscustomobject]@{ Id = $Matches[1]; Name = $Matches[1]; Lines = @() }
        } elseif ($blocks.Count -gt 0) {
            $blocks[-1].Lines += $line
            if ($line -match '^    name:\s*(.+?)\s*$') {
                $blocks[-1].Name = $Matches[1].Trim("'" + '"')
            }
        }
    }
    $blocks
}

function Get-WorkflowJobIds {
    param([string]$Path)
    @(Get-WorkflowJobBlocks -Path $Path | ForEach-Object { $_.Id })
}

function Get-WorkflowProblems {
    param([string]$Path)
    $problems = @()
    $lines = @(Get-Content -LiteralPath $Path)

    foreach ($line in $lines) {
        if ($line -notmatch '^\s*(-\s+)?uses:\s*(.+?)\s*$') { continue }
        $value = $Matches[2]
        $isLocal = $value -match '^\./'
        $isPinned = $value -match '^[\w.-]+/[\w.-]+(/[^@\s]+)?@[0-9a-f]{40}\s+#\s*v\S*'
        if (-not $isLocal -and -not $isPinned) { $problems += "uses '$value' is not pinned" }
    }

    if (-not ($lines -match '^permissions:')) { $problems += 'no top-level permissions' }

    foreach ($job in Get-WorkflowJobBlocks -Path $Path) {
        $callsReusable = $job.Lines -match '^    uses:'
        $hasTimeout = $job.Lines -match '^    timeout-minutes:'
        if (-not $callsReusable -and -not $hasTimeout) { $problems += "job '$($job.Id)' has no timeout-minutes" }
    }
    $problems
}
