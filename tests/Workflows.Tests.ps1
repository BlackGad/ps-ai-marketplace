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

    $workflowFolder = Join-Path $root '.github/workflows'
    $files = @()
    if (Test-Path -LiteralPath $workflowFolder) { $files = @(Get-ChildItem $workflowFolder -Filter '*.yml') }
    foreach ($file in $files) {
        $problems = @(Get-WorkflowProblems -Path $file.FullName)
        Assert-Equal 0 $problems.Count "$($file.Name): $($problems -join '; ')"
        $jobIds = @(Get-WorkflowJobIds -Path $file.FullName)
        if ($file.Name -ne 'tests.yml') { Assert-True ('gate' -notin $jobIds) "$($file.Name) must not have a job named gate" }
        if ($file.Name -ne 'integration.yml') { Assert-True ('integration' -notin $jobIds) "$($file.Name) must not have a job named integration" }
    }
    $tests = $files | Where-Object Name -eq 'tests.yml'
    if ($tests) { Assert-True ('gate' -in @(Get-WorkflowJobIds -Path $tests.FullName)) 'tests.yml has job gate' }
    $integration = $files | Where-Object Name -eq 'integration.yml'
    if ($integration) { Assert-True ('integration' -in @(Get-WorkflowJobIds -Path $integration.FullName)) 'integration.yml has job integration' }
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
