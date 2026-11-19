$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$setup = Join-Path $root 'plugins/ps-ai/bin/ps-ai-repository.ps1'
$sandbox = Join-Path $root ('.agents/temp/repository-defects-' + [guid]::NewGuid().ToString('N'))
$gitCommand = (Get-Command git -CommandType Application | Select-Object -First 1).Source
$savedEnv = @{}
foreach ($name in @('GIT_CONFIG_GLOBAL', 'GIT_CONFIG_NOSYSTEM', 'GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_COMMITTER_NAME', 'GIT_COMMITTER_EMAIL', 'EMAIL')) {
    $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
}

function New-RepositoryFixture {
    param([string]$Name)
    $repo = Join-Path $sandbox $Name
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    git init --quiet $repo
    Assert-Equal 0 $LASTEXITCODE 'Fixture repository initialized'
    git -C $repo config user.name 'Fixture Owner'
    git -C $repo config user.email 'fixture@example.invalid'
    'code' | Set-Content (Join-Path $repo 'code.txt')
    git -C $repo add code.txt
    git -C $repo commit --quiet -m 'Fixture'
    Assert-Equal 0 $LASTEXITCODE 'Fixture code committed'
    foreach ($folder in @('configuration', 'scripts', 'state')) {
        New-Item -ItemType Directory -Path (Join-Path $repo ".legion/$folder") -Force | Out-Null
        'fixture' | Set-Content (Join-Path $repo ".legion/$folder/input.txt")
    }
    return $repo
}

function Get-RepositorySnapshot {
    param([string]$Repo)
    return (@(Get-ChildItem -LiteralPath $Repo -Recurse -Force -File | Sort-Object FullName | ForEach-Object {
        "$($_.FullName)|$($_.LastWriteTimeUtc.Ticks)|$((Get-FileHash -LiteralPath $_.FullName).Hash)"
    }) -join "`n")
}

