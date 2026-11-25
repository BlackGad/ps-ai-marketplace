$root = Split-Path $PSScriptRoot -Parent
$bin = Join-Path $root 'plugins/legion/bin'
. (Join-Path $bin 'lib/settings.ps1')
. (Join-Path $bin 'lib/footprints.ps1')

# OneUserPathWriter: the user PATH is written in lib/paths.ps1 only; callers use Add-LegionUserPath.
foreach ($file in Get-ChildItem $bin -Recurse -Filter '*.ps1' | Where-Object { $_.Name -cne 'paths.ps1' }) {
    $text = [IO.File]::ReadAllText($file.FullName)
    Assert-True ($text -cnotmatch 'Registry\]::CurrentUser|function (Get|Set)-(Setup)?UserPath') "$($file.Name) does not read or write the user PATH itself"
}
$state = @{ Path = 'first'; Writes = 0 }
function Get-LegionUserPath { $state.Path }
function Set-LegionUserPath { param($Path) $state.Path = $Path; $state.Writes++ }
$savedOS = $env:OS
$pathHome = Join-Path $root ('.agents/temp/binshared-path-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $pathHome -Force | Out-Null
try {
    $env:OS = 'Windows_NT'
    Add-LegionUserPath -Folder 'C:\legion\bin' -HomeRoot $pathHome
    Assert-Equal 'first;C:\legion\bin' $state.Path 'Add-LegionUserPath appends the folder'
    $repeat = @(Add-LegionUserPath -Folder 'C:\legion\bin\' -HomeRoot $pathHome)
    Assert-Equal 1 $state.Writes 'A repeat (even with a trailing slash) writes nothing'
    Assert-Equal 'skip: path (already done)' ($repeat -join '|') 'A repeat says the PATH entry is already there'
    $state.Path = ''
    Add-LegionUserPath -Folder 'C:\legion\bin' -HomeRoot $pathHome
    Assert-Equal 'C:\legion\bin' $state.Path 'An empty user PATH becomes the folder'
    $footprints = @(Get-LegionFootprints -HomeRoot $pathHome -Kind path-entry)
    Assert-Equal 1 $footprints.Count 'Repeated PATH writes record one footprint in the fixture home'
    Assert-Equal 'C:\legion\bin' $footprints[0].value 'The fixture records the PATH folder'
} finally {
    $env:OS = $savedOS
    $allowed = [IO.Path]::GetFullPath((Join-Path $root '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
    if (-not [IO.Path]::GetFullPath($pathHome).StartsWith($allowed)) { throw 'Unsafe PATH fixture cleanup' }
    Remove-Item -LiteralPath $pathHome -Recurse -Force
}

# PersistentFolders: saved user and machine PATH entries, expanded, quotes and blanks dropped.
$env:LEGION_BINSHARED = 'C:\expanded'
function Get-LegionUserPath { '%LEGION_BINSHARED%\a;"C:\quoted";;' }
function Get-LegionMachinePath { 'C:\machine' }
Assert-Equal 'C:\expanded\a|C:\quoted|C:\machine' ((Get-LegionPersistentFolders) -join '|') 'Persistent folders are expanded user then machine entries'
Remove-Item Env:LEGION_BINSHARED

# FindPersistentCommand: a command found only in a saved PATH folder; nothing outside Windows.
$commandFolder = Join-Path $root ('.agents/temp/binshared-command-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $commandFolder -Force | Out-Null
try {
    Set-Content -LiteralPath (Join-Path $commandFolder 'legion-fake.cmd') -Value '@exit /b 0'
    Set-Content -LiteralPath (Join-Path $commandFolder 'legion-shim.ps1') -Value 'throw "a path-only probe never runs the shim"'
    function Get-LegionPersistentFolders { @($commandFolder) }
    if ($IsWindows) {
        Assert-Equal (Join-Path $commandFolder 'legion-fake.cmd') (Find-LegionPersistentCommand -Name 'legion-fake') 'A command in a saved PATH folder is found by name'
        Assert-Equal (Join-Path $commandFolder 'legion-shim.ps1') (Find-LegionPersistentCommand -Name 'legion-shim') 'A .ps1 shim in a saved PATH folder is found by path only'
        Assert-Equal $null (Find-LegionPersistentCommand -Name 'legion-missing') 'A missing command is not found'
    } else {
        Assert-Equal $null (Find-LegionPersistentCommand -Name 'legion-fake') 'Outside Windows there is no saved PATH to search'
    }
} finally { Remove-Item -LiteralPath $commandFolder -Recurse -Force }

# ChannelHelpers: one binding lookup, one kind lookup, one launch check.
$data = [pscustomobject]@{ channels = @([pscustomobject]@{ id = 'one'; kind = 'telegram' }, [pscustomobject]@{ id = 'two'; kind = 'telegram' }, [pscustomobject]@{ id = 'two'; kind = 'telegram' }) }
Assert-Equal 'one' (Get-LegionChannelBinding -Personalisation $data -Id 'one').id 'Binding lookup finds one channel'
Assert-Throws { Get-LegionChannelBinding -Personalisation $data -Id 'two' | Out-Null } 'Duplicate channel is rejected'
Assert-Throws { Get-LegionChannelBinding -Personalisation $data -Id 'none' | Out-Null } 'Unknown channel is rejected'
$kind = Get-LegionChannelKind -Kind telegram
Assert-True (Test-LegionChannelLaunchesTool $kind claude) 'Telegram launches claude'
Assert-True (-not (Test-LegionChannelLaunchesTool $kind absent)) 'Telegram does not launch an unknown tool'
Assert-Throws { Get-LegionChannelKind -Kind absent | Out-Null } 'Unknown channel kind is rejected'

# OneHeaderHome: the generated-file header and the shell profile marker are spelled out in lib/paths.ps1 only.
foreach ($file in @(Get-ChildItem (Split-Path $bin) -Recurse -Filter '*.ps1' | Where-Object { $_.FullName -cne [IO.Path]::GetFullPath((Join-Path $bin 'lib/paths.ps1')) })) {
    Assert-True ([IO.File]::ReadAllText($file.FullName) -cnotmatch 'Generated by legion|Added by legion') "$($file.Name) takes the header and marker from lib/paths.ps1"
}
