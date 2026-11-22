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

function Assert-InstallString {
    param($Value, [string]$Field, [switch]$AllowEmpty)
    if ($Value -isnot [string] -or (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($Value))) {
        throw "invalid catalog field '$Field': expected string"
    }
}

function Assert-InstallObject {
    param($Value, [string]$Field)
    if ($Value -isnot [pscustomobject] -and $Value -isnot [Collections.IDictionary]) {
        throw "invalid catalog field '$Field': expected object"
    }
}

function Assert-InstallRelativePath {
    param($Value, [string]$Field, [switch]$AllowEmpty)
    Assert-InstallString $Value $Field -AllowEmpty:$AllowEmpty
    if ($Value -match '(^[/\\]|:|(^|[/\\])\.\.([/\\]|$))') { throw "invalid catalog field '$Field': expected relative path" }
}

function Test-InstallCommandAvailable {
    param([string]$Name)
    return [bool](Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue)
}

function Get-InstallHome {
    if ($script:installHomeRoot) { return $script:installHomeRoot }
    return [Environment]::GetFolderPath('UserProfile')
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

function Get-InstallPowerShellCommand {
    $command = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command }
    $portable = Get-InstallPortablePowerShell
    if ($portable) { return @{ Source=$portable } }
    if ($env:OS -eq 'Windows_NT' -and $env:ProgramFiles) {
        $candidate = Join-Path $env:ProgramFiles 'PowerShell/7/pwsh.exe'
        if (Test-Path -LiteralPath $candidate) { return @{ Source=$candidate } }
    }
}

function Get-InstallPortablePowerShell {
    $root = Get-InstallLegionPath 'tools/pwsh'
    $pattern = Join-Path ([WildcardPattern]::Escape($root)) $script:installCatalog.bootstrap.windows.portableCommand
    $file = Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
    if ($file) { return $file.FullName }
}

function Get-InstallUserPath {
    # Read the raw registry value so entries such as %USERPROFILE%\bin stay unexpanded.
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
    if (-not $key) { return '' }
    try { return [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) }
    finally { $key.Dispose() }
}

