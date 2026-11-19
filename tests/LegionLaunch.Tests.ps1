# A missing permission profile must not silently launch a worker with CLI defaults.
$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $repo 'plugins/ps-ai/bin/PsAi.Tools.ps1')
$expected = @{
    codex = @('exec', '--dangerously-bypass-approvals-and-sandbox')
    claude = @('-p', '--permission-mode', 'bypassPermissions')
    copilot = @('-p', '--allow-all-tools', "--deny-tool=shell(git push)")
}
foreach ($id in @('codex', 'claude', 'copilot')) {
    $tool = Get-PsAiTool -Tool $id
    Assert-Equal ($expected[$id] -join '|') ($tool.legionArgs -join '|') "$id worker launch profile"
    Assert-True (-not ($tool.overseerArgs -contains $expected[$id][1])) "$id worker permissions stay out of overseer launches"
}
