param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'python.ps1')

function ConvertTo-LegionShellLiteral {
    param([string]$Value)
    return "'" + $Value.Replace("'", "'" + '"' + "'" + '"' + "'") + "'"
}

# The owner command runs the app version in $App through uv, with that version's environment.
# Windows: cmd reads a batch file in the console code page, so the text stays ASCII: the command lives in
# <home>/.legion/bin and finds the app, its environment and the home from its own folder (%~dp0).
# One line sets the environment, runs uv and ends the batch with (goto), so a command that an
# update rewrites while it runs still ends cleanly. Then, in the caller's context, it restores the caller's
# value and a child cmd exits with uv's code. `exit /b` there would close an interactive console, and
# %errorlevel% can be a caller's variable; the hidden %=ExitCode% (uv's code in hex) is neither. No
# setlocal: its end would reset %=ExitCode%.
function Get-LegionShimText {
    param([string]$App, [switch]$Windows, [string]$HomeRoot = $HOME)

    $environment = Get-LegionPythonEnvironment -PluginRoot $App -HomeRoot $HomeRoot
    $homeArgument = Get-LegionShimHomeArgument -HomeRoot $HomeRoot -Windows:$Windows
    $header = Get-LegionHeader -Name 'owner command' -Windows:$Windows
    if ($Windows) {
        $lines = @(
            $header
            '@where /q uv || (>&2 echo ' + $LegionUvMissing + '& exit /b 127)'
            ('@set "UV_PROJECT_ENVIRONMENT=%~dp0..\python\' + (Split-Path $environment -Leaf) + '" & uv run --project "%~dp0..\app\' + (Split-Path $App -Leaf) + '" --frozen --quiet legion' + $homeArgument + ' %* & (goto) 2>nul & ' +
                'set "UV_PROJECT_ENVIRONMENT=%UV_PROJECT_ENVIRONMENT%" & "%COMSPEC%" /d /c "set /a LEGION_EXIT=0x%%=ExitCode%% >nul & call exit %%^LEGION_EXIT%%"')
        )
        return ($lines -join "`r`n") + "`r`n"
    }
    $lines = @(
        '#!/bin/sh'
        $header
        "command -v uv >/dev/null 2>&1 || { echo '$LegionUvMissing' >&2; exit 127; }"
        'export UV_PROJECT_ENVIRONMENT=' + (ConvertTo-LegionShellLiteral $environment)
        'exec uv run --project ' + (ConvertTo-LegionShellLiteral $App) + ' --frozen --quiet legion' + $homeArgument + ' "$@"'
    )
    return ($lines -join "`n") + "`n"
}

function Get-LegionShimHomeArgument {
    param([string]$HomeRoot, [switch]$Windows)
    $words = @(Get-LegionHomeArguments -HomeRoot $HomeRoot)
    if (-not $words.Count) { return '' }
    $literal = if ($Windows) { '"%~dp0..\.."' } else { ConvertTo-LegionShellLiteral $words[1] }
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

# Setup and refresh write the same platform command files for one ready app version, preserving unrelated files.
function Write-LegionOwnerCommands {
    param([string]$App, [string]$HomeRoot, [Collections.Generic.List[string]]$Changes)
    foreach ($file in (Get-LegionCommandState -Bin (Get-LegionHomePath -HomeRoot $HomeRoot -Path 'bin') -HomeRoot $HomeRoot)) {
        if ($file.State -eq 'blocked' -or -not (Test-LegionOwnerPathSafe -Path $file.Path -StopRoot $HomeRoot)) { continue }
        $text = Get-LegionShimText -App $App -Windows:$file.Windows -HomeRoot $HomeRoot
        Write-LegionGeneratedFile -Path $file.Path -Content $text -Executable:(-not $file.Windows) -Changes $Changes
    }
}

# Setup and refresh: sync the app, point every command at the version sync made ready, and only then prune
# older versions. One sync runs at a time; the next one waits for it, then compares versions again.
function Publish-LegionApp {
    param([string]$HomeRoot = $HOME, [Collections.Generic.List[string]]$Changes)
    if (-not (Test-LegionOwnerPathSafe -Path (Get-LegionHomePath -Path 'app' -HomeRoot $HomeRoot) -StopRoot $HomeRoot)) { throw 'The legion app folder contains a link; resolve it before refreshing' }
    $lock = Wait-LegionLockFile -Path (Get-LegionHomePath -Path 'app/.sync.lock' -HomeRoot $HomeRoot) -Seconds 60
    if (-not $lock) { 'skip: legion app sync (another sync is still running; run legion setup again)'; return }
    try {
        $ready = $null
        Sync-LegionApp -HomeRoot $HomeRoot -Changes $Changes -ReadyPath ([ref]$ready)
        if (-not $ready) { 'skip: command legion (the legion app is not ready)'; return }
        Write-LegionOwnerCommands -App $ready -HomeRoot $HomeRoot -Changes $Changes
        Remove-LegionOldAppVersions -Keep $ready -HomeRoot $HomeRoot
    } finally { $lock.Dispose() }
}
