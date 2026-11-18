$root = Split-Path $PSScriptRoot -Parent
$script = Join-Path $root 'install.ps1'
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
Assert-Equal 'CLAUDE_CONFIG_DIR' (Get-ConfigEnvName -Tool claude) 'Claude config variable'
Assert-Equal 'CODEX_HOME' (Get-ConfigEnvName -Tool codex) 'Codex config variable'
Assert-Equal 'COPILOT_HOME' (Get-ConfigEnvName -Tool copilot) 'Copilot config variable'
$previewLines = @(Invoke-PsAiInstaller -Tools claude -Source 'local source' -ConfigDir X -DryRun -Catalog (Get-Content (Join-Path $PSScriptRoot 'fixtures/install/catalog.json') -Raw | ConvertFrom-Json))
Assert-True $? 'Injected dry run succeeds'
Assert-True ($previewLines -contains 'CLAUDE_CONFIG_DIR=X claude plugin marketplace add "local source"') 'Dry run marketplace command'
Assert-True ($previewLines -contains 'CLAUDE_CONFIG_DIR=X claude plugin install ps-ai@ps-ai-marketplace') 'Dry run plugin command'
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
$claudeEnabled = '  ❯ ps-ai@ps-ai-marketplace'
Assert-True (-not (Test-InstallListing -Kind plugin -Lines @($codexAvailable))) 'Available Codex plugin is not installed'
Assert-True (Test-InstallListing -Kind plugin -Lines @($codexInstalled)) 'Installed Codex plugin counts'
Assert-True (-not (Test-InstallListing -Kind plugin -Lines @($copilotDisabled))) 'Disabled Copilot plugin is not done'
Assert-True (Test-InstallListing -Kind plugin -Lines @($copilotEnabled)) 'Enabled Copilot plugin counts'
Assert-True (Test-InstallListing -Kind plugin -Lines @($claudeEnabled)) 'Claude listing counts'
Assert-True (Test-InstallListing -Kind marketplace -Lines @('ps-ai-marketplace       C:\repo')) 'Codex marketplace line'
Assert-True (-not (Test-InstallListing -Kind marketplace -Lines @('ps-ai-marketplace-old  C:\x'))) 'Similar marketplace name does not count'
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
$firstInstall = @(Invoke-PsAiInstallSteps -Tool codex -Source 'local source' -ConfigEnv CODEX_HOME -ConfigDir 'fixture-account')
Assert-Equal 2 @($firstInstall | Where-Object { $_ -eq 'installed' }).Count 'First install performs both steps'
$secondInstall = @(Invoke-PsAiInstallSteps -Tool codex -Source 'local source' -ConfigEnv CODEX_HOME -ConfigDir 'fixture-account')
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

