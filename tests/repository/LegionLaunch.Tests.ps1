$testBase = Split-Path $PSScriptRoot -Parent
$repo = Split-Path $testBase -Parent
$ErrorActionPreference = 'Stop'
. (Join-Path $testBase 'lib/workspace.ps1')
$scratch = Join-Path (Get-TestTempPath) 'legion-launch'
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
$launch = @('--home','legion home','run','--account','codex-a','--')
$expected = @{
    claude = $launch + @('-p','--permission-mode','bypassPermissions','--strict-mcp-config')
    codex = $launch + @('exec','--dangerously-bypass-approvals-and-sandbox','-C','repo with spaces','-o','report with spaces.last.md','-')
    copilot = $launch + @('-p','Read and follow the task in task prompt with spaces.md.','-s','--allow-all-tools','--deny-tool=shell(git push)')
}
$savedPath = $env:PATH
try {
    # A native stub on PATH stands in for the legion command: PowerShell passes `--` on to a program, never to a function.
    $env:PATH = $scratch + [IO.Path]::PathSeparator + $env:PATH
    $record = Join-Path $scratch 'record args.ps1'
    '$args | ConvertTo-Json -Compress | Set-Content -LiteralPath $env:LEGION_TEST_ARGS; $input | Out-Null' | Set-Content -LiteralPath $record
    $env:LEGION_TEST_ARGS = Join-Path $scratch 'args.json'
    foreach ($id in @('claude','codex','copilot')) {
        $reference = Get-Content (Join-Path $repo "plugins/legion/skills/legion-$id/references/run.md") -Raw
        $example = [regex]::Match($reference, '(?s)```powershell\r?\n(.*?)\r?\n```')
        Assert-True $example.Success "$id has an executable PowerShell worker example"
        New-TestCommandStub -Folder $scratch -Name legion -Script $record | Out-Null
        $legionHome = 'legion home'; $account = 'codex-a'; $repoPath='repo with spaces'; $report='report with spaces'; $promptText="task`nwith lines"
        $promptPath = 'task prompt with spaces.md'
        Push-Location $scratch
        try { & ([scriptblock]::Create($example.Groups[1].Value)) | Out-Null } finally { Pop-Location }
        Assert-Equal ($expected[$id] | ConvertTo-Json -Compress) (Get-Content -LiteralPath $env:LEGION_TEST_ARGS -Raw).Trim() "$id documented worker preserves complete argv"
        if ($id -ne 'codex') { Assert-True (Test-Path -LiteralPath (Join-Path $scratch 'report with spaces.stdout.md')) "$id documented worker captures stdout in the report's .stdout.md" }
    }
}
finally {
    $env:PATH = $savedPath
    Remove-Item Env:LEGION_TEST_ARGS -ErrorAction SilentlyContinue
    Remove-TestFolder -Path $scratch -AllowedParent (Get-TestTempPath)
}
