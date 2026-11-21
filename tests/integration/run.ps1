# Integration suite: install, setup and uninstall on a clean runner with the real CLIs and no login.
# CI only. Without -NoRun the script refuses to start unless CI is "true", so a local run never touches a real home.
# -AllowSourceFallback is set by the workflow for runs on main; it lets a CLI that refuses the checkout use the published source at the tested revision.
# Steps are data: @{ Name; DependsOn = @(<names>); First = { }; Repeat = { } }. A block throws to fail and may return @{ Skipped = '<reason>' }.
param(
    [string]$Out,
    [string]$HomeRoot,
    [string]$Checkout,
    [switch]$AllowSourceFallback,
    [switch]$NoRun
)

$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = 'PlainText'
$env:NO_COLOR = '1'
. (Join-Path $PSScriptRoot '../lib/junit.ps1')
. (Join-Path $PSScriptRoot '../lib/benchmark.ps1')
. (Join-Path $PSScriptRoot '../../plugins/ps-ai/bin/lib/installed.ps1')
$script:IntegrationScriptLog = $null

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
    $output = [Collections.Generic.List[object]]::new()
    $scriptOutput = [Collections.Generic.List[string]]::new()
    $previousLog = $script:IntegrationScriptLog
    $script:IntegrationScriptLog = $scriptOutput
    try {
        & $Block | ForEach-Object { $output.Add($_) }
        $skip = @($output | Where-Object { $_ -is [hashtable] -and $_.ContainsKey('Skipped') })
        if ($skip.Count) { $result = 'skipped'; $message = [string]$skip[0].Skipped }
    } catch {
        $result = 'failed'
        $message = $_.Exception.Message
    } finally {
        $script:IntegrationScriptLog = $previousLog
    }
    $watch.Stop()
    # Script output is recorded before callers can buffer it or throw an assertion.
    $stepOutput = @($output | Where-Object { $_ -isnot [hashtable] -and $scriptOutput -cnotcontains "$_" } | ForEach-Object { "$_" })
    $text = (@($scriptOutput) + $stepOutput + @($message | Where-Object { $_ })) -join "`n"
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
    $tool = { param($Command, [string[]]$Argument) (& (Get-Command $Command -ErrorAction Stop).Source @Argument 2>&1 | Select-Object -First 1) }
    return [ordered]@{
        winget     = { & $tool 'winget' '--version' }.GetNewClosure()
        pwsh       = { $PSVersionTable.PSVersion.ToString() }
        powershell = { & $tool 'powershell' @('-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()') }.GetNewClosure()
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

# Keep a hash per relative path so failures can name additions, removals and changes.
function Get-TreeSnapshot {
    param([string]$Path, [string[]]$Exclude = @())
    $base = (Resolve-Path -LiteralPath $Path).ProviderPath
    $items = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    foreach ($item in Get-ChildItem -LiteralPath $base -Recurse -Force) {
        $relative = [IO.Path]::GetRelativePath($base, $item.FullName).Replace('\', '/')
        if (@($Exclude | Where-Object { $relative -cmatch $_ }).Count) { continue }
        $items[$relative] = if ($item.PSIsContainer) { 'directory' } else { (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash }
    }
    return ,$items
}

function Assert-TreeUnchanged {
    param($Before, $After)
    $paths = @(@($Before.Keys) + @($After.Keys) | Sort-Object -Unique -CaseSensitive)
    $changes = @(foreach ($path in $paths) {
        if (-not $Before.ContainsKey($path)) { "added: $path" }
        elseif (-not $After.ContainsKey($path)) { "removed: $path" }
        elseif ($Before[$path] -cne $After[$path]) { "changed: $path" }
    })
    if ($changes.Count) {
        $message = @('the home changed on the repeat run:') + @($changes | Select-Object -First 20)
        if ($changes.Count -gt 20) { $message += "$($changes.Count - 20) more paths omitted" }
        throw ($message -join "`n")
    }
}

function Get-IntegrationHomeSnapshot {
    # Observed with the installed CLIs in disposable config folders, listing twice:
    $runtimePaths = @{
        claude = @() # 2.1.330: plugin and marketplace listings wrote nothing.
        # 0.171.0: per-process PATH helpers/locks; OS suffixes match codex-rs/arg0.
        codex = @('tmp', 'tmp/arg0-(windows|linux|macos)(/codex-arg0[^/]+(/.*)?)?')
        copilot = @('logs', 'logs/process-[0-9]+-[0-9]+\.log') # 1.0.114: one timestamp/pid log per invocation.
    }
    $folders = @(foreach ($tool in $script:IntegrationTools) {
        @{ Tool = $tool; Folder = Get-IntegrationToolFolder $tool }
    })
    $settings = Join-Path $script:Ctx.HomeRoot '.legion/configuration/ps-ai-personalisation.json'
    if (Test-Path -LiteralPath $settings) {
        foreach ($agent in (Get-IntegrationSettings).Data.agents) {
            $folders += @{ Tool = $agent.tool; Folder = Resolve-IntegrationFolder $agent.configDir }
        }
    }
    $exclude = @(foreach ($entry in $folders) {
        $relative = [IO.Path]::GetRelativePath($script:Ctx.HomeRoot, $entry.Folder).Replace('\', '/')
        foreach ($path in $runtimePaths[$entry.Tool]) {
            '^' + [regex]::Escape($relative) + '/' + $path + '$'
        }
    })
    return Get-TreeSnapshot $script:Ctx.HomeRoot -Exclude $exclude
}

# ---- Real steps: call the repository scripts by path -------------------------------------------

$script:Ctx = @{}
$script:IntegrationTools = @('claude', 'codex', 'copilot')
$script:MarketplaceRepo = 'BlackGad/ps-ai-marketplace'

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
    if ($null -ne $script:IntegrationScriptLog) { $script:IntegrationScriptLog.AddRange([string[]]$lines) }
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

# Install, listing and uninstall all run with each CLI's config variable pointing at the throwaway default folder.
function Set-IntegrationConfigEnvironment {
    foreach ($tool in $script:IntegrationTools) {
        [Environment]::SetEnvironmentVariable((Get-IntegrationToolInfo $tool).configEnv, (Get-IntegrationToolFolder $tool))
    }
}

function Get-IntegrationPluginVersion {
    param([string]$Tool, [string]$Folder)
    return Get-PsAiInstalledVersion -ConfigDir $Folder -Tool (Get-IntegrationToolInfo $Tool)
}

function Get-CheckoutVersion {
    return (Get-Content -LiteralPath (Join-Path $script:Ctx.Checkout 'plugins/ps-ai/plugin.json') -Raw | ConvertFrom-Json).version
}

# Tools that skipped the checkout (local-folder refusal) take no part in the later steps.
function Get-IntegrationActiveTools {
    return @($script:IntegrationTools | Where-Object { -not $script:Ctx.NotTested.Contains($_) })
}

# ---- CLI executables and listings --------------------------------------------------------------

function Get-IntegrationPersistentFolders {
    if ((Get-IntegrationOs) -eq 'windows') {
        $text = [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + [Environment]::GetEnvironmentVariable('Path', 'Machine')
        return @($text -split ';' | Where-Object { $_.Trim() } | ForEach-Object { [Environment]::ExpandEnvironmentVariables($_.Trim().Trim('"')) })
    }
    return @((Join-Path $HOME '.local/bin'))
}

# An installer changes the saved PATH, not this process; add the saved folders here so the runner and its children see the new tool.
function Resolve-IntegrationCommand {
    param([string]$Name)
    $found = @(Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue)[0]
    if (-not $found) {
        $separator = [IO.Path]::PathSeparator
        foreach ($folder in Get-IntegrationPersistentFolders) {
            if ((Test-Path -LiteralPath $folder -PathType Container) -and (@($env:PATH -split $separator) -notcontains $folder)) {
                $env:PATH = $env:PATH + $separator + $folder
            }
        }
        $found = @(Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue)[0]
    }
    if (-not $found) { throw "$Name was not found on PATH after the install" }
    return $found.Source
}

function Test-IntegrationWingetWorks {
    try { & winget --version 2>&1 | Out-Null; return ($LASTEXITCODE -eq 0) } catch { return $false }
}

# Runs the tool's own CLI with its config variable (and listing variables) set to $Folder, then puts them back.
function Invoke-IntegrationCli {
    param([string]$Tool, [string[]]$Arguments, [string]$Folder)
    $info = Get-IntegrationToolInfo $Tool
    $command = Resolve-IntegrationCommand $info.command
    $values = [ordered]@{ $info.configEnv = $Folder }
    if ($info.plugin.listingEnv) { foreach ($property in $info.plugin.listingEnv.PSObject.Properties) { $values[$property.Name] = $property.Value } }
    $saved = @{}
    foreach ($name in $values.Keys) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
    try {
        foreach ($name in $values.Keys) { [Environment]::SetEnvironmentVariable($name, $values[$name]) }
        $lines = @(& $command @Arguments 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
    } finally {
        foreach ($name in $values.Keys) {
            if ($null -eq $saved[$name]) { Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue }
            else { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
        }
    }
    return @{ ExitCode = $code; Lines = $lines }
}

# The installer's own parser, loaded in a child scope so its parameters and helpers stay out of this script.
function Test-IntegrationListing {
    param([string]$Tool, [string[]]$Lines, [switch]$IncludeDisabled, [ValidateSet('plugin', 'marketplace')][string]$Kind = 'plugin')
    return & {
        . (Join-Path $script:Ctx.Checkout 'plugins/ps-ai/install.ps1') -NoRun
        $script:installCatalog = Get-InstallCatalog -Source $script:Ctx.Checkout
        Test-InstallListing -Kind $Kind -Tool $Tool -Lines $Lines -IncludeDisabled:$IncludeDisabled
    }
}

# True when the folder lists ps-ai. A disabled entry counts as not installed unless -IncludeDisabled.
function Test-IntegrationPluginListed {
    param([string]$Tool, [string]$Folder, [switch]$IncludeDisabled)
    $result = Invoke-IntegrationCli -Tool $Tool -Arguments @((Get-IntegrationToolInfo $Tool).plugin.list) -Folder $Folder
    if ($result.ExitCode -ne 0) { throw "$Tool plugin list exited $($result.ExitCode)" }
    return [bool](Test-IntegrationListing -Tool $Tool -Lines $result.Lines -IncludeDisabled:$IncludeDisabled)
}

# A folder nobody installed into must list nothing; this proves the listing follows the folder it is given.
function Assert-IntegrationControlFolder {
    param([string]$Tool)
    $control = Join-Path $script:Ctx.Work "control-$Tool"
    New-Item -ItemType Directory -Path $control -Force | Out-Null
    Assert-IntegrationTrue (-not (Test-IntegrationPluginListed $Tool $control -IncludeDisabled)) "$Tool lists ps-ai in an empty control folder"
}

function Get-IntegrationSettings {
    $path = Join-Path $script:Ctx.HomeRoot '.legion/configuration/ps-ai-personalisation.json'
    return @{ Path = $path; Data = (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json) }
}

# Step 1
function Invoke-CliInstallScript {
    param([string]$Tool)
    $arguments = @('-Tool', $Tool, '-Yes')
    # Without a working winget the installer only asks for a method; zip needs no admin rights.
    if ((Get-IntegrationOs) -eq 'windows' -and -not (Test-IntegrationWingetWorks)) { $arguments += @('-Method', 'zip') }
    return Invoke-IntegrationScript (Join-Path (Get-IntegrationBin) 'ps-ai-install-tool.ps1') $arguments
}

function Get-IntegrationToolVersion {
    param([string]$Tool)
    # Load the standalone installer's parser in this scope, without running the installer.
    . (Join-Path $PSScriptRoot '../../plugins/ps-ai/install.ps1') -NoRun
    $command = Resolve-IntegrationCommand (Get-IntegrationToolInfo $Tool).command
    $output = @(& $command --version 2>&1 | ForEach-Object { "$_" }) -join "`n"
    Assert-IntegrationTrue ($LASTEXITCODE -eq 0) "$Tool --version exited $LASTEXITCODE"
    $version = Get-InstallVersion $output
    Assert-IntegrationTrue ([bool]$version) "$Tool --version has no version token:`n$output"
    return @{ Version = $version; Command = $command }
}

function Invoke-CliInstallFirst {
    param([string]$Tool)
    $lines = Invoke-CliInstallScript $Tool
    $installed = Get-IntegrationToolVersion $Tool
    $script:Ctx.Versions[$Tool] = $installed.Version
    $script:Ctx.Commands[$Tool] = $installed.Command
    return $lines
}

function Invoke-CliInstallRepeat {
    param([string]$Tool)
    $lines = Invoke-CliInstallScript $Tool
    Assert-IntegrationText $lines 'skip:'
    $installed = Get-IntegrationToolVersion $Tool
    Assert-IntegrationTrue ($installed.Version -ceq $script:Ctx.Versions[$Tool]) "$Tool version changed on the repeat run`nfirst version:`n$($script:Ctx.Versions[$Tool])`nrepeat version:`n$($installed.Version)"
    Assert-IntegrationTrue ($installed.Command -ceq $script:Ctx.Commands[$Tool]) "$Tool executable changed on the repeat run`nfirst executable:`n$($script:Ctx.Commands[$Tool])`nrepeat executable:`n$($installed.Command)"
    return $lines
}

# Step 2: one install.ps1 run per tool, so one tool's refusal never hides the others.
function Invoke-PsAiInstall {
    param([string]$Tool, $Target)
    $arguments = @('-Source', $Target.Source, '-Tools', $Tool, '-Yes', '-HomeRoot', $script:Ctx.HomeRoot)
    if ($Target.Ref) { $arguments += @('-Ref', $Target.Ref) }
    return Invoke-IntegrationScript (Join-Path $script:Ctx.Checkout 'plugins/ps-ai/install.ps1') $arguments
}

# Only the affected CLI's own refusal of a local folder counts; any other message is a real failure.
function Test-IntegrationLocalRefusal {
    param([string]$Tool, [string]$Message)
    $command = [regex]::Escape((Get-IntegrationToolInfo $Tool).command)
    if ($Message -notmatch "(?m)\b$command exited \d+") { return $false }
    return $Message -match '(?i)(local (path|folder|directory|source|marketplace)|filesystem|directory source)[^\r\n]{0,80}(not supported|unsupported|not allowed|not permitted|cannot|refus|rejected)'
}

function Get-IntegrationRevision { return (git -C $script:Ctx.Checkout rev-parse HEAD) }

function Get-IntegrationRemoteMain {
    return ((git -C $script:Ctx.Checkout ls-remote origin refs/heads/main) -split '\s+')[0]
}

function Install-IntegrationTool {
    param([string]$Tool)
    $checkout = @{ Source = $script:Ctx.Checkout; Ref = '' }
    try {
        $lines = Invoke-PsAiInstall $Tool $checkout
        $script:Ctx.Targets[$Tool] = $checkout
        return $lines
    } catch {
        if (-not (Test-IntegrationLocalRefusal $Tool $_.Exception.Message)) { throw }
        $reason = ($_.Exception.Message -split "`n")[0]
    }
    if (-not $script:Ctx.AllowFallback) {
        $script:Ctx.NotTested[$Tool] = "$Tool refuses a local folder and was not tested from the checkout: $reason"
        return @("skip: $($script:Ctx.NotTested[$Tool])")
    }
    # The published source must be exactly the tested revision.
    $revision = Get-IntegrationRevision
    $remote = Get-IntegrationRemoteMain
    if ($remote -ne $revision) { throw "$Tool needs the published source, but main is $remote and the tested revision is $revision" }
    $fallback = @{ Source = $script:MarketplaceRepo; Ref = 'main' }
    $lines = Invoke-PsAiInstall $Tool $fallback
    $remote = Get-IntegrationRemoteMain
    if ($remote -ne $revision) { throw "$Tool installed the published source, but main moved to $remote and the tested revision is $revision" }
    $script:Ctx.Targets[$Tool] = $fallback
    return $lines
}

function Invoke-PsAiInstallFirst {
    $lines = @()
    $errors = @()
    foreach ($tool in $script:IntegrationTools) {
        try { $lines += Install-IntegrationTool $tool }
        catch { $errors += "${tool}: $($_.Exception.Message)" }
    }
    if ($errors.Count) { throw ($errors -join "`n") }
    $active = Get-IntegrationActiveTools
    if (-not $active.Count) { return @{ Skipped = (@($script:Ctx.NotTested.Values) -join '; ') } }
    $expected = Get-CheckoutVersion
    foreach ($tool in $active) {
        $folder = Get-IntegrationToolFolder $tool
        Assert-IntegrationTrue (Test-IntegrationPluginListed $tool $folder) "$tool does not list an enabled ps-ai"
        Assert-IntegrationControlFolder $tool
        $found = Get-IntegrationPluginVersion $tool $folder
        Assert-IntegrationTrue ($found -eq $expected) "$tool has ps-ai $found, expected $expected"
    }
    $script:Ctx.HomeSnapshot = Get-IntegrationHomeSnapshot
    return $lines
}

function Invoke-PsAiInstallRepeat {
    $lines = @()
    foreach ($tool in (Get-IntegrationActiveTools)) { $lines += Invoke-PsAiInstall $tool $script:Ctx.Targets[$tool] }
    Assert-IntegrationText $lines 'skip:'
    Assert-TreeUnchanged $script:Ctx.HomeSnapshot (Get-IntegrationHomeSnapshot)
    return $lines
}

# Steps 3 and 4: setup with each tool's tested source. Explicit ids keep a repeat from asking for more accounts.
function Invoke-Setup {
    param([string]$Tool, [string]$Id)
    $arguments = @('-Add', @($Tool), '-Id', $Id, '-Yes', '-HomeRoot', $script:Ctx.HomeRoot, '-Source', $script:Ctx.Targets[$Tool].Source)
    return Invoke-IntegrationScript (Join-Path (Get-IntegrationBin) 'ps-ai-setup.ps1') $arguments
}

function Invoke-SetupAccounts {
    $lines = @()
    foreach ($tool in (Get-IntegrationActiveTools)) { $lines += Invoke-Setup -Tool $tool -Id "${tool}1" }
    return $lines
}

function Invoke-SetupFirst {
    $lines = Invoke-SetupAccounts
    $settings = Get-IntegrationSettings
    Invoke-IntegrationScript (Join-Path (Get-IntegrationBin) 'ps-ai-validate.ps1') @('-Kind', 'personalisation', '-Path', $settings.Path) | Out-Null
    Assert-IntegrationTrue (Test-Path -LiteralPath (Join-Path (Split-Path $settings.Path) 'ps-ai-notes.md')) 'ps-ai-notes.md is missing'
    $ids = @($settings.Data.agents | ForEach-Object id)
    foreach ($tool in (Get-IntegrationActiveTools)) {
        Assert-IntegrationTrue ($ids -contains "${tool}1") "account ${tool}1 is missing"
        Assert-IntegrationText $lines "log in: run ${tool}1"
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
    $script:Ctx.HomeSnapshot = Get-IntegrationHomeSnapshot
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
    $lines = Invoke-SetupAccounts
    Assert-IntegrationText $lines 'skip:'
    Assert-TreeUnchanged $script:Ctx.HomeSnapshot (Get-IntegrationHomeSnapshot)
    return $lines
}

function Get-AddTool { return (Get-IntegrationActiveTools)[0] }

function Invoke-AddFirst {
    $lines = Invoke-Setup -Tool (Get-AddTool) -Id 'ci-extra'
    $settings = Get-IntegrationSettings
    $agent = @($settings.Data.agents | Where-Object id -eq 'ci-extra')
    Assert-IntegrationTrue ($agent.Count -eq 1) 'account ci-extra was not recorded'
    Assert-IntegrationTrue (Test-Path -LiteralPath (Resolve-IntegrationFolder $agent[0].configDir) -PathType Container) 'ci-extra folder was not created'
    Assert-AccountsHavePsAi $agent
    $script:Ctx.AgentCount = @($settings.Data.agents).Count
    return $lines
}

function Invoke-AddRepeat {
    $lines = Invoke-Setup -Tool (Get-AddTool) -Id 'ci-extra'
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

# Steps 6 and 7: throwaway Git repositories. Shared needs a tracked rules file.
function New-IntegrationRepo {
    param([string]$Name, [switch]$WithRules)
    $repo = Join-Path $script:Ctx.Work $Name
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    git -C $repo init --quiet
    git -C $repo config user.name 'integration'
    git -C $repo config user.email 'integration@example.com'
    git -C $repo config commit.gpgsign false
    Set-Content -LiteralPath (Join-Path $repo 'README.md') -Value $Name
    git -C $repo add README.md
    if ($WithRules) {
        Set-Content -LiteralPath (Join-Path $repo 'AGENTS.md') -Value "# $Name rules"
        git -C $repo add AGENTS.md
    }
    git -C $repo commit --quiet -m 'initial'
    return $repo
}

function Invoke-RepositoryScript {
    param([string]$Repo, [string]$Mode)
    $arguments = @('-Repo', $Repo, '-Mode', $Mode, '-Gate', 'pwsh -NoProfile -Command exit 0')
    if ($Mode -eq 'Shared') { $arguments += @('-RulesFile', 'AGENTS.md') }
    return Invoke-IntegrationScript (Join-Path (Get-IntegrationBin) 'ps-ai-repository.ps1') $arguments
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
    $repo = New-IntegrationRepo 'repo-b' -WithRules
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

# Step 8: the default folders and the registered account folders, captured before the uninstall removes anything.
function Get-IntegrationUninstallTargets {
    param([switch]$AllTools)
    $active = if ($AllTools) { $script:IntegrationTools } else { Get-IntegrationActiveTools }
    $targets = @()
    foreach ($tool in $active) { $targets += @{ Tool = $tool; Folder = Get-IntegrationToolFolder $tool } }
    foreach ($agent in @((Get-IntegrationSettings).Data.agents)) {
        if ($agent.tool -notin $active -or -not $agent.configDir) { continue }
        $folder = Resolve-IntegrationFolder $agent.configDir
        if (-not @($targets | Where-Object { $_.Tool -eq $agent.tool -and $_.Folder -eq $folder }).Count) { $targets += @{ Tool = $agent.tool; Folder = $folder } }
    }
    return $targets
}

function Assert-IntegrationUninstalled {
    param($Target)
    $tool = $Target.Tool
    $info = Get-IntegrationToolInfo $tool
    Assert-IntegrationTrue ($null -eq (Get-IntegrationPluginVersion $tool $Target.Folder)) "ps-ai is still in $($Target.Folder)"
    Assert-IntegrationTrue (-not (Test-IntegrationPluginListed $tool $Target.Folder -IncludeDisabled)) "$tool still lists ps-ai in $($Target.Folder)"
    if ($info.plugin.cacheDir) {
        Assert-IntegrationTrue (-not (Test-Path -LiteralPath (Join-Path $Target.Folder $info.plugin.cacheDir))) "the $tool cache is still in $($Target.Folder)"
    }
}

function Invoke-UninstallScript {
    return Invoke-IntegrationScript (Join-Path $script:Ctx.Checkout 'plugins/ps-ai/install.ps1') @('-Uninstall', '-Yes', '-HomeRoot', $script:Ctx.HomeRoot)
}

function Invoke-UninstallFirst {
    $targets = @(Get-IntegrationUninstallTargets)
    $lines = Invoke-UninstallScript
    foreach ($target in $targets) { Assert-IntegrationUninstalled $target }
    foreach ($tool in (Get-IntegrationActiveTools)) {
        $command = Resolve-IntegrationCommand (Get-IntegrationToolInfo $tool).command
        & $command --version | Out-Null
        Assert-IntegrationTrue ($LASTEXITCODE -eq 0) "$tool is no longer installed"
    }
    # The owner commands go; every account launcher stays, so a later install is an upgrade.
    foreach ($name in Get-IntegrationOwnerCommandNames) {
        foreach ($path in Get-IntegrationLauncherPaths $name) {
            Assert-IntegrationTrue (-not (Test-Path -LiteralPath $path)) "owner command $name is still in .legion/bin"
        }
    }
    Assert-IntegrationLaunchersExist
    foreach ($kept in 'configuration', 'agents') {
        Assert-IntegrationTrue (Test-Path -LiteralPath (Join-Path $script:Ctx.HomeRoot ".legion/$kept") -PathType Container) ".legion/$kept was removed"
    }
    return $lines
}

# The installer's own list of owner commands, loaded in a child scope so its helpers stay out of this script.
function Get-IntegrationOwnerCommandNames {
    return @(& {
        . (Join-Path $script:Ctx.Checkout 'plugins/ps-ai/install.ps1') -NoRun
        (Get-InstallOwnerCommands).Keys
    })
}

# A launcher is one file on macOS and Linux, and a file plus a .cmd file on Windows.
function Get-IntegrationLauncherPaths {
    param([string]$Name)
    $path = Join-Path $script:Ctx.HomeRoot ".legion/bin/$Name"
    if ($IsWindows) { return @($path, "$path.cmd") }
    return @($path)
}

function Get-IntegrationAccountIds {
    $active = Get-IntegrationActiveTools
    return @((Get-IntegrationSettings).Data.agents | Where-Object { $_.tool -in $active } | ForEach-Object id)
}

function Assert-IntegrationLaunchersExist {
    foreach ($id in Get-IntegrationAccountIds) {
        foreach ($path in Get-IntegrationLauncherPaths $id) {
            Assert-IntegrationTrue (Test-Path -LiteralPath $path -PathType Leaf) "launcher $id is missing: $path"
        }
    }
}

# The launcher starts the account's own CLI; --version proves it without a login.
function Assert-IntegrationLaunchersRun {
    foreach ($id in Get-IntegrationAccountIds) {
        $launcher = @(Get-IntegrationLauncherPaths $id)[-1]
        & $launcher --version 2>&1 | Out-Null
        Assert-IntegrationTrue ($LASTEXITCODE -eq 0) "launcher $id --version exited $LASTEXITCODE"
    }
}

# Steps 9 and 10: the owner's scenario, uninstall then install again.
function Invoke-PsAiInstallAgain {
    $lines = @()
    foreach ($tool in (Get-IntegrationActiveTools)) { $lines += Invoke-PsAiInstall $tool $script:Ctx.Targets[$tool] }
    return $lines
}

function Invoke-ReinstallFirst {
    $lines = Invoke-PsAiInstallAgain
    $expected = Get-CheckoutVersion
    foreach ($target in (Get-IntegrationUninstallTargets)) {
        $found = Get-IntegrationPluginVersion $target.Tool $target.Folder
        Assert-IntegrationTrue ($found -eq $expected) "$($target.Tool) has ps-ai $found in $($target.Folder), expected $expected"
    }
    Assert-IntegrationLaunchersExist
    Assert-IntegrationLaunchersRun
    $script:Ctx.HomeSnapshot = Get-IntegrationHomeSnapshot
    return $lines
}

function Invoke-ReinstallRepeat {
    $lines = Invoke-PsAiInstallAgain
    Assert-IntegrationText $lines 'skip:'
    Assert-TreeUnchanged $script:Ctx.HomeSnapshot (Get-IntegrationHomeSnapshot)
    return $lines
}

function Invoke-RestoreLaunchersFirst {
    foreach ($id in Get-IntegrationAccountIds) {
        foreach ($path in Get-IntegrationLauncherPaths $id) { Remove-Item -LiteralPath $path -Force }
    }
    $lines = Invoke-PsAiInstallAgain
    Assert-IntegrationLaunchersExist
    Assert-IntegrationLaunchersRun
    $script:Ctx.HomeSnapshot = Get-IntegrationHomeSnapshot
    return $lines
}

function Invoke-RestoreLaunchersRepeat {
    $lines = Invoke-PsAiInstallAgain
    Assert-IntegrationText $lines 'skip:'
    Assert-TreeUnchanged $script:Ctx.HomeSnapshot (Get-IntegrationHomeSnapshot)
    return $lines
}

function Invoke-UninstallRepeat {
    $lines = Invoke-UninstallScript
    Assert-IntegrationText $lines 'Nothing to uninstall.'
    return $lines
}

# Step 11: purge also covers CLIs whose marketplace install was skipped.
function Invoke-PurgeScript {
    return Invoke-IntegrationScript (Join-Path $script:Ctx.Checkout 'plugins/ps-ai/install.ps1') @('-Uninstall', '-Purge', '-Yes', '-HomeRoot', $script:Ctx.HomeRoot)
}

function Assert-IntegrationPurged {
    param($Target)
    if (-not (Test-Path -LiteralPath $Target.Folder -PathType Container)) { return }
    Assert-IntegrationUninstalled $Target
    $info = Get-IntegrationToolInfo $Target.Tool
    $listing = Invoke-IntegrationCli -Tool $Target.Tool -Arguments $info.plugin.marketplaceList -Folder $Target.Folder
    Assert-IntegrationTrue ($listing.ExitCode -eq 0) "$($Target.Tool) marketplace listing failed after purge"
    Assert-IntegrationTrue (-not (Test-IntegrationListing -Kind marketplace -Tool $Target.Tool -Lines $listing.Lines)) "ps-ai marketplace is still registered in $($Target.Folder)"
    $paths = @($info.plugin.cacheDir) + @($info.plugin.purge.paths) + @($info.plugin.purge.emptyDirs)
    if ($info.plugin.purge.legacyHookTrust) {
        $paths += & {
            . (Join-Path $script:Ctx.Checkout 'plugins/ps-ai/install.ps1') -NoRun
            Get-InstallPurgeTrustPath -ConfigDir $Target.Folder
        }
    }
    foreach ($relative in $paths) {
        if (-not $relative) { continue }
        $path = Join-Path $Target.Folder $relative
        Assert-IntegrationTrue (-not (Test-Path -LiteralPath $path)) "ps-ai path remains after purge: $path"
    }
    foreach ($setting in $info.plugin.purge.settings) {
        $path = Join-Path $Target.Folder $setting.path
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        Assert-IntegrationTrue ([IO.File]::ReadAllText($path) -notmatch 'ps-ai') "ps-ai text remains after purge in $path"
    }
}

function Assert-IntegrationPurgeComplete {
    Assert-IntegrationTrue (-not (Test-Path -LiteralPath (Join-Path $script:Ctx.HomeRoot '.legion'))) 'legion home remains after purge'
    foreach ($target in $script:Ctx.PurgeTargets) { Assert-IntegrationPurged $target }
    foreach ($tool in $script:IntegrationTools) {
        $result = Invoke-IntegrationCli -Tool $tool -Arguments @('--version') -Folder (Get-IntegrationToolFolder $tool)
        Assert-IntegrationTrue ($result.ExitCode -eq 0) "$tool --version failed after purge"
    }
}

function Invoke-PurgeFirst {
    # Save account folders before purge removes the settings that name them.
    $script:Ctx.PurgeTargets = @(Get-IntegrationUninstallTargets -AllTools)
    $lines = Invoke-PurgeScript
    Assert-IntegrationPurgeComplete
    $script:Ctx.PurgeSnapshot = Get-IntegrationHomeSnapshot
    return $lines
}

function Invoke-PurgeRepeat {
    $lines = Invoke-PurgeScript
    Assert-IntegrationText $lines 'skip: purge (already done)'
    Assert-IntegrationPurgeComplete
    Assert-TreeUnchanged $script:Ctx.PurgeSnapshot (Get-IntegrationHomeSnapshot)
    return $lines
}

# Building the ordered steps touches nothing; only running a block does.
function Get-IntegrationSteps {
    param([string]$HomeRoot, [string]$Checkout, [string]$Work, [string]$Os, [switch]$AllowFallback)
    $script:Ctx = @{
        HomeRoot = $HomeRoot; Checkout = $Checkout; Work = $Work; Os = $Os; AllowFallback = [bool]$AllowFallback
        Versions = [ordered]@{}; Commands = @{}; Targets = @{}; NotTested = [ordered]@{}
    }
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
    $steps += @{ Name = 'reinstall'; DependsOn = @('uninstall'); First = { Invoke-ReinstallFirst }; Repeat = { Invoke-ReinstallRepeat } }
    $steps += @{ Name = 'restore-launchers'; DependsOn = @('reinstall'); First = { Invoke-RestoreLaunchersFirst }; Repeat = { Invoke-RestoreLaunchersRepeat } }
    $steps += @{ Name = 'purge'; DependsOn = @('restore-launchers'); First = { Invoke-PurgeFirst }; Repeat = { Invoke-PurgeRepeat } }
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
$steps = Get-IntegrationSteps -HomeRoot $HomeRoot -Checkout $Checkout -Work $work -Os $os -AllowFallback:$AllowSourceFallback
Set-IntegrationConfigEnvironment
$cases = @(Invoke-IntegrationSteps -Steps $steps -LogFolder (Join-Path $Out 'logs'))
$extra = ($script:Ctx.Versions.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)" }) -join ', '
if ($script:Ctx.NotTested.Count) { $extra += "; not tested from the checkout: $(@($script:Ctx.NotTested.Keys) -join ', ')" }
Write-IntegrationReport -Out $Out -Os $os -Cases $cases -Probe $probe -Extra $extra
if (@($cases | Where-Object Result -eq 'failed').Count) { exit 1 }
exit 0
