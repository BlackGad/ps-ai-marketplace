# Fresh, replaced and stale marketplaces, fresh Codex home and hook status.
. (Join-Path $PSScriptRoot 'lib/installer.ps1')

Invoke-InstallTestCase 'FreshMarketplace' {
    $fixtureConfig0 = Join-Path $env:HOME 'selected account'
    New-Item -ItemType Directory -Path $fixtureConfig0 -Force | Out-Null
    . $installerPath -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $calls = [Collections.Generic.List[string]]::new()
    $state = @{ Added=$false; Refreshed=$false; FailRefresh=$false }
    function Invoke-ClosedInput {
        param($Command, $Environment)
        Assert-Equal $fixtureConfig0 $Environment.CLAUDE_CONFIG_DIR 'Fresh install uses selected config'
        $line = $Command -join '|'
        $calls.Add($line)
        switch ($line) {
            'claude|plugin|marketplace|list|--json' { return @{ExitCode=0; Output=@('[]')} }
            'claude|plugin|list|--json' { return @{ExitCode=0; Output=@('[]')} }
            'claude|plugin|marketplace|add|BlackGad/ps-legion-marketplace#stable' { $state.Added=$true }
            'claude|plugin|marketplace|update|ps-legion-marketplace' {
                Assert-True $state.Added 'Refresh follows marketplace add'
                if ($state.FailRefresh) { return @{ExitCode=2; Output=@('fixture refresh failed')} }
                $state.Refreshed=$true
            }
            'claude|plugin|install|legion@ps-legion-marketplace' {
                if (-not $state.Refreshed) { return @{ExitCode=1; Output=@('Plugin "legion" not found in marketplace "ps-legion-marketplace". Your local copy may be out of date — try claude plugin marketplace update ps-legion-marketplace')} }
            }
            default { throw "Unexpected fake command: $line" }
        }
        return @{ExitCode=0; Output=@()}
    }
    $null = Invoke-LegionInstallSteps -Tool claude -Source 'BlackGad/ps-legion-marketplace' -ConfigEnv CLAUDE_CONFIG_DIR -ConfigDir $fixtureConfig0
    Assert-True $state.Refreshed 'Fresh GitHub marketplace is refreshed before plugin install'
    Assert-Equal 'claude|plugin|install|legion@ps-legion-marketplace' $calls[-1] 'Plugin install follows refresh'
    $calls.Clear()
    $state.FailRefresh=$true
    Assert-Throws { Invoke-LegionInstallSteps -Tool claude -Source 'BlackGad/ps-legion-marketplace' -ConfigEnv CLAUDE_CONFIG_DIR -ConfigDir $fixtureConfig0 } 'Failed marketplace refresh stops plugin install'
    Assert-True (-not ($calls -contains 'claude|plugin|install|legion@ps-legion-marketplace')) 'Plugin never installs from a failed refresh'
}

