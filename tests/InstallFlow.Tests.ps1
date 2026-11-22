# Install flow: accounts, target folders, consent, refs, finish and progress.
. (Join-Path $PSScriptRoot 'lib/installer.ps1')

Invoke-InstallTestCase 'Install' {
    $fixtureConfig0 = Join-Path $env:HOME 'selected-account'
    New-Item -ItemType Directory -Path $fixtureConfig0 -Force | Out-Null
    $fixtureConfig1 = Join-Path $env:HOME 'fixture-account'
    New-Item -ItemType Directory -Path $fixtureConfig1 -Force | Out-Null
    . (Join-Path $PSScriptRoot 'fixtures/install/MarketplaceListing.ps1')
    $script = Join-Path $repo 'plugins/legion/install.ps1'
    . $script -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $expected = @{
        claude = @('claude|plugin|marketplace|add|local source', 'claude|plugin|install|legion@ps-legion-marketplace')
        codex = @('codex|plugin|marketplace|add|local source', 'codex|plugin|add|legion@ps-legion-marketplace')
        copilot = @('copilot|plugin|marketplace|add|local source', 'copilot|plugin|install|legion@ps-legion-marketplace')
    }
    foreach ($tool in @('claude', 'codex', 'copilot')) {
        $commands = Get-InstallCommands -Tool $tool -Source 'local source'
        Assert-Equal 2 $commands.Count "$tool has two commands"
        Assert-Equal $expected[$tool][0] ($commands[0] -join '|') "$tool marketplace command"
        Assert-Equal $expected[$tool][1] ($commands[1] -join '|') "$tool install command"
        Assert-Equal 'local source' $commands[0][4] "$tool source with space remains one argument"
    }
    $previewLines = @(& {
        function Test-InstallStepDone { $false }
        Invoke-LegionInstaller -Tools claude -Source 'local source' -ConfigDir X -DryRun -Catalog (Get-Content (Join-Path $PSScriptRoot 'fixtures/install/catalog.json') -Raw | ConvertFrom-Json)
    })
    Assert-True $? 'Injected dry run succeeds'
    Assert-True ($previewLines -contains 'CLAUDE_CONFIG_DIR=X claude plugin marketplace add "local source"') 'Dry run marketplace command'
    Assert-True ($previewLines -contains 'CLAUDE_CONFIG_DIR=X claude plugin install legion@ps-legion-marketplace') 'Dry run plugin command'

    & {
        . $script -NoRun
        function Ensure-InstallPowerShell { return $true }
        function Get-InstallHome { Join-Path $repo '.agents/temp/install-selected-account' }
        function Get-InstallUserPath { Get-InstallLegionPath 'bin' }
        function Add-LegionUserPath { }
        function Invoke-InstallRefresh { }
        function Get-InstallPluginRoot { Join-Path $repo 'plugins/legion' }
        function codex { param($Version) Assert-Equal '--version' $Version 'Fake CLI only handles version'; 'fixture-version' }
        $calls = [Collections.Generic.List[string]]::new()
        function Invoke-ClosedInput {
            param([string[]]$Command, $Environment)
            Assert-Equal $fixtureConfig0 $Environment.CODEX_HOME 'Install uses selected account for checks and writes'
            $calls.Add(($Command -join '|'))
            if ($Command -contains 'marketplace' -and $Command -contains 'list') {
                return @{ ExitCode=0; Output=@(Get-FixtureMarketplaceListing -Tool codex) }
            }
            return @{ ExitCode=0; Output=@() }
        }
        $previous = $env:CODEX_HOME
        try {
            $env:CODEX_HOME = 'default-account'
            $null = Invoke-LegionInstaller -Tools codex -Source $repo -ConfigDir $fixtureConfig0 -Yes
            Assert-Equal 4 $calls.Count 'Fake install checks and performs both steps'
            Assert-True ($calls -contains 'codex|plugin|add|legion@ps-legion-marketplace') 'Fake install performs plugin write'
            Assert-Equal 'default-account' $env:CODEX_HOME 'Install restores caller account'
        } finally { $env:CODEX_HOME = $previous }
    }
    try {
        Get-InstallCommands -Tool other -Source . | Out-Null
        throw 'Expected unknown tool'
    } catch {
        Assert-Equal "unknown tool 'other'" $_.Exception.Message 'Unknown tool error'
    }

    # Real listings captured 2026-11-18 (Codex 0.167, Copilot 1.0.109, Claude 2.1.325).
    $codexAvailable = 'legion@ps-legion-marketplace  not installed           C:\repo\plugins\legion'
    $codexInstalled = 'legion@ps-legion-marketplace  installed, enabled  0.1.0    C:\repo\plugins\legion'
    $copilotDisabled = '  • legion@ps-legion-marketplace (v0.1.0) (disabled)'
    $copilotEnabled = '  • legion@ps-legion-marketplace (v0.1.0) (enabled)'
    Assert-True (-not (Test-InstallListing -Kind plugin -Tool codex -Lines @($codexAvailable))) 'Available Codex plugin is not installed'
    Assert-True (Test-InstallListing -Kind plugin -Tool codex -Lines @($codexInstalled)) 'Installed Codex plugin counts'
    Assert-True (-not (Test-InstallListing -Kind plugin -Tool copilot -Lines @($copilotDisabled))) 'Disabled Copilot plugin is not done'
    Assert-True (Test-InstallListing -Kind plugin -Tool copilot -Lines @($copilotEnabled)) 'Enabled Copilot plugin counts'
    $disabledFixture = Get-Content (Join-Path $PSScriptRoot 'fixtures/claude-plugin-disabled.json')
    Assert-True (-not (Test-InstallListing -Kind plugin -Tool claude -Lines $disabledFixture)) 'Disabled Claude JSON plugin is not done'
    $enabledFixture = ($disabledFixture -join "`n").Replace('"enabled": false', '"enabled": true') -split "`n"
    Assert-True (Test-InstallListing -Kind plugin -Tool claude -Lines $enabledFixture) 'Enabled Claude JSON plugin is done'
    $script:observedClaudeList = ''
    function Invoke-ClosedInput {
        param([string[]]$Command, $Environment)
        $script:observedClaudeList = $Command -join '|'
        return @{ ExitCode = 0; Output = $disabledFixture }
    }
    Assert-True (-not (Test-InstallStepDone -Command @('claude', 'plugin', 'install', 'legion@ps-legion-marketplace'))) 'Disabled Claude plugin requires install'
    Assert-Equal 'claude|plugin|list|--json' $script:observedClaudeList 'Claude check requests JSON listing'

    $script:installedSteps = @{}
    function Test-InstallStepDone {
        param([string[]]$Command, [string]$ConfigEnv, [string]$ConfigDir)
        return [bool]$script:installedSteps[$Command -join '|']
    }
    function Invoke-InstallCommand {
        param([string[]]$Command, [string]$ConfigEnv, [string]$ConfigDir)
        $script:installedSteps[$Command -join '|'] = $true
        'installed'
    }
    $firstInstall = @(Invoke-LegionInstallSteps -Tool codex -Source 'local source' -ConfigEnv CODEX_HOME -ConfigDir $fixtureConfig1)
    Assert-Equal 3 @($firstInstall | Where-Object { $_ -eq 'installed' }).Count 'First install adds and refreshes marketplace, then installs plugin'
    $secondInstall = @(Invoke-LegionInstallSteps -Tool codex -Source 'local source' -ConfigEnv CODEX_HOME -ConfigDir $fixtureConfig1)
    Assert-Equal 2 @($secondInstall | Where-Object { $_ -match '^skip: .*\(already done\)$' }).Count 'Second install skips both steps'

    # Listing checks must inspect the selected account rather than the caller's default account.
    . $script -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $savedCodexHome = $env:CODEX_HOME
    try {
        $env:CODEX_HOME = 'default-account'
        function Invoke-ClosedInput {
            param([string[]]$Command, $Environment)
            if ($Environment.CODEX_HOME -eq $fixtureConfig0) {
                return @{ ExitCode = 0; Output = @('legion@ps-legion-marketplace  installed, enabled') }
            }
            return @{ ExitCode = 0; Output = @('legion@ps-legion-marketplace  not installed') }
        }
        Assert-True (Test-InstallStepDone -Command @('codex', 'plugin', 'add', 'legion@ps-legion-marketplace') -ConfigEnv CODEX_HOME -ConfigDir $fixtureConfig0) 'Install check sees selected account listing'
        Assert-Equal 'default-account' $env:CODEX_HOME 'Install check restores caller account'
    } finally {
        $env:CODEX_HOME = $savedCodexHome
    }

    # Exact plugin identity and Boolean enabled state are runtime boundaries.
    & {
        . $script -NoRun
        $catalog = Get-InstallCatalog -Source $repo
        $script:installCatalog = $catalog
        foreach ($json in @('[{"id":["legion@ps-legion-marketplace","other"],"enabled":true}]','[{"id":"legion@ps-legion-marketplace","enabled":"true"}]','[{"id":"legion@ps-legion-marketplace-old","enabled":true}]','[{"id":"legion@ps-legion-marketplace","enabled":false}]')) {
            Assert-True (-not (Test-InstallListing -Kind plugin -Tool claude -Lines @($json))) 'Only exact id and Boolean true count'
        }
        $fourth = Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth/tool.json') -Raw | ConvertFrom-Json
        $fourth.plugin.marketplaceAdd = @('register','{source}','prefix-{source}')
        $script:installCatalog.tools += $fourth
        Assert-Equal 'fourth-cli|register|local source|prefix-local source' ((Get-InstallCommands -Tool fourth -Source 'local source')[0] -join '|') 'Source tokens are replaced within arguments'
    }
}

