$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
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
    . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
    $catalog = Get-InstallCatalog -Source $repo
    $sandbox = Join-Path $repo ('.agents/temp/restructure/update-' + [guid]::NewGuid().ToString('N'))
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
        $safeRoot = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp/restructure'))
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($safeRoot + [IO.Path]::DirectorySeparatorChar)) { throw 'Unsafe cleanup path' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
