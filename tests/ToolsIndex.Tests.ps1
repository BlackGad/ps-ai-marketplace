. (Join-Path $PSScriptRoot 'lib/paths.ps1')
# IndexProjectionIsDeterministicAndWriteFree: the standalone catalog is generated data.
& {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $generator = Join-Path $repoRoot 'tools/update-tools-index.ps1'
    $indexPath = Join-Path $repoRoot 'plugins/legion/tools.json'
    Assert-True (Test-Path -LiteralPath $generator) 'Tools index generator exists'
    Assert-True (Test-Path -LiteralPath $indexPath) 'Generated tools index exists'
    $trackedBytes = [IO.File]::ReadAllBytes($indexPath)
    $trackedTime = [IO.File]::GetLastWriteTimeUtc($indexPath)
    $noRunOutput = @(. $generator -NoRun)
    Assert-Equal 0 $noRunOutput.Count 'NoRun only defines functions'
    Assert-Equal $trackedTime ([IO.File]::GetLastWriteTimeUtc($indexPath)) 'NoRun does not write the index'

    $tools = @(Get-ToolsIndexTools)
    $rendered = Get-ToolsIndexContent -Tools $tools
    Assert-True ($rendered -is [string]) 'Renderer returns one string'
    Assert-Equal ([Convert]::ToBase64String($trackedBytes)) ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($rendered))) 'Fresh projection equals tracked bytes'
    Assert-True (-not ($trackedBytes[0] -eq 239 -and $trackedBytes[1] -eq 187 -and $trackedBytes[2] -eq 191)) 'Index has no UTF-8 BOM'
    Assert-True (-not $rendered.Contains("`r")) 'Index uses LF'
    Assert-True ($rendered.EndsWith("`n") -and -not $rendered.EndsWith("`n`n")) 'Index has one final newline'
    $reversed = @($tools)
    [Array]::Reverse($reversed)
    Assert-Equal $rendered (Get-ToolsIndexContent -Tools $reversed) 'Renderer sorts input by id'
    $index = $rendered | ConvertFrom-Json
    Assert-True (-not $rendered.Contains('legacyHookTrust')) 'Catalog has no legacy Codex trust cleanup flag'
    Assert-Equal 1 $index.schemaVersion 'Catalog schema version'
    Assert-Equal ($tools.id -join '|') ($index.tools.id -join '|') 'Catalog tools are sorted'
    foreach ($entry in $index.tools) {
        $source = $tools | Where-Object id -CEQ $entry.id
        Assert-Equal $source.command $entry.command 'Executable is projected'
        Assert-Equal $source.configEnv $entry.configEnv 'Config environment is projected'
        Assert-Equal ($source.plugin | ConvertTo-Json -Depth 100 -Compress) ($entry.plugin | ConvertTo-Json -Depth 100 -Compress) 'Plugin arguments and listing rules are projected intact'
        Assert-Equal ($source.hooks | ConvertTo-Json -Compress) ($entry.hooks | ConvertTo-Json -Compress) 'Hook hints are projected intact'
        Assert-Equal $source.install.hint $entry.installHint 'Install hint comes from the recipe'
    }
    Assert-True (-not ($rendered -match 'SkillRoot|foundry|foundry-launch|foundry-config|deploymentPrefix')) 'Index excludes runtime paths and provider data'

    $scratchRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot '.agents/temp/restructure'))
    $copyRoot = Join-Path $scratchRoot ('index-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $copyRoot 'tools'), (Join-Path $copyRoot 'plugins') -Force | Out-Null
    try {
        Copy-Item -LiteralPath $generator -Destination (Join-Path $copyRoot 'tools/update-tools-index.ps1')
        Copy-Item -LiteralPath (Join-Path $repoRoot 'plugins/legion') -Destination (Join-Path $copyRoot 'plugins/legion') -Recurse
        $copyGenerator = Join-Path $copyRoot 'tools/update-tools-index.ps1'
        $copyIndex = Join-Path $copyRoot 'plugins/legion/tools.json'
        Remove-Item -LiteralPath $copyIndex
        Assert-Throws { & $copyGenerator -Check } 'Check rejects a missing index'
        Assert-True (-not (Test-Path -LiteralPath $copyIndex)) 'Check never creates missing output'
        & $copyGenerator | Out-Null
        Assert-Equal ([Convert]::ToBase64String($trackedBytes)) ([Convert]::ToBase64String([IO.File]::ReadAllBytes($copyIndex))) 'Generation in a relocated repo produces identical bytes'
        [IO.File]::SetLastWriteTimeUtc($copyIndex, [datetime]'2020-01-01T00:00:00Z')
        $beforeTime = [IO.File]::GetLastWriteTimeUtc($copyIndex)
        Assert-Equal 'skip: tools index (already done)' (& $copyGenerator) 'Unchanged generation reports a skip'
        & $copyGenerator -Check | Out-Null
        Assert-Equal $beforeTime ([IO.File]::GetLastWriteTimeUtc($copyIndex)) 'Unchanged generation and Check preserve mtime'
        Assert-Equal ([Convert]::ToBase64String($trackedBytes)) ([Convert]::ToBase64String([IO.File]::ReadAllBytes($copyIndex))) 'Unchanged generation preserves bytes'

        # A byte-only drift must fail even when the parsed JSON still matches.
        [IO.File]::AppendAllText($copyIndex, "`n")
        $driftBytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($copyIndex))
        $driftTime = [IO.File]::GetLastWriteTimeUtc($copyIndex)
        Assert-Throws { & $copyGenerator -Check } 'Check detects byte drift'
        Assert-Equal $driftBytes ([Convert]::ToBase64String([IO.File]::ReadAllBytes($copyIndex))) 'Check leaves drifted bytes unchanged'
        Assert-Equal $driftTime ([IO.File]::GetLastWriteTimeUtc($copyIndex)) 'Check leaves drifted mtime unchanged'
        & $copyGenerator | Out-Null
        Assert-Equal ([Convert]::ToBase64String($trackedBytes)) ([Convert]::ToBase64String([IO.File]::ReadAllBytes($copyIndex))) 'Normal generation repairs drift'

        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth') -Destination (Join-Path $copyRoot 'plugins/legion/skills/legion-fourth') -Recurse
        Assert-Throws { & $copyGenerator -Check } 'New tool makes the catalog stale'
        & $copyGenerator | Out-Null
        $extended = Get-Content -LiteralPath $copyIndex -Raw | ConvertFrom-Json
        Assert-Equal (@(Get-ToolsIndexTools -SkillsRoot (Join-Path $copyRoot 'plugins/legion/skills')).id -join '|') ($extended.tools.id -join '|') 'A fourth skill enters the index without shared edits'
        $fourthDescriptor = Get-Content (Join-Path $copyRoot 'plugins/legion/skills/legion-fourth/tool.json') -Raw | ConvertFrom-Json
        Assert-Equal $fourthDescriptor.command ($extended.tools | Where-Object id -CEQ $fourthDescriptor.id).command 'Fourth tool executable comes from its descriptor'
        & $copyGenerator -Check | Out-Null

        # A checkout on Windows must preserve the generated byte contract too.
        $attributes = Join-Path $repoRoot '.gitattributes'
        if (Test-Path -LiteralPath $attributes) { Copy-Item -LiteralPath $attributes -Destination $copyRoot }
        & git -C $copyRoot -c init.defaultBranch=fixture init --quiet
        $checkoutBytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($copyIndex))
        $checkoutFiles = @('plugins/legion/tools.json')
        if (Test-Path -LiteralPath (Join-Path $copyRoot '.gitattributes')) { $checkoutFiles += '.gitattributes' }
        & git -C $copyRoot -c core.autocrlf=true -c core.safecrlf=false add -- @checkoutFiles 2>$null
        Assert-Equal 0 $LASTEXITCODE 'Fixture index is staged locally'
        Remove-Item -LiteralPath $copyIndex
        & git -C $copyRoot -c core.autocrlf=true checkout -- plugins/legion/tools.json
        Assert-Equal 0 $LASTEXITCODE 'Fixture index checks out locally'
        Assert-Equal $checkoutBytes ([Convert]::ToBase64String([IO.File]::ReadAllBytes($copyIndex))) 'Checkout preserves LF index bytes with autocrlf enabled'
        & $copyGenerator -Check | Out-Null

        $codexPath = Join-Path $copyRoot 'plugins/legion/skills/legion-codex/tool.json'
        $validCodex = [IO.File]::ReadAllText($codexPath)
        foreach ($unsafe in @('../outside', '/outside', 'C:/outside', 'plugins/*', 'plugins/?')) {
            $bad = $validCodex | ConvertFrom-Json
            $bad.plugin.cacheDir = $unsafe
            [IO.File]::WriteAllText($codexPath, ($bad | ConvertTo-Json -Depth 100))
            Assert-Throws { & $copyGenerator } 'Generator rejects an unsafe relative cache path'
            Assert-Throws { & $copyGenerator -Check } 'Check rejects an unsafe relative cache path'
            Assert-Equal $checkoutBytes ([Convert]::ToBase64String([IO.File]::ReadAllBytes($copyIndex))) 'Invalid descriptor leaves the generated catalog intact'
        }
        [IO.File]::WriteAllText($codexPath, $validCodex)

        foreach ($change in @(
            { param($d) $d.command = 12 },
            { param($d) $d.plugin.listing.format = @('json') },
            { param($d) $d.plugin.marketplaceAdd = 'bad' },
            { param($d) $d.id = 'claude' },
            { param($d) $d.plugin = @($d.plugin) },
            { param($d) $d.plugin.listing = @($d.plugin.listing) }
        )) {
            $bad = $validCodex | ConvertFrom-Json
            & $change $bad
            [IO.File]::WriteAllText($codexPath, ($bad | ConvertTo-Json -Depth 100))
            Assert-Throws { & $copyGenerator } 'Generator rejects malformed or duplicate tool metadata'
            Assert-Equal $checkoutBytes ([Convert]::ToBase64String([IO.File]::ReadAllBytes($copyIndex))) 'Invalid tool metadata leaves catalog intact'
        }
        [IO.File]::WriteAllText($codexPath, $validCodex)

        # The real generator also validates descriptors that are not projected.
        $channelPath = Join-Path $copyRoot 'plugins/legion/skills/legion-telegram/channel.json'
        $validChannel = [IO.File]::ReadAllText($channelPath)
        [IO.File]::WriteAllText($channelPath, '{"schemaVersion":1,"id":"telegram","launch":{"unknown":[]}}')
        Assert-Throws { & $copyGenerator } 'Generation rejects a channel bound to an unknown tool'
        Assert-Throws { & $copyGenerator -Check } 'Check validates channel descriptors too'
        Assert-Equal $checkoutBytes ([Convert]::ToBase64String([IO.File]::ReadAllBytes($copyIndex))) 'Invalid channel leaves the catalog intact'
        [IO.File]::WriteAllText($channelPath, $validChannel)
        $helpersPath = Join-Path $copyRoot 'plugins/legion/helpers.json'
        $validHelpers = [IO.File]::ReadAllText($helpersPath)
        [IO.File]::WriteAllText($helpersPath, '{"node":{"check":42}}')
        Assert-Throws { & $copyGenerator } 'Generation rejects malformed helper recipes'
        Assert-Throws { & $copyGenerator -Check } 'Check validates helper recipes too'
        Assert-Equal $checkoutBytes ([Convert]::ToBase64String([IO.File]::ReadAllBytes($copyIndex))) 'Invalid helpers leave the catalog intact'
        [IO.File]::WriteAllText($helpersPath, $validHelpers)

    } finally {
        Remove-TestFolder -Path $copyRoot -AllowedParent $scratchRoot
    }
}

