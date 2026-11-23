# A stand-in for `uv run --project <app> ... legion [--home <home>] <words>`: the Python CLI forwards the
# PowerShell verbs to the app's bin/legion.ps1 with -HomeRoot, so this runs it the same way.
$project = $args[[array]::IndexOf($args, '--project') + 1]
$words = @($args | Select-Object -Skip ([array]::IndexOf($args, 'legion') + 1))
$homeRoot = @()
if ($words.Count -ge 2 -and $words[0] -ceq '--home') {
    $homeRoot = @('-HomeRoot', $words[1])
    $words = @($words | Select-Object -Skip 2)
}
& pwsh -NoProfile -File (Join-Path $project 'bin/legion.ps1') @words @homeRoot
exit $LASTEXITCODE
