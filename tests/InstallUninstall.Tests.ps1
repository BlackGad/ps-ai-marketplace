# Uninstall: plan, kept paths, cache, commands, home and repair.
. (Join-Path $PSScriptRoot 'lib/installer.ps1')

Invoke-InstallTestCase 'Uninstall' {
    . (Join-Path $PSScriptRoot 'fixtures/install/MarketplaceListing.ps1')
    & {
        . $installerPath -NoRun
        $catalog = Get-InstallCatalog -Source $repo
        $sandbox = New-InstallTestFolder 'uninstall'
        $bin = Join-Path $sandbox '.legion/bin'
        # Old-only owner settings must still select every recorded uninstall target.
        $personalisation = Join-Path $sandbox '.legion/configuration/personalisation.json'
        $account = Join-Path $sandbox '.legion/agents/codex-a'
        $secondAccount = Join-Path $sandbox '.legion/agents/codex-b'
        $calls = [Collections.Generic.List[string]]::new()
        $writes = [Collections.Generic.List[string]]::new()
        $state = @{ Missing=$false; FailList=$false; FailRemove=$false; Answer='n'; Prompts=0; OnlyMissing=$false }
        . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome ($sandbox)
        # The sandbox is not the real profile, so each tool's default folder lives in it and exists when installed.
        foreach ($tool in $catalog.tools) { New-Item -ItemType Directory -Path (Join-Path $sandbox $tool.plugin.defaultConfigDir.Substring(2)) -Force | Out-Null }
        function Ensure-InstallPowerShell { throw 'Uninstall must not install prerequisites' }
        # Retargeting dead commands through a surviving install is covered in InstallOwnerCommands; here it only must not run a real refresh.
        function Invoke-InstallRefresh { param($Entry, [string]$ConfigDir) }
        function Test-InstallCommandAvailable { param($Name) -not $state.OnlyMissing }
        function Read-Host {
            param($Prompt)
            Assert-Equal 'Uninstall legion from these targets? [y/N]' $Prompt 'Exact confirmation prompt'
            Assert-Equal 0 $writes.Count 'No CLI changes before confirmation'
            Assert-True (Test-Path (Join-Path $bin 'codex-a.cmd')) 'No files removed before confirmation'
            $state.Prompts++
            $state.Answer
        }
        function Invoke-ClosedInput {
            param([string[]]$Command, $Environment)
            $entry = $catalog.tools | Where-Object command -EQ $Command[0]
            $folder = $Environment[$entry.configEnv]
            $calls.Add("$($entry.id):$folder|$($Command -join '|')")
            $line = $Command -join '|'
            if ($line -eq "$($entry.command)|plugin|list$(if ($entry.id -eq 'claude') { '|--json' })") {
                if ($state.FailList) { return @{ExitCode=7;Output=@()} }
                # The physical default folders hold no legion here; only the named accounts do.
                $absent = $state.Missing -or $folder -match '[\\/]\.(claude|codex|copilot)$'
                $output = if ($absent) { if ($entry.id -eq 'claude') { '[]' } else { 'legion@ps-legion-marketplace not installed' } }
                    elseif ($entry.id -eq 'claude') { '[{"id":"legion@ps-legion-marketplace","enabled":false}]' }
                    else { 'legion@ps-legion-marketplace installed (disabled)' }
                return @{ExitCode=0;Output=@($output)}
            }
            if ($line -eq ((@($entry.command) + $entry.plugin.marketplaceList) -join '|')) {
                $source = if ($state.Missing) { '' } else { 'example/other-source' }
                return @{ExitCode=0;Output=@(Get-FixtureMarketplaceListing -Tool $entry.id -Source $source)}
            }
            $allowed = @('claude|plugin|uninstall|legion@ps-legion-marketplace', 'codex|plugin|remove|legion@ps-legion-marketplace',
                'copilot|plugin|uninstall|legion@ps-legion-marketplace', 'claude|plugin|marketplace|remove|ps-legion-marketplace',
                'codex|plugin|marketplace|remove|ps-legion-marketplace', 'copilot|plugin|marketplace|remove|ps-legion-marketplace|--force',
                'fourth-cli|plugin|erase|legion@ps-legion-marketplace', 'fourth-cli|plugin|marketplace|unregister|ps-legion-marketplace')
            if ($line -notin $allowed) { throw "Unexpected command: $line" }
            if ($state.FailRemove) { return @{ExitCode=8;Output=@()} }
            $writes.Add($line)
            return @{ExitCode=0;Output=@()}
        }
        $saved = @{}
        foreach ($entry in $catalog.tools) {
            $saved[$entry.configEnv] = [Environment]::GetEnvironmentVariable($entry.configEnv, 'Process')
            [Environment]::SetEnvironmentVariable($entry.configEnv, (Join-Path $sandbox 'inherited-account'), 'Process')
        }
        try {
            New-Item -ItemType Directory -Path $bin, (Split-Path $personalisation), $account, $secondAccount -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $sandbox 'inherited-account'), (Join-Path $sandbox 'custom account'), (Join-Path $sandbox 'selected') -Force | Out-Null
            $agents = @(
                @{id='codex-a';tool='codex';configDir='~/.legion/agents/codex-a'},
                @{id='codex-b';tool='codex';configDir='~/.legion/agents/codex-b'},
                @{id='external';tool='claude';configDir=(Join-Path $sandbox 'custom account')},
                @{id='codex-duplicate';tool='codex';configDir='~/.legion/agents/codex-a'}
            )
            @{agents=$agents} | ConvertTo-Json | Set-Content $personalisation
            $original = Get-Content $personalisation -Raw
            'notes' | Set-Content (Join-Path (Split-Path $personalisation) 'notes.md')
            'login' | Set-Content (Join-Path $account 'auth.json')
            'second login' | Set-Content (Join-Path $secondAccount 'auth.json')
            foreach ($name in @('codex-a','codex-a.cmd','codex-b','codex-b.cmd','external','external.cmd','unrelated','legion.cmd')) {
                'owner file' | Set-Content (Join-Path $bin $name)
            }
            foreach ($id in @('codex-a','codex-b')) {
                "#!/bin/sh`n# Generated by legion: account $id`nexit 0" | Set-Content (Join-Path $bin $id)
                "@rem Generated by legion: account $id`r`n@exit /b 0" | Set-Content (Join-Path $bin "$id.cmd")
            }
            '#!/bin/sh
exec pwsh -NoProfile -File ''/plugin/bin/legion.ps1'' "$@"' | Set-Content (Join-Path $bin 'legion')
            # Use the actual runtime publisher, with no CLI or network boundary involved.
            & {
                . (Join-Path $repo 'plugins/legion/bin/lib/accounts.ps1')
                $null = Sync-LegionFoundryRuntime -Tool codex -HomeRoot $sandbox
            }
            $runtime = Join-Path $bin '.runtime'
            $published = @(Get-ChildItem -LiteralPath $runtime -Recurse -File -Force | ForEach-Object FullName)
            'keep' | Set-Content (Join-Path $runtime 'owner.txt')
            'owner script' | Set-Content (Join-Path $runtime 'skills/legion-codex/scripts/foundry-custom.ps1')
            $preview = @(Invoke-LegionInstaller -Source $repo -Catalog $catalog -Uninstall -DryRun)
            Assert-True ($calls.Count -gt 0) 'Dry run checks installed state'
            Assert-Equal 0 $writes.Count 'Dry run never changes any CLI'
            Assert-Equal 0 $state.Prompts 'Dry run never asks'
            Assert-True (($preview -join "`n").Contains('copilot plugin marketplace remove ps-legion-marketplace --force')) 'Preview includes force from metadata'
            Assert-True (($preview -join "`n").Contains($account)) 'Preview includes recorded targets'
            Assert-True (-not (($preview -join "`n").Contains("Remove file: $(Join-Path $bin 'codex-a.cmd')"))) 'Preview excludes account launcher removals'
            Assert-True (Test-Path (Join-Path $runtime 'bin/legion-foundry.ps1')) 'Preview preserves runtime'

            $declined = @(Invoke-LegionInstaller -Source $repo -Catalog $catalog -Uninstall)
            Assert-Equal 1 $state.Prompts 'Default confirmation happens once'
            Assert-Equal 0 $writes.Count 'Declined uninstall changes no CLI'
            Assert-True (Test-Path (Join-Path $bin 'codex-a.cmd')) 'Declined uninstall preserves launchers'
            $calls.Clear()

            $null = Invoke-LegionInstaller -Source $repo -Catalog $catalog -Tools codex -ConfigDir $account -Uninstall -Yes
            Assert-Equal 2 $writes.Count 'Filters remove exactly one target'
            Assert-Equal 'codex|plugin|remove|legion@ps-legion-marketplace' $writes[0] 'Disabled plugin uninstalls before marketplace'
            Assert-True ($calls[0].StartsWith("codex:$account|")) 'Explicit config scopes listing'
            Assert-True (Test-Path (Join-Path $bin 'codex-a.cmd')) 'Selected account launchers kept'
            Assert-True (Test-Path (Join-Path $bin 'codex-b')) 'Other account launcher kept by filters'
            Assert-True (Test-Path (Join-Path $runtime 'bin/legion-foundry.ps1')) 'Shared runtime stays while another owned launcher remains'
            $writes.Clear(); $calls.Clear()

            $output = @(Invoke-LegionInstaller -Source $repo -Catalog $catalog -Uninstall -Yes)
            Assert-Equal 12 $writes.Count 'Three defaults plus three unique account targets removed'
            foreach ($entry in $catalog.tools) {
                $inherited = Join-Path $sandbox 'inherited-account'
                Assert-True ($calls -contains "$($entry.id):$inherited|$($entry.command)|plugin|list$(if ($entry.id -eq 'claude') { '|--json' })") 'Default honors inherited config override'
                Assert-Equal $inherited ([Environment]::GetEnvironmentVariable($entry.configEnv, 'Process')) 'Caller environment restored'
            }
            foreach ($name in @('codex-a','codex-a.cmd','codex-b','codex-b.cmd')) {
                Assert-True (Test-Path (Join-Path $bin $name)) 'Account launcher kept'
            }
            Assert-True (Test-Path (Join-Path $bin 'legion')) 'A headerless command without an index stays'
            Assert-True ($output -contains "Kept account launchers: $bin") 'Summary names the retained account launchers'
            foreach ($name in @('external','external.cmd','unrelated','legion.cmd','.runtime/owner.txt','.runtime/skills/legion-codex/scripts/foundry-custom.ps1')) {
                Assert-True (Test-Path (Join-Path $bin $name)) 'Unowned files preserved'
            }
            Assert-True (Test-Path (Join-Path $runtime 'bin/legion-foundry.ps1')) 'Uninstall keeps the account-owned runtime'
            foreach ($path in $published) { Assert-True (Test-Path -LiteralPath $path) 'Every runtime dependency stays until the last account is removed' }
            Assert-Equal $original (Get-Content $personalisation -Raw) 'Personalisation untouched'
            Assert-Equal 'login' (Get-Content (Join-Path $account 'auth.json')) 'Account login untouched'
            Assert-Equal 'second login' (Get-Content (Join-Path $secondAccount 'auth.json')) 'Other account login untouched'
            foreach ($kept in @((Split-Path $personalisation), $account, 'repositories', 'CLIs')) {
                Assert-True (($output -join "`n").Contains($kept)) 'Summary names retained data and location'
            }
            $writes.Clear(); $calls.Clear()
            $state.Missing=$true
            $repeat = @(Invoke-LegionInstaller -Source $repo -Catalog $catalog -Uninstall -Yes)
            Assert-Equal 0 $writes.Count 'Repeat never removes absent plugin or marketplace'
            Assert-True (($repeat -join "`n") -match 'skip: .*\(not installed\)') 'Repeat prints not installed'
            $state.Missing=$false
            foreach ($failure in @('FailList','FailRemove')) {
                $state[$failure]=$true
                Assert-Throws { Invoke-LegionInstaller -Source $repo -Catalog $catalog -Tools codex -ConfigDir (Join-Path $sandbox 'selected') -Uninstall -Yes } "$failure propagates"
                Assert-Equal (Join-Path $sandbox 'inherited-account') $env:CODEX_HOME 'Failure restores config env'
                $state[$failure]=$false
            }
            $calls.Clear()
            Assert-Throws { Invoke-LegionInstaller -Source $repo -Catalog $catalog -Update -Uninstall -Yes } 'Update and uninstall are mutually exclusive'
            Assert-Equal 0 $calls.Count 'Invalid mode executes nothing'

            $state.OnlyMissing=$true
            $calls.Clear()
            $missing = @(Invoke-LegionInstaller -Source $repo -Catalog $catalog -Tools codex -Uninstall -Yes)
            Assert-Equal 0 $calls.Count 'Unavailable CLI never invoked'
            Assert-True (($missing -join "`n").Contains('skip: codex (not installed)')) 'Missing CLI skipped'
            '{' | Set-Content -LiteralPath $personalisation
            Assert-Throws { Invoke-LegionInstaller -Source $repo -Catalog $catalog -Uninstall -Yes } 'Invalid owner records fail before removal'
            Assert-Equal 0 $calls.Count 'Malformed records never reach CLI boundary'
        } finally {
            foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key, $saved[$key], 'Process') }
            Remove-InstallTestFolder $sandbox
        }
    }

    & {
        . $installerPath -NoRun
        $catalog = Get-InstallCatalog -Source $repo
        foreach ($field in @('uninstall','marketplaceRemove')) {
            $bad = Get-Content (Join-Path $repo 'plugins/legion/skills/legion-claude/tool.json') -Raw | ConvertFrom-Json
            $bad.plugin.$field = 'invalid'
            Assert-True (-not (Test-Json -Json ($bad | ConvertTo-Json -Depth 100) -SchemaFile (Join-Path $repo 'plugins/legion/schemas/tool.schema.json') -ErrorAction SilentlyContinue)) "Invalid $field rejected before catalog generation"
        }
    }
}

