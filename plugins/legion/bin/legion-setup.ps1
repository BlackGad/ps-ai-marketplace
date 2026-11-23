param(
    [string[]]$Add,
    [string]$Id,
    [switch]$Yes,
    [string]$HomeRoot = $HOME,
    [string]$Source,
    [switch]$NoRun
)

$ErrorActionPreference = 'Stop'
$script:SetupBin = $PSScriptRoot
$script:SetupPluginRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/accounts.ps1')
. (Join-Path $PSScriptRoot 'lib/installed.ps1')
. (Join-Path $PSScriptRoot 'lib/commands.ps1')
. (Join-Path $PSScriptRoot 'install-tool/recipe.ps1')
. (Join-Path $PSScriptRoot 'lib/process.ps1')

function Find-SetupCommand {
    param([string]$Name)
    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    # Probes newly installed commands without changing the calling process's PATH.
    return Find-LegionPersistentCommand -Name $Name
}

function Test-SetupCommand {
    param([string]$Name)
    return [bool](Find-SetupCommand -Name $Name)
}

function Invoke-SetupProcess {
    param([string[]]$Arguments)
    $environment = @{}
    if ($IsWindows) {
        $path = $env:PATH
        foreach ($folder in (Get-LegionPersistentFolders)) {
            if (-not (Test-LegionPathEntry -Path $path -Folder $folder)) { $path += ";$folder" }
        }
        $environment.PATH = $path
    }
    $result = Invoke-LegionProcess -Command pwsh -Arguments $Arguments -Environment $environment
    return @{ Code = $result.ExitCode; Output = $result.Output + $result.Error }
}

function ConvertTo-SetupOneLine {
    param([string]$Text)
    return $Text.Replace("`r", ' ').Replace("`n", ' ').Trim()
}

function Invoke-SetupToolInstall {
    param([string]$Tool)
    try {
        $result = Invoke-SetupProcess -Arguments @('-NoProfile', '-File', (Join-Path $script:SetupBin 'legion-install-tool.ps1'), '-Tool', $Tool, '-Yes')
        $message = ConvertTo-SetupOneLine $result.Output
        if (-not $message) { $message = "installer exit $($result.Code)" }
        return @{ Ok = ($result.Code -eq 0); Message = $message }
    } catch { return @{ Ok = $false; Message = (ConvertTo-SetupOneLine $_.Exception.Message) } }
}

function Invoke-SetupInstaller {
    param([string]$Installer, [string]$Tool, [string]$ConfigDir)
    $arguments = @('-NoProfile', '-File', $Installer, '-Tools', $Tool, '-ConfigDir', $ConfigDir, '-HomeRoot', $script:SetupHomeRoot, '-Update', '-Yes')
    if ($script:SetupSource) { $arguments += @('-Source', $script:SetupSource) }
    $result = Invoke-SetupProcess -Arguments $arguments
    $log = Get-LegionHomePath -HomeRoot $script:SetupHomeRoot -Path "temp/setup-install-$Tool.log"
    New-Item -ItemType Directory -Path (Split-Path $log) -Force | Out-Null
    [IO.File]::WriteAllText($log, $result.Output)
    return [int]$result.Code
}

function Resolve-SetupFolder {
    param([string]$Folder, [string]$HomeRoot)
    $Folder = Resolve-LegionHomePath -Path $Folder -HomeRoot $HomeRoot
    $fullPath = [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Folder))
    return [IO.Path]::TrimEndingDirectorySeparator($fullPath)
}

function Get-SetupNextId {
    param([string]$Tool, $Data)
    $number = 1
    while ($true) {
        $candidate = "$Tool$number"
        if ($candidate -cnotin @($Data.agents.id) -and -not (Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue)) { return $candidate }
        $number++
    }
}

