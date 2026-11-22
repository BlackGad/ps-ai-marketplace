param([string]$Installer, [string]$Repo, [switch]$NoRun)
. (Join-Path $PSScriptRoot '../../lib/installer.ps1')

function New-InstallTextRunner {
    param([string]$Path)
    @'
param($Installer, $Plugin, $Fixture, $Archive, $Mode = 'file', $Tool = 'claude', $CliPath, $Ref, [switch]$NoRelease)
$ErrorActionPreference = 'Stop'
# A 5.1 child of pwsh must use its own built-in archive module.
if ($PSVersionTable.PSVersion.Major -lt 7) { $env:PSModulePath=Join-Path $PSHOME 'Modules' }
$pwshFolder=Split-Path (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
if ($CliPath) { $env:PATH=$CliPath + [IO.Path]::PathSeparator + $pwshFolder }
foreach ($name in @('CLAUDE_CONFIG_DIR','CODEX_HOME','COPILOT_HOME')) { Remove-Item "Env:$name" -ErrorAction Ignore }
$script:downloads = 0
$script:fixtureArchive = $Archive
# The stub's download function runs for real; only the request is faked.
function Invoke-WebRequest {
    param($Uri,$OutFile)
    $Url = $Uri
    if ($Url -notmatch '^https://github.com/BlackGad/ps-legion-marketplace/archive/refs/heads/(stable|main)\.zip$') { throw "Unexpected URL: $Url" }
    $script:downloads++
    Write-Host "download=$Url"
    if ($NoRelease) { throw 'Fixture release unavailable' }
    Copy-Item -LiteralPath $script:fixtureArchive -Destination $OutFile
}
$arguments = @{ DryRun=$true; HomeRoot=$Fixture }
if ($Ref) { $arguments.Ref=$Ref }
if ($Mode -ne 'catalog') { $arguments.Tools=@($Tool); $arguments.Source=$Fixture }
else { $env:PATH=$pwshFolder }
if ($Mode -eq 'text') { & ([scriptblock]::Create((Get-Content -LiteralPath $Installer -Raw))) @arguments }
else { & $Installer @arguments }
"downloads=$script:downloads"
'@ | Set-Content -LiteralPath $Path
}

if ($NoRun) { return }
$fixtureInstaller=$Installer
. $fixtureInstaller -NoRun
$script:installCatalog=Get-Content (Join-Path $Repo 'tests/fixtures/install/catalog.json') -Raw | ConvertFrom-Json
& {
    $catalog = Get-InstallCatalog -Catalog $script:installCatalog
    $fourth = Get-Content (Join-Path $Repo 'tests/fixtures/tools/legion-fourth/tool.json') -Raw | ConvertFrom-Json
    $catalog.tools += [pscustomobject]@{id='fourth';command='fourth-cli';configEnv='FOURTH_HOME';plugin=$fourth.plugin;hooks=$fourth.hooks;installHint='fixture only'}
    $script:installCatalog = Get-InstallCatalog -Catalog $catalog
    Assert-Equal 'fourth-cli|plugin|marketplace|add|local source' ((Get-InstallCommands fourth 'local source')[0] -join '|') 'Standalone fourth command uses catalog'
    Assert-True (-not (Test-InstallListing -Kind plugin -Tool claude -Lines @('[{"id":"legion@ps-legion-marketplace","enabled":"true"}]'))) 'Windows PowerShell JSON rejects string true'
}
$sandbox = New-InstallTestFolder 'restructure/remote-install'
$savedPath=$env:PATH
$fixturePwshExe=(Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
try {
    # Run a copied archive layout, with no repository context or real CLIs.
    $fakeBin = Join-Path $sandbox 'fake-bin'
    New-Item -ItemType Directory -Path $fakeBin | Out-Null
    $listingScript = Join-Path $fakeBin 'listing.ps1'
    @'
param($Tool)
if ($args -contains 'marketplace') {
    if ($Tool -eq 'codex') { '{"marketplaces":[]}' } else { '[]' }
} elseif ($Tool -eq 'claude') { '[]' }
else { 'legion@ps-legion-marketplace installed, enabled ' + (Join-Path (Split-Path $PSScriptRoot -Parent) 'installed-update') }
'@ | Set-Content -LiteralPath $listingScript
    if ($env:OS -eq 'Windows_NT') {
        foreach ($tool in @('claude','codex','copilot')) {
            @('@echo off', ('"' + $fixturePwshExe + '" -NoProfile -File "%~dp0listing.ps1" ' + $tool + ' %*')) |
                Set-Content -LiteralPath (Join-Path $fakeBin "$tool.cmd")
        }
    } else {
        foreach ($tool in @('claude','codex','copilot')) {
            $fake = Join-Path $fakeBin $tool
            "#!/bin/sh`nexec pwsh -NoProfile -File '$listingScript' $tool `"`$@`"" | Set-Content -LiteralPath $fake
            Set-TestExecutable $fake
        }
    }
    $env:PATH = $fakeBin + [IO.Path]::PathSeparator + (Split-Path $fixturePwshExe -Parent)
    $standalone = Join-Path $sandbox 'install.ps1'
    Copy-Item -LiteralPath $fixtureInstaller -Destination $standalone
    New-Item -ItemType Directory -Path (Join-Path $sandbox 'bin/lib') -Force | Out-Null
    Copy-Item (Join-Path $Repo 'plugins/legion/bin/lib/paths.ps1') (Join-Path $sandbox 'bin/lib/paths.ps1')
    Copy-Item (Join-Path $Repo 'plugins/legion/bin/lib/footprints.ps1') (Join-Path $sandbox 'bin/lib/footprints.ps1')
    Copy-Item -LiteralPath (Join-Path $Repo 'tests/fixtures/install/catalog.json') -Destination (Join-Path $sandbox 'tools.json')
    New-Item -ItemType Directory -Path (Join-Path $sandbox 'plugins/legion') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $sandbox 'tools.json') -Destination (Join-Path $sandbox 'plugins/legion/tools.json')
    $runner = Join-Path $sandbox 'invoke-text.ps1'
    # The child reads the fixture home's accounts, never the real personalisation file.
    New-Item -ItemType Directory -Path (Join-Path $sandbox '.legion/configuration') -Force | Out-Null
    '{"agents":[{"id":"codex-fixture","tool":"codex","configDir":"~/.legion/agents/codex-fixture"}]}' | Set-Content -LiteralPath (Join-Path $sandbox '.legion/configuration/personalisation.json')
    New-InstallTextRunner -Path $runner
    $result = Invoke-ClosedInput -Command @($fixturePwshExe, '-NoProfile', '-File', $runner, '-Installer', $standalone, '-Fixture', $sandbox, '-Tool', 'codex', '-Mode', 'file')
    $output = $result.Output
    Assert-Equal 0 $result.ExitCode 'Expanded archive runs standalone without repository context'
    Assert-True (($output -join "`n").Contains('codex-fixture')) 'P2: the child uses the fixture home, not the real personalisation file'
    Assert-Equal 1 @($output | Where-Object { "$_" -eq 'Codex: approve the legion hooks once with /hooks in a Codex session.' }).Count 'Codex prints hook approval reminder once'
    # Exercise the actual subprocess adapter with a fake CLI, including npm-style Windows shims.
    if ($env:OS -eq 'Windows_NT') {
        $echoScript = Join-Path $fakeBin 'echo-args.ps1'
        'param($Value); "$Value|$env:CODEX_HOME|$([Console]::In.ReadToEnd().Length)"' | Set-Content -LiteralPath $echoScript
        @('@echo off', ('"' + $fixturePwshExe + '" -NoProfile -File "%~dp0echo-args.ps1" %*')) | Set-Content -LiteralPath (Join-Path $fakeBin 'codex.cmd')
    } else {
        "#!/bin/sh`nread value`nprintf '%s|%s|0\n' " + '"$1" "$CODEX_HOME"' | Set-Content -LiteralPath (Join-Path $fakeBin 'codex')
    }
    @'
param($Installer)
. $Installer -NoRun
$env:CODEX_HOME = 'default account'
Invoke-InstallCommand -Command @('codex', 'space value') -ConfigEnv CODEX_HOME -ConfigDir 'selected account'
if ($env:CODEX_HOME -ne 'default account') { throw 'account environment was not restored' }
'@ | Set-Content -LiteralPath $runner
    $runtimes = @($fixturePwshExe)
    foreach ($runtime in $runtimes) {
        $result = Invoke-ClosedInput -Command @($runtime, '-NoProfile', '-File', $runner, '-Installer', $standalone)
        Assert-Equal 0 $result.ExitCode 'Closed-input CLI process succeeds and restores account environment'
        Assert-Equal 'space value|selected account|0' ($result.Output -join '') 'CLI receives spaced argument, selected account, and EOF on stdin'
    }

    # Expanded installer updates every account under PowerShell 7.
    @'
param($Installer)
$ErrorActionPreference = 'Stop'
. $Installer -NoRun
$fixtureHome = Split-Path $Installer
$configFolder = Join-Path $fixtureHome '.legion/configuration'
New-Item -ItemType Directory -Path $configFolder -Force | Out-Null
'{"agents":[{"tool":"codex","configDir":"~/.legion/agents/codex-a"}]}' |
    Set-Content -LiteralPath (Join-Path $configFolder 'personalisation.json')
function Get-InstallHome { $fixtureHome }
function Invoke-InstallRefresh { } # Dedicated refresh tests exercise the installed script process.
function Ensure-InstallPowerShell { throw 'Update attempted prerequisite installation' }
function Test-InstallCommandAvailable { param($Name) $Name -eq 'codex' }
$fixturePlugin = Join-Path $fixtureHome 'installed-update'
New-Item -ItemType Directory -Path $fixturePlugin -Force | Out-Null
'{"name":"legion","version":"0.3.0"}' | Set-Content -LiteralPath (Join-Path $fixturePlugin 'plugin.json')
$state = @{ Calls=0; Default=0; Account=0 }
$inheritedAccount = Join-Path $fixtureHome 'inherited-account'
New-Item -ItemType Directory -Path $inheritedAccount, (Join-Path $fixtureHome '.legion/agents/codex-a') -Force | Out-Null
function Invoke-ClosedInput {
    param($Command, $Environment)
    $state.Calls++
    if ($Environment.CODEX_HOME -eq $inheritedAccount) { $state.Default++ }
    elseif ($Environment.CODEX_HOME -eq (Join-Path $fixtureHome '.legion/agents/codex-a')) { $state.Account++ }
    else { throw 'Incorrect config target' }
    if ($Command[2] -eq 'remove') { throw 'Update removed plugin approval' }
    return @{ ExitCode=0; Output=@("legion@ps-legion-marketplace installed, enabled $fixturePlugin") }
}
$env:CODEX_HOME = $inheritedAccount
$null = Invoke-LegionInstaller -Source $fixtureHome -Tools codex -Update -Yes
if ($state.Calls -ne 8 -or $state.Default -ne 4 -or $state.Account -ne 4) { throw 'Incorrect update target count' }
if ($env:CODEX_HOME -ne $inheritedAccount) { throw 'Caller config environment changed' }
'standalone update passed'
'@ | Set-Content -LiteralPath $runner
    foreach ($runtime in $runtimes) {
        $result = Invoke-ClosedInput -Command @($runtime, '-NoProfile', '-File', $runner, '-Installer', $standalone)
        Assert-Equal 0 $result.ExitCode 'Standalone account update works in each PowerShell runtime'
        Assert-True ($result.Output -contains 'standalone update passed') 'Standalone update uses fakes and preserves account environment'
    }

    # The expanded archive entry point lists the fake CLI during update preview.
    if ($env:OS -eq 'Windows_NT') {
        @('@echo off', ('"' + $fixturePwshExe + '" -NoProfile -File "%~dp0listing.ps1" codex %*')) |
            Set-Content -LiteralPath (Join-Path $fakeBin 'codex.cmd')
    } else {
        "#!/bin/sh`nexec pwsh -NoProfile -File '$listingScript' codex `"`$@`"" | Set-Content -LiteralPath (Join-Path $fakeBin 'codex')
    }
    'param($Installer); $selected = Join-Path (Split-Path $Installer) selected; New-Item -ItemType Directory -Path $selected -Force | Out-Null; & $Installer -Update -DryRun -Tools codex -ConfigDir $selected -Source (Split-Path $Installer)' |
        Set-Content -LiteralPath $runner
    foreach ($runtime in $runtimes) {
        $result = Invoke-ClosedInput -Command @($runtime, '-NoProfile', '-File', $runner, '-Installer', $standalone)
        Assert-Equal 0 $result.ExitCode 'Expanded archive entry accepts update preview'
        $selected = Join-Path (Split-Path $standalone) 'selected'
        Assert-True ($result.Output -contains "CODEX_HOME=$selected codex plugin add legion@ps-legion-marketplace") 'Expanded archive forwards update mode'
        Assert-True (-not (($result.Output -join "`n").Contains('marketplace add'))) 'Update preview does not add marketplaces'
    }

    # No CLI discovery must show hints and return normally, without touching any real CLI.
    function Ensure-InstallPowerShell { return $true }
    function Test-InstallCommandAvailable { param($Name) return $false }
    $noTools = @(Invoke-LegionInstaller -Catalog $script:installCatalog) -join "`n"
    foreach ($hint in @('irm https://claude.ai/install.ps1 | iex','npm install -g @openai/codex','npm install -g @github/copilot')) {
        Assert-True ($noTools.Contains($hint)) 'No installed CLI prints official install hint'
    }
} finally {
    $env:PATH = $savedPath
    Remove-InstallTestFolder $sandbox
}
