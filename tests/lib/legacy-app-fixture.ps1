# Test stand-in for what `legion refresh` does in Python (app sync, owner commands, prune), so the setup and
# footprint tests can still see a published app. The real behaviour is proven by tests/python/legion/test_app.py,
# test_shim.py and test_refresh.py; milestone 4 removes setup and these tests with it.
$LegionUvMissing = 'uv is missing. Ask the owner before installing it, then run the legion installer again.'

function Write-LegionGeneratedFile {
    param([string]$Path, [string]$Content, [Collections.Generic.List[string]]$Changes, [switch]$Executable)
    $same = (Test-Path -LiteralPath $Path) -and [IO.File]::ReadAllText($Path) -ceq $Content
    $changed = -not $same
    if (-not $same) {
        New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
        [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
    }
    if ($Executable -and -not $IsWindows -and -not (Test-LegionLauncherExecutable -Path $Path)) {
        [IO.File]::SetUnixFileMode($Path, [IO.File]::GetUnixFileMode($Path) -bor [IO.UnixFileMode]::UserExecute)
        $changed = $true
    }
    if ($changed -and $null -ne $Changes) { $Changes.Add($Path) }
}

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

# Ready app versions, newest first: recorded, safe (see Test-LegionAppVersionSafe) and marked.
function Get-LegionAppVersions {
    param([string]$HomeRoot = $HOME)
    $versions = foreach ($entry in @(Get-LegionFootprints -HomeRoot $HomeRoot -Kind app-version)) {
        $path = Get-LegionAppVersionPath -Entry $entry -HomeRoot $HomeRoot
        $version = $null
        if (-not [semver]::TryParse((Split-Path $path -Leaf), [ref]$version)) { continue }
        if ((Test-Path -LiteralPath (Get-LegionAppMarker $path) -PathType Leaf) -and (Test-LegionAppVersionSafe -Path $path -HomeRoot $HomeRoot)) { [pscustomobject]@{ Version = $version; Path = $path } }
    }
    return @($versions | Sort-Object Version -Descending)
}

# The owner command runs a copy of this plugin in ~/.legion/app/<version>, with that version's own environment.
# The copy is staged, recorded, renamed into place and then synced there (the project installs as editable);
# the marker is written only after uv sync succeeds and the version still holds no link. A recorded folder
# without the marker is unfinished: never run, repaired by the next sync of its version or removed with the
# older ones. Sets $ReadyPath to the ready version the commands should run, or leaves it $null.
function Sync-LegionApp {
    param([string]$HomeRoot = $HOME, [Collections.Generic.List[string]]$Changes, [ref]$ReadyPath)
    $source = Resolve-LegionDirectoryPath (Join-Path $PSScriptRoot '../../plugins/legion')
    $version = Get-InstallPluginVersion -Root $source
    $app = [IO.Path]::GetFullPath((Get-LegionHomePath -Path 'app' -HomeRoot $HomeRoot))
    $target = Join-Path $app $version
    $environment = Get-LegionPythonEnvironment -PluginRoot $target -HomeRoot $HomeRoot
    $ready = @(Get-LegionAppVersions -HomeRoot $HomeRoot)
    if ($ready.Count) { $ReadyPath.Value = $ready[0].Path }
    if ($ready.Count -and $ready[0].Version -gt [semver]$version) { "skip: legion app $version (newer $($ready[0].Version) in place)"; return }
    if ($ready.Count -and (Get-LegionPathComparer).Equals($ready[0].Path, $target)) { "skip: legion app $version (already done)"; return }
    $recorded = @(Get-LegionFootprints -HomeRoot $HomeRoot -Kind app-version | Where-Object { (Get-LegionPathComparer).Equals((Get-LegionAppVersionPath -Entry $_ -HomeRoot $HomeRoot), $target) }).Count
    if ((Test-Path -LiteralPath $target) -and -not $recorded) { "skip: $target (not legion's)"; return }
    if (-not (Test-LegionOwnerPathSafe -Path $target -StopRoot $HomeRoot) -or -not (Test-LegionOwnerPathSafe -Path $environment -StopRoot $HomeRoot)) { "skip: $target (linked version or environment)"; return }
    $uv = Get-LegionUv
    if (-not $uv) { $LegionUvMissing; return }
    if (-not (Test-Path -LiteralPath $target)) {
        $staging = Join-Path $app ('.staging-' + [guid]::NewGuid().ToString('N'))
        Copy-Item -LiteralPath $source -Destination $staging -Recurse
        Add-LegionFootprint -HomeRoot $HomeRoot -Kind app-version -Path $target -Owner legion
        [IO.Directory]::Move($staging, $target)
    }
    $result = Invoke-LegionProcess -Command $uv.Source -Arguments @('sync', '--project', $target, '--frozen', '--quiet') -Environment @{ UV_PROJECT_ENVIRONMENT = $environment }
    if ($result.ExitCode -ne 0) {
        if ($result.Error.Trim()) { $result.Error.Trim() }
        "legion app $version not ready (uv sync exited $($result.ExitCode)); run legion setup again"
        return
    }
    if (-not (Test-LegionAppVersionSafe -Path $target -HomeRoot $HomeRoot)) { "skip: $target (linked)"; return }
    [IO.File]::WriteAllText((Get-LegionAppMarker $target), '')
    "legion app $version ready"
    if ($null -ne $Changes) { $Changes.Add($target) }
    $ReadyPath.Value = $target
}

# After the commands run $Keep: removes recorded versions older than the ready one before it, which a
# running legion may still use. A version that cannot go yet stays recorded for the next sync.
function Remove-LegionOldAppVersions {
    param([string]$Keep, [string]$HomeRoot = $HOME)
    $keepVersion = [semver](Split-Path $Keep -Leaf)
    $previous = @(Get-LegionAppVersions -HomeRoot $HomeRoot | Where-Object Version -LT $keepVersion | Select-Object -First 1)
    foreach ($entry in @(Get-LegionFootprints -HomeRoot $HomeRoot -Kind app-version)) {
        $path = Get-LegionAppVersionPath -Entry $entry -HomeRoot $HomeRoot
        $version = $null
        if (-not [semver]::TryParse((Split-Path $path -Leaf), [ref]$version) -or $version -ge $keepVersion) { continue }
        if ($previous.Count -and (Get-LegionPathComparer).Equals($path, $previous[0].Path)) { continue }
        if (-not (Test-LegionAppVersionSafe -Path $path -HomeRoot $HomeRoot)) { "skip: $path (linked or not legion's)"; continue }
        if (-not (Remove-LegionAppVersion -Path $path -HomeRoot $HomeRoot)) { "skip: legion app $version (in use; removed at the next sync)"; continue }
        Remove-LegionFootprintEntry -HomeRoot $HomeRoot -Kind app-version -Path $path
        "removed legion app $version"
    }
}
