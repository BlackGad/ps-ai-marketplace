param(
    [ValidateSet('pwsh','git','node','claude','codex','copilot','gh','glab','az')][string]$Tool,
    [switch]$Yes,
    [ValidateSet('windows','macos','linux')][string]$Platform,
    [ValidateSet('winget','msi','zip')][string]$Method,
    [switch]$NoRun
)

function Get-ToolRecipe {
    param(
        [ValidateSet('pwsh','git','node','claude','codex','copilot','gh','glab','az')][string]$Tool,
        [ValidateSet('windows','macos','linux')][string]$Platform
    )
    $checkName = if ($Tool -eq 'node') { 'node' } else { $Tool }
    $needs = [string[]]@()
    $docs = ''
    $install = [object[]]@()
    if ($Tool -in @('codex','copilot') -and $Platform -ne 'windows') { $needs = [string[]]@('node') }
    if ($Platform -eq 'windows') {
        $id = @{ pwsh='Microsoft.PowerShell'; git='Git.Git'; node='OpenJS.NodeJS.LTS'; claude='Anthropic.ClaudeCode'; codex='OpenAI.Codex'; copilot='GitHub.Copilot'; gh='GitHub.cli'; glab='GLab.GLab'; az='Microsoft.AzureCLI' }[$Tool]
        $install = @(,([string[]]@('winget','install','--id',$id,'-e')))
    } elseif ($Platform -eq 'macos') {
        $package = @{ pwsh='powershell'; git='git'; node='node'; gh='gh'; glab='glab'; az='azure-cli' }[$Tool]
        if ($package) {
            $args = if ($Tool -eq 'pwsh') { [string[]]@('brew','install','--cask',$package) } else { [string[]]@('brew','install',$package) }
            $install = @(,($args))
        } elseif ($Tool -eq 'claude') { $install = @(,([string[]]@('bash','-c','curl -fsSL https://claude.ai/install.sh | bash'))) }
        elseif ($Tool -eq 'codex') { $install = @(,([string[]]@('npm','install','-g','@openai/codex'))) }
        else { $install = @(,([string[]]@('npm','install','-g','@github/copilot'))) }
    } else {
        $docs = @{ pwsh='https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux'; git='https://git-scm.com/download/linux'; node='https://nodejs.org/en/download'; gh='https://github.com/cli/cli/blob/trunk/docs/install_linux.md'; glab='https://gitlab.com/gitlab-org/cli#installation'; az='https://learn.microsoft.com/cli/azure/install-azure-cli-linux' }[$Tool]
        if ($Tool -eq 'claude') { $install = @(,([string[]]@('bash','-c','curl -fsSL https://claude.ai/install.sh | bash'))) }
        elseif ($Tool -eq 'codex') { $install = @(,([string[]]@('npm','install','-g','@openai/codex'))) }
        elseif ($Tool -eq 'copilot') { $install = @(,([string[]]@('npm','install','-g','@github/copilot'))) }
    }
    return [pscustomobject]@{ Check=[string[]]@($checkName,'--version'); Install=$install; Needs=$needs; Docs=$docs }
}

function Test-ToolCommandAvailable {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-ToolInstalled {
    param([ValidateSet('pwsh','git','node','claude','codex','copilot','gh','glab','az')][string]$Tool)
    $name = if ($Tool -eq 'node') { 'node' } else { $Tool }
    $command = $null
    if (Test-ToolCommandAvailable -Name $name) { $command = $name }
    elseif ($IsWindows) {
        # Installers update persistent PATH, while the current shell keeps its old copy.
        $persistentPath = (Get-UserPath) + ';' + [Environment]::GetEnvironmentVariable('PATH', 'Machine')
        foreach ($entry in ($persistentPath -split ';' | Where-Object { $_.Trim() })) {
            $folder = [Environment]::ExpandEnvironmentVariables($entry.Trim().Trim('"'))
            foreach ($suffix in @('.exe','.cmd','.ps1')) {
                $candidate = Join-Path $folder "$name$suffix"
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    # A sanitized shell may deliberately exclude this directory.
                    # Recognize an installation without executing outside its PATH.
                    return @{ Installed=$true; Version='persisted PATH' }
                }
            }
        }
    }
    if (-not $command) { return @{ Installed=$false; Version='' } }
    try {
        $version = (& $command --version 2>$null | Select-Object -First 1)
        return @{ Installed=$true; Version=([string]$version).Trim() }
    } catch { return @{ Installed=$false; Version='' } }
}

function Invoke-ToolCommand {
    param([string[]]$Command)
    $arguments = [string[]]@($Command | Select-Object -Skip 1)
    & $Command[0] @arguments | Out-Host
    return $LASTEXITCODE
}

function Invoke-ToolDownload {
    param([string]$Url, [string]$OutFile)
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -ErrorAction Stop
}

function Get-ToolInstallRoot {
    param([ValidateSet('pwsh','git','node','claude','codex','copilot','gh','glab','az')][string]$Tool)
    Join-Path $HOME ".agents/tools/$Tool"
}

