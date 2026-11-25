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

# The Windows bootstrap runs in the built-in Windows PowerShell 5.1 (or PowerShell 7).
# It only obtains uv, then hands every option to the Python `legion install` command.
# Hand-built, reason: this runs before uv and Python exist, so it cannot use any Python library; it stays small on purpose.

function Get-InstallHome {
    if ($script:installHomeRoot) { return $script:installHomeRoot }
    return $HOME
}

# Persistent changes need consent: -Yes, or a yes at the prompt.
function Confirm-InstallChange {
    param([string]$Question, [switch]$Yes)
    return $Yes -or (Read-Host $Question) -match '^(?i:y|yes)$'
}

function Get-InstallLegionPath {
    param([string]$Path)
    return Join-Path (Join-Path (Get-InstallHome) '.legion') $Path
}

# uv is found on PATH, or in the folder its own installer uses.
function Get-InstallUv {
    $found = Get-Command uv -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $found.Source }
    $folders = @($env:UV_INSTALL_DIR, $env:XDG_BIN_HOME, (Join-Path (Join-Path (Get-InstallHome) '.local') 'bin'))
    foreach ($folder in $folders) {
        if (-not $folder) { continue }
        foreach ($name in @('uv.exe', 'uv')) {
            $path = Join-Path $folder $name
            if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
        }
    }
}

function Invoke-InstallDownload {
    param([string]$Url, [string]$OutFile)
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
}

# Runs uv's own installer script, which checks the checksum of the uv build it downloads.
function Invoke-InstallUvScript {
    param([string]$Script)
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script | Out-Host
    return $LASTEXITCODE
}

function Remove-InstallTemporary {
    param([string]$Path)
    $homePrefix = [IO.Path]::GetFullPath((Get-InstallHome)).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $target = [IO.Path]::GetFullPath($Path)
    $comparison = [StringComparison]::Ordinal
    if ($env:OS -eq 'Windows_NT') { $comparison = [StringComparison]::OrdinalIgnoreCase }
    if (-not $target.StartsWith($homePrefix, $comparison)) { throw 'Unsafe installer temporary path' }
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop }
}