# 5.1 bootstrap twin of Set-InstallUserPath in plugins/legion/bin/lib/paths.ps1.
function Set-InstallUserPath {
    param([string]$Path)
    # Keep the existing value kind (normally REG_EXPAND_SZ), then tell Windows the environment changed.
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
    try {
        $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
        if ($key.GetValueNames() -icontains 'Path') { $kind = $key.GetValueKind('Path') }
        $key.SetValue('Path', $Path, $kind)
    } finally { $key.Dispose() }
    if (-not ('LegionInstall.Environment' -as [type])) {
        Add-Type -Namespace LegionInstall -Name Environment -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern IntPtr SendMessageTimeout(IntPtr window, uint message, UIntPtr parameter, string value, uint flags, uint timeout, out UIntPtr result);
'@
    }
    $result = [UIntPtr]::Zero
    [void][LegionInstall.Environment]::SendMessageTimeout([IntPtr]0xffff, 0x1a, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
}

function Test-InstallPathEntry {
    param([string]$Path, [string]$Entry, [string]$Separator)
    $target = $Entry.TrimEnd('\', '/')
    foreach ($part in ($Path -split [regex]::Escape($Separator))) {
        if ([Environment]::ExpandEnvironmentVariables($part).TrimEnd('\', '/') -ieq $target) { return $true }
    }
    return $false
}

function Add-InstallPowerShellPath {
    param([string]$Path)
    $userPath = Get-InstallUserPath
    if (-not (Test-InstallPathEntry -Path $userPath -Entry $Path -Separator ';')) {
        $updated = if ($userPath) { $userPath.TrimEnd(';') + ';' + $Path } else { $Path }
        Set-InstallUserPath -Path $updated
    }
    if (-not (Test-InstallPathEntry -Path $env:PATH -Entry $Path -Separator ([string][IO.Path]::PathSeparator))) {
        $env:PATH = $Path + [IO.Path]::PathSeparator + $env:PATH
    }
}

function Invoke-InstallDownload {
    param([string]$Url, [string]$OutFile)
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
}

function Install-PowerShellZip {
    $temporary = Join-Path (Get-InstallLegionPath 'temp') ('install-' + [guid]::NewGuid().ToString('N'))
    $metadata = Join-Path $temporary 'release.json'
    $archive = Join-Path $temporary 'pwsh.zip'
    try {
        New-Item -ItemType Directory -Path $temporary -Force -ErrorAction Stop | Out-Null
        $recipe = $script:installCatalog.bootstrap.windows.download.zip
        Invoke-InstallDownload -Url $recipe.metadataUrl -OutFile $metadata
        $release = Get-Content -LiteralPath $metadata -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $asset = $release.assets | Where-Object { $_.name -match $recipe.assetPattern } | Select-Object -First 1
        if (-not $asset -or $asset.digest -notmatch '^sha256:([a-fA-F0-9]{64})$') {
            throw 'PowerShell ZIP asset or SHA-256 digest is missing from the official release.'
        }
        $expectedHash = $Matches[1]
        Invoke-InstallDownload -Url $asset.browser_download_url -OutFile $archive
        if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256 -ErrorAction Stop).Hash -ine $expectedHash) {
            throw 'PowerShell ZIP SHA-256 digest mismatch; download deleted.'
        }
        $destination = Get-InstallLegionPath 'tools/pwsh'
        Expand-Archive -LiteralPath $archive -DestinationPath $destination -Force -ErrorAction Stop
        if (-not (Get-InstallPortablePowerShell)) { throw 'PowerShell ZIP does not contain the configured executable.' }
        $folder = $recipe.pathFolder.Replace('{version}', [string]$release.tag_name)
        Assert-InstallRelativePath $folder 'bootstrap ZIP pathFolder' -AllowEmpty
        Add-InstallPowerShellPath -Path (Join-Path $destination $folder)
    } finally {
        foreach ($file in @($archive, $metadata)) {
            if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force -ErrorAction Stop }
        }
        Remove-InstallTemporary -Path $temporary
    }
}

function Ensure-InstallPowerShell {
    param([bool]$OnWindows = ($env:OS -eq 'Windows_NT'), [switch]$DryRun, [switch]$Yes)
    $command = Get-InstallPowerShellCommand
    if ($command) {
        Write-Host 'skip: PowerShell 7 (already done)'
        # A previous portable install may be present before this shell has refreshed PATH.
        $portable = Get-InstallPortablePowerShell
        if ($OnWindows -and -not $DryRun -and $portable -and $command.Source -eq $portable -and
            (Confirm-InstallChange -Yes:$Yes -Question 'Add the portable PowerShell 7 folder to your user PATH? [y/N]')) {
            Add-InstallPowerShellPath -Path (Split-Path $portable -Parent)
        }
        return $true
    }
    if (-not $OnWindows) {
        Write-Host 'PowerShell 7 is missing.'
        Write-Host 'Install PowerShell 7: https://learn.microsoft.com/powershell/scripting/install/installing-powershell'
        return $false
    }
    if (-not $Yes -or $DryRun) {
        Write-Host 'PowerShell 7 is missing.'
        Write-Host ('winget install --id ' + $script:installCatalog.bootstrap.windows.wingetId + ' -e')
        Write-Host 'ZIP fallback: latest official PowerShell ZIP, verified with its SHA-256 digest, to ~/.legion/tools/pwsh/ (user and process PATH).'
    }
    if ($DryRun) { return $false }
    if (-not (Confirm-InstallChange -Yes:$Yes -Question 'Install PowerShell 7 now? [y/N]')) { return $false }
    if (Test-InstallCommandAvailable -Name winget) {
        try {
            $exitCode = Invoke-InstallWinget
            if ($exitCode -eq 0) {
                $command = Get-InstallPowerShellCommand
                if ($command) {
                    $folder = Split-Path $command.Source -Parent
                    if (-not (Test-InstallPathEntry -Path $env:PATH -Entry $folder -Separator ([string][IO.Path]::PathSeparator))) {
                        $env:PATH = $folder + [IO.Path]::PathSeparator + $env:PATH
                    }
                    return $true
                }
            }
            Write-Host 'winget did not make PowerShell 7 available.'
        } catch { Write-Host 'winget failed to install PowerShell 7.' }
    } else { Write-Host 'winget is missing.' }
    Install-PowerShellZip
    return $true
}

function Invoke-InstallWinget {
    & winget install --id $script:installCatalog.bootstrap.windows.wingetId -e | Out-Host
    return $LASTEXITCODE
}

function Assert-InstallBootstrapCatalog {
    param($Catalog)
    Assert-InstallObject $Catalog 'catalog'
    Assert-InstallObject $Catalog.bootstrap 'bootstrap'
    $windows = $Catalog.bootstrap.windows
    Assert-InstallObject $windows 'bootstrap.windows'
    Assert-InstallString $windows.wingetId 'bootstrap.windows.wingetId'
    Assert-InstallRelativePath $windows.portableCommand 'bootstrap.windows.portableCommand'
    Assert-InstallObject $windows.download 'bootstrap.windows.download'
    $zip = $windows.download.zip
    Assert-InstallObject $zip 'bootstrap.zip'
    foreach ($field in @('kind','resolver','verification')) { Assert-InstallString $zip.$field "bootstrap.zip.$field" }
    if ($zip.kind -cne 'zip' -or $zip.resolver -cne 'release-assets' -or $zip.verification -cne 'asset-digest') {
        throw 'invalid catalog bootstrap ZIP recipe'
    }
    Assert-InstallString $zip.metadataUrl 'bootstrap.zip.metadataUrl'
    Assert-InstallString $zip.assetPattern 'bootstrap.zip.assetPattern'
    $null = [regex]::new($zip.assetPattern)
    Assert-InstallRelativePath $zip.pathFolder 'bootstrap.zip.pathFolder' -AllowEmpty
}

function Remove-InstallTemporary {
    param([string]$Path)
    $homePrefix = [IO.Path]::GetFullPath((Get-InstallHome)).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $target = [IO.Path]::GetFullPath($Path)
    $comparison = if ($env:OS -eq 'Windows_NT') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $target.StartsWith($homePrefix, $comparison)) { throw 'Unsafe installer temporary path' }
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop }
}

