$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$scriptPath = Join-Path $root 'plugins/legion/bin/legion-install-tool.ps1'
$installer = Join-Path $root 'plugins/legion/install.ps1'
. $scriptPath -NoRun
Assert-Equal 'bun|--version' ((Get-ToolInstallData -Tool bun).check -join '|') 'Bun installed check'
& {
    $bunState = @{Bun=$false;Calls=0}
    function Test-ToolInstalled { param($Tool) @{Installed=$(if ($Tool -eq 'bun') { $bunState.Bun } else { throw 'Unexpected prerequisite' });Version='fixture'} }
    function Invoke-ToolCommand { param($Command) $bunState.Calls++; $bunState.Bun=$true; 0 }
    function Test-ToolCommandAvailable { param($Name) $true }
    function Get-ToolInstallRoot { throw 'No installer filesystem writes' }
    function Save-ToolDownload { throw 'No downloads in Unix helper test' }
    Invoke-ToolInstall -Tool bun -Platform linux | Out-Null
    Assert-Equal 0 $bunState.Calls 'Preview and decline execute nothing'
    Invoke-ToolInstall -Tool bun -Platform linux -Yes | Out-Null
    Assert-Equal 1 $bunState.Calls 'Approved Bun executes once'
    Invoke-ToolInstall -Tool bun -Platform linux -Yes | Out-Null
    Assert-Equal 1 $bunState.Calls 'Installed Bun skips repeat'
}

# Exercise the process exit contract without contacting a server or starting winget.
$choiceMessage = 'choose -Method msi (official installer, needs admin) or -Method zip (user folder, no admin)'
foreach ($wingetState in @('missing','error','blocked','ok')) {
    $result = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'fixtures/install/Invoke-Installer.ps1') -Installer $scriptPath -Winget $wingetState 2>&1
    $expectedExit = if ($wingetState -eq 'ok') { 0 } else { 2 }
    Assert-Equal $expectedExit $LASTEXITCODE "winget $wingetState process exit"
    if ($expectedExit -eq 2) { Assert-True (($result -join "`n").Contains($choiceMessage)) "winget $wingetState presents both methods" }
}
$result = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'fixtures/install/Invoke-Installer.ps1') -Installer $scriptPath -Winget missing -Preview 2>&1
Assert-Equal 2 $LASTEXITCODE 'Missing winget preview also requests explicit method'
Assert-True (($result -join "`n").Contains($choiceMessage)) 'Missing winget preview presents both methods'
foreach ($tool in @('claude','codex')) {
    $result = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'fixtures/install/Invoke-Installer.ps1') -Installer $scriptPath -Winget missing -Tool $tool -Method winget 2>&1
    Assert-Equal 2 $LASTEXITCODE "$tool explicit winget never switches to remote script"
    Assert-True (($result -join "`n").Contains($choiceMessage)) "$tool explicit winget presents fallback choices"
}

$expected = @{
    windows = @{ git='winget install --id Git.Git -e'; node='winget install --id OpenJS.NodeJS.LTS -e'; claude='winget install --id Anthropic.ClaudeCode -e'; codex='winget install --id OpenAI.Codex -e'; copilot='winget install --id GitHub.Copilot -e'; az='winget install --id Microsoft.AzureCLI -e' }
    macos = @{ git='brew install git'; node='brew install node'; claude='bash -c curl -fsSL https://claude.ai/install.sh | bash'; codex='npm install -g @openai/codex'; copilot='npm install -g @github/copilot'; az='brew install azure-cli' }
}
foreach ($platform in @('windows','macos')) {
    foreach ($tool in $expected[$platform].Keys) {
        $recipe = Get-ToolRecipe -Tool $tool -Platform $platform
        $expectedCommand = $expected[$platform][$tool]
        if ($platform -eq 'windows') { $expectedCommand += ' --source winget --accept-source-agreements --accept-package-agreements' }
        Assert-Equal $expectedCommand ($recipe.Install[0] -join ' ') "$platform $tool recipe"
    }
}
$linuxDocs = @{ git='https://git-scm.com/download/linux'; node='https://nodejs.org/en/download'; az='https://learn.microsoft.com/cli/azure/install-azure-cli-linux' }
foreach ($tool in $linuxDocs.Keys) {
    $recipe = Get-ToolRecipe -Tool $tool -Platform linux
    Assert-Equal 0 $recipe.Install.Count "Linux $tool is docs only"
    Assert-Equal $linuxDocs[$tool] $recipe.Docs "Linux $tool docs"
}
Assert-Equal '' ((Get-ToolRecipe -Tool codex -Platform windows).Needs -join ',') 'Native Windows Codex does not need Node'
Assert-Equal 'node' ((Get-ToolRecipe -Tool copilot -Platform linux).Needs -join ',') 'Linux Copilot needs Node'

