. (Join-Path $PSScriptRoot 'paths.ps1')
. (Join-Path $PSScriptRoot 'process.ps1')

# One environment folder per plugin copy, so copies never rebuild each other's environment.
function Get-LegionPythonEnvironment {
    param([string]$PluginRoot, [string]$HomeRoot = $HOME)

    $absolute = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PluginRoot)
    $key = (Resolve-LegionDirectoryPath $absolute).TrimEnd('/', '\')
    if ($IsWindows) { $key = $key.ToLowerInvariant() }
    $hash = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($key))
    $digest = ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant().Substring(0, 12)
    return Get-LegionHomePath -Path "python/env-$digest" -HomeRoot $HomeRoot
}

# The uv command line for a legion-py call, or $null when uv is missing.
function Get-LegionPythonCommand {
    param([string[]]$Arguments = @(), [string]$HomeRoot = $HOME)

    $pluginRoot = Resolve-LegionDirectoryPath (Join-Path $PSScriptRoot '../..')
    $uv = Get-Command uv -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $uv) { return $null }
    return @{
        Command = $uv.Source
        Arguments = @('run', '--project', $pluginRoot, '--frozen', 'legion-py') + $Arguments
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
