$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'fixtures/install/MarketplaceListing.ps1')
& {
    . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
    $catalog = Get-InstallCatalog -Source $repo
    $sandbox = Join-Path $repo ('.agents/temp/uninstall-' + [guid]::NewGuid().ToString('N'))
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
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe uninstall fixture cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}

& {
    . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
    $catalog = Get-InstallCatalog -Source $repo
    foreach ($field in @('uninstall','marketplaceRemove')) {
        $bad = Get-Content (Join-Path $repo 'plugins/legion/skills/legion-claude/tool.json') -Raw | ConvertFrom-Json
        $bad.plugin.$field = 'invalid'
        Assert-True (-not (Test-Json -Json ($bad | ConvertTo-Json -Depth 100) -SchemaFile (Join-Path $repo 'plugins/legion/schemas/tool.schema.json') -ErrorAction SilentlyContinue)) "Invalid $field rejected before catalog generation"
    }
}
