$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/workflows.ps1')

$sha = 'a' * 40
$temp = Join-Path ([IO.Path]::GetTempPath()) "ps-ai-workflows-$([guid]::NewGuid().ToString('N'))"
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

    $ids = @(Get-WorkflowJobIds -Path $local)
    Assert-Equal 'call,build' ($ids -join ',') 'job ids in order'
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
        if ($file.Name -ne 'tests.yml') { Assert-True ('gate' -notin $jobIds) "$($file.Name) must not have a job named gate" }
        if ($file.Name -ne 'tests.yml') { Assert-True ('gate' -notin $jobNames) "$($file.Name) must not display a check named gate" }
        if ($file.Name -ne 'integration.yml') { Assert-True ('integration' -notin $jobIds) "$($file.Name) must not have a job named integration" }
        if ($file.Name -ne 'integration.yml') { Assert-True ('integration' -notin $jobNames) "$($file.Name) must not display a check named integration" }
    }
    $tests = $files | Where-Object Name -eq 'tests.yml'
    if ($tests) { Assert-True ('gate' -in @(Get-WorkflowJobIds -Path $tests.FullName)) 'tests.yml has job gate' }
    $integration = $files | Where-Object Name -eq 'integration.yml'
    if ($integration) {
        $integrationGate = Get-WorkflowJobBlocks -Path $integration.FullName | Where-Object Id -eq 'integration'
        Assert-True ($null -ne $integrationGate) 'integration.yml has job integration'
        Assert-Equal 'integration' $integrationGate.Name 'integration job displays the required check name'
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
        if ($text -match '(?m)^      [\w-]+: write\s*$') {
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
    Require-Workflow ($mark -match 'needs: \[resolve-release-pr, test-release-pr\]' -and $mark.Contains('SHA: ${{ needs.resolve-release-pr.outputs.sha }}')) 'status publisher uses the same trusted sha even when checkout fails'
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
    Assert-Equal 0 $workflowProblems.Count ($workflowProblems -join '; ')
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