New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
try {
    # No global identity: only the code repo supplies the first Private commit's identity.
    $env:GIT_CONFIG_GLOBAL = Join-Path $sandbox 'gitconfig'
    $env:GIT_CONFIG_NOSYSTEM = '1'
    "[user]`nuseConfigOnly = true`n[commit]`ngpgsign = false`n[init]`ndefaultBranch = main`n" |
        Set-Content -LiteralPath $env:GIT_CONFIG_GLOBAL

    # 3a: Private refuses tracked .legion files before writing anything.
    $repo = New-RepositoryFixture 'tracked'
    git -C $repo add .legion/configuration/input.txt
    git -C $repo commit --quiet -m 'Share setup'
    $before = Get-RepositorySnapshot $repo
    $message = ''
    try { & $setup -Repo $repo -Mode Private | Out-Null } catch { $message = $_.Exception.Message }
    Assert-True ($message -like '*already shares .legion (Shared)*') 'Private explains that tracked files mean Shared'
    Assert-Equal $before (Get-RepositorySnapshot $repo) 'Refused Private setup writes nothing'

    # 3b: Shared refuses both forms of nested Git history without writes.
    foreach ($kind in @('folder', 'file')) {
        $repo = New-RepositoryFixture "shared-refuses-$kind"
        $legion = Join-Path $repo '.legion'
        if ($kind -eq 'file') {
            git init --quiet --separate-git-dir (Join-Path $sandbox 'private-history') $legion
        } else { git init --quiet $legion }
        Assert-Equal 0 $LASTEXITCODE 'Nested fixture history initialized'
        $before = Get-RepositorySnapshot $repo
        $message = ''
        try { & $setup -Repo $repo -Mode Shared | Out-Null } catch { $message = $_.Exception.Message }
        Assert-True ($message -like '*already has Private Git history*') "Shared refuses a .git $kind"
        Assert-Equal $before (Get-RepositorySnapshot $repo) "Refused Shared setup preserves a .git $kind"
    }

    # 3c and 3d: A .git file is existing history; commit with the code repo's local identity.
    $repo = New-RepositoryFixture 'private-pointer'
    $legion = Join-Path $repo '.legion'
    $history = Join-Path $sandbox 'pointer-history'
    git init --quiet --separate-git-dir $history $legion
    Assert-Equal 0 $LASTEXITCODE 'Private pointer fixture initialized'
    $pointer = [IO.File]::ReadAllText((Join-Path $legion '.git'))
    & $setup -Repo $repo | Out-Null
    Assert-Equal $pointer ([IO.File]::ReadAllText((Join-Path $legion '.git'))) 'Private preserves an existing .git file'
    Assert-Equal 'Fixture Owner|fixture@example.invalid|Fixture Owner|fixture@example.invalid' (git -C $legion log -1 '--format=%an|%ae|%cn|%ce') 'First Private commit uses the code repo identity'
    git -C $legion config --local --get user.name | Out-Null
    Assert-Equal 1 $LASTEXITCODE 'Commit identity does not alter nested Git configuration'
    $head = git -C $legion rev-parse HEAD
    Assert-True ((& $setup -Repo $repo) -like 'skip:*') 'Private .git file repeats without initialization'
    Assert-Equal $head (git -C $legion rev-parse HEAD) 'Private .git file repeat creates no commit'

    # 3d: A newly initialized nested repo also inherits the local code identity.
    $repo = New-RepositoryFixture 'private-identity'
    & $setup -Repo $repo | Out-Null
    $legion = Join-Path $repo '.legion'
    Assert-Equal 'Fixture Owner|fixture@example.invalid' (git -C $legion log -1 '--format=%an|%ae') 'Fresh nested history uses the local code identity'

    # 3f: Starting inside nested Private history still selects the code repo.
    $head = git -C $legion rev-parse HEAD
    foreach ($inside in @($legion, (Join-Path $legion 'configuration'))) {
        Assert-True ((& $setup -Repo $inside) -like 'skip:*') 'Repo inside .legion resolves to the parent code repo'
        Assert-Equal $head (git -C $legion rev-parse HEAD) 'Nested starting path preserves Private history'
        Assert-True (-not (Test-Path (Join-Path $legion '.legion'))) 'Nested starting path never creates .legion/.legion'
    }

    # 3e: Reject Git 2.31's newer flag and exercise relative and linked-worktree exclude paths.
    $codeRepo = New-RepositoryFixture 'exclude-main'
    $lane = Join-Path $sandbox 'exclude-lane'
    git -C $codeRepo worktree add --quiet --detach $lane HEAD
    Assert-Equal 0 $LASTEXITCODE 'Linked fixture worktree initialized'
    foreach ($folder in @('configuration', 'scripts', 'state')) {
        New-Item -ItemType Directory -Path (Join-Path $lane ".legion/$folder") -Force | Out-Null
        'fixture' | Set-Content (Join-Path $lane ".legion/$folder/input.txt")
    }
    foreach ($repo in @($codeRepo, $lane)) {
        & {
            function git {
                if ($args -match '^--path-format') { throw 'Git fixture does not support --path-format' }
                & $gitCommand @args
                $global:LASTEXITCODE = $LASTEXITCODE
            }
            & $setup -Repo $repo | Out-Null
        }
        $exclude = @(git -C $repo rev-parse --git-path info/exclude)[0]
        $exclude = [IO.Path]::GetFullPath([IO.Path]::Combine($repo, $exclude))
        Assert-Equal ([IO.Path]::GetFullPath((Join-Path $codeRepo '.git/info/exclude'))) $exclude 'Main and linked worktree resolve the shared exclude file'
        Assert-Equal 1 @((Get-Content -LiteralPath $exclude) | Where-Object { $_ -ceq '.legion/' }).Count 'Shared exclude entry is written once'
        Assert-Equal '.legion/configuration/input.txt' (git -C $repo check-ignore .legion/configuration/input.txt) 'Private configuration stays ignored in either worktree'
        Assert-Equal '' ((git -C $repo status --porcelain) -join "`n") 'Private setup leaves code Git clean in either worktree'
    }
} finally {
    foreach ($name in $savedEnv.Keys) {
        if ($null -eq $savedEnv[$name]) { Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue }
        else { [Environment]::SetEnvironmentVariable($name, $savedEnv[$name], 'Process') }
    }
    $allowed = [IO.Path]::GetFullPath((Join-Path $root '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
    if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe repository fixture cleanup' }
    Remove-Item -LiteralPath $sandbox -Recurse -Force
}
