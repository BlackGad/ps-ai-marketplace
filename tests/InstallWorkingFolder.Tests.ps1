$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'install.ps1') -NoRun
    # Codex reads <cwd>/.codex/config.toml as project settings, so running from the home folder
    # leaks the default account's marketplaces into every other account.
    $callerFolder = Join-Path ([IO.Path]::GetTempPath()) ('ps-ai-cwd-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $callerFolder '.codex') -Force | Out-Null
    $child = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
    Push-Location -LiteralPath $callerFolder
    try {
        $result = Invoke-ClosedInput -Command @($child, '-NoProfile', '-Command', '(Get-Location).ProviderPath')
    } finally {
        Pop-Location
    }
    Remove-Item -LiteralPath (Join-Path $callerFolder '.codex')
    Remove-Item -LiteralPath $callerFolder
    Assert-Equal 0 $result.ExitCode 'Working folder probe runs'
    $expected = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    Assert-Equal $expected ($result.Output[0].TrimEnd('\', '/')) 'CLI processes run from the system temp folder, not the caller folder'
}
