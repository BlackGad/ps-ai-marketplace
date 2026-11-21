$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent

# Every scenario has its own home, all three config overrides, and an outside-home
# sentinel. No test boundary can invoke a real CLI, registry writer or downloader.
function Test-PurgeScenario {
    param([scriptblock]$Body)
    & {
        . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
        $catalog = Get-InstallCatalog -Source $repo
        $scratch = Join-Path $repo ('.agents/temp/purge-' + [guid]::NewGuid().ToString('N'))
        $fixtureHome = Join-Path $scratch 'home'
        $outside = Join-Path $scratch 'fake-real'
        $saved = @{}
        foreach ($name in @('HOME', 'USERPROFILE', 'CLAUDE_CONFIG_DIR', 'CODEX_HOME', 'COPILOT_HOME', 'PATH', 'OS')) {
            $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        }
        New-Item -ItemType Directory -Path $fixtureHome, $outside -Force | Out-Null
        'outside data' | Set-Content (Join-Path $outside 'keep.txt')
        $outsideHash = (Get-FileHash (Join-Path $outside 'keep.txt')).Hash
        $env:HOME = $fixtureHome
        $env:USERPROFILE = $fixtureHome
        foreach ($entry in $catalog.tools) {
            [Environment]::SetEnvironmentVariable($entry.configEnv, (Join-Path $fixtureHome "override-$($entry.id)"), 'Process')
        }
        $state = @{ Installed=$false; Missing=$false; Answers=@(); Prompts=@(); Writes=@(); UserPath=''; PathWrites=0 }
        function Get-InstallHome { $fixtureHome }
        function Get-InstallSourceText { throw 'Network forbidden' }
        function Ensure-InstallPowerShell { throw 'Tool installation forbidden' }
        function Test-InstallCommandAvailable { -not $state.Missing }
        function Get-InstallUserPath { $state.UserPath }
        function Set-InstallUserPath { param($Path) $state.UserPath=$Path; $state.PathWrites++ }
        function Read-Host {
            param($Prompt)
            $state.Prompts += $Prompt
            if (-not $state.Answers.Count) { throw "Unexpected prompt: $Prompt" }
            $answer = $state.Answers[0]
            $state.Answers = @($state.Answers | Select-Object -Skip 1)
            return $answer
        }
        function Invoke-ClosedInput {
            param($Command)
            $entry = $catalog.tools | Where-Object command -CEQ $Command[0]
            $folder = [Environment]::GetEnvironmentVariable($entry.configEnv, 'Process')
            Assert-True ($folder.StartsWith($fixtureHome + [IO.Path]::DirectorySeparatorChar)) 'Every CLI gets a temporary config folder'
            if ($Command[2] -eq 'list') {
                $line = if ($entry.id -eq 'claude') { if ($state.Installed) { '[{"id":"ps-ai@ps-ai-marketplace","enabled":true}]' } else { '[]' } }
                    elseif ($state.Installed) { 'ps-ai@ps-ai-marketplace installed' } else { '' }
                return @{ ExitCode=0; Output=@($line) }
            }
            if ($Command[3] -eq 'list') {
                return @{ ExitCode=0; Output=@($(if ($entry.id -eq 'codex') { '{"marketplaces":[]}' } else { '[]' })) }
            }
            $state.Writes += $Command -join '|'
            $state.Installed=$false
            return @{ ExitCode=0; Output=@() }
        }
        function New-PurgeFile {
            param([string]$Relative, [string]$Text='ps-ai data')
            $path = Join-Path $fixtureHome $Relative
            New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
            [IO.File]::WriteAllText($path, $Text)
            return $path
        }
        try { & $Body }
        finally {
            Assert-Equal $outsideHash (Get-FileHash (Join-Path $outside 'keep.txt')).Hash 'Fake real folder bytes unchanged'
            Assert-Equal 1 @(Get-ChildItem $outside -Recurse -Force).Count 'Fake real folder inventory unchanged'
            foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
            $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
            if (-not [IO.Path]::GetFullPath($scratch).StartsWith($allowed)) { throw 'Unsafe purge fixture cleanup' }
            Remove-Item -LiteralPath $scratch -Recurse -Force
        }
    }
}

