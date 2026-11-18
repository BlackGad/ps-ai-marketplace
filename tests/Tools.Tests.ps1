$repoRoot = Split-Path $PSScriptRoot -Parent
$schemaPath = Join-Path $repoRoot 'plugins/ps-ai/schemas/tool.schema.json'
$skillsRoot = Join-Path $repoRoot 'plugins/ps-ai/skills'
$helpersPath = Join-Path $repoRoot 'plugins/ps-ai/bin/install-tool/helpers.json'

# DescriptorAndHelperSchema: malformed data must fail before any consumer acts.
Assert-True (Test-Path -LiteralPath $schemaPath) 'Tool descriptor schema exists'
$toolSchema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json -AsHashtable
function Test-DescriptorSchema {
    param($Data)
    Test-Json -Json ($Data | ConvertTo-Json -Depth 100) -SchemaFile $schemaPath -ErrorAction SilentlyContinue
}
foreach ($id in @('claude', 'codex', 'copilot')) {
    $descriptor = Get-Content -LiteralPath (Join-Path $skillsRoot "ps-ai-$id/tool.json") -Raw | ConvertFrom-Json -AsHashtable
    Assert-True (Test-DescriptorSchema $descriptor) "$id complete descriptor validates"
}
$fourthPath = Join-Path $PSScriptRoot 'fixtures/tools/ps-ai-fourth/tool.json'
$fourthJson = Get-Content -LiteralPath $fourthPath -Raw
Assert-True (Test-DescriptorSchema ($fourthJson | ConvertFrom-Json -AsHashtable)) 'Fourth tool validates without schema edits'
foreach ($mutation in @(
    { param($d) $d.Remove('command') },
    { param($d) $d.extra = 'unexpected' },
    { param($d) $d.schemaVersion = 2 },
    { param($d) $d.id = '../fourth' },
    { param($d) $d.id = 'Fourth' },
    { param($d) $d.configEnv = 'fourth-home' },
    { param($d) $d.foundry.aliases = @('alpha', 'alpha') },
    { param($d) $d.foundry.extra = 'unexpected' },
    { param($d) $d.plugin.listing.format = 'yaml' },
    { param($d) $d.plugin.listing.enabledField = 'enabled' },
    { param($d) $d.install.check = @() },
    { param($d) $d.install.windows.download.zip.kind = 'script' },
    { param($d) $d.install.windows.download.zip.verification = 'vendor' },
    { param($d) $d.install.windows.download.zip.Remove('pathFolder') },
    { param($d) $d.install.windows.download.zip.resolver = 'unknown' },
    { param($d) $d.install.windows.portableCommand = '../fourth.exe' },
    { param($d) $d.install.windows.download.zip.pathFolder = '/outside' },
    { param($d) $d.install.linux.commands = @(, @()) }
)) {
    $bad = $fourthJson | ConvertFrom-Json -AsHashtable
    $null = & $mutation $bad
    Assert-True (-not (Test-DescriptorSchema $bad)) 'Invalid descriptor rejected'
}
$noFoundry = $fourthJson | ConvertFrom-Json -AsHashtable
$noFoundry.foundry = $null
Assert-True (Test-DescriptorSchema $noFoundry) 'Null Foundry capability is supported'

