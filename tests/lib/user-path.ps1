# The real registry is read only here; snapshots and failures never expose its contents.
function Get-TestUserPathSnapshot {
    if (-not $IsWindows) { return [pscustomobject]@{ Value=$null; Kind=$null } }
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
    try {
        if ($key -and $key.GetValueNames() -icontains 'Path') {
            return [pscustomobject]@{
                Value = $key.GetValue('Path', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                Kind = $key.GetValueKind('Path')
            }
        }
        return [pscustomobject]@{ Value=$null; Kind=$null }
    } finally { if ($key) { $key.Dispose() } }
}

function Assert-TestUserPathUnchanged {
    param($Before)
    $after = Get-TestUserPathSnapshot
    if ($Before.Value -cne $after.Value -or $Before.Kind -ne $after.Kind) {
        throw 'Tests changed the real user PATH value or registry value kind.'
    }
}