Test-PurgeScenario {
    $login = New-PurgeFile '.legion/agents/codex-a/auth.json' 'fake login'
    $notes = New-PurgeFile '.legion/configuration/ps-ai-notes.md' 'notes'
    $repoFile = New-PurgeFile 'repositories/my-project/.legion/configuration/project.json' 'repository data'
    $settings = New-PurgeFile 'override-copilot/settings.json' '{"enabledPlugins":{"other@else":true,"ps-ai@ps-ai-marketplace":false},"theme":"dark"}'
    $cache = New-PurgeFile '.claude/plugins/cache/ps-ai-marketplace/ps-ai/1.0/plugin.json'
    $data = New-PurgeFile 'override-copilot/plugin-data/ps-ai-marketplace/ps-ai/keep-until-purge'
    $state.Installed=$true
    $preview = @(Invoke-PsAiInstaller -Catalog $catalog -Uninstall -Purge -DryRun) -join "`n"
    $legionFolder = Join-Path $fixtureHome '.legion'
    Assert-True ($preview.Contains("Remove folder: $legionFolder (2 files)")) 'Preview summarizes the legion folder with its file count'
    Assert-True ($preview.Contains("Remove entry: $settings")) 'Preview lists settings entries'
    foreach ($path in @($login, $notes, $cache, $data)) { Assert-True (-not $preview.Contains($path)) 'Preview does not list files inside removed folders' }
    Assert-Equal 0 $state.Prompts.Count 'Dry run never prompts'
    Assert-Equal 0 $state.Writes.Count 'Dry run never calls CLI mutations'
    Assert-True (Test-Path $login) 'Dry run keeps login'
    $state.Answers=@('y','n')
    $null = Invoke-PsAiInstaller -Catalog $catalog -Uninstall -Purge
    Assert-Equal 2 $state.Prompts.Count 'Purge has a separate confirmation after uninstall'
    Assert-True ($state.Prompts[1] -match 'Purge.*settings.*logins') 'Purge question names deleted settings and logins'
    Assert-True ($state.Writes.Count -gt 0) 'Normal uninstall runs first'
    Assert-True (Test-Path $login) 'Declined purge keeps legion'
    $state.Missing=$true
    $output = @(Invoke-PsAiInstaller -Catalog $catalog -Uninstall -Purge -Yes 6>&1) -join "`n"
    Assert-True (-not (Test-Path (Join-Path $fixtureHome '.legion'))) 'Purge removes entire legion home'
    Assert-True (-not (Test-Path $cache)) 'Physical default cache removed despite override and absent CLI'
    Assert-True (-not (Test-Path (Join-Path $fixtureHome 'override-copilot/plugin-data/ps-ai-marketplace'))) 'Purge removes Copilot data and empty marketplace parent'
    Assert-Equal '{"enabledPlugins":{"other@else":true},"theme":"dark"}' ([IO.File]::ReadAllText($settings)) 'Only ps-ai member and its comma removed'
    Assert-Equal 'repository data' ([IO.File]::ReadAllText($repoFile)) 'Repository legion folder preserved'
    Assert-True ($output.Contains('folders ps-ai no longer knows')) 'Prints hook baseline limitation'
    $repeat = @(Invoke-PsAiInstaller -Catalog $catalog -Uninstall -Purge -Yes)
    Assert-True ($repeat -contains 'skip: purge (already done)') 'Repeated purge skips without writes'
}

