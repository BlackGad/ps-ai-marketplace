param(
    [ValidateSet('personalisation', 'project')][string]$Kind,
    [string]$Path
)

. (Join-Path $PSScriptRoot 'lib/settings.ps1')

$issues = @(Invoke-LegionValidation -Kind $Kind -Path $Path)
if ($issues.Count -gt 0) {
    $issues | Write-Output
    exit 1
}