# Separate seam from the PowerShell ZIP download so tests can serve a local repository archive.
if (-not (Get-Command Invoke-InstallArchiveDownload -ErrorAction SilentlyContinue)) {
    function Invoke-InstallArchiveDownload {
        param([string]$Url, [string]$OutFile)
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
    }
}

function Invoke-InstallBootstrap {
    param([Collections.IDictionary]$Parameters, [string]$CheckoutRoot = $PSScriptRoot)
    $script:bootstrapExitCode = 0
    $script:installHomeRoot = $Parameters.HomeRoot
    $temporary = $null
    try {
        $installer = if ($CheckoutRoot) { Join-Path $CheckoutRoot 'plugins/legion/install.ps1' }
        if (-not $installer -or -not (Test-Path -LiteralPath $installer -PathType Leaf)) {
            $temporary = Join-Path (Get-InstallLegionPath 'temp') ('install-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $temporary -Force -ErrorAction Stop | Out-Null
            $archive = Join-Path $temporary 'legion.zip'
            $expanded = Join-Path $temporary 'expanded'
            $branch = if ($Parameters.Ref -eq 'main') { 'main' } else { 'stable' }
            try { Invoke-InstallArchiveDownload -Url "https://github.com/BlackGad/ps-legion-marketplace/archive/refs/heads/$branch.zip" -OutFile $archive }
            catch {
                if ($branch -eq 'stable') { throw 'could not find the latest release; try again or run with main' }
                throw
            }
            Expand-Archive -LiteralPath $archive -DestinationPath $expanded -ErrorAction Stop
            $top = @(Get-ChildItem -LiteralPath $expanded -Force)
            if ($top.Count -ne 1 -or -not $top[0].PSIsContainer) { throw 'Plugin archive must contain a single top folder.' }
            $installer = Join-Path $top[0].FullName 'plugins/legion/install.ps1'
        }
        if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) { throw 'Plugin archive installer is missing.' }
        $catalog = Join-Path (Split-Path $installer -Parent) 'tools.json'
        $script:installCatalog = Get-Content -LiteralPath $catalog -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        Assert-InstallBootstrapCatalog -Catalog $script:installCatalog
        if (-not (Ensure-InstallPowerShell -DryRun:$Parameters.DryRun -Yes:$Parameters.Yes)) {
            if (-not $Parameters.DryRun) { Write-Host 'Nothing changed. Run again with -Yes to apply.' }
            return
        }
        $pwsh = (Get-InstallPowerShellCommand).Source
        # SwitchParameter loses its type across the process boundary; Boolean keeps its binding meaning.
        $arguments = @{}
        foreach ($name in $Parameters.Keys) {
            $value = $Parameters[$name]
            $arguments[$name] = if ($value -is [Management.Automation.SwitchParameter]) { [bool]$value } else { $value }
        }
        & $pwsh -NoProfile -Command { param($p,$a) $ErrorActionPreference = 'Stop'; & $p @a; exit $LASTEXITCODE } -args $installer,$arguments
        $script:bootstrapExitCode = $LASTEXITCODE
    } finally {
        if ($temporary) { Remove-InstallTemporary -Path $temporary }
    }
}

if (-not $NoRun) {
    Invoke-InstallBootstrap -Parameters $PSBoundParameters
    if ($script:bootstrapExitCode) { exit $script:bootstrapExitCode }
}
