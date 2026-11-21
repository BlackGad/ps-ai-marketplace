function Get-LegionHomePath {
    param([string]$Path, [string]$HomeRoot = $HOME)
    return Join-Path (Join-Path $HomeRoot '.legion') $Path
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
