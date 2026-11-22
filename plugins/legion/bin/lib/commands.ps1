param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'paths.ps1')

function ConvertTo-LegionShellLiteral {
    param([string]$Value)
    return "'" + $Value.Replace("'", "'" + '"' + "'" + '"' + "'") + "'"
}

function Get-LegionShimText {
    param([string]$Script, [switch]$Windows, [string]$HomeRoot)

    $homeArgument = Get-LegionShimHomeArgument -HomeRoot $HomeRoot -Windows:$Windows
    $header = Get-LegionHeader -Name 'owner command' -Windows:$Windows
    if ($Windows) { return "$header`r`n" + '@pwsh -NoProfile -File "' + $Script.Replace('%', '%%') + '"' + $homeArgument + ' %* & (goto) 2>nul & exit /b' + "`r`n" }
    return "#!/bin/sh`n$header`n" + 'exec pwsh -NoProfile -File ' + (ConvertTo-LegionShellLiteral $Script) + $homeArgument + ' "$@"' + "`n"
}

function Get-LegionShimHomeArgument {
    param([string]$HomeRoot, [switch]$Windows)
    if (-not $HomeRoot) { return '' }
    $selectedHome = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($HomeRoot))
    $defaultHome = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($HOME))
    if ((Get-LegionPathComparer).Equals($selectedHome, $defaultHome)) { return '' }
    $literal = if ($Windows) { '"' + $selectedHome.Replace('%', '%%') + '"' } else { ConvertTo-LegionShellLiteral $selectedHome }
    return ' -HomeRoot ' + $literal
}

function Get-LegionOwnerCommandState {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 'missing' }
    if (-not (Test-LegionOwnerCommandFile -Path $Path)) { return 'blocked' }
    return 'owned'
}

# One state per command file, shared by setup and status.
function Get-LegionCommandState {
    param([string]$Bin, [string]$HomeRoot)
    $suffixes = if ($IsWindows) { @('', '.cmd') } else { @('') }
    foreach ($suffix in $suffixes) {
        $path = Join-Path $Bin "legion$suffix"
        $state = Get-LegionOwnerCommandState -Path $path
        if ($state -eq 'owned' -and -not (Test-LegionLauncherExecutable -Path $path)) { $state = 'permission' }
        [pscustomobject]@{ Name = 'legion'; Script = 'legion.ps1'; Path = $path; Windows = ($suffix -eq '.cmd'); State = $state }
    }
}

# Setup and refresh write the same platform command files, preserving unrelated files.
function Write-LegionOwnerCommands {
    param([string]$Bin, [string]$HomeRoot, [Collections.Generic.List[string]]$Changes)
    foreach ($file in (Get-LegionCommandState -Bin (Get-LegionHomePath -HomeRoot $HomeRoot -Path 'bin') -HomeRoot $HomeRoot)) {
        if ($file.State -eq 'blocked' -or -not (Test-LegionOwnerPathSafe -Path $file.Path -StopRoot $HomeRoot)) { continue }
        $text = Get-LegionShimText -Script (Join-Path $Bin $file.Script) -Windows:$file.Windows -HomeRoot $HomeRoot
        Write-LegionGeneratedFile -Path $file.Path -Content $text -Executable:(-not $file.Windows) -Changes $Changes
    }
}
