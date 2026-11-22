. (Join-Path $PSScriptRoot 'lib/installer.ps1')

# Every scenario has its own home, all three config overrides, and an outside-home
# sentinel. No test boundary can invoke a real CLI, registry writer or downloader.
function Test-PurgeScenario {
    param([scriptblock]$Body)
    & {
        . $installerPath -NoRun
        $catalog = Get-InstallCatalog -Source $repo
        $scratch = New-InstallTestFolder 'purge'
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
        function Get-LegionUserPath { $state.UserPath }
        function Set-LegionUserPath { param($Path) $state.UserPath=$Path; $state.PathWrites++ }
        function Read-Host {
            param($Prompt)
            $state.Prompts += $Prompt
            if (-not $state.Answers.Count) { throw "Unexpected prompt: $Prompt" }
            $answer = $state.Answers[0]
            $state.Answers = @($state.Answers | Select-Object -Skip 1)
            return $answer
        }
        function Invoke-ClosedInput {
            param($Command, $Environment)
            $entry = $catalog.tools | Where-Object command -CEQ $Command[0]
            $folder = $Environment[$entry.configEnv]
            Assert-True ($folder.StartsWith($fixtureHome + [IO.Path]::DirectorySeparatorChar)) 'Every CLI gets a temporary config folder'
            if ($Command[2] -eq 'list') {
                $line = if ($entry.id -eq 'claude') { if ($state.Installed) { '[{"id":"legion@ps-legion-marketplace","enabled":true}]' } else { '[]' } }
                    elseif ($state.Installed) { 'legion@ps-legion-marketplace installed' } else { '' }
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
            param([string]$Relative, [string]$Text='legion data')
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
            Remove-InstallTestFolder $scratch
        }
    }
}

Test-PurgeScenario {
    $sharedHomePath = ${function:Resolve-LegionHomePath}
    $expanded = [Collections.Generic.List[string]]::new()
    function Resolve-LegionHomePath {
        param([string]$Path, [string]$HomeRoot)
        Assert-Equal $fixtureHome $HomeRoot 'Shared expansion receives the selected home'
        $expanded.Add($Path)
        & $sharedHomePath -Path $Path -HomeRoot $HomeRoot
    }
    foreach ($path in @('~/selected/', '~\selected\', '~/nested/../selected/')) {
        Assert-Equal (Join-Path $fixtureHome 'selected') (Resolve-InstallConfigDir $path) 'Home aliases normalize to one folder'
    }
    Assert-Equal $fixtureHome (Resolve-InstallConfigDir '~') 'Bare tilde selects the home itself'
    Assert-True ($expanded.Count -ge 3) 'Installer delegates leading tilde expansion to the shared helper'
}

Test-PurgeScenario {
    $walks = [Collections.Generic.List[string]]::new()
    $sharedWalk = ${function:Test-LegionOwnerPathSafe}
    function Test-LegionOwnerPathSafe {
        param([string]$Path, [string]$StopRoot)
        $walks.Add($StopRoot)
        & $sharedWalk -Path $Path -StopRoot $StopRoot
    }
    $file = New-PurgeFile '.legion/bin/codex-a'
    Assert-True (Test-LegionOwnerPathSafe -Path $file -StopRoot $fixtureHome) 'Generated files use the shared link walk'
    Assert-Equal $file (Get-InstallSafePath -Root $fixtureHome -Relative '.legion/bin/codex-a' -AllowFile) 'Purge paths use the shared link walk'
    Assert-Equal 2 $walks.Count 'Both path guards delegate the ancestor walk'
    foreach ($root in $walks) { Assert-Equal $fixtureHome $root 'Installer link walks stop at the selected home' }
}

Test-PurgeScenario {
    $login = New-PurgeFile '.legion/agents/codex-a/auth.json' 'fake login'
    $notes = New-PurgeFile '.legion/configuration/notes.md' 'notes'
    $repoFile = New-PurgeFile 'repositories/my-project/.legion/configuration/project.json' 'repository data'
    $settings = New-PurgeFile 'override-copilot/settings.json' '{"enabledPlugins":{"other@else":true,"legion@ps-legion-marketplace":false},"theme":"dark"}'
    $cache = New-PurgeFile '.claude/plugins/cache/ps-legion-marketplace/legion/1.0/plugin.json'
    $data = New-PurgeFile 'override-copilot/plugin-data/ps-legion-marketplace/legion/keep-until-purge'
    $state.Installed=$true
    $preview = @(Invoke-LegionInstaller -Catalog $catalog -Uninstall -Purge -DryRun) -join "`n"
    $legionFolder = Join-Path $fixtureHome '.legion'
    Assert-True ($preview.Contains("Remove folder: $legionFolder (2 files)")) 'Preview summarizes the legion folder with its file count'
    Assert-True ($preview.Contains("Remove entry: $settings")) 'Preview lists settings entries'
    foreach ($path in @($login, $notes, $cache, $data)) { Assert-True (-not $preview.Contains($path)) 'Preview does not list files inside removed folders' }
    Assert-Equal 0 $state.Prompts.Count 'Dry run never prompts'
    Assert-Equal 0 $state.Writes.Count 'Dry run never calls CLI mutations'
    Assert-True (Test-Path $login) 'Dry run keeps login'
    $state.Answers=@('y','n')
    $null = Invoke-LegionInstaller -Catalog $catalog -Uninstall -Purge
    Assert-Equal 2 $state.Prompts.Count 'Purge has a separate confirmation after uninstall'
    Assert-True ($state.Prompts[1] -match 'Purge.*settings.*logins') 'Purge question names deleted settings and logins'
    Assert-True ($state.Writes.Count -gt 0) 'Normal uninstall runs first'
    Assert-True (Test-Path $login) 'Declined purge keeps legion'
    $state.Missing=$true
    $output = @(Invoke-LegionInstaller -Catalog $catalog -Uninstall -Purge -Yes 6>&1) -join "`n"
    Assert-True (-not (Test-Path (Join-Path $fixtureHome '.legion'))) 'Purge removes entire legion home'
    Assert-True (-not (Test-Path $cache)) 'Physical default cache removed despite override and absent CLI'
    Assert-True (-not (Test-Path (Join-Path $fixtureHome 'override-copilot/plugin-data/ps-legion-marketplace'))) 'Purge removes Copilot data and empty marketplace parent'
    Assert-Equal '{"enabledPlugins":{"other@else":true},"theme":"dark"}' ([IO.File]::ReadAllText($settings)) 'Only legion member and its comma removed'
    Assert-Equal 'repository data' ([IO.File]::ReadAllText($repoFile)) 'Repository legion folder preserved'
    Assert-True (-not $output.Contains('hook approvals')) 'Purge no longer advertises legacy hook-trust cleanup'
    $repeat = @(Invoke-LegionInstaller -Catalog $catalog -Uninstall -Purge -Yes)
    Assert-True ($repeat -contains 'skip: purge (already done)') 'Repeated purge skips without writes'
}

Test-PurgeScenario {
    $state.Missing=$true
    $null = New-PurgeFile '.legion/configuration/personalisation.json' '{"agents":[{"tool":"claude","configDir":"~/custom-claude"},{"tool":"codex","configDir":"~/custom-codex"}]}'
    $null = New-PurgeFile '.legion/configuration/notes.md' 'current notes'
    $claude = New-PurgeFile 'custom-claude/plugins/installed_plugins.json' '{"version":2,"plugins":{"legion@ps-legion-marketplace":[{"scope":"user"}],"other@else":[{"scope":"user"}]}}'
    $market = New-PurgeFile '.claude/plugins/known_marketplaces.json' '{"ps-legion-marketplace":{"source":{"source":"github"}},"other":{"keep":1}}'
    $copilot = New-PurgeFile 'override-copilot/config.json' '{"installedPlugins":[{"name":"legion","marketplace":"ps-legion-marketplace","cache_path":"unused"},{"name":"other","marketplace":"else"}],"other":123}'
    $tomlText = "# keep`r`nmodel = 'keep'`r`n[plugins.`"legion@ps-legion-marketplace`"]`r`nenabled = false`r`n[plugins.`"other@else`"]`r`nenabled = true`r`n[marketplaces.ps-legion-marketplace]`r`nsource_type = 'git'`r`nsource = 'example/repo'`r`n[hooks.state.'legion@ps-legion-marketplace:hooks/hooks.json:session_start:0:0']`r`ntrusted_hash = 'fake'`r`n[hooks.state.'other@else:hooks/hooks.json:session_start:0:0']`r`ntrusted_hash = 'keep'`r`n"
    $toml = New-PurgeFile 'custom-codex/config.toml' $tomlText
    $null = Invoke-LegionInstaller -Catalog $catalog -Uninstall -Purge -Yes
    Assert-Equal '{"version":2,"plugins":{"other@else":[{"scope":"user"}]}}' ([IO.File]::ReadAllText($claude)) 'Recorded config plugin inventory cleaned'
    Assert-Equal '{"other":{"keep":1}}' ([IO.File]::ReadAllText($market)) 'Physical default marketplace registry cleaned'
    Assert-Equal '{"installedPlugins":[{"name":"other","marketplace":"else"}],"other":123}' ([IO.File]::ReadAllText($copilot)) 'Copilot internal plugin record removed without rewriting unrelated state'
    $expected = "# keep`r`nmodel = 'keep'`r`n[plugins.`"other@else`"]`r`nenabled = true`r`n[hooks.state.'other@else:hooks/hooks.json:session_start:0:0']`r`ntrusted_hash = 'keep'`r`n"
    Assert-Equal $expected ([IO.File]::ReadAllText($toml)) 'Only legion TOML tables removed, keeping CRLF'
    Assert-True (-not (Test-Path (Join-Path $fixtureHome '.legion'))) 'Purge footprint includes both old and new owner filenames'
}

Test-PurgeScenario {
    $state.Missing=$true
    $cases = @(
        @{ Text='"legion@ps-legion-marketplace":false,"a":true'; Expected='"a":true' },
        @{ Text='"a":true,"legion@ps-legion-marketplace":false,"b":false'; Expected='"a":true,"b":false' },
        @{ Text='"legion@ps-legion-marketplace":true'; Expected='' },
        @{ Text='"a":true, /* keep */ "legion@ps-legion-marketplace":false,'; Expected='"a":true, /* keep */ '; Comment=$true }
    )
    foreach ($ending in @("`n", "`r`n")) {
        foreach ($case in $cases) {
            # Build input and expected output from explicit line endings, independent of checkout.
            $textLines = @('{', ('"enabledPlugins": {' + $case.Text + '},'), '"note":"legion@ps-legion-marketplace"', '}')
            $expectedLines = @('{', ('"enabledPlugins": {' + $case.Expected + '},'), '"note":"legion@ps-legion-marketplace"', '}')
            if ($case.Comment) { $textLines = @('// keep comment') + $textLines; $expectedLines = @('// keep comment') + $expectedLines }
            $text = $textLines -join $ending
            $expected = $expectedLines -join $ending
            $file = New-PurgeFile 'override-copilot/settings.json' $text
            $null = Invoke-LegionInstaller -Catalog $catalog -Uninstall -Purge -Yes
            Assert-Equal $expected ([IO.File]::ReadAllText($file)) 'JSON/JSONC removes only the legion member and preserves LF or CRLF bytes'
        }
        $file = New-PurgeFile 'override-copilot/settings.json' (@('{', '"enabledPlugins":{"legion@ps-legion-marketplace":false,broken}', '}') -join $ending)
        $before = (Get-FileHash $file).Hash
        $output = @(Invoke-LegionInstaller -Catalog $catalog -Uninstall -Purge -Yes 6>&1) -join "`n"
        Assert-Equal $before (Get-FileHash $file).Hash 'Unsafe JSONC left unchanged for either line ending'
        Assert-True ($output.Contains("Manual step: $file")) 'Unsafe JSONC reported for manual cleanup'
    }
}

