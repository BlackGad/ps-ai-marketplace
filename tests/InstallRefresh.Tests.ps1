$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $entry = Get-InstallTool claude
    $sandbox = Join-Path $repo ('.agents/temp/install-refresh-' + [guid]::NewGuid().ToString('N'))
    $oldPlugin = Join-Path $sandbox 'cache/old'
    $newPlugin = Join-Path $sandbox 'cache/new'
    $marker = Join-Path $sandbox 'refreshed.txt'
    $state = @{Updated=$false; Fail=$false; Missing=$false; Disappeared=$false}
    $realClosedInput = ${function:Invoke-ClosedInput}
    function Get-InstallHome { Join-Path $sandbox 'selected-home' }
    function Invoke-ClosedInput {
        param($Command)
        if ($Command[0] -ne 'claude') { return & $realClosedInput -Command $Command }
        Assert-Equal 'selected-account' $env:CLAUDE_CONFIG_DIR 'Listing and update use selected account'
        if ($Command -contains 'marketplace' -and $Command -contains 'list') { return @{ExitCode=0;Output=@('[]')} }
        if ($Command[2] -eq 'list') {
            if ($state.Missing -or ($state.Updated -and $state.Disappeared)) { return @{ExitCode=0;Output=@('[]')} }
            $path = if ($state.Updated) { $newPlugin } else { $oldPlugin }
            $json = @(@{id='ps-ai@ps-ai-marketplace'; enabled=$true; installPath=$path}) | ConvertTo-Json -Compress -AsArray
            return @{ExitCode=0;Output=@($json)}
        }
        if ($state.Fail) { return @{ExitCode=8;Output=@()} }
        if ($Command[1] -eq 'plugin' -and $Command[2] -eq 'update') { $state.Updated=$true }
        if ($Command[1] -eq 'plugin' -and $Command[2] -eq 'install') { $state.Missing=$false; $state.Updated=$true }
        return @{ExitCode=0;Output=@()}
    }
    try {
        foreach ($folder in @($oldPlugin,$newPlugin)) {
            New-Item -ItemType Directory -Path (Join-Path $folder 'bin') -Force | Out-Null
            '{"name":"ps-ai","version":"0.3.0"}' | Set-Content (Join-Path $folder 'plugin.json')
        }
        'throw "stale refresh script invoked"' | Set-Content (Join-Path $oldPlugin 'bin/ps-ai-refresh.ps1')
        ('param($HomeRoot); $HomeRoot | Set-Content -LiteralPath ''' + $marker.Replace("'", "''") + '''') | Set-Content (Join-Path $newPlugin 'bin/ps-ai-refresh.ps1')
        $null = Invoke-PsAiUpdateSteps -Entry $entry -ConfigDir selected-account
        Assert-True (Test-Path -LiteralPath $marker) 'Successful update invokes freshly installed refresh script'
        Assert-Equal (Get-InstallHome) ((Get-Content $marker -Raw).Trim()) 'Refresh receives the selected owner home'
        Remove-Item $marker
        $state.Fail=$true
        Assert-Throws { Invoke-PsAiUpdateSteps -Entry $entry -ConfigDir selected-account } 'Failed update propagates'
        Assert-True (-not (Test-Path $marker)) 'Failed update never refreshes generated artifacts'
        $state.Fail=$false
        $state.Missing=$true
        $null = Invoke-PsAiUpdateSteps -Entry $entry -ConfigDir selected-account
        Assert-True (Test-Path $marker) 'Missing plugin is installed then its fresh artifacts are refreshed'
        Remove-Item $marker
        $state.Missing=$false
        $null = Invoke-PsAiUpdateSteps -Entry $entry -ConfigDir selected-account -DryRun
        Assert-True (-not (Test-Path $marker)) 'Preview never invokes refresh'
        $state.Disappeared=$true
        New-Item -ItemType Directory -Path (Join-Path $sandbox 'selected-home/.claude/plugins/cache/ps-ai-marketplace/ps-ai') -Force | Out-Null
        Copy-Item -LiteralPath $newPlugin -Destination (Join-Path $sandbox 'selected-home/.claude/plugins/cache/ps-ai-marketplace/ps-ai/0.3.0') -Recurse
        $previousConfig = $env:CLAUDE_CONFIG_DIR
        try {
            $env:CLAUDE_CONFIG_DIR = 'selected-account'
            Assert-Throws { Invoke-InstallRefresh -Entry $entry } 'Absent post-update plugin cannot use a leftover cache'
        } finally { $env:CLAUDE_CONFIG_DIR = $previousConfig }
        Assert-True (-not (Test-Path $marker)) 'Leftover cache is never refreshed as an installed plugin'
        $state.Disappeared=$false
        Remove-Item (Join-Path $newPlugin 'bin/ps-ai-refresh.ps1')
        Assert-Throws { Invoke-PsAiUpdateSteps -Entry $entry -ConfigDir selected-account } 'Unresolvable installed refresh script is reported'
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe refresh fixture cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}

& {
    . (Join-Path $repo 'install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $sandbox = Join-Path $repo ('.agents/temp/refresh-cache-' + [guid]::NewGuid().ToString('N'))
    $configRoot = Join-Path $sandbox 'selected-account'
    $calls = [Collections.Generic.List[object]]::new()
    function Get-InstallHome { Join-Path $sandbox 'selected-home' }
    function Invoke-ClosedInput {
        param($Command)
        if ($Command[0] -eq 'copilot') { return @{ExitCode=0;Output=@('ps-ai@ps-ai-marketplace (v0.3.0) (enabled)')} }
        $calls.Add($Command)
        @{ExitCode=0;Output=@()}
    }
    try {
        foreach ($version in @('0.2.0','0.3.0')) {
            $plugin = Join-Path $configRoot "installed-plugins/arbitrary-layout/$version"
            New-Item -ItemType Directory -Path (Join-Path $plugin 'bin') -Force | Out-Null
            ('{"name":"ps-ai","version":"' + $version + '"}') | Set-Content (Join-Path $plugin 'plugin.json')
            '# inert refresh fixture' | Set-Content (Join-Path $plugin 'bin/ps-ai-refresh.ps1')
        }
        $null = Invoke-InstallRefresh -Entry (Get-InstallTool copilot) -ConfigDir $configRoot
        Assert-Equal 1 $calls.Count 'Selected Copilot installed-files root supplies one refresh'
        Assert-Equal (Join-Path $configRoot 'installed-plugins/arbitrary-layout/0.3.0/bin/ps-ai-refresh.ps1') $calls[0][3] 'Listing version selects the matching cached plugin'
        Assert-Equal (Get-InstallHome) $calls[0][5] 'Cache fallback retains selected home'
        $other = Join-Path $configRoot 'installed-plugins/ambiguous-copy'
        Copy-Item -LiteralPath (Join-Path $configRoot 'installed-plugins/arbitrary-layout/0.3.0') -Destination $other -Recurse
        Assert-Throws { Invoke-InstallRefresh -Entry (Get-InstallTool copilot) -ConfigDir $configRoot } 'Ambiguous installed copies require an explicit path'
        Assert-Equal 1 $calls.Count 'Ambiguous cache never launches a guessed refresh script'
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe installed cache cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
