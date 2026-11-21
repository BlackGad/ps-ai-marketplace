@{config=$env:FOURTH_HOME;arguments=@($args)} | ConvertTo-Json -Depth 10 | Set-Content $env:LEGION_FAKE_TOOL_LOG
exit 0
