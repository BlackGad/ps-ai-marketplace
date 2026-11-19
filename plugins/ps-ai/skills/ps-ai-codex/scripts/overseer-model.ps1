param([string]$Model, [string[]]$Arguments)
. (Join-Path $PSScriptRoot '../../../bin/lib/common.ps1')
Get-PsAiExplicitModelArguments -Model $Model -Arguments $Arguments -Codex:$true
