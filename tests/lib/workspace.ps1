. (Join-Path $PSScriptRoot 'guard.ps1')
. (Join-Path $PSScriptRoot 'paths.ps1')

function Set-TestExecutable {
    # Fake commands need the execute bit on macOS and Linux; Windows has no such bit.
    param([string]$Path)
    if ($IsWindows) { return }
    [IO.File]::SetUnixFileMode($Path, [IO.UnixFileMode]'UserRead, UserWrite, UserExecute')
}
