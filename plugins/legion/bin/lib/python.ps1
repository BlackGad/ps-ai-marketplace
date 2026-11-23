. (Join-Path $PSScriptRoot 'paths.ps1')
. (Join-Path $PSScriptRoot 'process.ps1')

. (Join-Path $PSScriptRoot 'footprints.ps1')

# The uv command line for a legion call, or $null when uv is missing.
function Get-LegionPythonCommand {
    param([string[]]$Arguments = @(), [string]$HomeRoot = $HOME)

    $pluginRoot = Resolve-LegionDirectoryPath (Join-Path $PSScriptRoot '../..')
    $uv = Get-Command uv -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $uv) { return $null }
    return @{
        Command = $uv.Source
        Arguments = @('run', '--project', $pluginRoot, '--frozen', 'legion') + $Arguments
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

# Ready app versions, newest first: recorded, safe and marked (see Test-LegionAppVersionSafe).
function Get-LegionAppVersions {
    param([string]$HomeRoot = $HOME)
    $versions = foreach ($entry in @(Get-LegionFootprints -HomeRoot $HomeRoot -Kind app-version)) {
        $path = Get-LegionAppVersionPath -Entry $entry -HomeRoot $HomeRoot
        $version = $null
        if (-not [semver]::TryParse((Split-Path $path -Leaf), [ref]$version)) { continue }
        if ((Test-Path -LiteralPath $path) -and (Test-LegionAppVersionSafe -Path $path -HomeRoot $HomeRoot)) { [pscustomobject]@{ Version = $version; Path = $path } }
    }
    return @($versions | Sort-Object Version -Descending)
}

# The owner command runs a copy of this plugin in ~/.legion/app/<version>, with that version's own environment.
# The copy is staged, recorded, renamed into place and then synced there (the project installs as editable);
# the marker is written only after uv sync succeeds. A recorded folder without the marker is unfinished and
# the next sync repairs it. Sets $ReadyPath to the ready version the commands should run, or leaves it $null.
function Sync-LegionApp {
    param([string]$HomeRoot = $HOME, [Collections.Generic.List[string]]$Changes, [ref]$ReadyPath)
    $source = Resolve-LegionDirectoryPath (Join-Path $PSScriptRoot '../..')
    $version = Get-InstallPluginVersion -Root $source
    $app = [IO.Path]::GetFullPath((Get-LegionHomePath -Path 'app' -HomeRoot $HomeRoot))
    $target = Join-Path $app $version
    if (-not (Test-LegionOwnerPathSafe -Path $target -StopRoot $HomeRoot)) { throw 'The legion app folder contains a link; resolve it before refreshing' }
    $ready = @(Get-LegionAppVersions -HomeRoot $HomeRoot)
    if ($ready.Count) { $ReadyPath.Value = $ready[0].Path }
    if ($ready.Count -and $ready[0].Version -gt [semver]$version) { "skip: legion app $version (newer $($ready[0].Version) in place)"; return }
    if ($ready.Count -and (Get-LegionPathComparer).Equals($ready[0].Path, $target)) { "skip: legion app $version (already done)"; return }
    $recorded = @(Get-LegionFootprints -HomeRoot $HomeRoot -Kind app-version | Where-Object { (Get-LegionPathComparer).Equals((Get-LegionAppVersionPath -Entry $_ -HomeRoot $HomeRoot), $target) }).Count
    if ((Test-Path -LiteralPath $target) -and -not $recorded) { "skip: $target (not legion's)"; return }
    if ($recorded -and -not (Test-LegionOwnerPathSafe -Path (Get-LegionPythonEnvironment -PluginRoot $target -HomeRoot $HomeRoot) -StopRoot $HomeRoot)) { "skip: $target (linked environment)"; return }
    $uv = Get-Command uv -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $uv) { 'uv is missing. Ask the owner before installing it, then run the legion installer again.'; return }
    if (-not (Test-Path -LiteralPath $target)) {
        $staging = Join-Path $app ('.staging-' + [guid]::NewGuid().ToString('N'))
        Copy-Item -LiteralPath $source -Destination $staging -Recurse
        Add-LegionFootprint -HomeRoot $HomeRoot -Kind app-version -Path $target -Owner legion
        [IO.Directory]::Move($staging, $target)
    }
    $environment = Get-LegionPythonEnvironment -PluginRoot $target -HomeRoot $HomeRoot
    $result = Invoke-LegionProcess -Command $uv.Source -Arguments @('sync', '--project', $target, '--frozen', '--quiet') -Environment @{ UV_PROJECT_ENVIRONMENT = $environment }
    if ($result.ExitCode -ne 0) {
        if ($result.Error.Trim()) { $result.Error.Trim() }
        "legion app $version not ready (uv sync exited $($result.ExitCode)); run legion setup again"
        return
    }
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
