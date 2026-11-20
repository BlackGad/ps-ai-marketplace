. (Join-Path $repo 'install.ps1') -NoRun
. (Join-Path $PSScriptRoot 'MarketplaceListing.ps1')
$catalog = Get-InstallCatalog -Source $repo
$sandbox = Join-Path $repo ('.agents/temp/uninstall-clean-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
$state = @{ Only=''; Plugin=$true; Marketplace=$true; FailRemove=$false; KeepListed=$false; FailVerify=$false; Answer='n'; Prompts=0 }
$writes = [Collections.Generic.List[string]]::new()
$calls = [Collections.Generic.List[string]]::new()
. (Join-Path $PSScriptRoot 'InstallerSandbox.ps1') -InstallFixtureHome ($sandbox)
function Ensure-InstallPowerShell { throw 'Uninstall must not install prerequisites' }
function Read-Host { $state.Prompts++; $state.Answer }
function Invoke-ClosedInput {
    param([string[]]$Command)
    $line = $Command -join '|'
    $calls.Add($line)
    $entry = $catalog.tools | Where-Object command -CEQ $Command[0]
    if ($line -ceq ((@($entry.command) + $entry.plugin.list) -join '|')) {
        if ($state.FailVerify -and $writes.Count) { return @{ExitCode=7;Output=@()} }
        # Only: when set, just that tool has ps-ai installed, so the others are not survivors.
        $installed = $state.Plugin -and (-not $state.Only -or $state.Only -ceq $entry.id)
        $output = if ($entry.plugin.listing.format -eq 'json') {
            if ($installed) { '[{"id":"ps-ai@ps-ai-marketplace","enabled":false}]' } else { '[]' }
        } elseif ($installed) { 'ps-ai@ps-ai-marketplace installed (disabled)' } else { '' }
        return @{ExitCode=0;Output=@($output)}
    }
    if ($line -ceq ((@($entry.command) + $entry.plugin.marketplaceList) -join '|')) {
        $source = if ($state.Marketplace) { 'example/marketplace' } else { '' }
        return @{ExitCode=0;Output=@(Get-FixtureMarketplaceListing -Tool $entry.id -Source $source)}
    }
    if ($state.FailRemove) { return @{ExitCode=8;Output=@()} }
    if ($line -ceq ((@($entry.command) + $entry.plugin.uninstall) -join '|')) {
        if (-not $state.KeepListed) { $state.Plugin=$false }
    } elseif ($line -ceq ((@($entry.command) + $entry.plugin.marketplaceRemove) -join '|')) {
        $state.Marketplace=$false
    } else { throw "Unexpected fake command: $line" }
    $writes.Add($line)
    return @{ExitCode=0;Output=@()}
}
function New-FixtureCache {
    param([string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    'keep or remove with cache' | Set-Content -LiteralPath (Join-Path $Path 'fixture.txt')
}
function Remove-UninstallSandbox {
    $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
    if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe uninstall fixture cleanup' }
    Remove-Item -LiteralPath $sandbox -Recurse -Force
}