Test-PurgeScenario {
    $state.Missing=$true
    $env:OS='Windows_NT'
    $bin = Join-Path $fixtureHome '.legion/bin'
    $portable = Join-Path $fixtureHome '.legion/tools/pwsh'
    foreach ($entry in @($bin, $portable)) { Add-LegionFootprint -HomeRoot $fixtureHome -Kind path-entry -Path 'user PATH' -Value $entry -Owner legion }
    $state.UserPath="keep-first;$bin;keep-middle;$portable;keep-last;"
    $separator = [string][IO.Path]::PathSeparator
    $env:PATH = @('keep-first', $bin, 'keep-middle', $portable, 'keep-last') -join $separator
    $null = New-PurgeFile '.legion/configuration/notes.md' 'notes'
    $preview = @(Invoke-LegionInstaller -Catalog $catalog -Uninstall -Purge -DryRun) -join "`n"
    Assert-True ($preview.IndexOf("Remove user PATH entry: $bin") -lt $preview.IndexOf('Remove folder:')) 'PATH entries listed before folder removal'
    Assert-True ($preview.Contains("Remove process PATH entry: $bin")) 'Process PATH changes listed'
    Assert-Equal 0 $state.PathWrites 'Preview keeps user PATH'
    $null = Invoke-LegionInstaller -Catalog $catalog -Uninstall -Purge -Yes
    Assert-Equal 'keep-first;keep-middle;keep-last;' $state.UserPath 'Only exact legion user PATH entries removed'
    Assert-Equal (@('keep-first','keep-middle','keep-last') -join $separator) $env:PATH 'Only exact legion process PATH entries removed'
    Assert-Equal 1 $state.PathWrites 'User PATH updated once'
    $null = Invoke-LegionInstaller -Catalog $catalog -Uninstall -Purge -Yes
    Assert-Equal 1 $state.PathWrites 'Repeat keeps PATH unchanged'
}

