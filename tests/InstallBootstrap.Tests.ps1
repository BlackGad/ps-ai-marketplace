# Bootstrap stub, PowerShell bootstrap and POSIX shell launcher.
. (Join-Path $PSScriptRoot 'lib/installer.ps1')

Invoke-InstallTestCase 'Bootstrap' {
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

    . $plugin -NoRun
    . (Join-Path $PSScriptRoot 'fixtures/install/Test-RemoteInstaller.ps1') -Repo $repo -Installer $plugin -NoRun
    $scratch = New-InstallTestFolder 'bootstrap'
    New-Item -ItemType Directory -Path (Join-Path $scratch 'plugins/legion') -Force | Out-Null
    try {
        $fakeBin = Join-Path $scratch 'bin'
        New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
        if ($env:OS -eq 'Windows_NT') {
            '@echo []' | Set-Content (Join-Path $fakeBin 'claude.cmd')
        } else {
            "#!/bin/sh`nprintf '[]\n'" | Set-Content (Join-Path $fakeBin 'claude')
            Set-TestExecutable (Join-Path $fakeBin 'claude')
        }
        # A source folder supplies data only; its executable must never run.
        Copy-Item (Join-Path $repo 'plugins/legion/tools.json') (Join-Path $scratch 'plugins/legion/tools.json')
        'throw "Source installer executed"' | Set-Content (Join-Path $scratch 'plugins/legion/install.ps1')
        'throw "Source installer executed"' | Set-Content (Join-Path $scratch 'install.ps1')
        $archivePlugin=Join-Path $scratch 'archive/single-top/plugins/legion'
        New-Item -ItemType Directory -Path (Join-Path $archivePlugin 'bin/lib') -Force | Out-Null
        Copy-Item $plugin (Join-Path $archivePlugin 'install.ps1')
        Copy-Item (Join-Path $repo 'plugins/legion/tools.json') (Join-Path $archivePlugin 'tools.json')
        Copy-Item (Join-Path $repo 'plugins/legion/bin/lib/paths.ps1') (Join-Path $archivePlugin 'bin/lib/paths.ps1')
        Copy-Item (Join-Path $repo 'plugins/legion/bin/lib/footprints.ps1') (Join-Path $archivePlugin 'bin/lib/footprints.ps1')
        $archive=Join-Path $scratch 'plugin.zip'
        Compress-Archive -Path (Join-Path $scratch 'archive/single-top') -DestinationPath $archive
        $runner = Join-Path $scratch 'invoke-text.ps1'
        New-InstallTextRunner -Path $runner
        $runtimes = @(Get-InstallTestPwsh)
        $legacy = Get-Command powershell.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($legacy) { $runtimes += $legacy.Source }
        foreach ($runtime in $runtimes) {
            foreach ($branch in @('stable','main')) {
                $extra = @()
                if ($branch -eq 'main') { $extra = @('-Ref','main') }
                $result = Invoke-ClosedInput -Command (@($runtime, '-NoProfile', '-File', $runner, '-Installer', $bootstrap, '-Plugin', $plugin, '-Archive', $archive, '-Fixture', $scratch, '-CliPath', $fakeBin, '-Mode', 'text') + $extra)
                Assert-Equal 0 $result.ExitCode "BootstrapReleaseUrl: $($result.ErrorOutput -join ' ')"
                Assert-True ($result.Output -contains "download=https://github.com/BlackGad/ps-legion-marketplace/archive/refs/heads/$branch.zip") "BootstrapReleaseUrl: $branch code is downloaded"
            }
            $result = Invoke-ClosedInput -Command @($runtime, '-NoProfile', '-File', $runner, '-Installer', $bootstrap, '-Plugin', $plugin, '-Archive', $archive, '-Fixture', $scratch, '-CliPath', $fakeBin, '-Mode', 'text', '-NoRelease')
            Assert-True ($result.ExitCode -ne 0) 'BootstrapNoRelease: failed release stops'
            Assert-True (($result.ErrorOutput -join ' ').Contains('could not find the latest release; try again or run with main')) 'BootstrapNoRelease: useful failure'
            Assert-Equal 1 @($result.Output | Where-Object { $_ -like 'download=*' }).Count 'BootstrapNoRelease: no fallback download'
            foreach ($case in @(
                @{ Name='BootstrapRunsPluginInstaller'; Installer=$bootstrap; Mode='text'; Downloads='downloads=1' }
                @{ Name='BootstrapCheckoutRunsOwnCopy'; Installer=$bootstrap; Mode='file'; Downloads='downloads=0' }
                @{ Name='PluginArchive'; Installer=$plugin; Mode='file'; Downloads='downloads=0' }
            )) {
                $caseRuntime=if ($case.Installer -eq $plugin) { $runtimes[0] } else { $runtime }
                $result = Invoke-ClosedInput -Command @($caseRuntime, '-NoProfile', '-File', $runner, '-Installer', $case.Installer, '-Plugin', $plugin, '-Archive', $archive, '-Fixture', $scratch, '-Mode', $case.Mode, '-CliPath', $fakeBin)
                Assert-Equal 0 $result.ExitCode "$($case.Name) in ${runtime}: $($result.Output -join ' ') $($result.ErrorOutput -join ' ')"
                Assert-True (($result.Output -join "`n").Contains('claude plugin marketplace add')) "$($case.Name): switch reaches the real preview ($($result.Output -join ' '); $($result.ErrorOutput -join ' '))"
                Assert-True ($result.Output -contains $case.Downloads) "$($case.Name): executable comes from the expected location"
                Write-Output "PASS $($case.Name) / BootstrapSourceIsData ($runtime)"
            }
            $copy = Join-Path $scratch 'installed'
            New-Item -ItemType Directory -Path $copy -Force | Out-Null
            Copy-Item $plugin (Join-Path $copy 'install.ps1')
            New-Item -ItemType Directory -Path (Join-Path $copy 'bin/lib') -Force | Out-Null
            Copy-Item (Join-Path $repo 'plugins/legion/bin/lib/paths.ps1') (Join-Path $copy 'bin/lib/paths.ps1')
            Copy-Item (Join-Path $repo 'plugins/legion/bin/lib/footprints.ps1') (Join-Path $copy 'bin/lib/footprints.ps1')
            $catalog = Get-Content (Join-Path $repo 'plugins/legion/tools.json') -Raw | ConvertFrom-Json
            $catalog.tools[0].installHint = 'sibling catalog selected'
            $catalog | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $copy 'tools.json')
            $result = Invoke-ClosedInput -Command @($runtimes[0], '-NoProfile', '-File', $runner, '-Installer', (Join-Path $copy 'install.ps1'), '-Plugin', $plugin, '-Archive', $archive, '-Fixture', $scratch, '-Mode', 'catalog', '-Ref', 'main')
            Assert-Equal 0 $result.ExitCode "InstalledCopyCatalog: $($result.Output -join ' ') $($result.ErrorOutput -join ' ')"
            Assert-True (($result.Output -join "`n").Contains('sibling catalog selected')) 'RefKeepsSiblingCatalog: installed file uses its sibling catalog offline with main'
            Assert-True ($result.Output -contains 'downloads=0') 'InstalledCopyCatalog: no download'
            Write-Output "PASS InstalledCopyCatalog ($runtime)"
        }
    } finally {
        Remove-InstallTestFolder $scratch
    }
}

