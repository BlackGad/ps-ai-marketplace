# Integration suite: install, setup and uninstall on a clean runner with the real CLIs and no login.
# CI only. Without -NoRun the script refuses to start unless CI is "true", so a local run never touches a real home.
# Steps are data: @{ Name; DependsOn = @(<names>); First = { }; Repeat = { } }. A block throws to fail and may return @{ Skipped = '<reason>' }.
param(
    [string]$Out,
    [string]$HomeRoot,
    [string]$Checkout,
    [switch]$NoRun
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../lib/junit.ps1')
. (Join-Path $PSScriptRoot '../lib/benchmark.ps1')
. (Join-Path $PSScriptRoot '../../plugins/ps-ai/bin/lib/installed.ps1')

function Get-IntegrationOs {
    if ($IsWindows) { return 'windows' }
    if ($IsMacOS) { return 'macos' }
    return 'linux'
}

# ---- Engine: runs steps, reports, hashes -------------------------------------------------------

function Invoke-IntegrationBlock {
    param([scriptblock]$Block)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $result = 'passed'
    $message = ''
    $output = @()
    try {
        $output = @(& $Block)
        $skip = @($output | Where-Object { $_ -is [hashtable] -and $_.ContainsKey('Skipped') })
        if ($skip.Count) { $result = 'skipped'; $message = [string]$skip[0].Skipped }
    } catch {
        $result = 'failed'
        $message = $_.Exception.Message
    }
    $watch.Stop()
    $text = (@($output | Where-Object { $_ -isnot [hashtable] } | ForEach-Object { "$_" }) + @($message | Where-Object { $_ })) -join "`n"
    return @{ Seconds = $watch.Elapsed.TotalSeconds; Result = $result; Message = $message; Log = $text }
}

function New-IntegrationCase {
    param([string]$Name, [double]$Seconds, [string]$Result, [string]$Message, [bool]$Repeat)
    $caseName = if ($Repeat) { "$Name (repeat)" } else { $Name }
    return [pscustomobject]@{ Name = $caseName; Seconds = $Seconds; Result = $Result; Message = $Message; Repeat = $Repeat }
}

function Invoke-IntegrationSteps {
    param([object[]]$Steps, [string]$LogFolder)
    $outcome = @{}
    foreach ($step in $Steps) {
        $name = $step.Name
        $blocker = @($step.DependsOn | Where-Object { $outcome[$_] -ne 'passed' })[0]
        if ($blocker) {
            New-IntegrationCase $name 0 'skipped' "needs $blocker" $false
            New-IntegrationCase $name 0 'skipped' "needs $blocker" $true
            $outcome[$name] = 'skipped'
            continue
        }
        $first = Invoke-IntegrationBlock $step.First
        New-IntegrationCase $name $first.Seconds $first.Result $first.Message $false
        $repeatMessage = if ($first.Result -eq 'skipped') { $first.Message } else { 'first run did not pass' }
        $final = $first.Result
        if ($first.Result -eq 'passed') {
            $repeat = Invoke-IntegrationBlock $step.Repeat
            New-IntegrationCase $name $repeat.Seconds $repeat.Result $repeat.Message $true
            $final = $repeat.Result
        } else {
            New-IntegrationCase $name 0 'skipped' $repeatMessage $true
        }
        $outcome[$name] = $final
        if ($LogFolder) {
            New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $LogFolder "$name.log") -Value $first.Log
            if ($repeat) { Set-Content -LiteralPath (Join-Path $LogFolder "$name-repeat.log") -Value $repeat.Log }
        }
        $repeat = $null
    }
}

# Step 0: never a case and never a failure. A check that throws means the tool is not there.
function Get-IntegrationProbe {
    param([System.Collections.IDictionary]$Checks)
    foreach ($entry in $Checks.GetEnumerator()) {
        try { $value = @(& $entry.Value)[0] } catch { $value = $null }
        if ($value) { "$($entry.Key): $value" } else { "$($entry.Key): not found" }
    }
}