Invoke-InstallTestCase 'UninstallPlan' {
    . (Join-Path $PSScriptRoot 'fixtures/install/UninstallSandbox.ps1')
    $selected = Join-Path $sandbox 'selected'
    New-Item -ItemType Directory -Path $selected -Force | Out-Null
    try {
        $state.Plugin=$false; $state.Marketplace=$false
        $output = @(Invoke-LegionInstaller -Catalog $catalog -Uninstall)
        Assert-Equal 0 $state.Prompts 'Empty uninstall never asks'
        Assert-True ($output -contains 'Nothing to uninstall.') 'Empty uninstall explains no work'
        Assert-Equal 0 @($output | Where-Object { $_ -match 'plugin (uninstall|remove|marketplace remove)' }).Count 'Empty uninstall has no command plan'
        Assert-Equal 6 @($output | Where-Object { $_ -match '^skip: .* (plugin|marketplace) in ' }).Count 'Empty uninstall reports all absent steps'

        foreach ($plugin in @($false, $true)) {
            $state.Plugin=$plugin; $state.Marketplace=-not $plugin
            $preview = @(Invoke-LegionInstaller -Catalog $catalog -Tools codex -ConfigDir $selected -Uninstall -DryRun)
            $commands = @($preview | Where-Object { $_ -match 'codex plugin (remove|marketplace remove)' })
            Assert-Equal 1 $commands.Count 'Preview only lists installed steps'
            $expected = if ($plugin) { 'codex plugin remove legion@ps-legion-marketplace' } else { 'codex plugin marketplace remove ps-legion-marketplace' }
            Assert-True ($commands[0].EndsWith($expected)) 'Preview selects the installed step'
            Assert-Equal 0 $writes.Count 'Preview only reads'
        }
        $state.Plugin=$true; $state.Marketplace=$true
        $declined = @(Invoke-LegionInstaller -Catalog $catalog -Tools codex -Uninstall)
        Assert-Equal 1 $state.Prompts 'Nonempty uninstall asks once'
        Assert-True ($calls.Count -gt 0) 'Detection happens before asking'
        Assert-Equal 0 $writes.Count 'Declining preserves installed state'

        $records = Join-Path $sandbox '.legion/configuration/personalisation.json'
        New-Item -ItemType Directory -Path (Split-Path $records) -Force | Out-Null
        @{agents=@(@{id='codex-a';tool='codex';configDir='~/.codex';command='external-command'})} | ConvertTo-Json | Set-Content -LiteralPath $records
        $preview = @(Invoke-LegionInstaller -Catalog $catalog -Tools codex -Uninstall -DryRun)
        Assert-Equal 1 @($preview | Where-Object { $_ -match '^Target:' }).Count 'Recorded default config is planned once'
        Assert-Equal 2 @($preview | Where-Object { $_ -match 'codex plugin (remove|marketplace remove)' }).Count 'Default alias does not duplicate commands'
        $null = Invoke-LegionInstaller -Catalog $catalog -Tools codex -Uninstall -Yes
        Assert-Equal 2 $writes.Count 'Default alias is uninstalled once'
    } finally { Remove-UninstallSandbox }
}

