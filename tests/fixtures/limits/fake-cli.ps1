# A stand-in for claude, codex and copilot. The test chooses its behavior through LEGION_FAKE_* variables.
$stdin = [Console]::In.ReadToEnd()
@{ arguments = @($args); folder = (Get-Location).Path; stdin = $stdin; claude = $env:CLAUDE_CONFIG_DIR; codex = $env:CODEX_HOME; copilot = $env:COPILOT_HOME } |
    ConvertTo-Json | Set-Content -LiteralPath $env:LEGION_FAKE_LOG
if ($env:LEGION_FAKE_SLEEP) { Start-Sleep -Seconds ([int]$env:LEGION_FAKE_SLEEP) }
if ($env:LEGION_FAKE_STDOUT) { [Console]::Out.Write([IO.File]::ReadAllText($env:LEGION_FAKE_STDOUT)) }
if ($env:LEGION_FAKE_STDERR) { [Console]::Error.Write([IO.File]::ReadAllText($env:LEGION_FAKE_STDERR)) }
if ($env:LEGION_FAKE_SESSION) {
    $folder = Join-Path $env:CODEX_HOME 'sessions/2026/11/22'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    Copy-Item -LiteralPath $env:LEGION_FAKE_SESSION -Destination (Join-Path $folder 'rollout-new.jsonl')
}
exit ([int]$env:LEGION_FAKE_EXIT)
