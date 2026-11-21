$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path $root ('.agents/temp/launcher-exit-' + [guid]::NewGuid().ToString('N'))
$plugin = Join-Path $scratch 'plugin'
$fixtureHome = Join-Path $scratch 'home'
$repo = Join-Path $scratch 'repo'
$savedPath = $env:PATH
try {
    Copy-Item (Join-Path $root 'plugins/ps-ai') $plugin -Recurse
    git init --quiet $repo 2>&1 | Out-Null
    New-Item -ItemType Directory (Join-Path $fixtureHome '.legion/configuration'), (Join-Path $repo '.legion/configuration') -Force | Out-Null
    '{"schemaVersion":1,"agents":[{"id":"codex-a","tool":"codex","configDir":"~/.codex"}],"channels":[]}' | Set-Content (Join-Path $fixtureHome '.legion/configuration/ps-ai-personalisation.json')
    '{"schemaVersion":1}' | Set-Content (Join-Path $repo '.legion/configuration/project.json')
    $overseer = Join-Path $plugin 'bin/ps-ai-overseer.ps1'
    $text = [IO.File]::ReadAllText($overseer)
    $homeLiteral = "'" + $fixtureHome.Replace("'", "''") + "'"
    $text = $text.Replace('[string]$HomeRoot = $HOME', '[string]$HomeRoot = ' + $homeLiteral)
    # Keep both real entry points; only terminal/agent launch is replaced in the fixture copy.
    $text = $text.Replace('if (-not $launcherNoRun) {', 'function Start-OverseerLaunch { $global:LASTEXITCODE = 5 }; if (-not $launcherNoRun) {')
    [IO.File]::WriteAllText($overseer, $text)
    . (Join-Path $root 'plugins/ps-ai/bin/ps-ai-account.ps1') -NoRun
    . (Join-Path $root 'plugins/ps-ai/bin/lib/commands.ps1')
    $public = Join-Path $scratch $(if ($IsWindows) { 'legion.cmd' } else { 'legion' })
    Get-PsAiShimText -Script (Join-Path $plugin 'bin/legion.ps1') -Windows:$IsWindows | Set-Content $public
    if (-not $IsWindows) { & chmod +x $public }
    $pwsh = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
    $git = (Get-Command git -CommandType Application | Select-Object -First 1).Source
    $env:PATH = (Split-Path $pwsh) + [IO.Path]::PathSeparator + (Split-Path $git) + [IO.Path]::PathSeparator + $(if ($IsWindows) { Join-Path $env:SystemRoot 'System32' } else { '/usr/bin' })
    Push-Location $repo
    try { $output = @(& $public start --no-channel 2>&1) }
    finally { Pop-Location }
    Assert-Equal 5 $LASTEXITCODE 'G5 public legion command preserves native launch exit 5'
    Assert-True (-not ($output -match '^launched ')) 'G5 failed public launch prints no success'
    $output = @(& $pwsh -NoProfile -File $overseer -Repo $repo -NoChannel 2>&1)
    Assert-Equal 5 $LASTEXITCODE 'G5 direct overseer entry preserves native launch exit 5'
    Assert-True (-not ($output -match '^launched ')) 'G5 failed direct launch prints no success'
} finally {
    $env:PATH = $savedPath
    if (-not ([IO.Path]::GetFullPath($scratch).StartsWith([IO.Path]::GetFullPath((Join-Path $root '.agents/temp/'))))) { throw 'fixture cleanup escaped the worktree' }
    Remove-Item -LiteralPath $scratch -Recurse -Force
}