Invoke-InstallTestCase 'ReplacedMarketplace' {
    $fixtureConfig0 = Join-Path $env:HOME 'selected account'
    New-Item -ItemType Directory -Path $fixtureConfig0 -Force | Out-Null
    . (Join-Path $PSScriptRoot 'fixtures/install/MarketplaceListing.ps1')
    . $installerPath -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $fourth = Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth/tool.json') -Raw | ConvertFrom-Json
    $script:installCatalog.tools += $fourth
    foreach ($entry in $script:installCatalog.tools) {
        $state = @{ Added=$false }
        $writes = [Collections.Generic.List[string]]::new()
        function Invoke-ClosedInput {
            param($Command, $Environment)
            Assert-Equal $fixtureConfig0 ($Environment[$entry.configEnv]) 'Every step uses selected config'
            $line = $Command -join '|'
            if ($line -ceq ((@($entry.command) + $entry.plugin.marketplaceList) -join '|')) {
                $source = if ($state.Added) { 'example/new-source' } else { '' }
                $output = @(Get-FixtureMarketplaceListing -Tool $entry.id -Source $source)
                return @{ExitCode=0; Output=$output}
            }
            if ($line -ceq ((@($entry.command) + $entry.plugin.list) -join '|')) {
                $output = if ($entry.plugin.listing.format -eq 'json') { @('[{"id":"legion@ps-legion-marketplace","enabled":true}]') }
                    else { @('legion@ps-legion-marketplace installed, enabled') }
                return @{ExitCode=0; Output=$output}
            }
            $writes.Add($line)
            if ($Command -contains 'example/new-source' -or $Command -contains 'example/new-source#stable') { $state.Added=$true }
            return @{ExitCode=0; Output=@()}
        }
        $null = Invoke-LegionInstallSteps -Tool $entry.id -Source 'example/new-source' -ConfigEnv $entry.configEnv -ConfigDir $fixtureConfig0
        Assert-True ($writes -contains ((@($entry.command) + $entry.plugin.install) -join '|')) "$($entry.id) newly added marketplace reinstalls an existing cached plugin"
        Assert-Equal 3 $writes.Count "$($entry.id) runs add, refresh and install from descriptor"
        Assert-Equal ((@($entry.command) + $entry.plugin.marketplaceUpdate) -join '|') $writes[1] 'Refresh uses tool data'
        $writes.Clear()
        $repeat = @(Invoke-LegionInstallSteps -Tool $entry.id -Source 'example/new-source' -ConfigEnv $entry.configEnv -ConfigDir $fixtureConfig0)
        Assert-Equal 0 $writes.Count 'Matching marketplace and installed plugin remain idempotent'
        Assert-Equal 2 @($repeat | Where-Object { $_ -match '^skip: ' }).Count 'Repeat skips both steps'
    }
}

Invoke-InstallTestCase 'StaleMarketplace' {
    & {
        . $installerPath -NoRun
        $script:installCatalog = Get-InstallCatalog -Source $repo
        $sandbox = New-InstallTestFolder 'stale-marketplace'
        $checkout = Join-Path $sandbox 'checkout'
        $state = @{ Installed = $false; Calls = [Collections.Generic.List[string]]::new(); FailRefresh = $false }
        function Invoke-ClosedInput {
            param($Command, $Environment)
            Assert-Equal $sandbox $Environment.CODEX_HOME 'Stale marketplace recovery uses selected account'
            $line = $Command -join '|'
            if ($line -eq 'codex|plugin|marketplace|list|--json') {
                return @{ ExitCode=0; Output=@(@{ marketplaces=@(@{ name='ps-legion-marketplace'; root=$checkout; marketplaceSource=@{sourceType='git';source='https://github.com/BlackGad/ps-legion-marketplace.git'} }) } | ConvertTo-Json -Depth 10 -Compress) }
            }
            if ($line -eq 'codex|plugin|list') {
                $output = if ($state.Installed) { @('legion@ps-legion-marketplace installed, enabled') } else { @() }
                return @{ ExitCode=0; Output=$output }
            }
            $state.Calls.Add($line)
            if ($line -eq 'codex|plugin|marketplace|upgrade') {
                if ($state.FailRefresh) { return @{ExitCode=1; Output=@(); ErrorOutput=@('fixture refresh failure')} }
                New-Item -ItemType Directory -Path $checkout -Force | Out-Null
            } elseif ($line -eq 'codex|plugin|add|legion@ps-legion-marketplace') {
                if (-not (Test-Path -LiteralPath $checkout)) { throw 'registered marketplace root is missing' }
                $state.Installed = $true
            } else { throw "Unexpected mutation: $line" }
            return @{ExitCode=0; Output=@(); ErrorOutput=@()}
        }
        try {
            New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
            $null = Invoke-LegionInstallSteps -Tool codex -Source 'BlackGad/ps-legion-marketplace' -ConfigEnv CODEX_HOME -ConfigDir $sandbox
            Assert-Equal 'codex|plugin|marketplace|upgrade,codex|plugin|add|legion@ps-legion-marketplace' ($state.Calls -join ',') 'Missing root refreshes before plugin install without re-registering'
            $state.Calls.Clear()
            $null = Invoke-LegionInstallSteps -Tool codex -Source 'BlackGad/ps-legion-marketplace' -ConfigEnv CODEX_HOME -ConfigDir $sandbox
            Assert-Equal 0 $state.Calls.Count 'Healthy repeat does not mutate the account'
            $state.Installed = $false
            $null = Invoke-LegionInstallSteps -Tool codex -Source 'BlackGad/ps-legion-marketplace' -ConfigEnv CODEX_HOME -ConfigDir $sandbox
            Assert-Equal 'codex|plugin|marketplace|upgrade' $state.Calls[0] 'Missing plugin refreshes an existing checkout'
            $state.Calls.Clear()
            Remove-Item -LiteralPath $checkout
            $preview = @(Invoke-LegionInstallSteps -Tool codex -Source 'BlackGad/ps-legion-marketplace' -ConfigEnv CODEX_HOME -ConfigDir $sandbox -DryRun)
            Assert-True (@($preview) -match 'plugin marketplace upgrade') 'Dry run previews stale-root refresh even with an installed plugin'
            Assert-Equal 0 $state.Calls.Count 'Dry run makes no mutations'
            $state.FailRefresh = $true
            Assert-Throws { Invoke-LegionInstallSteps -Tool codex -Source 'BlackGad/ps-legion-marketplace' -ConfigEnv CODEX_HOME -ConfigDir $sandbox } 'Failed refresh stops installation'
            Assert-Equal 1 $state.Calls.Count 'Refresh failure never reaches plugin install'
        } finally {
            Remove-InstallTestFolder $sandbox
        }
    }

    & {
        . $installerPath -NoRun
        $script:installCatalog = Get-InstallCatalog -Source $repo
        $entry = Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth/tool.json') -Raw | ConvertFrom-Json
        $entry.plugin.marketplaceUpdate = @('refresh-fixture-market')
        $script:installCatalog.tools += $entry
        $calls = [Collections.Generic.List[string]]::new()
        function Test-InstallStepDone { param($Command) $Command -contains 'marketplace' }
        function Invoke-InstallCommand { param($Command) $calls.Add(($Command -join '|')) }
        $null = Invoke-LegionInstallSteps -Tool fourth -Source 'example/market' -ConfigEnv FOURTH_HOME
        Assert-Equal 'fourth-cli|refresh-fixture-market' $calls[0] 'Registered marketplace without plugin uses descriptor refresh command'
        Assert-Equal 2 $calls.Count 'Generic recovery refreshes and installs without adding the registration'
    }
}