# Descriptor boundaries must survive the real renderer and standalone JSON loader.
& {
    $repo = Split-Path $PSScriptRoot -Parent
    . (Join-Path $repo 'tools/update-tools-index.ps1') -NoRun
    $schema = Join-Path $repo 'plugins/legion/schemas/tool.schema.json'
    $descriptorJson = Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth/tool.json') -Raw
    $fields = @('marketplaceAdd', 'marketplaceRemove', 'install', 'marketplaceList', 'list', 'marketplaceUpdate', 'update')
    $scratchRoot = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp/restructure'))
    $scratch = Join-Path $scratchRoot ('catalog-boundaries-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $scratch 'plugins/legion') -Force | Out-Null
    $descriptorFolder = Join-Path $scratch 'skills/legion-fourth'
    New-Item -ItemType Directory -Path $descriptorFolder -Force | Out-Null
    try {
        foreach ($boundary in @('empty-string-arguments', 'empty-arrays', 'empty-hook-status')) {
            $descriptor = $descriptorJson | ConvertFrom-Json
            switch ($boundary) {
                'empty-string-arguments' { foreach ($field in $fields) { $descriptor.plugin.$field = @('--namespace', '', ' ') } }
                'empty-arrays' { foreach ($field in $fields) { $descriptor.plugin.$field = @() } }
                'empty-hook-status' { $descriptor.hooks.status = '' }
            }
            Assert-True (Test-Json -Json ($descriptor | ConvertTo-Json -Depth 100) -SchemaFile $schema) "$boundary is schema valid"
            $loaded = Get-ToolsIndexContent -Tools @($descriptor) | ConvertFrom-Json
            foreach ($field in $fields) {
                Assert-Equal ($descriptor.plugin.$field | ConvertTo-Json -Compress) ($loaded.tools[0].plugin.$field | ConvertTo-Json -Compress) "$boundary preserves plugin.$field"
                Assert-True ($loaded.tools[0].plugin.$field -is [array]) "$boundary retains argument arrays"
            }
            Assert-Equal $descriptor.hooks.status $loaded.tools[0].hooks.status "$boundary preserves hooks.status"
        }
        foreach ($field in $fields) {
            foreach ($value in @($null, '', 42, @{}, @('valid', $null), @('valid', 42))) {
                $descriptor = $descriptorJson | ConvertFrom-Json
                $descriptor.plugin.$field = $value
                Assert-True (-not (Test-Json -Json ($descriptor | ConvertTo-Json -Depth 100) -SchemaFile $schema -ErrorAction SilentlyContinue)) "Schema rejects invalid plugin.$field"
                $descriptor | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $descriptorFolder 'tool.json')
                Assert-Throws { Get-ToolsIndexTools -SkillsRoot (Join-Path $scratch 'skills') } "Generator reader rejects invalid plugin.$field"
            }
        }
        foreach ($value in @($null, 42, @('status'))) {
            $descriptor = $descriptorJson | ConvertFrom-Json
            $descriptor.hooks.status = $value
            Assert-True (-not (Test-Json -Json ($descriptor | ConvertTo-Json -Depth 100) -SchemaFile $schema -ErrorAction SilentlyContinue)) 'Schema rejects non-string hooks.status'
            $descriptor | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $descriptorFolder 'tool.json')
            Assert-Throws { Get-ToolsIndexTools -SkillsRoot (Join-Path $scratch 'skills') } 'Generator reader rejects non-string hooks.status'
        }
    } finally {
        Remove-TestFolder -Path $scratch -AllowedParent $scratchRoot
    }
}

