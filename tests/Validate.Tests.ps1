$root = Split-Path $PSScriptRoot -Parent
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('legion-tests/' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

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

try {
    . (Join-Path $root 'plugins/legion/bin/lib/settings.ps1')
    $recorded = Get-Content (Join-Path $PSScriptRoot 'fixtures/validate/old-behaviour.json') -Raw | ConvertFrom-Json
    foreach ($case in $recorded.tool) {
        $json = Get-EditedDescriptor $case | ConvertTo-Json -Depth 100
        $valid = [bool](Test-Json -Json $json -SchemaFile (Join-Path $root 'plugins/legion/schemas/tool.schema.json') -ErrorAction SilentlyContinue)
        Assert-Equal $case.valid $valid "Tool schema case $($case.name) matches the recorded run"
    }
    $raw = Get-Content -Raw (Join-Path $PSScriptRoot 'fixtures/personalisation/valid-owner.json')
    $bomFile = Join-Path $tempRoot 'bom-crlf.json'
    [System.IO.File]::WriteAllText($bomFile, [char]0xFEFF + ($raw -replace "`r?`n", "`r`n"))
    Assert-Equal 1 (Read-LegionJson -Path $bomFile).schemaVersion 'Read-LegionJson accepts BOM CRLF'
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
# FourthToolAcrossSharedConsumers / DescriptorOverseerArgumentOrder.
& {
    $ErrorActionPreference = 'Stop'
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $scratch = [IO.Path]::GetFullPath((Join-Path $repoRoot '.agents/temp/restructure'))
    $fixture = Join-Path $scratch ('consumers-' + [guid]::NewGuid().ToString('N'))
    $plugin = Join-Path $fixture 'plugin'
    $homeRoot = Join-Path $fixture 'home with spaces'
    $ownerPath = Join-Path $homeRoot '.legion/configuration/personalisation.json'
    $savedPath = $env:PATH
    try {
        New-Item -ItemType Directory (Split-Path $ownerPath -Parent) -Force | Out-Null
        Copy-Item (Join-Path $repoRoot 'plugins/legion') $plugin -Recurse
        $fourthSkill = Join-Path $plugin 'skills/legion-fourth'
        Copy-Item (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth') $fourthSkill -Recurse
        $owner = [pscustomobject]@{schemaVersion=1;agents=@();channels=@()}
        $owner | ConvertTo-Json -Depth 100 | Set-Content $ownerPath
        . (Join-Path $plugin 'bin/lib/settings.ps1')
        Assert-Equal 'FOURTH_HOME' (Get-LegionTool -Tool fourth).configEnv 'Fourth config environment comes from descriptor'
        $env:PATH = @($fourthSkill,$env:PATH) -join [IO.Path]::PathSeparator
        $owner.agents = @([pscustomobject]@{ id = 'fourth-dev'; tool = 'fourth'; configDir = (Join-Path $homeRoot '.legion/agents/fourth-dev') })
        $owner | ConvertTo-Json -Depth 100 | Set-Content $ownerPath
        $owner = Read-LegionJson $ownerPath
        $descriptorPath = Join-Path $fourthSkill 'tool.json'
        $descriptor = Get-Content $descriptorPath -Raw | ConvertFrom-Json
        $descriptor.foundry = $null
        $descriptor | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
        Remove-Item (Join-Path $fourthSkill 'SKILL.md')
        # Loading definitions and lease/hook operations must not discover malformed data.
        '{broken' | Set-Content $descriptorPath
        . (Join-Path $plugin 'bin/lib/common.ps1')
        Assert-Throws { Get-LegionTool -Tool fourth } 'Tool operations discover malformed descriptor lazily'
    } finally {
        $env:PATH = $savedPath
        $cleanup = [IO.Path]::GetFullPath($fixture)
        if (-not $cleanup.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar)) { throw 'Unsafe consumer fixture cleanup' }
        Remove-Item -LiteralPath $cleanup -Recurse -Force
    }
}
