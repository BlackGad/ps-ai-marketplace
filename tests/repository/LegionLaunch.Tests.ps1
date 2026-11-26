$testBase = Split-Path $PSScriptRoot -Parent
$repo = Split-Path $testBase -Parent
$ErrorActionPreference = 'Stop'
. (Join-Path $testBase 'lib/workspace.ps1')
$scratch = Join-Path (Get-TestTempPath) 'legion-launch'
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
$launch = @('run','--account','codex-a','--')
$expected = @{
    claude = $launch + @('-p','--permission-mode','bypassPermissions','--strict-mcp-config')
    codex = $launch + @('exec','--dangerously-bypass-approvals-and-sandbox','-C','repo with spaces','-o','report with spaces.last.md','-')
    copilot = $launch + @('-p','Read and follow the task in task prompt with spaces.md; the report goes to stdout.','-s','--allow-all-tools','--deny-tool=shell(git push)')
}
try {
    # A native stub stands in for the legion command: PowerShell passes `--` on to a program, never to a function.
    $record = Join-Path $scratch 'record args.ps1'
    '$args | ConvertTo-Json -Compress | Set-Content -LiteralPath $env:LEGION_TEST_ARGS; $input | Out-Null' | Set-Content -LiteralPath $record
    $env:LEGION_TEST_ARGS = Join-Path $scratch 'args.json'
    foreach ($id in @('claude','codex','copilot')) {
        $reference = Get-Content (Join-Path $repo "plugins/legion/skills/legion-$id/references/run.md") -Raw
        $example = [regex]::Match($reference, '(?s)```powershell\r?\n(.*?)\r?\n```')
        Assert-True $example.Success "$id has an executable PowerShell worker example"
        $legion = New-TestCommandStub -Folder $scratch -Name legion -Script $record
        $account = 'codex-a'; $repoPath='repo with spaces'; $report='report with spaces'; $promptText="task`nwith lines"
        $promptPath = 'task prompt with spaces.md'
        & ([scriptblock]::Create($example.Groups[1].Value)) | Out-Null
        Assert-Equal ($expected[$id] | ConvertTo-Json -Compress) (Get-Content -LiteralPath $env:LEGION_TEST_ARGS -Raw).Trim() "$id documented worker preserves complete argv"
    }
}
finally {
    Remove-Item Env:LEGION_TEST_ARGS -ErrorAction SilentlyContinue
    Remove-TestFolder -Path $scratch -AllowedParent (Get-TestTempPath)
}
