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
                $release = @($release | Sort-Object { [version]$_.tag_name.TrimStart('v') } -Descending)[0]
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