Invoke-InstallTestCase 'UninstallKept' {
    . (Join-Path $PSScriptRoot 'fixtures/install/UninstallSandbox.ps1')
    try {
        $state.Plugin=$false; $state.Marketplace=$false
        # Only paths that exist are listed, so start with no default tool folders.
        foreach ($tool in $catalog.tools) { Remove-Item -LiteralPath (Join-Path $sandbox $tool.plugin.defaultConfigDir.Substring(2)) -Recurse -Force }
        $output = @(Invoke-LegionInstaller -Catalog $catalog -ConfigDir (Join-Path $sandbox 'missing') -Uninstall -Yes)
        Assert-Equal 0 @($output | Where-Object { $_ -match '^Kept .*: ' }).Count 'No nonexistent paths in kept summary'
        $configuration = Join-Path $sandbox '.legion/configuration'
        $account = Join-Path $sandbox 'custom account'
        New-Item -ItemType Directory -Path $configuration, $account -Force | Out-Null
        $output = @(Invoke-LegionInstaller -Catalog $catalog -ConfigDir $account -Uninstall -Yes)
        Assert-True ($output -contains "Kept settings and notes: $configuration") 'Existing settings directory is listed'
        Assert-True ($output -contains "Kept config folder and login: $account") 'Existing explicit config is listed'
        Assert-Equal 2 @($output | Where-Object { $_ -match '^Kept .*: ' }).Count 'Only existing paths are listed'
    } finally { Remove-UninstallSandbox }
}

