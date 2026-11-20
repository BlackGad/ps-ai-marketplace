$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$setupScript = Join-Path $root 'plugins/ps-ai/bin/ps-ai-setup.ps1'
$tempRoot = Join-Path $root ('.agents/temp/setup-' + [guid]::NewGuid().ToString('N'))
$savedPath = $env:PATH
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

function Assert-SetupText {
    param($Output, [string]$Text, [string]$Message)
    Assert-True (($Output -join "`n").Contains($Text)) $Message
}

function Get-SetupTree {
    param([string]$Folder)
    return (@(Get-ChildItem -LiteralPath $Folder -Force -Recurse | Sort-Object FullName | ForEach-Object {
        # Windows can update directory timestamps lazily after child writes; compare their paths only.
        if ($_.PSIsContainer) { $_.FullName + ':directory' }
        else { $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash + ':' + $_.LastWriteTimeUtc.Ticks }
    }) -join '|')
}

try {
    . $setupScript -NoRun
    $realFindInstaller = ${function:Find-SetupInstaller}
    $realInvokeInstaller = ${function:Invoke-SetupInstaller}
    $fakeBin = Join-Path $tempRoot 'tools'
    New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
    foreach ($tool in @('claude', 'codex', 'copilot', 'claude1')) {
        $path = Join-Path $fakeBin $(if ($IsWindows) { "$tool.cmd" } else { $tool })
        $text = if ($IsWindows) { '@exit /b 99' } else { "#!/bin/sh`nexit 99`n" }
        [IO.File]::WriteAllText($path, $text)
        if (-not $IsWindows) { & chmod +x $path }
    }
    $systemBin = if ($IsWindows) { Join-Path $env:SystemRoot 'System32' } else { '/usr/bin' }
    $fixturePath = @($fakeBin, (Split-Path (Get-Command pwsh -CommandType Application).Source), $systemBin) -join [IO.Path]::PathSeparator
    $env:PATH = $fixturePath
    $version = (Get-Content (Join-Path $root 'plugins/ps-ai/plugin.json') -Raw | ConvertFrom-Json).version

    # All machine, CLI and network seams are inert; account creation still runs the real child script.
    function Test-SetupCommand { param($Name) return ($Name -cnotin $script:missingTools) }
    function Get-SetupUserPath { return $script:userPath }
    function Set-SetupUserPath { param($Value) $script:pathWrites.Add($Value); $script:userPath = $Value }
    function Find-SetupInstaller { return (Join-Path $tempRoot 'inert-installer.ps1') }
    function Save-SetupInstaller { param($Path) $script:downloads.Add($Path); [IO.File]::WriteAllText($Path, '# inert') }
    function Invoke-SetupToolInstall {
        param($Tool)
        $script:toolInstalls.Add($Tool)
        if ($script:toolFailure) { return @{ Ok = $false; Message = "fixture failure`nsecond line" } }
        if (-not $script:needsTerminal) { $script:missingTools = @($script:missingTools | Where-Object { $_ -cne $Tool }) }
        return @{ Ok = $true; Message = 'installed' }
    }
    function Invoke-SetupInstaller {
        param($Installer, $Tool, $ConfigDir)
        $script:installs.Add(@{ Installer = $Installer; Tool = $Tool; ConfigDir = $ConfigDir })
        if ($script:failFolder -ceq $ConfigDir) { return 1 }
        $descriptor = Get-PsAiTool -Tool $Tool
        $manifest = Join-Path $ConfigDir "$($descriptor.plugin.installedRoot)/$version/plugin.json"
        New-Item -ItemType Directory -Path (Split-Path $manifest) -Force | Out-Null
        @{ name = 'ps-ai'; version = $version } | ConvertTo-Json | Set-Content -LiteralPath $manifest
        return 0
    }
    function Reset-SetupTest {
        param([string]$Name)
        $script:testHome = Join-Path $tempRoot $Name
        New-Item -ItemType Directory -Path $script:testHome -Force | Out-Null
        $script:settings = Join-Path $script:testHome '.legion/configuration/ps-ai-personalisation.json'
        $script:userPath = 'fixture-path'
        $script:pathWrites = [Collections.Generic.List[string]]::new()
        $script:toolInstalls = [Collections.Generic.List[string]]::new()
        $script:installs = [Collections.Generic.List[object]]::new()
        $script:downloads = [Collections.Generic.List[string]]::new()
        $script:missingTools = @()
        $script:toolFailure = $false
        $script:needsTerminal = $false
        $script:failFolder = ''
        $env:PATH = $fixturePath
    }

    Reset-SetupTest 'empty'
    $before = Get-SetupTree $testHome
    $plan = @(Invoke-Setup -HomeRoot $testHome)
    foreach ($text in @('Plan (nothing changed yet):', '  create   settings and notes', '  commands write ps-ai-setup, ps-ai-status, ps-ai-overseer, legion', '  path     ', 'Run again with -Yes to apply.')) {
        Assert-SetupText $plan $text 'Fresh empty plan has the contract lines'
    }
    Assert-Equal $before (Get-SetupTree $testHome) 'Plan changes no home bytes or timestamps'
    $apply = @(Invoke-Setup -HomeRoot $testHome -Yes)
    Assert-Equal 0 (@(Invoke-PsAiValidation -Kind personalisation -Path $settings).Count) 'Empty settings are valid'
    Assert-Equal 0 (@((Read-PsAiJson $settings).agents).Count) 'Fresh setup supports no accounts'
    Assert-Equal ([IO.File]::ReadAllText((Join-Path $root 'plugins/ps-ai/skills/ps-ai-personalisation/references/notes-template.md'))) ([IO.File]::ReadAllText((Join-Path (Split-Path $settings) 'ps-ai-notes.md'))) 'Notes use the unchanged template'
    if (-not $IsWindows) { $env:PATH += [IO.Path]::PathSeparator + (Join-Path $testHome '.legion/bin') }
    $before = Get-SetupTree $testHome
    $repeat = @(Invoke-Setup -HomeRoot $testHome -Yes)
    Assert-Equal 0 (@($repeat | Where-Object { -not $_.StartsWith('skip:') }).Count) 'Empty repeat prints only skips'
    Assert-Equal $before (Get-SetupTree $testHome) 'Empty repeat changes nothing'
    Assert-Equal 'Nothing to do.' (@(Invoke-Setup -HomeRoot $testHome)[-1]) 'Finished plan ends in Nothing to do'

    Reset-SetupTest 'accounts'
    $adopt = Join-Path $testHome 'my codex'
    New-Item -ItemType Directory -Path $adopt -Force | Out-Null
    'keep login data' | Set-Content (Join-Path $adopt 'owner.txt')
    $before = Get-SetupTree $testHome
    $planWatch = [Diagnostics.Stopwatch]::StartNew()
    $plan = @(Invoke-Setup -HomeRoot $testHome -Add @('claude', "codex:$adopt"))
    $planWatch.Stop()
    Assert-SetupText $plan '  add      claude2 (claude) new folder' 'Auto id skips application claude1'
    Assert-SetupText $plan "  add      codex1 (codex) existing folder $adopt" 'Adoption keeps spaces and drive colon'
    Assert-SetupText $plan '  install  ps-ai into ' 'Plan groups plugin installs'
    Assert-Equal $before (Get-SetupTree $testHome) 'Account plan changes no bytes or timestamps'
    Remove-Item -LiteralPath (Join-Path $fakeBin $(if ($IsWindows) { 'claude1.cmd' } else { 'claude1' }))
    $applyWatch = [Diagnostics.Stopwatch]::StartNew()
    $apply = @(Invoke-Setup -HomeRoot $testHome -Add @('claude', "codex:$adopt") -Yes)
    $applyWatch.Stop()
    $agents = (Read-PsAiJson $settings).agents
    Assert-Equal 'claude1|codex1' ($agents.id -join '|') 'Fresh apply records both accounts'
    Assert-Equal 2 $installs.Count 'Installer runs once per account folder'
    Assert-Equal $adopt $installs[1].ConfigDir 'Installer receives the whole adopted path'
    Assert-Equal 'keep login data' (Get-Content (Join-Path $adopt 'owner.txt')) 'Adoption preserves existing data'
    Assert-SetupText $apply 'account  tool  folder  ps-ai  next step' 'Table has the contract columns'
    Assert-SetupText $apply 'log in: run claude1' 'New folder asks for login'
    Assert-SetupText $apply 'ready' 'Adopted folder is ready'
    $bin = Join-Path $testHome '.legion/bin'
    foreach ($entry in (Get-PsAiOwnerCommands).GetEnumerator()) {
        $target = Join-Path $root "plugins/ps-ai/bin/$($entry.Value)"
        Assert-Equal (Get-PsAiShimText -Script $target) ([IO.File]::ReadAllText((Join-Path $bin $entry.Key))) 'Unix command shim equals shared format'
        if ($IsWindows) {
            Assert-Equal (Get-PsAiShimText -Script $target -Windows) ([IO.File]::ReadAllText((Join-Path $bin "$($entry.Key).cmd"))) 'Windows command shim equals shared format'
        }
    }
    Assert-Equal $(if ($IsWindows) { 1 } else { 0 }) $pathWrites.Count 'Only Windows writes user PATH'
    if ($IsWindows) { Assert-Equal "fixture-path;$bin" $pathWrites[0] 'User PATH appends bin' }
    else {
        Assert-SetupText $apply 'add to your shell profile: export PATH="$HOME/.legion/bin:$PATH"' 'Unix prints the profile instruction'
        $env:PATH += [IO.Path]::PathSeparator + $bin
    }
    $before = Get-SetupTree $testHome
    $repeat = @(Invoke-Setup -HomeRoot $testHome -Yes)
    Assert-Equal $before (Get-SetupTree $testHome) 'Repeated apply preserves all bytes and timestamps'
    Assert-Equal 2 $installs.Count 'Repeat does not reinstall ps-ai'
    Assert-Equal 0 $toolInstalls.Count 'Repeat installs no CLI'
    Assert-Equal $(if ($IsWindows) { 1 } else { 0 }) $pathWrites.Count 'Repeat writes no PATH'
    Assert-SetupText $repeat 'skip: ps-ai in ' 'Repeat reports installed folders'
    Assert-SetupText $repeat 'account  tool  folder  ps-ai  next step' 'Repeat keeps the table'
    Assert-Equal ($apply | Where-Object { $_.StartsWith('claude1  ') }) ($repeat | Where-Object { $_.StartsWith('claude1  ') }) 'Repeat retains new-folder login guidance'
    Assert-Equal 'Nothing to do.' (@(Invoke-Setup -HomeRoot $testHome)[-1]) 'Finished account setup needs no changes'
    $next = @(Invoke-Setup -HomeRoot $testHome -Add claude)
    Assert-SetupText $next 'add      claude2' 'Recorded claude1 makes next id claude2'

    Reset-SetupTest 'rejections'
    $before = Get-SetupTree $testHome
    Assert-Throws { Invoke-Setup -HomeRoot $testHome -Add @('claude', 'codex') -Id chosen -Yes } 'Custom id needs exactly one add'
    foreach ($id in (Get-PsAiOwnerCommands).Keys) {
        Assert-Throws { Invoke-Setup -HomeRoot $testHome -Add claude -Id $id -Yes } 'Reserved id rejected'
    }
    Assert-Throws { Invoke-Setup -HomeRoot $testHome -Add @('claude', "codex:$(Join-Path $testHome 'missing')") -Yes } 'Missing adopted folder rejected'
    Assert-Equal $before (Get-SetupTree $testHome) 'All bad input is rejected before any change'
    Assert-Equal 0 $pathWrites.Count 'Bad input does not write PATH'
    Assert-Equal 0 $installs.Count 'Bad input does not install'

    Reset-SetupTest 'partial'
    Invoke-Setup -HomeRoot $testHome -Add claude -Id claude1 -Yes | Out-Null
    $folder = (Read-PsAiJson $settings).agents[0].configDir
    $cache = Join-Path $folder (Get-PsAiTool claude).plugin.installedRoot
    # This cache is a fixture folder created under this test's home.
    Assert-True ([IO.Path]::GetFullPath($cache).StartsWith([IO.Path]::GetFullPath($testHome))) 'Fixture cache stays under test home'
    Remove-Item -LiteralPath $cache -Recurse -Force
    if (-not $IsWindows) { $env:PATH += [IO.Path]::PathSeparator + (Join-Path $testHome '.legion/bin') }
    $plan = @(Invoke-Setup -HomeRoot $testHome)
    Assert-Equal 3 $plan.Count 'Partial earlier run plans only the install'
    Assert-SetupText $plan "  install  ps-ai into $folder" 'Partial setup installs into recorded folder'
    Invoke-Setup -HomeRoot $testHome -Yes | Out-Null
    Assert-Equal 2 $installs.Count 'Partial setup is resumed without Add'
    $repeat = @(Invoke-Setup -HomeRoot $testHome -Add claude -Id claude1 -Yes)
    Assert-SetupText $repeat 'skip: account claude1 (already done)' 'Explicit id repeat skips'
    Assert-Equal 2 $installs.Count 'Explicit repeat does not reinstall'
    $adoptedPlan = @(Invoke-Setup -HomeRoot $testHome -Add "claude:$folder" -Id adopted -Yes)
    Assert-SetupText $adoptedPlan "skip: ps-ai in $folder (already done)" 'Adopted current plugin is skipped'

    foreach ($scenario in @('success', 'failure', 'terminal')) {
        Reset-SetupTest "cli-$scenario"
        $c2 = Join-Path $testHome 'c2'
        New-Item -ItemType Directory -Path $c2 -Force | Out-Null
        $script:missingTools = @('codex')
        $script:toolFailure = $scenario -eq 'failure'
        $script:needsTerminal = $scenario -eq 'terminal'
        $plan = @(Invoke-Setup -HomeRoot $testHome -Add @('codex', "codex:$c2", 'claude'))
        Assert-SetupText $plan 'cli      install codex' 'Missing CLI appears in plan'
        Assert-Equal 0 $toolInstalls.Count 'Plan never installs a CLI'
        $global:LASTEXITCODE = 7
        $output = @(Invoke-Setup -HomeRoot $testHome -Add @('codex', "codex:$c2", 'claude') -Yes)
        Assert-Equal 0 $LASTEXITCODE 'Recoverable install result exits zero'
        Assert-Equal 'codex' ($toolInstalls -join '|') 'Missing CLI installs once for several accounts'
        $agents = (Read-PsAiJson $settings).agents
        if ($scenario -eq 'success') {
            Assert-Equal 'codex1|codex2|claude1' ($agents.id -join '|') 'Rechecked CLI permits both accounts'
            Assert-Equal 3 $installs.Count 'All usable accounts install ps-ai'
        } else {
            Assert-Equal 'claude1' ($agents.id -join '|') 'Unusable CLI records no accounts while independent tool completes'
            Assert-Equal 1 $installs.Count 'Only usable CLI gets plugin installation'
            $expected = if ($scenario -eq 'failure') { 'codex install failed: fixture failure second line' } else { 'codex installed: open a new terminal, then finish setup' }
            Assert-SetupText $output $expected 'CLI failure or terminal row explains next step'
            Assert-True (-not (Test-Path (Join-Path $testHome '.legion/agents/codex1'))) 'Unusable CLI does not create an account folder'
        }
    }

    Reset-SetupTest 'plugin-failure'
    $script:failFolder = Join-Path $testHome '.legion/agents/claude1'
    $output = @(Invoke-Setup -HomeRoot $testHome -Add @('claude', 'codex') -Yes)
    Assert-SetupText $output 'install failed: log in with claude1, then finish setup' 'Plugin failure gives login fallback'
    Assert-Equal 2 $installs.Count 'Next folder installs after plugin failure'
    Assert-Equal 0 $LASTEXITCODE 'Plugin failure is a recoverable table row'

    Reset-SetupTest 'commands'
    $bin = Join-Path $testHome '.legion/bin'
    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    $owned = Join-Path $bin 'ps-ai-status'
    $oldText = Get-PsAiShimText -Script '/old/cache/bin/ps-ai-status.ps1'
    [IO.File]::WriteAllText($owned, $oldText)
    [IO.File]::WriteAllText((Join-Path $bin 'legion'), 'owner command')
    $output = @(Invoke-Setup -HomeRoot $testHome -Yes)
    Assert-Equal $oldText ([IO.File]::ReadAllText($owned)) 'Existing owned command is kept for refresh'
    Assert-Equal 'owner command' ([IO.File]::ReadAllText((Join-Path $bin 'legion'))) 'Unrelated command stays unchanged'
    Assert-SetupText $output 'skip: command ps-ai-status (already done)' 'Existing owned command reports skip'
    Assert-SetupText $output 'blocked: command legion (another file is there)' 'Unrelated command reports blocked'
    Assert-SetupText $output 'Blocked commands: legion' 'Blocked command is listed after table'

    Reset-SetupTest 'finder-failure'
    $script:findCalls = 0
    function Find-SetupInstaller { $script:findCalls++; throw 'fixture download failure' }
    $output = @(Invoke-Setup -HomeRoot $testHome -Add @('claude', 'codex') -Yes)
    Assert-Equal 1 $findCalls 'Installer discovery failure is attempted only once for the run'
    Assert-Equal 0 $installs.Count 'A missing installer is never invoked'
    Assert-SetupText $output 'install failed: log in with claude1, then finish setup' 'Discovery failure produces first fallback row'
    Assert-SetupText $output 'install failed: log in with codex1, then finish setup' 'Discovery failure still produces next fallback row'

    # Search only in fixture roots, and replace download even while testing the real finder.
    Reset-SetupTest 'search'
    $script:SetupHomeRoot = $testHome
    $script:SetupPluginRoot = Join-Path $testHome 'clone/plugins/ps-ai'
    New-Item -ItemType Directory -Path $script:SetupPluginRoot -Force | Out-Null
    $clone = Join-Path $testHome 'clone/install.ps1'
    $claudeCopy = Join-Path $testHome '.claude/plugins/marketplaces/ps-ai-marketplace/install.ps1'
    $codexCopy = Join-Path $testHome '.codex/.tmp/marketplaces/ps-ai-marketplace/install.ps1'
    foreach ($path in @($clone, $claudeCopy, $codexCopy)) {
        New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
        '# inert' | Set-Content -LiteralPath $path
    }
    foreach ($expected in @($clone, $claudeCopy, $codexCopy)) {
        Assert-Equal ([IO.Path]::GetFullPath($expected)) (& $realFindInstaller) 'Installer search prefers next existing local copy'
        Remove-Item -LiteralPath $expected
    }
    $fallback = Join-Path $testHome '.legion/temp/install.ps1'
    Assert-Equal $fallback (& $realFindInstaller) 'Finder falls back to download under chosen home'
    Assert-Equal $fallback (& $realFindInstaller) 'Finder reuses download during the run'
    Assert-Equal 1 $downloads.Count 'Fallback downloads once'
    $script:SetupDownloadedInstaller = $null
    & $realFindInstaller | Out-Null
    Assert-Equal 2 $downloads.Count 'A new run refreshes a previously downloaded installer'

    # Exercise the real process boundary against an inert script: flags, closed stdin and captured output.
    $standIn = Join-Path $testHome 'stand in.ps1'
    @'
param([string]$Tools, [string]$ConfigDir, [switch]$Update, [switch]$Yes)
@{ Tools=$Tools; ConfigDir=$ConfigDir; Update=[bool]$Update; Yes=[bool]$Yes; StdinClosed=([Console]::In.ReadToEnd() -eq '') } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ConfigDir 'args.json')
'inert installer output'
exit 3
'@ | Set-Content -LiteralPath $standIn
    $code = & $realInvokeInstaller -Installer $standIn -Tool codex -ConfigDir $testHome
    Assert-Equal 3 $code 'Installer seam returns child exit code'
    $bound = Read-PsAiJson (Join-Path $testHome 'args.json')
    Assert-Equal 'codex' $bound.Tools 'Installer receives -Tools'
    Assert-Equal $testHome $bound.ConfigDir 'Installer receives config folder intact'
    Assert-True ($bound.Update -and $bound.Yes -and $bound.StdinClosed) 'Installer receives update, consent and closed stdin'
    Assert-SetupText (Get-Content (Join-Path $testHome '.legion/temp/setup-install-codex.log')) 'inert installer output' 'Installer output goes to chosen-home log'
    Write-Output "Setup fake timings: plan $([math]::Round($planWatch.Elapsed.TotalSeconds, 3)) s; apply $([math]::Round($applyWatch.Elapsed.TotalSeconds, 3)) s"
} finally {
    $env:PATH = $savedPath
    # The generated absolute fixture root is inside the assigned worktree.
    if ([IO.Path]::GetFullPath($tempRoot).StartsWith([IO.Path]::GetFullPath((Join-Path $root '.agents/temp/')))) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
