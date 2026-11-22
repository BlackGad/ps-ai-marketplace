$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
    . (Join-Path $PSScriptRoot 'fixtures/install/MarketplaceListing.ps1')
    $catalog = Get-InstallCatalog -Source $repo
    $sandbox = Join-Path $repo ('.agents/temp/install-accounts-' + [guid]::NewGuid().ToString('N'))
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
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
