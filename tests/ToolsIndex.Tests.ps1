# IndexProjectionIsDeterministicAndWriteFree: the standalone catalog is generated data.
& {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $generator = Join-Path $repoRoot 'tools/update-tools-index.ps1'
    $indexPath = Join-Path $repoRoot 'tools.json'
    Assert-True (Test-Path -LiteralPath $generator) 'Tools index generator exists'
    Assert-True (Test-Path -LiteralPath $indexPath) 'Generated tools index exists'
    $trackedBytes = [IO.File]::ReadAllBytes($indexPath)
    $trackedTime = [IO.File]::GetLastWriteTimeUtc($indexPath)
    $noRunOutput = @(. $generator -NoRun)
    Assert-Equal 0 $noRunOutput.Count 'NoRun only defines functions'
    Assert-Equal $trackedTime ([IO.File]::GetLastWriteTimeUtc($indexPath)) 'NoRun does not write the index'

    $tools = @(Get-PsAiTools)
    $recipes = Get-PsAiInstallRecipes
    $rendered = Get-ToolsIndexContent -Tools $tools -Bootstrap $recipes.pwsh
    Assert-True ($rendered -is [string]) 'Renderer returns one string'
    Assert-Equal ([Convert]::ToBase64String($trackedBytes)) ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($rendered))) 'Fresh projection equals tracked bytes'
    Assert-True (-not ($trackedBytes[0] -eq 239 -and $trackedBytes[1] -eq 187 -and $trackedBytes[2] -eq 191)) 'Index has no UTF-8 BOM'
    Assert-True (-not $rendered.Contains("`r")) 'Index uses LF'
    Assert-True ($rendered.EndsWith("`n") -and -not $rendered.EndsWith("`n`n")) 'Index has one final newline'
    $reversed = @($tools)
    [Array]::Reverse($reversed)
    Assert-Equal $rendered (Get-ToolsIndexContent -Tools $reversed -Bootstrap $recipes.pwsh) 'Renderer sorts input by id'
    $index = $rendered | ConvertFrom-Json
    Assert-Equal 'schemaVersion|bootstrap|tools' ($index.PSObject.Properties.Name -join '|') 'Catalog has only ordered projection fields'
    Assert-Equal 1 $index.schemaVersion 'Catalog schema version'
    Assert-Equal ($recipes.pwsh | ConvertTo-Json -Depth 100 -Compress) ($index.bootstrap | ConvertTo-Json -Depth 100 -Compress) 'Bootstrap is the complete PowerShell helper recipe'
    Assert-Equal (($tools.id | Sort-Object -CaseSensitive) -join '|') ($index.tools.id -join '|') 'Catalog tools are sorted'
    foreach ($entry in $index.tools) {
        $source = $tools | Where-Object id -CEQ $entry.id
        Assert-Equal 'id|command|configEnv|plugin|hooks|installHint' ($entry.PSObject.Properties.Name -join '|') 'Tool projection has exactly the public fields'
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
        Copy-Item -LiteralPath (Join-Path $repoRoot 'plugins/ps-ai') -Destination (Join-Path $copyRoot 'plugins/ps-ai') -Recurse
        $copyGenerator = Join-Path $copyRoot 'tools/update-tools-index.ps1'
        $copyIndex = Join-Path $copyRoot 'tools.json'
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
        Assert-Equal ((@(Get-PsAiTools -SkillsRoot (Join-Path $copyRoot 'plugins/ps-ai/skills')).id | Sort-Object -CaseSensitive) -join '|') ($extended.tools.id -join '|') 'A fourth skill enters the index without shared edits'
        $fourthDescriptor = Get-Content (Join-Path $copyRoot 'plugins/ps-ai/skills/ps-ai-fourth/tool.json') -Raw | ConvertFrom-Json
        Assert-Equal $fourthDescriptor.command ($extended.tools | Where-Object id -CEQ $fourthDescriptor.id).command 'Fourth tool executable comes from its descriptor'
        & $copyGenerator -Check | Out-Null

        # A checkout on Windows must preserve the generated byte contract too.
        $attributes = Join-Path $repoRoot '.gitattributes'
        if (Test-Path -LiteralPath $attributes) { Copy-Item -LiteralPath $attributes -Destination $copyRoot }
        & git -C $copyRoot -c init.defaultBranch=fixture init --quiet
        $checkoutBytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($copyIndex))
        $checkoutFiles = @('tools.json')
        if (Test-Path -LiteralPath (Join-Path $copyRoot '.gitattributes')) { $checkoutFiles += '.gitattributes' }
        & git -C $copyRoot -c core.autocrlf=true -c core.safecrlf=false add -- @checkoutFiles 2>$null
        Assert-Equal 0 $LASTEXITCODE 'Fixture index is staged locally'
        Remove-Item -LiteralPath $copyIndex
        & git -C $copyRoot -c core.autocrlf=true checkout -- tools.json
        Assert-Equal 0 $LASTEXITCODE 'Fixture index checks out locally'
        Assert-Equal $checkoutBytes ([Convert]::ToBase64String([IO.File]::ReadAllBytes($copyIndex))) 'Checkout preserves LF index bytes with autocrlf enabled'
        & $copyGenerator -Check | Out-Null

        $copyHelpers = Join-Path $copyRoot 'plugins/ps-ai/bin/install-tool/helpers.json'
        $helperData = Get-Content -LiteralPath $copyHelpers -Raw | ConvertFrom-Json -AsHashtable
        $helperData.Remove('pwsh')
        $helperData | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $copyHelpers
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