function Get-SetupMissingAllowRules {
    param($Tool, [string]$Folder)
    $rules = @($Tool.allowRules | Where-Object { $_ })
    $file = Join-Path $Folder 'settings.json'
    if (-not $rules.Count -or -not (Test-Path -LiteralPath $file)) { return $rules }
    try { $current = @((Read-LegionJson $file).permissions.allow) }
    catch { throw "cannot read $file`: $(ConvertTo-SetupOneLine $_.Exception.Message)" }
    return @($rules | Where-Object { $_ -cnotin $current })
}

function New-SetupAccountRow {
    param($Agent, $Tool, [string]$HomeRoot, [switch]$Requested, [switch]$New, [switch]$Adopted)
    $folder = Resolve-SetupFolder $Agent.configDir $HomeRoot
    # Login is owner-only; infer the guidance from our managed folder without reading credentials.
    $managed = Get-LegionNewAccountDir -Id $Agent.id -HomeRoot $HomeRoot
    $nextStep = if (-not $Adopted -and -not $Agent.provider -and $folder -ceq $managed) { "log in: run $($Agent.id)" } else { 'ready' }
    $missingWrappers = Test-LegionLauncherMissing -Id $Agent.id -HomeRoot $HomeRoot
    $target = $null
    if ($missingWrappers -and -not $New -and -not $Agent.provider) { $target = Get-LegionWrapperTarget -Id $Agent.id -Tool $Tool.id -HomeRoot $HomeRoot -ConfigDir $folder }
    if ($missingWrappers -and -not $New -and -not $Agent.provider -and -not $target) { $nextStep = "target needed: $($Agent.id); ask the owner for the registered executable" }
    return [pscustomobject]@{
        Id = $Agent.id; Tool = $Tool; Folder = $folder
        Requested = [bool]$Requested; New = [bool]$New; Adopted = [bool]$Adopted
        Version = (Get-LegionInstalledVersion -ConfigDir $folder -Tool $Tool)
        NextStep = $nextStep; Usable = (-not $nextStep.StartsWith('target needed:'))
        MissingWrappers = $missingWrappers; WrapperTarget = $target; Provider = $Agent.provider
        MissingAllowRules = @(Get-SetupMissingAllowRules -Tool $Tool -Folder $folder)
    }
}

function Get-SetupAddedAccount {
    param([string]$Item, [string]$Id, $Data, $Tools, [string]$HomeRoot)
    $colon = $Item.IndexOf(':')
    $toolId = if ($colon -lt 0) { $Item } else { $Item.Substring(0, $colon) }
    if (-not $Tools.Contains($toolId)) { throw "unknown tool '$toolId'" }
    $folder = $null
    if ($colon -ge 0) {
        $folder = $Item.Substring($colon + 1)
        if (-not $folder) { throw 'Existing account config folder does not exist.' }
        $folder = Resolve-SetupFolder $folder $HomeRoot
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) { throw 'Existing account config folder does not exist.' }
        if (-not $Id) {
            $comparer = Get-LegionPathComparer
            $sameFolder = @($Data.agents | Where-Object {
                $_.tool -ceq $toolId -and -not $_.provider -and $comparer.Equals((Resolve-SetupFolder $_.configDir $HomeRoot), $folder)
            })[0]
            if ($sameFolder) { $Id = $sameFolder.id; $folder = Resolve-SetupFolder $sameFolder.configDir $HomeRoot }
        }
    }
    if (-not $Id) { $Id = Get-SetupNextId -Tool $toolId -Data $Data }
    if (-not $folder) { $folder = Get-LegionNewAccountDir -Id $Id -HomeRoot $HomeRoot }
    $existing = Get-LegionAgent -Data $Data -Id $Id
    if ($existing) {
        if ($existing.tool -cne $toolId -or $existing.provider -or -not (Get-LegionPathComparer).Equals((Resolve-SetupFolder $existing.configDir $HomeRoot), $folder)) { throw "account '$Id' already exists with other values" }
    } else { Assert-LegionNewId -Id $Id -Data $Data }
    $agent = [pscustomobject]@{ id = $Id; tool = $toolId; configDir = $folder }
    return New-SetupAccountRow -Agent $agent -Tool $Tools[$toolId] -HomeRoot $HomeRoot -Requested -New:(!$existing) -Adopted:($colon -ge 0)
}

