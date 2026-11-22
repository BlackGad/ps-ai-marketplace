$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $entry = Get-InstallTool -Tool claude
    $realProcess = ${function:Invoke-ClosedInput}
    $savedOverride = $env:CLAUDE_CONFIG_DIR
    try {
        $env:CLAUDE_CONFIG_DIR = 'inherited-account'
        foreach ($empty in @($null, '')) {
            $child = & $realProcess -Command @('pwsh', '-NoProfile', '-Command', '[Console]::Write((Test-Path Env:CLAUDE_CONFIG_DIR))') -Environment @{CLAUDE_CONFIG_DIR=$empty}
            Assert-Equal 'False' ($child.Output -join '') 'Default-home child removes inherited config variable'
            Assert-Equal 'inherited-account' $env:CLAUDE_CONFIG_DIR 'Child environment leaves caller untouched'
        }
    } finally {
        if ($null -eq $savedOverride) { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_CONFIG_DIR = $savedOverride }
    }
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
        param($Command, $Environment)
        $observed.Add(($Command -join '|'))
        # Real Claude returns [] when the variable is present but empty.
        Assert-True ($Environment.ContainsKey('CLAUDE_CONFIG_DIR')) 'Default listing explicitly overrides inherited config'
        Assert-True ([string]::IsNullOrEmpty($Environment.CLAUDE_CONFIG_DIR)) 'Default listing requests removal in the child'
        $output = $captured
        @{ExitCode=0; Output=$output; ErrorOutput=@()}
    }
    function Invoke-InstallRefresh { }
    try {
        $env:CLAUDE_CONFIG_DIR = 'selected-account'
        $output = @(Invoke-LegionUpdateSteps -Entry $entry)
        Assert-True ($observed -contains 'claude|plugin|update|legion@ps-legion-marketplace') 'Default update unsets environment override rather than passing empty string'
        Assert-Equal 'selected-account' $env:CLAUDE_CONFIG_DIR 'Default update restores inherited override'
        Remove-Item Env:CLAUDE_CONFIG_DIR
        $null = Invoke-LegionUpdateSteps -Entry $entry
        Assert-True (-not (Test-Path Env:CLAUDE_CONFIG_DIR)) 'Absent caller override remains absent after update'
        function Invoke-ClosedInput { throw 'fixture process failed' }
        Assert-Throws { Invoke-LegionUpdateSteps -Entry $entry } 'Failed default listing propagates'
        Assert-True (-not (Test-Path Env:CLAUDE_CONFIG_DIR)) 'Failure restores absent caller override'
    } finally {
        if ($null -eq $saved) { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_CONFIG_DIR = $saved }
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe environment fixture cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