Test-PurgeScenario {
    $state.Missing=$true
    $null = New-PurgeFile '.legion/configuration/ps-ai-personalisation.json' '{"agents":[{"tool":"claude","configDir":"~/custom-claude"},{"tool":"codex","configDir":"~/custom-codex"}]}'
    $claude = New-PurgeFile 'custom-claude/plugins/installed_plugins.json' '{"version":2,"plugins":{"ps-ai@ps-ai-marketplace":[{"scope":"user"}],"other@else":[{"scope":"user"}]}}'
    $market = New-PurgeFile '.claude/plugins/known_marketplaces.json' '{"ps-ai-marketplace":{"source":{"source":"github"}},"other":{"keep":1}}'
    $copilot = New-PurgeFile 'override-copilot/config.json' '{"installedPlugins":[{"name":"ps-ai","marketplace":"ps-ai-marketplace","cache_path":"unused"},{"name":"other","marketplace":"else"}],"other":123}'
    $tomlText = "# keep`r`nmodel = 'keep'`r`n[plugins.`"ps-ai@ps-ai-marketplace`"]`r`nenabled = false`r`n[plugins.`"other@else`"]`r`nenabled = true`r`n[marketplaces.ps-ai-marketplace]`r`nsource_type = 'git'`r`nsource = 'example/repo'`r`n[hooks.state.'ps-ai@ps-ai-marketplace:hooks/hooks.json:session_start:0:0']`r`ntrusted_hash = 'fake'`r`n[hooks.state.'other@else:hooks/hooks.json:session_start:0:0']`r`ntrusted_hash = 'keep'`r`n"
    $toml = New-PurgeFile 'custom-codex/config.toml' $tomlText
    $null = Invoke-PsAiInstaller -Catalog $catalog -Uninstall -Purge -Yes
    Assert-Equal '{"version":2,"plugins":{"other@else":[{"scope":"user"}]}}' ([IO.File]::ReadAllText($claude)) 'Recorded config plugin inventory cleaned'
    Assert-Equal '{"other":{"keep":1}}' ([IO.File]::ReadAllText($market)) 'Physical default marketplace registry cleaned'
    Assert-Equal '{"installedPlugins":[{"name":"other","marketplace":"else"}],"other":123}' ([IO.File]::ReadAllText($copilot)) 'Copilot internal plugin record removed without rewriting unrelated state'
    $expected = "# keep`r`nmodel = 'keep'`r`n[plugins.`"other@else`"]`r`nenabled = true`r`n[hooks.state.'other@else:hooks/hooks.json:session_start:0:0']`r`ntrusted_hash = 'keep'`r`n"
    Assert-Equal $expected ([IO.File]::ReadAllText($toml)) 'Only ps-ai TOML tables removed, keeping CRLF'
}

Test-PurgeScenario {
    $state.Missing=$true
    $cases = @(
        @{ Text='"ps-ai@ps-ai-marketplace":false,"a":true'; Expected='"a":true' },
        @{ Text='"a":true,"ps-ai@ps-ai-marketplace":false,"b":false'; Expected='"a":true,"b":false' },
        @{ Text='"ps-ai@ps-ai-marketplace":true'; Expected='' },
        @{ Text='"a":true, /* keep */ "ps-ai@ps-ai-marketplace":false,'; Expected='"a":true, /* keep */ '; Comment=$true }
    )
    foreach ($ending in @("`n", "`r`n")) {
        foreach ($case in $cases) {
            # Build input and expected output from explicit line endings, independent of checkout.
            $textLines = @('{', ('"enabledPlugins": {' + $case.Text + '},'), '"note":"ps-ai@ps-ai-marketplace"', '}')
            $expectedLines = @('{', ('"enabledPlugins": {' + $case.Expected + '},'), '"note":"ps-ai@ps-ai-marketplace"', '}')
            if ($case.Comment) { $textLines = @('// keep comment') + $textLines; $expectedLines = @('// keep comment') + $expectedLines }
            $text = $textLines -join $ending
            $expected = $expectedLines -join $ending
            $file = New-PurgeFile 'override-copilot/settings.json' $text
            $null = Invoke-PsAiInstaller -Catalog $catalog -Uninstall -Purge -Yes
            Assert-Equal $expected ([IO.File]::ReadAllText($file)) 'JSON/JSONC removes only the ps-ai member and preserves LF or CRLF bytes'
        }
        $file = New-PurgeFile 'override-copilot/settings.json' (@('{', '"enabledPlugins":{"ps-ai@ps-ai-marketplace":false,broken}', '}') -join $ending)
        $before = (Get-FileHash $file).Hash
        $output = @(Invoke-PsAiInstaller -Catalog $catalog -Uninstall -Purge -Yes 6>&1) -join "`n"
        Assert-Equal $before (Get-FileHash $file).Hash 'Unsafe JSONC left unchanged for either line ending'
        Assert-True ($output.Contains("Manual step: $file")) 'Unsafe JSONC reported for manual cleanup'
    }
}