# FourthToolStandaloneAndStrictListings: id is not an executable and string true is not enabled.
& {
    . $script -NoRun
    $catalog = Get-InstallCatalog -Source $root
    $fourth = Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/ps-ai-fourth/tool.json') -Raw | ConvertFrom-Json
    $entry = [pscustomobject]@{ id='fourth'; command='fourth-cli'; configEnv='FOURTH_HOME'; plugin=$fourth.plugin; hooks=$fourth.hooks; installHint='install fourth-cli' }
    $catalog.tools += $entry
    $script:installCatalog = Get-InstallCatalog -Catalog $catalog
    $commands = Get-InstallCommands -Tool fourth -Source 'local source'
    Assert-Equal 'fourth-cli' $commands[0][0] 'Fourth executable comes from catalog'
    Assert-Equal 'local source' $commands[0][4] 'Source replacement remains one argument'
    Assert-Equal 'FOURTH_HOME' (Get-ConfigEnvName fourth) 'Fourth environment comes from catalog'
    $state = @{ Commands=[Collections.Generic.List[string]]::new(); Versions=0; Detect=[Collections.Generic.List[string]]::new() }
    function Invoke-ClosedInput {
        param($Command)
        $state.Commands.Add(($Command -join '|'))
        Assert-Equal 'selected' $env:FOURTH_HOME 'Listing uses selected account'
        return @{ExitCode=0; Output=@('ps-ai@ps-ai-marketplace enabled')}
    }
    $previous = $env:FOURTH_HOME
    try {
        $env:FOURTH_HOME='default'
        Assert-True (Test-InstallStepDone -Command $commands[1] -ConfigEnv FOURTH_HOME -ConfigDir selected) 'Fourth listing can skip installed plugin'
        Assert-Equal 'fourth-cli|plugin|list' $state.Commands[0] 'Fourth listing uses catalog argv'
        Assert-Equal 'default' $env:FOURTH_HOME 'Listing restores caller env'
        function Invoke-ClosedInput { throw 'fixture launch failure' }
        Assert-Throws { Test-InstallStepDone -Command $commands[1] -ConfigEnv FOURTH_HOME -ConfigDir selected } 'Listing failure propagates'
        Assert-Equal 'default' $env:FOURTH_HOME 'Listing restores caller env on failure'
        Assert-Throws { Invoke-InstallCommand -Command $commands[1] -ConfigEnv FOURTH_HOME -ConfigDir selected } 'Install failure propagates'
        Assert-Equal 'default' $env:FOURTH_HOME 'Install restores caller env on failure'
    } finally { $env:FOURTH_HOME=$previous }
    foreach ($json in @('[{"id":"ps-ai@ps-ai-marketplace","enabled":"true"}]','[{"id":"ps-ai@ps-ai-marketplace-old","enabled":true}]','not json','[{"id":"ps-ai@ps-ai-marketplace","enabled":false}]')) {
        Assert-True (-not (Test-InstallListing -Kind plugin -Tool claude -Lines @($json))) 'Only exact id and Boolean true count'
    }
    foreach ($line in @('ps-ai@ps-ai-marketplace-old enabled','ps-ai@ps-ai-marketplace disabled','ps-ai@ps-ai-marketplace not installed')) {
        Assert-True (-not (Test-InstallListing -Kind plugin -Tool fourth -Lines @($line))) 'Line listing requires full id and enabled state'
    }
    $entry.plugin.listing = [pscustomobject]@{format='json';idField='key';enabledField='active'}
    Assert-True (Test-InstallListing -Kind plugin -Tool fourth -Lines @('[{"key":"ps-ai@ps-ai-marketplace","active":true}]')) 'JSON fields come from catalog'
    function Ensure-InstallPowerShell { return $true }
    function Test-InstallCommandAvailable { param($Name) $state.Detect.Add($Name); $Name -eq 'fourth-cli' }
    function Test-InstallStepDone { return $false }
    function Invoke-InstallCommand { param($Command) $state.Commands.Add(($Command -join '|')) }
    function fourth-cli { param($Version) Assert-Equal '--version' $Version 'Version uses descriptor executable'; $state.Versions++; 'fixture-version' }
    $null = Invoke-PsAiInstaller -Source 'example/market' -Catalog $catalog
    Assert-True ($state.Detect -contains 'fourth-cli') 'Automatic detection uses executable'
    Assert-Equal 1 $state.Versions 'Detected fourth tool version executes once'
    $entry.hooks.hint='fourth hook hint'
    $preview = @(Invoke-PsAiInstaller -Tools fourth -Source 'example/market' -Catalog $catalog -DryRun)
    Assert-Equal 1 @($preview | Where-Object { $_ -eq 'fourth hook hint' }).Count 'Catalog hint printed once in dry run'
    $entry.hooks.hint=''
    $preview = @(Invoke-PsAiInstaller -Tools fourth -Source 'example/market' -Catalog $catalog -DryRun)
    Assert-Equal 2 $preview.Count 'Empty hint adds no output'
    $entry.plugin.marketplaceAdd = @('register','{source}','prefix-{source}')
    Assert-Equal 'fourth-cli|register|local source|prefix-{source}' ((Get-InstallCommands -Tool fourth -Source 'local source')[0] -join '|') 'Only entire source argument is substituted'
}
