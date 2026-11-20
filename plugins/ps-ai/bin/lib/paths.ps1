function Get-PsAiHomePath {
    param([string]$Path, [string]$HomeRoot = $HOME)
    return Join-Path (Join-Path $HomeRoot '.legion') $Path
}

function Get-PsAiRepoPath {
    param([string]$Repo, [string]$Path)
    return Join-Path (Join-Path $Repo '.legion') $Path
}

function Get-PsAiPathComparer {
    if ($IsWindows) { return [StringComparer]::OrdinalIgnoreCase }
    return [StringComparer]::Ordinal
}

function Test-PsAiPathEntry {
    param([string]$Path, [string]$Folder)
    $comparer = Get-PsAiPathComparer
    foreach ($entry in $Path.Split([IO.Path]::PathSeparator)) {
        $expanded = if ($IsWindows) { [Environment]::ExpandEnvironmentVariables($entry) } else { $entry }
        $expanded = $expanded.TrimEnd('/', '\')
        if ($entry -and $comparer.Equals($expanded, $Folder.TrimEnd('/', '\'))) { return $true }
    }
    return $false
}
