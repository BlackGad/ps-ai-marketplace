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
        # Retarget only the quoted script path, preserving the owner's other shim flags.
        $start = $text.IndexOf('-File') + 5
        while ([char]::IsWhiteSpace($text[$start])) { $start++ }
        $quote = $text[$start]
        if ($quote -notin @([char]'"', [char]"'")) { continue }
        $end = $text.IndexOf($entry.Value + $quote, $start, [StringComparison]::Ordinal)
        if ($end -lt 0) { continue }
        $end += $entry.Value.Length + 1
        $target = if ($suffix) { '"' + $runner.Replace('%', '%%') + '"' } else { ConvertTo-PsAiShellLiteral $runner }
        $updated = $text.Substring(0, $start) + $target + $text.Substring($end)
        Write-PsAiGeneratedFile -Path $path -Content $updated -Changes $changes
    }
}
if ($changes.Count) { 'ps-ai generated runtimes and launchers refreshed' }
else { 'skip: ps-ai generated runtimes and launchers (already done)' }