Test-PurgeScenario {
    $state.Missing=$true
    $env:OS='Windows_NT'
    $bin = Join-Path $fixtureHome '.legion/bin'
    $portable = Join-Path $fixtureHome '.legion/tools/pwsh'
    $state.UserPath="keep-first;$bin;keep-middle;$portable;keep-last;"
    $separator = [string][IO.Path]::PathSeparator
    $env:PATH = @('keep-first', $bin, 'keep-middle', $portable, 'keep-last') -join $separator
    $null = New-PurgeFile '.legion/configuration/ps-ai-notes.md' 'notes'
    $preview = @(Invoke-PsAiInstaller -Catalog $catalog -Uninstall -Purge -DryRun) -join "`n"
    Assert-True ($preview.IndexOf("Remove user PATH entry: $bin") -lt $preview.IndexOf('Remove folder:')) 'PATH entries listed before folder removal'
    Assert-True ($preview.Contains("Remove process PATH entry: $bin")) 'Process PATH changes listed'
    Assert-Equal 0 $state.PathWrites 'Preview keeps user PATH'
    $null = Invoke-PsAiInstaller -Catalog $catalog -Uninstall -Purge -Yes
    Assert-Equal 'keep-first;keep-middle;keep-last;' $state.UserPath 'Only exact ps-ai user PATH entries removed'
    Assert-Equal (@('keep-first','keep-middle','keep-last') -join $separator) $env:PATH 'Only exact ps-ai process PATH entries removed'
    Assert-Equal 1 $state.PathWrites 'User PATH updated once'
    $null = Invoke-PsAiInstaller -Catalog $catalog -Uninstall -Purge -Yes
    Assert-Equal 1 $state.PathWrites 'Repeat keeps PATH unchanged'
}

Test-PurgeScenario {
    . (Join-Path $repo 'plugins/ps-ai/bin/legion.ps1') -HomeRoot $fixtureHome
    $call = Get-LegionCall -Words @('uninstall','--purge','--yes')
    Assert-True ($call.Splat.Uninstall -and $call.Splat.Purge -and $call.Splat.Yes) 'Legion forwards purge with uninstall'
    Assert-Throws { Get-LegionCall -Words @('update','--purge') } 'Update rejects purge'
    Assert-True (((Get-LegionHelp) -join "`n").Contains('uninstall [--purge]')) 'Help includes purge'
    # Exercise the local root entry point without invoking any CLI or registry API.
    $entry = Get-Content (Join-Path $repo 'install.ps1') -Raw
    $record = @{}
    function Get-InstallSourceText { "param([switch]`$Uninstall,[switch]`$Purge,[switch]`$Yes,[string]`$HomeRoot) `$record.Purge = [bool]`$Purge" }
    $null = & ([scriptblock]::Create($entry)) -Uninstall -Purge -Yes -HomeRoot $fixtureHome
    Assert-True $record.Purge 'Downloaded root one-liner forwards purge'
}

Test-PurgeScenario {
    $state.Missing=$true
    $config = Join-Path $fixtureHome '.codex'
    $baseline = New-PurgeFile ('.codex/' + (Get-InstallPurgeTrustPath -ConfigDir $config)) 'ps-ai bundle hash'
    $unknown = New-PurgeFile '.codex/.hook-trust/unknown-baseline' 'unattributable hash'
    $otherData = New-PurgeFile 'override-copilot/plugin-data/ps-ai-marketplace/other/keep.txt' 'other plugin'
    $otherCache = New-PurgeFile '.codex/plugins/cache/other-marketplace/other/1.0/plugin.json' 'other cache'
    $data = New-PurgeFile '.codex/plugins/data/ps-ai-ps-ai-marketplace/state.json'
    $checkout = New-PurgeFile '.codex/.tmp/marketplaces/ps-ai-marketplace/.git/config'
    $null = Invoke-PsAiInstaller -Catalog $catalog -Uninstall -Purge -Yes
    Assert-True (-not (Test-Path $baseline)) 'Known Codex baseline removed'
    Assert-Equal 'unattributable hash' ([IO.File]::ReadAllText($unknown)) 'Unknown baseline preserved'
    Assert-True (-not (Test-Path $data)) 'Codex plugin data removed'
    Assert-True (-not (Test-Path $checkout)) 'Managed marketplace checkout removed'
    Assert-Equal 'other plugin' ([IO.File]::ReadAllText($otherData)) 'Other plugin data in same marketplace preserved'
    Assert-Equal 'other cache' ([IO.File]::ReadAllText($otherCache)) 'Other marketplace cache preserved'
    $repeat = @(Invoke-PsAiInstaller -Catalog $catalog -Uninstall -Purge -Yes)
    Assert-True ($repeat -contains 'skip: purge (already done)') 'Unrelated marketplace data does not prevent repeat skip'
}