# All command execution and installed state are replaced; no install command can reach the machine.
$script:installed = @{}
$script:commands = [System.Collections.Generic.List[string]]::new()
function Test-ToolInstalled { param([string]$Tool) return @{ Installed=[bool]$script:installed[$Tool]; Version='1.2.3' } }
function Test-ToolCommandAvailable { param([string]$Name) return $true }
function Invoke-ToolCommand {
    param([string[]]$Command)
    $script:commands.Add(($Command -join ' '))
    if ($Command -contains '@openai/codex') { $script:installed['codex'] = $true }
    if (($Command -join ' ') -match 'codex.*install.ps1') { $script:installed['codex'] = $true }
    if ($Command -contains 'OpenJS.NodeJS.LTS') { $script:installed['node'] = $true }
    return 0
}
$preview = @(Invoke-ToolInstall -Tool codex -Platform linux)
Assert-Equal 0 $script:commands.Count 'Preview executes nothing'
Assert-True (($preview -join "`n") -match 'node') 'Preview names prerequisite'
Assert-True (($preview -join "`n") -match 'npm install -g @openai/codex') 'Preview names exact command'
$script:installed['node'] = $true
Invoke-ToolInstall -Tool codex -Platform macos -Yes | Out-Null
Assert-Equal 1 $script:commands.Count 'CLI command runs with Node available'
Assert-True ($script:commands[0] -match '@openai/codex') 'macOS Codex uses npm'
$second = @(Invoke-ToolInstall -Tool codex -Platform windows -Yes)
Assert-Equal 1 $script:commands.Count 'Second run executes nothing'
Assert-True (($second -join "`n") -match 'skip: codex already installed') 'Second run skips installed tool'
$script:commands.Clear()
$docs = @(Invoke-ToolInstall -Tool git -Platform linux -Yes)
Assert-Equal 0 $script:commands.Count 'Docs only executes nothing'
Assert-True (($docs -join "`n") -match 'https://git-scm.com/download/linux') 'Docs only prints link'
$script:installed.Remove('node') | Out-Null
$script:installed.Remove('codex') | Out-Null
Assert-Throws { Invoke-ToolInstall -Tool codex -Platform linux -Yes | Out-Null } 'Missing docs-only Node blocks Codex install'
Assert-Equal 0 $script:commands.Count 'Missing prerequisite runs no npm command'

# The standalone installer also runs in Windows PowerShell 5.1.
& (Join-Path $PSScriptRoot 'fixtures/install/Test-RemoteInstaller.ps1') -Installer $installer -Repo $root

$readme = Get-Content -Raw (Join-Path $root 'README.md')
$windowsExample = [regex]::Match($readme, '(?s)```powershell\r?\n(.*?)\r?\n```')
Assert-True $windowsExample.Success 'README includes a Windows PowerShell installer example'
& {
    $fixtureInstallerScope = 'caller'
    function Invoke-RestMethod {
        param([string]$Uri)
        Assert-Equal 'https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1' $Uri 'README downloads the remote installer'
        '$fixtureInstallerScope = "installer"; "fixture-installer-ran"'
    }
    $result = . ([scriptblock]::Create($windowsExample.Groups[1].Value))
    Assert-Equal 'fixture-installer-ran' $result 'README invocation executes the downloaded installer'
    Assert-Equal 'caller' $fixtureInstallerScope 'README installer invocation isolates caller variables'
}

