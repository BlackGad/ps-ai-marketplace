. (Join-Path $PSScriptRoot 'paths.ps1')
. (Join-Path $PSScriptRoot 'process.ps1')

. (Join-Path $PSScriptRoot 'footprints.ps1')

$LegionUvMissing = 'uv is missing. Ask the owner before installing it, then run the legion installer again.'

# The uv command, or $null when uv is missing.
function Get-LegionUv {
    return Get-Command uv -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
}

# The words that select the home for a legion call: none for the user's home, else --home and the home.
function Get-LegionHomeArguments {
    param([string]$HomeRoot)
    if (-not $HomeRoot) { return @() }
    $selectedHome = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($HomeRoot))
    $defaultHome = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($HOME))
    if ((Get-LegionPathComparer).Equals($selectedHome, $defaultHome)) { return @() }
    return @('--home', $selectedHome)
}

# The uv command line for a legion call, or $null when uv is missing.
function Get-LegionPythonCommand {
    param([string[]]$Arguments = @(), [string]$HomeRoot = $HOME)

    $pluginRoot = Resolve-LegionDirectoryPath (Join-Path $PSScriptRoot '../..')
    $uv = Get-LegionUv
    if (-not $uv) { return $null }
    return @{
        Command = $uv.Source
        Arguments = @('run', '--project', $pluginRoot, '--frozen', 'legion') + @(Get-LegionHomeArguments -HomeRoot $HomeRoot) + $Arguments
        Environment = @{ UV_PROJECT_ENVIRONMENT = Get-LegionPythonEnvironment -PluginRoot $pluginRoot -HomeRoot $HomeRoot }
    }
}

function Invoke-LegionPython {
    param([string[]]$Arguments = @(), [string]$HomeRoot = $HOME)

    $python = Get-LegionPythonCommand -Arguments $Arguments -HomeRoot $HomeRoot
    if (-not $python) {
        $pluginRoot = Resolve-LegionDirectoryPath (Join-Path $PSScriptRoot '../..')
        $output = @(
            'uv is missing. Ask the owner before installing it.'
            ('After the owner says yes: pwsh -NoProfile -File "' + (Join-Path $pluginRoot 'bin/legion-install-tool.ps1') + '" -Tool uv -Yes')
        )
        return @{ ExitCode = 127; Output = ($output -join "`n"); Error = '' }
    }
    return Invoke-LegionProcess -Command $python.Command -Arguments $python.Arguments -Environment $python.Environment
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
    $source = Resolve-LegionDirectoryPath (Join-Path $PSScriptRoot '../..')
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