Invoke-InstallTestCase 'BootstrapPowerShell' {
    & {
    . (Join-Path $Repo 'install.ps1') -NoRun
    $script:installCatalog = Get-Content (Join-Path $Repo 'tests/fixtures/install/catalog.json') -Raw | ConvertFrom-Json
    # RootBootstrapUsesLatestZipRecipe: change id, source, pattern and layout together.
    $script:installCatalog.bootstrap.windows.wingetId = 'Example.PowerShell'
    $script:installCatalog.bootstrap.windows.portableCommand = 'bin/shell.exe'
    $script:installCatalog.bootstrap.windows.download.zip.metadataUrl = 'https://fixture.test/latest'
    $script:installCatalog.bootstrap.windows.download.zip.assetPattern = '^Shell-[\d.]+-x64\.zip$'
    $script:installCatalog.bootstrap.windows.download.zip.pathFolder = 'bin'
    & {
        $state = @{ Command='' }
        function winget { $state.Command=(@('winget') + $args) -join '|'; $global:LASTEXITCODE=0 }
        Assert-Equal 0 (Invoke-InstallWinget) 'Catalog winget command succeeds'
        Assert-Equal 'winget|install|--id|Example.PowerShell|-e' $state.Command 'Winget id is catalog data'
    }
    $sandbox = New-InstallTestFolder 'restructure/remote-install'
    $savedPath = $env:PATH
    $fixturePwshExe = Get-InstallTestPwsh
    $windowsPowerShell = Get-Command powershell.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $state = @{ Present=$false; Winget=$false; WingetExit=5; Calls=0; Downloads=0; Digest=('0' * 64); UserPath='fixture-existing'; Writes=0; Prompts=0; Answer='n' }
    $downloaded = [Collections.Generic.List[string]]::new()
    function Get-InstallHome { $sandbox }
    function Get-InstallPowerShellCommand {
        if ($state.Present) { return @{ Source='fixture-pwsh' } }
        $portable = Join-Path $sandbox '.legion/tools/pwsh/bin/shell.exe'
        if (Test-Path -LiteralPath $portable) { return @{ Source=$portable } }
    }
    function Test-InstallCommandAvailable { param($Name) $Name -eq 'winget' -and $state.Winget }
    function Invoke-InstallWinget { $state.Calls++; return $state.WingetExit }
    function Get-InstallUserPath { $state.UserPath }
    function Set-InstallUserPath { param($Path) $state.Writes++; $state.UserPath = $Path }
    function Read-Host { param($Prompt) $state.Prompts++; return $state.Answer }
    function Invoke-InstallDownload {
        param($Url, $OutFile)
        $state.Downloads++
        $downloaded.Add($OutFile)
        if ($Url -eq 'https://fixture.test/latest') {
            @{ tag_name='v7.7.0'; assets=@(@{ name='Shell-7.7.0-x64.zip'; browser_download_url='https://fixture.test/pwsh.zip'; digest=$state.Digest }) } |
                ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutFile
        } elseif ($Url -eq 'https://fixture.test/pwsh.zip') { Copy-Item -LiteralPath $fixtureArchive -Destination $OutFile }
        else { throw "unexpected test download: $Url" }
    }
    try {
        $preview = @(& { $script:ready = Ensure-InstallPowerShell -OnWindows $true -DryRun } 6>&1) -join "`n"
        Assert-True ($preview.Contains('winget install --id Example.PowerShell -e')) 'Missing pwsh dry run shows winget'
        Assert-True ($preview.Contains('SHA-256')) 'Missing pwsh dry run shows ZIP option'
        Assert-Equal 0 $state.Downloads 'Dry run has no network'
        Assert-Equal 0 $state.Calls 'Dry run never runs winget'
        Assert-Equal 0 $state.Prompts 'Dry run never prompts'
        Assert-Equal 0 $state.Writes 'Dry run never writes user PATH'
        Assert-Equal $savedPath $env:PATH 'Dry run preserves process PATH'
        $state.Present = $true
        $skip = @(& { $script:ready = Ensure-InstallPowerShell -OnWindows $true } 6>&1) -join "`n"
        Assert-True $script:ready 'Present pwsh is ready'
        Assert-True ($skip.Contains('skip: PowerShell 7 (already done)')) 'Present pwsh skips'
        Assert-Equal 0 $state.Downloads 'Present pwsh never downloads'
        $state.Present = $false
        $null = & { $script:ready = Ensure-InstallPowerShell -OnWindows $true } 6>&1
        Assert-True (-not $script:ready) 'Declined install stops'
        Assert-Equal 0 $state.Downloads 'Declined install never downloads'
        $docs = @(& { $script:ready = Ensure-InstallPowerShell -OnWindows $false -Yes } 6>&1) -join "`n"
        Assert-True (-not $script:ready) 'Non-Windows missing pwsh stops'
        Assert-True ($docs.Contains('https://learn.microsoft.com/powershell/scripting/install/')) 'Non-Windows gives official install link'
        Assert-Equal 0 $state.Downloads 'Non-Windows never downloads'

        $archiveFolder = Join-Path $sandbox 'archive'
        New-Item -ItemType Directory -Path (Join-Path $archiveFolder 'bin') -Force | Out-Null
        'inert fixture, never execute' | Set-Content -LiteralPath (Join-Path $archiveFolder 'bin/shell.exe')
        $fixtureArchive = Join-Path $sandbox 'fixture.zip'
        Compress-Archive -Path (Join-Path $archiveFolder '*') -DestinationPath $fixtureArchive
        $state.Digest = 'sha256:' + ('0' * 64)
        $failure = ''
        try { $null = Ensure-InstallPowerShell -OnWindows $true -Yes } catch { $failure = $_.Exception.Message }
        Assert-True ($failure -match 'SHA-256.*mismatch') 'Digest mismatch stops installation'
        Assert-True (-not (Test-Path -LiteralPath $downloaded[$downloaded.Count - 1])) 'Digest mismatch deletes download'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $sandbox '.legion/tools/pwsh'))) 'Digest mismatch never unpacks'
        Assert-Equal 0 $state.Writes 'Digest mismatch never writes PATH'
        Assert-Equal $savedPath $env:PATH 'Digest mismatch preserves process PATH'
        $state.Digest = ''
        Assert-Throws { Ensure-InstallPowerShell -OnWindows $true -Yes | Out-Null } 'Missing digest stops installation'
        $state.Digest = 'sha256:' + (Get-FileHash -LiteralPath $fixtureArchive -Algorithm SHA256).Hash.ToLowerInvariant()
        $state.Winget = $true
        $null = & { $script:ready = Ensure-InstallPowerShell -OnWindows $true -Yes } 6>&1
        Assert-True $script:ready 'Failed winget falls back to verified ZIP'
        Assert-Equal 1 $state.Calls 'Winget tried once before ZIP'
        $portableFolder = Join-Path $sandbox '.legion/tools/pwsh/bin'
        Assert-True (Test-Path -LiteralPath (Join-Path $portableFolder 'shell.exe')) 'Verified ZIP unpacks per user'
        Assert-True ($state.UserPath.Contains($portableFolder)) 'ZIP adds user PATH'
        Assert-True ($env:PATH.Contains($portableFolder)) 'ZIP adds process PATH'
        Assert-Equal 1 $state.Writes 'ZIP writes user PATH once'
        $downloadCount = $state.Downloads
        $null = & { Ensure-InstallPowerShell -OnWindows $true -Yes } 6>&1
        Add-InstallPowerShellPath -Path $portableFolder
        Assert-Equal $downloadCount $state.Downloads 'Repeat ZIP installation never downloads'
        Assert-Equal 1 $state.Writes 'Repeat ZIP installation never duplicates user PATH'
        Assert-Equal 1 @($env:PATH -split [regex]::Escape([IO.Path]::PathSeparator) | Where-Object { $_ -eq $portableFolder }).Count 'Process PATH contains folder once'
        # The installer records the portable folder for purge only when the stub added it to the user PATH.
        Assert-Equal $portableFolder $env:LEGION_PORTABLE_PATH_ADDED 'The stub tells the installer it added the user PATH entry'
        $env:LEGION_PORTABLE_PATH_ADDED = $null
        Add-InstallPowerShellPath -Path $portableFolder
        Assert-Equal $null $env:LEGION_PORTABLE_PATH_ADDED 'An entry already on the user PATH is not reported as added'

        # Portable PATH repair retains explicit consent, including repeats and dry runs.
        $state.Answer='n'
        $beforeWrites=$state.Writes
        $state.UserPath='fixture-existing'
        $env:PATH=$savedPath
        $null=Ensure-InstallPowerShell -OnWindows $true
        Assert-Equal $beforeWrites $state.Writes 'Portable PATH stays unchanged after no'
        $state.Answer='y'
        $null=Ensure-InstallPowerShell -OnWindows $true
        Assert-Equal ($beforeWrites + 1) $state.Writes 'User PATH repaired only after yes'
        Assert-True ($env:PATH.Contains($portableFolder)) 'Portable PATH restored in this process after yes'
        $env:PATH=$savedPath
        $state.UserPath='fixture-existing'
        $null=Ensure-InstallPowerShell -OnWindows $true -DryRun
        Assert-Equal ($beforeWrites + 1) $state.Writes 'Dry run never repairs user PATH'
        Assert-Equal $savedPath $env:PATH 'Dry run never repairs portable PATH'
        $null=Ensure-InstallPowerShell -OnWindows $true -Yes
        Assert-Equal ($beforeWrites + 2) $state.Writes 'Yes repairs portable user PATH'
        Assert-True ($env:PATH.Contains($portableFolder)) 'Yes repairs portable process PATH'
        # The one check the stub keeps on the catalog: the PATH folder stays inside the portable folder.
        Remove-Item -LiteralPath (Join-Path $sandbox '.legion/tools') -Recurse -Force
        $writes = $state.Writes
        $script:installCatalog.bootstrap.windows.download.zip.pathFolder = '../escape'
        Assert-Throws { Install-PowerShellZip } 'A catalog pathFolder outside the portable folder stops before PATH'
        Assert-Equal $writes $state.Writes 'A rejected pathFolder never writes PATH'
        Write-Output 'PASS stub verified ZIP, fallback, repeats and portable PATH consent'
    } finally {
        $env:PATH=$savedPath
        $env:LEGION_PORTABLE_PATH_ADDED = $null
        Remove-InstallTestFolder $sandbox
    }
    }
}