Invoke-InstallTestCase 'UninstallCache' {
    . (Join-Path $PSScriptRoot 'fixtures/install/UninstallSandbox.ps1')
    try {
        Assert-True ([bool](Get-Command Get-InstallSafePath -ErrorAction SilentlyContinue)) 'One safe-path helper serves cache cleanup and purge'
        $safeRoot = Join-Path $sandbox 'safe-paths'
        New-FixtureCache (Join-Path $safeRoot 'cache')
        $safeFile = Join-Path $safeRoot 'cache/fixture.txt'
        Assert-Equal (Join-Path $safeRoot 'cache') (Get-InstallSafePath -Root $safeRoot -Relative 'cache') 'Safe folder resolves under its root'
        Assert-Equal $safeFile (Get-InstallSafePath -Root $safeRoot -Relative 'cache/fixture.txt' -AllowFile) 'Safe file resolves when allowed'
        Assert-True (-not (Get-InstallSafePath -Root $safeRoot -Relative 'cache/fixture.txt')) 'Folder-only cleanup skips files'
        Assert-True (-not (Get-InstallSafePath -Root $safeRoot -Relative 'missing')) 'Missing safe path has nothing to remove'
        foreach ($unsafe in @('', '../outside', '..\outside', '/outside', '\outside', 'C:/outside', 'C:outside', '.', 'cache/../outside', '~/outside', 'cache/*', 'cache/?', 'cache/./child', 'cache//child', 'cache/')) {
            Assert-Throws { Get-InstallSafePath -Root $safeRoot -Relative $unsafe -AllowFile } "Safe-path helper rejects '$unsafe' before looking at the filesystem"
        }
        foreach ($tool in @('claude','codex','copilot')) {
            $relative = if ($tool -eq 'copilot') { 'installed-plugins/legion-marketplace' } else { 'plugins/cache/ps-legion-marketplace' }
            $entry = $catalog.tools | Where-Object id -CEQ $tool
            Assert-Equal $relative $entry.plugin.cacheDir 'Cache cleanup path lives in tool data'
            foreach ($custom in @($false, $true)) {
                $folder = if ($custom) { Join-Path $sandbox "$tool-account" } else { Join-Path $sandbox ".$tool" }
                $config = if ($custom) { $folder } else { '' }
                $cache = Join-Path $folder $relative
                $other = Join-Path (Split-Path $cache) 'other-marketplace'
                $unselected = Join-Path $sandbox "$tool-unselected/$relative"
                foreach ($version in @('0.1.0','0.3.0','0.3.2','0.4.0')) { New-FixtureCache (Join-Path $cache "legion/$version") }
                New-FixtureCache $other
                New-FixtureCache $unselected
                $state.Plugin=$true; $state.Marketplace=$true
                $null = Invoke-LegionInstaller -Catalog $catalog -Tools $tool -ConfigDir $config -Uninstall -DryRun
                Assert-True (Test-Path -LiteralPath $cache) 'Preview preserves cache'
                $null = Invoke-LegionInstaller -Catalog $catalog -Tools $tool -ConfigDir $config -Uninstall -Yes
                Assert-True (-not (Test-Path -LiteralPath $cache)) 'Successful uninstall removes every cached version and marketplace cache folder'
                Assert-True (Test-Path -LiteralPath $other) 'Other marketplace cache remains'
                Assert-True (Test-Path -LiteralPath $unselected) 'Other config cache remains'
                $repeat = @(Invoke-LegionInstaller -Catalog $catalog -Tools $tool -ConfigDir $config -Uninstall)
                Assert-True ($repeat -contains 'Nothing to uninstall.') 'Clean repeat has no work'
            }
        }
        $folder = Join-Path $sandbox 'safety'
        $cache = Join-Path $folder 'plugins/cache/ps-legion-marketplace'
        New-FixtureCache $cache
        foreach ($failure in @('FailRemove','KeepListed','FailVerify')) {
            $state.Plugin=$true; $state.Marketplace=$true; $state[$failure]=$true
            $writes.Clear()
            Assert-Throws { Invoke-LegionInstaller -Catalog $catalog -Tools codex -ConfigDir $folder -Uninstall -Yes } "$failure refuses cleanup"
            Assert-True (Test-Path -LiteralPath $cache) "$failure preserves cache"
            $state[$failure]=$false
        }
        $state.Plugin=$false; $state.Marketplace=$false
        $state.Answer='n'
        $preview = @(Invoke-LegionInstaller -Catalog $catalog -Tools codex -ConfigDir $folder -Uninstall)
        Assert-True (($preview -join "`n").Contains("Remove cache folder: $cache")) 'Leftover cache alone is planned'
        Assert-True (Test-Path -LiteralPath $cache) 'Declining keeps leftover cache'
        $null = Invoke-LegionInstaller -Catalog $catalog -Tools codex -ConfigDir $folder -Uninstall -Yes
        Assert-True (-not (Test-Path -LiteralPath $cache)) 'Already uninstalled plugin leftovers can be cleaned'
        New-Item -ItemType Directory -Path $cache -Force | Out-Null
        $null = Invoke-LegionInstaller -Catalog $catalog -Tools codex -ConfigDir $folder -Uninstall -Yes
        Assert-True (-not (Test-Path -LiteralPath $cache)) 'Empty cache folder is cleaned'

        $entry = $catalog.tools | Where-Object id -CEQ codex
        $original = $entry.plugin.cacheDir
        foreach ($unsafe in @('../other-marketplace', '/outside', 'C:/outside', '.', 'plugins/../other', '~/outside', 'plugins/*', 'plugins/./cache')) {
            $entry.plugin.cacheDir=$unsafe
            Assert-Throws { Get-UninstallCachePath -Entry $entry -ConfigDir $folder } 'Unsafe catalog cache path rejected at the cleanup boundary'
            $writes.Clear()
            Assert-Throws { Invoke-LegionInstaller -Catalog $catalog -Tools codex -ConfigDir $folder -Uninstall -Yes } 'Bad relative path in a catalog stops uninstall'
            Assert-Equal 0 $writes.Count 'Unsafe catalog path never reaches a CLI write or cache deletion'
            $descriptor = Get-Content (Join-Path $repo 'plugins/legion/skills/legion-codex/tool.json') -Raw | ConvertFrom-Json
            $descriptor.plugin.cacheDir=$unsafe
            Assert-True (-not (Test-Json -Json ($descriptor | ConvertTo-Json -Depth 100) -SchemaFile (Join-Path $repo 'plugins/legion/schemas/tool.schema.json') -ErrorAction SilentlyContinue)) 'Schema rejects unsafe cache path'
        }
        $entry.plugin.cacheDir=$original
        $outside = Join-Path $sandbox 'linked-owner-data'
        New-FixtureCache $outside
        $linkType = if ($env:OS -eq 'Windows_NT') { 'Junction' } else { 'SymbolicLink' }
        foreach ($nested in @($false, $true)) {
            if ($nested) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }
            $link = if ($nested) { Join-Path $cache 'linked-version' } else { $cache }
            New-Item -ItemType $linkType -Path $link -Target $outside -ErrorAction Stop | Out-Null
            $null = Invoke-LegionInstaller -Catalog $catalog -Tools codex -ConfigDir $folder -Uninstall -Yes
            Assert-True (Test-Path -LiteralPath (Join-Path $outside 'fixture.txt')) 'Linked owner data remains'
            Assert-True (Test-Path -LiteralPath $link) 'Linked cache is skipped'
            Remove-Item -LiteralPath $link -Force
        }

        $fourth = Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth/tool.json') -Raw | ConvertFrom-Json
        $fourth.plugin | Add-Member cacheDir 'private/cache/legion-store'
        $catalog.tools += [pscustomobject]@{id=$fourth.id;command=$fourth.command;configEnv=$fourth.configEnv;plugin=$fourth.plugin;hooks=$fourth.hooks;installHint='fixture'}
        $futureCache = Join-Path $folder 'private/cache/legion-store'
        New-FixtureCache $futureCache
        $state.Plugin=$true; $state.Marketplace=$true
        $null = Invoke-LegionInstaller -Catalog $catalog -Tools fourth -ConfigDir $folder -Uninstall -Yes
        Assert-True (-not (Test-Path -LiteralPath $futureCache)) 'Future tools use their exact declared cache path'
    } finally { Remove-UninstallSandbox }
}

