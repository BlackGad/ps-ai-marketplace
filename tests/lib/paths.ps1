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

function Resolve-TestDirectory {
    param([string]$Path)
    $directory = Get-Item -LiteralPath $Path -Force
    if ($directory.Parent) {
        $parent = Resolve-TestDirectory $directory.Parent.FullName
        $directory = Get-Item -LiteralPath (Join-Path $parent $directory.Name) -Force
    }
    if ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $target = $directory.ResolveLinkTarget($true)
        return Resolve-TestDirectory $target.FullName
    }
    return $directory.FullName
}

function Get-TestTempPath {
    # The macOS temp folder is under /var, a link to /private/var, but a real home is not linked.
    # Fixtures use the resolved folder so they follow the same rules as a real home.
    return Resolve-TestDirectory ([IO.Path]::GetTempPath())
}
