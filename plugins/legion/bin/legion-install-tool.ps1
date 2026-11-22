param(
    [string]$Tool,
    [switch]$Yes,
    [ValidateSet('windows','macos','linux')][string]$Platform,
    [ValidateSet('winget','msi','zip')][string]$Method,
    [switch]$NoRun
)

. (Join-Path $PSScriptRoot 'lib/footprints.ps1')

. (Join-Path $PSScriptRoot 'lib/tools.ps1')

. (Join-Path $PSScriptRoot 'install-tool/recipe.ps1')

function Invoke-ToolCommand {
    param([string[]]$Command)
    $arguments = [string[]]@($Command | Select-Object -Skip 1)
    & $Command[0] @arguments | Out-Host
    return $LASTEXITCODE
}

function Invoke-ToolDownload {
    param([string]$Url, [string]$OutFile)
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -ErrorAction Stop
}

function Get-ToolInstallRoot {
    param([string]$Tool)
    $null = Get-ToolInstallData -Tool $Tool
    Get-LegionHomePath -Path "tools/$Tool"
}

function New-ToolDownloadPath {
    param([string]$Extension = 'txt')
    $tempRoot = Get-LegionHomePath -Path 'temp'
    New-Item -ItemType Directory -Path $tempRoot -Force -ErrorAction Stop | Out-Null
    Join-Path $tempRoot ("install-$([guid]::NewGuid().ToString('N')).$Extension")
}

function Get-ToolSourceText {
    param([string]$Url)
    $file = New-ToolDownloadPath
    try {
        Invoke-ToolDownload -Url $Url -OutFile $file
        Get-Content -LiteralPath $file -Raw -ErrorAction Stop
    } finally {
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force }
    }
}

function Get-ToolChecksum {
    param([string]$Text, [string]$Name)
    $match = [regex]::Match($Text, ('(?m)^([a-fA-F0-9]{64})\s+\*?' + [regex]::Escape($Name) + '\s*$'))
    if (-not $match.Success) { throw "no SHA-256 checksum for $Name" }
    $match.Groups[1].Value.ToLowerInvariant()
}

function Get-ToolDownload {
    param(
        [string]$Tool,
        [ValidateSet('msi','zip')][string]$Method
    )
    $recipe = (Get-ToolInstallData -Tool $Tool).windows.download.$Method
    $result = @{ Url=''; Hash=$null; Kind=$recipe.kind; Arguments=[string[]]@(); PathFolder='' }
    if ($recipe.kind -eq 'script') {
        # Official scripts verify their payloads; the schema requires vendor verification.
        $result.Url = $recipe.url
        return $result
    }
    $result.Arguments = [string[]]$recipe.arguments
    $result.PathFolder = [string]$recipe.pathFolder
    switch ($recipe.resolver) {
        'release-assets' {
            $release = Get-ToolSourceText -Url $recipe.metadataUrl | ConvertFrom-Json
            $asset = $release.assets | Where-Object name -Match $recipe.assetPattern | Select-Object -First 1
            if (-not $asset) { throw "no official $Tool $Method release asset found" }
            $digest = [regex]::Match([string]$asset.digest, '^sha256:([a-fA-F0-9]{64})$')
            if (-not $digest.Success) { throw "no SHA-256 digest for $($asset.name)" }
            $result.Url = $asset.browser_download_url
            $result.Hash = $digest.Groups[1].Value.ToLowerInvariant()
        }
        'lts-index' {
            $versions = Get-ToolSourceText -Url $recipe.metadataUrl | ConvertFrom-Json
            $version = ($versions | Where-Object lts | Select-Object -First 1).version
            if ($version -notmatch '^v\d+\.\d+\.\d+$') { throw "no $Tool LTS release found" }
            $name = $recipe.assetName.Replace('{version}', $version)
            $result.Url = $recipe.url.Replace('{version}', $version)
            $checksumUrl = $recipe.checksumUrl.Replace('{version}', $version)
            $checksums = Get-ToolSourceText -Url $checksumUrl
            $result.Hash = Get-ToolChecksum -Text $checksums -Name $name
            $result.PathFolder = $result.PathFolder.Replace('{version}', $version)
        }
        default { throw "unsupported download resolver '$($recipe.resolver)'" }
    }
    return $result
}

function Test-DownloadHash {
    param([string]$Path, [string]$Expected)
    if ($Expected -notmatch '^[a-fA-F0-9]{64}$') { return $false }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash -ieq $Expected
}

