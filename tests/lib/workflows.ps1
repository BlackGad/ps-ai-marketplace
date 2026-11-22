# Static checks for GitHub workflow files, read as plain text (no YAML module).
# Regex rules use the repository format: jobs at two spaces, job fields at four.

function Get-WorkflowJobBlocks {
    param([string]$Path)
    $text = Get-Content -LiteralPath $Path -Raw
    $jobs = [regex]::Match($text, '(?ms)^jobs:[ \t]*\r?\n(?<body>.*?)(?=^[^\s#]|\z)').Groups['body'].Value
    foreach ($job in [regex]::Matches($jobs, '(?ms)^  (?<id>[\w-]+):[ \t]*\r?\n(?<body>.*?)(?=^  [\w-]+:|\z)')) {
        $id = $job.Groups['id'].Value
        $body = $job.Groups['body'].Value
        $name = [regex]::Match($body, '(?m)^    name:[ \t]*(.+?)[ \t]*\r?$')
        [pscustomobject]@{ Id = $id; Name = $(if ($name.Success) { $name.Groups[1].Value.Trim("'" + '"') } else { $id }); Lines = @($body -split '\r?\n') }
    }
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
