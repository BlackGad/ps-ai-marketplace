param(
    [string[]]$Add,
    [string]$Id,
    [switch]$Yes,
    [string]$HomeRoot = $HOME,
    [switch]$NoRun
)

$ErrorActionPreference = 'Stop'
# The account script has its own parameters; keep this script's arguments across dot-sourcing.
$setupArguments = @{ Add = $Add; Id = $Id; Yes = $Yes; HomeRoot = $HomeRoot }
$setupNoRun = $NoRun
$script:SetupBin = $PSScriptRoot
$script:SetupPluginRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'ps-ai-account.ps1') -NoRun
. (Join-Path $PSScriptRoot 'lib/installed.ps1')
. (Join-Path $PSScriptRoot 'lib/commands.ps1')

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
    if (-not ('PsAiSetup.Environment' -as [type])) {
        Add-Type -Namespace PsAiSetup -Name Environment -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern IntPtr SendMessageTimeout(IntPtr window, uint message, UIntPtr parameter, string value, uint flags, uint timeout, out UIntPtr result);
'@
    }
    $result = [UIntPtr]::Zero
    [void][PsAiSetup.Environment]::SendMessageTimeout([IntPtr]0xffff, 0x1a, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
}

function Test-SetupPathEntry {
    param([string]$Path, [string]$Folder)
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    foreach ($entry in $Path.Split([IO.Path]::PathSeparator)) {
        $expanded = [Environment]::ExpandEnvironmentVariables($entry).TrimEnd('/', '\')
        if ([string]::Equals($expanded, $Folder.TrimEnd('/', '\'), $comparison)) { return $true }
    }
    return $false
}

function Test-SetupCommand {
    param([string]$Name)
    if ($IsWindows) {
        # An installer can add a new PATH entry after this process started; retain process-only entries too.
        foreach ($path in @((Get-SetupUserPath), [Environment]::GetEnvironmentVariable('Path', 'Machine'))) {
            if (-not $path) { continue }
            foreach ($entry in $path.Split(';', [StringSplitOptions]::RemoveEmptyEntries)) {
                $expanded = [Environment]::ExpandEnvironmentVariables($entry)
                if (-not (Test-SetupPathEntry -Path $env:PATH -Folder $expanded)) { $env:PATH += ";$expanded" }
            }
        }
    }
    return [bool](Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue)
}

function Invoke-SetupProcess {
    param([string[]]$Arguments)
    $start = [Diagnostics.ProcessStartInfo]::new('pwsh')
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
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

function Save-SetupInstaller {
    param([string]$Path)
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1' -OutFile $Path
}

function Find-SetupInstaller {
    $clone = [IO.Path]::GetFullPath((Join-Path $script:SetupPluginRoot '../../install.ps1'))
    if (Test-Path -LiteralPath $clone -PathType Leaf) { return $clone }
    $tools = @(Get-PsAiTools)
    foreach ($relative in @('plugins/marketplaces/ps-ai-marketplace/install.ps1', '.tmp/marketplaces/ps-ai-marketplace/install.ps1')) {
        foreach ($tool in $tools) {
            $folder = Join-Path $script:SetupHomeRoot $tool.plugin.defaultConfigDir.Substring(2)
            $path = Join-Path $folder $relative
            if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
        }
    }
    $download = Get-PsAiHomePath -HomeRoot $script:SetupHomeRoot -Path 'temp/install.ps1'
    New-Item -ItemType Directory -Path (Split-Path $download) -Force | Out-Null
    if ($script:SetupDownloadedInstaller -cne $download -or -not (Test-Path -LiteralPath $download -PathType Leaf)) {
        Save-SetupInstaller -Path $download
        $script:SetupDownloadedInstaller = $download
    }
    return $download
}

function Invoke-SetupInstaller {
    param([string]$Installer, [string]$Tool, [string]$ConfigDir)
    $result = Invoke-SetupProcess -Arguments @('-NoProfile', '-File', $Installer, '-Tools', $Tool, '-ConfigDir', $ConfigDir, '-Update', '-Yes')
    $log = Get-PsAiHomePath -HomeRoot $script:SetupHomeRoot -Path "temp/setup-install-$Tool.log"
    New-Item -ItemType Directory -Path (Split-Path $log) -Force | Out-Null
    [IO.File]::WriteAllText($log, $result.Output)
    return [int]$result.Code
}

function Resolve-SetupFolder {
    param([string]$Folder, [string]$HomeRoot)
    if ($Folder.StartsWith('~/') -or $Folder.StartsWith('~\')) { $Folder = Join-Path $HomeRoot $Folder.Substring(2) }
    return [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Folder))
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
    $managed = Get-PsAiNewAccountDir -Id $Agent.id -HomeRoot $HomeRoot
    $nextStep = if (-not $Adopted -and -not $Agent.provider -and $folder -ceq $managed) { "log in: run $($Agent.id)" } else { 'ready' }
    return [pscustomobject]@{
        Id = $Agent.id; Tool = $Tool; Folder = $folder
        Requested = [bool]$Requested; New = [bool]$New; Adopted = [bool]$Adopted
        Version = (Get-PsAiInstalledVersion -ConfigDir $folder -Tool $Tool)
        NextStep = $nextStep; Usable = $true
    }
}

function Get-SetupAddedAccount {
    param([string]$Item, [string]$Id, $Data, $Tools, [string]$HomeRoot)
    $colon = $Item.IndexOf(':')
    $toolId = if ($colon -lt 0) { $Item } else { $Item.Substring(0, $colon) }
    if (-not $Tools.Contains($toolId)) { throw "unknown tool '$toolId'" }
    if (-not $Id) { $Id = Get-SetupNextId -Tool $toolId -Data $Data }
    $folder = Get-PsAiNewAccountDir -Id $Id -HomeRoot $HomeRoot
    if ($colon -ge 0) {
        $folder = $Item.Substring($colon + 1)
        if (-not $folder) { throw 'Existing account config folder does not exist.' }
        $folder = Resolve-SetupFolder $folder $HomeRoot
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) { throw 'Existing account config folder does not exist.' }
    }
    $existing = @($Data.agents | Where-Object { $_.id -ceq $Id })[0]
    if ($existing) {
        if ($existing.tool -cne $toolId -or $existing.provider -or (Resolve-SetupFolder $existing.configDir $HomeRoot) -cne $folder) { throw "account '$Id' already exists with other values" }
    } else { Assert-PsAiNewId -Id $Id -Data $Data }
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
        if ($previous) { [void]$rows.Remove($previous) }
        $rows.Add($row)
        if ($row.New) { $planned.agents += [pscustomobject]@{ id = $row.Id; tool = $row.Tool.id; configDir = $row.Folder } }
    }
    return $rows.ToArray()
}

function Get-SetupCommands {
    param([string]$HomeRoot)
    foreach ($entry in (Get-PsAiOwnerCommands).GetEnumerator()) {
        $suffixes = if ($IsWindows) { @('', '.cmd') } else { @('') }
        foreach ($suffix in $suffixes) {
            $path = Get-PsAiHomePath -HomeRoot $HomeRoot -Path "bin/$($entry.Key)$suffix"
            $state = if (-not (Test-Path -LiteralPath $path)) { 'missing' }
                elseif (Test-PsAiOwnerCommandFile -Path $path -Script $entry.Value) { 'owned' } else { 'blocked' }
            [pscustomobject]@{ Name = $entry.Key; Script = $entry.Value; Path = $path; Windows = ($suffix -eq '.cmd'); State = $state }
        }
    }
}

function Get-SetupPlan {
    param([string[]]$Add, [string]$Id, [string]$HomeRoot)
    $settings = Get-PsAiHomePath -HomeRoot $HomeRoot -Path 'configuration/ps-ai-personalisation.json'
    $data = if (Test-Path -LiteralPath $settings) { Read-PsAiJson $settings } else { [pscustomobject]@{ schemaVersion = 1; agents = @(); channels = @() } }
    $tools = [ordered]@{}
    foreach ($tool in Get-PsAiTools) { $tools[$tool.id] = $tool }
    $accounts = @(Get-SetupAccounts -Add $Add -Id $Id -Data $data -Tools $tools -HomeRoot $HomeRoot)
    $missing = @()
    foreach ($tool in $tools.Values) {
        if ($tool.id -cin @($accounts.Tool.id) -and -not (Test-SetupCommand -Name $tool.command)) { $missing += $tool }
    }
    $bin = Get-PsAiHomePath -HomeRoot $HomeRoot -Path 'bin'
    $path = if ($IsWindows) { Get-SetupUserPath } else { $env:PATH }
    return @{
        HomeRoot = $HomeRoot; Settings = $settings; Data = $data; Accounts = $accounts; MissingTools = $missing
        Notes = (Join-Path (Split-Path $settings) 'ps-ai-notes.md'); Bin = $bin
        Commands = @(Get-SetupCommands -HomeRoot $HomeRoot); NeedsPath = (-not (Test-SetupPathEntry -Path $path -Folder $bin))
        Version = (Read-PsAiJson (Join-Path $script:SetupPluginRoot 'plugin.json')).version
    }
}

function Get-SetupPathHint {
    return 'add to your shell profile: export PATH="$HOME/.legion/bin:$PATH"'
}

function Write-SetupPlan {
    param($Plan)
    $lines = [Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $Plan.Settings) -or -not (Test-Path -LiteralPath $Plan.Notes)) { $lines.Add("  create   settings and notes in $(Split-Path $Plan.Settings)") }
    foreach ($tool in $Plan.MissingTools) {
        $method = if ($IsWindows) { 'winget' } else { $tool.install.hint }
        $lines.Add("  cli      install $($tool.id) ($method)")
    }
    foreach ($row in $Plan.Accounts) {
        if (-not $row.New) { continue }
        $kind = if ($row.Adopted) { 'existing' } else { 'new' }
        $lines.Add("  add      $($row.Id) ($($row.Tool.id)) $kind folder $($row.Folder)")
    }
    $folders = @($Plan.Accounts | Where-Object { $_.Version -cne $Plan.Version } | Select-Object -ExpandProperty Folder -Unique)
    if ($folders.Count) { $lines.Add("  install  ps-ai into $($folders -join ', ')") }
    $commands = @($Plan.Commands | Where-Object State -EQ missing | Select-Object -ExpandProperty Name -Unique)
    if ($commands.Count) { $lines.Add("  commands write $($commands -join ', ') in $($Plan.Bin)") }
    if ($Plan.NeedsPath) {
        $hint = if ($IsWindows) { "add $($Plan.Bin) to your user PATH" } else { Get-SetupPathHint }
        $lines.Add("  path     $hint")
    }
    if (-not $lines.Count) { 'Nothing to do.'; return }
    'Plan (nothing changed yet):'
    $lines.ToArray()
    'Run again with -Yes to apply.'
}

function Initialize-SetupFiles {
    param($Plan)
    if (Test-Path -LiteralPath $Plan.Settings) { 'skip: settings (already done)' }
    else { Write-PsAiPersonalisation -Data $Plan.Data -Path $Plan.Settings }
    if (Test-Path -LiteralPath $Plan.Notes) { 'skip: notes (already done)' }
    else {
        $template = Join-Path $script:SetupPluginRoot 'skills/ps-ai-personalisation/references/notes-template.md'
        Write-PsAiGeneratedFile -Path $Plan.Notes -Content ([IO.File]::ReadAllText($template))
    }
}

function Install-SetupTools {
    param($Plan)
    foreach ($tool in $Plan.MissingTools) {
        $result = Invoke-SetupToolInstall -Tool $tool.id
        $reason = if (-not $result.Ok) { "$($tool.id) install failed: $(ConvertTo-SetupOneLine $result.Message)" }
            elseif (-not (Test-SetupCommand -Name $tool.command)) { "$($tool.id) installed: open a new terminal, then finish setup" }
            else { '' }
        if (-not $reason) { continue }
        foreach ($row in $Plan.Accounts) {
            if ($row.Tool.id -cne $tool.id) { continue }
            $row.Usable = $false
            $row.NextStep = $reason
        }
    }
}

function Add-SetupAccounts {
    param($Plan)
    foreach ($row in $Plan.Accounts) {
        if (-not $row.Usable) { continue }
        if ($row.Requested) {
            $arguments = @{ Action = 'add'; Id = $row.Id; Tool = $row.Tool.id; HomeRoot = $Plan.HomeRoot }
            if ($row.Adopted) { $arguments.ConfigDir = $row.Folder }
            # Reuse the account script's validation and wrappers in a child; do not maintain another add implementation.
            $output = & pwsh -NoProfile -File (Join-Path $script:SetupBin 'ps-ai-account.ps1') @arguments 2>&1
            if ($LASTEXITCODE -ne 0) { throw (ConvertTo-SetupOneLine ($output -join "`n")) }
            if (-not $row.New) { "skip: account $($row.Id) (already done)" }
        } else { "skip: account $($row.Id) (already done)" }
        if ($row.New -and -not $row.Adopted) { $row.NextStep = "log in: run $($row.Id)" }
    }
}

function Write-SetupCommands {
    param($Plan)
    foreach ($name in (Get-PsAiOwnerCommands).Keys) {
        $files = @($Plan.Commands | Where-Object Name -CEQ $name)
        foreach ($file in $files) {
            if ($file.State -ne 'missing') { continue }
            $text = Get-PsAiShimText -Script (Join-Path $script:SetupBin $file.Script) -Windows:$file.Windows
            Write-PsAiGeneratedFile -Path $file.Path -Content $text -Executable
        }
        if (@($files | Where-Object State -EQ blocked).Count) { "blocked: command $name (another file is there)" }
        elseif (@($files | Where-Object State -EQ owned).Count) { "skip: command $name (already done)" }
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
    if (-not (Test-SetupPathEntry -Path $env:PATH -Folder $Plan.Bin)) { $env:PATH += ";$($Plan.Bin)" }
}

function Install-SetupPlugins {
    param($Plan)
    $installer = $null
    $installerChecked = $false
    $results = @{}
    foreach ($row in $Plan.Accounts) {
        if (-not $row.Usable) { continue }
        if ($row.Version -ceq $Plan.Version) { "skip: ps-ai in $($row.Folder) (already done)"; continue }
        $key = "$($row.Tool.id):$($row.Folder)"
        if (-not $results.ContainsKey($key)) {
            try {
                if (-not $installerChecked) { $installerChecked = $true; $installer = Find-SetupInstaller }
                $results[$key] = if ($installer) { Invoke-SetupInstaller -Installer $installer -Tool $row.Tool.id -ConfigDir $row.Folder } else { 1 }
            } catch { $results[$key] = 1 }
        }
        if ($results[$key] -ne 0) { $row.NextStep = "install failed: log in with $($row.Id), then finish setup" }
        $row.Version = Get-PsAiInstalledVersion -ConfigDir $row.Folder -Tool $row.Tool
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
    if (-not $IsWindows -and $Plan.NeedsPath) { Get-SetupPathHint }
}

function Invoke-Setup {
    param([string[]]$Add, [string]$Id, [switch]$Yes, [string]$HomeRoot = $HOME)
    $script:SetupHomeRoot = $HomeRoot
    $script:SetupDownloadedInstaller = $null
    $plan = Get-SetupPlan -Add $Add -Id $Id -HomeRoot $HomeRoot
    if (-not $Yes) { Write-SetupPlan -Plan $plan; return }
    Initialize-SetupFiles -Plan $plan
    Install-SetupTools -Plan $plan
    Add-SetupAccounts -Plan $plan
    Write-SetupCommands -Plan $plan
    Set-SetupPath -Plan $plan
    Install-SetupPlugins -Plan $plan
    Write-SetupTable -Plan $plan
    # Recoverable installer failures are next-step rows, not a failure of the whole setup run.
    $global:LASTEXITCODE = 0
}

# Main: parse adds and build the plan before any persistent change, then print it or apply and show the table.
if (-not $setupNoRun) { Invoke-Setup @setupArguments }