function Get-SetupAccounts {
    param([string[]]$Add, [string]$Id, $Data, $Tools, [string]$HomeRoot)
    if ($Id -and $Add.Count -ne 1) { throw '-Id requires exactly one -Add' }
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($agent in $Data.agents) { $rows.Add((New-SetupAccountRow -Agent $agent -Tool $Tools[$agent.tool] -HomeRoot $HomeRoot)) }
    # Reserve planned ids in memory, so two adds for one tool get distinct ids without writing settings.
    $planned = [pscustomobject]@{ agents = @($Data.agents) }
    foreach ($item in $Add) {
        $row = Get-SetupAddedAccount -Item $item -Id $Id -Data $planned -Tools $Tools -HomeRoot $HomeRoot
        $previous = @($rows | Where-Object { $_.Id -ceq $row.Id })[0]
        if ($previous) {
            $row.New = $previous.New
            if ($row.New) { $row.Usable = $true; $row.NextStep = $previous.NextStep }
            [void]$rows.Remove($previous)
        }
        $rows.Add($row)
        if ($row.New -and -not $previous) { $planned.agents += [pscustomobject]@{ id = $row.Id; tool = $row.Tool.id; configDir = $row.Folder } }
    }
    return $rows.ToArray()
}

function Get-SetupPlan {
    param([string[]]$Add, [string]$Id, [string]$HomeRoot)
    $settings = Get-LegionOwnerPath -HomeRoot $HomeRoot -Name Settings
    $data = if (Test-Path -LiteralPath $settings) { Read-LegionJson $settings } else { [pscustomobject]@{ schemaVersion = 1; agents = @(); channels = @() } }
    $tools = [ordered]@{}
    foreach ($tool in Get-LegionTools) { $tools[$tool.id] = $tool }
    $accounts = @(Get-SetupAccounts -Add $Add -Id $Id -Data $data -Tools $tools -HomeRoot $HomeRoot)
    $usable = @($accounts | Where-Object Usable)
    $needsStockCommand = @($usable | Where-Object { -not $_.WrapperTarget })
    $missing = @()
    foreach ($tool in $tools.Values) {
        if ($tool.id -cin @($needsStockCommand.Tool.id) -and -not (Test-SetupCommand -Name $tool.command)) { $missing += $tool }
    }
    $bin = Get-LegionHomePath -HomeRoot $HomeRoot -Path 'bin'
    $path = if ($IsWindows) { Get-LegionUserPath } else { $env:PATH }
    $version = (Read-LegionJson (Join-Path $script:SetupPluginRoot 'plugin.json')).version
    return @{
        HomeRoot = $HomeRoot; Settings = $settings; Data = $data; Accounts = $accounts; MissingTools = $missing
        Notes = (Get-LegionOwnerPath -HomeRoot $HomeRoot -Name Notes); Bin = $bin
        Commands = @(Get-LegionCommandState -Bin $bin -HomeRoot $HomeRoot)
        NeedsPath = $(if ($IsWindows) { -not (Test-LegionPathEntry -Path $path -Folder $bin) } else { -not (Get-LegionShellProfile -HomeRoot $HomeRoot).HasPath })
        Version = $version
    }
}

function Test-SetupToolInstalled {
    param([string]$Tool)
    $previousExit = $global:LASTEXITCODE
    try { return (Test-ToolInstalled -Tool $Tool).Installed }
    finally { $global:LASTEXITCODE = $previousExit }
}

