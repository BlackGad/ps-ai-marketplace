$root = Split-Path $PSScriptRoot -Parent
$bin = Join-Path $root 'plugins/legion/bin'
. (Join-Path $bin 'lib/settings.ps1')
. (Join-Path $bin 'lib/accounts.ps1')

# OneUserPathWriter: the user PATH is written in lib/paths.ps1 only; callers use Add-LegionUserPath.
foreach ($file in Get-ChildItem $bin -Recurse -Filter '*.ps1' | Where-Object { $_.Name -cne 'paths.ps1' }) {
    $text = [IO.File]::ReadAllText($file.FullName)
    Assert-True ($text -cnotmatch 'Registry\]::CurrentUser|function (Get|Set)-(Setup)?UserPath') "$($file.Name) does not read or write the user PATH itself"
}
$state = @{ Path = 'first'; Writes = 0 }
function Get-InstallUserPath { $state.Path }
function Set-InstallUserPath { param($Path) $state.Path = $Path; $state.Writes++ }
$savedOS = $env:OS
try {
    $env:OS = 'Windows_NT'
    Add-LegionUserPath -Folder 'C:\legion\bin' -HomeRoot $env:HOME
    Assert-Equal 'first;C:\legion\bin' $state.Path 'Add-LegionUserPath appends the folder'
    Add-LegionUserPath -Folder 'C:\legion\bin\' -HomeRoot $env:HOME
    Assert-Equal 1 $state.Writes 'A repeat (even with a trailing slash) writes nothing'
    $state.Path = ''
    Add-LegionUserPath -Folder 'C:\legion\bin' -HomeRoot $env:HOME
    Assert-Equal 'C:\legion\bin' $state.Path 'An empty user PATH becomes the folder'
} finally { $env:OS = $savedOS }

# PersistentFolders: saved user and machine PATH entries, expanded, quotes and blanks dropped.
$env:LEGION_BINSHARED = 'C:\expanded'
function Get-InstallUserPath { '%LEGION_BINSHARED%\a;"C:\quoted";;' }
function Get-InstallMachinePath { 'C:\machine' }
Assert-Equal 'C:\expanded\a|C:\quoted|C:\machine' ((Get-LegionPersistentFolders) -join '|') 'Persistent folders are expanded user then machine entries'
Remove-Item Env:LEGION_BINSHARED

# OneFoundryCheck: only lib/tools.ps1 throws "does not support Foundry".
foreach ($file in Get-ChildItem $bin -Recurse -Filter '*.ps1' | Where-Object { $_.Name -cne 'tools.ps1' }) {
    Assert-True ([IO.File]::ReadAllText($file.FullName) -cnotmatch 'throw "tool .* does not support Foundry') "$($file.Name) trusts Get-LegionFoundryTool"
}
Assert-Equal 'claude' (Get-LegionFoundryTool -Tool claude).id 'Foundry tool lookup returns the descriptor'
Assert-Throws { Get-LegionFoundryTool -Tool absent | Out-Null } 'Unknown tool is rejected'

# ChannelHelpers: one binding lookup, one kind lookup, one launch check.
$data = [pscustomobject]@{ channels = @([pscustomobject]@{ id = 'one'; kind = 'telegram' }, [pscustomobject]@{ id = 'two'; kind = 'telegram' }, [pscustomobject]@{ id = 'two'; kind = 'telegram' }) }
Assert-Equal 'one' (Get-LegionChannelBinding -Personalisation $data -Id 'one').id 'Binding lookup finds one channel'
Assert-Throws { Get-LegionChannelBinding -Personalisation $data -Id 'two' | Out-Null } 'Duplicate channel is rejected'
Assert-Throws { Get-LegionChannelBinding -Personalisation $data -Id 'none' | Out-Null } 'Unknown channel is rejected'
$kind = Get-LegionChannelKind -Kind telegram
Assert-True (Test-LegionChannelLaunchesTool $kind claude) 'Telegram launches claude'
Assert-True (-not (Test-LegionChannelLaunchesTool $kind absent)) 'Telegram does not launch an unknown tool'
Assert-Throws { Get-LegionChannelKind -Kind absent | Out-Null } 'Unknown channel kind is rejected'

# WrapperLinkWalkStopsAtHome: no wrapper check walks above the home folder by itself.
$accountsText = [IO.File]::ReadAllText((Join-Path $bin 'lib/accounts.ps1'))
Assert-True ($accountsText -cnotmatch 'ReparsePoint') 'Account helpers use Test-LegionOwnerPathSafe for link walks'
$tempHome = Join-Path ([IO.Path]::GetTempPath()) ('legion-binshared-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $tempHome '.legion/bin') -Force | Out-Null
try {
    Assert-LegionWrapperPath (Join-Path $tempHome '.legion/bin/claude-a') 'claude-a'
    Assert-True $true 'A wrapper path under a plain home passes the link check'
} finally { Remove-Item -LiteralPath $tempHome -Recurse -Force }

# FlatNeeds: a helper may not have prerequisites.
$recipes = @{ tool = @{ macos = @{ needs = @('helper') } }; helper = @{ macos = @{ needs = @('other') } }; other = @{ macos = @{ needs = @() } } }
Assert-Throws { Assert-LegionInstallNeeds -Tool tool -Platform macos -Recipes $recipes -HelperIds @('helper', 'other') } 'A helper with prerequisites is rejected'