Invoke-InstallTestCase 'BootstrapMinimumVersion' {
    # A pwsh older than 7.4 counts as missing for the stub; 7.4 and later (also a preview) count as present.
    . (Join-Path $repo 'install.ps1') -NoRun
    $script:installCatalog = Get-Content (Join-Path $repo 'plugins/legion/tools.json') -Raw | ConvertFrom-Json
    $scratch = New-InstallTestFolder 'min-version'
    $script:installHomeRoot = $scratch
    $savedProgramFiles = $env:ProgramFiles
    try {
        $fake = Join-Path $scratch 'fake-bin'
        New-Item -ItemType Directory -Path $fake -Force | Out-Null
        if ($env:OS -eq 'Windows_NT') {
            '@echo %FAKE_PWSH_VERSION%' | Set-Content -LiteralPath (Join-Path $fake 'pwsh.cmd')
            $env:PATH = $fake + [IO.Path]::PathSeparator + (Join-Path $env:SystemRoot 'System32')
        } else {
            "#!/bin/sh`necho `"`$FAKE_PWSH_VERSION`"" | Set-Content -LiteralPath (Join-Path $fake 'pwsh')
            [IO.File]::SetUnixFileMode((Join-Path $fake 'pwsh'), [IO.UnixFileMode]'UserRead, UserWrite, UserExecute')
            $env:PATH = $fake
        }
        $env:ProgramFiles = Join-Path $scratch 'program-files'
        foreach ($case in @(@('7.3.12', $false), @('6.2.0', $false), @('', $false), @('7.4.0', $true), @('7.5.0-preview.2', $true), @('8.0.1', $true))) {
            $env:FAKE_PWSH_VERSION = $case[0]
            Assert-Equal $case[1] ($null -ne (Get-InstallPowerShellCommand)) "pwsh '$($case[0])' present: $($case[1])"
        }
        $env:FAKE_PWSH_VERSION = '7.3.12'
        $output = @(& { $script:ready = Ensure-InstallPowerShell -OnWindows $false } 6>&1) -join "`n"
        Assert-True (-not $script:ready) 'An old pwsh stops a non-Windows run'
        Assert-True ($output.Contains('PowerShell 7 is missing.')) 'An old pwsh is reported as missing'
    } finally {
        $env:ProgramFiles = $savedProgramFiles
        Remove-Item Env:FAKE_PWSH_VERSION -ErrorAction SilentlyContinue
        Remove-InstallTestFolder $scratch
    }
}