# The helper map uses the same install definition, including checksum requirements.
$installSchema = @{
    '$schema' = $toolSchema.'$schema'
    '$defs' = $toolSchema.'$defs'
    '$ref' = '#/$defs/install'
} | ConvertTo-Json -Depth 100
$helpers = Get-Content -LiteralPath $helpersPath -Raw | ConvertFrom-Json -AsHashtable
Assert-Equal 'az|gh|git|glab|node|pwsh' (($helpers.Keys | Sort-Object) -join '|') 'Helpers have no agent descriptors'
. (Join-Path $repoRoot 'plugins/ps-ai/bin/ps-ai-install-tool.ps1') -NoRun
foreach ($id in $helpers.Keys) {
    $recipe = $helpers[$id]
    Assert-True (Test-Json -Json ($recipe | ConvertTo-Json -Depth 100) -Schema $installSchema -ErrorAction SilentlyContinue) "$id helper validates"
    foreach ($platform in @('macos', 'linux')) {
        $old = Get-ToolRecipe -Tool $id -Platform $platform
        Assert-Equal ($old.Check -join '|') ($recipe.check -join '|') "$id check preserved"
        Assert-Equal ($old.Install | ConvertTo-Json -Depth 20 -Compress -AsArray) ($recipe[$platform].commands | ConvertTo-Json -Depth 20 -Compress -AsArray) "$id $platform commands preserved"
        Assert-Equal $old.Docs $recipe[$platform].docs "$id $platform docs preserved"
    }
}
foreach ($id in @('node', 'glab')) {
    $badRecipe = $helpers[$id] | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
    $download = $badRecipe.windows.download.zip
    $download.Remove($(if ($id -eq 'node') { 'checksumUrl' } else { 'checksumAsset' }))
    Assert-True (-not (Test-Json -Json ($badRecipe | ConvertTo-Json -Depth 100) -Schema $installSchema -ErrorAction SilentlyContinue)) "$id checksum metadata is required"
}
$badRecipe = $helpers.pwsh | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
$badRecipe.windows.download.msi.releasesUrl = 'https://fixture.test/releases?page=1'
Assert-True (-not (Test-Json -Json ($badRecipe | ConvertTo-Json -Depth 100) -Schema $installSchema -ErrorAction SilentlyContinue)) 'Paginated recipes require the page placeholder'

# Resolve migrated metadata against the existing offline source fixtures.
$sources = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixtures/install/sources.json') -Raw | ConvertFrom-Json -AsHashtable
foreach ($id in $helpers.Keys) {
    foreach ($method in @('msi', 'zip')) {
        $download = $helpers[$id].windows.download[$method]
        if ($download.resolver -eq 'lts-index') {
            $version = @($sources[$download.metadataUrl] | Where-Object lts)[0].version
            Assert-Equal 'v28.1.0' $version 'Node selects first LTS, retaining leading v'
            Assert-True ($download.checksumUrl.Contains('{version}')) 'Node checksum follows selected version'
        } else {
            $url = if ($download.releasesUrl) { $download.releasesUrl.Replace('{page}', '1') } else { $download.metadataUrl }
            Assert-True ($sources.Contains($url)) "$id $method metadata URL preserved"
            $release = $sources[$url]
            if ($download.releasesUrl) {
                Assert-Equal '^v7\.6\.\d+$' $download.tagPattern 'PowerShell MSI stays on stable 7.6'
                Assert-True $download.stableOnly 'PowerShell excludes prereleases and drafts'
                Assert-Equal 'version-desc' $download.order 'PowerShell selects newest matching version'
                $release = @($sources[$download.releasesUrl.Replace('{page}', '2')] | Where-Object tag_name -CEQ 'v7.6.9')[0]
                Assert-Equal 'v7.6.9' $release.tag_name 'PowerShell MSI fixture selection'
            }
            $assets = if ($download.resolver -eq 'release-links') { $release.assets.links } else { $release.assets }
            Assert-Equal 1 @($assets | Where-Object name -Match $download.assetPattern).Count "$id $method pattern selects asset"
        }
    }
}
Assert-Equal 'ADD_PATH=1' $helpers.pwsh.windows.download.msi.arguments[2] 'PowerShell MSI keeps PATH argument'
Assert-Equal '/VERYSILENT|/NORESTART|/SP-|/CURRENTUSER' ($helpers.git.windows.download.msi.arguments -join '|') 'Git installer flags preserved'
Assert-Equal '/VERYSILENT|/SUPPRESSMSGBOXES|/NORESTART|/SP-' ($helpers.glab.windows.download.msi.arguments -join '|') 'glab installer flags preserved'

