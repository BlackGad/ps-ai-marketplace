param(
    [string[]]$Tools,
    [string]$Source = 'BlackGad/ps-ai-marketplace',
    [string]$ConfigDir,
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$NoRun,
    [string]$SourceRef = 'main',
    [switch]$Update,
    [switch]$Uninstall,
    [string]$HomeRoot
)

if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'plugins/ps-ai/install.ps1') -PathType Leaf)) {
    & (Join-Path $PSScriptRoot 'plugins/ps-ai/install.ps1') @PSBoundParameters
} else {
    if (-not (Get-Command Get-InstallSourceText -ErrorAction SilentlyContinue)) {
        function Get-InstallSourceText {
            param([string]$Url)
            $ProgressPreference = 'SilentlyContinue'
            (Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop).Content
        }
    }
    & ([scriptblock]::Create((Get-InstallSourceText -Url 'https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/plugins/ps-ai/install.ps1'))) @PSBoundParameters
}
