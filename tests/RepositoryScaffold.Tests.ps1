$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$setup = Join-Path $root 'plugins/ps-ai/bin/legion-repository.ps1'
$sandbox = Join-Path $root ('.agents/temp/repository-scaffold-' + [guid]::NewGuid().ToString('N'))
$savedEnv = @{}
foreach ($name in @('GIT_CONFIG_GLOBAL', 'GIT_CONFIG_NOSYSTEM')) {
    $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

function New-ScaffoldRepo {
    param([string]$Name, [string[]]$RulesFiles = @('AGENTS.md'))
    $repo = Join-Path $sandbox $Name
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    git init --quiet $repo
    foreach ($file in $RulesFiles) { "rules in $file" | Set-Content (Join-Path $repo $file) }
    'code' | Set-Content (Join-Path $repo 'code.txt')
    git -C $repo add .
    git -C $repo commit --quiet -m 'Fixture'
    Assert-Equal 0 $LASTEXITCODE 'Fixture committed'
    return $repo
}

function Get-FileText {
    param([string]$Path)
    return [IO.File]::ReadAllText($Path)
}

New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
try {
    $env:GIT_CONFIG_GLOBAL = Join-Path $sandbox 'gitconfig'
    $env:GIT_CONFIG_NOSYSTEM = '1'
    "[user]`nname = Fixture`nemail = fixture@example.invalid`n[commit]`ngpgsign = false`n[init]`ndefaultBranch = main`n" |
        Set-Content -LiteralPath $env:GIT_CONFIG_GLOBAL

    # A fresh Private repo (its path has a space) gets all eight items, the filled choices, and one inner commit.
    $repo = New-ScaffoldRepo 'private fresh'
    $legion = Join-Path $repo '.legion'
    $output = @(& $setup -Repo $repo)
    Assert-Equal 'prepared: Private orchestration' $output[-1] 'Private setup ends with the prepared line'
    Assert-True ($output -contains 'created .legion/configuration/workflow.md') 'Setup lists what it created'
    foreach ($file in @('configuration/project.json', 'configuration/workflow.md', 'scripts/index.md', 'state/handoff.md', 'state/history/.gitkeep')) {
        Assert-True (Test-Path -LiteralPath (Join-Path $legion $file) -PathType Leaf) "Setup creates $file"
    }
    foreach ($folder in @('docs/specs', 'docs/plans', 'temp')) {
        Assert-True (Test-Path -LiteralPath (Join-Path $legion $folder) -PathType Container) "Setup creates $folder"
    }
    $workflow = Get-FileText (Join-Path $legion 'configuration/workflow.md')
    Assert-True ($workflow.Contains('Rules file: `AGENTS.md`')) 'Choices name the rules file'
    Assert-True ($workflow.Contains('.legion/docs/specs') -and $workflow.Contains('.legion/docs/plans')) 'Choices name the spec and plan paths'
    Assert-True ($workflow.Contains('Delivery: `merge-request`')) 'Choices name the delivery mode'
    Assert-True ($workflow.Contains('## legion orchestration')) 'Private keeps the rules block in workflow.md'
    Assert-True (-not $workflow.Contains('Gate:')) 'No gate line without -Gate'
    Assert-Equal '' ((git -C $legion status --porcelain) -join "`n") 'Private setup leaves the inner repo committed'
    Assert-Equal 'Set up ps-ai orchestration' (git -C $legion log -1 --format=%s) 'Private commit message'
    Assert-Equal '' ((git -C $repo status --porcelain) -join "`n") 'Private setup leaves the code repo clean'
    $repeat = @(& $setup -Repo $repo)
    Assert-Equal 1 $repeat.Count 'Repeat prints one line'
    Assert-Equal 'skip: Private orchestration (already done)' $repeat[0] 'Repeat skips'

    # -Gate writes the script, replaces the example row, and adds the workflow line.
    $repo = New-ScaffoldRepo 'gate'
    $legion = Join-Path $repo '.legion'
    $gate = 'pwsh -NoProfile -File tests/run.ps1'
    $output = @(& $setup -Repo $repo -Gate $gate)
    Assert-True ($output -contains "created .legion/scripts/check-task.ps1 (gate: $gate)") 'Setup names the gate command'
    $script = Get-FileText (Join-Path $legion 'scripts/check-task.ps1')
    Assert-True ($script.StartsWith('#')) 'Gate script starts with a comment header'
    Assert-True ($script -match "(?m)^$([regex]::Escape($gate))\r?$") 'Gate script runs the command'
    Assert-True ($script.TrimEnd().EndsWith('exit $LASTEXITCODE')) 'Gate script exits with the command code'
    $index = Get-FileText (Join-Path $legion 'scripts/index.md')
    Assert-True ($index.Contains('check-task.ps1') -and $index.Contains($gate)) 'Index row shows the gate'
    Assert-True (-not $index.Contains('Release build, analyzers')) 'Example index row is replaced'
    Assert-True ((Get-FileText (Join-Path $legion 'configuration/workflow.md')).Contains('Gate: `check-task.ps1`')) 'Workflow names the gate script'
    Assert-Equal 'skip: Private orchestration (already done)' (@(& $setup -Repo $repo -Gate $gate))[0] 'Gate repeat skips'

    # Existing files are byte-identical afterwards.
    $repo = New-ScaffoldRepo 'existing'
    $legion = Join-Path $repo '.legion'
    foreach ($folder in @('configuration', 'scripts')) { New-Item -ItemType Directory -Path (Join-Path $legion $folder) -Force | Out-Null }
    $kept = @{ 'configuration/workflow.md' = "my workflow`n"; 'scripts/check-task.ps1' = "exit 7`n" }
    foreach ($file in $kept.Keys) { [IO.File]::WriteAllText((Join-Path $legion $file), $kept[$file]) }
    & $setup -Repo $repo -Gate 'echo other' | Out-Null
    foreach ($file in $kept.Keys) {
        Assert-Equal $kept[$file] (Get-FileText (Join-Path $legion $file)) "Existing $file is untouched"
    }

    # Shared adds the rules block once, and commits only its paths.
    $repo = New-ScaffoldRepo 'shared'
    $legion = Join-Path $repo '.legion'
    & $setup -Repo $repo -Mode Shared | Out-Null
    $rules = Get-FileText (Join-Path $repo 'AGENTS.md')
    Assert-Equal 1 ([regex]::Matches($rules, '## legion orchestration')).Count 'Shared adds the rules block'
    Assert-True ($rules.StartsWith('rules in AGENTS.md')) 'Shared keeps the existing rules text'
    Assert-True (-not (Get-FileText (Join-Path $legion 'configuration/workflow.md')).Contains('## legion orchestration')) 'Shared keeps the block out of workflow.md'
    Assert-Equal 'Set up ps-ai orchestration' (git -C $repo log -1 --format=%s) 'Shared commit message'
    Assert-Equal '' ((git -C $repo status --porcelain) -join "`n") 'Shared setup leaves the code repo clean'
    Assert-True (@(git -C $repo ls-files .legion) -contains '.legion/state/history/.gitkeep') 'Shared commits the setup files'
    Assert-Equal 'skip: Shared orchestration (already done)' (@(& $setup -Repo $repo -Mode Shared))[0] 'Shared repeat skips'
    Assert-Equal 1 ([regex]::Matches((Get-FileText (Join-Path $repo 'AGENTS.md')), '## legion orchestration')).Count 'Rules block stays single'

    # Two rules files where neither imports the other: stop and name them.
    $repo = New-ScaffoldRepo 'ambiguous' -RulesFiles @('AGENTS.md', 'CLAUDE.md')
    $message = ''
    try { & $setup -Repo $repo -Mode Shared | Out-Null } catch { $message = $_.Exception.Message }
    Assert-Equal 'choose -RulesFile: AGENTS.md, CLAUDE.md' $message 'Ambiguous rules files are named'
    Assert-True (-not (Test-Path (Join-Path $repo '.legion'))) 'Ambiguous stop changes nothing'
    & $setup -Repo $repo -Mode Shared -RulesFile CLAUDE.md | Out-Null
    Assert-True ((Get-FileText (Join-Path $repo 'CLAUDE.md')).Contains('## legion orchestration')) 'Chosen rules file gets the block'
    Assert-True (-not (Get-FileText (Join-Path $repo 'AGENTS.md')).Contains('## legion orchestration')) 'Other rules file is untouched'

    # A rules file that imports the other is not ambiguous.
    $repo = New-ScaffoldRepo 'import'
    '@AGENTS.md' | Set-Content (Join-Path $repo 'CLAUDE.md')
    git -C $repo add CLAUDE.md
    git -C $repo commit --quiet -m 'Import'
    & $setup -Repo $repo -Mode Shared | Out-Null
    Assert-True ((Get-FileText (Join-Path $repo 'AGENTS.md')).Contains('## legion orchestration')) 'The imported file gets the block'
} finally {
    foreach ($name in $savedEnv.Keys) {
        [Environment]::SetEnvironmentVariable($name, $savedEnv[$name], 'Process')
    }
    $allowed = [IO.Path]::GetFullPath((Join-Path $root '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
    if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe repository fixture cleanup' }
    Remove-Item -LiteralPath $sandbox -Recurse -Force
}
