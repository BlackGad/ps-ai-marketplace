# IndexProjectionIsDeterministicAndWriteFree: the standalone catalog is generated data.
& {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $generator = Join-Path $repoRoot 'tools/update-tools-index.ps1'
    $indexPath = Join-Path $repoRoot 'plugins/ps-ai/tools.json'
    Assert-True (Test-Path -LiteralPath $generator) 'Tools index generator exists'
    Assert-True (Test-Path -LiteralPath $indexPath) 'Generated tools index exists'
    $trackedBytes = [IO.File]::ReadAllBytes($indexPath)
    $trackedTime = [IO.File]::GetLastWriteTimeUtc($indexPath)
    $noRunOutput = @(. $generator -NoRun)
    Assert-Equal 0 $noRunOutput.Count 'NoRun only defines functions'
    Assert-Equal $trackedTime ([IO.File]::GetLastWriteTimeUtc($indexPath)) 'NoRun does not write the index'

    $tools = @(Get-PsAiTools)
    $bootstrap = Get-Content (Join-Path $repoRoot 'tools/bootstrap.json') -Raw | ConvertFrom-Json
    $rendered = Get-ToolsIndexContent -Tools $tools -Bootstrap $bootstrap
    Assert-True ($rendered -is [string]) 'Renderer returns one string'
    Assert-Equal ([Convert]::ToBase64String($trackedBytes)) ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($rendered))) 'Fresh projection equals tracked bytes'
    Assert-True (-not ($trackedBytes[0] -eq 239 -and $trackedBytes[1] -eq 187 -and $trackedBytes[2] -eq 191)) 'Index has no UTF-8 BOM'
    Assert-True (-not $rendered.Contains("`r")) 'Index uses LF'
    Assert-True ($rendered.EndsWith("`n") -and -not $rendered.EndsWith("`n`n")) 'Index has one final newline'
    $reversed = @($tools)
    [Array]::Reverse($reversed)
    Assert-Equal $rendered (Get-ToolsIndexContent -Tools $reversed -Bootstrap $bootstrap) 'Renderer sorts input by id'
    $index = $rendered | ConvertFrom-Json
    Assert-Equal 1 $index.schemaVersion 'Catalog schema version'
    Assert-Equal ($bootstrap.windows.download.zip | ConvertTo-Json -Depth 100 -Compress) ($index.bootstrap.windows.download.zip | ConvertTo-Json -Depth 100 -Compress) 'Bootstrap ZIP recipe preserves validation and integrity metadata'
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
        Copy-Item -LiteralPath (Join-Path $repoRoot 'tools/bootstrap.json') -Destination (Join-Path $copyRoot 'tools/bootstrap.json')
        Copy-Item -LiteralPath (Join-Path $repoRoot 'plugins/ps-ai') -Destination (Join-Path $copyRoot 'plugins/ps-ai') -Recurse
        $copyGenerator = Join-Path $copyRoot 'tools/update-tools-index.ps1'
        $copyIndex = Join-Path $copyRoot 'plugins/ps-ai/tools.json'
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

        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/tools/ps-ai-fourth') -Destination (Join-Path $copyRoot 'plugins/ps-ai/skills/ps-ai-fourth') -Recurse
        Assert-Throws { & $copyGenerator -Check } 'New tool makes the catalog stale'
        & $copyGenerator | Out-Null
        $extended = Get-Content -LiteralPath $copyIndex -Raw | ConvertFrom-Json
        Assert-Equal (@(Get-PsAiTools -SkillsRoot (Join-Path $copyRoot 'plugins/ps-ai/skills')).id -join '|') ($extended.tools.id -join '|') 'A fourth skill enters the index without shared edits'
        $fourthDescriptor = Get-Content (Join-Path $copyRoot 'plugins/ps-ai/skills/ps-ai-fourth/tool.json') -Raw | ConvertFrom-Json
        Assert-Equal $fourthDescriptor.command ($extended.tools | Where-Object id -CEQ $fourthDescriptor.id).command 'Fourth tool executable comes from its descriptor'
        & $copyGenerator -Check | Out-Null

        # A checkout on Windows must preserve the generated byte contract too.
        $attributes = Join-Path $repoRoot '.gitattributes'
        if (Test-Path -LiteralPath $attributes) { Copy-Item -LiteralPath $attributes -Destination $copyRoot }
        & git -C $copyRoot -c init.defaultBranch=fixture init --quiet
        $checkoutBytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($copyIndex))
        $checkoutFiles = @('plugins/ps-ai/tools.json')
        if (Test-Path -LiteralPath (Join-Path $copyRoot '.gitattributes')) { $checkoutFiles += '.gitattributes' }
        & git -C $copyRoot -c core.autocrlf=true -c core.safecrlf=false add -- @checkoutFiles 2>$null
        Assert-Equal 0 $LASTEXITCODE 'Fixture index is staged locally'
        Remove-Item -LiteralPath $copyIndex
        & git -C $copyRoot -c core.autocrlf=true checkout -- plugins/ps-ai/tools.json
        Assert-Equal 0 $LASTEXITCODE 'Fixture index checks out locally'
        Assert-Equal $checkoutBytes ([Convert]::ToBase64String([IO.File]::ReadAllBytes($copyIndex))) 'Checkout preserves LF index bytes with autocrlf enabled'
        & $copyGenerator -Check | Out-Null

        Remove-Item -LiteralPath (Join-Path $copyRoot 'tools/bootstrap.json')
        $beforeMissingTime = [IO.File]::GetLastWriteTimeUtc($copyIndex)
        Assert-Throws { & $copyGenerator } 'Missing PowerShell bootstrap recipe stops generation'
        Assert-Throws { & $copyGenerator -Check } 'Missing PowerShell bootstrap recipe also stops Check'
        Assert-Equal $checkoutBytes ([Convert]::ToBase64String([IO.File]::ReadAllBytes($copyIndex))) 'Invalid bootstrap source leaves catalog bytes intact'
        Assert-Equal $beforeMissingTime ([IO.File]::GetLastWriteTimeUtc($copyIndex)) 'Invalid bootstrap source leaves catalog mtime intact'
    } finally {
        $cleanupPath = [IO.Path]::GetFullPath($copyRoot)
        if (-not $cleanupPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup path' }
        Remove-Item -LiteralPath $cleanupPath -Recurse -Force
    }
}

