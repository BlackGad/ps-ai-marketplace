$root = Split-Path $PSScriptRoot -Parent
$bin = Join-Path $root 'plugins/legion/bin'

# LibrariesKeepCallerParameters: dot-sourcing a library never overwrites the caller's variables.
function Test-CallerParameters {
    param([string]$Id = 'caller-id', [string]$Tool = 'caller-tool', [string]$HomeRoot = 'caller-home', [string]$Kind = 'caller-kind', [string]$Path = 'caller-path', [switch]$NoRun)
    . (Join-Path $bin 'lib/settings.ps1')
    . (Join-Path $bin 'lib/accounts.ps1')
    return "$Id|$Tool|$HomeRoot|$Kind|$Path|$NoRun"
}
Assert-Equal 'caller-id|caller-tool|caller-home|caller-kind|caller-path|False' (Test-CallerParameters) 'Libraries keep the caller parameters'
foreach ($name in 'settings', 'accounts') {
    $text = [IO.File]::ReadAllText((Join-Path $bin "lib/$name.ps1"))
    Assert-True ($text -cnotmatch '(?m)^param\(') "lib/$name.ps1 has no top-level param block"
}

# EntryScriptsDoNotLoadEntryScripts: shared helpers live in lib, so no entry script is dot-sourced by another.
foreach ($file in Get-ChildItem $bin -Filter 'legion-*.ps1') {
    $text = [IO.File]::ReadAllText($file.FullName)
    Assert-True ($text -cnotmatch '\.\s+\(Join-Path \$PSScriptRoot ''legion-(account|validate)\.ps1''\)') "$($file.Name) does not dot-source an entry script"
    Assert-True ($text -cnotmatch '\$(account|channel|launcher|status|setup)NoRun') "$($file.Name) keeps no saved NoRun copy"
}
Assert-True ([IO.File]::ReadAllText((Join-Path $bin 'lib/commands.ps1')) -cnotmatch 'legion-account\.ps1') 'lib/commands.ps1 does not load an entry script'