Invoke-InstallTestCase 'InstallerMinimumVersion' {
    # The plugin installer names 7.4 as its minimum and stops below it (the check is raised in a copy to prove it runs).
    . $installerPath -NoRun
    $scratch = New-InstallTestFolder 'min-installer'
    try {
        $text = [IO.File]::ReadAllText($installerPath)
        $raised = $text.Replace("-lt [version]'7.4'", "-lt [version]'99.0'")
        Assert-True ($raised -cne $text) 'The installer states its PowerShell 7.4 minimum'
        [IO.File]::WriteAllText((Join-Path $scratch 'install.ps1'), $raised)
        $result = Invoke-ClosedInput -Command @((Get-InstallTestPwsh), '-NoProfile', '-File', (Join-Path $scratch 'install.ps1'), '-NoRun')
        Assert-True ($result.ExitCode -ne 0) 'An older PowerShell stops the installer'
        Assert-True (($result.ErrorOutput -join ' ').Contains('PowerShell 7.4')) 'The refusal names PowerShell 7.4'
    } finally { Remove-InstallTestFolder $scratch }
}

Invoke-InstallTestCase 'BootstrapShared' {
    & {
        . $installerPath -NoRun
        $script:installCatalog = Get-InstallCatalog -Source $repo
        $script:askedOwnerPath = ''
        function Get-LegionOwnerPath { param($Name,$HomeRoot) $script:askedOwnerPath = $Name; 'shared' }
        $null = Get-UpdateConfigDirs -Tool claude
        Assert-Equal 'Settings' $script:askedOwnerPath 'Installer calls shared owner paths'
        $message=''
        try { & ([scriptblock]::Create((Get-Content $installerPath -Raw))) -NoRun } catch { $message=$_.Exception.Message }
        Assert-True ($message.Contains('expanded archive')) 'Installer clearly refuses script text without PSScriptRoot'
        $scratch = New-InstallTestFolder 'missing-lib'
        try {
            $copy=Join-Path $scratch 'install.ps1'
            Copy-Item $installerPath $copy
            $message=''
            try { & $copy -NoRun } catch { $message=$_.Exception.Message }
            Assert-True ($message.Contains('bin/lib/paths.ps1')) 'Installer clearly refuses missing library'
            $physical=Join-Path $scratch 'physical'
            $linked=Join-Path $scratch 'linked'
            $fixtureHome=Join-Path $linked 'home'
            New-Item -ItemType Directory -Path (Join-Path $physical 'home'),(Join-Path $scratch 'outside') -Force | Out-Null
            $linkType=if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
            New-Item -ItemType $linkType -Path $linked -Target $physical | Out-Null
            Assert-True (Test-LegionOwnerPathSafe -Path (Join-Path $fixtureHome 'future-file') -StopRoot $fixtureHome) 'Link walk stops at home before a linked ancestor'
            $inner=Join-Path $fixtureHome 'linked-child'
            New-Item -ItemType $linkType -Path $inner -Target (Join-Path $scratch 'outside') | Out-Null
            Assert-True (-not (Test-LegionOwnerPathSafe -Path (Join-Path $inner 'future-file') -StopRoot $fixtureHome)) 'Link inside home is rejected'
            Assert-Throws { Test-LegionOwnerPathSafe -Path (Join-Path $scratch 'outside') -StopRoot $fixtureHome } 'Link walk rejects a path outside its stop root'
        } finally {
            if ($inner -and (Test-Path -LiteralPath $inner)) { [IO.Directory]::Delete($inner) }
            if ($linked -and (Test-Path -LiteralPath $linked)) { [IO.Directory]::Delete($linked) }
            Remove-InstallTestFolder $scratch
        }
    }
    # Keep the 7.4 LTS baseline visible while CI runs the latest PowerShell 7.
    # Later-than-7.4 commands and parameters, and the external chmod command (use [IO.File]::SetUnixFileMode), are not allowed.
    foreach ($file in Get-ChildItem (Join-Path $repo 'plugins/legion') -Recurse -File -Filter '*.ps1') {
        $text=Get-Content -LiteralPath $file.FullName -Raw
        Assert-True ($text -notmatch '\b(ConvertTo|ConvertFrom)-CliXml\b|\bTest-Path\b[^\r\n]*\s-(OlderThan|NewerThan)\b') "7.4 baseline: $($file.Name)"
        Assert-True ($text -notmatch '(?m)^[^#\r\n]*(&\s*|^\s*)chmod\b') "No external chmod: $($file.Name)"
        if ($text -match '-DateKind\b') {
            $tokens=$null; $errors=$null
            $ast=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
            foreach ($command in $ast.FindAll({param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.Extent.Text -match '-DateKind\b'},$true)) {
                $parent=$command.Parent
                while ($parent -and $parent -isnot [Management.Automation.Language.IfStatementAst]) { $parent=$parent.Parent }
                Assert-True ($parent -and $parent.Clauses[0].Item1.Extent.Text -match "Parameters.ContainsKey\('DateKind'\)") 'DateKind requires parameter-exists check'
            }
        }
    }
}