function Resolve-ToolRelativePath {
    param([string]$Root, [AllowEmptyString()][string]$RelativePath)
    $relative = $RelativePath.Replace('\', [IO.Path]::DirectorySeparatorChar).Replace('/', [IO.Path]::DirectorySeparatorChar)
    if ([IO.Path]::IsPathRooted($relative) -or $relative -match '^[a-zA-Z]:' -or '..' -in ($relative -split '[\\/]')) {
        throw 'path must be relative and inside the tool folder'
    }
    $rootPath = [IO.Path]::GetFullPath($Root)
    $path = [IO.Path]::GetFullPath((Join-Path $rootPath $relative))
    if (-not (Test-LegionPathUnder -Path $path -Root $rootPath -AllowEqual -PreserveLinks)) {
        throw 'path must be inside the tool folder'
    }
    return $path
}

function Get-ToolPortableCommand {
    param([string]$Tool)
    $relative = (Get-ToolInstallData -Tool $Tool).windows.portableCommand
    $root = [IO.Path]::GetFullPath((Get-ToolInstallRoot -Tool $Tool))
    $path = Resolve-ToolRelativePath -Root $root -RelativePath $relative
    if ([Management.Automation.WildcardPattern]::ContainsWildcardCharacters($relative)) {
        $pattern = Join-Path ([Management.Automation.WildcardPattern]::Escape($root)) $relative
        # Compare digit groups numerically so 22.10 sorts after 22.9.
        $entry = Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue | Sort-Object {
            $relativeName = [IO.Path]::GetRelativePath($root, $_.FullName)
            [regex]::Replace($relativeName, '\d+', { param($number) $number.Value.PadLeft(20, '0') })
        } -Descending | Select-Object -First 1
        if ($entry) {
            return Resolve-ToolRelativePath -Root $root -RelativePath ([IO.Path]::GetRelativePath($root, $entry.FullName))
        }
        return $null
    }
    return $path
}

function Install-ToolZip {
    param(
        [string]$Tool,
        [string]$Archive,
        [AllowEmptyString()][string]$PathFolder
    )
    $root = [IO.Path]::GetFullPath((Get-ToolInstallRoot -Tool $Tool))
    $folder = Resolve-ToolRelativePath -Root $root -RelativePath $PathFolder
    $command = Get-ToolPortableCommand -Tool $Tool
    if (-not $command -or -not (Test-Path -LiteralPath $command -PathType Leaf)) {
        Expand-Archive -LiteralPath $Archive -DestinationPath $root -Force -ErrorAction Stop
    }
    $command = Get-ToolPortableCommand -Tool $Tool
    if (-not $command -or -not (Test-Path -LiteralPath $command -PathType Leaf)) { throw "$Tool executable missing from download" }
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) { throw "executable folder missing for $Tool download" }
    Add-LegionUserPath -Folder $folder
}

function Invoke-ToolDownloadInstall {
    param([string]$Tool, [ValidateSet('msi','zip')][string]$Method)
    $download = Get-ToolDownload -Tool $Tool -Method $Method
    $extension = if ($download.Kind -eq 'script') { 'ps1' } else { $download.Kind }
    $file = New-ToolDownloadPath -Extension $extension
    try {
        Invoke-ToolDownload -Url $download.Url -OutFile $file
        if ($download.Kind -ne 'script' -and -not (Test-DownloadHash -Path $file -Expected $download.Hash)) { throw "hash mismatch for $Tool download" }
        if ($download.Kind -eq 'zip') {
            Install-ToolZip -Tool $Tool -Archive $file -PathFolder $download.PathFolder
        } else {
            $command = switch ($download.Kind) {
                msi { [string[]]@('msiexec.exe','/i',$file) + $download.Arguments }
                exe { [string[]]@($file) + $download.Arguments }
                script { [string[]]@((Join-Path $PSHOME 'pwsh.exe'),'-NoProfile','-File',$file) + $download.Arguments }
                default { throw "unsupported download kind '$($download.Kind)'" }
            }
            $code = Invoke-ToolCommand -Command $command
            if ($code -notin @(0,3010)) { throw "$Tool installation command exited $code" }
        }
        $global:LASTEXITCODE = 0
        "${Tool}: installed; open a new terminal to refresh PATH"
    } finally {
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force }
    }
}

