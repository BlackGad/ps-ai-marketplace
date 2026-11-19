$root = Split-Path $PSScriptRoot -Parent
$scriptPath = Join-Path $root 'plugins/ps-ai/bin/ps-ai-install-tool.ps1'
$bootstrap = Join-Path $root 'install.ps1'
. $scriptPath -NoRun

# Exercise the real entry point using the already running PowerShell, without installing.
$entryPreview = & pwsh -NoProfile -File $scriptPath -Tool pwsh 2>&1
Assert-Equal 0 $LASTEXITCODE 'Real CLI allows omitted Method'
Assert-True (($entryPreview -join "`n").Contains('pwsh: installed')) 'Real CLI preview checks installed tool'

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
    windows = @{ pwsh='winget install --id Microsoft.PowerShell -e'; git='winget install --id Git.Git -e'; node='winget install --id OpenJS.NodeJS.LTS -e'; claude='winget install --id Anthropic.ClaudeCode -e'; codex='winget install --id OpenAI.Codex -e'; copilot='winget install --id GitHub.Copilot -e'; gh='winget install --id GitHub.cli -e'; glab='winget install --id GLab.GLab -e'; az='winget install --id Microsoft.AzureCLI -e' }
    macos = @{ pwsh='brew install --cask powershell'; git='brew install git'; node='brew install node'; claude='bash -c curl -fsSL https://claude.ai/install.sh | bash'; codex='npm install -g @openai/codex'; copilot='npm install -g @github/copilot'; gh='brew install gh'; glab='brew install glab'; az='brew install azure-cli' }
}
foreach ($platform in @('windows','macos')) {
    foreach ($tool in $expected[$platform].Keys) {
        $recipe = Get-ToolRecipe -Tool $tool -Platform $platform
        Assert-Equal $expected[$platform][$tool] ($recipe.Install[0] -join ' ') "$platform $tool recipe"
        Assert-True ($recipe.Check.Count -gt 0) "$platform $tool check"
    }
}
$linuxDocs = @{ pwsh='https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux'; git='https://git-scm.com/download/linux'; node='https://nodejs.org/en/download'; gh='https://github.com/cli/cli/blob/trunk/docs/install_linux.md'; glab='https://gitlab.com/gitlab-org/cli#installation'; az='https://learn.microsoft.com/cli/azure/install-azure-cli-linux' }
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
$first = @(Invoke-ToolInstall -Tool codex -Platform macos -Yes)
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

# Root installer bootstrap cases replace the old bootstrap and shell entry points.
& (Join-Path $PSScriptRoot 'fixtures/install/Test-RemoteInstaller.ps1') -Installer $bootstrap -Repo $root

