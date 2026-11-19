$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $sandbox = Join-Path $repo ('.agents/temp/stale-marketplace-' + [guid]::NewGuid().ToString('N'))
    $checkout = Join-Path $sandbox 'checkout'
    $state = @{ Installed = $false; Calls = [Collections.Generic.List[string]]::new(); FailRefresh = $false }
    function Invoke-ClosedInput {
        param($Command)
        Assert-Equal $sandbox $env:CODEX_HOME 'Stale marketplace recovery uses selected account'
        $line = $Command -join '|'
        if ($line -eq 'codex|plugin|marketplace|list|--json') {
            return @{ ExitCode=0; Output=@(@{ marketplaces=@(@{ name='ps-ai-marketplace'; root=$checkout; marketplaceSource=@{sourceType='git';source='https://github.com/BlackGad/ps-ai-marketplace.git'} }) } | ConvertTo-Json -Depth 10 -Compress) }
        }
        if ($line -eq 'codex|plugin|list') {
            $output = if ($state.Installed) { @('ps-ai@ps-ai-marketplace installed, enabled') } else { @() }
            return @{ ExitCode=0; Output=$output }
        }
        $state.Calls.Add($line)
        if ($line -eq 'codex|plugin|marketplace|upgrade') {
            if ($state.FailRefresh) { return @{ExitCode=1; Output=@(); ErrorOutput=@('fixture refresh failure')} }
            New-Item -ItemType Directory -Path $checkout -Force | Out-Null
        } elseif ($line -eq 'codex|plugin|add|ps-ai@ps-ai-marketplace') {
            if (-not (Test-Path -LiteralPath $checkout)) { throw 'registered marketplace root is missing' }
            $state.Installed = $true
        } else { throw "Unexpected mutation: $line" }
        return @{ExitCode=0; Output=@(); ErrorOutput=@()}
    }
    try {
        New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
        $null = Invoke-PsAiInstallSteps -Tool codex -Source 'BlackGad/ps-ai-marketplace' -ConfigEnv CODEX_HOME -ConfigDir $sandbox
        Assert-Equal 'codex|plugin|marketplace|upgrade,codex|plugin|add|ps-ai@ps-ai-marketplace' ($state.Calls -join ',') 'Missing root refreshes before plugin install without re-registering'
        $state.Calls.Clear()
        $null = Invoke-PsAiInstallSteps -Tool codex -Source 'BlackGad/ps-ai-marketplace' -ConfigEnv CODEX_HOME -ConfigDir $sandbox
        Assert-Equal 0 $state.Calls.Count 'Healthy repeat does not mutate the account'
        $state.Installed = $false
        $null = Invoke-PsAiInstallSteps -Tool codex -Source 'BlackGad/ps-ai-marketplace' -ConfigEnv CODEX_HOME -ConfigDir $sandbox
        Assert-Equal 'codex|plugin|marketplace|upgrade' $state.Calls[0] 'Missing plugin refreshes an existing checkout'
        $state.Calls.Clear()
        Remove-Item -LiteralPath $checkout
        $preview = @(Invoke-PsAiInstallSteps -Tool codex -Source 'BlackGad/ps-ai-marketplace' -ConfigEnv CODEX_HOME -ConfigDir $sandbox -DryRun)
        Assert-True (@($preview) -match 'plugin marketplace upgrade') 'Dry run previews stale-root refresh even with an installed plugin'
        Assert-Equal 0 $state.Calls.Count 'Dry run makes no mutations'
        $state.FailRefresh = $true
        Assert-Throws { Invoke-PsAiInstallSteps -Tool codex -Source 'BlackGad/ps-ai-marketplace' -ConfigEnv CODEX_HOME -ConfigDir $sandbox } 'Failed refresh stops installation'
        Assert-Equal 1 $state.Calls.Count 'Refresh failure never reaches plugin install'
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe fixture cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}

& {
    . (Join-Path $repo 'install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $entry = Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/ps-ai-fourth/tool.json') -Raw | ConvertFrom-Json
    $entry.plugin.marketplaceUpdate = @('refresh-fixture-market')
    $script:installCatalog.tools += $entry
    $calls = [Collections.Generic.List[string]]::new()
    function Test-InstallStepDone { param($Command) $Command -contains 'marketplace' }
    function Invoke-InstallCommand { param($Command) $calls.Add(($Command -join '|')) }
    $null = Invoke-PsAiInstallSteps -Tool fourth -Source 'example/market' -ConfigEnv FOURTH_HOME
    Assert-Equal 'fourth-cli|refresh-fixture-market' $calls[0] 'Registered marketplace without plugin uses descriptor refresh command'
    Assert-Equal 2 $calls.Count 'Generic recovery refreshes and installs without adding the registration'
}