function Invoke-ToolInstall {
    param(
        [string]$Tool,
        [ValidateSet('windows','macos','linux')][string]$Platform,
        [ValidateSet('winget','msi','zip')][string]$Method,
        [switch]$Yes
    )
    $global:LASTEXITCODE = 0
    if ($Method -and $Platform -ne 'windows') { throw '-Method is Windows only' }
    $recipe = Get-ToolRecipe -Tool $Tool -Platform $Platform
    $state = Test-ToolInstalled -Tool $Tool
    if ($state.Installed) {
        if ($Yes) { "skip: $Tool already installed ($($state.Version)) (already done)" }
        else { "${Tool}: installed $($state.Version)" }
        return
    }
    if ($Platform -eq 'windows') {
        $portableCommand = Get-ToolPortableCommand -Tool $Tool
        if ($portableCommand -and (Test-Path -LiteralPath $portableCommand -PathType Leaf)) {
            if ($Yes) {
                $pathFolder = [IO.Path]::GetRelativePath((Get-ToolInstallRoot -Tool $Tool), (Split-Path $portableCommand -Parent))
                Install-ToolZip -Tool $Tool -PathFolder $pathFolder
            }
            "skip: $Tool already installed (portable) (already done)"
            return
        }
        $windows = (Get-ToolInstallData -Tool $Tool).windows
        $npm = $windows.npmWhenAvailable
        if ($npm -and (Test-ToolCommandAvailable -Name $npm.check)) {
            "${Tool}: $($npm.command -join ' ')"
            if ($Yes) {
                $code = Invoke-ToolCommand -Command $npm.command
                if ($code -ne 0) { throw "$Tool installation command exited $code" }
            }
            return
        }
        if ($Method -in @('msi','zip')) {
            $downloadMethod = $Method
            if ($windows.download.$downloadMethod.kind -eq 'script') {
                $scriptUrl = $windows.download.$downloadMethod.url
                "${Tool}: pwsh -NoProfile -Command irm $scriptUrl | iex"
            }
            else { "${Tool}: -Method $downloadMethod (official download)" }
            if ($Yes) { Invoke-ToolDownloadInstall -Tool $Tool -Method $downloadMethod }
            return
        }
        "${Tool}: $($recipe.Install[0] -join ' ')"
        $wingetAvailable = Test-ToolCommandAvailable -Name winget
        if ($wingetAvailable -and -not $Yes) { return }
        if ($wingetAvailable) {
            try {
                $code = Invoke-ToolCommand -Command $recipe.Install[0]
                if ($code -eq 0) { return }
                "winget failed (exit $code)."
            } catch { # A blocked or broken winget executable needs the same method choice.
                'winget failed to start.'
            }
        } else { 'winget is not available.' }
        'choose -Method msi (official installer, needs admin) or -Method zip (user folder, no admin)'
        $global:LASTEXITCODE = 2
        return
    }
    "${Tool}: missing"
    foreach ($need in $recipe.Needs) {
        $needState = Test-ToolInstalled -Tool $need
        if (-not $needState.Installed) {
            Invoke-ToolInstall -Tool $need -Platform $Platform -Yes:$Yes
            if ($Yes -and -not (Test-ToolInstalled -Tool $need).Installed) {
                throw "$Tool needs $need; install $need using the instructions above, then run this again"
            }
        }
    }
    if ($recipe.Install.Count -eq 0) {
        "${Tool}: install instructions: $($recipe.Docs)"
        return
    }
    foreach ($command in $recipe.Install) { "${Tool}: $($command -join ' ')" }
    if (-not $Yes) { return }
    $manager = [string]$recipe.Install[0][0]
    if ($manager -in @('winget','brew') -and -not (Test-ToolCommandAvailable -Name $manager)) {
        $url = if ($manager -eq 'winget') { 'https://learn.microsoft.com/windows/package-manager/winget/' } else { 'https://brew.sh/' }
        throw "$manager is missing; install it from $url, then run this again"
    }
    foreach ($command in $recipe.Install) {
        $code = Invoke-ToolCommand -Command ([string[]]$command)
        if ($code -ne 0) { throw "$Tool installation command exited $code" }
    }
    $after = Test-ToolInstalled -Tool $Tool
    if (-not $after.Installed) { throw "$Tool is still missing after installation; open a new terminal to refresh PATH, then check again" }
    "${Tool}: installed $($after.Version)"
}

if (-not $NoRun) {
    if (-not $Tool) { throw '-Tool is required' }
    if (-not $Platform) {
        $Platform = if ($IsWindows) { 'windows' } elseif ($IsMacOS) { 'macos' } else { 'linux' }
    }
    $parameters = @{ Tool=$Tool; Platform=$Platform; Yes=$Yes }
    if ($Method) { $parameters.Method = $Method }
    Invoke-ToolInstall @parameters
    exit $LASTEXITCODE
}
