$root = Split-Path $PSScriptRoot -Parent
$configPath = Join-Path $root 'release-please-config.json'
$manifestPath = Join-Path $root '.release-please-manifest.json'
Assert-True (Test-Path -LiteralPath $configPath) 'release-please-config.json exists'
Assert-True (Test-Path -LiteralPath $manifestPath) '.release-please-manifest.json exists'
$config = Get-Content -Raw $configPath | ConvertFrom-Json
$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
$package = $config.packages.'.'
Assert-Equal 'simple' $package.'release-type' 'Release type'
Assert-Equal $false $package.'include-component-in-tag' 'Tag has no component'

$expectedPaths = @(
    'plugins/ps-ai/.claude-plugin/plugin.json'
    'plugins/ps-ai/.codex-plugin/plugin.json'
    'plugins/ps-ai/plugin.json'
)
$extraFiles = @($package.'extra-files')
Assert-Equal 3 $extraFiles.Count 'Extra file count'
Assert-Equal ($expectedPaths -join ',') (($extraFiles.path | Sort-Object) -join ',') 'Extra file paths'
foreach ($file in $extraFiles) {
    Assert-Equal 'json' $file.type "Extra file type $($file.path)"
    Assert-Equal '$.version' $file.jsonpath "Extra file jsonpath $($file.path)"
    $plugin = Get-Content -Raw (Join-Path $root $file.path) | ConvertFrom-Json
    Assert-Equal $plugin.version $manifest.'.' "Manifest version matches $($file.path)"
}

# The stable branch moves to each release: checkout-free, fast-forward only, created on the first release.
. (Join-Path $PSScriptRoot 'lib/workflows.ps1')
$releasePath = Join-Path $root '.github/workflows/release.yml'
$releaseText = Get-Content -Raw $releasePath
$stable = (Get-WorkflowJobBlocks -Path $releasePath | Where-Object Id -eq 'stable').Lines -join "`n"
Assert-True ($stable -ne '') 'StableJob exists'
Assert-True ($stable -match '(?m)^    needs: release-please\s*$') 'StableJob needs release-please'
Assert-True ($stable.Contains("if: needs.release-please.outputs.release_created == 'true'")) 'StableJob runs only for a created release'
Assert-True ($stable -match '(?m)^    permissions:\r?\n      contents: write\r?\n(?!      )') 'StableJob has contents: write only'
Assert-True ($stable -match '(?m)^    timeout-minutes:') 'StableJob has a timeout'
Assert-True ($stable -notmatch 'actions/checkout|(?:-File|\. )\s*(?:\./)?(?:tests|plugins)/') 'StableJob has no checkout and no repository script'
Assert-True ($releaseText.Contains('sha: ${{ steps.release.outputs.sha }}')) 'release-please exposes the released commit'
Assert-True ($stable.Contains('SHA: ${{ needs.release-please.outputs.sha }}') -and $stable.Contains("'^[0-9a-f]{40}$'")) 'StableJob validates the released SHA from env'
Assert-True ($stable.Contains('refs/heads/stable') -and $stable.Contains('force=false')) 'StableJob updates stable without force'
Assert-True ($stable.Contains('git/refs')) 'StableJob creates the ref when it is missing'
Assert-True ($stable -notmatch '--force|force=true|CHANGELOG|version') 'StableJob never forces, versions or edits the changelog'
