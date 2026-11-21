$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'fixtures/install/MarketplaceListing.ps1')
$script = Join-Path $root 'plugins/ps-ai/install.ps1'
. $script -NoRun
$script:installCatalog = Get-InstallCatalog -Source $root
$expected = @{
    claude = @('claude|plugin|marketplace|add|local source', 'claude|plugin|install|ps-ai@ps-ai-marketplace')
    codex = @('codex|plugin|marketplace|add|local source', 'codex|plugin|add|ps-ai@ps-ai-marketplace')
    copilot = @('copilot|plugin|marketplace|add|local source', 'copilot|plugin|install|ps-ai@ps-ai-marketplace')
}
foreach ($tool in @('claude', 'codex', 'copilot')) {
    $commands = Get-InstallCommands -Tool $tool -Source 'local source'
    Assert-Equal 2 $commands.Count "$tool has two commands"
    Assert-Equal $expected[$tool][0] ($commands[0] -join '|') "$tool marketplace command"
    Assert-Equal $expected[$tool][1] ($commands[1] -join '|') "$tool install command"
    Assert-Equal 'local source' $commands[0][4] "$tool source with space remains one argument"
}
$previewLines = @(& {
    function Test-InstallStepDone { $false }
    Invoke-LegionInstaller -Tools claude -Source 'local source' -ConfigDir X -DryRun -Catalog (Get-Content (Join-Path $PSScriptRoot 'fixtures/install/catalog.json') -Raw | ConvertFrom-Json)
})
Assert-True $? 'Injected dry run succeeds'
Assert-True ($previewLines -contains 'CLAUDE_CONFIG_DIR=X claude plugin marketplace add "local source"') 'Dry run marketplace command'
Assert-True ($previewLines -contains 'CLAUDE_CONFIG_DIR=X claude plugin install ps-ai@ps-ai-marketplace') 'Dry run plugin command'

& {
    . $script -NoRun
    function Ensure-InstallPowerShell { return $true }
    function Get-InstallHome { Join-Path $root '.agents/temp/install-selected-account' }
    function Get-InstallUserPath { Get-InstallLegionPath 'bin' }
    function Add-InstallPowerShellPath { }
    function Invoke-InstallRefresh { }
    function Get-InstallPluginRoot { Join-Path $root 'plugins/ps-ai' }
    function codex { param($Version) Assert-Equal '--version' $Version 'Fake CLI only handles version'; 'fixture-version' }
    $calls = [Collections.Generic.List[string]]::new()
    function Invoke-ClosedInput {
        param([string[]]$Command)
        Assert-Equal 'selected-account' $env:CODEX_HOME 'Install uses selected account for checks and writes'
        $calls.Add(($Command -join '|'))
        if ($Command -contains 'marketplace' -and $Command -contains 'list') {
            return @{ ExitCode=0; Output=@(Get-FixtureMarketplaceListing -Tool codex) }
        }
        return @{ ExitCode=0; Output=@() }
    }
    $previous = $env:CODEX_HOME
    try {
        $env:CODEX_HOME = 'default-account'
        $null = Invoke-LegionInstaller -Tools codex -Source $root -ConfigDir selected-account -Yes
        Assert-Equal 4 $calls.Count 'Fake install checks and performs both steps'
        Assert-True ($calls -contains 'codex|plugin|add|ps-ai@ps-ai-marketplace') 'Fake install performs plugin write'
        Assert-Equal 'default-account' $env:CODEX_HOME 'Install restores caller account'
    } finally { $env:CODEX_HOME = $previous }
}
try {
    Get-InstallCommands -Tool other -Source . | Out-Null
    throw 'Expected unknown tool'
} catch {
    Assert-Equal "unknown tool 'other'" $_.Exception.Message 'Unknown tool error'
}

