$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    $catalog = Get-InstallCatalog -Source $repo
    $sandbox = Join-Path $repo ('.agents/temp/update-version-' + [guid]::NewGuid().ToString('N'))
    . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome $sandbox
    $entry = $catalog.tools | Where-Object id -EQ claude
    $folders = @((Join-Path $sandbox 'account-a'), (Join-Path $sandbox 'account-b'))
    $calls = [Collections.Generic.List[string]]::new()
    $questions = [Collections.Generic.List[string]]::new()
    $state = @{ Answer='y'; Target='0.8.0'; Refreshes=0 }
    function Get-UpdateConfigDirs { ,$folders }
    function Read-Host {
        param($Prompt)
        $questions.Add($Prompt)
        Assert-Equal 0 @($calls | Where-Object { $_ -notmatch '\|list\|' }).Count 'Question precedes all mutations'
        $state.Answer
    }
    function Invoke-ClosedInput {
        param($Command)
        if ($Command[0] -eq 'pwsh') { $state.Refreshes++; return @{ExitCode=0; Output=@()} }
        $calls.Add(($Command -join '|'))
        $config = $env:CLAUDE_CONFIG_DIR
        $root = Join-Path $config $entry.plugin.installedRoot
        $manifest = Join-Path $root 'plugin.json'
        if ($Command -contains 'list') {
            if ($Command -contains 'marketplace') { return @{ExitCode=0; Output=@('[]')} }
            $plugins = @()
            if (Test-Path -LiteralPath $manifest) {
                $version = (Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).version
                $plugins = @(@{id='ps-ai@ps-ai-marketplace'; enabled=$false; version=$version})
            }
            return @{ExitCode=0; Output=@(ConvertTo-Json -InputObject $plugins -Compress)}
        }
        if ($Command -notcontains 'marketplace') { Write-FixturePlugin -Folder $config -Version $state.Target }
        @{ExitCode=0; Output=@()}
    }
    function Get-InstallPowerShellCommand { @{Source='pwsh'} }
    function Write-FixturePlugin {
        param($Folder, $Version)
        $root = Join-Path $Folder $entry.plugin.installedRoot
        New-Item -ItemType Directory -Path (Join-Path $root 'bin') -Force | Out-Null
        @{name='ps-ai';version=$Version} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'plugin.json')
        '# inert refresh' | Set-Content -LiteralPath (Join-Path $root 'bin/ps-ai-refresh.ps1')
    }
    try {
        Write-FixturePlugin $folders[0] '0.7.0'
        Write-FixturePlugin $folders[1] '0.8.0'
        $output = @(Invoke-LegionInstaller -Tools claude -Catalog $catalog -Update)
        Assert-True ($output -contains 'ps-ai 0.7.0 -> 0.8.0') 'UpdateShowsVersions: reports installed versions before and after'
        Assert-True ($output -contains 'skip: ps-ai 0.8.0 (already up to date)') 'MixedFoldersUpdate: reports an unchanged folder separately'
        Assert-Equal 1 $questions.Count 'UpdateAsksOnce: one question across mixed folders'
        Assert-Equal 'Update ps-ai? [y/N]' $questions[0] 'Update question is explicit'
        Assert-Equal 2 @($calls | Where-Object { $_ -eq 'claude|plugin|marketplace|update|ps-ai-marketplace' }).Count 'Each registered marketplace updates'
        Assert-Equal 2 @($calls | Where-Object { $_ -eq 'claude|plugin|update|ps-ai@ps-ai-marketplace' }).Count 'Each installed plugin updates'
        Assert-Equal 2 $state.Refreshes 'Each folder refreshes its generated artifacts exactly once'
        Assert-Equal 0 @($calls | Where-Object { $_ -match '\|(add|remove|install)\|' }).Count 'Registered tracks are never re-added or switched'
        Assert-True ($output -contains 'done: restart your sessions; run legion in the repository') 'Successful update gives the restart hint'

        $calls.Clear(); $questions.Clear()
        $output = @(Invoke-LegionInstaller -Tools claude -Catalog $catalog -Update -Yes)
        Assert-Equal 2 @($output | Where-Object { $_ -eq 'skip: ps-ai 0.8.0 (already up to date)' }).Count 'UpdateAlreadyLatest: unchanged versions reported after tools run'
        Assert-Equal 2 @($calls | Where-Object { $_ -eq 'claude|plugin|update|ps-ai@ps-ai-marketplace' }).Count 'Same version never suppresses track updates'
        Assert-Equal 0 $questions.Count '-Yes suppresses the question'

        Remove-Item -LiteralPath (Join-Path (Join-Path $folders[1] $entry.plugin.installedRoot) 'plugin.json')
        $calls.Clear(); $questions.Clear(); $state.Answer='n'
        $output = @(Invoke-LegionInstaller -Tools claude -Catalog $catalog -Update)
        Assert-True (($output -join "`n").Contains($folders[1])) 'Preview names the missing target'
        Assert-True (($output -join "`n").Contains('not installed')) 'Preview identifies a fresh install'
        Assert-Equal 1 $questions.Count 'Declining mixed update asks once'
        Assert-Equal 0 @($calls | Where-Object { $_ -notmatch '\|list\|' }).Count 'Declining changes nothing, including already installed folders'
        Assert-True ($output -contains 'Nothing changed. Run again with -Yes to apply.') 'Decline explains how to apply'

        $calls.Clear(); $questions.Clear()
        $output = @(Invoke-LegionInstaller -Tools claude -Catalog $catalog -Update -DryRun)
        Assert-Equal 0 $questions.Count 'Dry run never asks'
        Assert-Equal 0 @($calls | Where-Object { $_ -notmatch '\|list\|' }).Count 'Dry run only reads listings'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path (Join-Path $folders[1] $entry.plugin.installedRoot) 'plugin.json'))) 'Dry run creates no missing copy'

        $calls.Clear(); $questions.Clear(); $state.Answer='y'
        $output = @(Invoke-LegionInstaller -Tools claude -Catalog $catalog -Update)
        Assert-Equal 1 $questions.Count 'One yes covers updating and fresh installation'
        Assert-True ($calls -contains 'claude|plugin|install|ps-ai@ps-ai-marketplace') 'Missing folder is installed under the same yes'
        Assert-True ($output -contains 'ps-ai not installed -> 0.8.0') 'Fresh installation reports its resulting version'
        $calls.Clear()
        $output = @(Invoke-LegionInstaller -Tools claude -Catalog $catalog -Update -Yes)
        Assert-Equal 0 @($calls | Where-Object { $_ -match '\|(add|install|remove)\|' }).Count 'FreshInstallThenUpdate: subsequent update keeps registration'
        Assert-Equal 2 @($output | Where-Object { $_ -eq 'skip: ps-ai 0.8.0 (already up to date)' }).Count 'FreshInstallThenUpdate: subsequent report is unchanged'
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe update fixture cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}

