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

$runner = Join-Path $PSScriptRoot 'ps-ai-overseer.ps1'
foreach ($name in @('ps-ai-overseer', 'ps-ai-overseer.cmd')) {
    $path = Get-PsAiHomePath -HomeRoot $HomeRoot -Path "bin/$name"
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $text = [IO.File]::ReadAllText($path)
    # Retarget the generated quoted -File argument, preserving the owner's other shim flags.
    $pattern = '(-File\s+)(["''][^\r\n]*?[/\\]bin[/\\]ps-ai-overseer\.ps1["''])'
    $updated = [regex]::Replace($text, $pattern, [Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $target = if ($name.EndsWith('.cmd')) { '"' + $runner.Replace('%', '%%') + '"' } else { ConvertTo-PsAiShellLiteral $runner }
        $match.Groups[1].Value + $target
    })
    Write-PsAiGeneratedFile -Path $path -Content $updated -Changes $changes
}
if ($changes.Count) { 'ps-ai generated runtimes and launchers refreshed' }
else { 'skip: ps-ai generated runtimes and launchers (already done)' }