# Build-time tool and helper validation (moved from runtime discovery tests).
& {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    . (Join-Path $repoRoot 'tools/update-tools-index.ps1') -NoRun
    $helpersPath = Join-Path $repoRoot 'plugins/legion/helpers.json'
    $fourthJson = Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth/tool.json') -Raw
    $scratchRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot '.agents/temp/restructure'))
    $discoveryRoot = Join-Path $scratchRoot ('discovery-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $discoveryRoot -Force | Out-Null
    function New-TestToolSkill {
        param([string]$Name = 'legion-fourth', [scriptblock]$Change = {})
        $folder = Join-Path $discoveryRoot $Name
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth') -Destination $folder -Recurse
        $data = $fourthJson | ConvertFrom-Json -AsHashtable
        $null = & $Change $data
        $data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $folder 'tool.json')
        return $folder
    }
    try {
        $folder = New-TestToolSkill
        $first = New-TestToolSkill -Name legion-aaa -Change { param($d) $d.id = 'aaa' }
        $cultureBefore = [cultureinfo]::CurrentCulture
        try {
            foreach ($cultureName in @('en-US', 'da-DK')) {
                [cultureinfo]::CurrentCulture = [cultureinfo]::GetCultureInfo($cultureName)
                Assert-Equal 'aaa|fourth' (@(Get-ToolsIndexTools -SkillsRoot $discoveryRoot).id -join '|') 'Discovery order is ordinal across cultures'
                # Both neighbors mismatch; the first diagnostic must also be stable.
                $badData = $fourthJson | ConvertFrom-Json -AsHashtable
                $badData.id = 'zzz'
                $badData | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $first 'tool.json')
                $badData.id = 'other'
                $badData | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $folder 'tool.json')
                $message = ''
                try { Get-ToolsIndexTools -SkillsRoot $discoveryRoot | Out-Null } catch { $message = $_.Exception.Message }
                Assert-True ($message.Contains("tool id 'zzz'")) 'Invalid neighbor diagnostics use ordinal folder order'
                $badData.id = 'aaa'
                $badData | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $first 'tool.json')
                Set-Content -LiteralPath (Join-Path $folder 'tool.json') -Value $fourthJson
            }
        } finally { [cultureinfo]::CurrentCulture = $cultureBefore }
        Move-Item -LiteralPath $first -Destination (Join-Path $discoveryRoot 'first-disabled')

        $original = Get-Content -LiteralPath (Join-Path $folder 'tool.json') -Raw
        foreach ($change in @(
            { param($d) $d.id = 'mismatch' },
            { param($d) $d.id = '../outside' },
            { param($d) $d.schemaVersion = 2 },
            { param($d) $d.Remove('command') },
            { param($d) $d.unexpected = 'value' },
            { param($d) $d.plugin.listing.rejectPattern = '[' },
            { param($d) $d.install.windows.download.zip.assetPattern = '[' },
            { param($d) $d.install.windows.portableCommand = '../outside.exe' },
            { param($d) $d.plugin.cacheDir = 'cache/../../outside' },
            { param($d) $d.overseerArgs = @('--flag', 42) }
        )) {
            $data = $original | ConvertFrom-Json -AsHashtable
            $null = & $change $data
            $data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $folder 'tool.json')
            Assert-Throws { Get-ToolsIndexTools -SkillsRoot $discoveryRoot | Out-Null } 'Invalid neighboring descriptor stops discovery'
        }
        '{invalid' | Set-Content -LiteralPath (Join-Path $folder 'tool.json')
        Assert-Throws { Get-ToolsIndexTools -SkillsRoot $discoveryRoot | Out-Null } 'Malformed descriptors stop generation'
        Set-Content -LiteralPath (Join-Path $folder 'tool.json') -Value $original
        foreach ($requiredFile in @('SKILL.md')) {
            $path = Join-Path $folder $requiredFile
            Move-Item -LiteralPath $path -Destination ($path + '.held')
            Assert-Throws { Get-ToolsIndexTools -SkillsRoot $discoveryRoot | Out-Null } 'Missing skill/capability script stops discovery'
            Move-Item -LiteralPath ($path + '.held') -Destination $path
        }
        $duplicate = New-TestToolSkill -Name legion-duplicate
        $message = ''
        try { Get-ToolsIndexTools -SkillsRoot $discoveryRoot | Out-Null } catch { $message = $_.Exception.Message }
        Assert-True ($message.Contains("duplicate tool id 'fourth'")) 'Duplicate diagnostic wins over directory mismatch'
        Move-Item -LiteralPath $duplicate -Destination (Join-Path $discoveryRoot 'duplicate-disabled')

        $recipes = Get-ToolsIndexRecipes -SkillsRoot $discoveryRoot
        $badHelpers = Get-Content -LiteralPath $helpersPath -Raw | ConvertFrom-Json -AsHashtable
        $badHelpers.fourth = $recipes.fourth
        $testHelpers = Join-Path $discoveryRoot 'helpers.json'
        $badHelpers | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $testHelpers
        Assert-Throws { Get-ToolsIndexRecipes -SkillsRoot $discoveryRoot -HelpersPath $testHelpers | Out-Null } 'Helper/agent collision rejected'
        $badHelpers.Remove('fourth')
        $validHelpers = $badHelpers | ConvertTo-Json -Depth 100
        foreach ($field in @('assetPattern')) {
            $badHelpers = $validHelpers | ConvertFrom-Json -AsHashtable
            $badHelpers.git.windows.download.msi[$field] = '['
            $badHelpers | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $testHelpers
            Assert-Throws { Get-ToolsIndexRecipes -SkillsRoot $discoveryRoot -HelpersPath $testHelpers | Out-Null } 'Invalid helper regex rejected'
        }
        $badHelpers = $validHelpers | ConvertFrom-Json -AsHashtable
        $badHelpers.node.windows.download.zip.Remove('checksumUrl')
        $badHelpers | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $testHelpers
        Assert-Throws { Get-ToolsIndexRecipes -SkillsRoot $discoveryRoot -HelpersPath $testHelpers | Out-Null } 'Malformed helper recipe rejected'

        # Prerequisite validation belongs to the build; no installer is invoked.
        foreach ($needs in @(@('fourth'), @('node', 'missing-helper'))) {
            $data = $original | ConvertFrom-Json -AsHashtable
            $data.install.macos.needs = $needs
            $data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $folder 'tool.json')
            Assert-Throws { Get-ToolsIndexRecipes -SkillsRoot $discoveryRoot } 'Self and unknown helper prerequisites fail generation'
        }
        Set-Content -LiteralPath (Join-Path $folder 'tool.json') -Value $original
        $badHelpers = $validHelpers | ConvertFrom-Json -AsHashtable
        $badHelpers.node.macos.needs = @('git')
        $badHelpers.git.macos.needs = @('node')
        $badHelpers | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $testHelpers
        Assert-Throws { Get-ToolsIndexRecipes -SkillsRoot $discoveryRoot -HelpersPath $testHelpers } 'Helper dependency cycles fail generation'


    } finally {
        Remove-TestFolder -Path $discoveryRoot -AllowedParent $scratchRoot
    }
}

