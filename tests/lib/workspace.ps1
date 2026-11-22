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

function Write-TestPersonalisation {
    param([string]$HomeRoot, [object[]]$Agents = @(), [object[]]$Channels = @())
    $folder = Join-Path $HomeRoot '.legion/configuration'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $path = Join-Path $folder 'personalisation.json'
    @{ schemaVersion = 1; agents = @($Agents); channels = @($Channels) } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path
    return $path
}
