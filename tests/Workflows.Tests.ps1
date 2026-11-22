$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/workflows.ps1')

$sha = 'a' * 40
$temp = Join-Path ([IO.Path]::GetTempPath()) "legion-workflows-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $temp | Out-Null

function New-Workflow {
    param([string]$Name, [string]$Uses = "actions/checkout@$sha  # v5.0.0", [string]$Permissions = "permissions: {}`n", [string]$Timeout = '    timeout-minutes: 5')
    $text = @"
name: fixture
on: push
${Permissions}jobs:
  build:
    runs-on: ubuntu-24.04
$Timeout
    steps:
      - uses: $Uses
      - run: echo hi
"@
    $path = Join-Path $temp "$Name.yml"
    Set-Content -LiteralPath $path -Value $text
    $path
}

try {
    Assert-Equal 0 @(Get-WorkflowProblems -Path (New-Workflow 'clean')).Count 'clean workflow has no problems'

    $local = Join-Path $temp 'local.yml'
    Set-Content -LiteralPath $local -Value @"
permissions: {}
jobs:
  call:
    uses: ./.github/workflows/tests.yml
  build:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - uses: ./local-action
"@
    Assert-Equal 0 @(Get-WorkflowProblems -Path $local).Count 'local uses and reusable job call are fine'

    $badUses = @(
        'actions/checkout@v5',
        'actions/checkout@main',
        "actions/checkout@$('a' * 39)  # v5.0.0",
        "actions/checkout@$sha",
        'docker://alpine:3.20'
    )
    $index = 0
    foreach ($value in $badUses) {
        $index++
        $problems = @(Get-WorkflowProblems -Path (New-Workflow "bad$index" -Uses $value))
        Assert-Equal 1 $problems.Count "unpinned '$value' flagged once"
        Assert-True ($problems[0] -like "uses '*' is not pinned") "message for '$value'"
    }

    $jobLevel = Join-Path $temp 'jobperm.yml'
    Set-Content -LiteralPath $jobLevel -Value @"
jobs:
  build:
    permissions: {}
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - run: echo hi
"@
    Assert-Equal 'no top-level permissions' (@(Get-WorkflowProblems -Path $jobLevel)[0]) 'job-level permissions do not count'
    Assert-Equal 1 @(Get-WorkflowProblems -Path (New-Workflow 'noperm' -Permissions '')).Count 'missing permissions flagged'

    $noTimeout = @(Get-WorkflowProblems -Path (New-Workflow 'notimeout' -Timeout ''))
    Assert-Equal 1 $noTimeout.Count 'missing timeout flagged'
    Assert-Equal "job 'build' has no timeout-minutes" $noTimeout[0] 'timeout message'

    Assert-Equal 'call,build' (@(Get-WorkflowJobIds -Path $local) -join ',') 'job ids in order'
    Assert-Equal 'call,build' ((Get-WorkflowJobBlocks -Path $local).Name -join ',') 'displayed names default to job ids'

    $named = Join-Path $temp 'named.yml'
    Set-Content -LiteralPath $named -Value @'
permissions: {}
jobs:
  build:
    name: 'gate'
    timeout-minutes: 5
    steps:
      - run: echo hi
  gate:
    name: another check
    timeout-minutes: 5
    steps:
      - name: step name must not replace the job name
        run: echo hi
'@
    Assert-Equal 'build,gate' ((Get-WorkflowJobBlocks -Path $named).Id -join ',') 'displayed names do not change job ids'
    Assert-Equal 'gate,another check' ((Get-WorkflowJobBlocks -Path $named).Name -join ',') 'displayed names include quoted names and ignore step names'

    $workflowFolder = Join-Path $root '.github/workflows'
    $files = @()
    if (Test-Path -LiteralPath $workflowFolder) { $files = @(Get-ChildItem $workflowFolder -Filter '*.yml') }
    foreach ($file in $files) {
        $problems = @(Get-WorkflowProblems -Path $file.FullName)
        Assert-Equal 0 $problems.Count "$($file.Name): $($problems -join '; ')"
        $jobIds = @(Get-WorkflowJobIds -Path $file.FullName)
        $jobNames = @((Get-WorkflowJobBlocks -Path $file.FullName).Name)
        # A required check name belongs to one workflow file only.
        foreach ($reserved in @{ gate = 'tests.yml'; integration = 'integration.yml' }.GetEnumerator()) {
            if ($file.Name -eq $reserved.Value) { continue }
            Assert-True ($reserved.Key -notin $jobIds) "$($file.Name) must not have a job named $($reserved.Key)"
            Assert-True ($reserved.Key -notin $jobNames) "$($file.Name) must not display a check named $($reserved.Key)"
        }
    }
    $tests = $files | Where-Object Name -eq 'tests.yml'
    if ($tests) { Assert-True ('gate' -in @(Get-WorkflowJobIds -Path $tests.FullName)) 'tests.yml has job gate' }
    $integration = $files | Where-Object Name -eq 'integration.yml'
    if ($integration) {
        $integrationGate = Get-WorkflowJobBlocks -Path $integration.FullName | Where-Object Id -eq 'integration'
        Assert-True ($null -ne $integrationGate) 'integration.yml has job integration'
        Assert-True ($integrationGate.Name -like "*'integration'*") 'integration job preserves the required check name for ordinary PRs'
    }

    # Collect the security contract failures so a regression shows every broken boundary.
    $workflowProblems = [Collections.Generic.List[string]]::new()
    function Require-Workflow {
        param([bool]$Condition, [string]$Message)
        if (-not $Condition) { $workflowProblems.Add($Message) }
    }

    $testPath = Join-Path $workflowFolder 'tests.yml'
    $releasePath = Join-Path $workflowFolder 'release.yml'
    $testText = Get-Content -LiteralPath $testPath -Raw
    $releaseText = Get-Content -LiteralPath $releasePath -Raw
    $testJobs = @(Get-WorkflowJobBlocks -Path $testPath)
    $releaseJobs = @(Get-WorkflowJobBlocks -Path $releasePath)
    Require-Workflow ($testText -notmatch '(?m)^\s+\w[\w-]*:\s*write\s*$') 'reusable tests must request no write permissions, even on skipped jobs'
    $report = ($testJobs | Where-Object Id -eq 'report').Lines -join "`n"
    Require-Workflow ($report -match '(?m)^          annotate_only: true\s*$') 'reusable JUnit reporting must use read-only annotation mode'
    foreach ($job in @($testJobs) + @($releaseJobs)) {
        $text = $job.Lines -join "`n"
        if ($text -match '(?m)^      [\w-]+: write\s*$' -and $job.Id -ne 'integration-release-pr') {
            Require-Workflow ($text -notmatch 'uses: (actions/checkout@|\./)|(?:-File|\. )\s*(?:\./)?(?:tests|plugins)/') "privileged job '$($job.Id)' must not check out or execute repository scripts"
        }
    }

    Require-Workflow ($testText -match '(?m)^    inputs:\r?\n      sha:\s*$') 'reusable tests accept a sha input'
    Require-Workflow ($testText -notmatch 'inputs\.ref') 'reusable tests must not resolve a moving ref input'
    $checkouts = @($testText -split "`n" | Where-Object { $_ -match 'uses: actions/checkout@' })
    $pinnedRefs = @($testText -split "`n" | Where-Object { $_.Trim() -eq 'ref: ${{ inputs.sha || github.sha }}' })
    Require-Workflow ($checkouts.Count -eq 2 -and $pinnedRefs.Count -eq $checkouts.Count) 'every test checkout uses the supplied sha or the triggering commit'
    $resolve = $releaseJobs | Where-Object Id -eq 'resolve-release-pr'
    $resolveText = $resolve.Lines -join "`n"
    Require-Workflow ($null -ne $resolve) 'release PR head is resolved in a trusted job before testing'
    Require-Workflow ($resolveText.Contains('PR_NUMBER: ${{ fromJSON(needs.release-please.outputs.pr).number }}')) 'trusted resolution uses the action output PR number'
    Require-Workflow ($resolveText -match 'gh api "repos/\$env:REPOSITORY/pulls/\$env:PR_NUMBER"') 'trusted resolution reads the PR through the API'
    Require-Workflow ($resolveText -match '\$pr\.state -ne ''open''' -and $resolveText -match '\$pr\.head\.sha' -and $resolveText.Contains("'^[0-9a-f]{40}$'")) 'trusted resolution validates the open PR and its full head sha'
    Require-Workflow ($resolveText.Contains('sha: ${{ steps.head.outputs.sha }}')) 'trusted job exposes the resolved head sha'
    Require-Workflow ($resolveText -notmatch 'actions/checkout@') 'trusted head resolution never checks out PR code'
    $call = ($releaseJobs | Where-Object Id -eq 'test-release-pr').Lines -join "`n"
    Require-Workflow ($call -match 'needs: resolve-release-pr' -and $call.Contains('sha: ${{ needs.resolve-release-pr.outputs.sha }}')) 'release tests depend on and use the resolved head sha'
    Require-Workflow ($releaseText -notmatch 'headBranchName|needs\.test-release-pr\.outputs\.sha') 'release tests and statuses never derive the revision from a branch or matrix output'
    $mark = ($releaseJobs | Where-Object Id -eq 'mark-release-pr').Lines -join "`n"
    Require-Workflow ($mark -match 'needs: \[resolve-release-pr, test-release-pr, integration-release-pr\]' -and $mark.Contains('SHA: ${{ needs.resolve-release-pr.outputs.sha }}')) 'status publisher uses the same trusted sha even when checkout fails'
    Require-Workflow ($mark -match 'if: always\(\) && needs\.resolve-release-pr\.result != ''skipped''' -and $mark.Contains("'^[0-9a-f]{40}$'") -and $mark -match 'missing or invalid release PR head SHA') 'status publisher fails clearly when trusted sha resolution fails'
    Require-Workflow ($mark -match 'statuses/\$env:SHA' -and $mark -match 'context=gate' -and $mark -match "RESULT -eq 'success'" -and $mark -match "else \{ 'failure' \}") 'trusted publisher marks success or failure on the resolved head with context gate'

    $gate = $testJobs | Where-Object Id -eq 'gate'
    $gateName = @'
${{ (inputs.sha != '' || (github.event_name == 'pull_request' && github.event.pull_request.user.login == 'github-actions[bot]' && startsWith(github.head_ref, 'release-please--'))) && 'release PR tests' || 'gate' }}
'@
    Require-Workflow ($gate.Name -ceq $gateName) 'gate displays exactly gate for ordinary PRs and a separate name for bot release PRs and reusable calls'
    foreach ($job in $testJobs | Where-Object Id -ne 'gate') {
        Require-Workflow ($job.Name -notin 'gate', 'integration') "job '$($job.Id)' must not display a reserved required check name"
    }

    $integrationPath = Join-Path $workflowFolder 'integration.yml'
    Require-Workflow (Test-Path -LiteralPath $integrationPath) 'integration workflow exists'
    if (Test-Path -LiteralPath $integrationPath) {
        $integrationText = Get-Content -LiteralPath $integrationPath -Raw
        $integrationJobs = @(Get-WorkflowJobBlocks -Path $integrationPath)
        $writers = @($integrationJobs | Where-Object { ($_.Lines -join "`n") -match '(?m)^      contents: write\s*$' })
        Require-Workflow ($writers.Count -eq 1 -and $writers[0].Id -eq 'save-trend') 'only save-trend may write contents'
        foreach ($job in $integrationJobs | Where-Object Id -ne 'save-trend') {
            Require-Workflow (($job.Lines -join "`n") -notmatch '(?m)^      [\w-]+: write\s*$') "integration job '$($job.Id)' is read-only"
        }
        $save = ($integrationJobs | Where-Object Id -eq 'save-trend').Lines -join "`n"
        $saveCondition = "needs.run.result == 'success' && needs.report.result == 'success' && needs.report.outputs.complete == 'true' && (github.event_name == 'push' || github.event_name == 'schedule') && github.ref == 'refs/heads/main' && inputs.sha == ''"
        Require-Workflow ($save.Contains("if: $saveCondition")) 'saving requires a complete successful matrix and a direct push or schedule on main with no checkout input'
        Require-Workflow ($save -match 'needs: \[run, report\]') 'save-trend depends on both matrix and reporting'
        Require-Workflow ($save -match 'group: integration-main-writer' -and $save -match 'queue: max' -and $save -match 'cancel-in-progress: false') 'main writers serialize without evicting pending saves'
        Require-Workflow ($integrationText.Contains('group: integration-${{ github.event_name }}-${{ inputs.sha || github.ref }}')) 'weekly concurrency is separate from pushes and release calls'
        Require-Workflow ($integrationText.Contains('queue: ${{ github.event_name == ''pull_request'' && ''single'' || ''max'' }}')) 'non-PR workflow runs retain pending runs'
        Require-Workflow ($integrationText -match 'types: \[opened, synchronize, reopened\]' -and $integrationText -match "cron: '0 3 \* \* 1'" -and $integrationText -match 'workflow_dispatch:' -and $integrationText -match 'workflow_call:') 'integration has PR, weekly, dispatch and reusable triggers'
        $run = ($integrationJobs | Where-Object Id -eq 'run').Lines -join "`n"
        Require-Workflow ($run -match 'os: \[windows-2025, macos-15, ubuntu-24.04\]' -and $run -match 'fail-fast: false' -and $run -match 'timeout-minutes: 30') 'integration matrix uses all three systems with independent timeouts'
        Require-Workflow ($run.Contains('ref: ${{ inputs.sha || github.sha }}')) 'matrix tests the supplied immutable SHA'
        Require-Workflow ($run.Contains('ALLOW_SOURCE_FALLBACK: ${{ github.event_name == ''push'' && github.ref == ''refs/heads/main'' && inputs.sha == '''' }}')) 'published-source fallback is allowed only on direct main pushes without a checkout input'
        Require-Workflow ($run -match "if: github.event_name == 'pull_request'\r?\n        uses: actions/cache/restore@" -and $run -match "if: github.event_name == 'schedule' && github.ref == 'refs/heads/main' && inputs.sha == ''\r?\n        uses: actions/cache/save@") 'npm downloads restore only on PRs and save only on the weekly main run'
        Require-Workflow ($run -match 'if: always\(\)' -and $run -match 'retention-days: 90') 'matrix preserves reports and logs for 90 days even on failure'
        $report = ($integrationJobs | Where-Object Id -eq 'report').Lines -join "`n"
        Require-Workflow ($report -match 'if: always\(\)' -and $report -match 'annotate_only: true') 'report runs after failures without check-writing permissions'
        Require-Workflow ($report -match "'windows', 'macos', 'linux'" -and $report -match 'missing integration timing file' -and $report -match 'Merge-BenchmarkFiles -Path \$paths -OutFile' -and $report -match 'complete=true') 'merger validates every OS result before exposing complete timings'
        foreach ($option in @('auto-push: false', 'save-data-file: false', 'comment-on-alert: false', 'summary-always: true', "alert-threshold: '200%'", 'fail-on-alert: false')) {
            Require-Workflow ($report.Contains($option)) "compare-only reporting sets $option"
        }
        foreach ($option in @('auto-push: true', 'save-data-file: true', 'comment-on-alert: true', "alert-threshold: '200%'", 'fail-on-alert: false')) {
            Require-Workflow ($save.Contains($option)) "main trend sets $option"
        }
        Require-Workflow ($report -match 'ls-remote --exit-code --heads origin refs/heads/gh-pages' -and $report -match 'No timing baseline yet') 'comparison handles the first run before gh-pages exists'
        Require-Workflow ($save -match 'uses: actions/checkout@' -and $save.Contains('ref: ${{ github.sha }}') -and $save -notmatch 'inputs.sha \|\| github.sha|(?:-File|\. )\s*(?:\./)?(?:tests|plugins)/') 'publisher has a trusted checkout and never runs PR scripts'
        Require-Workflow ($save -match 'ls-remote --exit-code --heads origin refs/heads/gh-pages' -and $save -match 'git commit-tree' -and $save -match 'git push origin .*refs/heads/gh-pages') 'publisher bootstraps gh-pages idempotently without replacing the source checkout'
        Require-Workflow ($save -match 'pages: write' -and $save -match 'gh api --method POST "repos/\$env:REPOSITORY/pages/builds"') 'publisher explicitly requests a Pages build after saving'
        $integrationGate = $integrationJobs | Where-Object Id -eq 'integration'
        $integrationName = $gateName.Replace('release PR tests', 'release PR integration').Replace("|| 'gate'", "|| 'integration'")
        Require-Workflow ($integrationGate.Name -ceq $integrationName) 'ordinary PRs display integration and bot release PRs reserve the required status context'
        Require-Workflow (($integrationGate.Lines -join "`n") -match 'needs: run' -and ($integrationGate.Lines -join "`n") -match "RUN_RESULT -ne 'success'") 'integration gate fails when the matrix fails or is cancelled'
        $integrationCall = ($releaseJobs | Where-Object Id -eq 'integration-release-pr').Lines -join "`n"
        Require-Workflow ($integrationCall -match 'needs: resolve-release-pr' -and $integrationCall.Contains('sha: ${{ needs.resolve-release-pr.outputs.sha }}') -and $integrationCall -match 'uses: \./.github/workflows/integration.yml') 'release integration uses the same trusted resolved head SHA'
        Require-Workflow ($integrationCall -match 'contents: write' -and $integrationCall -match 'pages: write' -and $integrationCall -notmatch 'steps:|runs-on:') 'release caller grants only the callee permission ceiling and cannot execute code itself'
        Require-Workflow ($mark -match 'context=integration' -and $mark.Contains('INTEGRATION_RESULT: ${{ needs.integration-release-pr.result }}') -and $mark -match "INTEGRATION_RESULT -eq 'success'") 'trusted status publisher reports the integration result independently on the resolved SHA'
        # Expressions in env values are data. No event, input or artifact text belongs in shell source.
        $inRun = $false
        foreach ($line in $integrationText -split "`n") {
            if ($line -match '^        run: \|') { $inRun = $true; continue }
            if ($inRun -and $line -match '^\S|^ {0,9}\S') { $inRun = $false }
            if ($inRun) { Require-Workflow ($line -notmatch '\$\{\{') 'integration shell source must use env values instead of expression substitution' }
        }

        $scripts = @([regex]::Matches($integrationText, '(?m)^        run: \|\r?\n(?<body>(?:^          [^\r\n]*(?:\r?\n|$)|^\r?\n)*)') | ForEach-Object {
            $_.Groups['body'].Value -replace '(?m)^          ', ''
        })
        foreach ($script in $scripts) {
            $parseErrors = $null
            [Management.Automation.Language.Parser]::ParseInput($script, [ref]$null, [ref]$parseErrors) | Out-Null
            Require-Workflow ($parseErrors.Count -eq 0) 'inline integration PowerShell parses cleanly'
        }
        # Exercise the actual merger step, including incomplete artifacts after a timeout.
        $mergeScript = $scripts | Where-Object { $_ -match 'Merge-BenchmarkFiles' }
        Assert-True ($null -ne $mergeScript) 'workflow contains a merger script to exercise'
        $benchmarkLib = (Join-Path $PSScriptRoot 'lib/benchmark.ps1').Replace("'", "''")
        $mergeScript = $mergeScript.Replace('. ./tests/lib/benchmark.ps1', ". '$benchmarkLib'")
        foreach ($count in 3, 2, 0) {
            $fixture = Join-Path $temp "timings-$count"
            New-Item -ItemType Directory -Path (Join-Path $fixture 'results') | Out-Null
            foreach ($os in @('windows', 'macos', 'linux') | Select-Object -First $count) {
                $folder = Join-Path $fixture "results/integration-$os"
                New-Item -ItemType Directory -Path $folder | Out-Null
                # Shell-looking artifact text must stay JSON data.
                '[{"name":"$(throw artifact-text)","unit":"s","value":1}]' | Set-Content (Join-Path $folder "integration-bench-$os.json")
            }
            $fixtureLiteral = $fixture.Replace("'", "''")
            $scriptPath = Join-Path $fixture 'merge.ps1'
            Set-Content -LiteralPath $scriptPath -Value @"
`$ErrorActionPreference = 'Stop'
Set-Location '$fixtureLiteral'
`$env:GITHUB_OUTPUT = Join-Path `$PWD 'output.txt'
`$env:GITHUB_STEP_SUMMARY = Join-Path `$PWD 'summary.md'
$mergeScript
"@
            & pwsh -NoProfile -File $scriptPath | Out-Null
            Assert-Equal 0 $LASTEXITCODE "merging $count OS artifacts exits cleanly"
            Assert-Equal ($count -eq 3) (Test-Path (Join-Path $fixture 'output.txt')) "only all three OS artifacts mark timings complete ($count present)"
            if ($count -gt 0) {
                $entries = @(Get-Content (Join-Path $fixture 'integration-bench.json') -Raw | ConvertFrom-Json)
                Assert-Equal $count $entries.Count "merger keeps all $count available OS results"
                Assert-Equal '$(throw artifact-text)' $entries[0].name 'artifact text remains data'
            } else {
                Assert-True (-not (Test-Path (Join-Path $fixture 'integration-bench.json'))) 'zero OS results produce no benchmark artifact'
            }
        }
    }
    Assert-Equal 0 $workflowProblems.Count ($workflowProblems -join '; ')
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
