$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'plugins/legion/bin/lib/paths.ps1')

$guard = $env:LEGION_TEST_GUARD
Assert-True ((Get-Item -LiteralPath (Split-Path $guard) -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) 'Every test home is reached through a link'
Assert-Equal $guard $env:HOME 'HOME keeps the linked spelling'
Assert-Equal $guard $env:USERPROFILE 'USERPROFILE keeps the linked spelling'
foreach ($name in @('TMPDIR', 'TEMP', 'TMP')) {
    Assert-Equal (Join-Path $guard 'temp') ([Environment]::GetEnvironmentVariable($name, 'Process')) "$name stays inside the linked guard"
}
Assert-Equal ([IO.Path]::GetTempPath()) (Get-TestTempPath) 'Fixtures keep the linked temp spelling'
$catalog = Get-Content (Join-Path $root 'plugins/legion/tools.json') -Raw | ConvertFrom-Json
foreach ($name in $catalog.tools.configEnv) {
    Assert-Equal (Join-Path $guard $name) ([Environment]::GetEnvironmentVariable($name, 'Process')) "$name stays behind the home link"
}

$scratch = Join-Path (Get-TestTempPath) ('paths-' + [guid]::NewGuid().ToString('N'))
$link = Join-Path $scratch 'escape'
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
try {
    $physical = Resolve-LegionDirectoryPath $scratch
    Assert-True (Test-LegionPathUnder -Path $physical -Root (Get-TestTempPath)) 'Physical children belong to linked roots'
    Assert-True (Test-LegionPathUnder -Path $scratch -Root $physical -AllowEqual) 'Linked and physical spellings compare equal'
    Assert-True (-not (Test-LegionPathUnder -Path $scratch -Root $physical)) 'Equal paths require AllowEqual'
    Assert-True (Test-LegionPathUnder -Path (Join-Path $scratch 'missing/leaf') -Root $physical) 'Missing leaves resolve their linked ancestors'
    Assert-True (-not (Test-LegionPathUnder -Path ($physical + '-sibling') -Root $scratch)) 'Sibling prefixes stay outside the root'
    Assert-Equal $IsWindows (Test-LegionPathUnder -Path $scratch.ToUpperInvariant() -Root $physical -AllowEqual) 'Resolved identity follows OS case rules'
    Assert-True (Test-LegionOwnerPathSafe -Path (Join-Path $scratch 'missing/leaf') -StopRoot $scratch) 'Safety walks stop below linked ancestors'
    Assert-True (Test-LegionOwnerPathSafe -Path $scratch -StopRoot $guard) 'Safety walks stop at the home below its linked ancestor'
    Assert-Throws { Test-LegionOwnerPathSafe -Path $guard -StopRoot $scratch } 'Safety walks reject paths outside their stop root'
    $type = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $type -Path $link -Target (Resolve-LegionDirectoryPath $guard) | Out-Null
    Assert-True (-not (Test-LegionPathUnder -Path $link -Root $scratch)) 'Links escaping a root fail resolved containment'
    Assert-True (-not (Test-LegionOwnerPathSafe -Path $link -StopRoot $scratch)) 'Link refusal still returns false for an escaping link'
} finally {
    if (-not (Test-LegionPathUnder -Path $scratch -Root (Get-TestTempPath))) { throw 'Unsafe path fixture cleanup' }
    if (Test-Path -LiteralPath $link) { Remove-Item -LiteralPath $link -Force }
    Remove-Item -LiteralPath $scratch -Recurse -Force
}
