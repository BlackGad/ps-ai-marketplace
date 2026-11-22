. (Join-Path $PSScriptRoot 'workspace.ps1')

function Set-TestGitEnvironment {
    param([string]$Sandbox)
    $saved = @{}
    foreach ($name in 'GIT_CONFIG_GLOBAL', 'GIT_CONFIG_NOSYSTEM') { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
    New-Item -ItemType Directory -Path $Sandbox -Force | Out-Null
    $env:GIT_CONFIG_GLOBAL = Join-Path $Sandbox 'gitconfig'
    $env:GIT_CONFIG_NOSYSTEM = '1'
    "[user]`nname = Fixture`nemail = fixture@example.invalid`n[commit]`ngpgsign = false`n[init]`ndefaultBranch = main`n" |
        Set-Content -LiteralPath $env:GIT_CONFIG_GLOBAL
    return $saved
}

function New-TestGitRepository {
    param([string]$Sandbox, [string]$Name)
    $repo = Join-Path $Sandbox $Name
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    git init --quiet $repo
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
