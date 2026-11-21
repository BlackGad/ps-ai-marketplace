param($Agent, [string]$HomeRoot)

function Get-FoundryTomlMultilineState {
    # Scan strings and comments so table-like prompt text is never treated as TOML syntax.
    param([string]$Line, [string]$Delimiter, [ref]$ArrayDepth)
    for ($i = 0; $i -lt $Line.Length;) {
        if ($Delimiter) {
            if ($Delimiter -ceq '"""' -and $Line[$i] -ceq '\') { $i += 2; continue }
            if ($i + 2 -lt $Line.Length -and $Line.Substring($i, 3) -ceq $Delimiter) { $Delimiter = ''; $i += 3; continue }
            $i++
            continue
        }
        if ($Line[$i] -ceq '#') { break }
        if ($Line[$i] -cin @('"', "'")) {
            $quote = [string]$Line[$i]
            if ($i + 2 -lt $Line.Length -and $Line.Substring($i, 3) -ceq ($quote * 3)) {
                $Delimiter = $quote * 3
                $i += 3
                continue
            }
            $string = [regex]::Match($Line.Substring($i), '^(?:"(?:\\.|[^"\\])*"|''[^'']*'')')
            # An unfinished single-line string cannot contain a real table header.
            if (-not $string.Success) { break }
            $i += $string.Length
        } else {
            if ($Line[$i] -ceq '[') { $ArrayDepth.Value++ }
            if ($Line[$i] -ceq ']') { $ArrayDepth.Value-- }
            $i++
        }
    }
    return $Delimiter
}

. (Join-Path $PSScriptRoot '../../../bin/lib/paths.ps1')
$folder = [string]$Agent.configDir
if ($folder.StartsWith('~/')) { $folder = Join-Path $HomeRoot $folder.Substring(2) }
$path = Join-Path $folder 'config.toml'
$az = Get-Command az -CommandType Application,ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $az) { throw 'az is not installed; run legion-install-tool.ps1 -Tool az' }
$original = if (Test-Path -LiteralPath $path) { [IO.File]::ReadAllText($path) } else { '' }
$newline = if ($original.Contains("`r`n")) { "`r`n" } else { "`n" }
$values = @{
    root = [ordered]@{ model = ($Agent.provider.default | ConvertTo-Json -Compress); model_provider = '"legion-foundry"' }
    provider = [ordered]@{ base_url = (($Agent.provider.endpoint + '/openai/v1') | ConvertTo-Json -Compress); wire_api = '"responses"' }
    auth = [ordered]@{
        command = ($az.Source | ConvertTo-Json -Compress)
        args = '["account","get-access-token","--resource","https://cognitiveservices.azure.com","--query","accessToken","-o","tsv"]'
        refresh_interval_ms = '1800000'
    }
}
$seen = @{ root = @(); provider = @(); auth = @() }
$visited = @('root')
$builder = [Text.StringBuilder]::new()
function Add-FoundryMissingKeys {
    param([string]$Section)
    if (-not $Section) { return }
    foreach ($key in $values[$Section].Keys) {
        if ($key -cin $seen[$Section]) { continue }
        if ($builder.Length -and $builder[$builder.Length - 1] -ne "`n") { [void]$builder.Append($newline) }
        [void]$builder.Append("$key = $($values[$Section][$key])$newline")
        $seen[$Section] += $key
    }
}
$section = 'root'
$multiline = ''
$arrayDepth = 0
$skipValue = $false
$tableKey = '(?:model_providers|"model_providers"|''model_providers'')'
$providerKey = '(?:legion-foundry|"legion-foundry"|''legion-foundry''|ps-ai-foundry|"ps-ai-foundry"|''ps-ai-foundry'')'
$authKey = '(?:auth|"auth"|''auth'')'
$providerTable = '^\s*\[\s*' + $tableKey + '\s*\.\s*(?<provider>' + $providerKey + ')(?<auth>\s*\.\s*' + $authKey + ')?\s*\]\s*(?:#.*)?$'
foreach ($match in [regex]::Matches($original, '[^\r\n]*(?:\r\n|\n|\r|$)')) {
    $line = $match.Value
    if (-not $line.Length) { continue }
    $outsideValue = -not $multiline -and $arrayDepth -eq 0
    if ($outsideValue -and $line -match '^\s*\[') {
        Add-FoundryMissingKeys $section
        $section = ''
        $table = [regex]::Match($line.TrimEnd("`r", "`n"), $providerTable)
        if ($table.Success) {
            $section = if ($table.Groups['auth'].Success) { 'auth' } else { 'provider' }
            $visited += $section
            $span = $table.Groups['provider']
            $line = $line.Remove($span.Index, $span.Length).Insert($span.Index, $span.Value.Replace('ps-ai-foundry', 'legion-foundry'))
        }
    }
    $assignment = [regex]::Match($line, '^(?<prefix>\s*(?<key>\w+|"\w+"|''\w+'')\s*=\s*)(?<rest>[^\r\n]*)(?<ending>\r\n|\n|\r|$)$')
    $key = $assignment.Groups['key'].Value.Trim('"', "'")
    $replace = $outsideValue -and $section -and $assignment.Success -and $key -cin $values[$section].Keys
    $updated = $line
    if ($replace) {
        $seen[$section] += $key
        $rest = $assignment.Groups['rest'].Value
        $value = [regex]::Match($rest, '^(?<value>"(?:\\.|[^"\\])*"|''[^'']*''|\[[^\r\n]*\]|\d+)(?<suffix>\s*(?:#.*)?)$')
        $desired = $values[$section][$key]
        if ($value.Success) {
            $actual = $value.Groups['value'].Value
            if ($key -eq 'model_provider' -and $actual -cmatch '^["'']ps-ai-foundry["'']$') { $desired = $actual.Replace('ps-ai-foundry', 'legion-foundry') }
            elseif ($actual.Trim('"', "'") -ceq $desired.Trim('"', "'")) { $desired = $actual }
            elseif ($key -eq 'args') {
                try {
                    $actualArray = ConvertFrom-Json -InputObject $actual -ErrorAction Stop
                    if ((ConvertTo-Json -InputObject $actualArray -Compress) -ceq $desired) { $desired = $actual }
                } catch { } # A different TOML array is replaced with the managed token command.
            }
            $updated = $assignment.Groups['prefix'].Value + $desired + $value.Groups['suffix'].Value + $assignment.Groups['ending'].Value
        } else { $updated = $assignment.Groups['prefix'].Value + $desired + $newline }
    }
    $omit = $skipValue
    $multiline = Get-FoundryTomlMultilineState -Line $line -Delimiter $multiline -ArrayDepth ([ref]$arrayDepth)
    if ($replace -or $skipValue) { $skipValue = [bool]$multiline -or $arrayDepth -gt 0 }
    if (-not $omit) { [void]$builder.Append($updated) }
}
if ($multiline -or $arrayDepth -ne 0) { throw 'Unclosed TOML value; resolve it before configuring Foundry' }
Add-FoundryMissingKeys $section
foreach ($missing in @('provider', 'auth')) {
    if ($missing -cin $visited) { continue }
    if ($builder.Length -and $builder[$builder.Length - 1] -ne "`n") { [void]$builder.Append($newline) }
    $suffix = if ($missing -eq 'auth') { '.auth' } else { '' }
    [void]$builder.Append("[model_providers.legion-foundry$suffix]$newline")
    Add-FoundryMissingKeys $missing
}
$content = $builder.ToString()
if ($original -ceq $content) { return @{ Changed = $false; Path = $path } }
New-Item -ItemType Directory -Path $folder -Force | Out-Null
if (Test-Path -LiteralPath $path) { Set-LegionTextPreservingEncoding -Path $path -Text $content }
else { [IO.File]::WriteAllText($path, $content, [Text.UTF8Encoding]::new($false)) }
return @{ Changed = $true; Path = $path }
