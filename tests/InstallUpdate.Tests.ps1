# Update and refresh.
. (Join-Path $PSScriptRoot 'lib/installer.ps1')

Invoke-InstallTestCase 'Update' {
    & {
        . $installerPath -NoRun
        $catalog = Get-InstallCatalog -Source $repo
        $expected = @{
            claude = @('plugin|marketplace|update|ps-legion-marketplace', 'plugin|update|legion@ps-legion-marketplace')
            copilot = @('plugin|marketplace|update|ps-legion-marketplace', 'plugin|update|legion@ps-legion-marketplace')
            codex = @('plugin|marketplace|upgrade', 'plugin|add|legion@ps-legion-marketplace')
        }
        foreach ($tool in $catalog.tools) {
            Assert-Equal $expected[$tool.id][0] ($tool.plugin.marketplaceUpdate -join '|') "$($tool.id) marketplace refresh metadata"
            Assert-Equal $expected[$tool.id][1] ($tool.plugin.update -join '|') "$($tool.id) plugin refresh metadata"
        }
        foreach ($field in @('marketplaceUpdate', 'update')) {
            $bad = Get-Content (Join-Path $repo 'plugins/legion/skills/legion-claude/tool.json') -Raw | ConvertFrom-Json
            $bad.plugin.$field = 'invalid'
            Assert-True (-not (Test-Json -Json ($bad | ConvertTo-Json -Depth 100) -SchemaFile (Join-Path $repo 'plugins/legion/schemas/tool.schema.json') -ErrorAction SilentlyContinue)) "Invalid $field rejected before catalog generation"
        }
    }

    & {
        . $installerPath -NoRun
        $catalog = Get-InstallCatalog -Source $repo
        $sandbox = New-InstallTestFolder 'restructure/update'
        New-Item -ItemType Directory -Path (Join-Path $sandbox '.legion/configuration') -Force | Out-Null
        $personalisation = Join-Path $sandbox '.legion/configuration/personalisation.json'
        $agents = @(
            @{tool='claude';configDir='~/.legion/agents/claude-a'},
            @{tool='claude';configDir='~/.legion/agents/claude-a'},
            @{tool='claude';configDir=(Join-Path $sandbox 'custom account')},
            @{tool='codex';configDir='~/.legion/agents/codex-a'},
            @{tool='copilot';configDir='~/.legion/agents/copilot-a'}
        )
        @{agents=$agents} | ConvertTo-Json | Set-Content -LiteralPath $personalisation
        . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome ($sandbox)
        $fixturePlugin = New-InstallFixturePlugin -Path (Join-Path $sandbox 'installed')
        function Invoke-InstallRefresh { } # The installed-script boundary has dedicated coverage.
        function Ensure-InstallPowerShell { throw 'Update must not install prerequisites' }
        function Get-InstallSourceText { throw 'Tests must not use network' }
        $calls = [Collections.Generic.List[string]]::new()
        $state = @{ Missing=$false; FailList=$false; FailUpdate=$false }
        $selected = Join-Path $sandbox 'selected'
        $selectedAccount = Join-Path $sandbox 'selected account'
        $absent = Join-Path $sandbox 'absent'
        $fixtureFolders = @($agents.configDir | ForEach-Object { Resolve-InstallConfigDir $_ })
        $fixtureFolders += @((Join-Path $sandbox 'inherited-account'), $selected, $selectedAccount, $absent)
        New-Item -ItemType Directory -Path $fixtureFolders -Force | Out-Null
        function Test-InstallCommandAvailable { param($Name) $Name -in @('claude','codex','copilot') }
        function Invoke-ClosedInput {
            param([string[]]$Command, $Environment)
            $entry = $catalog.tools | Where-Object command -EQ $Command[0]
            $folder = $Environment[$entry.configEnv]
            $calls.Add("$($entry.id):$folder|$($Command -join '|')")
            if ($Command -contains 'marketplace' -and $Command -contains 'list') {
                return @{ExitCode=0; Output=@('[]')}
            }
            if ($Command[2] -eq 'list') {
                if ($state.FailList) { return @{ExitCode=7; Output=@('list failed')} }
                if ($state.Missing) { return @{ExitCode=0; Output=@($(if ($entry.id -eq 'claude') { '[]' }))} }
                # Disabled plugins still have an installed copy that needs refreshing.
                $output = if ($entry.id -eq 'claude') { ConvertTo-Json -InputObject @(@{id='legion@ps-legion-marketplace';enabled=$false;installPath=$fixturePlugin}) -Compress }
                    else { "legion@ps-legion-marketplace installed (disabled) $fixturePlugin" }
                return @{ExitCode=0; Output=@($output)}
            }
            if ($state.FailUpdate) { return @{ExitCode=8; Output=@('update failed')} }
            if ($Command[2] -eq 'install') { $state.Missing=$false }
            return @{ExitCode=0; Output=@('refreshed')}
        }
        $saved = @{}
        $saved.FOURTH_HOME = [Environment]::GetEnvironmentVariable('FOURTH_HOME', 'Process')
        foreach ($entry in $catalog.tools) {
            $saved[$entry.configEnv] = [Environment]::GetEnvironmentVariable($entry.configEnv, 'Process')
            [Environment]::SetEnvironmentVariable($entry.configEnv, (Join-Path $sandbox 'inherited-account'), 'Process')
        }
        try {
            $output = @(Invoke-LegionInstaller -Source $repo -Catalog $catalog -Update -Yes)
            Assert-Equal 28 $calls.Count 'Seven distinct targets each list before and after two refresh steps'
            foreach ($entry in $catalog.tools) {
                $inherited = [IO.Path]::GetFullPath((Join-Path $sandbox 'inherited-account'))
                Assert-True ($calls -contains "$($entry.id):$inherited|$($entry.command)|plugin|list$(if ($entry.id -eq 'claude') { '|--json' })") 'Default config honors inherited account override'
                Assert-Equal (Join-Path $sandbox 'inherited-account') ([Environment]::GetEnvironmentVariable($entry.configEnv, 'Process')) 'Update restores caller config env'
            }
            $custom = Join-Path $sandbox 'custom account'
            Assert-True ($calls -contains "claude:$custom|claude|plugin|update|legion@ps-legion-marketplace") 'Registered custom folder refreshes'
            Assert-True ($calls -contains "codex:$(Join-Path $sandbox '.legion/agents/codex-a')|codex|plugin|add|legion@ps-legion-marketplace") 'Codex refresh repeats add without remove'
            Assert-Equal 0 @($calls | Where-Object { $_ -match '\|remove\||\|install\|' }).Count 'Installed plugin updates do not remove or reinstall'
            Assert-True (($output -join "`n").Contains('claude plugin update legion@ps-legion-marketplace')) 'Each mutation prints its command'

            $calls.Clear()
            $preview = @(Invoke-LegionInstaller -Source $repo -Catalog $catalog -Update -DryRun)
            Assert-Equal 7 $calls.Count 'Dry run reads installed state for seven targets'
            Assert-Equal 0 @($calls | Where-Object { $_ -notmatch '\|list(?:\|--json)?$' }).Count 'Dry run only invokes read-only listings'
            Assert-True (($preview -join "`n").Contains('codex plugin add legion@ps-legion-marketplace')) 'Dry run prints refresh commands'
            Assert-True (($preview -join "`n").Contains('custom account')) 'Dry run includes recorded accounts'

            $calls.Clear()
            $null = Invoke-LegionInstaller -Tools copilot -ConfigDir $selectedAccount -Source $repo -Catalog $catalog -Update -Yes
            Assert-Equal 4 $calls.Count 'Tools and ConfigDir narrow to exactly one target'
            Assert-True ($calls[2].StartsWith("copilot:$selectedAccount|")) 'Selected folder scopes mutation'

            # One update question also covers installing a missing plugin.
            $calls.Clear()
            $state.Missing = $true
            $script:answer = 'n'
            $script:questions = 0
            function Read-Host { $script:questions++; $script:answer }
            $declined = @(Invoke-LegionInstaller -Tools claude -ConfigDir $absent -Source $repo -Catalog $catalog -Update)
            Assert-Equal 1 $script:questions 'A missing plugin asks before a fresh install'
            Assert-Equal 0 @($calls | Where-Object { $_ -match '\|(add|install)\|' }).Count 'A declined install adds no marketplace and installs nothing'
            Assert-True (($declined -join "`n").Contains("Update legion for claude in $absent (not installed)")) 'Preview names the missing install before declining'
            Assert-True ($declined -contains 'Nothing changed. Run again with -Yes to apply.') 'A declined update explains that nothing changed'
            $calls.Clear()
            $script:questions = 0
            $null = Invoke-LegionInstaller -Tools claude -ConfigDir $absent -Source $repo -Catalog $catalog -Update -DryRun
            Assert-Equal 0 $script:questions 'A dry run never asks'
            $script:answer = 'y'
            $calls.Clear()
            $output = @(Invoke-LegionInstaller -Tools claude -ConfigDir $absent -Source $repo -Catalog $catalog -Update)
            Assert-True ($calls -contains "claude:$absent|claude|plugin|marketplace|add|$(Resolve-InstallSource $repo)") 'Update registers marketplace for missing plugin'
            Assert-True ($calls -contains "claude:$absent|claude|plugin|install|legion@ps-legion-marketplace") 'Update installs missing plugin'
            Assert-True (($output -join "`n") -notmatch 'skip: .*\(not installed\)') 'Missing plugin is no longer skipped'
            $state.Missing = $false

            foreach ($failure in @('FailList','FailUpdate')) {
                $state[$failure] = $true
                Assert-Throws { $null = Invoke-LegionInstaller -Tools claude -ConfigDir $selected -Source $repo -Catalog $catalog -Update } "$failure propagates"
                Assert-Equal (Join-Path $sandbox 'inherited-account') $env:CLAUDE_CONFIG_DIR 'Failure restores config env'
                $state[$failure] = $false
            }

            $caseAgents = @(@{tool='claude';configDir=(Join-Path $sandbox 'account-a')}, @{tool='claude';configDir=(Join-Path $sandbox 'Account-a')})
            @{agents=$caseAgents} | ConvertTo-Json | Set-Content -LiteralPath $personalisation
            $sharedComparer = ${function:Get-LegionPathComparer}
            try {
                function Get-LegionPathComparer { $caseComparer }
                $caseComparer = [StringComparer]::Ordinal
                Assert-Equal 3 (Get-UpdateConfigDirs -Tool claude).Count 'Case-distinct Unix folders both update'
                $caseComparer = [StringComparer]::OrdinalIgnoreCase
                Assert-Equal 2 (Get-UpdateConfigDirs -Tool claude).Count 'Windows folders deduplicate without case sensitivity'
            } finally { Set-Item -LiteralPath Function:Get-LegionPathComparer -Value $sharedComparer }
            Remove-Item -LiteralPath $personalisation
            $calls.Clear()
            $null = Invoke-LegionInstaller -Tools claude -Source $repo -Catalog $catalog -Update -Yes
            Assert-Equal 4 $calls.Count 'Missing account records still refresh default'

            $calls.Clear()
            '{' | Set-Content -LiteralPath $personalisation
            Assert-Throws { $null = Invoke-LegionInstaller -Tools claude -Source $repo -Catalog $catalog -Update } 'Unreadable records fail clearly'
            Assert-Equal 0 $calls.Count 'Invalid records never run CLI commands'
            Remove-Item -LiteralPath $personalisation

            function Test-InstallCommandAvailable { $false }
            $calls.Clear()
            $skip = @(Invoke-LegionInstaller -Tools claude -Source $repo -Catalog $catalog -Update)
            Assert-True ($skip -contains 'skip: claude (not installed)') 'Explicit missing CLI is skipped'
            Assert-Equal 0 $calls.Count 'Unavailable CLI is never launched'
        } finally {
            foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key, $saved[$key], 'Process') }
            Remove-InstallTestFolder $sandbox
        }
    }
}

