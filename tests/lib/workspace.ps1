. (Join-Path $PSScriptRoot 'guard.ps1')
. (Join-Path $PSScriptRoot 'paths.ps1')

# Executable boundary for a fake CLI implemented in PowerShell.
function New-TestCommandStub {
    param([string]$Folder, [string]$Name, [string]$Script)
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    $path = Join-Path $Folder $(if ($IsWindows) { "$Name.cmd" } else { $Name })
    if ($IsWindows) {
        '@pwsh -NoProfile -File "' + $Script.Replace('%', '%%') + '" %*' | Set-Content -LiteralPath $path
    } else {
        $quoted = "'" + $Script.Replace("'", "'\''") + "'"
        "#!/bin/sh`nexec pwsh -NoProfile -File $quoted `"`$@`"" | Set-Content -LiteralPath $path
        [IO.File]::SetUnixFileMode($path, [IO.UnixFileMode]'UserRead, UserWrite, UserExecute')
    }
    return $path
}

function Set-TestExecutable {
    # Fake commands need the execute bit on macOS and Linux; Windows has no such bit.
    param([string]$Path)
    if ($IsWindows) { return }
    [IO.File]::SetUnixFileMode($Path, [IO.UnixFileMode]'UserRead, UserWrite, UserExecute')
}