Invoke-InstallTestCase 'UninstallCommands' {
    . (Join-Path $PSScriptRoot 'fixtures/install/UninstallSandbox.ps1')
    try {
        $bin = Join-Path $sandbox '.legion/bin'
        New-Item -ItemType Directory -Path $bin -Force | Out-Null
        foreach ($name in @('legion', 'legion.cmd', 'codex-a', 'unrelated')) {
            '# Generated by legion: unrecorded' | Set-Content (Join-Path $bin $name)
        }
        $state.Only = 'claude'
        $null = Invoke-LegionInstaller -Catalog $catalog -Tools claude -Uninstall -Yes
        foreach ($name in @('legion', 'legion.cmd', 'codex-a', 'unrelated')) {
            Assert-True (Test-Path (Join-Path $bin $name)) 'Uninstall never discovers files outside the index, even with a header'
        }
        $state.Plugin = $true; $state.Marketplace = $true
        $owner = Get-LegionTargetOwner -Tool $catalog.tools[0] -HomeRoot $sandbox
        foreach ($name in @('legion', 'legion.cmd')) { Add-LegionFootprint -HomeRoot $sandbox -Kind file -Path (Join-Path $bin $name) -Owner $owner }
        $preview = @(Invoke-LegionInstaller -Catalog $catalog -Tools claude -Uninstall -DryRun) -join "`n"
        Assert-True ($preview.Contains("Remove file: $(Join-Path $bin 'legion')")) 'Preview lists recorded files'
        $null = Invoke-LegionInstaller -Catalog $catalog -Tools claude -Uninstall -Yes
        foreach ($name in @('legion', 'legion.cmd')) { Assert-Equal $false (Test-Path (Join-Path $bin $name)) 'Recorded owner commands are removed' }
        foreach ($name in @('codex-a', 'unrelated')) { Assert-True (Test-Path (Join-Path $bin $name)) 'Launchers and unrelated files stay' }
    } finally { Remove-UninstallSandbox }
}