Invoke-InstallTestCase 'UpdateJson' {
    . $installerPath -NoRun
    $sandbox = New-InstallTestFolder 'update-json'
    . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome $sandbox
    $fixturePlugin = New-InstallFixturePlugin -Path (Join-Path $sandbox 'installed')
    $catalog = Get-InstallCatalog -Source $repo
    $selected = Join-Path $sandbox 'selected'
    New-Item -ItemType Directory -Path $selected -Force | Out-Null
    $lines = @'
[
  {
    "id": "legion@ps-legion-marketplace",
    "version": "0.3.0",
    "scope": "user",
    "enabled": true
  }
]
'@ -split "`r?`n"
    $plugins = ($lines -join "`n") | ConvertFrom-Json
    $plugins[0] | Add-Member installPath $fixturePlugin
    $lines = ConvertTo-Json -InputObject @($plugins) -Depth 10
    $calls = [Collections.Generic.List[string]]::new()
    function Test-InstallCommandAvailable { param($Name) $Name -eq 'claude' }
    function Invoke-InstallRefresh { }
    function Invoke-ClosedInput {
        param($Command, $Environment)
        if ($calls.Count) { Assert-Equal $selected $Environment.CLAUDE_CONFIG_DIR 'Version lookup and update commands use the selected config in the child' }
        $calls.Add(($Command -join '|'))
        if ($Command[2] -eq 'list') { return @{ExitCode=0; Output=$lines} }
        return @{ExitCode=0; Output=@()}
    }
    $script:installCatalog = $catalog
    Assert-True (Test-InstallStepDone -Entry (Get-InstallTool -Tool claude)) 'Install detects exact multiline Claude JSON'
    $calls.Clear()
    try {
        $output = @(Invoke-LegionInstaller -Tools claude -ConfigDir $selected -Source $repo -Catalog $catalog -Update -Yes)
        Assert-Equal 4 $calls.Count 'Update detects multiline Claude JSON before and after both refresh commands'
        Assert-True ($calls -contains 'claude|plugin|update|legion@ps-legion-marketplace') 'Installed Claude plugin updates'
        Assert-True (-not (($output -join "`n").Contains('(not installed)'))) 'Installed Claude plugin is never reported missing'

        # The shared listing parser must retain disabled plugins and config scoping.
        $realDetection = ${function:Read-InstallPluginListing}
        $checks = [Collections.Generic.List[string]]::new()
        function Read-InstallPluginListing {
            param($Entry, $Lines)
            $parsed = & $realDetection -Entry $Entry -Lines $Lines
            $checks.Add("$($parsed.Listed)|$($parsed.Enabled)")
            $parsed
        }
        $plugins[0].enabled = $false
        $lines = ConvertTo-Json -InputObject @($plugins) -Depth 10
        $null = Invoke-LegionInstaller -Tools claude -ConfigDir $selected -Source $repo -Catalog $catalog -Update -Yes
        Assert-Equal 'True|False,True|False' ($checks -join ',') 'Both version lookups parse once and retain disabled copies'
    } finally {
        Remove-InstallTestFolder $sandbox
    }
}

