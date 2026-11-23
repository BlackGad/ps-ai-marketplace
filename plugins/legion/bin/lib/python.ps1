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

# Ready app versions under ~/.legion/app, newest first: folders named for the version their manifest holds.
function Get-LegionAppVersions {
    param([string]$HomeRoot = $HOME)
    $app = Get-LegionHomePath -Path 'app' -HomeRoot $HomeRoot
    if (-not (Test-Path -LiteralPath $app -PathType Container)) { return @() }
    $versions = foreach ($folder in Get-ChildItem -LiteralPath $app -Directory -Force) {
        $version = $null
        if (-not [semver]::TryParse($folder.Name, [ref]$version)) { continue }
        try { $manifestVersion = Get-InstallPluginVersion -Root $folder.FullName } catch { continue }
        if ($manifestVersion -ceq $folder.Name) { [pscustomobject]@{ Version = $version; Path = $folder.FullName } }
    }
    return @($versions | Sort-Object Version -Descending)
}

# The owner command runs a copy of this plugin in ~/.legion/app/<version>, with that version's own environment.
# The copy is staged, renamed into place and then synced (the project installs as editable, so it syncs where it
# stays); a failed sync removes it, so a ready folder means a real success and the command keeps the old version.
function Sync-LegionApp {
    param([string]$HomeRoot = $HOME, [Collections.Generic.List[string]]$Changes)
    $source = Resolve-LegionDirectoryPath (Join-Path $PSScriptRoot '../..')
    $version = Get-InstallPluginVersion -Root $source
    $app = [IO.Path]::GetFullPath((Get-LegionHomePath -Path 'app' -HomeRoot $HomeRoot))
    $target = Join-Path $app $version
    if (-not (Test-LegionOwnerPathSafe -Path $target -StopRoot $HomeRoot)) { throw 'The legion app folder contains a link; resolve it before refreshing' }
    $ready = @(Get-LegionAppVersions -HomeRoot $HomeRoot)
    if ($ready.Count -and $ready[0].Version -gt [semver]$version) { "skip: legion app $version (newer $($ready[0].Version) in place)"; return }
    if (@($ready | Where-Object { (Get-LegionPathComparer).Equals($_.Path, $target) }).Count) { "skip: legion app $version (already done)" }
    elseif (Test-Path -LiteralPath $target) { "skip: $target (not legion's)"; return }
    else {
        $uv = Get-Command uv -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $uv) { 'uv is missing. Ask the owner before installing it, then run the legion installer again.'; return }
        $staging = Join-Path $app ('.staging-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $app -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $staging -Recurse
        [IO.Directory]::Move($staging, $target)
        $environment = Get-LegionPythonEnvironment -PluginRoot $target -HomeRoot $HomeRoot
        $result = Invoke-LegionProcess -Command $uv.Source -Arguments @('sync', '--project', $target, '--frozen', '--quiet') -Environment @{ UV_PROJECT_ENVIRONMENT = $environment }
        if ($result.ExitCode -ne 0) {
            Remove-Item -LiteralPath $target -Recurse -Force
            if ($result.Error.Trim()) { $result.Error.Trim() }
            "legion app $version not ready (uv sync exited $($result.ExitCode)); run legion setup again"
            return
        }
        "legion app $version ready"
        if ($null -ne $Changes) { $Changes.Add($target) }
    }
    foreach ($old in @($ready | Where-Object { $_.Version -lt [semver]$version })) {
        if (Remove-LegionAppVersion -Path $old.Path -HomeRoot $HomeRoot) { "removed legion app $($old.Version)" }
        else { "skip: legion app $($old.Version) (in use; removed at the next sync)" }
    }
}