# Build-time channel validation (moved from runtime channel tests).
& {
    $root = Split-Path $PSScriptRoot -Parent
    . (Join-Path $root 'tools/update-tools-index.ps1') -NoRun
    $scratch = Join-Path $root ('.agents/temp/channel-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory $scratch -Force | Out-Null
    Copy-Item (Join-Path $root 'plugins/legion/skills/legion-claude') $scratch -Recurse
    $skill = Join-Path $scratch 'legion-fixture-channel'
    Copy-Item (Join-Path $PSScriptRoot 'fixtures/channels/legion-fixture-channel') $skill -Recurse
    $descriptor = @(Get-ToolsIndexChannels -SkillsRoot $scratch)[0]
    Assert-Equal '|two words|2026-11-19|semi;literal|quote''value' ($descriptor.launch.claude -join '|') 'LiteralChannelArguments'
    Assert-Equal 'fixture-channel' $descriptor.id 'DiscoverSecondChannelKind'
    foreach ($bad in @(
        '{"schemaVersion":2,"id":"fixture-channel","launch":{"claude":[]}}',
        '{"schemaVersion":1,"id":"wrong","launch":{"claude":[]}}',
        '{"schemaVersion":1,"id":"fixture-channel","launch":{"unknown":[]}}',
        '{"schemaVersion":1,"id":"fixture-channel","launch":{"claude":[1]}}'
    )) {
        $bad | Set-Content (Join-Path $skill 'channel.json')
        Assert-Throws { Get-ToolsIndexChannels -SkillsRoot $scratch } 'Malformed descriptor fails'
    }
    # ready is an accepted fourth key; any other extra key is rejected
    Remove-Item -LiteralPath $skill -Recurse -Force
    $telegram = Join-Path $scratch 'legion-telegram'
    New-Item -ItemType Directory $telegram -Force | Out-Null
    Copy-Item (Join-Path $root 'plugins/legion/skills/legion-telegram/SKILL.md') $telegram
    $ready = '"ready":{"command":"bun","pluginFolder":{"claude":"plugins/cache/claude-plugins-official/telegram"}}'
    $base = '"schemaVersion":1,"id":"telegram","launch":{"claude":[]}'
    "{$base,$ready}" | Set-Content (Join-Path $telegram 'channel.json')
    Assert-Equal 'bun' (@(Get-ToolsIndexChannels -SkillsRoot $scratch | Where-Object id -CEQ telegram)[0].ready.command) 'Ready accepted'
    $missingSkill = Join-Path $telegram 'SKILL.md'
    Move-Item -LiteralPath $missingSkill -Destination ($missingSkill + '.held')
    Assert-Throws { Get-ToolsIndexChannels -SkillsRoot $scratch } 'Missing channel skill fails generation'
    Move-Item -LiteralPath ($missingSkill + '.held') -Destination $missingSkill

    "{$base,$ready,`"extra`":1}" | Set-Content (Join-Path $telegram 'channel.json')
    Assert-Throws { Get-ToolsIndexChannels -SkillsRoot $scratch } 'Unknown fifth key rejected'
    "{$base,`"extra`":1}" | Set-Content (Join-Path $telegram 'channel.json')
    Assert-Throws { Get-ToolsIndexChannels -SkillsRoot $scratch } 'Unknown key without ready rejected'

    Remove-TestFolder -Path $scratch -AllowedParent (Join-Path $root '.agents/temp')
}

& {
    . (Join-Path (Split-Path $PSScriptRoot -Parent) 'tools/update-tools-index.ps1') -NoRun
    # FlatNeeds: a helper may not have prerequisites.
    $recipes = @{ tool = @{ macos = @{ needs = @('helper') } }; helper = @{ macos = @{ needs = @('other') } }; other = @{ macos = @{ needs = @() } } }
    Assert-Throws { Assert-LegionInstallNeeds -Tool tool -Platform macos -Recipes $recipes -HelperIds @('helper', 'other') } 'A helper with prerequisites is rejected'
}