Invoke-InstallTestCase 'UpdateVersion' {
    & {
        . $installerPath -NoRun
        $catalog = Get-InstallCatalog -Source $repo
        $sandbox = New-InstallTestFolder 'update-version'
        . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome $sandbox
        $entry = $catalog.tools | Where-Object id -EQ claude
        $folders = @((Join-Path $sandbox 'account-a'), (Join-Path $sandbox 'account-b'))
        $calls = [Collections.Generic.List[string]]::new()
        $questions = [Collections.Generic.List[string]]::new()
        $state = @{ Answer='y'; Target='0.8.0'; Refreshes=0 }
        function Get-UpdateConfigDirs { ,$folders }
        function Read-Host {
            param($Prompt)
            $questions.Add($Prompt)
            Assert-Equal 0 @($calls | Where-Object { $_ -notmatch '\|list\|' }).Count 'Question precedes all mutations'
            $state.Answer
        }
        function Invoke-ClosedInput {
            param($Command, $Environment)
            if ($Command[0] -eq (Get-Process -Id $PID).Path) { $state.Refreshes++; return @{ExitCode=0; Output=@()} }
            $calls.Add(($Command -join '|'))
            $config = $Environment.CLAUDE_CONFIG_DIR
            $root = Join-Path $config $entry.plugin.installedRoot
            $manifest = Join-Path $root 'plugin.json'
            if ($Command -contains 'list') {
                if ($Command -contains 'marketplace') { return @{ExitCode=0; Output=@('[]')} }
                $plugins = @()
                if (Test-Path -LiteralPath $manifest) {
                    $version = (Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).version
                    $plugins = @(@{id='legion@ps-legion-marketplace'; enabled=$false; version=$version})
                }
                return @{ExitCode=0; Output=@(ConvertTo-Json -InputObject $plugins -Compress)}
            }
            if ($Command -notcontains 'marketplace') { Write-FixturePlugin -Folder $config -Version $state.Target }
            @{ExitCode=0; Output=@()}
        }
        function Write-FixturePlugin {
            param($Folder, $Version)
            $root = Join-Path $Folder $entry.plugin.installedRoot
            New-Item -ItemType Directory -Path (Join-Path $root 'bin') -Force | Out-Null
            @{name='legion';version=$Version} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'plugin.json')
            '# inert refresh' | Set-Content -LiteralPath (Join-Path $root 'bin/legion-refresh.ps1')
        }
        try {
            Write-FixturePlugin $folders[0] '0.7.0'
            Write-FixturePlugin $folders[1] '0.8.0'
            $output = @(Invoke-LegionInstaller -Tools claude -Catalog $catalog -Update)
            Assert-True ($output -contains 'legion 0.7.0 -> 0.8.0') 'UpdateShowsVersions: reports installed versions before and after'
            Assert-True ($output -contains 'skip: legion 0.8.0 (already up to date)') 'MixedFoldersUpdate: reports an unchanged folder separately'
            Assert-Equal 1 $questions.Count 'UpdateAsksOnce: one question across mixed folders'
            Assert-Equal 'Update legion? [y/N]' $questions[0] 'Update question is explicit'
            Assert-Equal 2 @($calls | Where-Object { $_ -eq 'claude|plugin|marketplace|update|ps-legion-marketplace' }).Count 'Each registered marketplace updates'
            Assert-Equal 2 @($calls | Where-Object { $_ -eq 'claude|plugin|update|legion@ps-legion-marketplace' }).Count 'Each installed plugin updates'
            Assert-Equal 2 $state.Refreshes 'Each folder refreshes its generated artifacts exactly once'
            Assert-Equal 0 @($calls | Where-Object { $_ -match '\|(add|remove|install)\|' }).Count 'Registered tracks are never re-added or switched'
            Assert-True ($output -contains 'done: restart your sessions; run legion in the repository') 'Successful update gives the restart hint'

            $calls.Clear(); $questions.Clear()
            $output = @(Invoke-LegionInstaller -Tools claude -Catalog $catalog -Update -Yes)
            Assert-Equal 2 @($output | Where-Object { $_ -eq 'skip: legion 0.8.0 (already up to date)' }).Count 'UpdateAlreadyLatest: unchanged versions reported after tools run'
            Assert-Equal 2 @($calls | Where-Object { $_ -eq 'claude|plugin|update|legion@ps-legion-marketplace' }).Count 'Same version never suppresses track updates'
            Assert-Equal 0 $questions.Count '-Yes suppresses the question'

            Remove-Item -LiteralPath (Join-Path (Join-Path $folders[1] $entry.plugin.installedRoot) 'plugin.json')
            $calls.Clear(); $questions.Clear(); $state.Answer='n'
            $output = @(Invoke-LegionInstaller -Tools claude -Catalog $catalog -Update)
            Assert-True (($output -join "`n").Contains($folders[1])) 'Preview names the missing target'
            Assert-True (($output -join "`n").Contains('not installed')) 'Preview identifies a fresh install'
            Assert-Equal 1 $questions.Count 'Declining mixed update asks once'
            Assert-Equal 0 @($calls | Where-Object { $_ -notmatch '\|list\|' }).Count 'Declining changes nothing, including already installed folders'
            Assert-True ($output -contains 'Nothing changed. Run again with -Yes to apply.') 'Decline explains how to apply'

            $calls.Clear(); $questions.Clear()
            $output = @(Invoke-LegionInstaller -Tools claude -Catalog $catalog -Update -DryRun)
            Assert-Equal 0 $questions.Count 'Dry run never asks'
            Assert-Equal 0 @($calls | Where-Object { $_ -notmatch '\|list\|' }).Count 'Dry run only reads listings'
            Assert-True (-not (Test-Path -LiteralPath (Join-Path (Join-Path $folders[1] $entry.plugin.installedRoot) 'plugin.json'))) 'Dry run creates no missing copy'

            $calls.Clear(); $questions.Clear(); $state.Answer='y'
            $output = @(Invoke-LegionInstaller -Tools claude -Catalog $catalog -Update)
            Assert-Equal 1 $questions.Count 'One yes covers updating and fresh installation'
            Assert-True ($calls -contains 'claude|plugin|install|legion@ps-legion-marketplace') 'Missing folder is installed under the same yes'
            Assert-True ($output -contains 'legion not installed -> 0.8.0') 'Fresh installation reports its resulting version'
            $calls.Clear()
            $output = @(Invoke-LegionInstaller -Tools claude -Catalog $catalog -Update -Yes)
            Assert-Equal 0 @($calls | Where-Object { $_ -match '\|(add|install|remove)\|' }).Count 'FreshInstallThenUpdate: subsequent update keeps registration'
            Assert-Equal 2 @($output | Where-Object { $_ -eq 'skip: legion 0.8.0 (already up to date)' }).Count 'FreshInstallThenUpdate: subsequent report is unchanged'
        } finally {
            Remove-InstallTestFolder $sandbox
        }
    }

    & {
        . $installerPath -NoRun
        $script:installCatalog = Get-InstallCatalog -Source $repo
        $entry = Get-InstallTool codex
        $missingFolder = Join-Path $repo ('.agents/temp/absent-codex-' + [guid]::NewGuid().ToString('N'))
        $previous = $env:CODEX_HOME
        function Invoke-ClosedInput {
            @{ExitCode=1; Output=@(); ErrorOutput=@('failed to resolve CODEX_HOME: path does not exist, but that path does not exist')}
        }
        Assert-True ($null -eq (Get-InstallPluginRoot -Entry $entry -ConfigDir $missingFolder)) 'Missing Codex home counts as a pending fresh install'
        Assert-Equal $previous $env:CODEX_HOME 'Missing Codex home lookup restores caller config'
        Assert-True (-not (Test-Path -LiteralPath $missingFolder)) 'Pre-consent lookup never creates the Codex home'
        function Invoke-ClosedInput { @{ExitCode=1; Output=@(); ErrorOutput=@('unrelated listing failure')} }
        Assert-Throws { Get-InstallPluginRoot -Entry $entry } 'Unrelated Codex default-home listing errors still stop the update'
        try {
            New-Item -ItemType Directory -Path $missingFolder -Force | Out-Null
            Assert-Throws { Get-InstallPluginRoot -Entry $entry -ConfigDir $missingFolder } 'Unrelated Codex existing-home listing errors still stop the update'
        } finally { Remove-Item -LiteralPath $missingFolder }
    }

    & {
        . $installerPath -NoRun
        $script:installCatalog = Get-InstallCatalog -Source $repo
        $entry = Get-InstallTool claude
        $sandbox = New-InstallTestFolder 'nested-manifests'
        $cache = Join-Path $sandbox $entry.plugin.installedRoot
        function Invoke-ClosedInput { @{ExitCode=0; Output=@('[{"id":"legion@ps-legion-marketplace","enabled":true}]')} }
        try {
            $manifest = '{"name":"legion","version":"0.8.0"}'
            foreach ($folder in @('0.8.0', '0.8.0/.claude-plugin', '0.8.0/.codex-plugin')) {
                New-Item -ItemType Directory -Path (Join-Path $cache $folder) -Force | Out-Null
                $manifest | Set-Content -LiteralPath (Join-Path $cache "$folder/plugin.json")
            }
            Assert-Equal (Join-Path $cache '0.8.0') (Get-InstallPluginRoot -Entry $entry -ConfigDir $sandbox) 'Nested tool manifests are not separate copies'
            New-Item -ItemType Directory -Path (Join-Path $cache '0.9.0') -Force | Out-Null
            $manifest | Set-Content -LiteralPath (Join-Path $cache '0.9.0/plugin.json')
            Assert-Throws { Get-InstallPluginRoot -Entry $entry -ConfigDir $sandbox } 'Two real copies stay ambiguous'
        } finally {
            Remove-InstallTestFolder $sandbox
        }
    }
}

