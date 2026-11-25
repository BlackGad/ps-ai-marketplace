# Runs the root bootstrap with fakes in the PowerShell that runs this file (5.1 or 7): no network, no real uv.
param([string]$Installer, [string]$Mode, [string]$Scratch, [string]$Archive)
$ErrorActionPreference = 'Stop'
. $Installer -NoRun
$script:installHomeRoot = $Scratch
$script:downloads = [Collections.Generic.List[string]]::new()
$script:scriptRuns = 0
$uvLog = Join-Path $Scratch 'uv-log.txt'
$env:FAKE_UV_LOG = $uvLog
$env:FAKE_UV_EXIT = '0'
$onWindows = $env:OS -eq 'Windows_NT'
$uvName = 'uv'
if ($onWindows) { $uvName = 'uv.cmd' }
# A PATH with no uv on it, but with the system tools the bootstrap needs.
function Set-NoUvPath {
    if ($onWindows) { $env:PATH = Join-Path $env:SystemRoot 'System32' } else { $env:PATH = '/usr/bin:/bin' }
}

function Invoke-InstallDownload {
    param([string]$Url, [string]$OutFile)
    $script:downloads.Add($Url)
    if ($Url -like '*/archive/refs/heads/*') {
        if ($script:Mode -eq 'no-release') { throw 'HTTP 404' }
        Copy-Item -LiteralPath $script:Archive -Destination $OutFile
    } else { Set-Content -LiteralPath $OutFile -Value 'uv installer stand-in' }
}
function Invoke-InstallUvScript {
    param([string]$Script)
    $script:scriptRuns++
    # The real installer script puts uv into ~/.local/bin and the owner's next shell finds it; the stand-in does both.
    $folder = Join-Path (Join-Path $Scratch '.local') 'bin'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path (Join-Path $Scratch 'fake-uv-source') $uvName) -Destination (Join-Path $folder $uvName)
    $env:PATH = $folder + [IO.Path]::PathSeparator + $env:PATH
    return 0
}
function Read-Host { param($Prompt) $script:prompts++; return $script:answer }
$script:prompts = 0
$script:answer = 'n'

function Show-Result {
    Write-Output ("downloads=" + ($script:downloads -join ','))
    Write-Output "scriptRuns=$($script:scriptRuns)"
    Write-Output "prompts=$($script:prompts)"
    Write-Output "exit=$($script:bootstrapExitCode)"
    if (Test-Path -LiteralPath $uvLog) { Get-Content -LiteralPath $uvLog | ForEach-Object { Write-Output "uv:$_" } }
    $left = @(Get-ChildItem -LiteralPath (Join-Path $Scratch '.legion/temp') -Force -ErrorAction SilentlyContinue)
    Write-Output "tempLeft=$($left.Count)"
}

$parameters = @{ Yes = [switch]$true; Tools = @('claude'); HomeRoot = $Scratch }
switch ($Mode) {
    'checkout' { Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot (Join-Path $Scratch 'checkout') }
    'remote' { Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot '' }
    'remote-main' { $parameters.Ref = 'main'; Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot '' }
    'no-release' { Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot '' }
    'exit-code' { $env:FAKE_UV_EXIT = '3'; Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot (Join-Path $Scratch 'checkout') }
    'uv-missing-yes' {
        # No uv on PATH: -Yes installs it through uv's own script, then the hand-over runs.
        Set-NoUvPath
        Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot (Join-Path $Scratch 'checkout')
    }
    'uv-missing-dry' {
        Set-NoUvPath
        $parameters.DryRun = [switch]$true
        Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot (Join-Path $Scratch 'checkout')
    }
    'uv-missing-declined' {
        Set-NoUvPath
        $parameters.Remove('Yes')
        Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot (Join-Path $Scratch 'checkout')
    }
    'find-folder' {
        Set-NoUvPath
        $folder = Join-Path (Join-Path $Scratch '.local') 'bin'
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        $name = 'uv'
        if ($onWindows) { $name = 'uv.exe' }
        Set-Content -LiteralPath (Join-Path $folder $name) -Value ''
        Write-Output ('found=' + (Get-InstallUv))
        return
    }
    default { throw "unknown mode $Mode" }
}
Show-Result