Invoke-InstallTestCase 'FreshCodexHome' {
    . $installerPath -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $sandbox = New-InstallTestFolder 'fresh-codex'
    $folder = Join-Path $sandbox 'config'
    $realCommand = ${function:Invoke-InstallCommand}
    function Invoke-ClosedInput { throw 'Missing selected folder must not be listed' }
    foreach ($entry in $script:installCatalog.tools) {
        Assert-True (-not (Test-InstallStepDone -Command @($entry.command) -ConfigEnv $entry.configEnv -ConfigDir $folder)) 'Missing selected folder has no installed plugin for every tool'
        Assert-True ($null -eq (Get-InstallPluginRoot -Entry $entry -ConfigDir $folder)) 'Missing selected folder has no plugin root'
    }
    function Invoke-ClosedInput { @{ExitCode=0; Output=@()} }
    foreach ($entry in $script:installCatalog.tools) {
        & $realCommand -Command (@($entry.command) + $entry.plugin.uninstall) -ConfigEnv $entry.configEnv -ConfigDir $folder
        & $realCommand -Command (@($entry.command) + $entry.plugin.marketplaceRemove) -ConfigEnv $entry.configEnv -ConfigDir $folder
        Assert-True (-not (Test-Path -LiteralPath $folder)) 'Uninstall commands never create a missing folder for any tool'
    }
    function Invoke-ClosedInput {
        param($Command, $Environment)
        Assert-True (Test-Path -LiteralPath $Environment[$entry.configEnv] -PathType Container) 'Every tool gets an existing selected folder before install commands'
        @{ExitCode=0; Output=@('[]')}
    }
    foreach ($entry in $script:installCatalog.tools) {
        $null = Invoke-LegionInstallSteps -Tool $entry.id -Source $repo -ConfigEnv $entry.configEnv -ConfigDir $folder
        Remove-Item -LiteralPath $folder
    }
    $state = @{ Installed = $false; Mutations = 0; FailListing = $false }
    function Invoke-ClosedInput {
        param($Command, $Environment)
        Assert-Equal $folder $Environment.CODEX_HOME 'Fresh Codex uses the selected home'
        if ($Command -contains 'list') {
            if (-not (Test-Path -LiteralPath $folder)) {
                return @{ ExitCode=1; Output=@(); ErrorOutput=@('Error: failed to resolve CODEX_HOME', "CODEX_HOME points to `"$folder`", but that path does not exist") }
            }
            if ($state.FailListing) { return @{ ExitCode=1; Output=@(); ErrorOutput=@('fixture permission denied') } }
            if ($Command -contains 'marketplace') {
                $listing = @{ marketplaces=@(@{ name='ps-legion-marketplace'; root=$folder }) } | ConvertTo-Json -Depth 4 -Compress
                return @{ ExitCode=0; Output=@($listing) }
            }
            $output = if ($state.Installed) { 'legion@ps-legion-marketplace enabled' } else { 'No marketplace plugins found.' }
            return @{ ExitCode=0; Output=@($output) }
        }
        Assert-True (Test-Path -LiteralPath $folder -PathType Container) 'Codex home exists before a mutating command'
        $state.Mutations++
        if ($Command -notcontains 'marketplace') { $state.Installed = $true }
        return @{ ExitCode=0; Output=@() }
    }
    try {
        $preview = @(Invoke-LegionInstallSteps -Tool codex -Source $repo -ConfigEnv CODEX_HOME -ConfigDir $folder -DryRun)
        Assert-True (($preview -join "`n") -like '*plugin marketplace add*') 'Missing Codex home previews a fresh install'
        Assert-True (-not (Test-Path -LiteralPath $folder)) 'Preview leaves the missing home untouched'
        Assert-Equal 0 $state.Mutations 'Preview never runs a mutating CLI command'
        $null = Invoke-LegionInstallSteps -Tool codex -Source $repo -ConfigEnv CODEX_HOME -ConfigDir $folder
        Assert-True $state.Installed 'Fresh logged-out Codex home installs legion'
        $mutations = $state.Mutations
        $repeat = @(Invoke-LegionInstallSteps -Tool codex -Source $repo -ConfigEnv CODEX_HOME -ConfigDir $folder)
        Assert-Equal $mutations $state.Mutations 'Repeat install makes no changes'
        Assert-True (($repeat -join "`n") -like '*skip:*') 'Repeat install reports already done'
        $state.FailListing = $true
        Assert-Throws { Invoke-LegionInstallSteps -Tool codex -Source $repo -ConfigEnv CODEX_HOME -ConfigDir $folder } 'Other Codex listing errors still fail'
    } finally {
        Remove-InstallTestFolder $sandbox
    }
}

Invoke-InstallTestCase 'Hooks' {
    . (Join-Path $PSScriptRoot 'fixtures/install/MarketplaceListing.ps1')
    . $installerPath -NoRun
    . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome (New-InstallTestFolder 'unused-installer')
    $fixturePlugin = New-InstallFixturePlugin -Path (Join-Path (Get-InstallHome) 'installed')
    function Invoke-InstallRefresh { }
    function Invoke-ClosedInput {
        param($Command, $Environment)
        Assert-Equal 'copilot' $Command[0] 'Only fake Copilot commands run'
        if ($Command -contains 'list') {
            $listing = if ($Command -contains 'marketplace') { Get-FixtureMarketplaceListing -Tool copilot } else { "legion@ps-legion-marketplace installed (enabled) $fixturePlugin" }
            return @{ExitCode=0; Output=@($listing)}
        }
        return @{ExitCode=0; Output=@()}
    }
    $catalog = Get-InstallCatalog -Source $repo
    $table = Invoke-LegionInstaller -Tools copilot -Source $repo -Catalog $catalog -Yes | Out-String
    Assert-True ($table.Contains('loaded with plugin')) 'Copilot summary explains hook loading from tool data'
    Assert-True (-not $table.Contains('unknown')) 'Successful Copilot install never reports unknown hooks'
    Assert-Equal 'loaded with plugin' ($catalog.tools | Where-Object id -EQ copilot).hooks.status 'Hook status lives in descriptor data'
}
