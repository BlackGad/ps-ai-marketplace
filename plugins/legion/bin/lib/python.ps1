. (Join-Path $PSScriptRoot 'paths.ps1')
. (Join-Path $PSScriptRoot 'process.ps1')

. (Join-Path $PSScriptRoot 'footprints.ps1')

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
    param([string[]]$Arguments = @(), [string]$HomeRoot = $HOME, [hashtable]$Environment = @{})

    $python = Get-LegionPythonCommand -Arguments $Arguments -HomeRoot $HomeRoot
    if (-not $python) {
        $pluginRoot = Resolve-LegionDirectoryPath (Join-Path $PSScriptRoot '../..')
        $output = @(
            'uv is missing. Ask the owner before installing it.'
            ('After the owner says yes: pwsh -NoProfile -File "' + (Join-Path $pluginRoot 'bin/legion-install-tool.ps1') + '" -Tool uv -Yes')
        )
        return @{ ExitCode = 127; Output = ($output -join "`n"); Error = '' }
    }
    $merged = $python.Environment.Clone()
    foreach ($name in $Environment.Keys) { $merged[$name] = $Environment[$name] }
    return Invoke-LegionProcess -Command $python.Command -Arguments $python.Arguments -Environment $merged
}
