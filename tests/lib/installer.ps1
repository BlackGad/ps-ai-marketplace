# Shared helpers for tests/Install*.Tests.ps1. A test file dot-sources this once.
# It defines $repo, so a test file needs no setup line of its own.
. (Join-Path $PSScriptRoot 'workspace.ps1')
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$installerPath = Join-Path $repo 'plugins/legion/install.ps1'

function New-InstallTestFolder {
    # A new empty folder under the runner's linked temp.
    param([string]$Name)
    $path = Join-Path (Get-TestTempPath) ($Name + '-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Remove-InstallTestFolder {
    param([string]$Path)
    Remove-TestFolder -Path $Path -AllowedParent (Get-TestTempPath)
}

function Get-InstallTestPwsh {
    return (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
}

function Invoke-InstallTestCase {
    # One named section of a test file. It runs in its own scope, so functions a section
    # defines are gone afterwards, and it puts back every process setting the installer reads.
    param([string]$Name, [scriptblock]$Body)
    $variables = @('HOME', 'USERPROFILE', 'PATH', 'OS', 'CLAUDE_CONFIG_DIR', 'CODEX_HOME', 'COPILOT_HOME')
    $saved = @{}
    foreach ($variable in $variables) { $saved[$variable] = [Environment]::GetEnvironmentVariable($variable, 'Process') }
    $savedLocation = Get-Location
    # Each section loads its own catalog.
    $script:installCatalog = $null
    try {
        & $Body
        "PASS $Name"
    } catch {
        throw "$Name`: $($_.Exception.Message)"
    } finally {
        foreach ($variable in $variables) { [Environment]::SetEnvironmentVariable($variable, $saved[$variable], 'Process') }
        Set-Location -LiteralPath $savedLocation
    }
}