# Local archives and official-shaped metadata; no network, installers, or real PATH writes.
& {
    . $scriptPath -NoRun
    $realDownloadResolver = ${function:Get-ToolDownload}
    $realInstalledCheck = ${function:Test-ToolInstalled}
    $sandbox = Join-Path $root ('.agents/temp/restructure/install-tests-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
    $originalProcessPath = $env:PATH
    $sources = Get-Content (Join-Path $PSScriptRoot 'fixtures/install/sources.json') -Raw | ConvertFrom-Json -AsHashtable
    $testHash = '1' * 64
    $requests = [Collections.Generic.List[string]]::new()
    $downloadedFiles = [Collections.Generic.List[string]]::new()
    $commands = [Collections.Generic.List[object]]::new()
    $userPathState = @{ Value='%SYSTEMROOT%\existing' }
    $pathWrites = [Collections.Generic.List[string]]::new()
    $available = @{}
    $installed = @{}
    function Get-ToolInstallRoot { param($Tool) Join-Path $sandbox "tools/$Tool" }
    function New-ToolDownloadPath {
        param($Extension='txt')
        $temp = Join-Path $sandbox 'temp'
        New-Item -ItemType Directory $temp -Force | Out-Null
        Join-Path $temp ("install-$([guid]::NewGuid().ToString('N')).$Extension")
    }
    function Get-UserPath { $userPathState.Value }
    function Set-UserPath { param($Path) $pathWrites.Add($Path); $userPathState.Value = $Path }
    function Test-ToolCommandAvailable { param($Name) [bool]$available[$Name] }
    function Test-ToolInstalled { param($Tool) @{ Installed=[bool]$installed[$Tool]; Version='test-version' } }
    $commandState = @{ Exit=0 }
    function Invoke-ToolCommand { param($Command) $commands.Add($Command); $global:LASTEXITCODE = $commandState.Exit; $commandState.Exit }
    function Invoke-ToolDownload {
        param($Url, $OutFile)
        $requests.Add($Url)
        $downloadedFiles.Add($OutFile)
        if ($sources.ContainsKey($Url)) { $sources[$Url] | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutFile }
        elseif ($Url -like '*SHASUMS256.txt') { "$testHash  node-v28.1.0-x64.msi`n$testHash  node-v28.1.0-win-x64.zip" | Set-Content -LiteralPath $OutFile }
        elseif ($Url -like '*install.ps1') { '# inert test installer' | Set-Content -LiteralPath $OutFile }
        elseif ($Url -eq 'https://fixture.test/az.zip') { Copy-Item -LiteralPath $archive -Destination $OutFile }
        else { throw "unexpected test download: $Url" }
    }
    try {
        $folders = @{ git='cmd'; node='node-v28.1.0-win-x64'; az='bin'; copilot='' }
        foreach ($tool in $folders.Keys) {
            foreach ($method in @('msi','zip')) {
                $download = Get-ToolDownload -Tool $tool -Method $method
                Assert-Equal $testHash $download.Hash "$tool $method vendor hash"
                Assert-True ($download.Url.StartsWith('https://')) "$tool $method official HTTPS URL"
                if ($method -eq 'zip') {
                    Assert-Equal 'zip' $download.Kind "$tool archive kind"
                    Assert-Equal $folders[$tool] $download.PathFolder "$tool executable folder"
                } elseif ($tool -in @('git')) {
                    Assert-Equal 'exe' $download.Kind "$tool installer kind"
                    Assert-True ($download.Arguments -contains '/VERYSILENT') "$tool silent installer"
                    if ($tool -eq 'git') { Assert-True ($download.Arguments -contains '/CURRENTUSER') 'Git installs for current user' }
                } else {
                    Assert-Equal 'msi' $download.Kind "$tool MSI kind"
                    Assert-True ($download.Arguments -contains '/qn') "$tool silent MSI"
                }
                if ($tool -eq 'node') { Assert-True ($download.Url.Contains('v28.1.0')) 'Node selects latest LTS' }
            }
        }
        foreach ($tool in @('claude','codex')) {
            foreach ($method in @('msi','zip')) {
                $download = Get-ToolDownload -Tool $tool -Method $method
                Assert-Equal 'script' $download.Kind "$tool $method delegates to official installer"
                Assert-True ($download.Url.EndsWith('/install.ps1')) "$tool script URL"
            }
        }
        $azAsset = $sources['https://api.github.com/repos/Azure/azure-cli/releases/latest'].assets[0]
        $azAsset.digest = ''
        Assert-Throws { Get-ToolDownload -Tool az -Method zip } 'Missing vendor digest blocks download'
        $azAsset.digest = 'sha256:' + $testHash
        $requests.Clear()
        Invoke-ToolInstall -Tool az -Platform windows -Method zip | Out-Null
        Assert-Equal 0 $requests.Count 'Explicit method preview has no network'
        Assert-Equal 0 $commands.Count 'Explicit method preview executes nothing'
        Assert-Throws { Invoke-ToolInstall -Tool az -Platform linux -Method zip -Yes } 'Method is Windows only'

        $archiveSource = Join-Path $sandbox 'archive/bin'
        New-Item -ItemType Directory -Path $archiveSource -Force | Out-Null
        'inert fixture, never execute' | Set-Content -LiteralPath (Join-Path $archiveSource 'az.cmd')
        $archive = Join-Path $sandbox 'az.zip'
        Compress-Archive -Path (Join-Path $sandbox 'archive/*') -DestinationPath $archive
        $goodHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
        Assert-True (Test-DownloadHash -Path $archive -Expected $goodHash.ToLowerInvariant()) 'SHA-256 comparison accepts hex case'
        Assert-True (-not (Test-DownloadHash -Path $archive -Expected ('0' * 64))) 'SHA-256 comparison rejects mismatch'
        function Get-ToolDownload { param($Tool,$Method) @{ Url='https://fixture.test/az.zip'; Hash=$goodHash; Kind='zip'; Arguments=@(); PathFolder='bin' } }
        Invoke-ToolInstall -Tool az -Platform windows -Method zip -Yes | Out-Null
        $exe = Join-Path $sandbox 'tools/az/bin/az.cmd'
        Assert-True (Test-Path -LiteralPath $exe) 'Verified archive is extracted to user tool folder'
        $exeTime = (Get-Item -LiteralPath $exe).LastWriteTimeUtc
        $requestCount = $requests.Count
        $second = @(Invoke-ToolInstall -Tool az -Platform windows -Method zip -Yes)
        Assert-Equal $requestCount $requests.Count 'Repeat portable install performs no downloads'
        Assert-Equal $exeTime (Get-Item -LiteralPath $exe).LastWriteTimeUtc 'Repeat portable install writes nothing'
        Assert-True (($second -join "`n").Contains('skip: az already installed (')) 'Repeat portable install reports skip'
        Install-ToolZip -Tool az -Archive $archive -PathFolder bin | Out-Null
        Assert-Equal 1 $pathWrites.Count 'Portable folder is added to user PATH only once'
        Assert-True ($userPathState.Value.Contains((Split-Path $exe -Parent))) 'PATH points at executable folder'
        Assert-True ($userPathState.Value.StartsWith('%SYSTEMROOT%\existing')) 'Existing user PATH placeholders preserved'
        Assert-Equal $originalProcessPath $env:PATH 'Installer does not mutate process PATH'
        $userPathState.Value = 'C:\existing'
        Invoke-ToolInstall -Tool az -Platform windows -Method zip | Out-Null
        Assert-Equal 1 $pathWrites.Count 'Portable preview never repairs PATH without Yes'
        Invoke-ToolInstall -Tool az -Platform windows -Method zip -Yes | Out-Null
        Assert-Equal 2 $pathWrites.Count 'Retry repairs a missing portable user PATH entry'
        Assert-Equal $requestCount $requests.Count 'PATH repair does not download again'
        Assert-Equal $exeTime (Get-Item -LiteralPath $exe).LastWriteTimeUtc 'PATH repair preserves installed files'
        $savedTestRoot = $env:LEGION_INSTALL_TEST_ROOT
        try {
            $env:LEGION_INSTALL_TEST_ROOT = $sandbox
            $separator = [IO.Path]::DirectorySeparatorChar
            $userPathState.Value = "%LEGION_INSTALL_TEST_ROOT%${separator}tools${separator}az${separator}bin${separator}"
            Install-ToolZip -Tool az -Archive $archive -PathFolder bin | Out-Null
            Assert-Equal 2 $pathWrites.Count 'Expanded equivalent PATH entry is not duplicated'
        } finally { $env:LEGION_INSTALL_TEST_ROOT = $savedTestRoot }

        $installed['az'] = $true
        $requests.Clear()
        $skip = @(Invoke-ToolInstall -Tool az -Platform windows -Method msi -Yes)
        Assert-True (($skip -join "`n").Contains('skip: az already installed (test-version)')) 'Installed tool skips with version'
        Assert-Equal 0 $requests.Count 'Installed tool does not resolve downloads'
        $installed.Remove('az')
        # Move only the harmless local fixture, so the next attempt reaches download verification.
        Move-Item -LiteralPath (Join-Path $sandbox 'tools/az') -Destination (Join-Path $sandbox 'saved-az')
        $goodHash = '0' * 64
        $errorText = ''
        try { Invoke-ToolInstall -Tool az -Platform windows -Method zip -Yes | Out-Null } catch { $errorText = $_.Exception.Message }
        Assert-Equal 'hash mismatch for az download' $errorText 'Hash mismatch has exact error'
        Assert-True (-not (Test-Path -LiteralPath $downloadedFiles[$downloadedFiles.Count - 1])) 'Hash mismatch deletes download'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $sandbox 'tools/az'))) 'Hash mismatch never extracts archive'
        Assert-Equal 0 $commands.Count 'Zip and hash mismatch never start commands'
        $badSource = Join-Path $sandbox 'bad/bin'
        New-Item -ItemType Directory -Path $badSource -Force | Out-Null
        'no executable' | Set-Content -LiteralPath (Join-Path $badSource 'readme.txt')
        $badArchive = Join-Path $sandbox 'bad.zip'
        Compress-Archive -Path (Join-Path $sandbox 'bad/*') -DestinationPath $badArchive
        $writesBeforeBadZip = $pathWrites.Count
        Assert-Throws { Install-ToolZip -Tool az -Archive $badArchive -PathFolder bin } 'Missing executable blocks portable installation'
        Assert-Equal $writesBeforeBadZip $pathWrites.Count 'Invalid ZIP never updates PATH'

        foreach ($kind in @('msi','exe')) {
            function Get-ToolDownload {
                param($Tool,$Method)
                @{ Url='https://fixture.test/az.zip'; Hash=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash; Kind=$kind; Arguments=@('/qn','/norestart'); PathFolder='' }
            }
            Invoke-ToolInstall -Tool az -Platform windows -Method msi -Yes | Out-Null
            $command = $commands[$commands.Count - 1]
            if ($kind -eq 'msi') {
                Assert-Equal 'msiexec.exe' $command[0] 'MSI uses msiexec'
                Assert-Equal '/i' $command[1] 'MSI passes install operation'
            } else { Assert-True ($command[0].EndsWith('.exe')) 'EXE runs verified downloaded path' }
            Assert-True ($command -contains '/qn') "$kind passes silent arguments"
            $commandState.Exit = 3010
            Invoke-ToolInstall -Tool az -Platform windows -Method msi -Yes | Out-Null
            Assert-Equal 0 $LASTEXITCODE "$kind reboot-success code normalized for CLI"
            $commandState.Exit = 5
            Assert-Throws { Invoke-ToolInstall -Tool az -Platform windows -Method msi -Yes } "$kind propagates installer failure"
            $commandState.Exit = 0
            Assert-True (-not (Test-Path -LiteralPath $downloadedFiles[$downloadedFiles.Count - 1])) "$kind failure deletes download"
        }
        $commands.Clear()

        # Restore only the resolver; all external side effects stay replaced.
        Set-Item Function:Get-ToolDownload $realDownloadResolver
        function Test-ToolInstalled { param($Tool) @{ Installed=$false; Version='' } }
        $available['node'] = $true
        foreach ($method in @('msi','zip')) { Invoke-ToolInstall -Tool copilot -Platform windows -Method $method -Yes | Out-Null }
        Assert-Equal 2 $commands.Count 'Copilot uses npm for either explicit method with Node'
        Assert-True (($commands[0] -join ' ').Contains('npm install -g @github/copilot')) 'Copilot prefers npm'
        $commands.Clear()
        foreach ($tool in @('claude','codex')) {
            foreach ($method in @('msi','zip')) { Invoke-ToolInstall -Tool $tool -Platform windows -Method $method -Yes | Out-Null }
        }
        Assert-Equal 4 $commands.Count 'Claude and Codex invoke official scripts for both methods'
        Assert-True (($commands[0] -join ' ').Contains('-File')) 'Vendor script runs through pwsh'
        Assert-True (-not (($commands | ForEach-Object { $_ -join ' ' }) -join "`n").Contains('winget')) 'Explicit methods do not invoke winget'
        # The persisted user PATH exists only on Windows.
        if ($IsWindows) {
            Set-Item Function:Test-ToolInstalled $realInstalledCheck
            function Test-ToolCommandAvailable { param($Name) $false }
            function Get-UserPath { Join-Path $PSScriptRoot 'fixtures/install/path-only' }
            $state = Test-ToolInstalled -Tool az
            Assert-True $state.Installed 'Installed tool is found on persisted PATH before shell refresh'
            Assert-Equal 'persisted PATH' $state.Version 'Persisted-only tool is recognized without execution'
        }
    } finally {
        # The absolute target is checked before recursive cleanup.
        $resolved = [IO.Path]::GetFullPath($sandbox)
        $expectedParent = [IO.Path]::GetFullPath((Join-Path $root '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not $resolved.StartsWith($expectedParent, [StringComparison]::OrdinalIgnoreCase)) { throw 'unsafe test cleanup path' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

# SyntheticRecipeAndPortableGlob: a skill folder is sufficient for installation.
& {
    $ErrorActionPreference = 'Stop'
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $scratch = [IO.Path]::GetFullPath((Join-Path $repoRoot '.agents/temp/restructure'))
    $sandbox = Join-Path $scratch ('recipe-' + [guid]::NewGuid().ToString('N'))
    $plugin = Join-Path $sandbox 'plugin'
    $savedPath = $env:PATH
    try {
        New-Item -ItemType Directory $sandbox -Force | Out-Null
        Copy-Item (Join-Path $repoRoot 'plugins/legion') $plugin -Recurse
        $fourthSkill = Join-Path $plugin 'skills/legion-fourth'
        Copy-Item (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth') $fourthSkill -Recurse
        $descriptorPath = Join-Path $fourthSkill 'tool.json'
        $data = Get-Content $descriptorPath -Raw | ConvertFrom-Json
        $data.install.check = @('fourth-cli','--probe','space value')
        $data.install.macos.needs = @('node')
        $data.install.macos.commands = @(,([string[]]@('fixture-manager','setup','space value')))
        $data | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
        . (Join-Path $plugin 'bin/legion-install-tool.ps1') -NoRun
        function Get-ToolInstallRoot { param($Tool) Join-Path $sandbox "home[1]/tools/$Tool" }
        $recipe = Get-ToolRecipe -Tool fourth -Platform macos
        Assert-Equal 'node' ($recipe.Needs -join '|') 'Recipe needs come from platform data'
        Assert-Equal 'fixture-manager|setup|space value' ($recipe.Install[0] -join '|') 'Recipe commands retain array boundaries'
        Assert-Equal 'https://fixture.test/install' (Get-ToolRecipe -Tool fourth -Platform linux).Docs 'Recipe docs come from data'
        Assert-Equal 'winget|install|--id|Example.Fourth|-e|--source|winget|--accept-source-agreements|--accept-package-agreements' ((Get-ToolRecipe -Tool fourth -Platform windows).Install[0] -join '|') 'Recipe Windows id comes from data'
        $probeLog = Join-Path $sandbox 'probe.json'
        $fake = '@($args) | ConvertTo-Json | Set-Content -LiteralPath ''' + $probeLog.Replace("'","''") + '''; Write-Output "fixture-version"'
        $fake | Set-Content (Join-Path $fourthSkill 'fourth-cli.ps1')
        $env:PATH = @($fourthSkill,$PSHOME) -join [IO.Path]::PathSeparator
        $state = Test-ToolInstalled -Tool fourth
        Assert-True $state.Installed 'Declared executable is detected'
        Assert-Equal 'fixture-version' $state.Version 'Version comes from declared check'
        Assert-Equal '--probe|space value' ((Get-Content $probeLog -Raw | ConvertFrom-Json) -join '|') 'Installed detection executes declared check arguments'
        $calls = [Collections.Generic.List[string]]::new()
        function Test-ToolCommandAvailable { param($Name) $Name -eq 'winget' }
        function Invoke-ToolCommand { param($Command) $calls.Add(($Command -join '|')); 0 }
        function Invoke-ToolDownload { throw 'Preview must not download' }
        $env:PATH = $PSHOME
        $preview = @(Invoke-ToolInstall -Tool fourth -Platform windows)
        Assert-Equal 0 $calls.Count 'Preview executes no command'
        Assert-True (-not (Test-Path (Get-ToolInstallRoot fourth))) 'Preview writes no tool files'
        Assert-True (($preview -join '|').Contains('Example.Fourth')) 'Preview uses declared winget recipe'
        foreach ($version in @('fourth-v10','fourth-v2')) {
            $folder = Join-Path (Get-ToolInstallRoot fourth) $version
            New-Item -ItemType Directory $folder -Force | Out-Null
            [IO.File]::WriteAllText((Join-Path $folder 'fourth-cli.exe'), '')
        }
        $sibling = Join-Path $sandbox 'home1/tools/fourth/fourth-v9'
        New-Item -ItemType Directory $sibling -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $sibling 'fourth-cli.exe'), '')
        $expectedCommand = Join-Path (Get-ToolInstallRoot fourth) 'fourth-v10/fourth-cli.exe'
        Assert-Equal $expectedCommand (Get-ToolPortableCommand fourth) 'Portable glob compares numeric version components'
        $pathState = @{Value='existing'}
        $writes = [Collections.Generic.List[string]]::new()
        function Get-UserPath { $pathState.Value }
        function Set-UserPath { param($Path) $writes.Add($Path); $pathState.Value = $Path }
        $preview = @(Invoke-ToolInstall -Tool fourth -Platform windows)
        Assert-Equal 0 $writes.Count 'Portable preview does not repair PATH'
        Invoke-ToolInstall -Tool fourth -Platform windows -Yes | Out-Null
        Invoke-ToolInstall -Tool fourth -Platform windows -Yes | Out-Null
        Assert-Equal 1 $writes.Count 'Approved portable repair is idempotent'
        Assert-True ($pathState.Value.Contains((Split-Path $expectedCommand -Parent))) 'PATH points to discovered version folder'
        $extractions = [Collections.Generic.List[string]]::new()
        function Expand-Archive { param($LiteralPath,$DestinationPath,[switch]$Force,$ErrorAction) $extractions.Add($DestinationPath) }
        foreach ($badPath in @('../fourth-sibling/file.exe',(Join-Path $sandbox 'outside.exe'),'sub/../../fourth-sibling/file.exe')) {
            $data.install.windows.portableCommand = $badPath
            $data | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
            Assert-Throws { Get-ToolPortableCommand fourth } 'Unsafe portable path rejected'
        }
        # CompactSchemaKeepsRuntimeGuards: copied loaders fail before fake execution/extraction.
        $data.install.windows.portableCommand = 'fourth-v*/fourth-cli.exe'
        foreach ($change in @(
            { param($d) $d.plugin | Add-Member -NotePropertyName cacheDir -NotePropertyValue '../outside' -Force },
            { param($d) $d.overseerArgs = @('--flag',42) }
        )) {
            $bad = $data | ConvertTo-Json -Depth 100 | ConvertFrom-Json
            & $change $bad
            $bad | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
            Assert-Throws { Invoke-ToolInstall -Tool fourth -Platform windows -Yes } 'Unsafe descriptor stops before installation'
        }
        $data | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
        $adapter = Join-Path $fourthSkill 'scripts/foundry-launch.ps1'
        Move-Item -LiteralPath $adapter -Destination ($adapter + '.held')
        Assert-Throws { Invoke-ToolInstall -Tool fourth -Platform windows -Yes } 'Missing adapter stops before installation'
        Move-Item -LiteralPath ($adapter + '.held') -Destination $adapter
        Assert-Equal 0 $calls.Count 'Rejected descriptors execute no commands'
        $data | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
        foreach ($badPath in @('../fourth-sibling',(Join-Path $sandbox 'outside'),'sub/../../fourth-sibling')) {
            Assert-Throws { Install-ToolZip -Tool fourth -Archive unused.zip -PathFolder $badPath } 'Unsafe PATH folder rejected'
        }
        Assert-Equal 0 $extractions.Count 'Invalid paths never extract'
        Assert-Equal 1 $writes.Count 'Invalid paths never write PATH'
        $helpersPath = Join-Path $plugin 'bin/install-tool/helpers.json'
        $helpers = Get-Content $helpersPath -Raw | ConvertFrom-Json -AsHashtable
        $data.install.macos.needs = @('fourth')
        $data | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
        Assert-Throws { Get-ToolRecipe -Tool fourth -Platform macos } 'Self prerequisite is rejected before recursion'
        $data.install.macos.needs = @('node','missing-helper')
        $data | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
        $beforeCommands = $calls.Count
        Assert-Throws { Invoke-ToolInstall -Tool fourth -Platform macos -Yes } 'Unknown later prerequisite is rejected before any install'
        Assert-Equal $beforeCommands $calls.Count 'Invalid prerequisite list executes no earlier helper'
        $data.install.macos.needs = @('node')
        $data | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
        $helpers.node.macos.needs = @('git')
        $helpers.git.macos.needs = @('node')
        $helpers | ConvertTo-Json -Depth 100 | Set-Content $helpersPath
        Assert-Throws { Get-ToolRecipe -Tool fourth -Platform macos } 'Helper dependency cycle is rejected'
        $helpers.node.macos.needs = @()
        $helpers.git.macos.needs = @()
        $helpers.fourth = $helpers.az
        $helpers | ConvertTo-Json -Depth 100 | Set-Content $helpersPath
        Assert-Throws { Get-ToolRecipe -Tool fourth -Platform windows } 'Helper/agent id collision fails before installation'
    } finally {
        $env:PATH = $savedPath
        $cleanup = [IO.Path]::GetFullPath($sandbox)
        if (-not $cleanup.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar)) { throw 'Unsafe recipe fixture cleanup' }
        Remove-Item -LiteralPath $cleanup -Recurse -Force
    }
}

# SyntheticDownloads: source formats, never ids, select resolution.
& {
    $ErrorActionPreference = 'Stop'
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $scratch = [IO.Path]::GetFullPath((Join-Path $repoRoot '.agents/temp/restructure'))
    $sandbox = Join-Path $scratch ('downloads-' + [guid]::NewGuid().ToString('N'))
    $plugin = Join-Path $sandbox 'plugin'
    try {
        New-Item -ItemType Directory $sandbox -Force | Out-Null
        Copy-Item (Join-Path $repoRoot 'plugins/legion') $plugin -Recurse
        $fourthSkill = Join-Path $plugin 'skills/legion-fourth'
        Copy-Item (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth') $fourthSkill -Recurse
        $descriptorPath = Join-Path $fourthSkill 'tool.json'
        $data = Get-Content $descriptorPath -Raw | ConvertFrom-Json
        . (Join-Path $plugin 'bin/legion-install-tool.ps1') -NoRun
        $sources = Get-Content (Join-Path $PSScriptRoot 'fixtures/install/sources.json') -Raw | ConvertFrom-Json -AsHashtable
        $requests = [Collections.Generic.List[string]]::new()
        function Get-ToolSourceText {
            param($Url)
            $requests.Add($Url)
            if (-not $sources.ContainsKey($Url)) { throw "Unexpected metadata: $Url" }
            if ($sources[$Url] -is [string]) { return $sources[$Url] }
            return $sources[$Url] | ConvertTo-Json -Depth 30
        }
        $assetRecipe = $data.install.windows.download.zip
        $download = Get-ToolDownload -Tool fourth -Method zip
        Assert-Equal 'https://fixture.test/fourth.zip' $download.Url 'Fourth release-assets URL'
        Assert-Equal ('1' * 64) $download.Hash 'Fourth release-assets digest'
        foreach ($digest in @($null,'sha256:bad','sha512:' + ('1' * 64))) {
            $sources['https://fixture.test/releases/latest'].assets[0].digest = $digest
            Assert-Throws { Get-ToolDownload -Tool fourth -Method zip } 'Missing or malformed release digest stops resolution'
        }
        $sources['https://fixture.test/releases/latest'].assets[0].digest = 'sha256:' + ('1' * 64)
        $data.install.windows.download.zip = [pscustomobject]@{kind='zip';resolver='lts-index';metadataUrl='https://fixture.test/versions';assetName='fourth-{version}.zip';url='https://fixture.test/{version}/fourth-{version}.zip';checksumUrl='https://fixture.test/{version}/sums';verification='checksum-file';arguments=@();pathFolder='fourth-{version}'}
        $data | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
        $download = Get-ToolDownload -Tool fourth -Method zip
        Assert-Equal 'https://fixture.test/v42.3.1/fourth-v42.3.1.zip' $download.Url 'First LTS retains leading v in URL and filename'
        Assert-Equal 'fourth-v42.3.1' $download.PathFolder 'First LTS retains leading v in PATH folder'
        Assert-True ($requests -contains 'https://fixture.test/v42.3.1/sums') 'Checksum URL retains leading v'
        Assert-Equal ('3' * 64) $download.Hash 'LTS checksum filename uses the same version'
        $sources['https://fixture.test/v42.3.1/sums'] = ('3' * 64) + '  other.zip'
        Assert-Throws { Get-ToolDownload -Tool fourth -Method zip } 'Checksum for another filename stops LTS resolution'
        $sources['https://fixture.test/versions'] = '[{"version":"v99.0.0","lts":false}]'
        $message = ''
        try { Get-ToolDownload -Tool fourth -Method zip | Out-Null } catch { $message=$_.Exception.Message }
        Assert-Equal 'no fourth LTS release found' $message 'LTS failure names the requested tool'
        $data.install.windows.download.zip = [pscustomobject]@{kind='script';url='https://fixture.test/install.ps1';verification='vendor'}
        $data | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
        $download = Get-ToolDownload -Tool fourth -Method zip
        Assert-Equal $null $download.Hash 'Vendor script alone has no hash'
        Assert-Equal 'script' $download.Kind 'Vendor script selection is format-based'
        $commands = [Collections.Generic.List[object]]::new()
        $files = [Collections.Generic.List[string]]::new()
        function New-ToolDownloadPath { param($Extension='txt') $path = Join-Path $sandbox ('download.' + $Extension); $files.Add($path); $path }
        function Invoke-ToolDownload { param($Url,$OutFile) '# inert vendor script' | Set-Content $OutFile }
        function Invoke-ToolCommand { param($Command) $commands.Add($Command); 0 }
        function Install-ToolZip { throw 'Vendor script must bypass extraction' }
        function Set-UserPath { throw 'Vendor script must bypass PATH writes' }
        Invoke-ToolDownloadInstall -Tool fourth -Method zip | Out-Null
        Assert-Equal 1 $commands.Count 'Vendor script is executed once through existing consent executor'
        Assert-True ($commands[0] -contains '-File') 'Vendor script runs as a script'
        Assert-True (-not (Test-Path $files[-1])) 'Vendor script download is removed'
        $data.install.windows.download.zip = $assetRecipe
        $data | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
        Assert-Throws { Invoke-ToolDownloadInstall -Tool fourth -Method zip } 'Mismatched payload hash stops before extraction'
        Assert-True (-not (Test-Path $files[-1])) 'Mismatched download is removed'
    } finally {
        $cleanup = [IO.Path]::GetFullPath($sandbox)
        if (-not $cleanup.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar)) { throw 'Unsafe download fixture cleanup' }
        Remove-Item -LiteralPath $cleanup -Recurse -Force
    }
}
