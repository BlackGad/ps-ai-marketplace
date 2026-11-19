$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$setup = Join-Path $root 'plugins/ps-ai/bin/ps-ai-repository.ps1'
$sandbox = Join-Path $root ('.agents/temp/repository-mode-' + [guid]::NewGuid().ToString('N'))
$savedGlobal = $env:GIT_CONFIG_GLOBAL
$savedSystem = $env:GIT_CONFIG_NOSYSTEM
New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
try {
    # Every Git write and identity stays inside the fixture.
    $env:GIT_CONFIG_GLOBAL = Join-Path $sandbox 'gitconfig'
    $env:GIT_CONFIG_NOSYSTEM = '1'
    "[user]`nname = Fixture`nemail = fixture@example.invalid`n[commit]`ngpgsign = false`n[init]`ndefaultBranch = main`n" |
        Set-Content -LiteralPath $env:GIT_CONFIG_GLOBAL
    foreach ($mode in @('Private', 'Shared')) {
        $repo = Join-Path $sandbox $mode
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        git init --quiet $repo
        Assert-Equal 0 $LASTEXITCODE 'Fixture repository initialized'
        'owner rules' | Set-Content (Join-Path $repo 'AGENTS.md')
        'existing/' | Set-Content (Join-Path $repo '.gitignore')
        git -C $repo add .
        git -C $repo commit --quiet -m 'Fixture'
        Assert-Equal 0 $LASTEXITCODE 'Fixture baseline committed'
        $outerHead = git -C $repo rev-parse HEAD
        $rules = [IO.File]::ReadAllText((Join-Path $repo 'AGENTS.md'))
        $ignore = [IO.File]::ReadAllText((Join-Path $repo '.gitignore'))
        $legion = Join-Path $repo '.legion'
        foreach ($folder in @('configuration', 'scripts', 'state/history', 'temp', 'docs')) {
            New-Item -ItemType Directory -Path (Join-Path $legion $folder) -Force | Out-Null
        }
        '{"schemaVersion":1}' | Set-Content (Join-Path $legion 'configuration/project.json')
        'workflow' | Set-Content (Join-Path $legion 'configuration/workflow.md')
        'index' | Set-Content (Join-Path $legion 'scripts/index.md')
        'handoff' | Set-Content (Join-Path $legion 'state/handoff.md')
        '' | Set-Content (Join-Path $legion 'state/history/.gitkeep')
        'scratch' | Set-Content (Join-Path $legion 'temp/report.md')
        'local spec' | Set-Content (Join-Path $legion 'docs/spec.md')
        $parameters = @{ Repo = $repo }
        # Omitting Mode exercises the Private default.
        if ($mode -eq 'Shared') { $parameters.Mode = 'Shared' }
        & $setup @parameters | Out-Null
        $excludePath = git -C $repo rev-parse --path-format=absolute --git-path info/exclude
        if ($mode -eq 'Private') {
            Assert-True ((Get-Content $excludePath) -ccontains '.legion/') 'Private excludes the whole layout locally'
            Assert-Equal $ignore ([IO.File]::ReadAllText((Join-Path $repo '.gitignore'))) 'Private preserves tracked ignores byte for byte'
            Assert-Equal $rules ([IO.File]::ReadAllText((Join-Path $repo 'AGENTS.md'))) 'Private preserves rules byte for byte'
            Assert-Equal '' ((git -C $repo status --porcelain) -join "`n") 'Private leaves no outer tracked or untracked changes'
            Assert-Equal $outerHead (git -C $repo rev-parse HEAD) 'Private leaves the code history unchanged'
            Assert-True (Test-Path (Join-Path $legion '.git') -PathType Container) 'Private initializes an inner repository'
            Assert-Equal 'temp/|docs/' ((Get-Content (Join-Path $legion '.gitignore')) -join '|') 'Inner ignores only scratch and local docs'
            $tracked = @(git -C $legion ls-files)
            foreach ($file in @('.gitignore', 'configuration/project.json', 'configuration/workflow.md', 'scripts/index.md', 'state/handoff.md', 'state/history/.gitkeep')) {
                Assert-True ($tracked -ccontains $file) 'Private commits each durable setup file'
            }
            Assert-Equal '' ((git -C $legion status --porcelain) -join "`n") 'Private initial commit excludes docs and scratch'
            # Handoff and history updates must go to the inner history.
            'next handoff' | Set-Content (Join-Path $legion 'state/handoff.md')
            'finished stage' | Set-Content (Join-Path $legion 'state/history/stage.md')
            git -C $legion add state
            git -C $legion commit --quiet -m 'Stage'
            Assert-Equal 0 $LASTEXITCODE 'Private state can be committed independently'
            Assert-Equal $outerHead (git -C $repo rev-parse HEAD) 'Private state commits leave code history unchanged'
            $lane = Join-Path $sandbox 'lane'
            git -C $repo worktree add --quiet --detach $lane HEAD
            Assert-Equal 0 $LASTEXITCODE 'Fixture worktree created'
            New-Item -ItemType Directory -Path (Join-Path $lane '.legion/temp') -Force | Out-Null
            'worker log' | Set-Content (Join-Path $lane '.legion/temp/task.log')
            Assert-Equal '.legion/temp/task.log' (git -C $lane check-ignore .legion/temp/task.log) 'Shared Git exclude also hides worktree scratch'
            Assert-Equal '' ((git -C $lane status --porcelain) -join "`n") 'Private worktree scratch stays invisible to code Git'
        } else {
            Assert-True (-not (Test-Path (Join-Path $legion '.git'))) 'Shared uses the code repository'
            Assert-Equal 'existing/|.legion/temp/|.legion/docs/' ((Get-Content (Join-Path $repo '.gitignore')) -join '|') 'Shared appends narrow ignores'
            Assert-True (-not ((Get-Content $excludePath) -ccontains '.legion/')) 'Shared keeps orchestration visible to code Git'
            git -C $repo add .gitignore .legion/configuration .legion/scripts .legion/state
            git -C $repo commit --quiet -m 'Shared setup'
            Assert-Equal 0 $LASTEXITCODE 'Shared commits belong to the code repository'
            Assert-Equal '' ((git -C $repo status --porcelain) -join "`n") 'Shared docs and scratch stay untracked'
        }
        $owningRepo = if ($mode -eq 'Private') { $legion } else { $repo }
        $head = git -C $owningRepo rev-parse HEAD
        $paths = @((Join-Path $repo '.gitignore'), $excludePath, (Join-Path $repo 'AGENTS.md'))
        if ($mode -eq 'Private') { $paths += Join-Path $legion '.gitignore' }
        $ticks = @($paths | ForEach-Object { [IO.File]::GetLastWriteTimeUtc($_).Ticks }) -join '|'
        $repeat = @(& $setup @parameters)
        Assert-True ($repeat -match '^skip: .*\(already done\)$') 'Setup repeat reports a skip'
        Assert-Equal $head (git -C $owningRepo rev-parse HEAD) 'Setup repeat creates no commit'
        Assert-Equal $ticks (@($paths | ForEach-Object { [IO.File]::GetLastWriteTimeUtc($_).Ticks }) -join '|') 'Setup repeat rewrites no file'
    }
} finally {
    $env:GIT_CONFIG_GLOBAL = $savedGlobal
    $env:GIT_CONFIG_NOSYSTEM = $savedSystem
    $allowed = [IO.Path]::GetFullPath((Join-Path $root '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
    if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe repository fixture cleanup' }
    Remove-Item -LiteralPath $sandbox -Recurse -Force
}
