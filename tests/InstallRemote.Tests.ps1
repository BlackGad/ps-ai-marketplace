# Installer runs in a child PowerShell process.
. (Join-Path $PSScriptRoot 'lib/installer.ps1')

Invoke-InstallTestCase 'ProcessEncoding' {
    . $installerPath -NoRun
    $child = Get-InstallTestPwsh
    $runtimes = @($child)
    foreach ($runtime in $runtimes) {
        # The PowerShell 7 installer launches an inert UTF-8 listing process with a separate warning.
        $result = Invoke-ClosedInput -Command @($runtime, '-NoProfile', '-File', (Join-Path $PSScriptRoot 'fixtures/install/Test-ListingProcess.ps1'), '-Installer', $installerPath, '-ChildRuntime', $child)
        Assert-Equal 0 $result.ExitCode "UTF-8 listing and EOF survive subprocess adapter ($($result.ErrorOutput -join ' '))"
        Assert-True ($result.Output -contains 'listing process passed') 'Real adapter preserves listing JSON, separate stderr, and closed stdin'
    }
}

Invoke-InstallTestCase 'RemoteFlow' {
    . $installerPath -NoRun
    $runtimes = @(Get-InstallTestPwsh)
    $sandbox = New-InstallTestFolder 'generic-flow'
    try {
        $installer = Join-Path $sandbox 'install.ps1'
        $catalog = Join-Path $sandbox 'tools.json'
        Copy-Item -LiteralPath $installerPath -Destination $installer
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
        Remove-InstallTestFolder $sandbox
    }
}

Invoke-InstallTestCase 'UninstallRemote' {
    . $installerPath -NoRun
    $runtimes = @(Get-InstallTestPwsh)
    $sandbox = New-InstallTestFolder 'uninstall-remote'
    try {
        $installer = Join-Path $sandbox 'install.ps1'
        $catalog = Join-Path $sandbox 'tools.json'
        Copy-Item -LiteralPath $installerPath -Destination $installer
        Copy-Item -LiteralPath (Join-Path $repo 'plugins/legion/tools.json') -Destination $catalog
        New-Item -ItemType Directory -Path (Join-Path $sandbox 'bin/lib') -Force | Out-Null
        Copy-Item (Join-Path $repo 'plugins/legion/bin/lib/paths.ps1') (Join-Path $sandbox 'bin/lib/paths.ps1')
        Copy-Item (Join-Path $repo 'plugins/legion/bin/lib/footprints.ps1') (Join-Path $sandbox 'bin/lib/footprints.ps1')
        foreach ($runtime in $runtimes) {
            $result = Invoke-ClosedInput -Command @($runtime, '-NoProfile', '-File', (Join-Path $PSScriptRoot 'fixtures/install/Test-Uninstall.ps1'), '-Installer', $installer, '-Catalog', $catalog)
            Assert-Equal 0 $result.ExitCode "Standalone uninstall succeeds in $runtime ($($result.ErrorOutput -join ' '))"
            Assert-True ($result.Output -contains 'standalone uninstall passed') 'Expanded archive forwards uninstall and preserves unrelated files'
        }
    } finally {
        Remove-InstallTestFolder $sandbox
    }
}
