$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
    $child = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
    $runtimes = @($child)
    foreach ($runtime in $runtimes) {
        # The PowerShell 7 installer launches an inert UTF-8 listing process with a separate warning.
        $result = Invoke-ClosedInput -Command @($runtime, '-NoProfile', '-File', (Join-Path $PSScriptRoot 'fixtures/install/Test-ListingProcess.ps1'), '-Installer', (Join-Path $repo 'plugins/legion/install.ps1'), '-ChildRuntime', $child)
        Assert-Equal 0 $result.ExitCode "UTF-8 listing and EOF survive subprocess adapter ($($result.ErrorOutput -join ' '))"
        Assert-True ($result.Output -contains 'listing process passed') 'Real adapter preserves listing JSON, separate stderr, and closed stdin'
    }
}