Invoke-InstallTestCase 'Accounts' {
    . $installerPath -NoRun
    . (Join-Path $PSScriptRoot 'fixtures/install/MarketplaceListing.ps1')
    $catalog = Get-InstallCatalog -Source $repo
    $sandbox = New-InstallTestFolder 'install-accounts'
    $file = Join-Path $sandbox '.legion/configuration/personalisation.json'
    New-Item -ItemType Directory -Path (Split-Path $file -Parent) -Force | Out-Null
    @{agents=@(
        @{tool='claude';configDir='~/.claude-account2'},
        @{tool='claude';configDir='~/.claude-account2'},
        @{tool='codex';configDir='~/.codex-account2'}
    )} | ConvertTo-Json | Set-Content -LiteralPath $file
    . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome ($sandbox)
    $fixturePlugin = New-InstallFixturePlugin -Path (Join-Path $sandbox 'installed')
    function Test-InstallCommandAvailable { param($Name) $Name -in @('claude', 'codex') }
    function Invoke-InstallRefresh { }
    $calls = [Collections.Generic.List[string]]::new()
    $installed = @{}
    $state = @{ Fail=$false }
    $selected = Join-Path $sandbox 'selected'
    New-Item -ItemType Directory -Path $selected -Force | Out-Null
    function Invoke-ClosedInput {
        param([string[]]$Command, $Environment)
        $entry = $catalog.tools | Where-Object command -CEQ $Command[0]
        $folder = $Environment[$entry.configEnv]
        $key = "$($entry.id):$folder"
        $calls.Add("$key|$($Command -join '|')")
        if ($state.Fail) { throw 'fixture failure' }
        if ($Command -contains 'list') {
            if ($Command -contains 'marketplace') {
                $source = if ($installed[$key]) { $repo } else { '' }
                return @{ExitCode=0;Output=@(Get-FixtureMarketplaceListing -Tool $entry.id -Source $source)}
            }
            $output = if ($installed[$key]) {
                if ($entry.id -eq 'claude') { ConvertTo-Json -InputObject @(@{id='legion@ps-legion-marketplace';enabled=$true;installPath=$fixturePlugin}) -Compress }
                else { "legion@ps-legion-marketplace enabled $fixturePlugin" }
            } elseif ($entry.id -eq 'claude') { '[]' } else { '' }
            return @{ExitCode=0;Output=@($output)}
        }
        if ($Command -notcontains 'marketplace') { $installed[$key] = $true }
        return @{ExitCode=0;Output=@()}
    }
    $savedClaude = $env:CLAUDE_CONFIG_DIR
    $savedCodex = $env:CODEX_HOME
    try {
        $env:CLAUDE_CONFIG_DIR = (Join-Path $sandbox 'inherited-account')
        $env:CODEX_HOME = (Join-Path $sandbox 'inherited-account')
        $null = Invoke-LegionInstaller -Source $repo -Catalog $catalog -Yes
        $inherited = [IO.Path]::GetFullPath((Join-Path $sandbox 'inherited-account'))
        $expected = @("claude:$inherited", "claude:$(Join-Path $sandbox '.claude-account2')", "codex:$inherited", "codex:$(Join-Path $sandbox '.codex-account2')") | Sort-Object
        $targets = @($calls | ForEach-Object { ($_ -split '\|')[0] } | Sort-Object -Unique)
        Assert-Equal ($expected -join '|') ($targets -join '|') 'Install covers defaults and recorded folders once'
        Assert-Equal 4 $installed.Count 'Install installs each distinct target'
        Assert-Equal (Join-Path $sandbox 'inherited-account') $env:CLAUDE_CONFIG_DIR 'Install restores inherited environment'
        $calls.Clear()
        $null = Invoke-LegionInstaller -Source $repo -Catalog $catalog -Yes
        Assert-Equal 0 @($calls | Where-Object { $_ -match '\|plugin\|(install|add)\|' }).Count 'Repeat install skips installed plugins'

        $installed.Clear()
        $calls.Clear()
        $preview = @(Invoke-LegionInstaller -Source $repo -Catalog $catalog -Update -DryRun)
        Assert-Equal 0 $installed.Count 'Update preview never mutates missing targets'
        Assert-True (($preview -join "`n") -match 'plugin marketplace add') 'Update previews marketplace install for missing plugin'
        $calls.Clear()
        $null = Invoke-LegionInstaller -Source $repo -Catalog $catalog -Update -Yes
        $targets = @($calls | ForEach-Object { ($_ -split '\|')[0] } | Sort-Object -Unique)
        Assert-Equal ($expected -join '|') ($targets -join '|') 'Update and install use the same targets'
        Assert-Equal 4 $installed.Count 'Update installs every missing target'
        Assert-Equal 4 @($calls | Where-Object { $_ -match '\|marketplace\|add\|' }).Count 'Update registers missing marketplaces'
        Assert-Equal (Join-Path $sandbox 'inherited-account') $env:CODEX_HOME 'Update restores inherited environment'
        foreach ($update in @($false, $true)) {
            $calls.Clear()
            $null = Invoke-LegionInstaller -Source $repo -Catalog $catalog -Tools claude -ConfigDir $selected -Update:$update -DryRun
            Assert-Equal "claude:$selected" (($calls | ForEach-Object { ($_ -split '\|')[0] } | Sort-Object -Unique) -join '|') 'Both modes honor tool and folder narrowing'
        }
        $state.Fail = $true
        Assert-Throws { Invoke-LegionInstaller -Source $repo -Catalog $catalog -Tools claude -Yes } 'Install listing failure propagates'
        Assert-Equal (Join-Path $sandbox 'inherited-account') $env:CLAUDE_CONFIG_DIR 'Failed default install restores inherited environment'
    } finally {
        [Environment]::SetEnvironmentVariable('CLAUDE_CONFIG_DIR', $savedClaude, 'Process')
        [Environment]::SetEnvironmentVariable('CODEX_HOME', $savedCodex, 'Process')
        Remove-InstallTestFolder $sandbox
    }
}