# Real listings captured 2026-11-18 (Codex 0.167, Copilot 1.0.109, Claude 2.1.325).
$codexAvailable = 'ps-ai@ps-ai-marketplace  not installed           C:\repo\plugins\ps-ai'
$codexInstalled = 'ps-ai@ps-ai-marketplace  installed, enabled  0.1.0    C:\repo\plugins\ps-ai'
$copilotDisabled = '  • ps-ai@ps-ai-marketplace (v0.1.0) (disabled)'
$copilotEnabled = '  • ps-ai@ps-ai-marketplace (v0.1.0) (enabled)'
Assert-True (-not (Test-InstallListing -Kind plugin -Tool codex -Lines @($codexAvailable))) 'Available Codex plugin is not installed'
Assert-True (Test-InstallListing -Kind plugin -Tool codex -Lines @($codexInstalled)) 'Installed Codex plugin counts'
Assert-True (-not (Test-InstallListing -Kind plugin -Tool copilot -Lines @($copilotDisabled))) 'Disabled Copilot plugin is not done'
Assert-True (Test-InstallListing -Kind plugin -Tool copilot -Lines @($copilotEnabled)) 'Enabled Copilot plugin counts'
$disabledFixture = Get-Content (Join-Path $PSScriptRoot 'fixtures/claude-plugin-disabled.json')
Assert-True (-not (Test-InstallListing -Kind plugin -Tool claude -Lines $disabledFixture)) 'Disabled Claude JSON plugin is not done'
$enabledFixture = ($disabledFixture -join "`n").Replace('"enabled": false', '"enabled": true') -split "`n"
Assert-True (Test-InstallListing -Kind plugin -Tool claude -Lines $enabledFixture) 'Enabled Claude JSON plugin is done'
$script:observedClaudeList = ''
function Invoke-ClosedInput {
    param([string[]]$Command)
    $script:observedClaudeList = $Command -join '|'
    return @{ ExitCode = 0; Output = $disabledFixture }
}
Assert-True (-not (Test-InstallStepDone -Command @('claude', 'plugin', 'install', 'ps-ai@ps-ai-marketplace'))) 'Disabled Claude plugin requires install'
Assert-Equal 'claude|plugin|list|--json' $script:observedClaudeList 'Claude check requests JSON listing'

$script:installedSteps = @{}
function Test-InstallStepDone {
    param([string[]]$Command, [string]$ConfigEnv, [string]$ConfigDir)
    return [bool]$script:installedSteps[$Command -join '|']
}
function Invoke-InstallCommand {
    param([string[]]$Command, [string]$ConfigEnv, [string]$ConfigDir)
    $script:installedSteps[$Command -join '|'] = $true
    'installed'
}
$firstInstall = @(Invoke-LegionInstallSteps -Tool codex -Source 'local source' -ConfigEnv CODEX_HOME -ConfigDir 'fixture-account')
Assert-Equal 3 @($firstInstall | Where-Object { $_ -eq 'installed' }).Count 'First install adds and refreshes marketplace, then installs plugin'
$secondInstall = @(Invoke-LegionInstallSteps -Tool codex -Source 'local source' -ConfigEnv CODEX_HOME -ConfigDir 'fixture-account')
Assert-Equal 2 @($secondInstall | Where-Object { $_ -match '^skip: .*\(already done\)$' }).Count 'Second install skips both steps'

# Listing checks must inspect the selected account rather than the caller's default account.
. $script -NoRun
$script:installCatalog = Get-InstallCatalog -Source $root
$savedCodexHome = $env:CODEX_HOME
try {
    $env:CODEX_HOME = 'default-account'
    function Invoke-ClosedInput {
        param([string[]]$Command)
        if ($env:CODEX_HOME -eq 'selected-account') {
            return @{ ExitCode = 0; Output = @('ps-ai@ps-ai-marketplace  installed, enabled') }
        }
        return @{ ExitCode = 0; Output = @('ps-ai@ps-ai-marketplace  not installed') }
    }
    Assert-True (Test-InstallStepDone -Command @('codex', 'plugin', 'add', 'ps-ai@ps-ai-marketplace') -ConfigEnv CODEX_HOME -ConfigDir 'selected-account') 'Install check sees selected account listing'
    Assert-Equal 'default-account' $env:CODEX_HOME 'Install check restores caller account'
} finally {
    $env:CODEX_HOME = $savedCodexHome
}

# Exact plugin identity and Boolean enabled state are runtime boundaries.
& {
    . $script -NoRun
    $catalog = Get-InstallCatalog -Source $root
    $script:installCatalog = $catalog
    foreach ($json in @('[{"id":["ps-ai@ps-ai-marketplace","other"],"enabled":true}]','[{"id":"ps-ai@ps-ai-marketplace","enabled":"true"}]','[{"id":"ps-ai@ps-ai-marketplace-old","enabled":true}]','[{"id":"ps-ai@ps-ai-marketplace","enabled":false}]')) {
        Assert-True (-not (Test-InstallListing -Kind plugin -Tool claude -Lines @($json))) 'Only exact id and Boolean true count'
    }
    $fourth = Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/ps-ai-fourth/tool.json') -Raw | ConvertFrom-Json
    $fourth.plugin.marketplaceAdd = @('register','{source}','prefix-{source}')
    $script:installCatalog.tools += $fourth
    Assert-Equal 'fourth-cli|register|local source|prefix-local source' ((Get-InstallCommands -Tool fourth -Source 'local source')[0] -join '|') 'Source tokens are replaced within arguments'
}
