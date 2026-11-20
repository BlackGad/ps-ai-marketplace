$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$setup = Join-Path $root 'plugins/ps-ai/bin/ps-ai-repository.ps1'
$sandbox = Join-Path $root ('.agents/temp/repository-hardening-' + [guid]::NewGuid().ToString('N'))
$savedEnv = @{}
foreach ($name in @('GIT_CONFIG_GLOBAL', 'GIT_CONFIG_NOSYSTEM')) {
    $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

function New-HardeningRepo {
    param([string]$Name)
    $repo = Join-Path $sandbox $Name
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    git init --quiet $repo
    git -C $repo config user.name 'Fixture Owner'
    git -C $repo config user.email 'fixture@example.invalid'
    'rules' | Set-Content (Join-Path $repo 'AGENTS.md')
    git -C $repo add .
    git -C $repo commit --quiet -m 'Fixture'
    return $repo
}

function Get-ThrownMessage {
    param([scriptblock]$Action)
    try { & $Action | Out-Null } catch { return $_.Exception.Message }
    return ''
}

# The git working tree that holds the setup files: the inner repository in Private mode.
function Get-SetupGitRoot {
    param([string]$Repo, [string]$Mode)
    if ($Mode -eq 'Private') { return Join-Path $Repo '.legion' }
    return $Repo
}

New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
try {
    $env:GIT_CONFIG_GLOBAL = Join-Path $sandbox 'gitconfig'
    $env:GIT_CONFIG_NOSYSTEM = '1'

    foreach ($mode in @('Shared', 'Private')) {
        $prefix = if ($mode -eq 'Shared') { '.legion/' } else { '' }

        # A1: a repeat leaves the owner's untracked files under the setup folders alone.
        $repo = New-HardeningRepo "a1-untracked-$mode"
        & $setup -Repo $repo -Mode $mode | Out-Null
        $gitRoot = Get-SetupGitRoot $repo $mode
        Set-Content -LiteralPath (Join-Path $repo '.legion/scripts/mine.ps1') -Value 'owner script'
        # An unrelated pending setup file makes the repeat commit something.
        Remove-Item -LiteralPath (Join-Path $repo '.legion/state/history/.gitkeep')
        git -C $gitRoot rm -q --cached -- "$($prefix)state/history/.gitkeep"
        git -C $gitRoot config user.name Owner; git -C $gitRoot config user.email owner@example.invalid; git -C $gitRoot commit -q -m 'Drop gitkeep'
        & $setup -Repo $repo -Mode $mode | Out-Null
        $tracked = @(git -C $gitRoot ls-files)
        Assert-True ($tracked -ccontains "$($prefix)state/history/.gitkeep") "A1 $mode`: the setup file is committed again"
        Assert-True ($tracked -cnotcontains "$($prefix)scripts/mine.ps1") "A1 $mode`: the owner file stays untracked"

        # A1: a file the owner staged in part is refused, not committed.
        $repo = New-HardeningRepo "a1-partial-$mode"
        & $setup -Repo $repo -Mode $mode | Out-Null
        $gitRoot = Get-SetupGitRoot $repo $mode
        $handoff = Join-Path $repo '.legion/state/handoff.md'
        Add-Content -LiteralPath $handoff -Value 'staged part'
        git -C $gitRoot add -- "$($prefix)state/handoff.md"
        Add-Content -LiteralPath $handoff -Value 'unstaged part'
        $before = git -C $gitRoot rev-parse HEAD
        $message = Get-ThrownMessage { & $setup -Repo $repo -Mode $mode }
        Assert-True ($message -like '*handoff.md*staged and unstaged*') "A1 $mode`: a partly staged setup file is refused ($message)"
        Assert-Equal $before (git -C $gitRoot rev-parse HEAD) "A1 $mode`: nothing is committed"
    }

    # A2: a rules file name with spaces and non-ASCII letters is staged after an earlier failed commit.
    $repo = New-HardeningRepo 'a2-quoted'
    $hook = Join-Path $repo '.git/hooks/pre-commit'
    New-Item -ItemType Directory -Path (Split-Path $hook -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($hook, "#!/bin/sh`nexit 1`n")
    if (-not $IsWindows) { chmod +x $hook }
    $rulesName = 'my rules ' + [char]0x00FC + '.md'
    $message = Get-ThrownMessage { & $setup -Repo $repo -Mode Shared -RulesFile $rulesName }
    Assert-True ($message -ne '') 'A2: the first run fails (hook or staging)'
    Remove-Item -LiteralPath $hook
    & $setup -Repo $repo -Mode Shared -RulesFile $rulesName | Out-Null
    Assert-Equal '' ((git -C $repo status --porcelain) -join "`n") 'A2: the repeat commits the oddly named rules file'

    # A3: a link under a write destination is refused before anything is written.
    $outside = Join-Path $sandbox 'a3-outside'
    New-Item -ItemType Directory -Path $outside -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $outside 'ignore-target'), 'outside')
    $folderType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
    $linkCases = @(
        @{ Name = 'ignore file'; Mode = 'Shared'; Link = '.gitignore'; Type = 'SymbolicLink'; Target = (Join-Path $outside 'ignore-target') },
        @{ Name = 'inner ignore file'; Mode = 'Private'; Link = '.legion/.gitignore'; Type = 'SymbolicLink'; Target = (Join-Path $outside 'ignore-target') },
        @{ Name = 'docs folder'; Mode = 'Shared'; Link = '.legion/docs'; Type = $folderType; Target = $outside },
        @{ Name = 'state folder'; Mode = 'Private'; Link = '.legion/state'; Type = $folderType; Target = $outside }
    )
    foreach ($case in $linkCases) {
        $repo = New-HardeningRepo "a3-$($case.Name -replace ' ', '-')"
        New-Item -ItemType Directory -Path (Join-Path $repo '.legion') -Force | Out-Null
        try { New-Item -ItemType $case.Type -Path (Join-Path $repo $case.Link) -Target $case.Target -ErrorAction Stop | Out-Null }
        catch { Write-Host "skip A3 $($case.Name): cannot create a link here"; continue }
        $message = Get-ThrownMessage { & $setup -Repo $repo -Mode $case.Mode }
        Assert-True ($message -like '*link*') "A3 $($case.Name): refused ($message)"
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $repo '.legion/configuration'))) "A3 $($case.Name): nothing is written"
        Assert-Equal 'outside' ([IO.File]::ReadAllText((Join-Path $outside 'ignore-target'))) "A3 $($case.Name): the ignore target is untouched"
        Assert-True (@(Get-ChildItem -LiteralPath $outside).Count -eq 1) "A3 $($case.Name): nothing is created outside"
    }

    # A1: a Git setting that hides untracked files does not hide the new scaffold from the commit.
    $repo = New-HardeningRepo 'a1-hidden-untracked'
    git -C $repo config status.showUntrackedFiles no
    & $setup -Repo $repo -Mode Shared | Out-Null
    Assert-True (@(git -C $repo ls-files) -ccontains '.legion/state/handoff.md') 'A1: showUntrackedFiles=no still commits the new scaffold'

    # A3: a link at the Private exclude file, or its folder, is refused before anything is written.
    $excludeCases = @(
        @{ Name = 'exclude file'; Link = '.git/info/exclude'; Type = 'SymbolicLink'; Target = (Join-Path $outside 'ignore-target') },
        @{ Name = 'exclude folder'; Link = '.git/info'; Type = $folderType; Target = $outside }
    )
    foreach ($case in $excludeCases) {
        $repo = New-HardeningRepo "a3-$($case.Name -replace ' ', '-')"
        $linkPath = Join-Path $repo $case.Link
        Remove-Item -LiteralPath $linkPath -Recurse -Force -ErrorAction SilentlyContinue
        try { New-Item -ItemType $case.Type -Path $linkPath -Target $case.Target -ErrorAction Stop | Out-Null }
        catch { Write-Host "skip A3 $($case.Name): cannot create a link here"; continue }
        $message = Get-ThrownMessage { & $setup -Repo $repo -Mode Private }
        Assert-True ($message -like '*link*') "A3 $($case.Name): refused ($message)"
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $repo '.legion/configuration'))) "A3 $($case.Name): nothing is written"
        Assert-Equal 'outside' ([IO.File]::ReadAllText((Join-Path $outside 'ignore-target'))) "A3 $($case.Name): the linked exclude target is untouched"
    }

    # A4: an edited gate script stays in a rebuilt index with a generic description.
    $repo = New-HardeningRepo 'a4-edited-gate'
    & $setup -Repo $repo -Mode Shared -Gate 'echo first' | Out-Null
    [IO.File]::WriteAllText((Join-Path $repo '.legion/scripts/check-task.ps1'), "Write-Host 'custom gate'`n")
    git -C $repo commit -q -am 'Edit gate'
    git -C $repo rm -q .legion/scripts/index.md
    git -C $repo commit -q -m 'Drop index'
    & $setup -Repo $repo -Mode Shared | Out-Null
    $index = [IO.File]::ReadAllText((Join-Path $repo '.legion/scripts/index.md'))
    Assert-True ($index.Contains('`check-task.ps1`')) 'A4: the edited gate script is listed in the rebuilt index'
    $workflow = [IO.File]::ReadAllText((Join-Path $repo '.legion/configuration/workflow.md'))
    Assert-True ($workflow.Contains('check-task.ps1')) 'A4: the workflow names the edited gate script'
} finally {
    foreach ($name in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnv[$name], 'Process') }
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}
