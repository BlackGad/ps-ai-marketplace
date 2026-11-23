param([string]$HomeRoot = $HOME)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/accounts.ps1')
$changes = [Collections.Generic.List[string]]::new()
$file = Get-LegionOwnerPath -HomeRoot $HomeRoot -Name Settings
if (Test-Path -LiteralPath $file) {
    $owner = Read-LegionJson -Path $file
    foreach ($agent in $owner.agents) {
        if (-not $agent.provider) {
            if (-not (Test-LegionLauncherMissing -Id $agent.id -HomeRoot $HomeRoot)) { continue }
            $folder = Resolve-LegionHomePath -Path $agent.configDir -HomeRoot $HomeRoot
            $target = Get-LegionWrapperTarget -Id $agent.id -Tool $agent.tool -HomeRoot $HomeRoot -ConfigDir $folder
            if (-not $target) { "skip: account $($agent.id) (CLI target not found or launcher needs repair)"; continue }
            New-LegionWrappers -Id $agent.id -Tool $agent.tool -HomeRoot $HomeRoot -ConfigDir $folder -RealCommand $target -Changes $changes
            continue
        }
        if ($agent.provider.kind -cne 'foundry') { continue }
        $wrapper = Get-LegionWrapperCommand $agent.id $HomeRoot
        if (-not (Test-LegionOwnedWrapper $wrapper $agent.id)) { continue }
        New-FoundryWrappers -Id $agent.id -Tool $agent.tool -HomeRoot $HomeRoot -Changes $changes
    }
}

Publish-LegionApp -HomeRoot $HomeRoot -Changes $changes
if ($changes.Count) { 'legion generated runtimes and launchers refreshed' }
else { 'skip: legion generated runtimes and launchers (already done)' }