Invoke-InstallTestCase 'BootstrapStub' {
    . (Join-Path $repo 'install.ps1') -NoRun
    $scratch = New-InstallTestFolder 'stub'
    $savedPath = $env:PATH
    $savedOS = $env:OS
    try {
        $pwsh = Get-InstallTestPwsh
        $archiveRoot = Join-Path $scratch 'archive/single-top/plugins/legion'
        New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
        Copy-Item (Join-Path $repo 'plugins/legion/tools.json') (Join-Path $archiveRoot 'tools.json')
        @'
param([string[]]$Tools, [string]$Source, [string]$ConfigDir, [switch]$DryRun, [switch]$Yes,
    [switch]$Update, [switch]$Uninstall, [switch]$Purge, [string]$Ref, [string]$HomeRoot)
if (-not $DryRun -and -not $Yes -and (Read-Host 'Install fixture plugin? [y/N]') -notmatch '^(y|yes)$') {
    'Nothing changed. Run again with -Yes to apply.'
    return
}
@{ Tools=$Tools; Source=$Source; ConfigDir=$ConfigDir; DryRun=[bool]$DryRun; Yes=[bool]$Yes;
    Update=[bool]$Update; Uninstall=[bool]$Uninstall; Purge=[bool]$Purge; Ref=$Ref;
    Major=$PSVersionTable.PSVersion.Major } | ConvertTo-Json | Set-Content (Join-Path $HomeRoot 'record.json')
if ($ConfigDir -eq 'exit 23') { exit 23 }
'fixture installer ran'
'@ | Set-Content (Join-Path $archiveRoot 'install.ps1')
        $zip = Join-Path $scratch 'fixture.zip'
        Compress-Archive -Path (Join-Path $scratch 'archive/single-top') -DestinationPath $zip
        $state = @{ Downloads=0; Url=''; Missing=$false; Answer='n'; Prompts=0 }
        function Get-InstallPowerShellCommand { if (-not $state.Missing) { @{Source=$pwsh} } }
        function Invoke-WebRequest {
            param($Uri, $OutFile)
            $Url = $Uri
            $state.Downloads++; $state.Url=$Url
            Assert-True ($OutFile.EndsWith('.zip')) 'Archive filename has zip extension'
            Copy-Item -LiteralPath $zip -Destination $OutFile
        }
        function Invoke-InstallWinget { throw 'Installing tools forbidden' }
        function Install-PowerShellZip { throw 'Installing tools forbidden' }
        function Read-Host { param($Prompt) $state.Prompts++; $state.Answer }
        function Set-InstallUserPath { throw 'Registry writes forbidden' }
        foreach ($branch in @('stable','main')) {
            $parameters = @{Tools=@('claude','codex');Source='example/market';ConfigDir='folder with spaces';
                DryRun=[switch]::new($true);Yes=$true;Update=$true;Uninstall=$true;Purge=$true;HomeRoot=$scratch}
            if ($branch -eq 'main') { $parameters.Ref='main' }
            $null = Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot ''
            $record = Get-Content (Join-Path $scratch 'record.json') -Raw | ConvertFrom-Json
            Assert-Equal 'claude|codex' ($record.Tools -join '|') 'Typed tools array survives pwsh'
            Assert-Equal 'folder with spaces' $record.ConfigDir 'ConfigDir with spaces survives pwsh'
            Assert-True ($record.DryRun -and $record.Yes -and $record.Update -and $record.Uninstall -and $record.Purge) 'Typed switches survive pwsh'
            Assert-Equal 'example/market' $record.Source 'Source is data only'
            Assert-True ($record.Major -ge 7) 'Plugin runs under PowerShell 7'
            Assert-Equal "https://github.com/BlackGad/ps-legion-marketplace/archive/refs/heads/$branch.zip" $state.Url 'Code archive comes from fixed repository'
            Assert-Equal 0 @(Get-ChildItem (Join-Path $scratch '.legion/temp') -Directory -Filter 'install-*').Count 'Expanded archive cleaned up'
        }
        Write-Output 'PASS stub archive, typed arguments and BootstrapSourceIsData'
        $parameters.Update=[switch]::new($false)
        $null=Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot ''
        Assert-True (-not (Get-Content (Join-Path $scratch 'record.json') -Raw | ConvertFrom-Json).Update) 'False switch stays false across pwsh'
        $parameters.ConfigDir='exit 23'
        $null = Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot ''
        Assert-Equal 23 $script:bootstrapExitCode 'Non-zero installer exit code survives pwsh'
        $runner=Join-Path $scratch 'exit-entry.ps1'
        @'
param($Stub,$Archive,$Fixture)
if ($PSVersionTable.PSVersion.Major -lt 7) { $env:PSModulePath=Join-Path $PSHOME 'Modules' }
$script:fixtureZip=$Archive
function Invoke-WebRequest { param($Uri,$OutFile) Copy-Item -LiteralPath $script:fixtureZip -Destination $OutFile }
& ([scriptblock]::Create((Get-Content -LiteralPath $Stub -Raw))) -HomeRoot $Fixture -Tools @('claude','codex') -ConfigDir 'exit 23' -DryRun
'@ | Set-Content -LiteralPath $runner
        $runtime=(Get-Process -Id $PID).Path
        $exitOutput=@(& $runtime -NoProfile -File $runner -Stub (Join-Path $repo 'install.ps1') -Archive $zip -Fixture $scratch 2>&1)
        Assert-Equal 23 $LASTEXITCODE "Root entry point returns installer exit code ($($exitOutput -join ' '))"
        Write-Output 'PASS stub preserves installer exit code'
        $parameters.ConfigDir='local checkout'
        $downloads = $state.Downloads
        $null = Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot (Join-Path $scratch 'archive/single-top')
        Assert-Equal $downloads $state.Downloads 'Local checkout skips archive download'
        Assert-True ((Get-Content (Join-Path $scratch 'record.json') -Raw | ConvertFrom-Json).Major -ge 7) 'Local checkout goes through pwsh'
        Write-Output 'PASS local checkout runs through pwsh'
        Remove-Item -LiteralPath (Join-Path $scratch 'record.json')
        $state.Missing=$true
        $env:OS='Windows_NT'
        $parameters = @{ HomeRoot=$scratch; DryRun=$true }
        $preview = @(& { Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot '' } 6>&1) -join "`n"
        Assert-True ($preview.Contains('winget install --id Microsoft.PowerShell -e')) 'Missing pwsh offers bootstrap'
        Assert-Equal 0 $state.Prompts 'Dry run never prompts'
        Assert-True (-not (Test-Path (Join-Path $scratch 'record.json'))) 'Missing pwsh dry run never starts installer'
        $parameters.DryRun=$false
        $declined = @(& { Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot '' } 6>&1) -join "`n"
        Assert-True ($declined.Contains('Nothing changed')) 'Decline reports no changes'
        Assert-Equal 0 $script:bootstrapExitCode 'Decline exits zero'
        Assert-True (-not (Test-Path (Join-Path $scratch 'record.json'))) 'Decline never starts installer'
        Write-Output 'PASS missing pwsh offers bootstrap and decline runs nothing'
        # Compose the bootstrap and plugin questions at the process boundary, with no real installation.
        function Get-InstallPowerShellCommand { if (-not $state.Missing) { @{Source='Invoke-FixturePowerShell'} } }
        function Test-InstallCommandAvailable { param($Name) $Name -eq 'winget' }
        function Invoke-InstallWinget { $state.Calls++; if ($state.ZipFallback) { 5 } else { $state.Missing=$false; 0 } }
        function Install-PowerShellZip { $state.Zip++; $state.Missing=$false }
        function Read-Host {
            param($Prompt)
            $state.Prompts++
            if (-not $state.Answers.Count) { throw 'Unexpected prompt' }
            $answer=$state.Answers[0]
            $state.Answers=@($state.Answers | Select-Object -Skip 1)
            $answer
        }
        function Invoke-FixturePowerShell {
            param([switch]$NoProfile,[scriptblock]$Command,[Alias('args')][object[]]$InputArguments)
            $path=$InputArguments[0]; $forwarded=$InputArguments[1]
            & $path @forwarded
            $global:LASTEXITCODE=0
        }
        foreach ($fallback in @($false,$true)) {
            $state.ZipFallback=$fallback
            $state.Missing=$true; $state.Calls=0; $state.Zip=0; $state.Prompts=0; $state.Answers=@('y','n')
            $declined=@(Invoke-InstallBootstrap -Parameters @{HomeRoot=$scratch} -CheckoutRoot '') -join "`n"
            Assert-Equal 2 $state.Prompts 'Bootstrap yes still requires plugin consent'
            Assert-Equal 1 $state.Calls 'PowerShell consent permits one winget attempt'
            Assert-Equal ([int]$fallback) $state.Zip 'Failed winget uses ZIP under the PowerShell consent'
            Assert-True ($declined.Contains('Nothing changed')) 'Plugin decline reports no changes'
            Assert-True (-not (Test-Path (Join-Path $scratch 'record.json'))) 'Plugin decline never installs plugin'
            $state.Missing=$true; $state.Prompts=0; $state.Answers=@('y','y')
            $null=Invoke-InstallBootstrap -Parameters @{HomeRoot=$scratch} -CheckoutRoot ''
            Assert-Equal 2 $state.Prompts 'Both bootstrap and plugin ask before installing'
            Assert-True (Test-Path (Join-Path $scratch 'record.json')) 'Two yes answers permit plugin installation'
            Remove-Item -LiteralPath (Join-Path $scratch 'record.json')
            $state.Missing=$true; $state.Prompts=0; $state.Answers=@()
            $null=Invoke-InstallBootstrap -Parameters @{HomeRoot=$scratch;Yes=[switch]::new($true)} -CheckoutRoot ''
            Assert-Equal 0 $state.Prompts 'Yes skips both questions'
            Assert-True (Test-Path (Join-Path $scratch 'record.json')) 'Yes permits plugin installation after bootstrap'
            Remove-Item -LiteralPath (Join-Path $scratch 'record.json')
        }
        Write-Output 'PASS separate PowerShell and plugin consent, ZIP fallback and Yes'
        function Invoke-WebRequest { throw 'Fixture release unavailable' }
        $message=''
        try { Invoke-InstallBootstrap -Parameters @{HomeRoot=$scratch} -CheckoutRoot '' } catch { $message=$_.Exception.Message }
        Assert-True ($message.Contains('could not find the latest release')) 'Missing release keeps useful error'
        Assert-Equal 0 @(Get-ChildItem (Join-Path $scratch '.legion/temp') -Directory -Filter 'install-*').Count 'Failed archive cleaned up'
        Write-Output 'PASS stub release error and cleanup'
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            $message=''
            try { & $installerPath -NoRun } catch { $message=$_.Exception.Message }
            Assert-True ($message.Contains('PowerShell 7')) 'Plugin refusal names required runtime'
            Write-Output 'PASS installer refuses 5.1'
        }
    } finally {
        $env:PATH=$savedPath
        $env:OS=$savedOS
        Remove-InstallTestFolder $scratch
    }
}

