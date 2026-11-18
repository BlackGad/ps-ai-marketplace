param($Agent, [string]$HomeRoot)

$folder = [string]$Agent.configDir
if ($folder.StartsWith('~/')) { $folder = Join-Path $HomeRoot $folder.Substring(2) }
$path = Join-Path $folder 'settings.json'
$settings = [ordered]@{}
if (Test-Path -LiteralPath $path) {
    try {
        $jsonOptions = @{}
        if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $jsonOptions.DateKind = 'String' }
        $settings = [IO.File]::ReadAllText($path) | ConvertFrom-Json -AsHashtable -NoEnumerate @jsonOptions -ErrorAction Stop
        if ($settings -isnot [Collections.IDictionary]) { throw 'not an object' }
    } catch { throw 'settings.json is not valid JSON; fix or remove it' }
}
$settings['modelPicker'] = [ordered]@{
    replaceBuiltInOptions = $true
    options = @($Agent.provider.deployments | ForEach-Object { [ordered]@{ model = $_.name; label = $_.name } })
}
$content = ($settings | ConvertTo-Json -Depth 100) + "`n"
if ((Test-Path -LiteralPath $path) -and [IO.File]::ReadAllText($path) -ceq $content) {
    return @{ Changed = $false; Path = $path }
}
New-Item -ItemType Directory -Path $folder -Force | Out-Null
[IO.File]::WriteAllText($path, $content, [Text.UTF8Encoding]::new($false))
return @{ Changed = $true; Path = $path }
