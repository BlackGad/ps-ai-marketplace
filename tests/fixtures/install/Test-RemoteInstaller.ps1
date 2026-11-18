param([string]$Installer, [string]$Repo)
$fixtureInstaller = $Installer
. $fixtureInstaller -NoRun
$script:installCatalog = Get-Content (Join-Path $Repo 'tests/fixtures/install/catalog.json') -Raw | ConvertFrom-Json
# The standalone contract also runs in the legacy fixture process.
& {
    $catalog = Get-InstallCatalog -Catalog $script:installCatalog
    $fourth = Get-Content (Join-Path $Repo 'tests/fixtures/tools/ps-ai-fourth/tool.json') -Raw | ConvertFrom-Json
    $catalog.tools += [pscustomobject]@{id='fourth';command='fourth-cli';configEnv='FOURTH_HOME';plugin=$fourth.plugin;hooks=$fourth.hooks;installHint='fixture only'}
    $script:installCatalog = Get-InstallCatalog -Catalog $catalog
    Assert-Equal 'fourth-cli|plugin|marketplace|add|local source' ((Get-InstallCommands fourth 'local source')[0] -join '|') 'Standalone fourth command uses catalog'
    Assert-True (-not (Test-InstallListing -Kind plugin -Tool claude -Lines @('[{"id":"ps-ai@ps-ai-marketplace","enabled":"true"}]'))) 'Legacy JSON rejects string true'
    function Ensure-InstallPowerShell { throw 'Invalid metadata reached bootstrap' }
    foreach ($field in @('wingetId','portableCommand')) {
        $bad = $catalog | ConvertTo-Json -Depth 100 | ConvertFrom-Json
        $bad.bootstrap.windows.$field = $null
        $message = ''
        try { Invoke-PsAiInstaller -Catalog $bad -DryRun } catch { $message=$_.Exception.Message }
        Assert-True ($message -match 'invalid catalog field') 'Legacy invalid bootstrap stops before action'
    }
}
$script:installCatalog = Get-Content (Join-Path $Repo 'tests/fixtures/install/catalog.json') -Raw | ConvertFrom-Json
# RootBootstrapUsesLatestZipRecipe: change id, source, pattern and layout together.
$script:installCatalog.bootstrap.windows.wingetId = 'Example.PowerShell'
$script:installCatalog.bootstrap.windows.portableCommand = 'bin/shell.exe'
$script:installCatalog.bootstrap.windows.download.zip.metadataUrl = 'https://fixture.test/latest'
$script:installCatalog.bootstrap.windows.download.zip.assetPattern = '^Shell-[\d.]+-x64\.zip$'
$script:installCatalog.bootstrap.windows.download.zip.pathFolder = 'bin'
& {
    $state = @{ Command='' }
    function Invoke-ClosedInput { param($Command) $state.Command=$Command -join '|'; return @{ExitCode=0;Output=@()} }
    Assert-Equal 0 (Invoke-InstallWinget) 'Catalog winget command succeeds'
    Assert-Equal 'winget|install|--id|Example.PowerShell|-e' $state.Command 'Winget id is catalog data'
}
$sandbox = Join-Path $Repo ('.agents/temp/restructure/remote-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
$savedPath = $env:PATH
$fixturePwshExe = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
$legacy = Get-Command powershell.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$state = @{ Present=$false; Winget=$false; WingetExit=5; Calls=0; Downloads=0; Digest=('0' * 64); UserPath='C:\existing'; Writes=0; Prompts=0; Answer='n' }
$downloaded = [Collections.Generic.List[string]]::new()
function Get-InstallHome { $sandbox }
function Get-InstallPowerShellCommand {
    if ($state.Present) { return @{ Source='fixture-pwsh' } }
    $portable = Join-Path $sandbox '.agents/tools/pwsh/bin/shell.exe'
    if (Test-Path -LiteralPath $portable) { return @{ Source=$portable } }
}
function Test-InstallCommandAvailable { param($Name) $Name -eq 'winget' -and $state.Winget }
function Invoke-InstallWinget { $state.Calls++; return $state.WingetExit }
function Get-InstallUserPath { $state.UserPath }
function Set-InstallUserPath { param($Path) $state.Writes++; $state.UserPath = $Path }
function Read-Host { param($Prompt) $state.Prompts++; return $state.Answer }
function Invoke-InstallDownload {
    param($Url, $OutFile)
    $state.Downloads++
    $downloaded.Add($OutFile)
    if ($Url -eq 'https://fixture.test/latest') {
        @{ tag_name='v7.7.0'; assets=@(@{ name='Shell-7.7.0-x64.zip'; browser_download_url='https://fixture.test/pwsh.zip'; digest=$state.Digest }) } |
            ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutFile
    } elseif ($Url -eq 'https://fixture.test/pwsh.zip') { Copy-Item -LiteralPath $fixtureArchive -Destination $OutFile }
    else { throw "unexpected test download: $Url" }
}
try {
    $preview = @(& { $script:ready = Ensure-InstallPowerShell -OnWindows $true -DryRun } 6>&1) -join "`n"
    Assert-True ($preview.Contains('winget install --id Example.PowerShell -e')) 'Missing pwsh dry run shows winget'
    Assert-True ($preview.Contains('SHA-256')) 'Missing pwsh dry run shows ZIP option'
    Assert-Equal 0 $state.Downloads 'Dry run has no network'
    Assert-Equal 0 $state.Calls 'Dry run never runs winget'
    Assert-Equal 0 $state.Prompts 'Dry run never prompts'
    Assert-Equal 0 $state.Writes 'Dry run never writes user PATH'
    Assert-Equal $savedPath $env:PATH 'Dry run preserves process PATH'
    $state.Present = $true
    $skip = @(& { $script:ready = Ensure-InstallPowerShell -OnWindows $true } 6>&1) -join "`n"
    Assert-True $script:ready 'Present pwsh is ready'
    Assert-True ($skip.Contains('skip: PowerShell 7 (already done)')) 'Present pwsh skips'
    Assert-Equal 0 $state.Downloads 'Present pwsh never downloads'
    $state.Present = $false
    $null = & { $script:ready = Ensure-InstallPowerShell -OnWindows $true } 6>&1
    Assert-True (-not $script:ready) 'Declined install stops'
    Assert-Equal 0 $state.Downloads 'Declined install never downloads'
    $docs = @(& { $script:ready = Ensure-InstallPowerShell -OnWindows $false -Yes } 6>&1) -join "`n"
    Assert-True (-not $script:ready) 'Non-Windows missing pwsh stops'
    Assert-True ($docs.Contains('https://learn.microsoft.com/powershell/scripting/install/')) 'Non-Windows gives official install link'
    Assert-Equal 0 $state.Downloads 'Non-Windows never downloads'

    $archiveFolder = Join-Path $sandbox 'archive'
    New-Item -ItemType Directory -Path (Join-Path $archiveFolder 'bin') -Force | Out-Null
    'inert fixture, never execute' | Set-Content -LiteralPath (Join-Path $archiveFolder 'bin/shell.exe')
    $fixtureArchive = Join-Path $sandbox 'fixture.zip'
    Compress-Archive -Path (Join-Path $archiveFolder '*') -DestinationPath $fixtureArchive
    $state.Digest = 'sha256:' + ('0' * 64)
    $failure = ''
    try { $null = Ensure-InstallPowerShell -OnWindows $true -Yes } catch { $failure = $_.Exception.Message }
    Assert-True ($failure -match 'SHA-256.*mismatch') 'Digest mismatch stops installation'
    Assert-True (-not (Test-Path -LiteralPath $downloaded[$downloaded.Count - 1])) 'Digest mismatch deletes download'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $sandbox '.agents/tools/pwsh'))) 'Digest mismatch never unpacks'
    Assert-Equal 0 $state.Writes 'Digest mismatch never writes PATH'
    Assert-Equal $savedPath $env:PATH 'Digest mismatch preserves process PATH'
    $state.Digest = ''
    Assert-Throws { Ensure-InstallPowerShell -OnWindows $true -Yes | Out-Null } 'Missing digest stops installation'
    $state.Digest = 'sha256:' + (Get-FileHash -LiteralPath $fixtureArchive -Algorithm SHA256).Hash.ToLowerInvariant()
    $state.Winget = $true
    $null = & { $script:ready = Ensure-InstallPowerShell -OnWindows $true -Yes } 6>&1
    Assert-True $script:ready 'Failed winget falls back to verified ZIP'
    Assert-Equal 1 $state.Calls 'Winget tried once before ZIP'
    $portableFolder = Join-Path $sandbox '.agents/tools/pwsh/bin'
    Assert-True (Test-Path -LiteralPath (Join-Path $portableFolder 'shell.exe')) 'Verified ZIP unpacks per user'
    Assert-True ($state.UserPath.Contains($portableFolder)) 'ZIP adds user PATH'
    Assert-True ($env:PATH.Contains($portableFolder)) 'ZIP adds process PATH'
    Assert-Equal 1 $state.Writes 'ZIP writes user PATH once'
    $downloadCount = $state.Downloads
    $null = & { Ensure-InstallPowerShell -OnWindows $true -Yes } 6>&1
    Add-InstallPowerShellPath -Path $portableFolder
    Assert-Equal $downloadCount $state.Downloads 'Repeat ZIP installation never downloads'
    Assert-Equal 1 $state.Writes 'Repeat ZIP installation never duplicates user PATH'
    Assert-Equal 1 @($env:PATH -split [regex]::Escape([IO.Path]::PathSeparator) | Where-Object { $_ -eq $portableFolder }).Count 'Process PATH contains folder once'

    # Run a copied, standalone script from script text, with no repository context or real CLIs.
    $fakeBin = Join-Path $sandbox 'fake-bin'
    New-Item -ItemType Directory -Path $fakeBin | Out-Null
    if ($env:OS -eq 'Windows_NT') {
        foreach ($tool in @('claude','codex','copilot')) { '@echo off' | Set-Content -LiteralPath (Join-Path $fakeBin "$tool.cmd") }
    } else {
        foreach ($tool in @('claude','codex','copilot')) {
            $fake = Join-Path $fakeBin $tool
            "#!/bin/sh`nexit 0" | Set-Content -LiteralPath $fake
            & chmod +x $fake
        }
    }
    $env:PATH = $fakeBin + [IO.Path]::PathSeparator + (Split-Path $fixturePwshExe -Parent)
    $standalone = Join-Path $sandbox 'install.ps1'
    Copy-Item -LiteralPath $fixtureInstaller -Destination $standalone
    Copy-Item -LiteralPath (Join-Path $Repo 'tests/fixtures/install/catalog.json') -Destination (Join-Path $sandbox 'tools.json')
    $runner = Join-Path $sandbox 'invoke-text.ps1'
    'param($Installer); & ([scriptblock]::Create((Get-Content -Raw $Installer))) -DryRun -Tools codex -Source (Split-Path $Installer)' | Set-Content -LiteralPath $runner
    $result = Invoke-ClosedInput -Command @($fixturePwshExe, '-NoProfile', '-File', $runner, '-Installer', $standalone)
    $output = $result.Output
    Assert-Equal 0 $result.ExitCode 'Script text runs standalone without repository context'
    Assert-Equal 1 @($output | Where-Object { "$_" -eq 'Codex: approve the ps-ai hooks once with /hooks in a Codex session.' }).Count 'Codex prints hook approval reminder once'
    if ($legacy) {
        $result = Invoke-ClosedInput -Command @($legacy.Source, '-NoProfile', '-File', $fixtureInstaller, '-DryRun', '-Source', $Repo, '-Tools', 'claude')
        $output = $result.Output
        Assert-Equal 0 $result.ExitCode 'Root installer runs under Windows PowerShell 5.1'
        Assert-True (($output -join "`n").Contains('claude plugin marketplace add')) 'Windows PowerShell 5.1 previews CLI command'
    } else { Write-Output 'SKIP Windows PowerShell 5.1 (powershell.exe unavailable)' }

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
    if ($legacy) { $runtimes += $legacy.Source }
    foreach ($runtime in $runtimes) {
        $result = Invoke-ClosedInput -Command @($runtime, '-NoProfile', '-File', $runner, '-Installer', $standalone)
        Assert-Equal 0 $result.ExitCode 'Closed-input CLI process succeeds and restores account environment'
        Assert-Equal 'space value|selected account|0' ($result.Output -join '') 'CLI receives spaced argument, selected account, and EOF on stdin'
    }

    # No CLI discovery must show hints and return normally, without touching any real CLI.
    function Ensure-InstallPowerShell { return $true }
    function Test-InstallCommandAvailable { param($Name) return $false }
    $noTools = @(Invoke-PsAiInstaller -Catalog $script:installCatalog) -join "`n"
    foreach ($hint in @('irm https://claude.ai/install.ps1 | iex','npm install -g @openai/codex','npm install -g @github/copilot')) {
        Assert-True ($noTools.Contains($hint)) 'No installed CLI prints official install hint'
    }
} finally {
    $env:PATH = $savedPath
    $resolved = [IO.Path]::GetFullPath($sandbox)
    $allowed = [IO.Path]::GetFullPath((Join-Path $Repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'unsafe test cleanup path' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
