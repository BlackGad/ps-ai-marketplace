$testBase = Split-Path $PSScriptRoot -Parent
$root = Split-Path $testBase -Parent
# A tool case is the real descriptor with one edit: the value at a JSON pointer path, or no property there.
function Get-EditedDescriptor {
    param($Case)
    $data = Get-Content (Join-Path $root "plugins/legion/skills/legion-$($Case.tool)/tool.json") -Raw | ConvertFrom-Json
    if (-not $Case.path) { return $data }
    $keys = @($Case.path.Split('/') | Select-Object -Skip 1)
    $target = $data
    foreach ($key in @($keys | Select-Object -SkipLast 1)) {
        if ($target -is [array]) { $target = $target[[int]$key] } else { $target = $target.$key }
    }
    $last = $keys[-1]
    if ($Case.PSObject.Properties.Name -notcontains 'value') { $target.PSObject.Properties.Remove($last) }
    elseif ($target -is [array]) { $target[[int]$last] = $Case.value }
    else { $target.$last = $Case.value }
    return $data
}

$recorded = Get-Content (Join-Path $testBase 'fixtures/validate/old-behaviour.json') -Raw | ConvertFrom-Json
foreach ($case in $recorded.tool) {
    $json = Get-EditedDescriptor $case | ConvertTo-Json -Depth 100
    $valid = [bool](Test-Json -Json $json -SchemaFile (Join-Path $root 'plugins/legion/schemas/tool.schema.json') -ErrorAction SilentlyContinue)
    Assert-Equal $case.valid $valid "Tool schema case $($case.name) matches the recorded run"
}