function Get-IntegrationProbeChecks {
    $tool = { param($Command, $Argument) (& (Get-Command $Command -ErrorAction Stop).Source $Argument 2>&1 | Select-Object -First 1) }
    return [ordered]@{
        winget     = { & $tool 'winget' '--version' }.GetNewClosure()
        pwsh       = { $PSVersionTable.PSVersion.ToString() }
        powershell = { & $tool 'powershell' '-Version' }.GetNewClosure()
        node       = { & $tool 'node' '--version' }.GetNewClosure()
        git        = { & $tool 'git' '--version' }.GetNewClosure()
    }
}

function Get-StepBaseName {
    param([string]$CaseName)
    return $CaseName -replace ' \(repeat\)$', ''
}

function Write-IntegrationReport {
    param([string]$Out, [string]$Os, [object[]]$Cases, [string[]]$Probe, [string]$Extra)
    New-Item -ItemType Directory -Path $Out -Force | Out-Null
    $suite = "integration.$Os"
    $junitCases = foreach ($case in $Cases) {
        [pscustomobject]@{ Name = $case.Name; ClassName = $suite; Seconds = $case.Seconds; Result = $case.Result; Message = $case.Message }
    }
    Write-JUnitFile -Path (Join-Path $Out "integration-$Os.xml") -SuiteName $suite -Cases $junitCases

    # The benchmark adds " (repeat)" itself, so it gets the step name without it.
    $benchCases = foreach ($case in $Cases) {
        [pscustomobject]@{ Name = Get-StepBaseName $case.Name; Seconds = $case.Seconds; Result = $case.Result; Repeat = $case.Repeat }
    }
    $entries = @(New-BenchmarkEntries -Os $Os -Cases $benchCases -Extra $Extra)
    Write-BenchmarkFile -Path (Join-Path $Out "integration-bench-$Os.json") -Entries $entries

    $lines = @("## Integration ($Os)", '', '### Probe', '')
    $lines += @($Probe | ForEach-Object { "- $_" })
    $lines += @('', '| step | first s | repeat s | result |', '| --- | --- | --- | --- |')
    $notes = @()
    foreach ($stepName in @($Cases | ForEach-Object { Get-StepBaseName $_.Name } | Select-Object -Unique)) {
        $first = @($Cases | Where-Object { -not $_.Repeat -and (Get-StepBaseName $_.Name) -eq $stepName })[0]
        $repeat = @($Cases | Where-Object { $_.Repeat -and (Get-StepBaseName $_.Name) -eq $stepName })[0]
        $result = if ($first.Result -eq 'passed' -and $repeat.Result -ne 'passed') { $repeat.Result } else { $first.Result }
        $lines += "| $stepName | $(Format-JUnitSeconds $first.Seconds) | $(Format-JUnitSeconds $repeat.Seconds) | $result |"
        foreach ($case in @($first, $repeat)) {
            if ($case.Result -ne 'passed') { $notes += "- ``$($case.Name)`` $($case.Result): $(($case.Message -split "`n")[0])" }
        }
    }
    if ($notes.Count) { $lines += @('', '### Details', '') + $notes }
    $text = ($lines -join "`n") + "`n"
    Set-Content -LiteralPath (Join-Path $Out 'summary.md') -Value $text -NoNewline
    if ($env:GITHUB_STEP_SUMMARY) { Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $text -NoNewline }
}

# Hashes relative paths and file contents, so a repeat run can prove nothing changed.
function Get-TreeHash {
    param([string]$Path)
    $base = (Resolve-Path -LiteralPath $Path).ProviderPath
    $items = [System.Collections.Generic.List[string]]::new()
    foreach ($item in Get-ChildItem -LiteralPath $base -Recurse -Force) {
        $relative = [IO.Path]::GetRelativePath($base, $item.FullName).Replace('\', '/')
        if ($item.PSIsContainer) { $items.Add("dir:$relative") }
        else { $items.Add("file:${relative}:$((Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash)") }
    }
    $sorted = $items.ToArray()
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    $bytes = [Text.Encoding]::UTF8.GetBytes($sorted -join "`n")
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
}

# ---- Real steps: call the repository scripts by path -------------------------------------------

$script:Ctx = @{}
$script:IntegrationTools = @('claude', 'codex', 'copilot')

# Runs a repository script in its own pwsh. Plain values are quoted, -Names are not, arrays become a,b,c.
function Invoke-IntegrationScript {
    param([string]$Script, [object[]]$Arguments = @())
    $quote = { param($value) "'" + ([string]$value).Replace("'", "''") + "'" }
    $words = foreach ($argument in $Arguments) {
        if ($argument -is [array]) { ($argument | ForEach-Object { & $quote $_ }) -join ',' }
        elseif ("$argument".StartsWith('-')) { "$argument" }
        else { & $quote $argument }
    }
    $command = "& $(& $quote $Script) $($words -join ' '); exit `$LASTEXITCODE"
    $lines = @(& pwsh -NoProfile -Command $command 2>&1 | ForEach-Object { "$_" })
    if ($LASTEXITCODE -ne 0) { throw "$(Split-Path $Script -Leaf) exited $LASTEXITCODE`n$($lines -join "`n")" }
    return $lines
}

function Assert-IntegrationText {
    param([string[]]$Lines, [string]$Text)
    if (-not ($Lines -join "`n").Contains($Text)) { throw "expected '$Text' in the output:`n$($Lines -join "`n")" }
}

function Assert-IntegrationTrue {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-IntegrationBin { return Join-Path $script:Ctx.Checkout 'plugins/ps-ai/bin' }

function Get-IntegrationToolInfo {
    param([string]$Tool)
    $json = Get-Content -LiteralPath (Join-Path $script:Ctx.Checkout "plugins/ps-ai/skills/ps-ai-$Tool/tool.json") -Raw | ConvertFrom-Json
    return $json
}

function Resolve-IntegrationFolder {
    param([string]$Folder)
    if ($Folder.StartsWith('~')) { return Join-Path $script:Ctx.HomeRoot $Folder.Substring(1).TrimStart('/', '\') }
    return $Folder
}

function Get-IntegrationToolFolder {
    param([string]$Tool)
    return Resolve-IntegrationFolder (Get-IntegrationToolInfo $Tool).plugin.defaultConfigDir
}

function Get-IntegrationPluginVersion {
    param([string]$Tool, [string]$Folder)
    return Get-PsAiInstalledVersion -ConfigDir $Folder -Tool (Get-IntegrationToolInfo $Tool)
}

function Get-CheckoutVersion {
    return (Get-Content -LiteralPath (Join-Path $script:Ctx.Checkout 'plugins/ps-ai/plugin.json') -Raw | ConvertFrom-Json).version
}

# `<cli> plugin list` against the config folder the install used.
function Get-IntegrationPluginList {
    param([string]$Tool, [string]$Folder)
    $envName = (Get-IntegrationToolInfo $Tool).configEnv
    $saved = [Environment]::GetEnvironmentVariable($envName)
    [Environment]::SetEnvironmentVariable($envName, $Folder)
    try { $lines = @(& $Tool plugin list 2>&1 | ForEach-Object { "$_" }) }
    finally { [Environment]::SetEnvironmentVariable($envName, $saved) }
    if ($LASTEXITCODE -ne 0) { throw "$Tool plugin list exited $LASTEXITCODE" }
    return $lines
}

function Get-IntegrationSettings {
    $path = Join-Path $script:Ctx.HomeRoot '.legion/configuration/ps-ai-personalisation.json'
    return @{ Path = $path; Data = (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json) }
}

function Get-IntegrationSource { return $script:Ctx.Source }

# Local-folder fallback (spec risk note): a CLI that refuses the checkout is tested from GitHub on main push runs only.
function Test-IntegrationMainPush {
    return ($env:GITHUB_REF -eq 'refs/heads/main' -and $env:GITHUB_EVENT_NAME -eq 'push')
}

# Step 1
function Invoke-CliInstallFirst {
    param([string]$Tool)
    $lines = Invoke-IntegrationScript (Join-Path (Get-IntegrationBin) 'ps-ai-install-tool.ps1') @('-Tool', $Tool, '-Yes')
    $version = @(& $Tool --version 2>&1 | ForEach-Object { "$_" })
    Assert-IntegrationTrue ($LASTEXITCODE -eq 0) "$Tool --version exited $LASTEXITCODE"
    $script:Ctx.Versions[$Tool] = $version -join ' '
    return $lines
}

function Invoke-CliInstallRepeat {
    param([string]$Tool)
    $lines = Invoke-IntegrationScript (Join-Path (Get-IntegrationBin) 'ps-ai-install-tool.ps1') @('-Tool', $Tool, '-Yes')
    Assert-IntegrationText $lines 'skip:'
    $version = @(& $Tool --version 2>&1 | ForEach-Object { "$_" }) -join ' '
    Assert-IntegrationTrue ($LASTEXITCODE -eq 0 -and $version -eq $script:Ctx.Versions[$Tool]) "$Tool version changed on the repeat run"
    return $lines
}

# Step 2
function Invoke-PsAiInstall {
    param([string]$Source)
    $lines = @()
    foreach ($tool in $script:IntegrationTools) {
        $lines += Invoke-IntegrationScript (Join-Path $script:Ctx.Checkout 'install.ps1') @('-Source', $Source, '-Tools', $tool, '-Yes', '-HomeRoot', $script:Ctx.HomeRoot)
    }
    return $lines
}

function Invoke-PsAiInstallFirst {
    try { $lines = Invoke-PsAiInstall -Source $script:Ctx.Checkout }
    catch {
        if (-not (Test-IntegrationMainPush)) {
            return @{ Skipped = "a CLI did not install ps-ai from the checkout, so it was not tested from it: $(($_.Exception.Message -split "`n")[0])" }
        }
        $script:Ctx.Source = 'BlackGad/ps-ai-marketplace'
        $lines = Invoke-PsAiInstall -Source $script:Ctx.Source
    }
    $expected = Get-CheckoutVersion
    foreach ($tool in $script:IntegrationTools) {
        $folder = Get-IntegrationToolFolder $tool
        Assert-IntegrationText (Get-IntegrationPluginList $tool $folder) 'ps-ai'
        $found = Get-IntegrationPluginVersion $tool $folder
        Assert-IntegrationTrue ($found -eq $expected) "$tool has ps-ai $found, expected $expected"
    }
    $script:Ctx.HomeHash = Get-TreeHash $script:Ctx.HomeRoot
    return $lines
}

function Invoke-PsAiInstallRepeat {
    $lines = Invoke-PsAiInstall -Source $script:Ctx.Source
    Assert-IntegrationText $lines 'skip:'
    Assert-IntegrationTrue ((Get-TreeHash $script:Ctx.HomeRoot) -eq $script:Ctx.HomeHash) 'the home changed on the repeat run'
    return $lines
}

# Steps 3 and 4: setup with the checkout as the plugin source.
function Invoke-Setup {
    param([string[]]$Add, [string]$Id)
    $arguments = @('-Add', $Add)
    if ($Id) { $arguments += @('-Id', $Id) }
    $arguments += @('-Yes', '-HomeRoot', $script:Ctx.HomeRoot, '-Source', (Get-IntegrationSource))
    return Invoke-IntegrationScript (Join-Path (Get-IntegrationBin) 'ps-ai-setup.ps1') $arguments
}

function Invoke-SetupFirst {
    $lines = Invoke-Setup -Add $script:IntegrationTools
    $settings = Get-IntegrationSettings
    Invoke-IntegrationScript (Join-Path (Get-IntegrationBin) 'ps-ai-validate.ps1') @('-Kind', 'personalisation', '-Path', $settings.Path) | Out-Null
    Assert-IntegrationTrue (Test-Path -LiteralPath (Join-Path (Split-Path $settings.Path) 'ps-ai-notes.md')) 'ps-ai-notes.md is missing'
    $ids = @($settings.Data.agents | ForEach-Object id)
    foreach ($id in 'claude1', 'codex1', 'copilot1') {
        Assert-IntegrationTrue ($ids -contains $id) "account $id is missing"
        Assert-IntegrationText $lines "log in: run $id"
    }
    $bin = Join-Path $script:Ctx.HomeRoot '.legion/bin'
    Assert-IntegrationTrue (@(Get-ChildItem -LiteralPath $bin -File -ErrorAction SilentlyContinue).Count -gt 0) 'no owner commands in .legion/bin'
    Assert-AccountsHavePsAi $settings.Data.agents
    if ($IsWindows) {
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        Assert-IntegrationTrue ($userPath.Split(';') -contains $bin) '.legion/bin is not on the user PATH'
    } else {
        Assert-IntegrationText $lines 'export PATH='
    }
    $script:Ctx.HomeHash = Get-TreeHash $script:Ctx.HomeRoot
    return $lines
}

function Assert-AccountsHavePsAi {
    param([object[]]$Agents)
    $expected = Get-CheckoutVersion
    foreach ($agent in $Agents) {
        $found = Get-IntegrationPluginVersion $agent.tool (Resolve-IntegrationFolder $agent.configDir)
        Assert-IntegrationTrue ($found -eq $expected) "$($agent.id) has ps-ai $found, expected $expected"
    }
}

function Invoke-SetupRepeat {
    $lines = Invoke-Setup -Add $script:IntegrationTools
    Assert-IntegrationText $lines 'skip:'
    Assert-IntegrationTrue ((Get-TreeHash $script:Ctx.HomeRoot) -eq $script:Ctx.HomeHash) 'the home changed on the repeat run'
    return $lines
}

function Invoke-AddFirst {
    $lines = Invoke-Setup -Add @('claude') -Id 'ci-extra'
    $settings = Get-IntegrationSettings
    $agent = @($settings.Data.agents | Where-Object id -eq 'ci-extra')
    Assert-IntegrationTrue ($agent.Count -eq 1) 'account ci-extra was not recorded'
    Assert-IntegrationTrue (Test-Path -LiteralPath (Resolve-IntegrationFolder $agent[0].configDir) -PathType Container) 'ci-extra folder was not created'
    Assert-AccountsHavePsAi $agent
    $script:Ctx.AgentCount = @($settings.Data.agents).Count
    return $lines
}

function Invoke-AddRepeat {
    $lines = Invoke-Setup -Add @('claude') -Id 'ci-extra'
    Assert-IntegrationText $lines 'skip: account ci-extra (already done)'
    Assert-IntegrationTrue (@((Get-IntegrationSettings).Data.agents).Count -eq $script:Ctx.AgentCount) 'the repeat run added an account'
    return $lines
}

# Step 5
function Invoke-AccountRemove {
    return Invoke-IntegrationScript (Join-Path (Get-IntegrationBin) 'ps-ai-account.ps1') @('-Action', 'remove', '-Id', 'ci-extra', '-HomeRoot', $script:Ctx.HomeRoot)
}

function Invoke-RemoveFirst {
    $folder = Resolve-IntegrationFolder (@((Get-IntegrationSettings).Data.agents | Where-Object id -eq 'ci-extra')[0].configDir)
    $lines = Invoke-AccountRemove
    Assert-IntegrationTrue (@((Get-IntegrationSettings).Data.agents | Where-Object id -eq 'ci-extra').Count -eq 0) 'ci-extra is still in the settings'
    Assert-IntegrationTrue (Test-Path -LiteralPath $folder -PathType Container) 'the ci-extra folder was removed'
    Assert-IntegrationText $lines 'Config folder kept at'
    return $lines
}

function Invoke-RemoveRepeat {
    $lines = Invoke-AccountRemove
    Assert-IntegrationText $lines 'skip: account remove ci-extra (already done)'
    return $lines
}

# Steps 6 and 7: throwaway Git repositories.
function New-IntegrationRepo {
    param([string]$Name)
    $repo = Join-Path $script:Ctx.Work $Name
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    git -C $repo init --quiet
    git -C $repo config user.name 'integration'
    git -C $repo config user.email 'integration@example.com'
    git -C $repo config commit.gpgsign false
    Set-Content -LiteralPath (Join-Path $repo 'README.md') -Value $Name
    git -C $repo add README.md
    git -C $repo commit --quiet -m 'initial'
    return $repo
}

function Invoke-RepositoryScript {
    param([string]$Repo, [string]$Mode)
    return Invoke-IntegrationScript (Join-Path (Get-IntegrationBin) 'ps-ai-repository.ps1') @('-Repo', $Repo, '-Mode', $Mode, '-Gate', 'pwsh -NoProfile -Command exit 0')
}

function Get-CommitCount {
    param([string]$Repo)
    return [int](git -C $Repo rev-list --count HEAD)
}

function Assert-LegionItems {
    param([string]$Repo)
    foreach ($item in 'configuration/project.json', 'configuration/workflow.md', 'scripts/index.md', 'scripts/check-task.ps1', 'state/handoff.md') {
        Assert-IntegrationTrue (Test-Path -LiteralPath (Join-Path $Repo ".legion/$item")) ".legion/$item is missing"
    }
    Invoke-IntegrationScript (Join-Path (Get-IntegrationBin) 'ps-ai-validate.ps1') @('-Kind', 'project', '-Path', (Join-Path $Repo '.legion/configuration/project.json')) | Out-Null
}

function Invoke-RepoPrivateFirst {
    $repo = New-IntegrationRepo 'repo-a'
    $lines = Invoke-RepositoryScript $repo 'Private'
    Assert-LegionItems $repo
    Assert-IntegrationTrue ((Get-CommitCount (Join-Path $repo '.legion')) -ge 1) 'the inner .legion repository has no commit'
    Assert-IntegrationTrue ((Get-CommitCount $repo) -eq 1) 'the outer repository got a commit'
    Assert-IntegrationTrue (-not (git -C $repo status --porcelain)) 'the outer repository has changes beyond the ignore rule'
    $script:Ctx.InnerCommits = Get-CommitCount (Join-Path $repo '.legion')
    return $lines
}

function Invoke-RepoPrivateRepeat {
    $repo = Join-Path $script:Ctx.Work 'repo-a'
    $lines = Invoke-RepositoryScript $repo 'Private'
    Assert-IntegrationText $lines 'skip: Private orchestration (already done)'
    Assert-IntegrationTrue ((Get-CommitCount (Join-Path $repo '.legion')) -eq $script:Ctx.InnerCommits) 'the repeat run made a commit'
    return $lines
}

function Invoke-RepoSharedFirst {
    $repo = New-IntegrationRepo 'repo-b'
    $lines = Invoke-RepositoryScript $repo 'Shared'
    Assert-LegionItems $repo
    $rules = [regex]::Matches((Get-Content -LiteralPath (Join-Path $repo 'AGENTS.md') -Raw), '(?m)^## ps-ai orchestration').Count
    Assert-IntegrationTrue ($rules -eq 1) "AGENTS.md has the rules block $rules times"
    Assert-IntegrationTrue ((Get-CommitCount $repo) -eq 2) 'expected exactly one new commit'
    Assert-IntegrationTrue ((git -C $repo log -1 --format=%s) -eq 'Set up ps-ai orchestration') 'unexpected commit subject'
    Assert-IntegrationTrue (-not (git -C $repo status --porcelain)) 'files were left uncommitted'
    return $lines
}

function Invoke-RepoSharedRepeat {
    $repo = Join-Path $script:Ctx.Work 'repo-b'
    $lines = Invoke-RepositoryScript $repo 'Shared'
    Assert-IntegrationText $lines 'skip:'
    Assert-IntegrationTrue ((Get-CommitCount $repo) -eq 2) 'the repeat run made a commit'
    return $lines
}

# Step 8
function Invoke-UninstallFirst {
    $lines = Invoke-IntegrationScript (Join-Path $script:Ctx.Checkout 'install.ps1') @('-Uninstall', '-Yes', '-HomeRoot', $script:Ctx.HomeRoot)
    foreach ($tool in $script:IntegrationTools) {
        $folder = Get-IntegrationToolFolder $tool
        Assert-IntegrationTrue ($null -eq (Get-IntegrationPluginVersion $tool $folder)) "ps-ai is still in the $tool folder"
        Assert-IntegrationTrue (-not ((Get-IntegrationPluginList $tool $folder) -join "`n").Contains('ps-ai')) "$tool still lists ps-ai"
        & $tool --version | Out-Null
        Assert-IntegrationTrue ($LASTEXITCODE -eq 0) "$tool is no longer installed"
    }
    $bin = Join-Path $script:Ctx.HomeRoot '.legion/bin'
    Assert-IntegrationTrue (@(Get-ChildItem -LiteralPath $bin -File -ErrorAction SilentlyContinue).Count -eq 0) 'owner commands are still in .legion/bin'
    foreach ($kept in 'configuration', 'agents') {
        Assert-IntegrationTrue (Test-Path -LiteralPath (Join-Path $script:Ctx.HomeRoot ".legion/$kept") -PathType Container) ".legion/$kept was removed"
    }
    return $lines
}

function Invoke-UninstallRepeat {
    return Invoke-IntegrationScript (Join-Path $script:Ctx.Checkout 'install.ps1') @('-Uninstall', '-Yes', '-HomeRoot', $script:Ctx.HomeRoot)
}

# The steps in the spec's order 1-8. Building them touches nothing; only running a block does.
function Get-IntegrationSteps {
    param([string]$HomeRoot, [string]$Checkout, [string]$Work, [string]$Os)
    $script:Ctx = @{ HomeRoot = $HomeRoot; Checkout = $Checkout; Work = $Work; Os = $Os; Source = $Checkout; Versions = [ordered]@{} }
    $steps = @()
    foreach ($tool in $script:IntegrationTools) {
        $steps += @{
            Name = "install-cli-$tool"; DependsOn = @()
            First = [scriptblock]::Create("Invoke-CliInstallFirst '$tool'")
            Repeat = [scriptblock]::Create("Invoke-CliInstallRepeat '$tool'")
        }
    }
    $cliSteps = @($script:IntegrationTools | ForEach-Object { "install-cli-$_" })
    $steps += @{ Name = 'install-ps-ai'; DependsOn = $cliSteps; First = { Invoke-PsAiInstallFirst }; Repeat = { Invoke-PsAiInstallRepeat } }
    $steps += @{ Name = 'setup'; DependsOn = @('install-ps-ai'); First = { Invoke-SetupFirst }; Repeat = { Invoke-SetupRepeat } }
    $steps += @{ Name = 'add'; DependsOn = @('setup'); First = { Invoke-AddFirst }; Repeat = { Invoke-AddRepeat } }
    $steps += @{ Name = 'remove'; DependsOn = @('add'); First = { Invoke-RemoveFirst }; Repeat = { Invoke-RemoveRepeat } }
    $steps += @{ Name = 'repo-private'; DependsOn = @(); First = { Invoke-RepoPrivateFirst }; Repeat = { Invoke-RepoPrivateRepeat } }
    $steps += @{ Name = 'repo-shared'; DependsOn = @(); First = { Invoke-RepoSharedFirst }; Repeat = { Invoke-RepoSharedRepeat } }
    $steps += @{ Name = 'uninstall'; DependsOn = @('setup'); First = { Invoke-UninstallFirst }; Repeat = { Invoke-UninstallRepeat } }
    return $steps
}

# ---- Main -------------------------------------------------------------------------------------

if ($NoRun) { return }

if ($env:CI -ne 'true') {
    Write-Error 'tests/integration/run.ps1 installs real tools into a throwaway home and only runs in CI (CI=true).'
    exit 1
}
if (-not $Out) { throw '-Out <folder> is required' }
if (-not $HomeRoot) { $HomeRoot = Join-Path $env:RUNNER_TEMP 'ps-ai-home' }
if (-not $Checkout) { $Checkout = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent }
$os = Get-IntegrationOs
$work = Join-Path (Split-Path $HomeRoot -Parent) 'ps-ai-work'
New-Item -ItemType Directory -Path $HomeRoot, $work, $Out -Force | Out-Null

$probe = @(Get-IntegrationProbe -Checks (Get-IntegrationProbeChecks))
$steps = Get-IntegrationSteps -HomeRoot $HomeRoot -Checkout $Checkout -Work $work -Os $os
$cases = @(Invoke-IntegrationSteps -Steps $steps -LogFolder (Join-Path $Out 'logs'))
$extra = ($script:Ctx.Versions.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)" }) -join ', '
Write-IntegrationReport -Out $Out -Os $os -Cases $cases -Probe $probe -Extra $extra
if (@($cases | Where-Object Result -eq 'failed').Count) { exit 1 }
exit 0