& {
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $entry = Get-InstallTool codex
    $missingFolder = Join-Path $repo ('.agents/temp/absent-codex-' + [guid]::NewGuid().ToString('N'))
    $previous = $env:CODEX_HOME
    function Invoke-ClosedInput {
        @{ExitCode=1; Output=@(); ErrorOutput=@('failed to resolve CODEX_HOME: path does not exist, but that path does not exist')}
    }
    Assert-True ($null -eq (Get-InstallPluginRoot -Entry $entry -ConfigDir $missingFolder)) 'Missing Codex home counts as a pending fresh install'
    Assert-Equal $previous $env:CODEX_HOME 'Missing Codex home lookup restores caller config'
    Assert-True (-not (Test-Path -LiteralPath $missingFolder)) 'Pre-consent lookup never creates the Codex home'
    function Invoke-ClosedInput { @{ExitCode=1; Output=@(); ErrorOutput=@('unrelated listing failure')} }
    Assert-Throws { Get-InstallPluginRoot -Entry $entry -ConfigDir $missingFolder } 'Unrelated Codex listing errors still stop the update'
}

& {
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $entry = Get-InstallTool claude
    $sandbox = Join-Path $repo ('.agents/temp/nested-manifests-' + [guid]::NewGuid().ToString('N'))
    $cache = Join-Path $sandbox $entry.plugin.installedRoot
    function Invoke-ClosedInput { @{ExitCode=0; Output=@('[{"id":"ps-ai@ps-ai-marketplace","enabled":true}]')} }
    try {
        $manifest = '{"name":"ps-ai","version":"0.8.0"}'
        foreach ($folder in @('0.8.0', '0.8.0/.claude-plugin', '0.8.0/.codex-plugin')) {
            New-Item -ItemType Directory -Path (Join-Path $cache $folder) -Force | Out-Null
            $manifest | Set-Content -LiteralPath (Join-Path $cache "$folder/plugin.json")
        }
        Assert-Equal (Join-Path $cache '0.8.0') (Get-InstallPluginRoot -Entry $entry -ConfigDir $sandbox) 'Nested tool manifests are not separate copies'
        New-Item -ItemType Directory -Path (Join-Path $cache '0.9.0') -Force | Out-Null
        $manifest | Set-Content -LiteralPath (Join-Path $cache '0.9.0/plugin.json')
        Assert-Throws { Get-InstallPluginRoot -Entry $entry -ConfigDir $sandbox } 'Two real copies stay ambiguous'
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe nested fixture cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
