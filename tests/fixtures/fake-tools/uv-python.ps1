# Run the installed app's production Python CLI while keeping uv itself fake.
$project = $args[[array]::IndexOf($args, '--project') + 1]
$words = @($args | Select-Object -Skip ([array]::IndexOf($args, 'legion') + 1))
$env:PYTHONPATH = Join-Path $project 'src'
& $env:LEGION_TEST_PYTHON -c 'from legion._cli import main; main()' @words
exit $LASTEXITCODE