Invoke-InstallTestCase 'CommaSeparatedTools' {
    . $installerPath -NoRun
    $catalog = Get-Content (Join-Path $PSScriptRoot 'fixtures/install/catalog.json') -Raw | ConvertFrom-Json
    $seen = [System.Collections.Generic.List[string]]::new()
    function Invoke-ClosedInput { throw 'No child process expected' }
    function Get-UpdateConfigDirs { ,@('fixture-account') }
    function Invoke-LegionInstallSteps { param($Tool) $seen.Add($Tool) }
    $output = @(Invoke-LegionInstaller -Catalog $catalog -Tools @('codex,claude', 'copilot') -DryRun)
    Assert-Equal 'codex|claude|copilot' ($seen -join '|') 'Comma-separated and array tool selections keep their order'
    Assert-True ($output -contains 'Install legion for codex, claude, copilot') 'Install summary lists split tool ids'
    function Invoke-LegionUninstall { param($Tools) foreach ($tool in $Tools) { $seen.Add($tool) } }
    $seen.Clear()
    $null = Invoke-LegionInstaller -Catalog $catalog -Tools 'codex,claude' -Uninstall -DryRun
    Assert-Equal 'codex|claude' ($seen -join '|') 'Uninstall receives split tool ids too'
}

Invoke-InstallTestCase 'Shell' {
    # The shell bootstrap needs no PowerShell, JSON utility, package manager or sudo.
    $launcher = Join-Path $repo 'install.sh'
    Assert-True (Test-Path -LiteralPath $launcher) 'POSIX bootstrap exists'
    Assert-True (-not ([IO.File]::ReadAllText($launcher)).Contains("`r")) 'Shell bootstrap uses LF'
    $shell = Get-Command sh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($shell) {
        & $shell.Source -n $launcher
        Assert-Equal 0 $LASTEXITCODE 'Shell bootstrap parses'
    }
    if ($IsWindows) { return } # macOS and Linux CI execute the fake-driven cases below.

    & {
        $scratch = New-InstallTestFolder 'install-shell'
        $saved = @{}
        $variables = @('HOME', 'PATH', 'FAKE_ROOT', 'FAKE_REAL_PWSH', 'FAKE_PWSH_PRESENT', 'FAKE_OS', 'FAKE_CPU', 'FAKE_EXIT', 'FAKE_SHA256SUM')
        foreach ($name in $variables) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
        try {
            $bin = Join-Path $scratch 'bin'
            New-Item -ItemType Directory -Path $bin -Force | Out-Null
            Copy-Item -LiteralPath $launcher -Destination (Join-Path $scratch 'install.sh')
            $launcher = Join-Path $scratch 'install.sh'
            $env:FAKE_ROOT = $scratch
            $env:FAKE_REAL_PWSH = (Get-Process -Id $PID).Path
            $env:FAKE_OS = 'Linux'
            $env:FAKE_CPU = 'x86_64'
            $env:FAKE_EXIT = '0'
            $env:FAKE_SHA256SUM = (Get-Command sha256sum -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
            $env:PATH = $bin + [IO.Path]::PathSeparator + $env:PATH
            $pwshFake = @'
#!/bin/sh
if [ "$2" = '-Command' ]; then
    [ "$FAKE_PWSH_PRESENT" = 1 ] || [ "$0" = "$HOME/.legion/tools/pwsh/pwsh" ]
    exit $?
fi
exec "$FAKE_REAL_PWSH" "$@"
'@
            $curlFake = @'
#!/bin/sh
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o) output=$2; shift 2 ;;
        -w) format=$2; shift 2 ;;
        -*) shift ;;
        *) url=$1; shift ;;
    esac
done
printf '%s\n' "$url" >> "$FAKE_ROOT/downloads"
case "$url" in
    */install.ps1) cp "$FAKE_ROOT/stub.ps1" "$output" ;;
    https://github.com/PowerShell/PowerShell/releases/latest)
        [ "$format" = '%{url_effective}' ] && [ "$output" = /dev/null ] || exit 1
        cat "$FAKE_ROOT/redirect" ;;
    */hashes.sha256) cp "$FAKE_ROOT/hashes.sha256" "$output" ;;
    https://github.com/PowerShell/PowerShell/releases/download/v7.9.0/powershell-*.tar.gz) cp "$FAKE_ROOT/pwsh.tar.gz" "$output" ;;
    *) echo "Unexpected download: $url" >&2; exit 1 ;;
