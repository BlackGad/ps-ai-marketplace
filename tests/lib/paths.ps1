. (Join-Path $PSScriptRoot '../../plugins/legion/bin/lib/paths.ps1')

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
