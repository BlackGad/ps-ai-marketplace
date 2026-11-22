. (Join-Path $PSScriptRoot 'paths.ps1')
. (Join-Path $PSScriptRoot 'process.ps1')

function Invoke-LegionPython {
    param([string[]]$Arguments = @(), [string]$HomeRoot = $HOME)

    $pluginRoot = Resolve-LegionDirectoryPath (Join-Path $PSScriptRoot '../..')
    $uv = Get-Command uv -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $uv) {
        $output = @(
            'uv is missing. Ask the owner before installing it.'
            ('After the owner says yes: pwsh -NoProfile -File "' + (Join-Path $pluginRoot 'bin/legion-install-tool.ps1') + '" -Tool uv -Yes')
        )
        $output | ForEach-Object { Write-Host $_ }
        return @{ ExitCode = 127; Output = ($output -join "`n"); Error = '' }
    }

    $environment = @{ UV_PROJECT_ENVIRONMENT = Get-LegionHomePath -Path 'python/env' -HomeRoot $HomeRoot }
    $commandArguments = @('run', '--project', $pluginRoot, '--frozen', 'legion-py') + $Arguments
    return Invoke-LegionProcess -Command $uv.Source -Arguments $commandArguments -Environment $environment
}