function New-InstallTemporary {
    $temporary = Join-Path (Get-InstallLegionPath 'temp') ('install-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temporary -Force -ErrorAction Stop | Out-Null
    return $temporary
}

# Returns the path of uv, or $null when the owner has to act first (dry run, or no consent).
function Ensure-InstallUv {
    param([bool]$OnWindows = ($env:OS -eq 'Windows_NT'), [switch]$DryRun, [switch]$Yes)
    $uv = Get-InstallUv
    if ($uv) {
        Write-Host 'skip: uv (already done)'
        return $uv
    }
    Write-Host 'uv is missing.'
    if (-not $OnWindows) {
        Write-Host 'On macOS and Linux run install.sh instead: https://github.com/BlackGad/ps-legion-marketplace'
        return $null
    }
    Write-Host 'Install uv: download the official uv installer (https://astral.sh/uv/install.ps1), which checks its download and adds uv to your user PATH.'
    if ($DryRun) { return $null }
    if (-not (Confirm-InstallChange -Yes:$Yes -Question 'Install uv now? [y/N]')) {
        Write-Host 'Nothing changed. Run again with -Yes to apply.'
        return $null
    }
    $temporary = New-InstallTemporary
    try {
        $script = Join-Path $temporary 'uv-install.ps1'
        Invoke-InstallDownload -Url 'https://astral.sh/uv/install.ps1' -OutFile $script
        if ((Invoke-InstallUvScript -Script $script) -ne 0) { throw 'The uv installer failed.' }
    } finally {
        Remove-InstallTemporary -Path $temporary
    }
    $uv = Get-InstallUv
    if (-not $uv) { throw 'uv was installed but could not be found; open a new terminal and run the bootstrap again.' }
    return $uv
}

# The plugin folder that holds the Python project: this checkout, or the archive downloaded from the fixed legion repository.
function Get-InstallProject {
    param([string]$CheckoutRoot, [string]$Branch, [string]$Temporary)
    if ($CheckoutRoot) {
        $project = Join-Path (Join-Path $CheckoutRoot 'plugins') 'legion'
        if (Test-Path -LiteralPath (Join-Path $project 'pyproject.toml') -PathType Leaf) { return $project }
    }
    $archive = Join-Path $Temporary 'legion.zip'
    $expanded = Join-Path $Temporary 'expanded'
    try { Invoke-InstallDownload -Url "https://github.com/BlackGad/ps-legion-marketplace/archive/refs/heads/$Branch.zip" -OutFile $archive }
    catch {
        if ($Branch -eq 'stable') { throw 'could not find the latest release; try again or run with main' }
        throw
    }
    Expand-Archive -LiteralPath $archive -DestinationPath $expanded -ErrorAction Stop
    $top = @(Get-ChildItem -LiteralPath $expanded -Force)
    if ($top.Count -ne 1 -or -not $top[0].PSIsContainer) { throw 'Plugin archive must contain a single top folder.' }
    $project = Join-Path (Join-Path $top[0].FullName 'plugins') 'legion'
    if (-not (Test-Path -LiteralPath (Join-Path $project 'pyproject.toml') -PathType Leaf)) { throw 'Plugin archive is missing the legion project.' }
    return $project
}

# The options of this script, as the `legion install` command spells them.
function Get-InstallArguments {
    param([Collections.IDictionary]$Parameters)
    $arguments = @()
    if ($Parameters.HomeRoot) { $arguments += @('--home', $Parameters.HomeRoot) }
    $arguments += 'install'
    if ($Parameters.Tools) { $arguments += @('--tool', (@($Parameters.Tools) -join ',')) }
    if ($Parameters.Source) { $arguments += @('--source', $Parameters.Source) }
    if ($Parameters.ConfigDir) { $arguments += @('--config-dir', $Parameters.ConfigDir) }
    if ($Parameters.Ref) { $arguments += @('--ref', $Parameters.Ref) }
    foreach ($switch in @('DryRun', 'Yes', 'Update', 'Uninstall', 'Purge')) {
        if ($Parameters[$switch]) { $arguments += '--' + (($switch -creplace '([a-z])([A-Z])', '$1-$2').ToLowerInvariant()) }
    }
    return $arguments
}

function Invoke-InstallBootstrap {
    param([Collections.IDictionary]$Parameters, [string]$CheckoutRoot = $PSScriptRoot)
    $script:bootstrapExitCode = 0
    $script:installHomeRoot = $Parameters.HomeRoot
    $dryRun = [bool]$Parameters.DryRun
    $uv = Ensure-InstallUv -DryRun:$dryRun -Yes:([bool]$Parameters.Yes)
    if (-not $uv) { return }
    $folder = Split-Path $uv -Parent
    if (($env:PATH -split [regex]::Escape([string][IO.Path]::PathSeparator)) -notcontains $folder) {
        $env:PATH = $folder + [IO.Path]::PathSeparator + $env:PATH
    }
    $temporary = New-InstallTemporary
    $savedEnvironment = $env:UV_PROJECT_ENVIRONMENT
    try {
        $branch = 'stable'
        if ($Parameters.Ref -eq 'main') { $branch = 'main' }
        $project = Get-InstallProject -CheckoutRoot $CheckoutRoot -Branch $branch -Temporary $temporary
        # The project environment lives beside the downloaded copy and goes with it.
        $env:UV_PROJECT_ENVIRONMENT = Join-Path $temporary 'env'
        & $uv run --project $project --frozen --quiet legion @(Get-InstallArguments -Parameters $Parameters)
        $script:bootstrapExitCode = $LASTEXITCODE
    } finally {
        $env:UV_PROJECT_ENVIRONMENT = $savedEnvironment
        Remove-InstallTemporary -Path $temporary
    }
}

if (-not $NoRun) {
    Invoke-InstallBootstrap -Parameters $PSBoundParameters
    if ($script:bootstrapExitCode) { exit $script:bootstrapExitCode }
}