function New-ToolDownloadPath {
    param([string]$Extension = 'txt')
    $tempRoot = Join-Path (Split-Path (Split-Path (Get-ToolInstallRoot -Tool gh) -Parent) -Parent) 'temp'
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
        [ValidateSet('pwsh','git','node','claude','codex','copilot','gh','glab','az')][string]$Tool,
        [ValidateSet('msi','zip')][string]$Method
    )
    $result = @{ Url=''; Hash=$null; Kind=$Method; Arguments=[string[]]@(); PathFolder='' }
    if ($Tool -in @('claude','codex')) {
        # Official bootstrap scripts verify their payloads (Claude manifest,
        # Codex release digest); neither vendor publishes a bootstrap hash.
        $result.Url = if ($Tool -eq 'claude') { 'https://claude.ai/install.ps1' } else { 'https://chatgpt.com/codex/install.ps1' }
        $result.Kind = 'script'
        return $result
    }
    if ($Tool -eq 'node') {
        $versions = Get-ToolSourceText -Url 'https://nodejs.org/dist/index.json' | ConvertFrom-Json
        $version = ($versions | Where-Object lts | Select-Object -First 1).version
        if ($version -notmatch '^v\d+\.\d+\.\d+$') { throw 'no Node LTS release found' }
        $name = if ($Method -eq 'zip') { "node-$version-win-x64.zip" } else { "node-$version-x64.msi" }
        $result.Url = "https://nodejs.org/dist/$version/$name"
        $checksums = Get-ToolSourceText -Url "https://nodejs.org/dist/$version/SHASUMS256.txt"
        $result.Hash = Get-ToolChecksum -Text $checksums -Name $name
        if ($Method -eq 'zip') { $result.PathFolder = "node-$version-win-x64" }
    } elseif ($Tool -eq 'glab') {
        $release = Get-ToolSourceText -Url 'https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases/permalink/latest' | ConvertFrom-Json
        $pattern = if ($Method -eq 'zip') { '^glab_[\d.]+_windows_amd64\.zip$' } else { '^glab_[\d.]+_Windows_x86_64_installer\.exe$' }
        $asset = $release.assets.links | Where-Object name -Match $pattern | Select-Object -First 1
        $checksumAsset = $release.assets.links | Where-Object name -EQ 'checksums.txt' | Select-Object -First 1
        if (-not $asset -or -not $checksumAsset) { throw "no official $Tool $Method release asset found" }
        $result.Url = $asset.url
        $checksums = Get-ToolSourceText -Url $checksumAsset.url
        $result.Hash = Get-ToolChecksum -Text $checksums -Name $asset.name
        if ($Method -eq 'zip') { $result.PathFolder = 'bin' }
        else { $result.Kind = 'exe'; $result.Arguments = [string[]]@('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-') }
    } else {
        $repo = @{ pwsh='PowerShell/PowerShell'; git='git-for-windows/git'; gh='cli/cli'; az='Azure/azure-cli'; copilot='github/copilot-cli' }[$Tool]
        $base = "https://api.github.com/repos/$repo/releases"
        $release = Get-ToolSourceText -Url "$base/latest" | ConvertFrom-Json
        if ($Tool -eq 'pwsh' -and $Method -eq 'msi') {
            # 7.7 publishes MSIX/ZIP only; the MSI method uses the newest 7.6 LTS.
            $page = 1
            do {
                $releases = @(Get-ToolSourceText -Url "${base}?per_page=100&page=$page" | ConvertFrom-Json)
                $release = $releases | Where-Object { -not $_.prerelease -and -not $_.draft -and $_.tag_name -match '^v7\.6\.\d+$' -and ($_.assets.name -match '-win-x64\.msi$') } |
                    Sort-Object { [version]($_.tag_name -replace '^v','') } -Descending | Select-Object -First 1
                $page++
            } while (-not $release -and $releases.Count -eq 100)
        }
        $pattern = switch ($Tool) {
            pwsh { "^PowerShell-[\d.]+-win-x64\.$Method`$" }
            git { if ($Method -eq 'zip') { '^MinGit-[\d.]+-64-bit\.zip$' } else { '^Git-[\d.]+-64-bit\.exe$' } }
            gh { "^gh_[\d.]+_windows_amd64\.$Method`$" }
            az { "^azure-cli-[\d.]+-x64\.$Method`$" }
            copilot { if ($Method -eq 'zip') { '^copilot-win32-x64\.zip$' } else { '^copilot-x64\.msi$' } }
        }
        $asset = $release.assets | Where-Object name -Match $pattern | Select-Object -First 1
        if (-not $asset) { throw "no official $Tool $Method release asset found" }
        if ($asset.digest -notmatch '^sha256:([a-fA-F0-9]{64})$') { throw "no SHA-256 digest for $($asset.name)" }
        $result.Url = $asset.browser_download_url
        $result.Hash = $Matches[1].ToLowerInvariant()
        if ($Method -eq 'zip') {
            $result.PathFolder = @{ pwsh=''; git='cmd'; gh='bin'; az='bin'; copilot='' }[$Tool]
        } elseif ($Tool -eq 'git') {
            $result.Kind = 'exe'
            $result.Arguments = [string[]]@('/VERYSILENT','/NORESTART','/SP-','/CURRENTUSER')
        }
    }
    if ($result.Kind -eq 'msi') {
        $result.Arguments = [string[]]@('/qn','/norestart')
        if ($Tool -eq 'pwsh') { $result.Arguments += 'ADD_PATH=1' }
    }
    return $result
}

