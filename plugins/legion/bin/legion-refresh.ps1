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
            $folder = $agent.configDir
            if ($folder -match '^~[/\\]') { $folder = Join-Path $HomeRoot $folder.Substring(2) }
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

foreach ($entry in (Get-LegionOwnerCommands).GetEnumerator()) {
    $runner = Join-Path $PSScriptRoot $entry.Value
    foreach ($suffix in @('', '.cmd')) {
        $path = Get-LegionHomePath -HomeRoot $HomeRoot -Path "bin/$($entry.Key)$suffix"
        $state = Get-LegionOwnerCommandState -Path $path -Script $entry.Value
        if ($state -eq 'blocked') { continue }
        if ($state -eq 'missing') {
            if ($suffix -and -not $IsWindows) { continue }
            $updated = Get-LegionShimText -Script $runner -Windows:([bool]$suffix) -HomeRoot $HomeRoot
        } else {
            $text = [IO.File]::ReadAllText($path)
            $updated = Update-LegionOwnerCommandText -Text $text -Script $entry.Value -Runner $runner -Windows:([bool]$suffix) -HomeRoot $HomeRoot
        }
        Write-LegionGeneratedFile -Path $path -Content $updated -Changes $changes -Executable:($suffix -eq '')
    }
}
if ($changes.Count) { 'legion generated runtimes and launchers refreshed' }
else { 'skip: legion generated runtimes and launchers (already done)' }