Test-PurgeScenario {
    . (Join-Path $repo 'plugins/legion/bin/legion.ps1') -HomeRoot $fixtureHome
    $call = Get-LegionCall -Words @('uninstall','--purge','--yes')
    Assert-True ($call.Splat.Uninstall -and $call.Splat.Purge -and $call.Splat.Yes) 'Legion forwards purge with uninstall'
    Assert-Throws { Get-LegionCall -Words @('update','--purge') } 'Update rejects purge'
    Assert-True (((Get-LegionHelp) -join "`n").Contains('uninstall [--purge]')) 'Help includes purge'
    # Exercise the local root entry point without invoking any CLI or registry API.
    $entry = Get-Content (Join-Path $repo 'install.ps1') -Raw
    $pluginFolder=Join-Path $fixtureHome 'archive/top/plugins/legion'
    New-Item -ItemType Directory -Path $pluginFolder -Force | Out-Null
    'param([switch]$Uninstall,[switch]$Purge,[switch]$Yes,[string]$HomeRoot); [string][bool]$Purge | Set-Content (Join-Path $HomeRoot "purge-forwarded.txt")' |
        Set-Content (Join-Path $pluginFolder 'install.ps1')
    Copy-Item (Join-Path $repo 'plugins/legion/tools.json') (Join-Path $pluginFolder 'tools.json')
    $archive=Join-Path $fixtureHome 'plugin.zip'
    Compress-Archive -Path (Join-Path $fixtureHome 'archive/top') -DestinationPath $archive
    function Invoke-WebRequest { param($Uri,$OutFile) Copy-Item -LiteralPath (Join-Path $fixtureHome 'plugin.zip') -Destination $OutFile }
    $null = & ([scriptblock]::Create($entry)) -Uninstall -Purge -Yes -HomeRoot $fixtureHome
    Assert-Equal 'True' ((Get-Content (Join-Path $fixtureHome 'purge-forwarded.txt') -Raw).Trim()) 'Downloaded root one-liner forwards purge'
}

