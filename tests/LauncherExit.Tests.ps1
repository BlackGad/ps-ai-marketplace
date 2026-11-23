$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/workspace.ps1')
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$scratch = Join-Path $tempBase ('launcher-exit-' + [guid]::NewGuid().ToString('N'))
# The public command finds the app from its own folder, as in an installed home.
$fixtureHome = Join-Path $scratch 'home'
$plugin = Join-Path $fixtureHome '.legion/app/9.9.9'
$repo = Join-Path $scratch 'repo'
$savedPath = $env:PATH
try {
    Copy-Item (Join-Path $root 'plugins/legion') $plugin -Recurse
    git init --quiet $repo 2>&1 | Out-Null
    New-Item -ItemType Directory (Join-Path $fixtureHome '.legion/configuration'), (Join-Path $repo '.legion/configuration') -Force | Out-Null
    '{"schemaVersion":1,"agents":[{"id":"codex-a","tool":"codex","configDir":"~/.codex"}],"channels":[]}' | Set-Content (Join-Path $fixtureHome '.legion/configuration/personalisation.json')
    '{"schemaVersion":1}' | Set-Content (Join-Path $repo '.legion/configuration/project.json')
    $overseer = Join-Path $plugin 'bin/legion-overseer.ps1'
    $text = [IO.File]::ReadAllText($overseer)
    $homeLiteral = "'" + $fixtureHome.Replace("'", "''") + "'"
    $text = $text.Replace('[string]$HomeRoot = $HOME', '[string]$HomeRoot = ' + $homeLiteral)
    # Keep both real entry points; only terminal/agent launch is replaced in the fixture copy.
    $text = $text.Replace('if (-not $NoRun) {', 'function Start-OverseerLaunch { $global:LASTEXITCODE = 5 }; if (-not $NoRun) {')
    [IO.File]::WriteAllText($overseer, $text)
    . (Join-Path $root 'plugins/legion/bin/lib/accounts.ps1')
    . (Join-Path $root 'plugins/legion/bin/lib/commands.ps1')
    $public = Join-Path $fixtureHome $(if ($IsWindows) { '.legion/bin/legion.cmd' } else { '.legion/bin/legion' })
    New-Item -ItemType Directory (Split-Path $public) -Force | Out-Null
    Get-LegionShimText -App $plugin -Windows:$IsWindows | Set-Content $public
    Set-TestExecutable $public
    # The fake uv forwards to the app's PowerShell entry point, as the Python CLI does.
    $uvFolder = Split-Path (New-TestCommandStub -Folder (Join-Path $scratch 'uv') -Name uv -Script (Join-Path $PSScriptRoot 'fixtures/fake-tools/uv.ps1'))
    $pwsh = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
    $git = (Get-Command git -CommandType Application | Select-Object -First 1).Source
    $env:PATH = $uvFolder + [IO.Path]::PathSeparator + (Split-Path $pwsh) + [IO.Path]::PathSeparator + (Split-Path $git) + [IO.Path]::PathSeparator + $(if ($IsWindows) { Join-Path $env:SystemRoot 'System32' } else { '/usr/bin' })
    Push-Location $repo
    try { $output = @(& $public --no-channel 2>&1) }
    finally { Pop-Location }
    Assert-Equal 5 $LASTEXITCODE 'G5 public legion command preserves native launch exit 5'
    Assert-True (-not ($output -match '^launched ')) 'G5 failed public launch prints no success'
    $output = @(& $pwsh -NoProfile -File $overseer -Repo $repo -NoChannel 2>&1)
    Assert-Equal 5 $LASTEXITCODE 'G5 direct overseer entry preserves native launch exit 5'
    Assert-True (-not ($output -match '^launched ')) 'G5 failed direct launch prints no success'
} finally {
    $env:PATH = $savedPath
    if (-not ([IO.Path]::GetFullPath($scratch).StartsWith($tempBase))) { throw 'fixture cleanup escaped the temp folder' }
    Remove-Item -LiteralPath $scratch -Recurse -Force
}