Test-PurgeScenario {
    $state.Missing=$true
    foreach ($encoding in @([Text.UTF8Encoding]::new($true), [Text.UnicodeEncoding]::new($false,$true), [Text.UnicodeEncoding]::new($true,$true))) {
        foreach ($ending in @("`n", "`r`n")) {
            $file = New-PurgeFile 'override-copilot/settings.json'
            $text = @('// preserve BOM, Unicode and line endings', "{`"enabledPlugins`":{`"ps-ai@ps-ai-marketplace`":false},`"name`":`"caf$([char]0xe9)`"}", '') -join $ending
            [IO.File]::WriteAllText($file, $text, $encoding)
            $null = Invoke-PsAiInstaller -Catalog $catalog -Uninstall -Purge -Yes
            $expected = [byte[]]($encoding.GetPreamble() + $encoding.GetBytes($text.Replace('"ps-ai@ps-ai-marketplace":false','')))
            Assert-Equal ([Convert]::ToBase64String($expected)) ([Convert]::ToBase64String([IO.File]::ReadAllBytes($file))) 'Settings edit keeps encoding, BOM, Unicode and LF or CRLF bytes'
        }
    }
    foreach ($ending in @("`n", "`r`n")) {
        $prompt = @("developer_instructions = '''", '[plugins."ps-ai@ps-ai-marketplace"]', 'This is prompt text, not a plugin table.', "'''")
        $otherTable = @('[plugins."other@else"]', 'enabled = true')
        $tomlText = ($prompt + @('[plugins."ps-ai@ps-ai-marketplace"]', 'enabled = false') + $otherTable) -join $ending
        $expected = ($prompt + $otherTable) -join $ending
        $file = New-PurgeFile 'override-codex/config.toml' $tomlText
        $output = @(Invoke-PsAiInstaller -Catalog $catalog -Uninstall -Purge -Yes) -join "`n"
        Assert-Equal $expected ([IO.File]::ReadAllText($file)) 'TOML removes the real ps-ai table and preserves table-like prompt text with LF or CRLF'
        Assert-True (-not $output.Contains('Manual step:')) 'Valid TOML table removal needs no manual step for either line ending'
        $inlineCases = @(
            @('plugins = { "ps-ai@ps-ai-marketplace" = { enabled = false }, other = { enabled = true } }', ''),
            @('[plugins]', '"ps-ai@ps-ai-marketplace" = { enabled = false }', '"other@else" = { enabled = true }', '')
        )
        foreach ($lines in $inlineCases) {
            $file = New-PurgeFile 'override-codex/config.toml' ($lines -join $ending)
            $before = (Get-FileHash $file).Hash
            $output = @(Invoke-PsAiInstaller -Catalog $catalog -Uninstall -Purge -Yes) -join "`n"
            Assert-Equal $before (Get-FileHash $file).Hash 'Unsupported inline TOML stays byte-for-byte unchanged with LF or CRLF'
            Assert-True ($output.Contains("Manual step: $file")) 'Unsupported inline TOML requires a manual step for either line ending'
            Assert-True (-not $output.Contains('skip: purge (already done)')) 'Manual steps never claim purge already complete'
        }
    }
}

Test-PurgeScenario {
    $state.Missing=$true
    $cache = Join-Path $fixtureHome '.claude/plugins/cache/ps-ai-marketplace'
    New-Item -ItemType Directory -Path (Split-Path $cache) -Force | Out-Null
    $linkType = if ($env:OS -eq 'Windows_NT') { 'Junction' } else { 'SymbolicLink' }
    $null = New-Item -ItemType $linkType -Path $cache -Target $outside
    $output = @(Invoke-PsAiInstaller -Catalog $catalog -Uninstall -Purge -Yes 6>&1) -join "`n"
    Assert-True ($output.Contains('linked path; left in place')) 'Linked cache reported as manual cleanup'
    Assert-True (Test-Path $cache) 'Purge never traverses linked cache'
    # Remove the link itself before recursive fixture cleanup, without following it.
    [IO.Directory]::Delete($cache)
}

Test-PurgeScenario {
    . (Join-Path $repo 'plugins/ps-ai/bin/legion.ps1') -HomeRoot $fixtureHome
    $copy = Copy-LegionInstaller
    $installer = Join-Path $copy 'install.ps1'
    # The copied installer is real; only its external boundaries are replaced.
    $fakes = @'
function Test-InstallCommandAvailable { $false }
function Get-InstallSourceText { throw 'Network forbidden' }
function Get-InstallUserPath { '' }
function Set-InstallUserPath { throw 'Registry writes forbidden' }
function Read-Host { throw 'Yes must not prompt' }
function Invoke-ClosedInput { throw 'Real CLI calls forbidden' }
'@
    $text = [IO.File]::ReadAllText($installer).Replace('if (-not $NoRun) {', $fakes + "`nif (-not `$NoRun) {")
    [IO.File]::WriteAllText($installer, $text)
    $null = New-PurgeFile '.legion/agents/codex-a/auth.json' 'fake login'
    function Copy-LegionInstaller { $copy }
    $output = @(Invoke-LegionScript -Call (Get-LegionCall -Words @('uninstall','--purge','--yes')) 6>&1) -join "`n"
    Assert-Equal 0 $script:LegionExit 'Legion tolerates its copied installer being purged'
    Assert-True (-not (Test-Path (Join-Path $fixtureHome '.legion'))) 'Running copy and legion home removed'
    Assert-True ($output.Contains('done: purge')) 'Copied installer finished purge'
}

Test-PurgeScenario {
    $state.Missing=$true
    $owned = New-PurgeFile 'override-claude/plugins/extra-owned-ps-ai/entry.txt'
    $settings = New-PurgeFile 'override-claude/extra-settings.json' '{"enabledPlugins":{"ps-ai@ps-ai-marketplace":false},"other":1}'
    $entry = $catalog.tools | Where-Object id -CEQ claude
    $entry.plugin.purge = [pscustomobject]@{
        paths=@('plugins/extra-owned-ps-ai')
        settings=@([pscustomobject]@{path='extra-settings.json';kind='settings'})
    }
    $script:installCatalog = Get-InstallCatalog -Catalog $catalog
    $before = (Get-FileHash $settings).Hash
    $plans = @(Get-InstallPurgePlan)
    Assert-Equal 1 $plans.Count 'Plan builder returns one plan without preview output'
    Assert-Equal $before (Get-FileHash $settings).Hash 'Planning leaves settings unchanged'
    Assert-True (Test-Path $owned) 'Planning leaves descriptor-owned paths unchanged'
    Assert-Equal 0 $state.Prompts.Count 'Planning does not ask to apply'
    $preview = @(Show-InstallPurgePlan -Plan $plans[0]) -join "`n"
    Assert-True ($preview.Contains("Remove folder: $(Split-Path $owned) (1 files)")) 'Descriptor-added folder appears once with its file count'
    Assert-True (-not $preview.Contains($owned)) 'Folder preview omits contained filenames'
    Invoke-InstallPurgePlan -Plan $plans[0]
    Assert-True (-not (Test-Path $owned)) 'Applier removes the folder declared by the descriptor'
    Assert-Equal '{"enabledPlugins":{},"other":1}' ([IO.File]::ReadAllText($settings)) 'Applier uses the descriptor settings file and preserves unrelated bytes'
    $entry.plugin.purge.paths=@('../fake-real')
    Assert-Throws { Get-InstallCatalog -Catalog $catalog } 'Standalone catalog rejects purge paths outside a tool folder'
    $descriptor = Get-Content (Join-Path $repo 'plugins/ps-ai/skills/ps-ai-claude/tool.json') -Raw | ConvertFrom-Json
    $descriptor.plugin.purge.settings[0].path='../outside.json'
    $invalid = $descriptor | ConvertTo-Json -Depth 100
    # The standalone installer also runs on 5.1; JSON Schema validation is a 7-only check.
    if (Get-Command Test-Json -ErrorAction SilentlyContinue) {
        Assert-True (-not (Test-Json -Json $invalid -SchemaFile (Join-Path $repo 'plugins/ps-ai/schemas/tool.schema.json') -ErrorAction SilentlyContinue)) 'Tool schema rejects settings paths outside the config folder'
    }
}
