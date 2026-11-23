param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'python.ps1')

function ConvertTo-LegionShellLiteral {
    param([string]$Value)
    return "'" + $Value.Replace("'", "'" + '"' + "'" + '"' + "'") + "'"
}

# The owner command runs the app version in $App through uv, with that version's environment.
# Windows: setlocal keeps the environment out of the caller's console. The run line ends the batch with
# (goto), so a command that an update rewrites while it runs still ends cleanly; a child cmd then exits
# with uv's code, which `exit /b` cannot do here without closing an interactive console.
function Get-LegionShimText {
    param([string]$App, [switch]$Windows, [string]$HomeRoot = $HOME)

    $environment = Get-LegionPythonEnvironment -PluginRoot $App -HomeRoot $HomeRoot
    $homeArgument = Get-LegionShimHomeArgument -HomeRoot $HomeRoot -Windows:$Windows
    $missing = 'uv is missing. Ask the owner before installing it, then run the legion installer again.'
    $header = Get-LegionHeader -Name 'owner command' -Windows:$Windows
    if ($Windows) {
        $lines = @(
            $header
            '@setlocal'
            '@set "UV_PROJECT_ENVIRONMENT=' + $environment.Replace('%', '%%') + '"'
            '@where /q uv || (>&2 echo ' + $missing + '& exit /b 127)'
            '@uv run --project "' + $App.Replace('%', '%%') + '" --frozen --quiet legion' + $homeArgument + ' %* & (goto) 2>nul & call "%%COMSPEC%%" /d /c exit %%errorlevel%%'
        )
        return ($lines -join "`r`n") + "`r`n"
    }
    $lines = @(
        '#!/bin/sh'
        $header
        "command -v uv >/dev/null 2>&1 || { echo '$missing' >&2; exit 127; }"
        'export UV_PROJECT_ENVIRONMENT=' + (ConvertTo-LegionShellLiteral $environment)
        'exec uv run --project ' + (ConvertTo-LegionShellLiteral $App) + ' --frozen --quiet legion' + $homeArgument + ' "$@"'
    )
    return ($lines -join "`n") + "`n"
}

function Get-LegionShimHomeArgument {
    param([string]$HomeRoot, [switch]$Windows)
    if (-not $HomeRoot) { return '' }
    $selectedHome = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($HomeRoot))
    $defaultHome = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($HOME))
    if ((Get-LegionPathComparer).Equals($selectedHome, $defaultHome)) { return '' }
    $literal = if ($Windows) { '"' + $selectedHome.Replace('%', '%%') + '"' } else { ConvertTo-LegionShellLiteral $selectedHome }
    return ' --home ' + $literal
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

# Setup and refresh write the same platform command files for the newest ready app, preserving unrelated files.
function Write-LegionOwnerCommands {
    param([string]$HomeRoot, [Collections.Generic.List[string]]$Changes)
    $app = @(Get-LegionAppVersions -HomeRoot $HomeRoot)[0].Path
    if (-not $app) { 'skip: command legion (the legion app is not ready)'; return }
    foreach ($file in (Get-LegionCommandState -Bin (Get-LegionHomePath -HomeRoot $HomeRoot -Path 'bin') -HomeRoot $HomeRoot)) {
        if ($file.State -eq 'blocked' -or -not (Test-LegionOwnerPathSafe -Path $file.Path -StopRoot $HomeRoot)) { continue }
        $text = Get-LegionShimText -App $app -Windows:$file.Windows -HomeRoot $HomeRoot
        Write-LegionGeneratedFile -Path $file.Path -Content $text -Executable:(-not $file.Windows) -Changes $Changes
    }
}
