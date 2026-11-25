$testBase = Split-Path $PSScriptRoot -Parent
$repo = Split-Path $testBase -Parent
$expected = @{
    claude = @('-p','--permission-mode','bypassPermissions','--strict-mcp-config')
    codex = @('exec','--dangerously-bypass-approvals-and-sandbox','-C','repo with spaces','-o','report with spaces.last.md','-')
    copilot = @('-p','Read and follow the task in task prompt with spaces.md; the report goes to stdout.','-s','--allow-all-tools','--deny-tool=shell(git push)')
}
foreach ($id in @('claude','codex','copilot')) {
    $reference = Get-Content (Join-Path $repo "plugins/legion/skills/legion-$id/references/run.md") -Raw
    $example = [regex]::Match($reference, '(?s)```powershell\r?\n(.*?)\r?\n```')
    Assert-True $example.Success "$id has an executable PowerShell worker example"
    $state = @{Args=@()}
    function Invoke-FakeWorker { $state.Args=@($args); $input | Out-Null }
    $command='Invoke-FakeWorker'; $repoPath='repo with spaces'; $report='report with spaces'; $promptText="task`nwith lines"
    $promptPath = 'task prompt with spaces.md'
    & ([scriptblock]::Create($example.Groups[1].Value)) | Out-Null
    Assert-Equal ($expected[$id] | ConvertTo-Json -Compress) ($state.Args | ConvertTo-Json -Compress) "$id documented worker preserves complete argv"
}