Invoke-InstallTestCase 'Refresh' {
    & {
        . $installerPath -NoRun
        $script:installCatalog = Get-InstallCatalog -Source $repo
        $entry = Get-InstallTool claude
        $sandbox = New-InstallTestFolder 'install-refresh'
        $oldPlugin = Join-Path $sandbox 'cache/old'
        $newPlugin = Join-Path $sandbox 'cache/new'
        $marker = Join-Path $sandbox 'refreshed.txt'
        $selectedAccount = Join-Path $sandbox 'selected-account'
        New-Item -ItemType Directory -Path $selectedAccount -Force | Out-Null
        $state = @{Updated=$false; Fail=$false; Missing=$false; Disappeared=$false}
        $realClosedInput = ${function:Invoke-ClosedInput}
        . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome (Join-Path $sandbox 'selected-home')
        function Invoke-ClosedInput {
            param($Command, $Environment)
            if ($Command[0] -ne 'claude') { return & $realClosedInput -Command $Command -Environment $Environment }
            Assert-Equal $selectedAccount $Environment.CLAUDE_CONFIG_DIR 'Listing and update use selected account'
            if ($Command -contains 'marketplace' -and $Command -contains 'list') { return @{ExitCode=0;Output=@('[]')} }
            if ($Command[2] -eq 'list') {
                if ($state.Missing -or ($state.Updated -and $state.Disappeared)) { return @{ExitCode=0;Output=@('[]')} }
                $path = if ($state.Updated) { $newPlugin } else { $oldPlugin }
                $json = @(@{id='legion@ps-legion-marketplace'; enabled=$true; installPath=$path}) | ConvertTo-Json -Compress -AsArray
                return @{ExitCode=0;Output=@($json)}
            }
            if ($state.Fail) { return @{ExitCode=8;Output=@()} }
            if ($Command[1] -eq 'plugin' -and $Command[2] -eq 'update') { $state.Updated=$true }
            if ($Command[1] -eq 'plugin' -and $Command[2] -eq 'install') { $state.Missing=$false; $state.Updated=$true }
            return @{ExitCode=0;Output=@()}
        }
        try {
            foreach ($folder in @($oldPlugin,$newPlugin)) {
                New-Item -ItemType Directory -Path (Join-Path $folder 'bin') -Force | Out-Null
                '{"name":"legion","version":"0.3.0"}' | Set-Content (Join-Path $folder 'plugin.json')
            }
            'throw "stale refresh script invoked"' | Set-Content (Join-Path $oldPlugin 'bin/legion-refresh.ps1')
            ('param($HomeRoot); $HomeRoot | Set-Content -LiteralPath ''' + $marker.Replace("'", "''") + '''') | Set-Content (Join-Path $newPlugin 'bin/legion-refresh.ps1')
            $null = Invoke-LegionUpdateSteps -Entry $entry -ConfigDir $selectedAccount
            Assert-True (Test-Path -LiteralPath $marker) 'Successful update invokes freshly installed refresh script'
            Assert-Equal (Get-InstallHome) ((Get-Content $marker -Raw).Trim()) 'Refresh receives the selected owner home'
            Remove-Item $marker
            $state.Fail=$true
            Assert-Throws { Invoke-LegionUpdateSteps -Entry $entry -ConfigDir $selectedAccount } 'Failed update propagates'
            Assert-True (-not (Test-Path $marker)) 'Failed update never refreshes generated artifacts'
            $state.Fail=$false
            $state.Missing=$true
            $null = Invoke-LegionUpdateSteps -Entry $entry -ConfigDir $selectedAccount
            Assert-True (Test-Path $marker) 'Missing plugin is installed then its fresh artifacts are refreshed'
            Remove-Item $marker
            $state.Missing=$false
            $null = Invoke-LegionUpdateSteps -Entry $entry -ConfigDir $selectedAccount -DryRun
            Assert-True (-not (Test-Path $marker)) 'Preview never invokes refresh'
            $state.Disappeared=$true
            New-Item -ItemType Directory -Path (Join-Path $sandbox 'selected-home/.claude/plugins/cache/ps-legion-marketplace/legion') -Force | Out-Null
            Copy-Item -LiteralPath $newPlugin -Destination (Join-Path $sandbox 'selected-home/.claude/plugins/cache/ps-legion-marketplace/legion/0.3.0') -Recurse
            $previousConfig = $env:CLAUDE_CONFIG_DIR
            try {
                $env:CLAUDE_CONFIG_DIR = $selectedAccount
                Assert-Throws { Invoke-InstallRefresh -Entry $entry -ConfigDir $selectedAccount } 'Absent post-update plugin cannot use a leftover cache'
            } finally { $env:CLAUDE_CONFIG_DIR = $previousConfig }
            Assert-True (-not (Test-Path $marker)) 'Leftover cache is never refreshed as an installed plugin'
            $state.Disappeared=$false
            Remove-Item (Join-Path $newPlugin 'bin/legion-refresh.ps1')
            Assert-Throws { Invoke-LegionUpdateSteps -Entry $entry -ConfigDir $selectedAccount } 'Unresolvable installed refresh script is reported'
        } finally {
            Remove-InstallTestFolder $sandbox
        }
    }

    & {
        . $installerPath -NoRun
        $script:installCatalog = Get-InstallCatalog -Source $repo
        $sandbox = New-InstallTestFolder 'refresh-cache'
        $configRoot = Join-Path $sandbox 'selected-account'
        $calls = [Collections.Generic.List[object]]::new()
        . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome (Join-Path $sandbox 'selected-home')
        function Invoke-ClosedInput {
            param($Command, $Environment)
            if ($Command[0] -eq 'copilot') { return @{ExitCode=0;Output=@('legion@ps-legion-marketplace (v0.3.0) (enabled)')} }
            $calls.Add($Command)
            @{ExitCode=0;Output=@()}
        }
        try {
            foreach ($version in @('0.2.0','0.3.0')) {
                $plugin = Join-Path $configRoot "installed-plugins/arbitrary-layout/$version"
                New-Item -ItemType Directory -Path (Join-Path $plugin 'bin') -Force | Out-Null
                ('{"name":"legion","version":"' + $version + '"}') | Set-Content (Join-Path $plugin 'plugin.json')
                '# inert refresh fixture' | Set-Content (Join-Path $plugin 'bin/legion-refresh.ps1')
            }
            $null = Invoke-InstallRefresh -Entry (Get-InstallTool copilot) -ConfigDir $configRoot
            Assert-Equal 1 $calls.Count 'Selected Copilot installed-files root supplies one refresh'
            Assert-Equal (Join-Path $configRoot 'installed-plugins/arbitrary-layout/0.3.0/bin/legion-refresh.ps1') $calls[0][3] 'Listing version selects the matching cached plugin'
            Assert-Equal (Get-InstallHome) $calls[0][5] 'Cache fallback retains selected home'
            $other = Join-Path $configRoot 'installed-plugins/ambiguous-copy'
            Copy-Item -LiteralPath (Join-Path $configRoot 'installed-plugins/arbitrary-layout/0.3.0') -Destination $other -Recurse
            Assert-Throws { Invoke-InstallRefresh -Entry (Get-InstallTool copilot) -ConfigDir $configRoot } 'Ambiguous installed copies require an explicit path'
            Assert-Equal 1 $calls.Count 'Ambiguous cache never launches a guessed refresh script'

            # A directory marketplace is loaded live; Copilot lists its root on the next line.
            $marketplace = Join-Path $sandbox 'live-marketplace'
            $livePlugin = Join-Path $marketplace 'extensions/orchestration'
            New-Item -ItemType Directory -Path (Join-Path $marketplace '.claude-plugin'), (Join-Path $livePlugin 'bin') -Force | Out-Null
            '{"plugins":[{"name":"legion","source":"./extensions/orchestration"}]}' | Set-Content -LiteralPath (Join-Path $marketplace '.claude-plugin/marketplace.json')
            '{"name":"legion","version":"0.6.0"}' | Set-Content -LiteralPath (Join-Path $livePlugin 'plugin.json')
            '# inert live refresh fixture' | Set-Content -LiteralPath (Join-Path $livePlugin 'bin/legion-refresh.ps1')
            function Invoke-ClosedInput {
                param($Command, $Environment)
                if ($Command[0] -eq 'copilot') {
                    return @{ ExitCode = 0; Output = @('Live Plugins (loaded from a local marketplace directory, never copied):', '  • legion@ps-legion-marketplace (v0.6.0) (enabled)', "      from $marketplace") }
                }
                $calls.Add($Command)
                return @{ ExitCode = 0; Output = @() }
            }
            $freshAccount = Join-Path $sandbox 'fresh-account'
            New-Item -ItemType Directory -Path $freshAccount -Force | Out-Null
            $null = Invoke-InstallRefresh -Entry (Get-InstallTool copilot) -ConfigDir $freshAccount
            Assert-Equal 2 $calls.Count 'Live Copilot update refreshes without a copied plugin cache'
            Assert-Equal ([IO.Path]::GetFullPath((Join-Path $livePlugin 'bin/legion-refresh.ps1'))) ([IO.Path]::GetFullPath($calls[1][3])) 'Live refresh follows the marketplace plugin source'
        } finally {
            Remove-InstallTestFolder $sandbox
        }
    }
}

Invoke-InstallTestCase 'RefreshDescriptor' {
    & {
        . $installerPath -NoRun
        $script:installCatalog = Get-InstallCatalog -Source $repo
        $entry = Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth/tool.json') -Raw | ConvertFrom-Json
        $entry.plugin | Add-Member defaultConfigDir '~/.fixture-agent-data'
        $entry.plugin | Add-Member installedRoot 'actual-installed-files'
        $script:installCatalog.tools += $entry
        $sandbox = New-InstallTestFolder 'refresh-descriptor'
        $plugin = Join-Path $sandbox '.fixture-agent-data/actual-installed-files/arbitrary-plugin-folder'
        $calls = [Collections.Generic.List[object]]::new()
        . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome ($sandbox)
        function Invoke-ClosedInput {
            param($Command, $Environment)
            if ($Command[0] -eq 'fourth-cli') { return @{ExitCode=0; Output=@('legion@ps-legion-marketplace (v0.3.0) (enabled)')} }
            $calls.Add($Command)
            @{ExitCode=0; Output=@()}
        }
        try {
            New-Item -ItemType Directory -Path (Join-Path $plugin 'bin') -Force | Out-Null
            '{"name":"legion","version":"0.3.0"}' | Set-Content (Join-Path $plugin 'plugin.json')
            '# inert refresh fixture' | Set-Content (Join-Path $plugin 'bin/legion-refresh.ps1')
            $null = Invoke-InstallRefresh -Entry $entry
            Assert-Equal 1 $calls.Count 'Fourth tool refresh uses descriptor config root and installed-files path'
            Assert-Equal (Join-Path $plugin 'bin/legion-refresh.ps1') $calls[0][3] 'Shared installer does not guess fourth tool directory layout'
            $entry.plugin.PSObject.Properties.Remove('defaultConfigDir')
            $errorMessage = ''
            try { Invoke-InstallRefresh -Entry $entry } catch { $errorMessage = $_.Exception.Message }
            Assert-True ($errorMessage.Contains('defaultConfigDir')) 'Missing default-root metadata names the descriptor field'
            $entry.plugin.PSObject.Properties.Remove('installedRoot')
            $errorMessage = ''
            try { Invoke-InstallRefresh -Entry $entry -ConfigDir $sandbox } catch { $errorMessage = $_.Exception.Message }
            Assert-True ($errorMessage.Contains('installedRoot')) 'Missing installed-root metadata is reported without guessing'
        } finally {
            Remove-InstallTestFolder $sandbox
        }
    }

    & {
        . $installerPath -NoRun
        $descriptor = Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth/tool.json') -Raw | ConvertFrom-Json
        $descriptor.plugin | Add-Member defaultConfigDir '~/.fixture-agent-data'
        $descriptor.plugin | Add-Member installedRoot 'actual-installed-files'
        foreach ($field in @('installedRoot','defaultConfigDir')) {
            foreach ($badValue in @('../outside','/absolute','C:/absolute','~/../outside',42,'')) {
                $bad = $descriptor | ConvertTo-Json -Depth 100 | ConvertFrom-Json
                $bad.plugin.$field = $badValue
                Assert-True (-not (Test-Json -Json ($bad | ConvertTo-Json -Depth 100) -SchemaFile (Join-Path $repo 'plugins/legion/schemas/tool.schema.json') -ErrorAction SilentlyContinue)) "Schema rejects unsafe plugin.$field before catalog generation"
            }
        }
    }
}

Invoke-InstallTestCase 'RefreshForwarder' {
    & {
        # An installer 0.15 or older calls legion-refresh.ps1 by path with -HomeRoot; it must reach `legion refresh`.
        $sandbox = New-InstallTestFolder 'install-refresh-forwarder'
        try {
            $fake = Join-Path $sandbox 'fake-uv.ps1'
            @'
$args | ConvertTo-Json -Compress
[Console]::Error.WriteLine('fixture stderr')
exit ([int]$env:FAKE_UV_EXIT)
'@ | Set-Content -LiteralPath $fake
            $null = New-TestCommandStub -Folder (Join-Path $sandbox 'bin') -Name uv -Script $fake
            $selectedHome = Join-Path $sandbox 'selected home'
            $forwarder = Join-Path $repo 'plugins/legion/bin/legion-refresh.ps1'
            $env:PATH = (Join-Path $sandbox 'bin') + [IO.Path]::PathSeparator + $env:PATH
            foreach ($code in @(0, 3)) {
                $env:FAKE_UV_EXIT = "$code"
                $output = @(& (Get-InstallTestPwsh) -NoProfile -File $forwarder -HomeRoot $selectedHome 2>&1 | ForEach-Object { "$_" })
                Assert-Equal $code $LASTEXITCODE "The forwarder passes legion refresh exit code $code on"
                $arguments = @($output[0] | ConvertFrom-Json)
                Assert-Equal "--frozen|legion|--home|$selectedHome|refresh" (($arguments | Select-Object -Skip 3) -join '|') 'The forwarder runs legion refresh for the given home'
                Assert-True ($output -contains 'fixture stderr') 'The forwarder passes the error output on'
            }
        } finally {
            Remove-Item Env:FAKE_UV_EXIT -ErrorAction SilentlyContinue
            Remove-InstallTestFolder $sandbox
        }
    }
}
