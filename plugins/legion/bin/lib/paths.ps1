function Get-LegionHomePath {
    param([string]$Path, [string]$HomeRoot = $HOME)
    return Join-Path (Join-Path $HomeRoot '.legion') $Path
}

# Owner-file names shared by the installer and bin scripts.
function Get-LegionOwnerPath {
    param([ValidateSet('Settings', 'Notes', 'Update', 'Runtime', 'Install', 'Index')][string]$Name,
        [string]$HomeRoot = $HOME)
    $names = @{
        Settings = 'configuration/personalisation.json'
        Notes = 'configuration/notes.md'
        Update = 'temp/update.json'
        Runtime = 'bin/.runtime'
        Install = 'temp/install-'
        Index = 'footprints.json'
    }
    return Join-Path (Join-Path $HomeRoot '.legion') $names[$Name]
}

function Set-LegionTextPreservingEncoding {
    param([string]$Path, [string]$Text)
    $reader = [IO.StreamReader]::new($Path, $true)
    try {
        $original = $reader.ReadToEnd()
        $encoding = $reader.CurrentEncoding
    } finally { $reader.Dispose() }
    if ($original -ceq $Text) { return }
    $bytes = [IO.File]::ReadAllBytes($Path)
    $preamble = $encoding.GetPreamble()
    $hasPreamble = $preamble.Length -gt 0 -and $bytes.Length -ge $preamble.Length
    for ($i = 0; $hasPreamble -and $i -lt $preamble.Length; $i++) { $hasPreamble = $bytes[$i] -eq $preamble[$i] }
    $updated = $encoding.GetBytes($Text)
    $roundTrip = $encoding.GetBytes($original)
    if ($hasPreamble) {
        $updated = [byte[]]($preamble + $updated)
        $roundTrip = [byte[]]($preamble + $roundTrip)
    }
    if ([Convert]::ToBase64String($bytes) -cne [Convert]::ToBase64String($roundTrip)) { throw 'File encoding is not lossless; resolve it manually before editing' }
    [IO.File]::WriteAllBytes($Path, $updated)
}

function Test-LegionOwnerPathSafe {
    param([string]$Path, [Parameter(Mandatory)][string]$StopRoot)
    $comparer = Get-LegionPathComparer
    $current = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($StopRoot))
    if (-not (Test-LegionPathUnder -Path $current -Root $root -AllowEqual -PreserveLinks)) { throw 'Path is outside the link-walk stop root' }
    while ($current) {
        # The stop root itself may be a link, such as a linked home.
        if ($comparer.Equals($current, $root)) { return $true }
        if ((Test-Path -LiteralPath $current) -and ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
        $current = Split-Path $current -Parent
    }
    return $false
}

# Expand a leading ~/ or ~\ to the home root; any other path stays as given.
function Resolve-LegionHomePath {
    param([string]$Path, [string]$HomeRoot = $HOME)
    if ($Path -match '^~[/\\]') { return Join-Path $HomeRoot $Path.Substring(2) }
    return $Path
}

function Get-LegionRepoPath {
    param([string]$Repo, [string]$Path)
    return Join-Path (Join-Path $Repo '.legion') $Path
}

# The code worktree root: the parent of a Private .legion repository, or $null outside Git.
function Get-LegionCodeRoot {
    param([string]$Path)
    $root = git -C $Path rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    if ((Split-Path $root -Leaf) -eq '.legion') {
        $root = git -C (Split-Path $root -Parent) rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
    }
    return [IO.Path]::GetFullPath($root)
}

function Get-LegionPathComparer {
    if ($IsWindows) { return [StringComparer]::OrdinalIgnoreCase }
    return [StringComparer]::Ordinal
}

# Resolve linked ancestors too, keeping missing leaves such as a removed probe folder.
function Resolve-LegionDirectoryPath {
    param([string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    $parent = Split-Path $full -Parent
    if ($parent) {
        $full = Join-Path (Resolve-LegionDirectoryPath $parent) (Split-Path $full -Leaf)
    }
    if (Test-Path -LiteralPath $full -PathType Container) {
        $directory = Get-Item -LiteralPath $full -Force
        if ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            return Resolve-LegionDirectoryPath ($directory.ResolveLinkTarget($true).FullName)
        }
        return $directory.FullName
    }
    return $full
}

function Get-LegionSettingsLockPath {
    param([string]$Path)
    $resolved = Resolve-LegionDirectoryPath $Path
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        $resolved = $item.ResolveLinkTarget($true).FullName
    }
    return "$resolved.lock"
}

# Compare resolved paths with OS case rules. Safety walks preserve links so they can refuse them.
function Test-LegionPathUnder {
    param([string]$Path, [string]$Root, [switch]$AllowEqual, [switch]$PreserveLinks)
    $full = if ($PreserveLinks) { [IO.Path]::GetFullPath($Path) } else { Resolve-LegionDirectoryPath $Path }
    $rootPath = if ($PreserveLinks) { [IO.Path]::GetFullPath($Root) } else { Resolve-LegionDirectoryPath $Root }
    $full = [IO.Path]::TrimEndingDirectorySeparator($full)
    $rootPath = [IO.Path]::TrimEndingDirectorySeparator($rootPath)
    if ((Get-LegionPathComparer).Equals($full, $rootPath)) { return [bool]$AllowEqual }
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    return $full.StartsWith($rootPath.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, $comparison)
}

