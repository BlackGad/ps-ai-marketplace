param(
    [string[]]$Tools,
    [string]$Source = 'BlackGad/ps-legion-marketplace',
    [string]$ConfigDir,
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$NoRun,
    [ValidateSet('release','main')][string]$Ref = 'release',
    [switch]$Update,
    [switch]$Uninstall,
    [switch]$Purge,
    [string]$HomeRoot
)

if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'plugins/legion/install.ps1') -PathType Leaf)) {
    & (Join-Path $PSScriptRoot 'plugins/legion/install.ps1') @PSBoundParameters
} else {
    if (-not (Get-Command Get-InstallSourceText -ErrorAction SilentlyContinue)) {
        function Get-InstallSourceText {
            param([string]$Url)
            $ProgressPreference = 'SilentlyContinue'
            (Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop).Content
        }
    }
    $branch = if ($Ref -eq 'main') { 'main' } else { 'stable' }
    try { $installer = Get-InstallSourceText -Url "https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/$branch/plugins/legion/install.ps1" }
    catch {
        if ($Ref -eq 'release') { throw 'could not find the latest release; try again or run with main' }
        throw
    }
    & ([scriptblock]::Create($installer)) @PSBoundParameters
}