Invoke-InstallTestCase 'UninstallHome' {
    $profileHome = $env:HOME
    . (Join-Path $PSScriptRoot 'fixtures/install/UninstallSandbox.ps1')
    # Unix resolves UserProfile from HOME; keep the profile separate from the chosen home.
    $env:HOME = $profileHome
    try {
        # A home that is not the real profile never reaches the real default tool folders.
        Assert-True (-not (Test-InstallRealProfile)) 'The chosen home is not the process profile'
        $codexFolder = Join-Path $sandbox '.codex'
        $preview = @(Invoke-LegionInstaller -Catalog $catalog -Tools codex -Uninstall -DryRun) -join "`n"
        Assert-True ($preview -notmatch 'default config') 'A non-default home never plans the CLI default folder'
        Assert-True ($preview.Contains("Target: codex in $codexFolder")) 'The default folder is under the chosen home'

        $null = Invoke-LegionInstaller -Catalog $catalog -Tools codex -Uninstall -Yes
        Assert-True ($writes.Count -gt 0) 'The uninstall ran'
        Assert-Equal 0 @($callEnvironments | Where-Object { $_ -cne "codex=$codexFolder" }).Count 'Every codex call sets CODEX_HOME to the chosen home'

        # Install, update and refresh take their folders from the same list, so none of them gets the CLI default.
        foreach ($tool in $catalog.tools) {
            Assert-Equal (Join-Path $sandbox $tool.plugin.defaultConfigDir.Substring(2)) (@(Get-UpdateConfigDirs -Tool $tool.id)[0]) "$($tool.id) default folder is inside the chosen home"
        }

        # A tool without a folder in that home is skipped, not run against the CLI default.
        $state.Plugin = $true; $state.Marketplace = $true
        $writes.Clear(); $calls.Clear()
        Remove-Item -LiteralPath $codexFolder -Recurse -Force
        $output = @(Invoke-LegionInstaller -Catalog $catalog -Tools codex -Uninstall -Yes)
        Assert-Equal 0 $calls.Count 'A missing folder in the chosen home runs no CLI'
        Assert-True ($output -contains "skip: codex plugin in $codexFolder (not installed)") 'A missing folder is reported as not installed'
    } finally { Remove-UninstallSandbox }
}

