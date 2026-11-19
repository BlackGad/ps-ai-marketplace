$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'install.ps1') -NoRun
    . (Join-Path $PSScriptRoot 'fixtures/install/MarketplaceListing.ps1')
    $catalog = Get-InstallCatalog -Source $repo
    $sandbox = Join-Path $repo ('.agents/temp/install-accounts-' + [guid]::NewGuid().ToString('N'))
    $file = Join-Path $sandbox '.agents/configuration/ps-ai-personalisation.json'
    New-Item -ItemType Directory -Path (Split-Path $file -Parent) -Force | Out-Null
    @{agents=@(
        @{tool='claude';configDir='default'},
        @{tool='claude';configDir='~/.claude-account2'},
        @{tool='claude';configDir='~/.claude-account2'},
        @{tool='codex';configDir='~/.codex-account2'}
    )} | ConvertTo-Json | Set-Content -LiteralPath $file
    function Get-InstallHome { $sandbox }
    function Get-InstallSourceText { throw 'No network in tests' }
    function Ensure-InstallPowerShell { $true }
    function Test-InstallCommandAvailable { param($Name) $Name -in @('claude', 'codex') }
    function claude { 'fixture-version' }
    function codex { 'fixture-version' }
    function Invoke-InstallRefresh { }
    $calls = [Collections.Generic.List[string]]::new()
    $installed = @{}
    $state = @{ Fail=$false }
    function Invoke-ClosedInput {
        param([string[]]$Command)
        $entry = $catalog.tools | Where-Object command -CEQ $Command[0]
        $folder = [Environment]::GetEnvironmentVariable($entry.configEnv, 'Process')
        $key = "$($entry.id):$folder"
        $calls.Add("$key|$($Command -join '|')")
        if ($state.Fail) { throw 'fixture failure' }
        if ($Command -contains 'list') {
            if ($Command -contains 'marketplace') {
                $source = if ($installed[$key]) { $repo } else { '' }
                return @{ExitCode=0;Output=@(Get-FixtureMarketplaceListing -Tool $entry.id -Source $source)}
            }
            $output = if ($installed[$key]) {
                if ($entry.id -eq 'claude') { '[{"id":"ps-ai@ps-ai-marketplace","enabled":true}]' }
                else { 'ps-ai@ps-ai-marketplace enabled' }
            } elseif ($entry.id -eq 'claude') { '[]' } else { '' }
            return @{ExitCode=0;Output=@($output)}
        }
        if ($Command -notcontains 'marketplace') { $installed[$key] = $true }
        return @{ExitCode=0;Output=@()}
    }
    $savedClaude = $env:CLAUDE_CONFIG_DIR
    $savedCodex = $env:CODEX_HOME
    try {
        $env:CLAUDE_CONFIG_DIR = 'inherited-account'
        $env:CODEX_HOME = 'inherited-account'
        $null = Invoke-PsAiInstaller -Source $repo -Catalog $catalog -Yes
        $inherited = [IO.Path]::GetFullPath('inherited-account')
        $expected = @("claude:$inherited", "claude:$(Join-Path $sandbox '.claude-account2')", "codex:$inherited", "codex:$(Join-Path $sandbox '.codex-account2')") | Sort-Object
        $targets = @($calls | ForEach-Object { ($_ -split '\|')[0] } | Sort-Object -Unique)
        Assert-Equal ($expected -join '|') ($targets -join '|') 'Install covers defaults and recorded folders once'
        Assert-Equal 4 $installed.Count 'Install installs each distinct target'
        Assert-Equal 'inherited-account' $env:CLAUDE_CONFIG_DIR 'Install restores inherited environment'
        $calls.Clear()
        $null = Invoke-PsAiInstaller -Source $repo -Catalog $catalog -Yes
        Assert-Equal 0 @($calls | Where-Object { $_ -match '\|plugin\|(install|add)\|' }).Count 'Repeat install skips installed plugins'

        $installed.Clear()
        $calls.Clear()
        $preview = @(Invoke-PsAiInstaller -Source $repo -Catalog $catalog -Update -DryRun)
        Assert-Equal 0 $installed.Count 'Update preview never mutates missing targets'
        Assert-True (($preview -join "`n") -match 'plugin marketplace add') 'Update previews marketplace install for missing plugin'
        $calls.Clear()
        $null = Invoke-PsAiInstaller -Source $repo -Catalog $catalog -Update
        $targets = @($calls | ForEach-Object { ($_ -split '\|')[0] } | Sort-Object -Unique)
        Assert-Equal ($expected -join '|') ($targets -join '|') 'Update and install use the same targets'
        Assert-Equal 4 $installed.Count 'Update installs every missing target'
        Assert-Equal 4 @($calls | Where-Object { $_ -match '\|marketplace\|add\|' }).Count 'Update registers missing marketplaces'
        Assert-Equal 'inherited-account' $env:CODEX_HOME 'Update restores inherited environment'
        foreach ($update in @($false, $true)) {
            $calls.Clear()
            $null = Invoke-PsAiInstaller -Source $repo -Catalog $catalog -Tools claude -ConfigDir selected -Update:$update -DryRun
            Assert-Equal 'claude:selected' (($calls | ForEach-Object { ($_ -split '\|')[0] } | Sort-Object -Unique) -join '|') 'Both modes honor tool and folder narrowing'
        }
        $state.Fail = $true
        Assert-Throws { Invoke-PsAiInstaller -Source $repo -Catalog $catalog -Tools claude -Yes } 'Install listing failure propagates'
        Assert-Equal 'inherited-account' $env:CLAUDE_CONFIG_DIR 'Failed default install restores inherited environment'
    } finally {
        Set-InstallConfigEnvironment -Name CLAUDE_CONFIG_DIR -Value $savedClaude
        Set-InstallConfigEnvironment -Name CODEX_HOME -Value $savedCodex
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
