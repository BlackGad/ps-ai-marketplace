# Plugin and marketplace listings as the installer reads them.
. (Join-Path $PSScriptRoot 'lib/installer.ps1')

Invoke-InstallTestCase 'Listing' {
    . $installerPath -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $listing = Read-InstallPluginListing -Entry (Get-InstallTool claude) -Lines @('[{"id":"legion@ps-legion-marketplace","enabled":false,"installPath":"/absent/plugin","version":"0.8.0"}]')
    Assert-True $listing.Listed 'One parse finds the disabled installed plugin'
    Assert-True (-not $listing.Enabled) 'One parse retains disabled state'
    Assert-Equal '/absent/plugin' $listing.Path 'Listing parser returns a path without touching disk'
    Assert-Equal '0.8.0' $listing.Version 'One parse retains the listed version'
    $listing = Read-InstallPluginListing -Entry (Get-InstallTool copilot) -Lines @('legion@ps-legion-marketplace (v0.8.0) (disabled)', '    from /absent/marketplace')
    Assert-True $listing.Listed 'Text listing finds disabled plugins'
    Assert-True (-not $listing.Enabled) 'Text listing retains disabled state'
    Assert-Equal '/absent/marketplace' $listing.MarketplacePath 'Live marketplace path stays unresolved until needed'
    Assert-Equal '0.8.0' $listing.Version 'Text version is parsed with the plugin'
    # Launch only an inert PowerShell fixture; never a real coding CLI.
    $result = Invoke-ClosedInput -Command @('pwsh', '-NoProfile', '-Command', '[Console]::Out.Write(''[{"id":"legion@ps-legion-marketplace","enabled":true}]''); [Console]::Error.WriteLine(''fixture warning'')')
    Assert-Equal '[{"id":"legion@ps-legion-marketplace","enabled":true}]' ($result.Output -join "`n") 'Listing stdout excludes stderr warning'
    Assert-Equal 'fixture warning' ($result.ErrorOutput -join "`n") 'CLI stderr is retained separately'
    Assert-True (Test-InstallListing -Kind plugin -Tool claude -Lines $result.Output) 'Valid JSON remains installed with a stderr warning'
    function Invoke-ClosedInput { @{ExitCode=7; Output=@()} }
    Assert-Throws { Test-InstallStepDone -Command @('claude','plugin','install','legion@ps-legion-marketplace') } 'Initial install listing failure is distinct from absence'
    function Invoke-ClosedInput { @{ExitCode=7; Output=@('  fixture stdout  '); ErrorOutput=@('  fixture stderr  ')} }
    $message = ''
    try { Test-InstallStepDone -Command @('claude','plugin','install','legion@ps-legion-marketplace') }
    catch { $message = $_.Exception.Message }
    Assert-Equal "claude listing exited 7`nfixture stderr`nfixture stdout" $message 'Listing failure includes trimmed stderr and stdout'
    Assert-Throws { Test-InstallListing -Kind plugin -Tool claude -Lines @('invalid JSON') } 'Malformed successful listing is a failure, not absent plugin'
    Assert-True (-not (Test-InstallListing -Kind plugin -Tool claude -Lines @('[]'))) 'Valid empty JSON is absent plugin'
}

