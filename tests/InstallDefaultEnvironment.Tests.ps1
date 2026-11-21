$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $entry = Get-InstallTool -Tool claude
    $captured = Get-Content (Join-Path $PSScriptRoot 'fixtures/install/listings/claude-plugins.json')
    Assert-True (Test-InstallListing -Kind plugin -Tool claude -Lines $captured -IncludeDisabled) 'Captured user-scope Claude plugin is installed despite projectEnabled false'
    $sandbox = Join-Path $repo ('.agents/temp/default-environment-' + [guid]::NewGuid().ToString('N'))
    . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome $sandbox
    $fixturePlugin = New-InstallFixturePlugin -Path (Join-Path $sandbox 'installed')
    $plugins = ($captured -join "`n") | ConvertFrom-Json
    $plugins[0].installPath = $fixturePlugin
    $captured = @(ConvertTo-Json -InputObject @($plugins) -Depth 10)
    $saved = [Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR', 'Process')
    $observed = [Collections.Generic.List[string]]::new()
    function Invoke-ClosedInput {
        param($Command)
        $observed.Add(($Command -join '|'))
        # Real Claude returns [] when the variable is present but empty.
        $output = if (Test-Path Env:CLAUDE_CONFIG_DIR) { @('[]') } else { $captured }
        @{ExitCode=0; Output=$output; ErrorOutput=@()}
    }
    function Invoke-InstallRefresh { }
    try {
        $env:CLAUDE_CONFIG_DIR = 'selected-account'
        $output = @(Invoke-PsAiUpdateSteps -Entry $entry)
        Assert-True ($observed -contains 'claude|plugin|update|ps-ai@ps-ai-marketplace') 'Default update unsets environment override rather than passing empty string'
        Assert-Equal 'selected-account' $env:CLAUDE_CONFIG_DIR 'Default update restores inherited override'
        Remove-Item Env:CLAUDE_CONFIG_DIR
        $null = Invoke-PsAiUpdateSteps -Entry $entry
        Assert-True (-not (Test-Path Env:CLAUDE_CONFIG_DIR)) 'Absent caller override remains absent after update'
        function Invoke-ClosedInput { throw 'fixture process failed' }
        Assert-Throws { Invoke-PsAiUpdateSteps -Entry $entry } 'Failed default listing propagates'
        Assert-True (-not (Test-Path Env:CLAUDE_CONFIG_DIR)) 'Failure restores absent caller override'
    } finally {
        if ($null -eq $saved) { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_CONFIG_DIR = $saved }
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe environment fixture cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