foreach ($tool in @('claude','codex','copilot')) {
    $folder = Join-Path $root "plugins/ps-ai/skills/ps-ai-$tool"
    $main = Get-Content -Raw (Join-Path $folder 'SKILL.md')
    Assert-True ($main.Contains('references/install.md')) "$tool skill routes missing CLI to install reference"
    $installReference = Join-Path $folder 'references/install.md'
    Assert-True (Test-Path $installReference) "$tool install reference exists"
    $reference = Get-Content -Raw $installReference
    Assert-True ($reference.Contains('ps-ai-install-tool.ps1')) "$tool install reference uses shared script"
    Assert-True ($reference.Contains('-Yes')) "$tool install reference requires explicit approval"
}
$repositorySkill = Get-Content -Raw (Join-Path $root 'plugins/ps-ai/skills/ps-ai-repository/SKILL.md')
Assert-True ($repositorySkill.Contains('references/tools.md')) 'Repository skill routes tool hints'
$repositoryTools = Join-Path $root 'plugins/ps-ai/skills/ps-ai-repository/references/tools.md'
Assert-True (Test-Path $repositoryTools) 'Repository tool reference exists'
$readme = Get-Content -Raw (Join-Path $root 'README.md')
Assert-True ($readme.Contains('irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1 | iex')) 'README gives remote Windows installer'
Assert-True ($readme.Contains('ps-ai-install-tool.ps1')) 'README explains optional CLI install hints'

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
        elseif ($Url -like '*checksums.txt') { "$testHash  glab_1.2.3_windows_amd64.zip`n$testHash  glab_1.2.3_Windows_x86_64_installer.exe" | Set-Content -LiteralPath $OutFile }
        elseif ($Url -like '*install.ps1') { '# inert test installer' | Set-Content -LiteralPath $OutFile }
        elseif ($Url -eq 'https://fixture.test/gh.zip') { Copy-Item -LiteralPath $archive -Destination $OutFile }
        else { throw "unexpected test download: $Url" }
    }
    try {
        $folders = @{ pwsh=''; git='cmd'; node='node-v28.1.0-win-x64'; az='bin'; gh='bin'; glab='bin'; copilot='' }
        foreach ($tool in $folders.Keys) {
            foreach ($method in @('msi','zip')) {
                $download = Get-ToolDownload -Tool $tool -Method $method
                Assert-Equal $testHash $download.Hash "$tool $method vendor hash"
                Assert-True ($download.Url.StartsWith('https://')) "$tool $method official HTTPS URL"
                if ($method -eq 'zip') {
                    Assert-Equal 'zip' $download.Kind "$tool archive kind"
                    Assert-Equal $folders[$tool] $download.PathFolder "$tool executable folder"
                } elseif ($tool -in @('git','glab')) {
                    Assert-Equal 'exe' $download.Kind "$tool installer kind"
                    Assert-True ($download.Arguments -contains '/VERYSILENT') "$tool silent installer"
                    if ($tool -eq 'git') { Assert-True ($download.Arguments -contains '/CURRENTUSER') 'Git installs for current user' }
                } else {
                    Assert-Equal 'msi' $download.Kind "$tool MSI kind"
                    Assert-True ($download.Arguments -contains '/qn') "$tool silent MSI"
                }
                if ($tool -eq 'pwsh' -and $method -eq 'msi') { Assert-True ($download.Url.Contains('7.6.9')) 'PowerShell MSI selects newest stable 7.6 release' }
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
        $ghAsset = $sources['https://api.github.com/repos/cli/cli/releases/latest'].assets[0]
        $ghAsset.digest = ''
        Assert-Throws { Get-ToolDownload -Tool gh -Method zip } 'Missing vendor digest blocks download'
        $ghAsset.digest = 'sha256:' + $testHash
        $requests.Clear()
        Invoke-ToolInstall -Tool gh -Platform windows -Method zip | Out-Null
        Assert-Equal 0 $requests.Count 'Explicit method preview has no network'
        Assert-Equal 0 $commands.Count 'Explicit method preview executes nothing'
        Assert-Throws { Invoke-ToolInstall -Tool gh -Platform linux -Method zip -Yes } 'Method is Windows only'

        $archiveSource = Join-Path $sandbox 'archive/bin'
        New-Item -ItemType Directory -Path $archiveSource -Force | Out-Null
        'inert fixture, never execute' | Set-Content -LiteralPath (Join-Path $archiveSource 'gh.exe')
        $archive = Join-Path $sandbox 'gh.zip'
        Compress-Archive -Path (Join-Path $sandbox 'archive/*') -DestinationPath $archive
        $goodHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
        Assert-True (Test-DownloadHash -Path $archive -Expected $goodHash.ToLowerInvariant()) 'SHA-256 comparison accepts hex case'
        Assert-True (-not (Test-DownloadHash -Path $archive -Expected ('0' * 64))) 'SHA-256 comparison rejects mismatch'
        function Get-ToolDownload { param($Tool,$Method) @{ Url='https://fixture.test/gh.zip'; Hash=$goodHash; Kind='zip'; Arguments=@(); PathFolder='bin' } }
        Invoke-ToolInstall -Tool gh -Platform windows -Method zip -Yes | Out-Null
        $exe = Join-Path $sandbox 'tools/gh/bin/gh.exe'
        Assert-True (Test-Path -LiteralPath $exe) 'Verified archive is extracted to user tool folder'
        $exeTime = (Get-Item -LiteralPath $exe).LastWriteTimeUtc
        $requestCount = $requests.Count
        $second = @(Invoke-ToolInstall -Tool gh -Platform windows -Method zip -Yes)
        Assert-Equal $requestCount $requests.Count 'Repeat portable install performs no downloads'
        Assert-Equal $exeTime (Get-Item -LiteralPath $exe).LastWriteTimeUtc 'Repeat portable install writes nothing'
        Assert-True (($second -join "`n").Contains('skip: gh already installed (')) 'Repeat portable install reports skip'
        Install-ToolZip -Tool gh -Archive $archive -PathFolder bin | Out-Null
        Assert-Equal 1 $pathWrites.Count 'Portable folder is added to user PATH only once'
        Assert-True ($userPathState.Value.Contains((Split-Path $exe -Parent))) 'PATH points at executable folder'
        Assert-True ($userPathState.Value.StartsWith('%SYSTEMROOT%\existing')) 'Existing user PATH placeholders preserved'
        Assert-Equal $originalProcessPath $env:PATH 'Installer does not mutate process PATH'
        $userPathState.Value = 'C:\existing'
        Invoke-ToolInstall -Tool gh -Platform windows -Method zip | Out-Null
        Assert-Equal 1 $pathWrites.Count 'Portable preview never repairs PATH without Yes'
        Invoke-ToolInstall -Tool gh -Platform windows -Method zip -Yes | Out-Null
        Assert-Equal 2 $pathWrites.Count 'Retry repairs a missing portable user PATH entry'
        Assert-Equal $requestCount $requests.Count 'PATH repair does not download again'
        Assert-Equal $exeTime (Get-Item -LiteralPath $exe).LastWriteTimeUtc 'PATH repair preserves installed files'
        $savedTestRoot = $env:PS_AI_INSTALL_TEST_ROOT
        try {
            $env:PS_AI_INSTALL_TEST_ROOT = $sandbox
            $userPathState.Value = '%PS_AI_INSTALL_TEST_ROOT%\tools\gh\bin\'
            Install-ToolZip -Tool gh -Archive $archive -PathFolder bin | Out-Null
            Assert-Equal 2 $pathWrites.Count 'Expanded equivalent PATH entry is not duplicated'
        } finally { $env:PS_AI_INSTALL_TEST_ROOT = $savedTestRoot }

        $installed['gh'] = $true
        $requests.Clear()
        $skip = @(Invoke-ToolInstall -Tool gh -Platform windows -Method msi -Yes)
        Assert-True (($skip -join "`n").Contains('skip: gh already installed (test-version)')) 'Installed tool skips with version'
        Assert-Equal 0 $requests.Count 'Installed tool does not resolve downloads'
        $installed.Remove('gh')
        # Move only the harmless local fixture, so the next attempt reaches download verification.
        Move-Item -LiteralPath (Join-Path $sandbox 'tools/gh') -Destination (Join-Path $sandbox 'saved-gh')
        $goodHash = '0' * 64
        $errorText = ''
        try { Invoke-ToolInstall -Tool gh -Platform windows -Method zip -Yes | Out-Null } catch { $errorText = $_.Exception.Message }
        Assert-Equal 'hash mismatch for gh download' $errorText 'Hash mismatch has exact error'
        Assert-True (-not (Test-Path -LiteralPath $downloadedFiles[$downloadedFiles.Count - 1])) 'Hash mismatch deletes download'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $sandbox 'tools/gh'))) 'Hash mismatch never extracts archive'
        Assert-Equal 0 $commands.Count 'Zip and hash mismatch never start commands'
        $badSource = Join-Path $sandbox 'bad/bin'
        New-Item -ItemType Directory -Path $badSource -Force | Out-Null
        'no executable' | Set-Content -LiteralPath (Join-Path $badSource 'readme.txt')
        $badArchive = Join-Path $sandbox 'bad.zip'
        Compress-Archive -Path (Join-Path $sandbox 'bad/*') -DestinationPath $badArchive
        $writesBeforeBadZip = $pathWrites.Count
        Assert-Throws { Install-ToolZip -Tool gh -Archive $badArchive -PathFolder bin } 'Missing executable blocks portable installation'
        Assert-Equal $writesBeforeBadZip $pathWrites.Count 'Invalid ZIP never updates PATH'

        foreach ($kind in @('msi','exe')) {
            function Get-ToolDownload {
                param($Tool,$Method)
                @{ Url='https://fixture.test/gh.zip'; Hash=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash; Kind=$kind; Arguments=@('/qn','/norestart'); PathFolder='' }
            }
            Invoke-ToolInstall -Tool gh -Platform windows -Method msi -Yes | Out-Null
            $command = $commands[$commands.Count - 1]
            if ($kind -eq 'msi') {
                Assert-Equal 'msiexec.exe' $command[0] 'MSI uses msiexec'
                Assert-Equal '/i' $command[1] 'MSI passes install operation'
            } else { Assert-True ($command[0].EndsWith('.exe')) 'EXE runs verified downloaded path' }
            Assert-True ($command -contains '/qn') "$kind passes silent arguments"
            $commandState.Exit = 3010
            Invoke-ToolInstall -Tool gh -Platform windows -Method msi -Yes | Out-Null
            Assert-Equal 0 $LASTEXITCODE "$kind reboot-success code normalized for CLI"
            $commandState.Exit = 5
            Assert-Throws { Invoke-ToolInstall -Tool gh -Platform windows -Method msi -Yes } "$kind propagates installer failure"
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
        & {
            Set-Item Function:Test-ToolInstalled $realInstalledCheck
            function Test-ToolCommandAvailable { param($Name) $false }
            function Get-UserPath { Join-Path $PSScriptRoot 'fixtures/install/path-only' }
            $state = Test-ToolInstalled -Tool gh
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
        Copy-Item (Join-Path $repoRoot 'plugins/ps-ai') $plugin -Recurse
        $fourthSkill = Join-Path $plugin 'skills/ps-ai-fourth'
        Copy-Item (Join-Path $PSScriptRoot 'fixtures/tools/ps-ai-fourth') $fourthSkill -Recurse
        $descriptorPath = Join-Path $fourthSkill 'tool.json'
        $data = Get-Content $descriptorPath -Raw | ConvertFrom-Json
        $data.install.check = @('fourth-cli','--probe','space value')
        $data.install.macos.needs = @('node')
        $data.install.macos.commands = @(,([string[]]@('fixture-manager','setup','space value')))
        $data | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
        . (Join-Path $plugin 'bin/ps-ai-install-tool.ps1') -NoRun
        function Get-ToolInstallRoot { param($Tool) Join-Path $sandbox "home[1]/tools/$Tool" }
        $recipe = Get-ToolRecipe -Tool fourth -Platform macos
        Assert-Equal 'fourth-cli|--probe|space value' ($recipe.Check -join '|') 'Recipe check keeps declared executable and arguments'
        Assert-Equal 'node' ($recipe.Needs -join '|') 'Recipe needs come from platform data'
        Assert-Equal 'fixture-manager|setup|space value' ($recipe.Install[0] -join '|') 'Recipe commands retain array boundaries'
        Assert-Equal 'https://fixture.test/install' (Get-ToolRecipe -Tool fourth -Platform linux).Docs 'Recipe docs come from data'
        Assert-Equal 'winget|install|--id|Example.Fourth|-e' ((Get-ToolRecipe -Tool fourth -Platform windows).Install[0] -join '|') 'Recipe Windows id comes from data'
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
        $data.install.windows.portableCommand = 'fourth-v*/fourth-cli.exe'
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
        $helpers.fourth = $helpers.gh
        $helpers | ConvertTo-Json -Depth 100 | Set-Content $helpersPath
        Assert-Throws { Get-ToolRecipe -Tool fourth -Platform windows } 'Helper/agent id collision fails before installation'
    } finally {
        $env:PATH = $savedPath
        $cleanup = [IO.Path]::GetFullPath($sandbox)
        if (-not $cleanup.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar)) { throw 'Unsafe recipe fixture cleanup' }
        Remove-Item -LiteralPath $cleanup -Recurse -Force
    }
}

