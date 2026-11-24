. (Join-Path $PSScriptRoot 'lib/workspace.ps1')
$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $repo 'plugins/legion/bin/lib/python.ps1')

# Uninstall (installer side, stays in PowerShell until milestone 4) removes recorded app versions and nothing else.
$folder = Join-Path $HOME 'app uninstall'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }

# A version as an earlier sync leaves it: the folder, its marker, its environment and its record.
function New-OldApp {
    param([string]$HomeRoot, [string]$Version = '0.0.1', [switch]$NotRecorded, [switch]$NoMarker)
    $path = Join-Path $HomeRoot ".legion/app/$Version"
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    @{ name = 'legion'; version = $Version } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $path 'plugin.json')
    if (-not $NoMarker) { New-Item -ItemType File -Path (Get-LegionAppMarker $path) -Force | Out-Null }
    $environment = Get-LegionPythonEnvironment -PluginRoot $path -HomeRoot $HomeRoot
    New-Item -ItemType Directory -Path $environment -Force | Out-Null
    'python' | Set-Content -LiteralPath (Join-Path $environment 'python.txt')
    if (-not $NotRecorded) { Add-LegionFootprint -HomeRoot $HomeRoot -Kind app-version -Path $path -Owner legion }
    return @{ Path = $path; Environment = $environment }
}

function Add-AppOwner {
    param([string]$HomeRoot, [string]$Owner)
    Add-LegionFootprint -HomeRoot $HomeRoot -Kind app -Path (Get-LegionHomePath -Path 'app' -HomeRoot $HomeRoot) -Owner $Owner
}

# An unrecorded folder, even with a marker, and a linked recorded one are never removed.
$homeO = Join-Path $folder 'home o'
$stranger = New-OldApp -HomeRoot $homeO -Version '98.0.0' -NotRecorded
$elsewhereO = Join-Path $folder 'elsewhere o'
$linkedTarget = New-OldApp -HomeRoot $elsewhereO -Version '97.0.0' -NotRecorded
$linked = Join-Path $homeO '.legion/app/97.0.0'
New-Item -ItemType $linkType -Path $linked -Target $linkedTarget.Path | Out-Null
Add-LegionFootprint -HomeRoot $homeO -Kind app-version -Path $linked -Owner legion
Add-AppOwner -HomeRoot $homeO -Owner 'codex:one'
$output = @(Remove-LegionFootprintOwner -HomeRoot $homeO -Owner 'codex:one' -RetryOrphans)
Assert-True ($output -contains "skip: $linked (linked or not legion's)") 'Uninstall refuses a linked version'
Assert-True ((Test-Path -LiteralPath $stranger.Path) -and (Test-Path -LiteralPath $stranger.Environment)) 'Uninstall never removes an unrecorded folder'
Assert-True ((Test-Path -LiteralPath $linkedTarget.Path) -and (Test-Path -LiteralPath (Get-LegionAppMarker $linkedTarget.Path))) 'Uninstall never removes through a link'
(Get-Item -LiteralPath $linked -Force).Delete()

# A linked environment parent makes the version unsafe too.
$homeL = Join-Path $folder 'home l'
$linkedEnv = New-OldApp -HomeRoot $homeL -Version '96.0.0'
$elsewhereL = Join-Path $folder 'elsewhere l'
Move-Item -LiteralPath (Join-Path $homeL '.legion/python') -Destination $elsewhereL
New-Item -ItemType $linkType -Path (Join-Path $homeL '.legion/python') -Target $elsewhereL | Out-Null
Add-AppOwner -HomeRoot $homeL -Owner 'codex:one'
Remove-LegionFootprintOwner -HomeRoot $homeL -Owner 'codex:one' -RetryOrphans | Out-Null
Assert-True ((Test-Path -LiteralPath $linkedEnv.Path) -and @(Get-ChildItem -LiteralPath $elsewhereL -Recurse -File).Count) 'A version whose environment folder is linked is never removed'
(Get-Item -LiteralPath (Join-Path $homeL '.legion/python') -Force).Delete()

# A recorded version a failed sync left without the marker is legion's but never run: uninstall removes it.
$homeW = Join-Path $folder 'home w'
$unfinished = New-OldApp -HomeRoot $homeW -Version '0.0.1' -NoMarker
Add-AppOwner -HomeRoot $homeW -Owner 'codex:one'
$output = @(Remove-LegionFootprintOwner -HomeRoot $homeW -Owner 'codex:one' -RetryOrphans)
Assert-True ($output -contains "Remove app version: $($unfinished.Path)") 'Uninstall removes an unfinished version'
Assert-True (-not (Test-Path -LiteralPath $unfinished.Path) -and -not (Test-Path -LiteralPath $unfinished.Environment)) 'Uninstall removes the unfinished version and its environment'

# The app goes with its last owner, every version and environment it can remove.
$homeH = Join-Path $folder 'home h'
$current = New-OldApp -HomeRoot $homeH -Version '1.2.3'
$app = Get-LegionHomePath -Path 'app' -HomeRoot $homeH
foreach ($owner in @('claude:one', 'codex:two', 'codex:two')) { Add-AppOwner -HomeRoot $homeH -Owner $owner }
Assert-Equal 'claude:one|codex:two' (@(Get-LegionFootprints -HomeRoot $homeH -Kind app).owners -join '|') 'Each installing account is registered once'
Remove-LegionFootprintOwner -HomeRoot $homeH -Owner 'claude:one' | Out-Null
Assert-True (Test-Path -LiteralPath $current.Path) 'The app stays while an owner remains'
if ($IsWindows) {
    $lock = [IO.File]::Open((Join-Path $current.Environment 'python.txt'), 'Open', 'Read', 'None')
    try {
        $output = @(Remove-LegionFootprintOwner -HomeRoot $homeH -Owner 'codex:two' -RetryOrphans)
        Assert-True ($output -contains "Kept app version in use: $($current.Path) (close legion, then run uninstall again)") 'A running version is kept with one line'
        Assert-Equal 1 @(Get-LegionFootprints -HomeRoot $homeH -Kind app).Count 'The kept app stays recorded for a retry'
        Assert-Equal 1 @(Get-LegionFootprints -HomeRoot $homeH -Kind app-version).Count 'The kept version stays recorded for a retry'
        Assert-True (-not (Test-Path -LiteralPath $current.Path) -or (Test-Path -LiteralPath $current.Environment)) 'An app never stays without its environment'
    } finally { $lock.Dispose() }
}
$output = @(Remove-LegionFootprintOwner -HomeRoot $homeH -Owner 'codex:two' -RetryOrphans)
Assert-True ($output -contains "Remove app version: $($current.Path)") 'Uninstall names each app version it removes'
Assert-True (-not (Test-Path -LiteralPath $app) -and -not (Test-Path -LiteralPath $current.Environment)) 'The last owner removes the app and its environments'
Assert-Equal 0 @(Get-LegionFootprints -HomeRoot $homeH | Where-Object { $_.kind -cin @('app', 'app-version') }).Count 'The removed app is no longer recorded'