Invoke-InstallTestCase 'UninstallRepair' {
    $cases = [ordered]@{
        RefreshFailureKeepsCommand = {
            $other = Get-LegionTargetOwner -Tool ($catalog.tools | Where-Object id -EQ codex) -HomeRoot $sandbox
            Add-LegionFootprint -HomeRoot $sandbox -Kind file -Path $commandPath -Owner $other
            function Invoke-InstallRefresh { throw 'unreadable remaining install' }
            $output = @(Invoke-LegionInstaller -Catalog $catalog -Tools claude -Uninstall -Yes) -join "`n"
            Assert-True (Test-Path $commandPath) 'A failed survivor refresh keeps the shared command'
            Assert-True ($output.Contains('run legion setup')) 'Failed refresh gives a repair instruction'
            Assert-Equal $other ((Get-LegionFootprints -HomeRoot $sandbox -Kind file).owners -join '|') 'The remaining owner stays recorded'
        }
        OwnershipReplacedAfterPreview = {
            $state.BeforeAnswer = { 'owner file' | Set-Content $commandPath }
            $null = Invoke-LegionInstaller -Catalog $catalog -Tools claude -Uninstall
            Assert-Equal 'owner file' (Get-Content $commandPath) 'A headerless replacement is never deleted'
            Assert-Equal 1 @(Get-LegionFootprints -HomeRoot $sandbox -Kind file).Count 'Rejected deletion stays recorded'
            '# Generated by legion' | Set-Content $commandPath
            $null = Invoke-LegionInstaller -Catalog $catalog -Tools claude -Uninstall -Yes
            Assert-Equal $false (Test-Path $commandPath) 'A later run retries an unowned entry after the check passes'
        }
        FileLinkedAfterPreview = {
            $protected = Join-Path $sandbox 'protected'
            'owner data' | Set-Content $protected
            $probe = Join-Path $bin 'link-probe'
            try { New-Item -ItemType SymbolicLink -Path $probe -Target $protected -ErrorAction Stop | Out-Null }
            catch { 'skip: linked file (links unavailable)'; return }
            (Get-Item $probe -Force).Delete()
            $state.BeforeAnswer = {
                Remove-Item -LiteralPath $commandPath
                New-Item -ItemType SymbolicLink -Path $commandPath -Target $protected -ErrorAction Stop | Out-Null
            }
            try {
                $null = Invoke-LegionInstaller -Catalog $catalog -Tools claude -Uninstall
                Assert-True (Test-Path $commandPath) 'A file replaced by a link after preview stays'
                Assert-Equal 'owner data' (Get-Content $protected) 'The link target stays untouched'
            } finally { if ((Get-Item $commandPath -Force).LinkType) { (Get-Item $commandPath -Force).Delete() } }
        }
        AncestorLinkedAfterPreview = {
            $relocated = Join-Path $sandbox 'relocated-bin'
            $state.BeforeAnswer = {
                Move-Item -LiteralPath $bin -Destination $relocated
                $type = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
                New-Item -ItemType $type -Path $bin -Target $relocated -ErrorAction Stop | Out-Null
            }
            try {
                $null = Invoke-LegionInstaller -Catalog $catalog -Tools claude -Uninstall
                Assert-Equal '# Generated by legion: command' (Get-Content (Join-Path $relocated 'legion')) 'An ancestor changed after preview blocks removal'
            } finally { if ((Get-Item $bin -Force).LinkType) { (Get-Item $bin -Force).Delete() } }
        }
        NoUnrelatedListings = {
            $null = Invoke-LegionInstaller -Catalog $catalog -Tools claude -Uninstall -Yes
            Assert-Equal 0 @($calls | Where-Object { $_ -match '^(codex|copilot)\|' }).Count 'Uninstall does not scan unrelated tools for survivors'
        }
    }
    foreach ($case in $cases.GetEnumerator()) {
        Invoke-InstallTestCase $case.Key {
            . (Join-Path $PSScriptRoot 'fixtures/install/UninstallSandbox.ps1')
            try {
                $state.Only = 'claude'; $state.Answer = 'y'
                $bin = Join-Path $sandbox '.legion/bin'
                $commandPath = Join-Path $bin 'legion'
                New-Item -ItemType Directory -Path $bin -Force | Out-Null
                '# Generated by legion: command' | Set-Content $commandPath
                Add-LegionFootprint -HomeRoot $sandbox -Kind file -Path $commandPath -Owner (Get-LegionTargetOwner -Tool $catalog.tools[0] -HomeRoot $sandbox)
                function Read-Host { $state.Prompts++; if ($state.BeforeAnswer) { & $state.BeforeAnswer }; $state.Answer }
                & $case.Value
            } finally { Remove-UninstallSandbox }
        }
    }
}