Test-PurgeScenario {
    $state.Missing=$true
    $config = Join-Path $fixtureHome '.codex'
    # Reproduce the historical key only in this fixture to prove it stays untouched.
    $bytes = [Collections.Generic.List[byte]]::new()
    foreach ($part in @([IO.Path]::GetFullPath((Join-Path $config 'config.toml')), 'legion@ps-legion-marketplace')) {
        $textBytes = [Text.Encoding]::UTF8.GetBytes($part)
        $length = [BitConverter]::GetBytes([uint64]$textBytes.Length)
        if (-not [BitConverter]::IsLittleEndian) { [Array]::Reverse($length) }
        $bytes.AddRange($length)
        $bytes.AddRange($textBytes)
    }
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $key = ([BitConverter]::ToString($hash.ComputeHash($bytes.ToArray()))).Replace('-', '').ToLowerInvariant() }
    finally { $hash.Dispose() }
    $baseline = New-PurgeFile ".codex/.hook-trust/$key" 'legion bundle hash'
    $unknown = New-PurgeFile '.codex/.hook-trust/unknown-baseline' 'unattributable hash'
    $otherData = New-PurgeFile 'override-copilot/plugin-data/ps-legion-marketplace/other/keep.txt' 'other plugin'
    $otherCache = New-PurgeFile '.codex/plugins/cache/other-marketplace/other/1.0/plugin.json' 'other cache'
    $data = New-PurgeFile '.codex/plugins/data/legion-ps-legion-marketplace/state.json'
    $checkout = New-PurgeFile '.codex/.tmp/marketplaces/ps-legion-marketplace/.git/config'
    $null = Invoke-LegionInstaller -Catalog $catalog -Uninstall -Purge -Yes
    Assert-Equal 'legion bundle hash' ([IO.File]::ReadAllText($baseline)) 'Legacy Codex baseline preserved'
    Assert-Equal 'unattributable hash' ([IO.File]::ReadAllText($unknown)) 'Unknown baseline preserved'
    Assert-True (-not (Test-Path $data)) 'Codex plugin data removed'
    Assert-True (-not (Test-Path $checkout)) 'Managed marketplace checkout removed'
    Assert-Equal 'other plugin' ([IO.File]::ReadAllText($otherData)) 'Other plugin data in same marketplace preserved'
    Assert-Equal 'other cache' ([IO.File]::ReadAllText($otherCache)) 'Other marketplace cache preserved'
    $repeat = @(Invoke-LegionInstaller -Catalog $catalog -Uninstall -Purge -Yes)
    Assert-True ($repeat -contains 'skip: purge (already done)') 'Unrelated marketplace data does not prevent repeat skip'
}

