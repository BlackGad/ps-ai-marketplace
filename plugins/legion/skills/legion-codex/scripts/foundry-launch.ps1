param($Agent, [string]$HomeRoot, $Token)

. (Join-Path $PSScriptRoot '../../../bin/lib/paths.ps1')

$folder = Resolve-LegionHomePath -Path $Agent.configDir -HomeRoot $HomeRoot
return @{ Set = @{ CODEX_HOME = $folder }; Clear = [string[]]@(); ProvidersFile = $null; ProvidersJson = $null; Notice = $null }