# DiscoverFourthAndRejectInvalidNeighbors: folder additions need no shared id list.
$toolsModule = Join-Path $repoRoot 'plugins/ps-ai/bin/PsAi.Tools.ps1'
Assert-True (Test-Path -LiteralPath $toolsModule) 'Tool discovery module exists'
. $toolsModule
$builtIns = @(Get-PsAiTools)
Assert-Equal 'claude|codex|copilot' ($builtIns.id -join '|') 'Default discovery is sorted by id'
foreach ($discoveredTool in $builtIns) {
    Assert-True ([IO.Path]::IsPathFullyQualified($discoveredTool.SkillRoot)) 'Runtime SkillRoot is absolute'
    Assert-Equal (Join-Path $discoveredTool.SkillRoot 'scripts/foundry-launch.ps1') (Get-PsAiToolScript -Tool $discoveredTool -Name foundry-launch) 'Launch lookup follows the skill convention'
    Assert-True (-not (Get-Content -LiteralPath (Join-Path $discoveredTool.SkillRoot 'tool.json') -Raw).Contains('SkillRoot')) 'Runtime data is not written into descriptors'
}
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot '.agents/temp/restructure'))
$discoveryRoot = Join-Path $scratchRoot ('discovery-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $discoveryRoot -Force | Out-Null
function New-TestToolSkill {
    param([string]$Name = 'ps-ai-fourth', [scriptblock]$Change = {})
    $folder = Join-Path $discoveryRoot $Name
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/tools/ps-ai-fourth') -Destination $folder -Recurse
    $data = $fourthJson | ConvertFrom-Json -AsHashtable
    $null = & $Change $data
    $data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $folder 'tool.json')
    return $folder
}
try {
    $folder = New-TestToolSkill
    New-Item -ItemType Directory -Path (Join-Path $discoveryRoot 'ps-ai-shared'), (Join-Path $discoveryRoot 'nested') -Force | Out-Null
    Copy-Item -LiteralPath $folder -Destination (Join-Path $discoveryRoot 'nested/ps-ai-hidden') -Recurse
    Copy-Item -LiteralPath $folder -Destination (Join-Path $discoveryRoot 'unrelated') -Recurse
    Assert-Equal 'fourth' (@(Get-PsAiTools -SkillsRoot $discoveryRoot).id -join '|') 'Only direct ps-ai descriptors are discovered'
    $fourth = Get-PsAiTool -Tool fourth -SkillsRoot $discoveryRoot
    Assert-Equal $null (Get-PsAiToolScript -Tool $fourth -Name foundry-config) 'Missing optional config adapter returns null'
    Assert-Equal 'fourth-cli' $fourth.command 'Tool id does not dictate executable'
    Assert-Equal 'model[1]' $fourth.foundry.deploymentPrefix 'Deployment prefix remains literal data'
    Assert-Equal '--interactive|space value' ($fourth.overseerArgs -join '|') 'Argument boundaries are preserved'
    foreach ($id in @('absent', '../fourth')) {
        $message = ''
        try { Get-PsAiTool -Tool $id -SkillsRoot $discoveryRoot | Out-Null } catch { $message = $_.Exception.Message }
        Assert-Equal "unknown tool '$id'" $message 'Unknown and traversal ids stop with exact diagnostic'
    }
    $added = New-TestToolSkill -Name ps-ai-added -Change { param($d) $d.id = 'added' }
    Assert-Equal 'added|fourth' (@(Get-PsAiTools -SkillsRoot $discoveryRoot).id -join '|') 'Fresh discovery sees additions'
    Move-Item -LiteralPath $added -Destination (Join-Path $discoveryRoot 'removed')
    Assert-Equal 'fourth' (@(Get-PsAiTools -SkillsRoot $discoveryRoot).id -join '|') 'Fresh discovery sees removals'

    $first = New-TestToolSkill -Name ps-ai-aaa -Change { param($d) $d.id = 'aaa' }
    $cultureBefore = [cultureinfo]::CurrentCulture
    try {
        foreach ($cultureName in @('en-US', 'da-DK')) {
            [cultureinfo]::CurrentCulture = [cultureinfo]::GetCultureInfo($cultureName)
            Assert-Equal 'aaa|fourth' (@(Get-PsAiTools -SkillsRoot $discoveryRoot).id -join '|') 'Discovery order is ordinal across cultures'
            # Both neighbors mismatch; the first diagnostic must also be stable.
            $badData = $fourthJson | ConvertFrom-Json -AsHashtable
            $badData.id = 'zzz'
            $badData | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $first 'tool.json')
            $badData.id = 'other'
            $badData | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $folder 'tool.json')
            $message = ''
            try { Get-PsAiTools -SkillsRoot $discoveryRoot | Out-Null } catch { $message = $_.Exception.Message }
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
        { param($d) $d.install.windows.download.zip.assetPattern = '[' }
    )) {
        $data = $original | ConvertFrom-Json -AsHashtable
        $null = & $change $data
        $data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $folder 'tool.json')
        Assert-Throws { Get-PsAiTools -SkillsRoot $discoveryRoot | Out-Null } 'Invalid neighboring descriptor stops discovery'
    }
    '{invalid' | Set-Content -LiteralPath (Join-Path $folder 'tool.json')
    Assert-Throws { Get-PsAiTool -Tool absent -SkillsRoot $discoveryRoot | Out-Null } 'Malformed neighbors cannot be hidden by a lookup'
    Set-Content -LiteralPath (Join-Path $folder 'tool.json') -Value $original
    foreach ($requiredFile in @('SKILL.md', 'scripts/foundry-launch.ps1')) {
        $path = Join-Path $folder $requiredFile
        Move-Item -LiteralPath $path -Destination ($path + '.held')
        Assert-Throws { Get-PsAiTools -SkillsRoot $discoveryRoot | Out-Null } 'Missing skill/capability script stops discovery'
        Move-Item -LiteralPath ($path + '.held') -Destination $path
    }
    $duplicate = New-TestToolSkill -Name ps-ai-duplicate
    $message = ''
    try { Get-PsAiTools -SkillsRoot $discoveryRoot | Out-Null } catch { $message = $_.Exception.Message }
    Assert-True ($message.Contains("duplicate tool id 'fourth'")) 'Duplicate diagnostic wins over directory mismatch'
    Move-Item -LiteralPath $duplicate -Destination (Join-Path $discoveryRoot 'duplicate-disabled')

    $data = $original | ConvertFrom-Json -AsHashtable
    $data.foundry = $null
    $data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $folder 'tool.json')
    Move-Item -LiteralPath (Join-Path $folder 'scripts/foundry-launch.ps1') -Destination (Join-Path $folder 'scripts/foundry-launch.held')
    $fourth = Get-PsAiTool -Tool fourth -SkillsRoot $discoveryRoot
    Assert-Throws { Get-PsAiToolScript -Tool $fourth -Name foundry-launch | Out-Null } 'Null capability rejects launch resolution'
    Assert-Throws { Get-PsAiToolScript -Tool $fourth -Name foundry-config | Out-Null } 'Null capability rejects config resolution'
    Set-Content -LiteralPath (Join-Path $folder 'tool.json') -Value $original
    Move-Item -LiteralPath (Join-Path $folder 'scripts/foundry-launch.held') -Destination (Join-Path $folder 'scripts/foundry-launch.ps1')
    $recipes = Get-PsAiInstallRecipes -SkillsRoot $discoveryRoot
    Assert-True ($recipes -is [hashtable]) 'Install recipes return one hashtable'
    Assert-Equal 'az|fourth|gh|git|glab|node|pwsh' (($recipes.Keys | Sort-Object) -join '|') 'Recipes combine helper and agent installs'
    Assert-Equal 'fourth-cli|--version' ($recipes.fourth.check -join '|') 'Fourth install recipe is exposed'
    Copy-Item -LiteralPath $helpersPath -Destination (Join-Path $discoveryRoot 'relative-helpers.json')
    Push-Location -LiteralPath $discoveryRoot
    try {
        $relativeError = ''
        try { $relativeRecipes = Get-PsAiInstallRecipes -SkillsRoot $discoveryRoot -HelpersPath './relative-helpers.json' }
        catch { $relativeError = $_.Exception.Message }
        Assert-Equal '' $relativeError 'Relative HelpersPath resolves without a read error'
        Assert-Equal 'az|fourth|gh|git|glab|node|pwsh' (($relativeRecipes.Keys | Sort-Object) -join '|') 'Relative HelpersPath uses the PowerShell current location'
    } finally { Pop-Location }
    $dateArgument = '2026-11-18T18:30:00+00:00'
    $dateData = $original | ConvertFrom-Json -AsHashtable
    $dateData.overseerArgs = @($dateArgument)
    $dateData.install.linux.commands = @(, @('fourth-cli', $dateArgument))
    $dateData | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $folder 'tool.json')
    $dateTool = Get-PsAiTool -Tool fourth -SkillsRoot $discoveryRoot
    Assert-True ($dateTool.overseerArgs[0] -is [string]) 'Descriptor date-like arguments remain strings'
    Assert-Equal $dateArgument $dateTool.overseerArgs[0] 'Descriptor date-like argument text is unchanged'
    Assert-Equal $dateArgument $dateTool.install.linux.commands[0][1] 'Nested command date-like text is unchanged'
    Set-Content -LiteralPath (Join-Path $folder 'tool.json') -Value $original
    $badHelpers = Get-Content -LiteralPath $helpersPath -Raw | ConvertFrom-Json -AsHashtable
    $badHelpers.fourth = $recipes.fourth
    $testHelpers = Join-Path $discoveryRoot 'helpers.json'
    $badHelpers | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $testHelpers
    Assert-Throws { Get-PsAiInstallRecipes -SkillsRoot $discoveryRoot -HelpersPath $testHelpers | Out-Null } 'Helper/agent collision rejected'
    $badHelpers.Remove('fourth')
    $validHelpers = $badHelpers | ConvertTo-Json -Depth 100
    foreach ($field in @('assetPattern', 'tagPattern')) {
        $badHelpers = $validHelpers | ConvertFrom-Json -AsHashtable
        $badHelpers.pwsh.windows.download.msi[$field] = '['
        $badHelpers | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $testHelpers
        Assert-Throws { Get-PsAiInstallRecipes -SkillsRoot $discoveryRoot -HelpersPath $testHelpers | Out-Null } 'Invalid helper regex rejected'
    }
    $badHelpers = $validHelpers | ConvertFrom-Json -AsHashtable
    $badHelpers.node.check = @('node', $dateArgument)
    $badHelpers | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $testHelpers
    $dateRecipes = Get-PsAiInstallRecipes -SkillsRoot $discoveryRoot -HelpersPath $testHelpers
    Assert-True ($dateRecipes.node.check[1] -is [string]) 'Helper date-like arguments remain strings'
    Assert-Equal $dateArgument $dateRecipes.node.check[1] 'Helper date-like argument text is unchanged'
    $badHelpers = $validHelpers | ConvertFrom-Json -AsHashtable
    $badHelpers.node.windows.download.zip.Remove('checksumUrl')
    $badHelpers | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $testHelpers
    Assert-Throws { Get-PsAiInstallRecipes -SkillsRoot $discoveryRoot -HelpersPath $testHelpers | Out-Null } 'Malformed helper recipe rejected'

    # A minimal relocated runtime must discover without an installer helper map.
    $runtime = Join-Path $discoveryRoot 'runtime'
    New-Item -ItemType Directory -Path (Join-Path $runtime 'bin'), (Join-Path $runtime 'schemas'), (Join-Path $runtime 'skills') -Force | Out-Null
    Copy-Item -LiteralPath $toolsModule -Destination (Join-Path $runtime 'bin/PsAi.Tools.ps1')
    Copy-Item -LiteralPath $schemaPath -Destination (Join-Path $runtime 'schemas/tool.schema.json')
    Copy-Item -LiteralPath $folder -Destination (Join-Path $runtime 'skills/ps-ai-fourth') -Recurse
    & {
        . (Join-Path $runtime 'bin/PsAi.Tools.ps1')
        Assert-Equal 'fourth' (@(Get-PsAiTools).id -join '|') 'Relocated discovery never reads helpers eagerly'
    }
} finally {
    $cleanupPath = [IO.Path]::GetFullPath($discoveryRoot)
    if (-not $cleanupPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup path' }
    Remove-Item -LiteralPath $cleanupPath -Recurse -Force
}
