$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    $child = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
    $runtimes = @($child)
    $legacy = Get-Command powershell.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($legacy) { $runtimes += $legacy.Source }
    foreach ($runtime in $runtimes) {
        # Both parents launch an inert process that emits the CLI's UTF-8 JSON and a separate warning.
        $result = Invoke-ClosedInput -Command @($runtime, '-NoProfile', '-File', (Join-Path $PSScriptRoot 'fixtures/install/Test-ListingProcess.ps1'), '-Installer', (Join-Path $repo 'plugins/ps-ai/install.ps1'), '-ChildRuntime', $child)
        Assert-Equal 0 $result.ExitCode "UTF-8 listing and EOF survive subprocess adapter ($($result.ErrorOutput -join ' '))"
        Assert-True ($result.Output -contains 'listing process passed') 'Real adapter preserves listing JSON, separate stderr, and closed stdin'
    }
}