function Test-DownloadHash {
    param([string]$Path, [string]$Expected)
    if ($Expected -notmatch '^[a-fA-F0-9]{64}$') { return $false }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash -ieq $Expected
}

function Get-UserPath {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
    try {
        if ($key) { [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) }
    } finally { if ($key) { $key.Dispose() } }
}
function Set-UserPath {
    param([string]$Path)
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
    try {
        $kind = if ($key.GetValueNames() -icontains 'Path') { $key.GetValueKind('Path') } else { [Microsoft.Win32.RegistryValueKind]::ExpandString }
        $key.SetValue('Path', $Path, $kind)
    } finally { $key.Dispose() }
    # Notify Explorer so future terminals receive the changed persistent environment.
    if (-not ('PsAi.InstallEnvironment' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace PsAi {
    public static class InstallEnvironment {
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern IntPtr SendMessageTimeout(IntPtr window, uint message,
            UIntPtr parameter, string value, uint flags, uint timeout, out UIntPtr result);
    }
}
'@
    }
    $result = [uintptr]::Zero
    [PsAi.InstallEnvironment]::SendMessageTimeout([intptr]0xffff, 0x1a, [uintptr]::Zero, 'Environment', 2, 5000, [ref]$result) | Out-Null
}

function Get-ToolPortableCommand {
    param([string]$Tool)
    $root = Get-ToolInstallRoot -Tool $Tool
    $relative = switch ($Tool) {
        git { 'cmd/git.exe' }
        gh { 'bin/gh.exe' }
        glab { 'bin/glab.exe' }
        az { 'bin/az.cmd' }
        node {
            if (Test-Path -LiteralPath $root) {
                $entry = Get-ChildItem -LiteralPath $root -Directory -Filter 'node-v*-win-x64' | Sort-Object Name -Descending | Select-Object -First 1
                if ($entry) { Join-Path $entry.Name 'node.exe' }
            }
        }
        default { "$Tool.exe" }
    }
    if ($relative) { Join-Path $root $relative }
}

function Install-ToolZip {
    param(
        [ValidateSet('pwsh','git','node','claude','codex','copilot','gh','glab','az')][string]$Tool,
        [string]$Archive,
        [AllowEmptyString()][string]$PathFolder
    )
    $root = [IO.Path]::GetFullPath((Get-ToolInstallRoot -Tool $Tool))
    $folder = [IO.Path]::GetFullPath((Join-Path $root $PathFolder))
    if ($folder -ne $root -and -not $folder.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'PathFolder must be inside the tool folder' }
    $command = Get-ToolPortableCommand -Tool $Tool
    if (-not $command -or -not (Test-Path -LiteralPath $command -PathType Leaf)) {
        Expand-Archive -LiteralPath $Archive -DestinationPath $root -Force -ErrorAction Stop
    }
    $command = Get-ToolPortableCommand -Tool $Tool
    if (-not $command -or -not (Test-Path -LiteralPath $command -PathType Leaf)) { throw "$Tool executable missing from download" }
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) { throw "executable folder missing for $Tool download" }
    $userPath = Get-UserPath
    $entries = @($userPath -split ';' | ForEach-Object { [Environment]::ExpandEnvironmentVariables($_.Trim().Trim('"')).TrimEnd('\','/') })
    if ($entries -inotcontains $folder.TrimEnd('\','/')) {
        $updated = if ([string]::IsNullOrEmpty($userPath)) { $folder } else { $userPath.TrimEnd(';') + ';' + $folder }
        Set-UserPath -Path $updated
    }
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
        [ValidateSet('pwsh','git','node','claude','codex','copilot','gh','glab','az')][string]$Tool,
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
        if ($Tool -eq 'copilot' -and (Test-ToolCommandAvailable -Name node)) {
            'copilot: npm install -g @github/copilot'
            if ($Yes) {
                $code = Invoke-ToolCommand -Command @('npm','install','-g','@github/copilot')
                if ($code -ne 0) { throw "$Tool installation command exited $code" }
            }
            return
        }
        if ($Method -in @('msi','zip')) {
            $downloadMethod = $Method
            if ($Tool -in @('claude','codex')) {
                $scriptUrl = if ($Tool -eq 'claude') { 'https://claude.ai/install.ps1' } else { 'https://chatgpt.com/codex/install.ps1' }
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
            } catch { # A blocked or broken winget executable needs the same method choice.
            }
        }
        'winget is not available; choose -Method msi (official installer, needs admin) or -Method zip (user folder, no admin)'
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