function Get-SetupToolInstallHint {
    param($Tool, [string]$Platform = $(if ($IsWindows) { 'windows' } elseif ($IsMacOS) { 'macos' } else { 'linux' }))
    return @(Get-ToolInstallHints -Tool $Tool.id -Platform $Platform -CommandAvailable { param($Name) Test-SetupCommand -Name $Name } -ToolInstalled { param($Name) Test-SetupToolInstalled -Tool $Name }) -join '; '
}

function Write-SetupPlan {
    param($Plan)
    $lines = [Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $Plan.Settings) -or -not (Test-Path -LiteralPath $Plan.Notes)) { $lines.Add("  create   settings and notes in $(Split-Path $Plan.Settings)") }
    foreach ($tool in $Plan.MissingTools) {
        $method = Get-SetupToolInstallHint -Tool $tool
        $lines.Add("  cli      install $($tool.id) ($method)")
    }
    foreach ($row in $Plan.Accounts) {
        if (-not $row.New) { continue }
        $kind = if ($row.Adopted) { 'existing' } else { 'new' }
        $lines.Add("  add      $($row.Id) ($($row.Tool.id)) $kind folder $($row.Folder)")
    }
    $repairs = @($Plan.Accounts | Where-Object { -not $_.New -and $_.MissingWrappers -and $_.Usable } | Select-Object -ExpandProperty Id)
    if ($repairs.Count) { $lines.Add("  wrappers repair $($repairs -join ', ')") }
    foreach ($row in $Plan.Accounts) { if ($row.NextStep.StartsWith('target needed:')) { $lines.Add("  wrappers $($row.NextStep)") } }
    $folders = @($Plan.Accounts | Where-Object { $_.Usable -and -not $_.Version } | Select-Object -ExpandProperty Folder -Unique)
    if ($folders.Count) { $lines.Add("  install  legion into $($folders -join ', ')") }
    foreach ($row in @($Plan.Accounts | Where-Object { $_.Usable -and $_.MissingAllowRules.Count } | Sort-Object Folder -Unique)) {
        $lines.Add("  permission allow $($row.MissingAllowRules -join ', ') in $($row.Folder)/settings.json")
    }
    $commands = @($Plan.Commands | Where-Object State -EQ missing | Select-Object -ExpandProperty Name -Unique)
    if ($commands.Count) { $lines.Add("  commands write $($commands -join ', ') in $($Plan.Bin)") }
    $permissions = @($Plan.Commands | Where-Object State -EQ permission | Select-Object -ExpandProperty Name -Unique)
    if ($permissions.Count) { $lines.Add("  commands restore execute permission for $($permissions -join ', ')") }
    if ($Plan.NeedsPath) {
        $hint = Add-LegionUserPath -Folder $Plan.Bin -HomeRoot $Plan.HomeRoot -DryRun
        $lines.Add("  path     $hint")
    }
    $blocked = @($Plan.Commands | Where-Object State -EQ blocked | Select-Object -ExpandProperty Name -Unique)
    foreach ($name in $blocked) { "blocked: command $name (another file is there)" }
    if (-not $lines.Count) { 'Nothing to do.'; return }
    'Plan (nothing changed yet):'
    $lines.ToArray()
    'Run again with -Yes to apply.'
}

function Initialize-SetupFiles {
    param($Plan)
    if (Test-Path -LiteralPath $Plan.Settings) { 'skip: settings (already done)' }
    else { Write-LegionPersonalisation -Data $Plan.Data -Path $Plan.Settings }
    if (Test-Path -LiteralPath $Plan.Notes) { 'skip: notes (already done)' }
    else {
        $template = Join-Path $script:SetupPluginRoot 'skills/legion-personalisation/references/notes-template.md'
        Write-LegionGeneratedFile -Path $Plan.Notes -Content ([IO.File]::ReadAllText($template))
    }
}

