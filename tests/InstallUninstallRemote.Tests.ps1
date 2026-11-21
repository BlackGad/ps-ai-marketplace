$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
    $runtimes = @((Get-Command pwsh -CommandType Application | Select-Object -First 1).Source)
    $legacy = Get-Command powershell.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($legacy) { $runtimes += $legacy.Source }
    $sandbox = Join-Path $repo ('.agents/temp/uninstall-remote-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
    try {
        $installer = Join-Path $sandbox 'install.ps1'
        $catalog = Join-Path $sandbox 'tools.json'
        Copy-Item -LiteralPath (Join-Path $repo 'plugins/legion/install.ps1') -Destination $installer
        Copy-Item -LiteralPath (Join-Path $repo 'plugins/legion/tools.json') -Destination $catalog
        foreach ($runtime in $runtimes) {
            $result = Invoke-ClosedInput -Command @($runtime, '-NoProfile', '-File', (Join-Path $PSScriptRoot 'fixtures/install/Test-Uninstall.ps1'), '-Installer', $installer, '-Catalog', $catalog)
            Assert-Equal 0 $result.ExitCode "Standalone uninstall succeeds in $runtime ($($result.ErrorOutput -join ' '))"
            Assert-True ($result.Output -contains 'standalone uninstall passed') 'Downloaded script-block forwards uninstall and preserves unrelated files'
        }
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe uninstall remote cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
