param([string]$HomeRoot = $HOME)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ps-ai-account.ps1') -NoRun -HomeRoot $HomeRoot
$changes = [Collections.Generic.List[string]]::new()
$file = Get-PsAiHomePath -HomeRoot $HomeRoot -Path 'configuration/ps-ai-personalisation.json'
if (Test-Path -LiteralPath $file) {
    $owner = Read-PsAiJson -Path $file
    foreach ($agent in $owner.agents) {
        if ($agent.provider.kind -cne 'foundry') { continue }
        $wrapper = Get-PsAiWrapperCommand $agent.id $HomeRoot
        if (-not (Test-PsAiOwnedWrapper $wrapper $agent.id)) { continue }
        New-FoundryWrappers -Id $agent.id -Tool $agent.tool -HomeRoot $HomeRoot -Changes $changes
    }
}

foreach ($entry in (Get-PsAiOwnerCommands).GetEnumerator()) {
    $runner = Join-Path $PSScriptRoot $entry.Value
    foreach ($suffix in @('', '.cmd')) {
        $path = Get-PsAiHomePath -HomeRoot $HomeRoot -Path "bin/$($entry.Key)$suffix"
        if (-not (Test-PsAiOwnerCommandFile -Path $path -Script $entry.Value)) { continue }
        $text = [IO.File]::ReadAllText($path)
        $updated = Update-PsAiOwnerCommandText -Text $text -Script $entry.Value -Runner $runner -Windows:([bool]$suffix)
        Write-PsAiGeneratedFile -Path $path -Content $updated -Changes $changes
    }
}
if ($changes.Count) { 'ps-ai generated runtimes and launchers refreshed' }
else { 'skip: ps-ai generated runtimes and launchers (already done)' }
