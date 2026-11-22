$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
    $runtimes = @((Get-Command pwsh -CommandType Application | Select-Object -First 1).Source)
    $sandbox = Join-Path $repo ('.agents/temp/generic-flow-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
    try {
        $installer = Join-Path $sandbox 'install.ps1'
        $catalog = Join-Path $sandbox 'tools.json'
        Copy-Item -LiteralPath (Join-Path $repo 'plugins/legion/install.ps1') -Destination $installer
        Copy-Item -LiteralPath (Join-Path $repo 'plugins/legion/tools.json') -Destination $catalog
        New-Item -ItemType Directory -Path (Join-Path $sandbox 'bin/lib') -Force | Out-Null
        Copy-Item (Join-Path $repo 'plugins/legion/bin/lib/paths.ps1') (Join-Path $sandbox 'bin/lib/paths.ps1')
        Copy-Item (Join-Path $repo 'plugins/legion/bin/lib/footprints.ps1') (Join-Path $sandbox 'bin/lib/footprints.ps1')
        $fixture = Join-Path $PSScriptRoot 'fixtures/install/Test-GenericFlow.ps1'
        foreach ($runtime in $runtimes) {
            foreach ($mode in @('fresh','cached','update','registered')) {
                $result = Invoke-ClosedInput -Command @($runtime, '-NoProfile', '-File', $fixture, '-Installer', $installer, '-Catalog', $catalog, '-Mode', $mode)
                Assert-Equal 0 $result.ExitCode "Standalone $mode succeeds in $runtime"
                Assert-True ($result.Output -contains "generic $mode passed") 'Every tool completes against fake remote metadata'
            }
        }
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe generic fixture cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
