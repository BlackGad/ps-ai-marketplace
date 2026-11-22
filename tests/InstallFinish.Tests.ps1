param([string[]]$Cases = @('InstallRunsRefresh','InstallQuestionNamesPath','InstallUnixPathHint','InstallNextStep','NonInteractiveInstall'))

$repo = Split-Path $PSScriptRoot -Parent
$failures = @()
foreach ($case in $Cases) {
    try { & {
        . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
        . (Join-Path $PSScriptRoot 'fixtures/install/MarketplaceListing.ps1')
        $scratch = Join-Path $repo ('.agents/temp/install-finish-' + [guid]::NewGuid().ToString('N'))
        $plugin = Join-Path $scratch 'installed'
        New-Item -ItemType Directory -Path $plugin -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $repo 'plugins/legion/bin') -Destination $plugin -Recurse
        '{"name":"legion","version":"0.8.0"}' | Set-Content -LiteralPath (Join-Path $plugin 'plugin.json')
        $fixturePwsh = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
        $catalog = Get-InstallCatalog -Source $repo
        $state = @{ Ready=$true; UserPath='fixture-existing'; Writes=0; Winget=0; Zip=0; Answer='y' }
        $questions = [Collections.Generic.List[string]]::new()
        $refreshes = [Collections.Generic.List[string]]::new()
        $installed = @{}
        function Get-InstallHome { $scratch }
        function Get-InstallUserPath { $state.UserPath }
        function Set-InstallUserPath { param($Path) $state.Writes++; $state.UserPath=$Path }
        function Test-InstallCommandAvailable { $true }
        function Get-InstallSourceText { throw 'Unexpected network access' }
        function Invoke-InstallDownload { throw 'Unexpected download' }
        function Read-Host { param($Prompt) $questions.Add($Prompt); $state.Answer }
        function claude { param($Version) Assert-Equal '--version' $Version 'Only version probes run directly'; 'fixture CLI' }
        function Invoke-ClosedInput {
            param($Command, $Environment)
            if ($Command[0] -eq $fixturePwsh) {
                $refreshes.Add($Command[3])
                $output = & $Command[0] @($Command | Select-Object -Skip 1) 2>&1
                return @{ ExitCode=$LASTEXITCODE; Output=@($output); ErrorOutput=@() }
            }
            Assert-Equal 'claude' $Command[0] 'Only fixture Claude calls are allowed'
            $folder = [string]$Environment.CLAUDE_CONFIG_DIR
            if ($Command -contains 'list') {
                if ($Command -contains 'marketplace') { return @{ExitCode=0;Output=@(Get-FixtureMarketplaceListing -Tool claude -Source $repo)} }
                $listing = if ($installed[$folder]) { '[{"id":"legion@ps-legion-marketplace","enabled":true,"installPath":' + (ConvertTo-Json $plugin -Compress) + '}]' } else { '[]' }
                return @{ExitCode=0;Output=@($listing)}
            }
            if ($Command[2] -eq 'install') { $installed[$folder]=$true }
            return @{ExitCode=0;Output=@();ErrorOutput=@()}
        }
        $savedPath = $env:PATH
        $savedOS = $env:OS
        $savedClaude = $env:CLAUDE_CONFIG_DIR
        $options = @{ Tools=@('claude'); Source=$repo; Catalog=$catalog; ConfigDir=(Join-Path $scratch 'fixture-account') }
        try {
            $env:OS = 'Windows_NT'
            switch ($case) {
                'InstallRunsRefresh' {
                    function Get-UpdateConfigDirs { @((Join-Path $scratch 'fixture-one'), (Join-Path $scratch 'fixture-two')) }
                    $null = Invoke-LegionInstaller @options -Yes
                    Assert-Equal 2 $refreshes.Count 'InstallRunsRefresh: refresh runs once for each installed folder'
                    $command = Join-Path $scratch '.legion/bin/legion'
                    Assert-True (Test-Path -LiteralPath $command) 'InstallRunsRefresh: plain install creates legion'
                    Assert-True ((Get-Content -LiteralPath $command -Raw).Replace('\','/').Contains($plugin.Replace('\','/'))) 'InstallRunsRefresh: legion points at the installed copy'
                }
                'InstallQuestionNamesPath' {
                    $null = Invoke-LegionInstaller @options
                    Assert-Equal 'Install legion for claude now, and add ~/.legion/bin to your PATH? [y/N]' ($questions -join '|') 'InstallQuestionNamesPath: one question covers PATH'
                    Assert-Equal 1 $state.Writes 'InstallQuestionNamesPath: consent adds user PATH once'
                    Assert-True (Test-Path -LiteralPath (Join-Path $scratch '.legion/bin') -PathType Container) 'InstallQuestionNamesPath: command folder exists'
                    $questions.Clear()
                    $null = Invoke-LegionInstaller @options
                    Assert-Equal 'Install legion for claude now? [y/N]' ($questions -join '|') 'InstallQuestionNamesPath: existing PATH needs no PATH question'
                    Assert-Equal 1 $state.Writes 'InstallQuestionNamesPath: repeat does not rewrite PATH'
                }
                # Missing-pwsh consent and both prompts are covered by the stub tests.
                'InstallUnixPathHint' {
                    $env:OS='fixture-unix'
                    $preview = @(Invoke-LegionInstaller @options -DryRun) -join "`n"
                    $profile = Get-LegionShellProfile -HomeRoot $scratch
                    Assert-True ($preview.Contains($profile.Path)) 'InstallUnixPathHint: dry run names the profile'
                    Assert-True (-not (Test-Path $profile.Path)) 'InstallUnixPathHint: dry run never writes the profile'
                    $state.Answer = 'n'
                    $null = Invoke-LegionInstaller @options
                    Assert-True (-not (Test-Path $profile.Path)) 'InstallUnixPathHint: decline never writes the profile'
                    $output = @(Invoke-LegionInstaller @options -Yes)
                    Assert-True (Get-LegionShellProfile -HomeRoot $scratch).HasPath 'InstallUnixPathHint: consent writes the shell profile line'
                    Assert-Equal 0 $state.Writes 'InstallUnixPathHint: no user PATH write'
                    Assert-Equal $savedPath $env:PATH 'InstallUnixPathHint: no process PATH write'
                    $repeat = @(Invoke-LegionInstaller @options -Yes)
                    Assert-True ($repeat -contains 'skip: shell profile PATH (already done)') 'InstallUnixPathHint: repeat skips the profile before a new terminal'
                }
                'InstallNextStep' {
                    foreach ($track in @('release','main')) {
                        $output = @(Invoke-LegionInstaller @options -Ref $track -Yes)
                        Assert-Equal "installed: legion 0.8.0 ($track)" $output[-2] 'InstallNextStep: installed plugin version and track'
                        Assert-Equal 'next: legion add claude (or legion in a repository)' $output[-1] 'InstallNextStep: explains the next action'
                    }
                }
                'NonInteractiveInstall' {
                    $state.Ready=$false
                    $state.Answer=''
                    $output = @(Invoke-LegionInstaller @options 6>&1)
                    Assert-True ($output -contains 'Nothing changed. Run again with -Yes to apply.') 'NonInteractiveInstall: empty redirected answer explains no changes'
                    Assert-Equal 0 $state.Writes 'NonInteractiveInstall: no PATH write'
                    Assert-Equal 0 $state.Winget 'NonInteractiveInstall: no prerequisite install'
                    Assert-Equal 0 $installed.Count 'NonInteractiveInstall: no plugin install'
                    Assert-True (-not (Test-Path -LiteralPath (Join-Path $scratch '.legion'))) 'NonInteractiveInstall: nothing generated'
                    $questions.Clear()
                    $null = Invoke-LegionInstaller @options -DryRun
                    Assert-Equal 0 $questions.Count 'NonInteractiveInstall: dry run never prompts'
                    Assert-Equal 0 $state.Writes 'NonInteractiveInstall: dry run never writes PATH'
                }
            }
        } finally {
            $env:PATH=$savedPath
            $env:OS=$savedOS
            [Environment]::SetEnvironmentVariable('CLAUDE_CONFIG_DIR', $savedClaude, 'Process')
            $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
            if (-not [IO.Path]::GetFullPath($scratch).StartsWith($allowed)) { throw 'Unsafe cleanup' }
            Remove-Item -LiteralPath $scratch -Recurse -Force
        }
    }; "PASS $case" } catch { $failures += "$case`: $($_.Exception.Message)"; "FAIL $($failures[-1])" }
}
if ($failures.Count) { throw ($failures -join "`n") }
