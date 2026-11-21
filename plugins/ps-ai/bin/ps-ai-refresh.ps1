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
        $state = Get-PsAiOwnerCommandState -Path $path -Script $entry.Value
        if ($state -eq 'blocked') { continue }
        if ($state -eq 'missing') {
            if ($suffix -and -not $IsWindows) { continue }
            $updated = Get-PsAiShimText -Script $runner -Windows:([bool]$suffix) -HomeRoot $HomeRoot
        } else {
            $text = [IO.File]::ReadAllText($path)
            $updated = Update-PsAiOwnerCommandText -Text $text -Script $entry.Value -Runner $runner -Windows:([bool]$suffix) -HomeRoot $HomeRoot
        }
        Write-PsAiGeneratedFile -Path $path -Content $updated -Changes $changes -Executable:($suffix -eq '')
    }
}
if ($changes.Count) { 'ps-ai generated runtimes and launchers refreshed' }
else { 'skip: ps-ai generated runtimes and launchers (already done)' }