esac
'@
            $unameFake = @'
#!/bin/sh
case "$1" in
    -s) printf '%s\n' "$FAKE_OS" ;;
    -m) printf '%s\n' "$FAKE_CPU" ;;
    *) exit 1 ;;
esac
'@
            $stub = @'
param([string[]]$Tools, [string]$ConfigDir, [string]$Ref, [switch]$Update,
    [switch]$Uninstall, [switch]$Purge, [switch]$DryRun, [switch]$Yes)
$captured = @{}
foreach ($key in $PSBoundParameters.Keys) {
    $value = $PSBoundParameters[$key]
    $captured[$key] = if ($value -is [Management.Automation.SwitchParameter]) { [bool]$value } else { $value }
}
$captured | ConvertTo-Json | Set-Content (Join-Path $env:FAKE_ROOT 'handoff.json')
exit ([int]$env:FAKE_EXIT)
'@
            foreach ($file in @{ pwsh=$pwshFake; curl=$curlFake; uname=$unameFake }.GetEnumerator()) {
                [IO.File]::WriteAllText((Join-Path $bin $file.Key), $file.Value.Replace("`r", '') + "`n")
                Set-TestExecutable (Join-Path $bin $file.Key)
            }
            [IO.File]::WriteAllText((Join-Path $scratch 'stub.ps1'), $stub)
            & tar -czf (Join-Path $scratch 'pwsh.tar.gz') -C $bin pwsh
            Assert-Equal 0 $LASTEXITCODE 'Fixture archive is ready'
            $digest = (Get-FileHash (Join-Path $scratch 'pwsh.tar.gz') -Algorithm SHA256).Hash.ToLowerInvariant()

            function Set-ShellRelease {
                param([string]$Name, [string]$Hash = $digest, [switch]$Utf8)
                [IO.File]::WriteAllText((Join-Path $scratch 'redirect'), 'https://github.com/PowerShell/PowerShell/releases/tag/v7.9.0')
                # Official hashes are UTF-16LE with BOM and CRLF; accept plain UTF-8 too.
                $hashes = "$Hash *$Name`r`n$digest *$Name.backup`r`n"
                $encoding = if ($Utf8) { [Text.UTF8Encoding]::new($false) } else { [Text.Encoding]::Unicode }
                [IO.File]::WriteAllText((Join-Path $scratch 'hashes.sha256'), $hashes, $encoding)
            }
            function Invoke-ShellCase {
                param([string[]]$Options = @(), [switch]$Stream)
                $env:HOME = Join-Path $scratch ('home-' + [guid]::NewGuid().ToString('N'))
                New-Item -ItemType Directory -Path $env:HOME | Out-Null
                Remove-Item (Join-Path $scratch 'handoff.json'), (Join-Path $scratch 'downloads') -ErrorAction SilentlyContinue
                if ($Stream) { $output = @((Get-Content $launcher -Raw) | & $shell.Source -s -- @Options 2>&1) -join "`n" }
                else { $output = @('' | & $shell.Source $launcher @Options 2>&1) -join "`n" }
                return @{ Code=$LASTEXITCODE; Output=$output; Home=$env:HOME }
            }
            $env:FAKE_PWSH_PRESENT = '1'
            $configDir = Join-Path $scratch 'account with spaces;$(literal)&value'
            $result = Invoke-ShellCase -Options @('--main', '--update', '--uninstall', '--purge', '--dry-run', '--yes', '--tools', 'codex,claude', '--config-dir', $configDir)
            Assert-Equal 0 $result.Code "Existing PowerShell hands over successfully: $($result.Output)"
            $handoff = Get-Content (Join-Path $scratch 'handoff.json') -Raw | ConvertFrom-Json
            Assert-Equal 'codex,claude' ($handoff.Tools -join '|') 'Tools cross the shell boundary as one literal argument'
            Assert-Equal $configDir $handoff.ConfigDir 'Config folder spaces and shell metacharacters remain literal'
            Assert-Equal 'main' $handoff.Ref 'Main selects the main track'
            foreach ($option in @('Update', 'Uninstall', 'Purge', 'DryRun', 'Yes')) { Assert-Equal $true $handoff.$option "$option is mapped" }
            Assert-True (-not ((Get-Content (Join-Path $scratch 'downloads') -Raw).Contains('/latest'))) 'Existing PowerShell needs no runtime download'
            $env:FAKE_EXIT = '23'
            Assert-Equal 23 (Invoke-ShellCase).Code 'Child exit status is preserved'
            $env:FAKE_EXIT = '0'
            $result = Invoke-ShellCase -Stream -Options @('--main', '--dry-run')
            Assert-Equal 0 $result.Code 'Piped script hands over successfully'
            $handoff = Get-Content (Join-Path $scratch 'handoff.json') -Raw | ConvertFrom-Json
            Assert-Equal 'main' $handoff.Ref 'Piped script maps options after sh -s --'
            Assert-Equal $true $handoff.DryRun 'Piped script preserves dry run'

            $checkout = Join-Path $scratch 'checkout'
            New-Item -ItemType Directory -Path (Join-Path $checkout 'plugins/legion') -Force | Out-Null
            Copy-Item $launcher (Join-Path $checkout 'install.sh')
            Copy-Item (Join-Path $scratch 'stub.ps1') (Join-Path $checkout 'install.ps1')
            '{}' | Set-Content (Join-Path $checkout 'plugins/legion/tools.json')
            $launcher = Join-Path $checkout 'install.sh'
            Assert-Equal 0 (Invoke-ShellCase).Code 'Checkout runs its sibling stub'
            Assert-True (-not (Test-Path (Join-Path $scratch 'downloads'))) 'Checkout handoff downloads nothing'
            $launcher = Join-Path $scratch 'install.sh'

            $env:FAKE_PWSH_PRESENT = '0'
            foreach ($options in @(@(), @('--dry-run', '--yes'))) {
                $result = Invoke-ShellCase -Options $options
                Assert-Equal 0 $result.Code 'Missing PowerShell without approval succeeds without changes'
                Assert-True ($result.Output.Contains('PowerShell 7 is missing')) 'Missing PowerShell shows a hint'
                Assert-True (-not (Test-Path (Join-Path $scratch 'downloads'))) 'Decline and dry run download nothing'
                Assert-True (-not (Test-Path (Join-Path $result.Home '.legion'))) 'Decline and dry run create nothing'
            }
            foreach ($platform in @(
                @{ OS='Linux'; CPU='x86_64'; Asset='linux-x64' },
                @{ OS='Linux'; CPU='aarch64'; Asset='linux-arm64' },
                @{ OS='Darwin'; CPU='x86_64'; Asset='osx-x64' },
                @{ OS='Darwin'; CPU='arm64'; Asset='osx-arm64' }
            )) {
                $env:FAKE_OS = $platform.OS
                $env:FAKE_CPU = $platform.CPU
                Set-ShellRelease -Name "powershell-7.9.0-$($platform.Asset).tar.gz"
                $result = Invoke-ShellCase -Options @('-y')
                Assert-Equal 0 $result.Code "Verified $($platform.Asset) archive hands over: $($result.Output)"
                Assert-True (Test-Path (Join-Path $result.Home '.legion/tools/pwsh/pwsh')) 'Portable runtime uses the agreed folder'
                Assert-True (Test-Path (Join-Path $scratch 'handoff.json')) 'Installer ran after verification'
                $downloads = Get-Content (Join-Path $scratch 'downloads') -Raw
                Assert-True ($downloads.Contains("powershell-7.9.0-$($platform.Asset).tar.gz")) 'Platform and CPU choose the official asset'
                Assert-True ($downloads.Contains('/releases/download/v7.9.0/hashes.sha256')) 'Hashes come from the selected release'
                Assert-True (-not ($downloads.Contains('.json'))) 'Bootstrap downloads no JSON'
                Assert-True ($downloads.Contains('/stable/install.ps1')) 'Default track downloads the stable stub'
                Remove-Item (Join-Path $scratch 'downloads')
                $output = @('' | & $shell.Source $launcher 2>&1) -join "`n"
                Assert-Equal 0 $LASTEXITCODE 'Repeat reuses the portable runtime'
                Assert-True ($output.Contains('skip: PowerShell 7 (already done)')) 'Repeat reports a skip'
                Assert-True (-not ((Get-Content (Join-Path $scratch 'downloads') -Raw).Contains('/latest'))) 'Repeat does not download PowerShell'
                Assert-Equal 0 @(Get-ChildItem (Join-Path $result.Home '.legion/temp') -Force).Count 'Scratch is removed after handoff'
            }
            Set-ShellRelease -Name 'powershell-7.9.0-osx-arm64.tar.gz' -Utf8
            Assert-Equal 0 (Invoke-ShellCase -Options @('--yes')).Code 'Plain UTF-8 hashes also verify'
            if ($env:FAKE_SHA256SUM) {
                # Exercise the macOS shasum branch on Linux without its sha256sum on PATH.
                foreach ($name in @('mkdir', 'mktemp', 'rm', 'dirname', 'tar', 'gzip', 'chmod', 'awk', 'tr', 'cat', 'cp')) {
                    $command = (Get-Command $name -CommandType Application | Select-Object -First 1).Source
                    New-Item -ItemType SymbolicLink -Path (Join-Path $bin $name) -Target $command | Out-Null
                }
                $shasum = Join-Path $bin 'shasum'
                $shasumFake = @'
#!/bin/sh
printf 'shasum\n' >> "$FAKE_ROOT/hash-command"
exec "$FAKE_SHA256SUM" "$3"
'@
                [IO.File]::WriteAllText($shasum, $shasumFake.Replace("`r", '') + "`n")
                Set-TestExecutable $shasum
                $fullPath = $env:PATH
                try {
                    $env:PATH = $bin
                    $result = Invoke-ShellCase -Options @('--yes')
                    Assert-Equal 0 $result.Code "macOS shasum fallback verifies the archive: $($result.Output)"
                    Assert-Equal 'shasum' (Get-Content (Join-Path $scratch 'hash-command') -Raw).Trim() 'Fallback actually calls shasum'
                } finally { $env:PATH = $fullPath }
            }
            Set-ShellRelease -Name 'unrelated.tar.gz'
            $result = Invoke-ShellCase -Options @('--yes')
            Assert-True ($result.Code -ne 0) 'A missing archive hash fails before extraction'
            Assert-True (-not (Test-Path (Join-Path $scratch 'handoff.json'))) 'Missing hash never runs the installer'
            Set-ShellRelease -Name 'powershell-7.9.0-osx-arm64.tar.gz' -Hash ('0' * 64)
            $result = Invoke-ShellCase -Options @('--yes')
            Assert-True ($result.Code -ne 0) 'Hash mismatch fails'
            Assert-True ($result.Output.Contains('SHA-256 digest mismatch')) 'Hash mismatch explains the failure'
            Assert-True (-not (Test-Path (Join-Path $scratch 'handoff.json'))) 'Hash mismatch never runs the installer'
            Assert-True (-not (Test-Path (Join-Path $result.Home '.legion/tools/pwsh/pwsh'))) 'Hash mismatch never extracts PowerShell'
            Assert-Equal 0 @(Get-ChildItem (Join-Path $result.Home '.legion/temp') -Force).Count 'Failed download scratch is removed'
            foreach ($badHash in @('', 'not-a-digest', ('a' * 63))) {
                Set-ShellRelease -Name 'powershell-7.9.0-osx-arm64.tar.gz' -Hash $badHash
                $result = Invoke-ShellCase -Options @('--yes')
                Assert-True ($result.Code -ne 0) 'Missing or invalid SHA-256 metadata fails'
                Assert-True (-not (Test-Path (Join-Path $scratch 'handoff.json'))) 'Invalid digest never runs the installer'
                Assert-True (-not ((Get-Content (Join-Path $scratch 'downloads') -Raw).Contains('.tar.gz'))) 'Invalid digest never downloads an archive'
            }
            foreach ($redirect in @('https://example.test/tag/v7.9.0', 'https://github.com/PowerShell/PowerShell/releases/latest', 'https://github.com/PowerShell/PowerShell/releases/tag/v../outside')) {
                [IO.File]::WriteAllText((Join-Path $scratch 'redirect'), $redirect)
                $result = Invoke-ShellCase -Options @('--yes')
                Assert-True ($result.Code -ne 0) 'Invalid release redirect fails'
                Assert-True (-not ((Get-Content (Join-Path $scratch 'downloads') -Raw).Contains('/releases/download/'))) 'Invalid redirect never downloads release assets'
            }
            $env:FAKE_CPU = 'unsupported'
            $result = Invoke-ShellCase -Options @('--yes')
            Assert-True ($result.Code -ne 0) 'Unsupported CPU stops'
            Assert-True (-not (Test-Path (Join-Path $scratch 'downloads'))) 'Unsupported CPU downloads nothing'
            foreach ($options in @(@('--unknown'), @('--tools'), @('--config-dir'))) {
                Assert-True ((Invoke-ShellCase -Options $options).Code -ne 0) 'Invalid options fail before any download'
                Assert-True (-not (Test-Path (Join-Path $scratch 'downloads'))) 'Invalid options download nothing'
            }
        } finally {
            foreach ($name in $variables) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
            Remove-InstallTestFolder $scratch
        }
    }
}
