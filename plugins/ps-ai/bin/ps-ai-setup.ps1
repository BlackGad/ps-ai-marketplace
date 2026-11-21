param(
    [string[]]$Add,
    [string]$Id,
    [switch]$Yes,
    [string]$HomeRoot = $HOME,
    [string]$Source,
    [switch]$NoRun
)

$ErrorActionPreference = 'Stop'
# The account script has its own parameters; keep this script's arguments across dot-sourcing.
$setupArguments = @{ Add = $Add; Id = $Id; Yes = $Yes; HomeRoot = $HomeRoot; Source = $Source }
$setupNoRun = $NoRun
$script:SetupBin = $PSScriptRoot
$script:SetupPluginRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'ps-ai-account.ps1') -NoRun
. (Join-Path $PSScriptRoot 'lib/installed.ps1')
. (Join-Path $PSScriptRoot 'lib/commands.ps1')
. (Join-Path $PSScriptRoot 'install-tool/recipe.ps1')

function Get-SetupUserPath {
    # Preserve expandable entries such as %USERPROFILE% rather than writing their expanded values.
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
    if (-not $key) { return '' }
    try { return [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) }
    finally { $key.Dispose() }
}

function Set-SetupUserPath {
    param([string]$Value)
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
    try {
        $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
        if ($key.GetValueNames() -icontains 'Path') { $kind = $key.GetValueKind('Path') }
        $key.SetValue('Path', $Value, $kind)
    } finally { $key.Dispose() }
    # Notify other Windows applications without requiring a sign-out.
    if (-not ('LegionSetup.Environment' -as [type])) {
        Add-Type -Namespace LegionSetup -Name Environment -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern IntPtr SendMessageTimeout(IntPtr window, uint message, UIntPtr parameter, string value, uint flags, uint timeout, out UIntPtr result);
'@
    }
    $result = [UIntPtr]::Zero
    [void][LegionSetup.Environment]::SendMessageTimeout([IntPtr]0xffff, 0x1a, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
}

function Get-SetupMachinePath {
    return [Environment]::GetEnvironmentVariable('Path', 'Machine')
}

function Find-SetupCommand {
    param([string]$Name)
    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    if ($IsWindows) {
        # Probe newly installed commands without changing the calling process's PATH.
        foreach ($path in @((Get-SetupUserPath), (Get-SetupMachinePath))) {
            if (-not $path) { continue }
            foreach ($entry in $path.Split(';', [StringSplitOptions]::RemoveEmptyEntries)) {
                $expanded = [Environment]::ExpandEnvironmentVariables($entry)
                $command = Get-Command (Join-Path $expanded $Name) -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($command) { return $command.Source }
            }
        }
    }
    return $null
}

function Test-SetupCommand {
    param([string]$Name)
    return [bool](Find-SetupCommand -Name $Name)
}

function Invoke-SetupProcess {
    param([string[]]$Arguments)
    $start = [Diagnostics.ProcessStartInfo]::new('pwsh')
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    if ($IsWindows) {
        foreach ($path in @((Get-SetupUserPath), (Get-SetupMachinePath))) {
            if (-not $path) { continue }
            foreach ($entry in $path.Split(';', [StringSplitOptions]::RemoveEmptyEntries)) {
                $expanded = [Environment]::ExpandEnvironmentVariables($entry)
                if (-not (Test-LegionPathEntry -Path $start.Environment['PATH'] -Folder $expanded)) { $start.Environment['PATH'] += ";$expanded" }
            }
        }
    }
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        [void]$process.Start()
        $process.StandardInput.Close()
        # Drain both streams concurrently so verbose installers cannot fill either pipe and deadlock.
        $output = $process.StandardOutput.ReadToEndAsync()
        $errors = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        return @{ Code = $process.ExitCode; Output = $output.GetAwaiter().GetResult() + $errors.GetAwaiter().GetResult() }
    } finally { $process.Dispose() }
}

