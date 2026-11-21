param($Agent, [string]$HomeRoot, $Token)

$folder = [string]$Agent.configDir
if ($folder.StartsWith('~/')) { $folder = Join-Path $HomeRoot $folder.Substring(2) }
return @{ Set = @{ FOURTH_HOME = $folder }; Clear = [string[]]@(); ProvidersFile = $null; ProvidersJson = $null; Notice = $null }
