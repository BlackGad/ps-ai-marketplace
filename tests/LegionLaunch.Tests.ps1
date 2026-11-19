$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $repo 'plugins/ps-ai/bin/ps-ai-overseer.ps1') -NoRun
$expected = @{
    claude = @('-p','--permission-mode','bypassPermissions')
    codex = @('exec','--dangerously-bypass-approvals-and-sandbox','-C','repo with spaces','-o','report with spaces','-')
    copilot = @('-p',"task`nwith lines",'-s','--allow-all-tools','--deny-tool=shell(git push)')
}
foreach ($id in @('claude','codex','copilot')) {
    $reference = Get-Content (Join-Path $repo "plugins/ps-ai/skills/ps-ai-$id/references/run.md") -Raw
    $example = [regex]::Match($reference, '(?s)```powershell\r?\n(.*?)\r?\n```')
    Assert-True $example.Success "$id has an executable PowerShell worker example"
    $state = @{Args=@()}
    function Invoke-FakeWorker { $state.Args=@($args); $input | Out-Null }
    $command='Invoke-FakeWorker'; $repoPath='repo with spaces'; $report='report with spaces'; $promptText="task`nwith lines"
    & ([scriptblock]::Create($example.Groups[1].Value)) | Out-Null
    Assert-Equal ($expected[$id] | ConvertTo-Json -Compress) ($state.Args | ConvertTo-Json -Compress) "$id documented worker preserves complete argv"
    $owner = @{agents=@(@{id='chosen';tool=$id});channels=@()}
    $launch = Get-OverseerLaunch -Personalisation $owner -AccountId chosen
    Invoke-OverseerInRepo -Repo $repo -Command Invoke-FakeWorker -Arguments $launch.Args
    $interactive = if ($id -eq 'copilot') { @('-i','continue as the overseer') } else { @('continue as the overseer') }
    Assert-Equal ($interactive | ConvertTo-Json -Compress) ($state.Args | ConvertTo-Json -Compress) "$id overseer launches without worker permissions"
}
