# Link-safe path comparison for the test runner and the tests.

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

function Get-LongPath {
    # Windows CI runners use an 8.3 short TEMP such as C:\Users\RUNNER~1; tools report the long form.
    param([string]$Path)
    if (-not $IsWindows) { return $Path }
    if (-not ('LegionTestNative' -as [type])) {
        Add-Type -Namespace '' -Name LegionTestNative -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
public static extern int GetLongPathName(string shortPath, System.Text.StringBuilder longPath, int size);
'@
    }
    $buffer = New-Object System.Text.StringBuilder 32768
    if ([LegionTestNative]::GetLongPathName($Path, $buffer, $buffer.Capacity) -eq 0) { return $Path }
    return $buffer.ToString()
}

function Get-TestTempPath {
    # Keep the runner's linked temp path so every OS exercises linked ancestors.
    return [IO.Path]::GetTempPath()
}

function Remove-TestFolder {
    param([string]$Path, [string]$AllowedParent)
    $full = Resolve-LegionDirectoryPath $Path
    if (-not (Test-LegionPathUnder -Path $full -Root $AllowedParent)) { throw 'Unsafe test folder cleanup' }
    if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Recurse -Force }
}