function Install-SetupTools {
    param($Plan)
    foreach ($tool in $Plan.MissingTools) {
        $result = Invoke-SetupToolInstall -Tool $tool.id
        $reason = if (-not $result.Ok) { "$($tool.id) install failed: $(ConvertTo-SetupOneLine $result.Message)" }
            elseif (-not (Test-SetupCommand -Name $tool.command)) { "$($tool.id) installed: open a new terminal, then repeat the add" }
            else { '' }
        if (-not $reason) { continue }
        foreach ($row in $Plan.Accounts) {
            if ($row.Tool.id -cne $tool.id -or $row.WrapperTarget) { continue }
            $row.Usable = $false
            $row.NextStep = $reason
        }
    }
}

function Add-SetupAccounts {
    param($Plan)
    $file = Get-LegionOwnerPath -HomeRoot $Plan.HomeRoot -Name Settings
    $data = Read-LegionJson -Path $file
    foreach ($row in $Plan.Accounts) {
        if (-not $row.Usable) { continue }
        if ($row.Provider -and $row.MissingWrappers) {
            New-FoundryWrappers -Id $row.Id -HomeRoot $Plan.HomeRoot -Tool $row.Tool.id
            "skip: account $($row.Id) (already done)"
            continue
        }
        if ($row.Requested -or $row.MissingWrappers) {
            $arguments = @{ Id = $row.Id; Tool = $row.Tool.id; HomeRoot = $Plan.HomeRoot; Data = $data; Path = $file }
            $managed = Get-LegionNewAccountDir -Id $row.Id -HomeRoot $Plan.HomeRoot
            if ($row.Adopted -or -not (Get-LegionPathComparer).Equals($row.Folder, $managed)) { $arguments.ConfigDir = $row.Folder }
            if ($row.New) { $arguments.Command = Find-SetupCommand -Name $row.Tool.command }
            elseif ($row.MissingWrappers) { $arguments.Command = $row.WrapperTarget }
            try { $result = @(Add-LegionSubscriptionAccount @arguments) }
            catch { throw (ConvertTo-SetupOneLine $_.Exception.Message) }
            if (-not $row.New) { $result }
        } else { "skip: account $($row.Id) (already done)" }
        if ($row.New -and -not $row.Adopted) { $row.NextStep = "log in: run $($row.Id)" }
    }
}

function Add-SetupAllowRules {
    param($Plan)
    foreach ($row in $Plan.Accounts) {
        if (-not $row.Usable) { continue }
        # Read again: an earlier account may share this folder, and the file may have changed since the plan.
        $missing = @(Get-SetupMissingAllowRules -Tool $row.Tool -Folder $row.Folder)
        if (-not $missing.Count) { "skip: permission rule in $($row.Folder) (already done)"; continue }
        $file = Join-Path $row.Folder 'settings.json'
        # Record only the rules setup adds; a rule the owner already had stays theirs.
        foreach ($rule in $missing) {
            Add-LegionFootprint -HomeRoot $Plan.HomeRoot -Kind edit -Path $file -Key permissions.allow -Value $rule -Owner (Get-LegionTargetOwner -Tool $row.Tool -Folder $row.Folder -HomeRoot $Plan.HomeRoot)
        }
        $data = if (Test-Path -LiteralPath $file) { Read-LegionJson $file } else { [pscustomobject]@{} }
        if (-not $data.PSObject.Properties['permissions']) { $data | Add-Member -NotePropertyName permissions -NotePropertyValue ([pscustomobject]@{}) }
        $allow = @($data.permissions.allow | Where-Object { $_ }) + $missing
        if ($data.permissions.PSObject.Properties['allow']) { $data.permissions.allow = $allow }
        else { $data.permissions | Add-Member -NotePropertyName allow -NotePropertyValue $allow }
        New-Item -ItemType Directory -Path $row.Folder -Force | Out-Null
        [IO.File]::WriteAllText($file, ($data | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))
    }
}