Invoke-InstallTestCase 'TargetFolders' {
    . $installerPath -NoRun
    . (Join-Path $PSScriptRoot 'fixtures/install/MarketplaceListing.ps1')
    $catalog = Get-InstallCatalog -Source $repo
    $sandbox = New-InstallTestFolder 'install-targets'
    $file = Join-Path $sandbox '.legion/configuration/personalisation.json'
    New-Item -ItemType Directory -Path (Split-Path $file) -Force | Out-Null
    . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome ($sandbox)
    # The sandbox is not the real profile, so each tool's default folder lives in it and exists when installed.
    foreach ($tool in $catalog.tools) { New-Item -ItemType Directory -Path (Join-Path $sandbox $tool.plugin.defaultConfigDir.Substring(2)) -Force | Out-Null }
    $fixturePlugin = New-InstallFixturePlugin -Path (Join-Path $sandbox 'installed')
    $calls = New-Object 'Collections.Generic.List[string]'
    function Invoke-ClosedInput {
        param([string[]]$Command, $Environment)
        if ($Command -notcontains 'list') { throw 'Preview attempted a write' }
        $entry = $catalog.tools | Where-Object command -CEQ $Command[0]
        $folder = $Environment[$entry.configEnv]
        $calls.Add("$($entry.id):$folder")
        $output = if ($Command -contains 'marketplace') {
            Get-FixtureMarketplaceListing -Tool $entry.id -Source 'BlackGad/ps-legion-marketplace'
        } elseif ($entry.plugin.listing.format -eq 'json') {
            ConvertTo-Json -InputObject @(@{id='legion@ps-legion-marketplace';enabled=$true;installPath=$fixturePlugin}) -Compress
        } else { "legion@ps-legion-marketplace enabled $fixturePlugin" }
        return @{ExitCode=0;Output=@($output)}
    }
    $saved = @{}
    foreach ($entry in $catalog.tools) {
        $saved[$entry.configEnv] = [Environment]::GetEnvironmentVariable($entry.configEnv, 'Process')
        Remove-Item -LiteralPath "Env:$($entry.configEnv)" -ErrorAction SilentlyContinue
    }
    try {
        foreach ($entry in $catalog.tools) {
            $relative = $entry.plugin.defaultConfigDir
            $expected = Join-Path $sandbox $relative.Substring(2)
            $aliases = @($relative, ($expected.Replace('\', '/') + '/'), ($expected + '\'))
            if ($env:OS -eq 'Windows_NT') { $aliases += $expected.ToUpperInvariant() }
            $agents = @($aliases | ForEach-Object { @{id='account-a';tool=$entry.id;configDir=$_} })
            @{agents=$agents} | ConvertTo-Json | Set-Content -LiteralPath $file
            $script:installCatalog = $catalog
            $folders = Get-UpdateConfigDirs -Tool $entry.id
            Assert-Equal 1 $folders.Count "$($entry.id) default aliases select one folder"
            Assert-Equal $expected $folders[0] 'The recorded account replaces the empty default target'
            foreach ($mode in @('install', 'update', 'uninstall')) {
                $calls.Clear()
                $options = @{Catalog=$catalog;Tools=@($entry.id);DryRun=$true}
                if ($mode -eq 'update') { $options.Update=$true }
                if ($mode -eq 'uninstall') { $options.Uninstall=$true }
                $preview = @(Invoke-LegionInstaller @options)
                # An uninstall also reads the other CLIs to find installs that stay; this test is about the selected tool.
                $selectedCalls = @($calls | Where-Object { $_.StartsWith("$($entry.id):") })
                Assert-Equal 1 @($selectedCalls | Select-Object -Unique).Count "$mode selects one real folder"
                Assert-True ($selectedCalls -contains "$($entry.id):$expected") "$mode uses the account environment"
                $expectedReads = if ($mode -eq 'update') { 1 } else { 2 }
                if ($mode -eq 'install' -and $entry.plugin.marketplaceListing.rootField) { $expectedReads = 3 }
                Assert-Equal $expectedReads $selectedCalls.Count "$mode reads each target once"
                Assert-True (($preview -join "`n") -notmatch 'default config') "$mode labels the account folder"
            }

            # The caller's environment defines the default even if tool data points elsewhere.
            $override = Join-Path $sandbox 'override'
            [Environment]::SetEnvironmentVariable($entry.configEnv, ($override.Replace('\', '/') + '/'), 'Process')
            @{agents=@(@{tool=$entry.id;configDir='~/override/'}, @{tool=$entry.id;configDir='~/other/'}, @{tool=$entry.id;configDir='~/other'})} |
                ConvertTo-Json | Set-Content -LiteralPath $file
            $folders = Get-UpdateConfigDirs -Tool $entry.id
            Assert-Equal 2 $folders.Count 'Environment default and distinct account each occur once'
            Assert-Equal $override $folders[0] 'Environment default is normalized'
            Assert-Equal (Join-Path $sandbox 'other') $folders[1] 'Trailing separators do not duplicate accounts'
            Remove-Item -LiteralPath $file
            Assert-Equal $override (Get-UpdateConfigDirs -Tool $entry.id)[0] 'Environment override is honored without records'
            Assert-Equal 'selected' (Get-UpdateConfigDirs -Tool $entry.id -ConfigDir selected)[0] 'Explicit folder still narrows selection'
            Remove-Item -LiteralPath "Env:$($entry.configEnv)" -ErrorAction SilentlyContinue
        }

        # Folder metadata and environment names also work for a tool unknown to the installer.
        $entry = $catalog.tools[0]
        $entry.id = 'fixture-agent'
        $entry.plugin.defaultConfigDir = '~/.fixture-data'
        @{agents=@(@{tool='fixture-agent';configDir='~/.fixture-data/'})} | ConvertTo-Json | Set-Content -LiteralPath $file
        Assert-Equal (Join-Path $sandbox '.fixture-data') ((Get-UpdateConfigDirs -Tool fixture-agent) -join '|') 'Target selection uses descriptor data'
    } finally {
        foreach ($name in $saved.Keys) {
            if ($null -eq $saved[$name]) { Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue }
            else { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
        }
        Remove-InstallTestFolder $sandbox
    }
}

Invoke-InstallTestCase 'Consent' {
    $fixtureHome = New-InstallTestFolder 'install-consent'
    $savedPath = $env:PATH
    $savedLog = $env:LEGION_CONSENT_LOG
    try {
        $fixtureBin = Join-Path $fixtureHome 'tools'
        New-Item -ItemType Directory -Path $fixtureBin -Force | Out-Null
        $env:LEGION_CONSENT_LOG = Join-Path $fixtureHome 'versions.txt'
        $codex = Join-Path $fixtureBin $(if ($IsWindows) { 'codex.cmd' } else { 'codex' })
        $text = if ($IsWindows) {
            "@echo %*>>`"%LEGION_CONSENT_LOG%`"`r`n@echo fixture codex`r`n@exit /b 0`r`n"
        } else {
            '#!/bin/sh' + "`n" + 'printf "%s\n" "$*" >> "$LEGION_CONSENT_LOG"' + "`n" + 'echo fixture codex' + "`n"
        }
        [IO.File]::WriteAllText($codex, $text)
        if (-not $IsWindows) {
            [IO.File]::SetUnixFileMode($codex, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute)
        }
        $systemBin = if ($IsWindows) { Join-Path $env:SystemRoot 'System32' } else { '/usr/bin' }
        $env:PATH = @($fixtureBin, $PSHOME, $systemBin) -join [IO.Path]::PathSeparator
        Assert-Equal $codex (Get-Command codex -CommandType Application).Source 'R4 B6 consent uses the fixture executable'
        # B4: the home chosen with -HomeRoot is the home for every install path, including the refresh.
        . $installerPath -NoRun -HomeRoot $fixtureHome
        Assert-Equal $fixtureHome (Get-InstallHome) 'B4: -HomeRoot selects the install home'
        Assert-Equal (Join-Path $fixtureHome '.legion/bin') (Get-InstallLegionPath 'bin') 'B4: legion paths follow the selected home'

        # P1: persistent changes need consent: -Yes, or an answer at the prompt.
        $script:answer = 'n'
        $script:prompts = 0
        $script:pathWrites = 0
        $script:installs = 0
        function Read-Host { param($Prompt) $script:prompts++; return $script:answer }
        function Add-LegionUserPath { param($Path) $script:pathWrites++ }
        function Get-InstallUserPath { Get-InstallLegionPath 'bin' }
        function Invoke-InstallRefresh { }
        function Get-InstallPluginRoot { Join-Path $repo 'plugins/legion' }
        function Get-UpdateConfigDirs { param($Tool, $ConfigDir) ,@('') }
        function Resolve-InstallSource { param($Source) return $Source }
        function Test-InstallCommandAvailable { param($Name) $true }
        function Invoke-LegionInstallSteps { $script:installs++ }
        # Portable PowerShell consent is covered with the root stub in InstallBootstrapPowerShell.Tests.ps1.
        $script:answer = 'n'
        $null = Invoke-LegionInstaller -Catalog (Get-InstallCatalog -Source $repo) -Tools codex
        Assert-Equal 0 $script:installs 'P1: no install into the default account without consent'
        $script:answer = 'y'
        $null = Invoke-LegionInstaller -Catalog (Get-InstallCatalog -Source $repo) -Tools codex
        Assert-Equal 1 $script:installs 'P1: the owner can say yes at the prompt'
        $script:prompts = 0
        $null = Invoke-LegionInstaller -Catalog (Get-InstallCatalog -Source $repo) -Tools codex -Yes
        $null = Invoke-LegionInstaller -Catalog (Get-InstallCatalog -Source $repo) -Tools codex -DryRun
        Assert-Equal 3 $script:installs '-Yes and a dry run both go on to the install steps'
        Assert-Equal 0 $script:prompts '-Yes and a dry run never prompt'
        Assert-Equal '--version|--version' ((Get-Content -LiteralPath $env:LEGION_CONSENT_LOG) -join '|') 'R4 B6 version probes call only the fixture executable'

        # A refresh failure is one plain line; install goes on to the summary.
        function Invoke-InstallRefresh { throw 'refresh broke' }
        $output = @(Invoke-LegionInstaller -Catalog (Get-InstallCatalog -Source $repo) -Tools codex -Yes)
        Assert-True ($output -contains 'commands not refreshed for codex in default config; run legion setup') 'Refresh failure prints one plain line'
        Assert-True (@($output | Where-Object { $_ -like 'installed: legion *' }).Count -eq 1) 'Install still prints the summary after a refresh failure'
        function Invoke-InstallRefresh { }
    } finally {
        $env:PATH = $savedPath
        $env:LEGION_CONSENT_LOG = $savedLog
        Remove-InstallTestFolder $fixtureHome
    }
}

foreach ($case in @('InstallRunsRefresh', 'InstallQuestionNamesPath', 'InstallUnixPathHint', 'InstallNextStep', 'NonInteractiveInstall')) {
    Invoke-InstallTestCase $case {
        . $installerPath -NoRun
        . (Join-Path $PSScriptRoot 'fixtures/install/MarketplaceListing.ps1')
        $scratch = New-InstallTestFolder 'install-finish'
        $plugin = Join-Path $scratch 'installed'
        New-Item -ItemType Directory -Path $plugin -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $repo 'plugins/legion/bin') -Destination $plugin -Recurse
        '{"name":"legion","version":"0.8.0"}' | Set-Content -LiteralPath (Join-Path $plugin 'plugin.json')
        $fixturePwsh = Get-InstallTestPwsh
        $catalog = Get-InstallCatalog -Source $repo
        $state = @{ Ready=$true; UserPath='fixture-existing'; Writes=0; Winget=0; Zip=0; Answer='y' }
        $questions = [Collections.Generic.List[string]]::new()
        $refreshes = [Collections.Generic.List[string]]::new()
        $installed = @{}
        function Get-InstallHome { $scratch }
        function Get-InstallUserPath { $state.UserPath }
        function Set-InstallUserPath { param($Path) $state.Writes++; $state.UserPath=$Path }
        function Test-InstallCommandAvailable { $true }
        function Get-InstallSourceText { throw 'Unexpected network access' }
        function Invoke-InstallDownload { throw 'Unexpected download' }
        function Read-Host { param($Prompt) $questions.Add($Prompt); $state.Answer }
        function claude { param($Version) Assert-Equal '--version' $Version 'Only version probes run directly'; 'fixture CLI' }
        function Invoke-ClosedInput {
            param($Command, $Environment)
            if ($Command[0] -eq $fixturePwsh) {
                $refreshes.Add($Command[3])
                $output = & $Command[0] @($Command | Select-Object -Skip 1) 2>&1
                return @{ ExitCode=$LASTEXITCODE; Output=@($output); ErrorOutput=@() }
            }
            Assert-Equal 'claude' $Command[0] 'Only fixture Claude calls are allowed'
            $folder = [string]$Environment.CLAUDE_CONFIG_DIR
            if ($Command -contains 'list') {
                if ($Command -contains 'marketplace') { return @{ExitCode=0;Output=@(Get-FixtureMarketplaceListing -Tool claude -Source $repo)} }
                $listing = if ($installed[$folder]) { '[{"id":"legion@ps-legion-marketplace","enabled":true,"installPath":' + (ConvertTo-Json $plugin -Compress) + '}]' } else { '[]' }
                return @{ExitCode=0;Output=@($listing)}
            }
            if ($Command[2] -eq 'install') { $installed[$folder]=$true }
            return @{ExitCode=0;Output=@();ErrorOutput=@()}
        }
        $savedPath = $env:PATH
        $options = @{ Tools=@('claude'); Source=$repo; Catalog=$catalog; ConfigDir=(Join-Path $scratch 'fixture-account') }
        try {
            $env:OS = 'Windows_NT'
            switch ($case) {
                'InstallRunsRefresh' {
                    function Get-UpdateConfigDirs { @((Join-Path $scratch 'fixture-one'), (Join-Path $scratch 'fixture-two')) }
                    $null = Invoke-LegionInstaller @options -Yes
                    Assert-Equal 2 $refreshes.Count 'InstallRunsRefresh: refresh runs once for each installed folder'
                    $command = Join-Path $scratch '.legion/bin/legion'
                    Assert-True (Test-Path -LiteralPath $command) 'InstallRunsRefresh: plain install creates legion'
                    Assert-True ((Get-Content -LiteralPath $command -Raw).Replace('\','/').Contains($plugin.Replace('\','/'))) 'InstallRunsRefresh: legion points at the installed copy'
                }
                'InstallQuestionNamesPath' {
                    $null = Invoke-LegionInstaller @options
                    Assert-Equal 'Install legion for claude now, and add ~/.legion/bin to your PATH? [y/N]' ($questions -join '|') 'InstallQuestionNamesPath: one question covers PATH'
                    Assert-Equal 1 $state.Writes 'InstallQuestionNamesPath: consent adds user PATH once'
                    Assert-True (Test-Path -LiteralPath (Join-Path $scratch '.legion/bin') -PathType Container) 'InstallQuestionNamesPath: command folder exists'
                    $questions.Clear()
                    $null = Invoke-LegionInstaller @options
                    Assert-Equal 'Install legion for claude now? [y/N]' ($questions -join '|') 'InstallQuestionNamesPath: existing PATH needs no PATH question'
                    Assert-Equal 1 $state.Writes 'InstallQuestionNamesPath: repeat does not rewrite PATH'
                }
                # Missing-pwsh consent and both prompts are covered by the stub tests.
                'InstallUnixPathHint' {
                    $env:OS='fixture-unix'
                    $preview = @(Invoke-LegionInstaller @options -DryRun) -join "`n"
                    $profile = Get-LegionShellProfile -HomeRoot $scratch
                    Assert-True ($preview.Contains($profile.Path)) 'InstallUnixPathHint: dry run names the profile'
                    Assert-True (-not (Test-Path $profile.Path)) 'InstallUnixPathHint: dry run never writes the profile'
                    $state.Answer = 'n'
                    $null = Invoke-LegionInstaller @options
                    Assert-True (-not (Test-Path $profile.Path)) 'InstallUnixPathHint: decline never writes the profile'
                    $output = @(Invoke-LegionInstaller @options -Yes)
                    Assert-True (Get-LegionShellProfile -HomeRoot $scratch).HasPath 'InstallUnixPathHint: consent writes the shell profile line'
                    Assert-Equal 0 $state.Writes 'InstallUnixPathHint: no user PATH write'
                    Assert-Equal $savedPath $env:PATH 'InstallUnixPathHint: no process PATH write'
                    $repeat = @(Invoke-LegionInstaller @options -Yes)
                    Assert-True ($repeat -contains 'skip: shell profile PATH (already done)') 'InstallUnixPathHint: repeat skips the profile before a new terminal'
                }
                'InstallNextStep' {
                    foreach ($track in @('release','main')) {
                        $output = @(Invoke-LegionInstaller @options -Ref $track -Yes)
                        Assert-Equal "installed: legion 0.8.0 ($track)" $output[-2] 'InstallNextStep: installed plugin version and track'
                        Assert-Equal 'next: legion add claude (or legion in a repository)' $output[-1] 'InstallNextStep: explains the next action'
                    }
                }
                'NonInteractiveInstall' {
                    $state.Ready=$false
                    $state.Answer=''
                    $output = @(Invoke-LegionInstaller @options 6>&1)
                    Assert-True ($output -contains 'Nothing changed. Run again with -Yes to apply.') 'NonInteractiveInstall: empty redirected answer explains no changes'
                    Assert-Equal 0 $state.Writes 'NonInteractiveInstall: no PATH write'
                    Assert-Equal 0 $state.Winget 'NonInteractiveInstall: no prerequisite install'
                    Assert-Equal 0 $installed.Count 'NonInteractiveInstall: no plugin install'
                    Assert-True (-not (Test-Path -LiteralPath (Join-Path $scratch '.legion'))) 'NonInteractiveInstall: nothing generated'
                    $questions.Clear()
                    $null = Invoke-LegionInstaller @options -DryRun
                    Assert-Equal 0 $questions.Count 'NonInteractiveInstall: dry run never prompts'
                    Assert-Equal 0 $state.Writes 'NonInteractiveInstall: dry run never writes PATH'
                }
            }
        } finally {
            Remove-InstallTestFolder $scratch
        }
    }
}

Invoke-InstallTestCase 'Ref' {
    . $installerPath -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    function Ensure-InstallPowerShell { $true }
    function Get-UpdateConfigDirs { ,@('') }
    function Invoke-ClosedInput {
        param($Command, $Environment)
        if ($Command -contains 'list') { return @{ ExitCode=0; Output=@('[]') } }
        throw "Unexpected CLI call: $($Command -join ' ')"
    }
    foreach ($case in @(
        @{ Name='ReleaseAddsStable'; Ref='release'; Claude='BlackGad/ps-legion-marketplace#stable'; Codex='BlackGad/ps-legion-marketplace --ref stable' }
        @{ Name='MainAddsMain'; Ref='main'; Claude='BlackGad/ps-legion-marketplace#main'; Codex='BlackGad/ps-legion-marketplace --ref main' }
    )) {
        $options = @{ Tools=@('claude','codex','copilot'); Catalog=$script:installCatalog; DryRun=$true }
        if ($case.Ref -eq 'main') { $options.Ref = 'main' }
        $preview = @(Invoke-LegionInstaller @options)
        Assert-True ($preview -contains "claude plugin marketplace add $($case.Claude)") "$($case.Name): Claude pins the branch"
        Assert-True ($preview -contains "codex plugin marketplace add $($case.Codex)") "$($case.Name): Codex pins the branch"
        Assert-True ($preview -contains "copilot plugin marketplace add $($case.Claude)") "$($case.Name): Copilot pins the branch"
    }
    foreach ($tool in @('claude','codex','copilot')) {
        Assert-Equal "$tool|plugin|marketplace|add|$repo" ((Get-InstallCommands -Tool $tool -Source $repo -Ref main)[0] -join '|') 'LocalSourceHasNoRef'
    }
    function Invoke-ClosedInput {
        param($Command, $Environment)
        Assert-Equal 'codex|plugin|marketplace|list|--json' ($Command -join '|') 'KindIsPassed: marketplace listing is selected explicitly'
        @{ ExitCode=0; Output=@('{"marketplaces":[{"name":"ps-legion-marketplace","root":"fixture"}]}') }
    }
    Assert-True (Test-InstallStepDone -Command @('codex','plugin','marketplace','add','example/market','--ref','stable') -Kind marketplace) 'KindIsPassed'
    foreach ($value in @($null, 'not an array', 42, @(1))) {
        $bad = Get-Content (Join-Path $repo 'plugins/legion/skills/legion-claude/tool.json') -Raw | ConvertFrom-Json
        $bad.plugin.marketplaceAddRef = $value
        Assert-True (-not (Test-Json -Json ($bad | ConvertTo-Json -Depth 100) -SchemaFile (Join-Path $repo 'plugins/legion/schemas/tool.schema.json') -ErrorAction SilentlyContinue)) 'CatalogRequiresRefArray'
    }
}

Invoke-InstallTestCase 'WorkingFolder' {
    . $installerPath -NoRun
    # Codex reads <cwd>/.codex/config.toml as project settings, so running from the home folder
    # leaks the default account's marketplaces into every other account.
    $callerFolder = Join-Path ([IO.Path]::GetTempPath()) ('legion-cwd-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $callerFolder '.codex') -Force | Out-Null
    $child = Get-InstallTestPwsh
    Push-Location -LiteralPath $callerFolder
    try {
        $result = Invoke-ClosedInput -Command @($child, '-NoProfile', '-Command', '(Get-Location).ProviderPath')
    } finally {
        Pop-Location
    }
    Remove-Item -LiteralPath (Join-Path $callerFolder '.codex') -Force
    Remove-Item -LiteralPath $callerFolder
    Assert-Equal 0 $result.ExitCode 'Working folder probe runs'
    $expected = (Get-TestTempPath).TrimEnd('\', '/')
    Assert-Equal $expected ($result.Output[0].TrimEnd('\', '/')) 'CLI processes run from the system temp folder, not the caller folder'
}
