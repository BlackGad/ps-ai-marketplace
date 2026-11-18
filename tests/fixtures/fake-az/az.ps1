$keyArgs = [System.Collections.Generic.List[string]]::new()
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -in @('-o', '--output', '--query')) { $i++; continue }
    $keyArgs.Add([string]$args[$i])
}
$key = $keyArgs -join ' '
Add-Content -LiteralPath $env:PS_AI_FAKE_AZ_LOG -Value $key
$answers = Get-Content -LiteralPath $env:PS_AI_FAKE_AZ -Raw | ConvertFrom-Json -AsHashtable
if (-not $answers.ContainsKey($key)) {
    Write-Error "fake az: no answer for $key" -ErrorAction Continue
    exit 1
}
$answer = $answers[$key]
if ($answer.stdout) { Write-Output $answer.stdout }
exit ([int]$answer.exit)