Invoke-InstallTestCase 'ListingEnvironment' {
    . $installerPath -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $realProcess = ${function:Invoke-ClosedInput}
    $saved = [Environment]::GetEnvironmentVariable('CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC', 'Process')
    $savedConfig = $env:CLAUDE_CONFIG_DIR
    $folder = Join-Path $env:HOME 'listing account'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    function Invoke-ClosedInput {
        param($Command, $Environment)
        $json = if ($Command -contains 'marketplace') { '[{"name":"ps-legion-marketplace","source":"github","repo":"BlackGad/ps-legion-marketplace"}]' }
            else { '[{"id":"legion@ps-legion-marketplace","enabled":true}]' }
        Assert-Equal $savedConfig $env:CLAUDE_CONFIG_DIR 'Listing leaves parent config unchanged while the child runs'
        $configCheck = if ($Environment.CLAUDE_CONFIG_DIR) { '$env:CLAUDE_CONFIG_DIR -ceq ''' + $folder.Replace("'", "''") + "'" }
            else { '-not (Test-Path Env:CLAUDE_CONFIG_DIR)' }
        $code = 'if ($env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC -eq ''1'' -and (' + $configCheck + ')) { [Console]::Out.Write(''' + $json + ''') } else { [Console]::Out.Write(''[]'') }'
        & $realProcess -Command @('pwsh', '-NoProfile', '-Command', $code) -Environment $Environment
    }
    try {
        $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '0'
        $commands = Get-InstallCommands -Tool claude -Source 'BlackGad/ps-legion-marketplace'
        foreach ($target in @('', $folder)) {
            for ($index = 0; $index -lt $commands.Count; $index++) {
                $kind = if ($index -eq 0) { 'marketplace' } else { 'plugin' }
                Assert-True (Test-InstallStepDone -Command $commands[$index] -Kind $kind -ConfigDir $target) 'Both listings merge config and descriptor environment in the child'
                Assert-Equal '0' $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 'Listing environment only affects child process'
            }
        }
        Assert-True (-not $script:installCatalog.tools[0].plugin.listingEnv.PSObject.Properties['CLAUDE_CONFIG_DIR']) 'Merging never changes the catalog environment'
    } finally {
        if ($null -eq $saved) { Remove-Item Env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = $saved }
    }
}

Invoke-InstallTestCase 'DefaultEnvironment' {
    . $installerPath -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $entry = Get-InstallTool -Tool claude
    $realProcess = ${function:Invoke-ClosedInput}
    $savedOverride = $env:CLAUDE_CONFIG_DIR
    try {
        $env:CLAUDE_CONFIG_DIR = 'inherited-account'
        foreach ($empty in @($null, '')) {
            $child = & $realProcess -Command @('pwsh', '-NoProfile', '-Command', '[Console]::Write((Test-Path Env:CLAUDE_CONFIG_DIR))') -Environment @{CLAUDE_CONFIG_DIR=$empty}
            Assert-Equal 'False' ($child.Output -join '') 'Default-home child removes inherited config variable'
            Assert-Equal 'inherited-account' $env:CLAUDE_CONFIG_DIR 'Child environment leaves caller untouched'
        }
    } finally {
        if ($null -eq $savedOverride) { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_CONFIG_DIR = $savedOverride }
    }
    $captured = Get-Content (Join-Path $PSScriptRoot 'fixtures/install/listings/claude-plugins.json')
    Assert-True (Test-InstallListing -Kind plugin -Tool claude -Lines $captured -IncludeDisabled) 'Captured user-scope Claude plugin is installed despite projectEnabled false'
    $sandbox = New-InstallTestFolder 'default-environment'
    . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome $sandbox
    $fixturePlugin = New-InstallFixturePlugin -Path (Join-Path $sandbox 'installed')
    $plugins = ($captured -join "`n") | ConvertFrom-Json
    $plugins[0].installPath = $fixturePlugin
    $captured = @(ConvertTo-Json -InputObject @($plugins) -Depth 10)
    $saved = [Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR', 'Process')
    $observed = [Collections.Generic.List[string]]::new()
    function Invoke-ClosedInput {
        param($Command, $Environment)
        $observed.Add(($Command -join '|'))
        # Real Claude returns [] when the variable is present but empty.
        Assert-True ($Environment.ContainsKey('CLAUDE_CONFIG_DIR')) 'Default listing explicitly overrides inherited config'
        Assert-True ([string]::IsNullOrEmpty($Environment.CLAUDE_CONFIG_DIR)) 'Default listing requests removal in the child'
        $output = $captured
        @{ExitCode=0; Output=$output; ErrorOutput=@()}
    }
    function Invoke-InstallRefresh { }
    try {
        $env:CLAUDE_CONFIG_DIR = 'selected-account'
        $output = @(Invoke-LegionUpdateSteps -Entry $entry)
        Assert-True ($observed -contains 'claude|plugin|update|legion@ps-legion-marketplace') 'Default update unsets environment override rather than passing empty string'
        Assert-Equal 'selected-account' $env:CLAUDE_CONFIG_DIR 'Default update restores inherited override'
        Remove-Item Env:CLAUDE_CONFIG_DIR
        $null = Invoke-LegionUpdateSteps -Entry $entry
        Assert-True (-not (Test-Path Env:CLAUDE_CONFIG_DIR)) 'Absent caller override remains absent after update'
        function Invoke-ClosedInput { throw 'fixture process failed' }
        Assert-Throws { Invoke-LegionUpdateSteps -Entry $entry } 'Failed default listing propagates'
        Assert-True (-not (Test-Path Env:CLAUDE_CONFIG_DIR)) 'Failure restores absent caller override'
    } finally {
        if ($null -eq $saved) { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_CONFIG_DIR = $saved }
        Remove-InstallTestFolder $sandbox
    }
}

Invoke-InstallTestCase 'DryRunListings' {
    . $installerPath -NoRun
    $catalog = Get-InstallCatalog -Source $repo
    $fixtures = Join-Path $PSScriptRoot 'fixtures/install/listings'
    $sandbox = New-InstallTestFolder 'dry-listings'
    . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome $sandbox
    $fixturePlugin = New-InstallFixturePlugin -Path (Join-Path $sandbox 'installed') -Version '0.3.0'
    $calls = [Collections.Generic.List[string]]::new()
    function Ensure-InstallPowerShell { $true }
    function Test-InstallCommandAvailable { $true }
    function Get-UpdateConfigDirs { ,@('') }
    function Invoke-ClosedInput {
        param($Command, $Environment)
        if ($Command -notcontains 'list') { throw 'DryRun attempted a write or version command' }
        $calls.Add(($Command -join '|'))
        $file = if ($Command -contains 'marketplace') { "$($Command[0])-marketplaces.json" } else { 'claude-plugins.json' }
        $output = if ($Command -contains 'marketplace' -or $Command[0] -eq 'claude') { Get-Content (Join-Path $fixtures $file) }
            else { @("legion@ps-legion-marketplace installed, enabled 0.3.0 $fixturePlugin") }
        if ($Command[0] -eq 'claude' -and $Command -notcontains 'marketplace') {
            $plugins = ($output -join "`n") | ConvertFrom-Json
            foreach ($plugin in $plugins) { $plugin | Add-Member installPath $fixturePlugin -Force }
            $output = @(ConvertTo-Json -InputObject @($plugins) -Depth 10)
        }
        if ($Command[0] -eq 'codex' -and $Command -contains 'marketplace') {
            $listing = ($output -join "`n") | ConvertFrom-Json
            $listing.marketplaces[0].root = $fixtures
            $output = @($listing | ConvertTo-Json -Depth 10)
        }
        @{ExitCode=0; Output=$output; ErrorOutput=@()}
    }
    try {
        $preview = @(Invoke-LegionInstaller -Catalog $catalog -DryRun)
        Assert-Equal 7 $calls.Count 'Install DryRun reads registrations, checkout health and installed plugins'
        Assert-Equal 6 @($preview | Where-Object { $_ -match '^skip: .*already done' }).Count 'Install DryRun proves matching sources and enabled plugins'
        $calls.Clear()
        $preview = @(Invoke-LegionInstaller -Catalog $catalog -Update -DryRun)
        Assert-Equal 3 $calls.Count 'Update DryRun checks installed state for every tool'
        Assert-True ($preview -contains 'claude plugin update legion@ps-legion-marketplace') 'Update DryRun detects captured Claude user plugin'
        function Invoke-ClosedInput { @{ExitCode=0; Output=@('[]'); ErrorOutput=@()} }
        $preview = @(Invoke-LegionInstaller -Tools claude -Catalog $catalog -Update -DryRun)
        Assert-True ($preview -contains 'claude plugin marketplace add BlackGad/ps-legion-marketplace#stable') 'Update DryRun proposes registering missing marketplace'
        Assert-True ($preview -contains 'claude plugin install legion@ps-legion-marketplace') 'Update DryRun proposes installing absent plugin'
        Assert-True (-not ($preview -contains 'claude plugin update legion@ps-legion-marketplace')) 'Update DryRun never proposes updating absent plugin'
    } finally {
        Remove-InstallTestFolder $sandbox
    }
}

Invoke-InstallTestCase 'RealMarketplace' {
    . $installerPath -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $fixtures = Join-Path $PSScriptRoot 'fixtures/install/listings'
    foreach ($tool in @('claude', 'codex', 'copilot')) {
        $lines = Get-Content (Join-Path $fixtures "$tool-marketplaces.json")
        Assert-True (Test-InstallListing -Kind marketplace -Tool $tool -Lines $lines) "$tool captured JSON identifies the marketplace"
        Assert-True (-not (Test-InstallListing -Kind marketplace -Tool $tool -Lines @('[]'))) "$tool empty listing is absent"
        Assert-Throws { Test-InstallListing -Kind marketplace -Tool $tool -Lines @('broken JSON') } "$tool malformed listing is not absence"
        function Invoke-ClosedInput {
            param($Command, $Environment)
            Assert-Equal "$tool|plugin|marketplace|list|--json" ($Command -join '|') 'Marketplace detection requests JSON'
            @{ExitCode=0; Output=$lines; ErrorOutput=@('unrelated warning')}
        }
        $command = (Get-InstallCommands -Tool $tool -Source 'example/requested-source')[0]
        Assert-True (Test-InstallStepDone -Command $command -Kind marketplace) "$tool existing registration is reused regardless of source"
    }
    foreach ($invalid in @(@{'bad-name'='1'}, @{FIXTURE_FLAG=$true})) {
        $descriptor = Get-Content (Join-Path $repo 'plugins/legion/skills/legion-claude/tool.json') -Raw | ConvertFrom-Json
        $descriptor.plugin | Add-Member listingEnv $invalid -Force
        Assert-True (-not (Test-Json -Json ($descriptor | ConvertTo-Json -Depth 100) -SchemaFile (Join-Path $repo 'plugins/legion/schemas/tool.schema.json') -ErrorAction SilentlyContinue)) 'Invalid listing environment is rejected before catalog generation'
    }
}

Invoke-InstallTestCase 'CatalogSelection' {
    . $installerPath -NoRun
    $sandbox = New-InstallTestFolder 'catalog-selection'
    try {
        $catalog = Get-InstallCatalog -Source $repo
        $catalog.tools[0].hooks.hint = 'local catalog selected'
        $catalog | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $sandbox 'tools.json')
        $catalog.tools[0].hooks.hint = 'remote catalog selected'
        $catalog | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $sandbox 'remote.json')
        $overrides = @'
function Get-InstallHome { $PSScriptRoot }
function Get-InstallSourceText {
    param($Url)
    if ($Url -ne 'https://raw.githubusercontent.com/example/market/stable/plugins/legion/tools.json') { throw "Unexpected URL: $Url" }
    Get-Content (Join-Path $PSScriptRoot 'remote.json') -Raw
}
function Ensure-InstallPowerShell { $true }
function Test-InstallStepDone { $false }
'@
        $text = [IO.File]::ReadAllText($installerPath).Replace('if (-not $NoRun) {', $overrides + "`nif (-not `$NoRun) {")
        New-Item -ItemType Directory -Path (Join-Path $sandbox 'bin/lib') -Force | Out-Null
        Copy-Item (Join-Path $repo 'plugins/legion/bin/lib/paths.ps1') (Join-Path $sandbox 'bin/lib/paths.ps1')
        $installer = Join-Path $sandbox 'install.ps1'
        [IO.File]::WriteAllText($installer, $text)
        foreach ($extra in @(@(), @('-Source', 'example/market'), @('-Ref', 'main'))) {
            $result = Invoke-ClosedInput -Command (@('pwsh', '-NoProfile', '-File', $installer, '-DryRun', '-Tools', 'claude') + $extra)
            Assert-Equal 0 $result.ExitCode 'Catalog preview succeeds with fake boundaries'
            $expected = if ($extra -contains '-Source') { 'remote catalog selected' } else { 'local catalog selected' }
            Assert-True ($result.Output -contains $expected) 'RefKeepsSiblingCatalog: only Source overrides the sibling catalog'
        }
    } finally {
        Remove-InstallTestFolder $sandbox
    }
}