# SyntheticDownloadsAndPagedStableSelection: source formats, never ids, select resolution.
& {
    $ErrorActionPreference = 'Stop'
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $scratch = [IO.Path]::GetFullPath((Join-Path $repoRoot '.agents/temp/restructure'))
    $sandbox = Join-Path $scratch ('downloads-' + [guid]::NewGuid().ToString('N'))
    $plugin = Join-Path $sandbox 'plugin'
    try {
        New-Item -ItemType Directory $sandbox -Force | Out-Null
        Copy-Item (Join-Path $repoRoot 'plugins/ps-ai') $plugin -Recurse
        $fourthSkill = Join-Path $plugin 'skills/ps-ai-fourth'
        Copy-Item (Join-Path $PSScriptRoot 'fixtures/tools/ps-ai-fourth') $fourthSkill -Recurse
        $descriptorPath = Join-Path $fourthSkill 'tool.json'
        $data = Get-Content $descriptorPath -Raw | ConvertFrom-Json
        . (Join-Path $plugin 'bin/ps-ai-install-tool.ps1') -NoRun
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
        $data.install.windows.download.zip = [pscustomobject]@{kind='zip';resolver='release-links';metadataUrl='https://fixture.test/links/latest';assetPattern='^fourth\.zip$';checksumAsset='checksums.txt';verification='checksum-file';arguments=@();pathFolder='bin'}
        $data | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
        $download = Get-ToolDownload -Tool fourth -Method zip
        Assert-Equal 'https://fixture.test/linked-fourth.zip' $download.Url 'Fourth release-links URL'
        Assert-Equal ('2' * 64) $download.Hash 'Fourth exact checksum file'
        Assert-True ($requests -contains 'https://fixture.test/checksums.txt') 'Named checksum asset is fetched'
        Assert-True (-not ($requests -contains 'https://fixture.test/decoy-checksums')) 'Similarly named checksum is ignored'
        $sources['https://fixture.test/checksums.txt'] = ('2' * 64) + '  other.zip'
        Assert-Throws { Get-ToolDownload -Tool fourth -Method zip } 'Checksum for another filename is rejected'
        $data.install.windows.download.zip = [pscustomobject]@{kind='zip';resolver='lts-index';metadataUrl='https://fixture.test/versions';assetName='fourth-{version}.zip';url='https://fixture.test/{version}/fourth-{version}.zip';checksumUrl='https://fixture.test/{version}/sums';verification='checksum-file';arguments=@();pathFolder='fourth-{version}'}
        $data | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
        $download = Get-ToolDownload -Tool fourth -Method zip
        Assert-Equal 'https://fixture.test/v42.3.1/fourth-v42.3.1.zip' $download.Url 'First LTS retains leading v in URL and filename'
        Assert-Equal 'fourth-v42.3.1' $download.PathFolder 'First LTS retains leading v in PATH folder'
        Assert-True ($requests -contains 'https://fixture.test/v42.3.1/sums') 'Checksum URL retains leading v'
        Assert-Equal ('3' * 64) $download.Hash 'LTS checksum filename uses the same version'
        $sources['https://fixture.test/versions'] = '[{"version":"v99.0.0","lts":false}]'
        $message = ''
        try { Get-ToolDownload -Tool fourth -Method zip | Out-Null } catch { $message=$_.Exception.Message }
        Assert-Equal 'no fourth LTS release found' $message 'LTS failure names the requested tool'
        $helpers = Get-Content (Join-Path $plugin 'bin/install-tool/helpers.json') -Raw | ConvertFrom-Json
        $data.install.windows.download.msi = $helpers.pwsh.windows.download.msi
        $data | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
        $requests.Clear()
        $download = Get-ToolDownload -Tool fourth -Method msi
        Assert-True ($download.Url.Contains('7.6.9')) 'Fourth paginated recipe selects newest qualifying stable MSI on second page'
        Assert-True ($requests -contains 'https://api.github.com/repos/PowerShell/PowerShell/releases?per_page=100&page=2') 'Full unusable first page advances to second page'
        Assert-True (-not ($requests -contains 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest')) 'Paged selector uses only its declared source'
        Assert-Equal '/qn|/norestart|ADD_PATH=1' ($download.Arguments -join '|') 'Installer flags are recipe data even for fourth tool'
        $latest = Get-ToolDownload -Tool pwsh -Method zip
        Assert-True ($latest.Url.Contains('7.7.0')) 'Latest ZIP selection remains independent of stable MSI'
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