# The one header that marks a generated file as legion's, such as 'owner command' or 'account claude-a'.
function Get-LegionHeader {
    param([string]$Name, [switch]$Windows)
    $prefix = if ($Windows) { '@rem' } else { '#' }
    return "$prefix Generated by legion: $Name"
}

# The header owns the whole file: the first line of a .cmd file, the line after the shebang otherwise.
function Test-LegionHeader {
    param([string]$Path, [string]$Name)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $reader = [IO.StreamReader]::new($Path)
    try { $first = $reader.ReadLine(); $second = $reader.ReadLine() } finally { $reader.Dispose() }
    if ($Path.EndsWith('.cmd', [StringComparison]::OrdinalIgnoreCase)) { return $first -ceq (Get-LegionHeader -Name $Name -Windows) }
    return $first -ceq '#!/bin/sh' -and $second -ceq (Get-LegionHeader -Name $Name)
}

function Test-LegionOwnerCommandFile {
    param([string]$Path)
    return Test-LegionHeader -Path $Path -Name 'owner command'
}

function Test-LegionLauncherExecutable {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    if ($IsWindows) { return $true }
    return ([IO.File]::GetUnixFileMode($Path) -band [IO.UnixFileMode]::UserExecute) -ne 0
}

# One platform switch for the saved-PATH helpers: $env:OS, which tests can set.
# Windows compares without case and expands %VARIABLES%; elsewhere entries are literal.
function Test-LegionPathEntry {
    param([string]$Path, [string]$Folder, [string]$Separator = [string][IO.Path]::PathSeparator)
    $onWindows = $env:OS -eq 'Windows_NT'
    $comparer = if ($onWindows) { [StringComparer]::OrdinalIgnoreCase } else { [StringComparer]::Ordinal }
    $target = $Folder.TrimEnd('\', '/')
    foreach ($part in ($Path -split [regex]::Escape($Separator))) {
        $expanded = if ($onWindows) { [Environment]::ExpandEnvironmentVariables($part) } else { $part }
        if ($comparer.Equals($expanded.TrimEnd('\', '/'), $target)) { return $true }
    }
    return $false
}

# Get-LegionLease still uses this twin; milestone 3 removes it.
function Test-LegionSameStartTime {
    # Linux and macOS derive a process start time from the clock, so two reads can differ by a few milliseconds.
    param([datetime]$First, [datetime]$Second)
    return [math]::Abs(($First.ToUniversalTime() - $Second.ToUniversalTime()).TotalMilliseconds) -lt 500
}

function Get-LegionUserPath {
    if ($env:LEGION_TEST_USER_PATH_FILE) { return [IO.File]::ReadAllText($env:LEGION_TEST_USER_PATH_FILE) }
    # Read the raw registry value so entries such as %USERPROFILE%\bin stay unexpanded.
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
    if (-not $key) { return '' }
    try { return [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) }
    finally { $key.Dispose() }
}

function Set-LegionUserPath {
    param([string]$Path)
    if ($env:LEGION_TEST_USER_PATH_FILE) {
        [IO.File]::WriteAllText($env:LEGION_TEST_USER_PATH_FILE, $Path)
        return
    }
    # Keep the existing value kind (normally REG_EXPAND_SZ), then tell Windows the environment changed.
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
    try {
        $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
        if ($key.GetValueNames() -icontains 'Path') { $kind = $key.GetValueKind('Path') }
        $key.SetValue('Path', $Path, $kind)
    } finally { $key.Dispose() }
    if (-not ('LegionInstall.Environment' -as [type])) {
        Add-Type -Namespace LegionInstall -Name Environment -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern IntPtr SendMessageTimeout(IntPtr window, uint message, UIntPtr parameter, string value, uint flags, uint timeout, out UIntPtr result);
'@
    }
    $result = [UIntPtr]::Zero
    [void][LegionInstall.Environment]::SendMessageTimeout([IntPtr]0xffff, 0x1a, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
}

# The marker line above the PATH line legion adds to a shell profile.
function Get-LegionProfileMarker {
    return '# Added by legion'
}

function Get-LegionShellProfile {
    param([string]$HomeRoot = $HOME)
    $name = switch ([IO.Path]::GetFileName($env:SHELL)) { zsh { '.zshrc' } bash { '.bashrc' } default { '.profile' } }
    $path = Join-Path $HomeRoot $name
    $text = if (Test-Path -LiteralPath $path) { [IO.File]::ReadAllText($path) } else { '' }
    $line = 'export PATH="$HOME/.legion/bin:$PATH"'
    # Marked: the line sits under legion's marker, so legion added it; a bare line is the owner's.
    $marked = $text -cmatch ('(?m)^' + [regex]::Escape((Get-LegionProfileMarker)) + '\r?\n' +[regex]::Escape($line) + '\r?$')
    return [pscustomobject]@{ Path=$path; Text=$text; Line=$line; HasPath=($line -cin ($text -split '\r?\n')); Marked=$marked }
}

# The one saved user PATH writer; callers obtain consent before calling it.
function Add-LegionUserPath {
    param([string]$Folder, [string]$HomeRoot = $HOME, [switch]$DryRun)
    if ($env:OS -ne 'Windows_NT') {
        $profile = Get-LegionShellProfile -HomeRoot $HomeRoot
        if (-not (Test-LegionOwnerPathSafe -Path $profile.Path -StopRoot $HomeRoot)) { throw 'Shell profile contains a link; resolve it before writing' }
        if ($profile.HasPath) {
            if ($profile.Marked -and -not $DryRun) {
                $recorded = Get-LegionFootprints -HomeRoot $HomeRoot -Kind path-entry | Where-Object { $_.value -ceq $profile.Line -and (Resolve-LegionHomePath -Path $_.path -HomeRoot $HomeRoot) -ceq $profile.Path }
                Add-LegionFootprint -HomeRoot $HomeRoot -Kind path-entry -Path $profile.Path -Key ([string]$recorded.key) -Value $profile.Line -Owner legion
            }
            'skip: shell profile PATH (already done)'; return
        }
        "add $(Get-LegionProfileMarker) and $($profile.Line) to $($profile.Path)"
        if ($DryRun) { return }
        # Record a separating newline too, so purge restores a file without a final newline exactly.
        $separator = if ($profile.Text -and -not $profile.Text.EndsWith("`n")) { "`n" } else { '' }
        Add-LegionFootprint -HomeRoot $HomeRoot -Kind path-entry -Path $profile.Path -Key $separator -Value $profile.Line -Owner legion
        $text = $profile.Text + $separator + (Get-LegionProfileMarker) + "`n" + $profile.Line + "`n"
        if (Test-Path -LiteralPath $profile.Path) { Set-LegionTextPreservingEncoding -Path $profile.Path -Text $text }
        else { [IO.File]::WriteAllText($profile.Path, $text) }
        return
    }
    if ($DryRun) { "add $Folder to your user PATH"; return }
    $userPath = Get-LegionUserPath
    if (Test-LegionPathEntry -Path $userPath -Folder $Folder -Separator ';') { 'skip: path (already done)'; return }
    Add-LegionFootprint -HomeRoot $HomeRoot -Kind path-entry -Path 'user PATH' -Value $Folder.TrimEnd('\', '/') -Owner legion
    $updated = if ($userPath) { $userPath.TrimEnd(';') + ';' + $Folder } else { $Folder }
    Set-LegionUserPath -Path $updated
}

function Get-LegionMachinePath {
    return [Environment]::GetEnvironmentVariable('Path', 'Machine')
}

# Windows: the folders on the saved user and machine PATH, expanded. A new install shows up here before a new terminal.
function Get-LegionPersistentFolders {
    $folders = foreach ($path in @((Get-LegionUserPath), (Get-LegionMachinePath))) {
        foreach ($entry in ([string]$path).Split(';', [StringSplitOptions]::RemoveEmptyEntries)) {
            $folder = [Environment]::ExpandEnvironmentVariables($entry.Trim().Trim('"'))
            if ($folder) { $folder }
        }
    }
    return @($folders)
}

# Windows: a command found only on the saved PATH (a new install, before a new terminal).
# Path-only: nothing is run, and a sanitized shell may leave these folders out on purpose.
function Find-LegionPersistentCommand {
    param([string]$Name)
    if (-not $IsWindows) { return $null }
    foreach ($folder in (Get-LegionPersistentFolders)) {
        $command = Get-Command (Join-Path $folder $Name) -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { return $command.Source }
    }
    return $null
}

function Get-LegionRuntimeFiles {
    return @('bin/lib/tools.ps1', 'bin/lib/foundry.ps1', 'bin/lib/paths.ps1', 'bin/legion-foundry.ps1', 'schemas/tool.schema.json')
}

function Get-InstallPluginVersion {
    param([string]$Root)
    return (Get-Content -LiteralPath (Join-Path $Root 'plugin.json') -Raw | ConvertFrom-Json).version
}

# One environment folder per plugin copy, so copies never rebuild each other's environment.
function Get-LegionPythonEnvironment {
    param([string]$PluginRoot, [string]$HomeRoot = $HOME)

    $absolute = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PluginRoot)
    $key = (Resolve-LegionDirectoryPath $absolute).TrimEnd('/', '\')
    if ($IsWindows) { $key = $key.ToLowerInvariant() }
    $hash = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($key))
    $digest = ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant().Substring(0, 12)
    return Get-LegionHomePath -Path "python/env-$digest" -HomeRoot $HomeRoot
}