Test-PurgeScenario {
    $state.Missing=$true
    foreach ($encoding in @([Text.UTF8Encoding]::new($true), [Text.UnicodeEncoding]::new($false,$true), [Text.UnicodeEncoding]::new($true,$true))) {
        foreach ($ending in @("`n", "`r`n")) {
            $file = New-PurgeFile 'override-copilot/settings.json'
            $text = @('// preserve BOM, Unicode and line endings', "{`"enabledPlugins`":{`"legion@ps-legion-marketplace`":false},`"name`":`"caf$([char]0xe9)`"}", '') -join $ending
            [IO.File]::WriteAllText($file, $text, $encoding)
            $null = Invoke-LegionInstaller -Catalog $catalog -Uninstall -Purge -Yes
            $expected = [byte[]]($encoding.GetPreamble() + $encoding.GetBytes($text.Replace('"legion@ps-legion-marketplace":false','')))
            Assert-Equal ([Convert]::ToBase64String($expected)) ([Convert]::ToBase64String([IO.File]::ReadAllBytes($file))) 'Settings edit keeps encoding, BOM, Unicode and LF or CRLF bytes'
        }
    }
    foreach ($ending in @("`n", "`r`n")) {
        $prompt = @("developer_instructions = '''", '[plugins."legion@ps-legion-marketplace"]', 'This is prompt text, not a plugin table.', "'''")
        $otherTable = @('[plugins."other@else"]', 'enabled = true')
        $tomlText = ($prompt + @('[plugins."legion@ps-legion-marketplace"]', 'enabled = false') + $otherTable) -join $ending
        $expected = ($prompt + $otherTable) -join $ending
        $file = New-PurgeFile 'override-codex/config.toml' $tomlText
        $output = @(Invoke-LegionInstaller -Catalog $catalog -Uninstall -Purge -Yes) -join "`n"
        Assert-Equal $expected ([IO.File]::ReadAllText($file)) 'TOML removes the real legion table and preserves table-like prompt text with LF or CRLF'
        Assert-True (-not $output.Contains('Manual step:')) 'Valid TOML table removal needs no manual step for either line ending'
        $inlineCases = @(
            @('plugins = { "legion@ps-legion-marketplace" = { enabled = false }, other = { enabled = true } }', ''),
            @('[plugins]', '"legion@ps-legion-marketplace" = { enabled = false }', '"other@else" = { enabled = true }', '')
        )
        foreach ($lines in $inlineCases) {
            $file = New-PurgeFile 'override-codex/config.toml' ($lines -join $ending)
            $before = (Get-FileHash $file).Hash
            $output = @(Invoke-LegionInstaller -Catalog $catalog -Uninstall -Purge -Yes) -join "`n"
            Assert-Equal $before (Get-FileHash $file).Hash 'Unsupported inline TOML stays byte-for-byte unchanged with LF or CRLF'
            Assert-True ($output.Contains("Manual step: $file")) 'Unsupported inline TOML requires a manual step for either line ending'
            Assert-True (-not $output.Contains('skip: purge (already done)')) 'Manual steps never claim purge already complete'
        }
    }
}

Test-PurgeScenario {
    $state.Missing=$true
    $cache = Join-Path $fixtureHome '.claude/plugins/cache/ps-legion-marketplace'
    New-Item -ItemType Directory -Path (Split-Path $cache) -Force | Out-Null
    $linkType = if ($env:OS -eq 'Windows_NT') { 'Junction' } else { 'SymbolicLink' }
    $null = New-Item -ItemType $linkType -Path $cache -Target $outside
    $output = @(Invoke-LegionInstaller -Catalog $catalog -Uninstall -Purge -Yes 6>&1) -join "`n"
    Assert-True ($output.Contains('linked path; left in place')) 'Linked cache reported as manual cleanup'
    Assert-True (Test-Path $cache) 'Purge never traverses linked cache'
    # Remove the link itself before recursive fixture cleanup, without following it.
    [IO.Directory]::Delete($cache)
}

Test-PurgeScenario {
    . (Join-Path $repo 'plugins/legion/bin/legion.ps1') -HomeRoot $fixtureHome
    $copy = Copy-LegionInstaller
    $installer = Join-Path $copy 'install.ps1'
    # The copied installer is real; only its external boundaries are replaced.
    $fakes = @'
function Test-InstallCommandAvailable { $false }
function Get-InstallSourceText { throw 'Network forbidden' }
function Get-LegionUserPath { '' }
function Set-LegionUserPath { throw 'Registry writes forbidden' }
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
    $owned = New-PurgeFile 'override-claude/plugins/extra-owned-legion/entry.txt'
    $settings = New-PurgeFile 'override-claude/extra-settings.json' '{"enabledPlugins":{"legion@ps-legion-marketplace":false},"other":1}'
    $entry = $catalog.tools | Where-Object id -CEQ claude
    $entry.plugin.purge = [pscustomobject]@{
        paths=@('plugins/extra-owned-legion')
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
    Assert-Throws { Get-InstallPurgePlan } 'Purge rejects catalog paths outside a tool folder'
    $descriptor = Get-Content (Join-Path $repo 'plugins/legion/skills/legion-claude/tool.json') -Raw | ConvertFrom-Json
    $descriptor.plugin.purge.settings[0].path='../outside.json'
    $invalid = $descriptor | ConvertTo-Json -Depth 100
    Assert-True (-not (Test-Json -Json $invalid -SchemaFile (Join-Path $repo 'plugins/legion/schemas/tool.schema.json') -ErrorAction SilentlyContinue)) 'Tool schema rejects settings paths outside the config folder'
}
