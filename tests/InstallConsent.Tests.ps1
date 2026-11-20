$repo = Split-Path $PSScriptRoot -Parent
& {
    $fixtureHome = Join-Path $repo ('.agents/temp/install-consent-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $fixtureHome -Force | Out-Null
    try {
        # B4: the home chosen with -HomeRoot is the home for every install path, including the refresh.
        . (Join-Path $repo 'install.ps1') -NoRun -HomeRoot $fixtureHome
        Assert-Equal $fixtureHome (Get-InstallHome) 'B4: -HomeRoot selects the install home'
        Assert-Equal (Join-Path $fixtureHome '.legion/bin') (Get-InstallLegionPath 'bin') 'B4: legion paths follow the selected home'

        # P1: persistent changes need consent: -Yes, or an answer at the prompt.
        $script:answer = 'n'
        $script:prompts = 0
        $script:pathWrites = 0
        $script:installs = 0
        function Read-Host { param($Prompt) $script:prompts++; return $script:answer }
        $portable = Join-Path $fixtureHome 'pwsh.exe'
        function Get-InstallPowerShellCommand { return @{ Source = $portable } }
        function Get-InstallPortablePowerShell { return $portable }
        function Add-InstallPowerShellPath { param($Path) $script:pathWrites++ }
        function Get-UpdateConfigDirs { param($Tool, $ConfigDir) ,@('') }
        function Resolve-InstallSource { param($Source) return $Source }
        function Test-InstallCommandAvailable { param($Name) $true }
        function Invoke-PsAiInstallSteps { $script:installs++ }
        $null = Ensure-InstallPowerShell -OnWindows $true
        Assert-Equal 0 $script:pathWrites 'P1: a portable PowerShell does not touch the user PATH without consent'
        $script:answer = 'y'
        $null = Ensure-InstallPowerShell -OnWindows $true
        Assert-Equal 1 $script:pathWrites 'P1: the owner can say yes at the prompt'
        $null = Ensure-InstallPowerShell -OnWindows $true -Yes
        Assert-Equal 2 $script:pathWrites 'P1: -Yes repairs the PATH'
        $script:pathWrites = 0
        $null = Ensure-InstallPowerShell -OnWindows $true -DryRun
        Assert-Equal 0 $script:pathWrites 'P1: a dry run never repairs the PATH'

        $script:answer = 'n'
        $null = Invoke-PsAiInstaller -Catalog (Get-InstallCatalog -Source $repo) -Tools codex
        Assert-Equal 0 $script:installs 'P1: no install into the default account without consent'
        $script:answer = 'y'
        $null = Invoke-PsAiInstaller -Catalog (Get-InstallCatalog -Source $repo) -Tools codex
        Assert-Equal 1 $script:installs 'P1: the owner can say yes at the prompt'
        $script:prompts = 0
        $null = Invoke-PsAiInstaller -Catalog (Get-InstallCatalog -Source $repo) -Tools codex -Yes
        $null = Invoke-PsAiInstaller -Catalog (Get-InstallCatalog -Source $repo) -Tools codex -DryRun
        Assert-Equal 3 $script:installs '-Yes and a dry run both go on to the install steps'
        Assert-Equal 0 $script:prompts '-Yes and a dry run never prompt'
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if ([IO.Path]::GetFullPath($fixtureHome).StartsWith($allowed)) { Remove-Item -LiteralPath $fixtureHome -Recurse -Force }
    }
}
