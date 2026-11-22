$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
    . (Join-Path $PSScriptRoot 'fixtures/install/MarketplaceListing.ps1')
    $catalog = Get-InstallCatalog -Source $repo
    $sandbox = Join-Path $repo ('.agents/temp/install-targets-' + [guid]::NewGuid().ToString('N'))
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
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe target fixture cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