function ConvertTo-SetupOneLine {
    param([string]$Text)
    return $Text.Replace("`r", ' ').Replace("`n", ' ').Trim()
}

function Invoke-SetupToolInstall {
    param([string]$Tool)
    try {
        $result = Invoke-SetupProcess -Arguments @('-NoProfile', '-File', (Join-Path $script:SetupBin 'ps-ai-install-tool.ps1'), '-Tool', $Tool, '-Yes')
        $message = ConvertTo-SetupOneLine $result.Output
        if (-not $message) { $message = "installer exit $($result.Code)" }
        return @{ Ok = ($result.Code -eq 0); Message = $message }
    } catch { return @{ Ok = $false; Message = (ConvertTo-SetupOneLine $_.Exception.Message) } }
}

function Find-SetupInstaller {
    return Join-Path $script:SetupPluginRoot 'install.ps1'
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
    if ($Folder.StartsWith('~/') -or $Folder.StartsWith('~\')) { $Folder = Join-Path $HomeRoot $Folder.Substring(2) }
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

function New-SetupAccountRow {
    param($Agent, $Tool, [string]$HomeRoot, [switch]$Requested, [switch]$New, [switch]$Adopted)
    $folder = Resolve-SetupFolder $Agent.configDir $HomeRoot
    # Login is owner-only; infer the guidance from our managed folder without reading credentials.
    $managed = Get-LegionNewAccountDir -Id $Agent.id -HomeRoot $HomeRoot
    $nextStep = if (-not $Adopted -and -not $Agent.provider -and $folder -ceq $managed) { "log in: run $($Agent.id)" } else { 'ready' }
    $suffixes = if ($IsWindows) { @('', '.cmd') } else { @('') }
    $missingWrappers = @($suffixes | Where-Object {
        -not (Test-LegionLauncherExecutable -Path (Get-LegionHomePath -HomeRoot $HomeRoot -Path "bin/$($Agent.id)$_"))
    }).Count -gt 0
    $target = $null
    if ($missingWrappers -and -not $New -and -not $Agent.provider) { $target = Get-LegionWrapperTarget -Id $Agent.id -Tool $Tool.id -HomeRoot $HomeRoot -ConfigDir $folder }
    if ($missingWrappers -and -not $New -and -not $Agent.provider -and -not $target) { $nextStep = "target needed: $($Agent.id); ask the owner for the registered executable" }
    return [pscustomobject]@{
        Id = $Agent.id; Tool = $Tool; Folder = $folder
        Requested = [bool]$Requested; New = [bool]$New; Adopted = [bool]$Adopted
        Version = (Get-LegionInstalledVersion -ConfigDir $folder -Tool $Tool)
        NextStep = $nextStep; Usable = (-not $nextStep.StartsWith('target needed:'))
        MissingWrappers = $missingWrappers; WrapperTarget = $target; Provider = $Agent.provider
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
    $existing = @($Data.agents | Where-Object { $_.id -ceq $Id })[0]
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

function Get-SetupCommands {
    param([string]$HomeRoot)
    foreach ($entry in (Get-LegionOwnerCommands).GetEnumerator()) {
        $suffixes = if ($IsWindows) { @('', '.cmd') } else { @('') }
        foreach ($suffix in $suffixes) {
            $path = Get-LegionHomePath -HomeRoot $HomeRoot -Path "bin/$($entry.Key)$suffix"
            $state = Get-LegionOwnerCommandState -Path $path -Script $entry.Value
            if ($state -eq 'owned' -and (Get-LegionShimHomeArgument -HomeRoot $HomeRoot -Windows:($suffix -eq '.cmd'))) {
                $target = Read-LegionOwnerCommandTarget -Path $path -Script $entry.Value
                if ($target.Arguments -inotcontains '-HomeRoot') { $state = 'unbound' }
            }
            if ($state -eq 'owned' -and -not (Test-LegionLauncherExecutable -Path $path)) { $state = 'permission' }
            [pscustomobject]@{ Name = $entry.Key; Script = $entry.Value; Path = $path; Windows = ($suffix -eq '.cmd'); State = $state }
        }
    }
}

function Get-SetupPlan {
    param([string[]]$Add, [string]$Id, [string]$HomeRoot)
    $settings = Get-LegionHomePath -HomeRoot $HomeRoot -Path 'configuration/ps-ai-personalisation.json'
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
    $path = if ($IsWindows) { Get-SetupUserPath } else { $env:PATH }
    $version = (Read-LegionJson (Join-Path $script:SetupPluginRoot 'plugin.json')).version
    return @{
        HomeRoot = $HomeRoot; Settings = $settings; Data = $data; Accounts = $accounts; MissingTools = $missing
        Notes = (Join-Path (Split-Path $settings) 'ps-ai-notes.md'); Bin = $bin
        Commands = @(Get-SetupCommands -HomeRoot $HomeRoot); NeedsPath = (-not (Test-LegionPathEntry -Path $path -Folder $bin))
        Version = $version
    }
}

function Get-SetupPathHint {
    param($Plan)
    return 'add to your shell profile: export PATH=' + (ConvertTo-LegionShellLiteral $Plan.Bin) + ':"$PATH"'
}

function Test-SetupToolInstalled {
    param([string]$Tool)
    $previousExit = $global:LASTEXITCODE
    try {
        # Load the installer's probe in a child scope, keeping its parameters and helpers local.
        & {
            . (Join-Path $script:SetupBin 'ps-ai-install-tool.ps1') -NoRun -Tool $Tool
            return (Test-ToolInstalled -Tool $Tool).Installed
        }
    } finally { $global:LASTEXITCODE = $previousExit }
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
    if ($folders.Count) { $lines.Add("  install  ps-ai into $($folders -join ', ')") }
    $commands = @($Plan.Commands | Where-Object State -EQ missing | Select-Object -ExpandProperty Name -Unique)
    if ($commands.Count) { $lines.Add("  commands write $($commands -join ', ') in $($Plan.Bin)") }
    $stale = @($Plan.Commands | Where-Object State -EQ stale | Select-Object -ExpandProperty Name -Unique)
    if ($stale.Count) { $lines.Add("  commands rewrite $($stale -join ', ') (their script is gone)") }
    $unbound = @($Plan.Commands | Where-Object State -EQ unbound | Select-Object -ExpandProperty Name -Unique)
    if ($unbound.Count) { $lines.Add("  commands bind $($unbound -join ', ') to home $($Plan.HomeRoot)") }
    $permissions = @($Plan.Commands | Where-Object State -EQ permission | Select-Object -ExpandProperty Name -Unique)
    if ($permissions.Count) { $lines.Add("  commands restore execute permission for $($permissions -join ', ')") }
    if ($Plan.NeedsPath) {
        $hint = if ($IsWindows) { "add $($Plan.Bin) to your user PATH" } else { Get-SetupPathHint -Plan $Plan }
        $lines.Add("  path     $hint")
    }
    $retired = @(Get-LegionRetiredCommandFiles -HomeRoot $Plan.HomeRoot | Where-Object Generated)
    if ($retired.Count) { $lines.Add("  remove   old commands $($retired.Name -join ', ') (use legion instead)") }
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
        $template = Join-Path $script:SetupPluginRoot 'skills/ps-ai-personalisation/references/notes-template.md'
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
    $file = Get-LegionHomePath -HomeRoot $Plan.HomeRoot -Path 'configuration/ps-ai-personalisation.json'
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

function Write-SetupCommands {
    param($Plan)
    foreach ($name in (Get-LegionOwnerCommands).Keys) {
        $files = @($Plan.Commands | Where-Object Name -CEQ $name)
        foreach ($file in $files) {
            if ($file.State -eq 'permission') {
                Write-LegionGeneratedFile -Path $file.Path -Content ([IO.File]::ReadAllText($file.Path)) -Executable
                continue
            }
            if ($file.State -notin @('missing', 'stale', 'unbound')) { continue }
            $runner = Join-Path $script:SetupBin $file.Script
            if ($file.State -eq 'unbound') { $runner = (Read-LegionOwnerCommandTarget -Path $file.Path -Script $file.Script).Path }
            # Existing commands keep owner flags, and live commands keep their target.
            $text = if ($file.State -in @('stale', 'unbound')) { Update-LegionOwnerCommandText -Text ([IO.File]::ReadAllText($file.Path)) -Script $file.Script -Runner $runner -Windows:$file.Windows -HomeRoot $Plan.HomeRoot }
                else { Get-LegionShimText -Script $runner -Windows:$file.Windows -HomeRoot $Plan.HomeRoot }
            Write-LegionGeneratedFile -Path $file.Path -Content $text -Executable
        }
        # Blocked commands are reported once, in the final table.
        if (@($files | Where-Object State -EQ owned).Count) { "skip: command $name (already done)" }
    }
}

function Set-SetupPath {
    param($Plan)
    if (-not $IsWindows) {
        if (-not $Plan.NeedsPath) { 'skip: path (already done)' }
        return
    }
    if ($Plan.NeedsPath) {
        $current = Get-SetupUserPath
        $updated = if ($current) { $current.TrimEnd(';') + ';' + $Plan.Bin } else { $Plan.Bin }
        Set-SetupUserPath -Value $updated
    } else { 'skip: path (already done)' }
    if (-not (Test-LegionPathEntry -Path $env:PATH -Folder $Plan.Bin)) { $env:PATH += ";$($Plan.Bin)" }
}

function Install-SetupPlugins {
    param($Plan)
    $installer = $null
    $installerChecked = $false
    $results = [Collections.Generic.Dictionary[string,int]]::new((Get-LegionPathComparer))
    foreach ($row in $Plan.Accounts) {
        if (-not $row.Usable) { continue }
        # Setup installs ps-ai only where it is missing; moving versions is the update flow's job.
        if ($row.Version) { "skip: ps-ai in $($row.Folder) (already done)"; continue }
        $key = "$($row.Tool.id):$($row.Folder)"
        if (-not $results.ContainsKey($key)) {
            try {
                if (-not $installerChecked) { $installerChecked = $true; $installer = Find-SetupInstaller }
                $results[$key] = if ($installer) { Invoke-SetupInstaller -Installer $installer -Tool $row.Tool.id -ConfigDir $row.Folder } else { 1 }
            } catch { $results[$key] = 1 }
        }
        if ($results[$key] -ne 0) { $row.NextStep = "install failed: log in with $($row.Id), then finish setup" }
        $row.Version = Get-LegionInstalledVersion -ConfigDir $row.Folder -Tool $row.Tool
    }
}

function Write-SetupTable {
    param($Plan)
    if ($Plan.Accounts.Count) {
        'account  tool  folder  ps-ai  next step'
        foreach ($row in $Plan.Accounts) {
            $version = if ($row.Version) { $row.Version } else { 'missing' }
            "$($row.Id)  $($row.Tool.id)  $($row.Folder)  $version  $($row.NextStep)"
        }
    }
    $blocked = @($Plan.Commands | Where-Object State -EQ blocked | Select-Object -ExpandProperty Name -Unique)
    if ($blocked.Count) { "Blocked commands: $($blocked -join ', ')" }
    if (-not $IsWindows -and $Plan.NeedsPath) { Get-SetupPathHint -Plan $Plan }
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
    Write-SetupCommands -Plan $plan
    Remove-LegionRetiredCommands -HomeRoot $HomeRoot
    Set-SetupPath -Plan $plan
    Install-SetupPlugins -Plan $plan
    Write-SetupTable -Plan $plan
    # Recoverable installer failures are next-step rows, not a failure of the whole setup run.
    $global:LASTEXITCODE = 0
}

# Main: parse adds and build the plan before any persistent change, then print it or apply and show the table.
if (-not $setupNoRun) { Invoke-Setup @setupArguments }
