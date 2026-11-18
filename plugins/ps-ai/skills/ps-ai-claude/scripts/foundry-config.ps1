param($Agent, [string]$HomeRoot)

. (Join-Path $PSScriptRoot '../../../bin/PsAi.Tools.ps1')

$folder = [string]$Agent.configDir
if ($folder.StartsWith('~/')) { $folder = Join-Path $HomeRoot $folder.Substring(2) }
$path = Join-Path $folder 'settings.json'
$settings = [ordered]@{}
if (Test-Path -LiteralPath $path) {
    try {
        $existing = ConvertFrom-PsAiToolJson -Json ([IO.File]::ReadAllText($path))
        if ($existing -isnot [pscustomobject]) { throw 'not an object' }
        foreach ($property in $existing.PSObject.Properties) { $settings[$property.Name] = $property.Value }
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