# Descriptor boundaries must survive the real renderer and standalone JSON loader.
& {
    $repo = Split-Path $PSScriptRoot -Parent
    . (Join-Path $repo 'tools/update-tools-index.ps1') -NoRun
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    $schema = Join-Path $repo 'plugins/ps-ai/schemas/tool.schema.json'
    $descriptorJson = Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/ps-ai-fourth/tool.json') -Raw
    $bootstrap = Get-Content (Join-Path $repo 'tools/bootstrap.json') -Raw | ConvertFrom-Json
    $fields = @('marketplaceAdd', 'marketplaceRemove', 'install', 'marketplaceList', 'list', 'marketplaceUpdate', 'update')
    $scratchRoot = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp/restructure'))
    $scratch = Join-Path $scratchRoot ('catalog-boundaries-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $scratch 'plugins/ps-ai') -Force | Out-Null
    try {
        foreach ($boundary in @('empty-string-arguments', 'empty-arrays', 'empty-hook-status')) {
            $descriptor = $descriptorJson | ConvertFrom-Json
            switch ($boundary) {
                'empty-string-arguments' { foreach ($field in $fields) { $descriptor.plugin.$field = @('--namespace', '', ' ') } }
                'empty-arrays' { foreach ($field in $fields) { $descriptor.plugin.$field = @() } }
                'empty-hook-status' { $descriptor.hooks.status = '' }
            }
            Assert-True (Test-Json -Json ($descriptor | ConvertTo-Json -Depth 100) -SchemaFile $schema) "$boundary is schema valid"
            Get-ToolsIndexContent -Tools @($descriptor) -Bootstrap $bootstrap | Set-Content -LiteralPath (Join-Path $scratch 'plugins/ps-ai/tools.json')
            $loaded = Get-InstallCatalog -Source $scratch
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
                Get-ToolsIndexContent -Tools @($descriptor) -Bootstrap $bootstrap | Set-Content -LiteralPath (Join-Path $scratch 'plugins/ps-ai/tools.json')
                Assert-Throws { Get-InstallCatalog -Source $scratch } "Loader rejects invalid plugin.$field"
            }
        }
        foreach ($value in @($null, 42, @('status'))) {
            $descriptor = $descriptorJson | ConvertFrom-Json
            $descriptor.hooks.status = $value
            Assert-True (-not (Test-Json -Json ($descriptor | ConvertTo-Json -Depth 100) -SchemaFile $schema -ErrorAction SilentlyContinue)) 'Schema rejects non-string hooks.status'
            Get-ToolsIndexContent -Tools @($descriptor) -Bootstrap $bootstrap | Set-Content -LiteralPath (Join-Path $scratch 'plugins/ps-ai/tools.json')
            Assert-Throws { Get-InstallCatalog -Source $scratch } 'Loader rejects non-string hooks.status'
        }
    } finally {
        $cleanupPath = [IO.Path]::GetFullPath($scratch)
        if (-not $cleanupPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup path' }
        Remove-Item -LiteralPath $cleanupPath -Recurse -Force
    }
}

# CatalogLoadsBeforeBootstrapInBothRuntimes: bad metadata must stop before mutation.
& {
    $repo = Split-Path $PSScriptRoot -Parent
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    $fixtureText = Get-Content (Join-Path $PSScriptRoot 'fixtures/install/catalog.json') -Raw
    $catalog = $fixtureText | ConvertFrom-Json
    $state = @{ Reads=0; Bootstrap=0; Url='' }
    function Get-InstallSourceText { param($Url) $state.Reads++; $state.Url=$Url; return $fixtureText }
    function Ensure-InstallPowerShell { $state.Bootstrap++; return $true }
    Assert-Equal 3 @( (Get-InstallCatalog -Source 'example/market' -Catalog $catalog).tools ).Count 'Injected catalog is accepted'
    Assert-Equal 0 $state.Reads 'Injected catalog bypasses reads'
    foreach ($ref in @('release','main')) {
        $null = Get-InstallCatalog -Source 'example/market' -Ref $ref
        $branch = if ($ref -eq 'release') { 'stable' } else { 'main' }
        Assert-Equal "https://raw.githubusercontent.com/example/market/$branch/plugins/ps-ai/tools.json" $state.Url 'Remote ref selects the install branch'
    }
    $withString = $fixtureText | ConvertFrom-Json
    $withString.tools[0].plugin.install += '2026-11-18T00:00:00Z'
    $fixtureText = $withString | ConvertTo-Json -Depth 100
    Assert-Equal '2026-11-18T00:00:00Z' (Get-InstallCatalog -Source 'example/market').tools[0].plugin.install[-1] 'Remote JSON preserves date-looking argument as text'
    foreach ($source in @('https://example.test/repo','owner/repo/extra','missing-folder')) {
        Assert-Throws { Get-InstallCatalog -Source $source } 'Unsupported source stops'
    }
    $scratch = Join-Path $repo ('.agents/temp/restructure/catalog space-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory (Join-Path $scratch 'plugins/ps-ai') -Force | Out-Null
    try {
        Assert-Throws { Get-InstallCatalog -Source $scratch } 'Local missing index stops'
        $fixtureText | Set-Content (Join-Path $scratch 'plugins/ps-ai/tools.json')
        $before = $state.Reads
        Assert-Equal 3 @((Get-InstallCatalog -Source $scratch).tools).Count 'Local spaced source loads offline'
        Assert-Equal $before $state.Reads 'Local source never fetches'
        Assert-Equal '2026-11-18T00:00:00Z' (Get-InstallCatalog -Source $scratch).tools[0].plugin.install[-1] 'Local JSON preserves date-looking argument as text'
    } finally {
        if (-not ([IO.Path]::GetFullPath($scratch)).StartsWith([IO.Path]::GetFullPath((Join-Path $repo '.agents/temp/restructure')) + [IO.Path]::DirectorySeparatorChar)) { throw 'unsafe cleanup' }
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
    $invalid = @(
        '{', 'null', '{"schemaVersion":2}',
        $fixtureText.Replace('"tools": [','"tools": 1, "unused": ['),
        $fixtureText.Replace('"command": "claude"','"command": 12'),
        $fixtureText.Replace('"format": "json"','"format": ["json"]'),
        $fixtureText.Replace('"kind": "zip"','"kind": ["zip"]'),
        $fixtureText.Replace('"marketplaceAdd": [','"marketplaceAdd": "bad", "unused": ['),
        $fixtureText.Replace('"wingetId": "Microsoft.PowerShell"','"wingetId": false'),
        $fixtureText.Replace('"pathFolder": ""','"pathFolder": "../outside"'),
        $fixtureText.Replace('"metadataUrl": "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"','"metadataUrl": null'),
        $fixtureText.Replace('"id": "codex"','"id": "claude"')
    )
    foreach ($bad in $invalid) {
        $fixtureText = $bad
        Assert-Throws { Invoke-PsAiInstaller -Source 'example/market' -DryRun } 'Invalid catalog fails before bootstrap'
        Assert-Equal 0 $state.Bootstrap 'Invalid catalog never bootstraps'
    }
    foreach ($field in @('plugin','listing','bootstrap','windows')) {
        $bad = Get-Content (Join-Path $PSScriptRoot 'fixtures/install/catalog.json') -Raw | ConvertFrom-Json
        switch ($field) {
            plugin { $bad.tools[0].plugin = @($bad.tools[0].plugin) }
            listing { $bad.tools[0].plugin.listing = @($bad.tools[0].plugin.listing) }
            bootstrap { $bad.bootstrap = @($bad.bootstrap) }
            windows { $bad.bootstrap.windows = @($bad.bootstrap.windows) }
        }
        Assert-Throws { Get-InstallCatalog -Catalog $bad } 'Consumed object nodes cannot be arrays'
    }
    function Get-InstallSourceText { throw 'fixture metadata unavailable' }
    Assert-Throws { Invoke-PsAiInstaller -Source 'example/market' -DryRun } 'Fetch failure stops before bootstrap'
    Assert-Equal 0 $state.Bootstrap 'Fetch failure never bootstraps'
    $fixtureText = Get-Content (Join-Path $PSScriptRoot 'fixtures/install/catalog.json') -Raw
    function Get-InstallSourceText { param($Url) $state.Reads++; return $fixtureText }
    $before = $state.Reads
    function Test-InstallStepDone { $false }
    $null = Invoke-PsAiInstaller -Source 'example/market' -Tools claude -DryRun
    Assert-Equal ($before + 1) $state.Reads 'Dry run reads metadata exactly once'
    Assert-Equal 1 $state.Bootstrap 'Valid invocation reaches bootstrap once'
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    Assert-Equal ($before + 1) $state.Reads 'Dot source NoRun fetches nothing'
}
