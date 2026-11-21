$repo = Split-Path $PSScriptRoot -Parent
$bootstrap = Join-Path $repo 'install.ps1'
$plugin = Join-Path $repo 'plugins/legion/install.ps1'
Assert-True (Test-Path -LiteralPath $plugin) 'BootstrapParamsMatchInstaller: the installed copy ships its installer'
$signatures = foreach ($path in @($bootstrap, $plugin)) {
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    Assert-Equal 0 $errors.Count 'Installer parses without errors'
    (@($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath + ':' + $_.StaticType.FullName }) -join '|')
}
Assert-Equal $signatures[1] $signatures[0] 'BootstrapParamsMatchInstaller: names and types match'

& {
    . $plugin -NoRun
    . (Join-Path $PSScriptRoot 'fixtures/install/Test-RemoteInstaller.ps1') -Repo $repo -Installer $plugin -NoRun
    $scratch = Join-Path $repo ('.agents/temp/bootstrap-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $scratch 'plugins/legion') -Force | Out-Null
    try {
        $fakeBin = Join-Path $scratch 'bin'
        New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
        if ($env:OS -eq 'Windows_NT') {
            '@echo []' | Set-Content (Join-Path $fakeBin 'claude.cmd')
        } else {
            "#!/bin/sh`nprintf '[]\n'" | Set-Content (Join-Path $fakeBin 'claude')
            & chmod +x (Join-Path $fakeBin 'claude')
        }
        # A source folder supplies data only; its executable must never run.
        Copy-Item (Join-Path $repo 'plugins/legion/tools.json') (Join-Path $scratch 'plugins/legion/tools.json')
        'throw "Source installer executed"' | Set-Content (Join-Path $scratch 'plugins/legion/install.ps1')
        'throw "Source installer executed"' | Set-Content (Join-Path $scratch 'install.ps1')
        $runner = Join-Path $scratch 'invoke-text.ps1'
        New-InstallTextRunner -Path $runner
        $runtimes = @((Get-Command pwsh -CommandType Application | Select-Object -First 1).Source)
        $legacy = Get-Command powershell.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($legacy) { $runtimes += $legacy.Source }
        foreach ($runtime in $runtimes) {
            foreach ($branch in @('stable','main')) {
                $extra = @()
                if ($branch -eq 'main') { $extra = @('-Ref','main') }
                $result = Invoke-ClosedInput -Command (@($runtime, '-NoProfile', '-File', $runner, '-Installer', $bootstrap, '-Plugin', $plugin, '-Fixture', $scratch, '-CliPath', $fakeBin) + $extra)
                Assert-Equal 0 $result.ExitCode "BootstrapReleaseUrl: $($result.ErrorOutput -join ' ')"
                Assert-True ($result.Output -contains "download=https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/$branch/plugins/legion/install.ps1") "BootstrapReleaseUrl: $branch code is downloaded"
            }
            $result = Invoke-ClosedInput -Command @($runtime, '-NoProfile', '-File', $runner, '-Installer', $bootstrap, '-Plugin', $plugin, '-Fixture', $scratch, '-CliPath', $fakeBin, '-NoRelease')
            Assert-True ($result.ExitCode -ne 0) 'BootstrapNoRelease: failed release stops'
            Assert-True (($result.ErrorOutput -join ' ').Contains('could not find the latest release; try again or run with main')) 'BootstrapNoRelease: useful failure'
            Assert-Equal 1 @($result.Output | Where-Object { $_ -like 'download=*' }).Count 'BootstrapNoRelease: no fallback download'
            foreach ($case in @(
                @{ Name='BootstrapRunsPluginInstaller'; Installer=$bootstrap; Mode='text'; Downloads='downloads=1' }
                @{ Name='BootstrapCheckoutRunsOwnCopy'; Installer=$bootstrap; Mode='file'; Downloads='downloads=0' }
                @{ Name='PluginScriptText'; Installer=$plugin; Mode='text'; Downloads='downloads=0' }
            )) {
                $result = Invoke-ClosedInput -Command @($runtime, '-NoProfile', '-File', $runner, '-Installer', $case.Installer, '-Plugin', $plugin, '-Fixture', $scratch, '-Mode', $case.Mode, '-CliPath', $fakeBin)
                Assert-Equal 0 $result.ExitCode "$($case.Name) in ${runtime}: $($result.Output -join ' ') $($result.ErrorOutput -join ' ')"
                Assert-True (($result.Output -join "`n").Contains('claude plugin marketplace add')) "$($case.Name): switch reaches the real preview"
                Assert-True ($result.Output -contains $case.Downloads) "$($case.Name): executable comes from the expected location"
                Write-Output "PASS $($case.Name) / BootstrapSourceIsData ($runtime)"
            }
            $copy = Join-Path $scratch 'installed'
            New-Item -ItemType Directory -Path $copy -Force | Out-Null
            Copy-Item $plugin (Join-Path $copy 'install.ps1')
            $catalog = Get-Content (Join-Path $repo 'plugins/legion/tools.json') -Raw | ConvertFrom-Json
            $catalog.tools[0].installHint = 'sibling catalog selected'
            $catalog | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $copy 'tools.json')
            $result = Invoke-ClosedInput -Command @($runtime, '-NoProfile', '-File', $runner, '-Installer', (Join-Path $copy 'install.ps1'), '-Plugin', $plugin, '-Fixture', $scratch, '-Mode', 'catalog', '-Ref', 'main')
            Assert-Equal 0 $result.ExitCode "InstalledCopyCatalog: $($result.Output -join ' ') $($result.ErrorOutput -join ' ')"
            Assert-True (($result.Output -join "`n").Contains('sibling catalog selected')) 'RefKeepsSiblingCatalog: installed file uses its sibling catalog offline with main'
            Assert-True ($result.Output -contains 'downloads=0') 'InstalledCopyCatalog: no download'
            Write-Output "PASS InstalledCopyCatalog ($runtime)"
        }
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($scratch).StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe bootstrap cleanup' }
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}
