$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$runner = Join-Path $root 'tests/integration/run.ps1'
$tempRoot = Join-Path $root ('.agents/temp/integration-runner-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$savedCi = $env:CI
$savedSummary = $env:GITHUB_STEP_SUMMARY
try {
    . $runner -NoRun

    # Each fake step gives a first and a repeat case with a time above zero.
    $fake = @(
        @{ Name = 'one'; DependsOn = @(); First = { Start-Sleep -Milliseconds 5 }; Repeat = { Start-Sleep -Milliseconds 5 } }
        @{ Name = 'two'; DependsOn = @('one'); First = { Start-Sleep -Milliseconds 5 }; Repeat = { Start-Sleep -Milliseconds 5 } }
    )
    $cases = @(Invoke-IntegrationSteps -Steps $fake)
    Assert-Equal 4 $cases.Count 'two cases per step'
    Assert-Equal 'one' $cases[0].Name 'first-run case name'
    Assert-Equal 'one (repeat)' $cases[1].Name 'repeat case name'
    Assert-True ((-not $cases[0].Repeat) -and $cases[1].Repeat) 'Repeat flag marks the second run'
    foreach ($case in $cases) {
        Assert-Equal 'passed' $case.Result "$($case.Name) passed"
        Assert-True ($case.Seconds -gt 0) "$($case.Name) has a time above zero"
    }

    # A throwing step fails; dependants skip without running; independent steps still run.
    $script:counter = 0
    $script:independent = 0
    $failing = @(
        @{ Name = 'bad'; DependsOn = @(); First = { throw 'boom' }; Repeat = { } }
        @{ Name = 'child'; DependsOn = @('bad'); First = { $script:counter++ }; Repeat = { $script:counter++ } }
        @{ Name = 'grandchild'; DependsOn = @('child'); First = { $script:counter++ }; Repeat = { $script:counter++ } }
        @{ Name = 'free'; DependsOn = @(); First = { $script:independent++ }; Repeat = { $script:independent++ } }
    )
    $cases = @(Invoke-IntegrationSteps -Steps $failing)
    $byName = @{}
    foreach ($case in $cases) { $byName[$case.Name] = $case }
    Assert-Equal 'failed' $byName['bad'].Result 'throwing step fails'
    Assert-True ($byName['bad'].Message -like '*boom*') 'failure keeps the message'
    Assert-Equal 'skipped' $byName['child'].Result 'dependant is skipped'
    Assert-Equal 'needs bad' $byName['child'].Message 'dependant says what it needs'
    Assert-Equal 'skipped' $byName['child (repeat)'].Result 'dependant repeat is skipped'
    Assert-Equal 'skipped' $byName['grandchild'].Result 'second-level dependant is skipped'
    Assert-Equal 'needs child' $byName['grandchild'].Message 'second-level dependant names its direct parent'
    Assert-Equal 0 $script:counter 'dependant blocks never run'
    Assert-Equal 2 $script:independent 'independent step still ran both times'
    Assert-Equal 'passed' $byName['free'].Result 'independent step passed'

    # A step that returns Skipped is skipped with that message; its dependants skip too.
    $script:counter = 0
    $skipping = @(
        @{ Name = 'codex'; DependsOn = @(); First = { @{ Skipped = 'codex refuses a local folder' } }; Repeat = { $script:counter++ } }
        @{ Name = 'after'; DependsOn = @('codex'); First = { $script:counter++ }; Repeat = { $script:counter++ } }
    )
    $cases = @(Invoke-IntegrationSteps -Steps $skipping)
    Assert-Equal 'skipped' $cases[0].Result 'returned Skipped is skipped'
    Assert-Equal 'codex refuses a local folder' $cases[0].Message 'skip keeps its reason'
    Assert-Equal 'skipped' $cases[1].Result 'its repeat is skipped too'
    Assert-Equal 'needs codex' $cases[2].Message 'dependant of a skipped step says needs'
    Assert-Equal 0 $script:counter 'no block ran after a skip'

    # Step output goes to a log file when a log folder is given.
    $logs = Join-Path $tempRoot 'logs'
    $logged = @(@{ Name = 'talk'; DependsOn = @(); First = { 'hello log' }; Repeat = { 'again' } })
    Invoke-IntegrationSteps -Steps $logged -LogFolder $logs | Out-Null
    Assert-True ((Get-Content -LiteralPath (Join-Path $logs 'talk.log') -Raw) -like '*hello log*') 'step output is logged'

    # The probe never adds a case and never fails, even when it throws.
    $probe = (Get-IntegrationProbe -Checks ([ordered]@{ good = { 'v1' }; bad = { throw 'no such tool' } })) -join "`n"
    Assert-True ($probe -like '*good*v1*') 'probe records a version'
    Assert-True ($probe -like '*bad*not found*') 'probe records a missing tool without throwing'
    Assert-Equal 0 @(Invoke-IntegrationSteps -Steps @()).Count 'no steps, no cases'

    # The report: XML, benchmark JSON and summary.md; summary appended to GITHUB_STEP_SUMMARY.
    $out = Join-Path $tempRoot 'results'
    $env:GITHUB_STEP_SUMMARY = Join-Path $tempRoot 'step-summary.md'
    $reportCases = @(
        [pscustomobject]@{ Name = 'setup'; Seconds = 4.21; Result = 'passed'; Message = ''; Repeat = $false }
        [pscustomobject]@{ Name = 'setup (repeat)'; Seconds = 0.62; Result = 'passed'; Message = ''; Repeat = $true }
        [pscustomobject]@{ Name = 'add'; Seconds = 1.5; Result = 'failed'; Message = 'boom'; Repeat = $false }
        [pscustomobject]@{ Name = 'add (repeat)'; Seconds = 0; Result = 'skipped'; Message = 'needs add'; Repeat = $true }
    )
    Write-IntegrationReport -Out $out -Os 'linux' -Cases $reportCases -Probe @('winget: not found') -Extra 'claude 2.1.0'
    $xml = [xml](Get-Content -LiteralPath (Join-Path $out 'integration-linux.xml') -Raw)
    Assert-Equal 'integration.linux' $xml.testsuite.name 'suite name'
    Assert-Equal '4' $xml.testsuite.tests 'four test cases'
    Assert-Equal 'integration.linux' $xml.testsuite.testcase[0].classname 'class name'
    $bench = @(ConvertFrom-Json (Get-Content -LiteralPath (Join-Path $out 'integration-bench-linux.json') -Raw))
    Assert-Equal 2 $bench.Count 'only passed cases in the benchmark'
    Assert-Equal 'linux / setup' $bench[0].name 'benchmark name'
    Assert-Equal 'claude 2.1.0' $bench[0].extra 'extra on the first-run row'
    $summary = Get-Content -LiteralPath (Join-Path $out 'summary.md') -Raw
    Assert-True ($summary -like '*winget: not found*') 'summary has the probe'
    Assert-True ($summary -like '*| step | first s | repeat s | result |*') 'summary has the table header'
    Assert-True ($summary -like '*| setup | 4.210 | 0.620 | passed |*') 'summary row for a passed step'
    Assert-True ($summary -like '*| add | 1.500 | 0.000 | failed |*') 'summary row for a failed step'
    Assert-True ((Get-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Raw) -like '*| setup | 4.210*') 'summary appended to GITHUB_STEP_SUMMARY'

    # Tree hash: same for an unchanged folder, different after a change.
    $tree = Join-Path $tempRoot 'tree'
    New-Item -ItemType Directory -Path (Join-Path $tree 'sub') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tree 'sub/a.txt') -Value 'one'
    $before = Get-TreeHash -Path $tree
    Assert-Equal $before (Get-TreeHash -Path $tree) 'unchanged folder hashes the same'
    Set-Content -LiteralPath (Join-Path $tree 'sub/a.txt') -Value 'two'
    Assert-True ($before -ne (Get-TreeHash -Path $tree)) 'a changed file changes the hash'
    Set-Content -LiteralPath (Join-Path $tree 'sub/a.txt') -Value 'one'
    Rename-Item -LiteralPath (Join-Path $tree 'sub/a.txt') -NewName 'b.txt'
    Assert-True ($before -ne (Get-TreeHash -Path $tree)) 'a renamed file changes the hash'

    # Without -NoRun and without CI=true the script stops before any step.
    $env:CI = ''
    $refusedOut = Join-Path $tempRoot 'refused'
    $text = (& pwsh -NoProfile -File $runner -Out $refusedOut -HomeRoot (Join-Path $tempRoot 'home') 2>&1 | Out-String)
    Assert-True ($LASTEXITCODE -ne 0) 'a local run exits non-zero'
    Assert-True ($text -like '*CI*') 'the refusal mentions CI'
    Assert-True (-not (Test-Path -LiteralPath $refusedOut)) 'a refused run writes nothing'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $tempRoot 'home'))) 'a refused run does not create the home'

    # The real steps exist in the spec's order and depend on what they need (never run here).
    $steps = @(Get-IntegrationSteps -HomeRoot (Join-Path $tempRoot 'home') -Checkout $root -Work (Join-Path $tempRoot 'work') -Os 'linux')
    Assert-Equal 'install-cli-claude,install-cli-codex,install-cli-copilot,install-ps-ai,setup,add,remove,repo-private,repo-shared,uninstall' (($steps.Name) -join ',') 'step order'
    Assert-True ($steps.Where({ $_.Name -eq 'setup' }).DependsOn -contains 'install-ps-ai') 'setup needs install-ps-ai'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $tempRoot 'home'))) 'building the steps touches nothing'
} finally {
    $env:CI = $savedCi
    $env:GITHUB_STEP_SUMMARY = $savedSummary
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