function Write-SetupCommands {
    param($Plan)
    foreach ($row in @($Plan.Accounts | Where-Object Version)) {
        $owner = Get-LegionTargetOwner -Tool $row.Tool -Folder $row.Folder -HomeRoot $Plan.HomeRoot
        foreach ($file in $Plan.Commands) {
            Add-LegionFootprint -HomeRoot $Plan.HomeRoot -Kind file -Path $file.Path -Owner $owner
        }
        Add-LegionFootprint -HomeRoot $Plan.HomeRoot -Kind app -Path (Get-LegionHomePath -Path 'app' -HomeRoot $Plan.HomeRoot) -Owner $owner
    }
    Sync-LegionApp -HomeRoot $Plan.HomeRoot
    Write-LegionOwnerCommands -HomeRoot $Plan.HomeRoot
    if (@($Plan.Commands | Where-Object State -EQ owned).Count) { 'skip: command legion (already done)' }
}

function Set-SetupPath {
    param($Plan)
    Add-LegionUserPath -Folder $Plan.Bin -HomeRoot $Plan.HomeRoot
    if (-not $IsWindows) { return }
    if (-not (Test-LegionPathEntry -Path $env:PATH -Folder $Plan.Bin)) { $env:PATH += ";$($Plan.Bin)" }
}

function Install-SetupPlugins {
    param($Plan)
    $installer = Join-Path $script:SetupPluginRoot 'install.ps1'
    $results = [Collections.Generic.Dictionary[string,int]]::new((Get-LegionPathComparer))
    foreach ($row in $Plan.Accounts) {
        if (-not $row.Usable) { continue }
        # Setup installs legion only where it is missing; moving versions is the update flow's job.
        if ($row.Version) { "skip: legion in $($row.Folder) (already done)"; continue }
        $key = "$($row.Tool.id):$($row.Folder)"
        if (-not $results.ContainsKey($key)) {
            try {
                $results[$key] = Invoke-SetupInstaller -Installer $installer -Tool $row.Tool.id -ConfigDir $row.Folder
            } catch { $results[$key] = 1 }
        }
        if ($results[$key] -ne 0) { $row.NextStep = "install failed: log in with $($row.Id), then finish setup" }
        $row.Version = Get-LegionInstalledVersion -ConfigDir $row.Folder -Tool $row.Tool
    }
}

function Write-SetupTable {
    param($Plan)
    if ($Plan.Accounts.Count) {
        'account  tool  folder  legion  next step'
        foreach ($row in $Plan.Accounts) {
            $version = if ($row.Version) { $row.Version } else { 'missing' }
            "$($row.Id)  $($row.Tool.id)  $($row.Folder)  $version  $($row.NextStep)"
        }
    }
    $blocked = @($Plan.Commands | Where-Object State -EQ blocked | Select-Object -ExpandProperty Name -Unique)
    if ($blocked.Count) { "Blocked commands: $($blocked -join ', ')" }
}

function Invoke-Setup {
    param([string[]]$Add, [string]$Id, [switch]$Yes, [string]$HomeRoot = $HOME, [string]$Source)
    $script:SetupHomeRoot = $HomeRoot
    $script:SetupSource = $Source
    $plan = Get-SetupPlan -Add $Add -Id $Id -HomeRoot $HomeRoot
    if (-not $Yes) { Write-SetupPlan -Plan $plan; return }
    Initialize-SetupFiles -Plan $plan
    Install-SetupTools -Plan $plan
    Add-SetupAccounts -Plan $plan
    Add-SetupAllowRules -Plan $plan
    Set-SetupPath -Plan $plan
    Install-SetupPlugins -Plan $plan
    Write-SetupCommands -Plan $plan
    Write-SetupTable -Plan $plan
    # Recoverable installer failures are next-step rows, not a failure of the whole setup run.
    $global:LASTEXITCODE = 0
}

# Main: parse adds and build the plan before any persistent change, then print it or apply and show the table.
if (-not $NoRun) { Invoke-Setup -Add $Add -Id $Id -Yes:$Yes -HomeRoot $HomeRoot -Source $Source }
