$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'install.ps1') -NoRun
    $catalog = Get-InstallCatalog -Source $repo
    $expected = @{
        claude = @('plugin|marketplace|update|ps-ai-marketplace', 'plugin|update|ps-ai@ps-ai-marketplace')
        copilot = @('plugin|marketplace|update|ps-ai-marketplace', 'plugin|update|ps-ai@ps-ai-marketplace')
        codex = @('plugin|marketplace|upgrade', 'plugin|add|ps-ai@ps-ai-marketplace')
    }
    foreach ($tool in $catalog.tools) {
        Assert-Equal $expected[$tool.id][0] ($tool.plugin.marketplaceUpdate -join '|') "$($tool.id) marketplace refresh metadata"
        Assert-Equal $expected[$tool.id][1] ($tool.plugin.update -join '|') "$($tool.id) plugin refresh metadata"
    }
    foreach ($field in @('marketplaceUpdate', 'update')) {
        $bad = $catalog | ConvertTo-Json -Depth 100 | ConvertFrom-Json
        $bad.tools[0].plugin.$field = 'invalid'
        Assert-Throws { Get-InstallCatalog -Catalog $bad } "Invalid $field rejected before action"
    }
}

& {
    . (Join-Path $repo 'install.ps1') -NoRun
    $catalog = Get-InstallCatalog -Source $repo
    $sandbox = Join-Path $repo ('.agents/temp/restructure/update-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $sandbox '.legion/configuration') -Force | Out-Null
    $personalisation = Join-Path $sandbox '.legion/configuration/ps-ai-personalisation.json'
    $agents = @(
        @{tool='claude';configDir='~/.legion/agents/claude-a'},
        @{tool='claude';configDir='~/.legion/agents/claude-a'},
        @{tool='claude';configDir=(Join-Path $sandbox 'custom account')},
        @{tool='codex';configDir='~/.legion/agents/codex-a'},
        @{tool='copilot';configDir='~/.legion/agents/copilot-a'}
    )
    @{agents=$agents} | ConvertTo-Json | Set-Content -LiteralPath $personalisation
    . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome ($sandbox)
    function Invoke-InstallRefresh { } # The installed-script boundary has dedicated coverage.
    function Ensure-InstallPowerShell { throw 'Update must not install prerequisites' }
    function Get-InstallSourceText { throw 'Tests must not use network' }
    $calls = [Collections.Generic.List[string]]::new()
    $state = @{ Missing=$false; FailList=$false; FailUpdate=$false }
    function Test-InstallCommandAvailable { param($Name) $Name -in @('claude','codex','copilot') }
    function Invoke-ClosedInput {
        param([string[]]$Command)
        $entry = $catalog.tools | Where-Object command -EQ $Command[0]
        $folder = [Environment]::GetEnvironmentVariable($entry.configEnv, 'Process')
        $calls.Add("$($entry.id):$folder|$($Command -join '|')")
        if ($Command -contains 'marketplace' -and $Command -contains 'list') {
            return @{ExitCode=0; Output=@('[]')}
        }
        if ($Command[2] -eq 'list') {
            if ($state.FailList) { return @{ExitCode=7; Output=@('list failed')} }
            if ($state.Missing) { return @{ExitCode=0; Output=@($(if ($entry.id -eq 'claude') { '[]' }))} }
            # Disabled plugins still have an installed copy that needs refreshing.
            $output = if ($entry.id -eq 'claude') { '[{"id":"ps-ai@ps-ai-marketplace","enabled":false}]' }
                else { 'ps-ai@ps-ai-marketplace installed (disabled)' }
            return @{ExitCode=0; Output=@($output)}
        }
        if ($state.FailUpdate) { return @{ExitCode=8; Output=@('update failed')} }
        return @{ExitCode=0; Output=@('refreshed')}
    }
    $saved = @{}
    $saved.FOURTH_HOME = [Environment]::GetEnvironmentVariable('FOURTH_HOME', 'Process')
    foreach ($entry in $catalog.tools) {
        $saved[$entry.configEnv] = [Environment]::GetEnvironmentVariable($entry.configEnv, 'Process')
        [Environment]::SetEnvironmentVariable($entry.configEnv, 'inherited-account', 'Process')
    }
    try {
        $output = @(Invoke-PsAiInstaller -Source $repo -Catalog $catalog -Update)
        Assert-Equal 21 $calls.Count 'Seven distinct targets each list and run two refresh steps'
        foreach ($entry in $catalog.tools) {
            $inherited = [IO.Path]::GetFullPath('inherited-account')
            Assert-True ($calls -contains "$($entry.id):$inherited|$($entry.command)|plugin|list$(if ($entry.id -eq 'claude') { '|--json' })") 'Default config honors inherited account override'
            Assert-Equal 'inherited-account' ([Environment]::GetEnvironmentVariable($entry.configEnv, 'Process')) 'Update restores caller config env'
        }
        $custom = Join-Path $sandbox 'custom account'
        Assert-True ($calls -contains "claude:$custom|claude|plugin|update|ps-ai@ps-ai-marketplace") 'Registered custom folder refreshes'
        Assert-True ($calls -contains "codex:$(Join-Path $sandbox '.legion/agents/codex-a')|codex|plugin|add|ps-ai@ps-ai-marketplace") 'Codex refresh repeats add without remove'
        Assert-Equal 0 @($calls | Where-Object { $_ -match '\|remove\||\|install\|' }).Count 'Installed plugin updates do not remove or reinstall'
        Assert-True (($output -join "`n").Contains('claude plugin update ps-ai@ps-ai-marketplace')) 'Each mutation prints its command'

        $calls.Clear()
        $preview = @(Invoke-PsAiInstaller -Source $repo -Catalog $catalog -Update -DryRun)
        Assert-Equal 7 $calls.Count 'Dry run reads installed state for seven targets'
        Assert-Equal 0 @($calls | Where-Object { $_ -notmatch '\|list(?:\|--json)?$' }).Count 'Dry run only invokes read-only listings'
        Assert-True (($preview -join "`n").Contains('codex plugin add ps-ai@ps-ai-marketplace')) 'Dry run prints refresh commands'
        Assert-True (($preview -join "`n").Contains('custom account')) 'Dry run includes recorded accounts'

        $calls.Clear()
        $null = Invoke-PsAiInstaller -Tools copilot -ConfigDir 'selected account' -Source $repo -Catalog $catalog -Update
        Assert-Equal 3 $calls.Count 'Tools and ConfigDir narrow to exactly one target'
        Assert-True ($calls[2].StartsWith('copilot:selected account|')) 'Selected folder scopes mutation'

        $calls.Clear()
        $state.Missing = $true
        $output = @(Invoke-PsAiInstaller -Tools claude -ConfigDir absent -Source $repo -Catalog $catalog -Update)
        Assert-True ($calls -contains "claude:absent|claude|plugin|marketplace|add|$(Resolve-InstallSource $repo)") 'Update registers marketplace for missing plugin'
        Assert-True ($calls -contains 'claude:absent|claude|plugin|install|ps-ai@ps-ai-marketplace') 'Update installs missing plugin'
        Assert-True (($output -join "`n") -notmatch 'skip: .*\(not installed\)') 'Missing plugin is no longer skipped'
        $state.Missing = $false

        foreach ($failure in @('FailList','FailUpdate')) {
            $state[$failure] = $true
            Assert-Throws { $null = Invoke-PsAiInstaller -Tools claude -ConfigDir selected -Source $repo -Catalog $catalog -Update } "$failure propagates"
            Assert-Equal 'inherited-account' $env:CLAUDE_CONFIG_DIR 'Failure restores config env'
            $state[$failure] = $false
        }

        $caseAgents = @(@{tool='claude';configDir=(Join-Path $sandbox 'account-a')}, @{tool='claude';configDir=(Join-Path $sandbox 'Account-a')})
        @{agents=$caseAgents} | ConvertTo-Json | Set-Content -LiteralPath $personalisation
        $savedOS = $env:OS
        try {
            $env:OS = 'fixture-unix'
            Assert-Equal 3 (Get-UpdateConfigDirs -Tool claude).Count 'Case-distinct Unix folders both update'
            $env:OS = 'Windows_NT'
            Assert-Equal 2 (Get-UpdateConfigDirs -Tool claude).Count 'Windows folders deduplicate without case sensitivity'
        } finally { $env:OS = $savedOS }
        Remove-Item -LiteralPath $personalisation
        $calls.Clear()
        $null = Invoke-PsAiInstaller -Tools claude -Source $repo -Catalog $catalog -Update
        Assert-Equal 3 $calls.Count 'Missing account records still refresh default'

        $calls.Clear()
        '{' | Set-Content -LiteralPath $personalisation
        Assert-Throws { $null = Invoke-PsAiInstaller -Tools claude -Source $repo -Catalog $catalog -Update } 'Unreadable records fail clearly'
        Assert-Equal 0 $calls.Count 'Invalid records never run CLI commands'
        Remove-Item -LiteralPath $personalisation

        function Test-InstallCommandAvailable { $false }
        $calls.Clear()
        $skip = @(Invoke-PsAiInstaller -Tools claude -Source $repo -Catalog $catalog -Update)
        Assert-True ($skip -contains 'skip: claude (not installed)') 'Explicit missing CLI is skipped'
        Assert-Equal 0 $calls.Count 'Unavailable CLI is never launched'
    } finally {
        foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key, $saved[$key], 'Process') }
        $safeRoot = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp/restructure'))
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($safeRoot + [IO.Path]::DirectorySeparatorChar)) { throw 'Unsafe cleanup path' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
