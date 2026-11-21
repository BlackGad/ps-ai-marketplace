$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$setup = Join-Path $root 'plugins/legion/bin/legion-repository.ps1'
$sandbox = Join-Path $root ('.agents/temp/repository-review-' + [guid]::NewGuid().ToString('N'))
$savedEnv = @{}
foreach ($name in @('GIT_CONFIG_GLOBAL', 'GIT_CONFIG_NOSYSTEM')) {
    $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

function New-ReviewRepo {
    param([string]$Name)
    $repo = Join-Path $sandbox $Name
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    git init --quiet $repo
    git -C $repo config user.name 'Fixture Owner'
    git -C $repo config user.email 'fixture@example.invalid'
    'rules' | Set-Content (Join-Path $repo 'AGENTS.md')
    git -C $repo add .
    git -C $repo commit --quiet -m 'Fixture'
    Assert-Equal 0 $LASTEXITCODE 'Fixture committed'
    return $repo
}

function Get-ThrownMessage {
    param([scriptblock]$Action)
    try { & $Action | Out-Null } catch { return $_.Exception.Message }
    return ''
}

New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
try {
    $env:GIT_CONFIG_GLOBAL = Join-Path $sandbox 'gitconfig'
    $env:GIT_CONFIG_NOSYSTEM = '1'

    # D1: after a failed commit, a repeat commits the files that are still untracked.
    $repo = New-ReviewRepo 'failed-commit'
    $hook = Join-Path $repo '.git/hooks/pre-commit'
    New-Item -ItemType Directory -Path (Split-Path $hook -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($hook, "#!/bin/sh`nexit 1`n")
    # Git runs a hook on Unix only when it is executable.
    if (-not $IsWindows) { chmod +x $hook }
    $message = Get-ThrownMessage { & $setup -Repo $repo -Mode Shared }
    Assert-True ($message -like '*Cannot commit setup files*') 'The commit failure is reported'
    Remove-Item -LiteralPath $hook
    $repeat = @(& $setup -Repo $repo -Mode Shared)
    Assert-Equal 'prepared: Shared orchestration' $repeat[-1] 'The repeat after a failed commit does not say already done'
    Assert-Equal '' ((git -C $repo status --porcelain) -join "`n") 'The repeat commits every setup file'

    # N1: a repeat never commits the owner's unrelated uncommitted edits.
    foreach ($mode in @('Shared', 'Private')) {
        $repo = New-ReviewRepo "owner-edits-$mode"
        & $setup -Repo $repo -Mode $mode | Out-Null
        $ownerFiles = @('.legion/state/handoff.md')
        if ($mode -eq 'Shared') { $ownerFiles += @('AGENTS.md', '.gitignore') }
        foreach ($file in $ownerFiles) { Add-Content -LiteralPath (Join-Path $repo $file) -Value 'owner edit' }
        $repeat = @(& $setup -Repo $repo -Mode $mode)
        Assert-Equal "skip: $mode orchestration (already done)" $repeat[-1] "$mode repeat leaves owner edits alone"
        $dirty = @(git -C $repo status --porcelain -- $ownerFiles) + @(git -C (Join-Path $repo '.legion') status --porcelain -- state/handoff.md)
        Assert-True ($dirty.Count -ge $ownerFiles.Count) "$mode owner edits stay uncommitted"
    }

    # D2: a rules file outside the repository is refused.
    $repo = New-ReviewRepo 'rules-outside'
    foreach ($outside in @('../outside.md', (Join-Path $sandbox 'outside.md'))) {
        $message = Get-ThrownMessage { & $setup -Repo $repo -Mode Shared -RulesFile $outside }
        Assert-True ($message -like '*inside the repository*') "RulesFile '$outside' is refused"
    }
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $sandbox 'outside.md'))) 'Nothing is written outside the repository'

    # D3: a tracked setup file the owner deleted is not recreated over the deletion.
    foreach ($mode in @('Shared', 'Private')) {
        $repo = New-ReviewRepo "deleted-$mode"
        & $setup -Repo $repo -Mode $mode | Out-Null
        $deleted = Join-Path $repo '.legion/configuration/project.json'
        Remove-Item -LiteralPath $deleted
        $message = Get-ThrownMessage { & $setup -Repo $repo -Mode $mode }
        Assert-True ($message -like '*project.json*') "$mode refuses to recreate a deleted tracked file"
        Assert-True (-not (Test-Path -LiteralPath $deleted)) "$mode leaves the deletion in place"
    }

    # D4: a changed -Gate is reported, not silently ignored.
    $repo = New-ReviewRepo 'gate-changed'
    & $setup -Repo $repo -Gate 'echo first' | Out-Null
    $gatePath = Join-Path $repo '.legion/scripts/check-task.ps1'
    $before = [IO.File]::ReadAllText($gatePath)
    $repeat = @(& $setup -Repo $repo -Gate 'echo second')
    Assert-Equal $before ([IO.File]::ReadAllText($gatePath)) 'A changed gate leaves the script alone'
    Assert-True (@($repeat | Where-Object { $_ -like 'skip: .legion/scripts/check-task.ps1*-Gate*' }).Count -eq 1) 'A changed gate is reported'

    # D4: without a gate the index does not advertise check-task.ps1.
    $repo = New-ReviewRepo 'no-gate'
    & $setup -Repo $repo | Out-Null
    $index = [IO.File]::ReadAllText((Join-Path $repo '.legion/scripts/index.md'))
    Assert-True (-not $index.Contains('check-task.ps1')) 'No gate: the index lists no check-task.ps1'

    # D4: a failing PowerShell cmdlet makes the gate exit nonzero.
    $repo = New-ReviewRepo 'gate-cmdlet'
    & $setup -Repo $repo -Gate 'Get-Item -LiteralPath ./missing-for-gate' | Out-Null
    & pwsh -NoProfile -File (Join-Path $repo '.legion/scripts/check-task.ps1') 2>&1 | Out-Null
    Assert-True ($LASTEXITCODE -ne 0) 'A failing cmdlet gate exits nonzero'

    # K2: a rules file that is a link, or sits under a linked folder, is refused before anything is written.
    $outside = Join-Path $sandbox 'outside-target'
    New-Item -ItemType Directory -Path $outside -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $outside 'RULES.md'), 'outside')
    $linkCases = @(
        @{ Name = 'file link'; RulesFile = 'RULES.md'; LinkPath = 'RULES.md'; Type = 'SymbolicLink'; Target = (Join-Path $outside 'RULES.md') },
        @{ Name = 'folder link'; RulesFile = 'docs/RULES.md'; LinkPath = 'docs'; Type = $(if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }); Target = $outside }
    )
    foreach ($case in $linkCases) {
        $repo = New-ReviewRepo "link-$($case.Name -replace ' ', '-')"
        try { New-Item -ItemType $case.Type -Path (Join-Path $repo $case.LinkPath) -Target $case.Target -ErrorAction Stop | Out-Null }
        catch { Write-Host "skip K2 $($case.Name): cannot create a link here"; continue }
        $message = Get-ThrownMessage { & $setup -Repo $repo -Mode Shared -RulesFile $case.RulesFile }
        Assert-True ($message -like '*link*') "K2 $($case.Name): the rules file is refused"
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $repo '.legion'))) "K2 $($case.Name): nothing is written"
        Assert-Equal 'outside' ([IO.File]::ReadAllText((Join-Path $outside 'RULES.md'))) "K2 $($case.Name): the target is untouched"
    }

    # K2: a staged rename of a scaffold file is not recreated at its source.
    $repo = New-ReviewRepo 'staged-rename'
    & $setup -Repo $repo -Mode Shared | Out-Null
    git -C $repo mv .legion/configuration/project.json .legion/configuration/moved.json
    $message = Get-ThrownMessage { & $setup -Repo $repo -Mode Shared }
    Assert-True ($message -like '*project.json*') 'K2: a staged rename of a setup file is refused'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $repo '.legion/configuration/project.json'))) 'K2: the rename source is not recreated'

    # G4: a partial setup builds the index from the gate that exists and reports the kept files.
    $repo = New-ReviewRepo 'partial'
    & $setup -Repo $repo -Mode Shared -Gate 'echo kept-gate' | Out-Null
    git -C $repo rm -q .legion/scripts/index.md
    git -C $repo commit -q -m 'Drop index'
    $repeat = @(& $setup -Repo $repo -Mode Shared)
    $index = [IO.File]::ReadAllText((Join-Path $repo '.legion/scripts/index.md'))
    Assert-True ($index.Contains('echo kept-gate')) 'G4: the new index has the row of the existing gate'
    Assert-True ($repeat -contains 'skip: .legion/scripts/check-task.ps1 (already done)') 'G4: a partial setup reports a kept file'
    $full = @(& $setup -Repo $repo -Mode Shared)
    Assert-Equal 1 $full.Count 'G4: a full repeat prints one line'
} finally {
    foreach ($name in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnv[$name], 'Process') }
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}
