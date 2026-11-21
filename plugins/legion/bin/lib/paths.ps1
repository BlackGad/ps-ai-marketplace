function Get-LegionHomePath {
    param([string]$Path, [string]$HomeRoot = $HOME)
    return Join-Path (Join-Path $HomeRoot '.legion') $Path
}

# Owner-file names live here; standalone install.ps1 carries the same small helpers.
function Get-LegionOwnerPath {
    param([ValidateSet('Settings', 'Notes', 'Update', 'Runtime', 'Install')][string]$Name,
        [string]$HomeRoot = $HOME)
    $names = @{
        Settings = 'configuration/personalisation.json'
        Notes = 'configuration/notes.md'
        Update = 'temp/update.json'
        Runtime = 'bin/.runtime'
        Install = 'temp/install-'
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
    param([string]$Path)
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if ((Test-Path -LiteralPath $current) -and ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
        $current = Split-Path $current -Parent
    }
    return $true
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

function Test-LegionLauncherExecutable {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    if ($IsWindows) { return $true }
    return ([IO.File]::GetUnixFileMode($Path) -band [IO.UnixFileMode]::UserExecute) -ne 0
}

function Test-LegionPathEntry {
    param([string]$Path, [string]$Folder)
    $comparer = Get-LegionPathComparer
    foreach ($entry in $Path.Split([IO.Path]::PathSeparator)) {
        $expanded = if ($IsWindows) { [Environment]::ExpandEnvironmentVariables($entry) } else { $entry }
        $expanded = $expanded.TrimEnd('/', '\')
        if ($entry -and $comparer.Equals($expanded, $Folder.TrimEnd('/', '\'))) { return $true }
    }
    return $false
}

function Test-LegionSameStartTime {
    # Linux and macOS derive a process start time from the clock, so two reads can differ by a few milliseconds.
    param([datetime]$First, [datetime]$Second)
    return [math]::Abs(($First.ToUniversalTime() - $Second.ToUniversalTime()).TotalMilliseconds) -lt 500
}
