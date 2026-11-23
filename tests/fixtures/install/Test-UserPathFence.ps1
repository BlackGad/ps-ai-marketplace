param([string]$Repo, [string]$FixtureHome)
$ErrorActionPreference = 'Stop'
if (-not $env:LEGION_TEST_USER_PATH_FILE) { throw 'Child did not inherit the user PATH fence' }
# Exercise the Windows saved-PATH branches on every host, using only the inherited file.
$env:OS = 'Windows_NT'
. (Join-Path $Repo 'install.ps1') -NoRun
function Get-InstallHome { $FixtureHome }
$before = Get-InstallUserPath
$portable = Join-Path $FixtureHome '.legion/tools/pwsh'
$prefix = if ($before) { $before.TrimEnd(';') + ';' } else { '' }
$null = Add-InstallPowerShellPath -Path $portable
if ((Get-InstallUserPath) -cne ($prefix + $portable)) { throw 'Bootstrap add did not use the fake store' }

. (Join-Path $Repo 'plugins/legion/install.ps1') -NoRun
function Get-InstallHome { $FixtureHome }
$script:installCatalog = Get-InstallCatalog -Source $Repo
Add-LegionFootprint -HomeRoot $FixtureHome -Kind path-entry -Path 'user PATH' -Value $portable -Owner legion
$bin = Join-Path $FixtureHome '.legion/bin'
$null = Add-LegionUserPath -Folder $bin -HomeRoot $FixtureHome
$added = Get-LegionUserPath
if ($added -cne ($prefix + $portable + ';' + $bin)) { throw 'Plugin add did not use the bootstrap store' }
$null = Add-LegionUserPath -Folder $bin -HomeRoot $FixtureHome
if ((Get-LegionUserPath) -cne $added) { throw 'Repeated add changed the fake store' }
$null = Invoke-LegionPurge -DryRun
if ((Get-LegionUserPath) -cne $added) { throw 'Purge preview changed the fake store' }
$null = Invoke-LegionPurge -Yes
if ((Get-LegionUserPath) -cne $before.TrimEnd(';')) { throw 'Purge did not remove only the recorded fake entries' }
if ((Get-InstallUserPath) -cne (Get-LegionUserPath)) { throw 'Bootstrap and plugin readers disagree' }
$null = Invoke-LegionPurge -Yes
if ((Get-LegionUserPath) -cne $before.TrimEnd(';')) { throw 'Repeated purge changed the fake store' }
Write-Output 'child PATH fence passed'
