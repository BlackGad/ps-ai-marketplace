function Get-LongPath {
    # Windows CI runners use an 8.3 short TEMP such as C:\Users\RUNNER~1; tools report the long form.
    param([string]$Path)
    if (-not $IsWindows) { return $Path }
    if (-not ('PsAiTestNative' -as [type])) {
        Add-Type -Namespace '' -Name PsAiTestNative -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
public static extern int GetLongPathName(string shortPath, System.Text.StringBuilder longPath, int size);
'@
    }
    $buffer = New-Object System.Text.StringBuilder 32768
    if ([PsAiTestNative]::GetLongPathName($Path, $buffer, $buffer.Capacity) -eq 0) { return $Path }
    return $buffer.ToString()
}

function Get-TestTempPath {
    # The macOS temp folder is under /var, a link to /private/var, but a real home is not linked.
    # Fixtures use the resolved folder so they follow the same rules as a real home.
    $temp = [IO.Path]::GetTempPath()
    if ($IsWindows) { return $temp }
    return (& /bin/sh -c 'cd "$1" && pwd -P' sh $temp)
}
