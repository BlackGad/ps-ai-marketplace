param([string]$Finding)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$setupScript = Join-Path $root 'plugins/ps-ai/bin/ps-ai-setup.ps1'
$tempRoot = Join-Path $root ('.agents/temp/setup-' + [guid]::NewGuid().ToString('N'))
$savedPath = $env:PATH
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

function Assert-SetupText {
    param($Output, [string]$Text, [string]$Message)
    Assert-True (($Output -join "`n").Contains($Text)) $Message
}

function Get-SetupTree {
    param([string]$Folder)
    return (@(Get-ChildItem -LiteralPath $Folder -Force -Recurse | Sort-Object FullName | ForEach-Object {
        # Windows can update directory timestamps lazily after child writes; compare their paths only.
        if ($_.PSIsContainer) { $_.FullName + ':directory' }
        else { $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash + ':' + $_.LastWriteTimeUtc.Ticks }
    }) -join '|')
}

try {
    . $setupScript -NoRun
    $realFindInstaller = ${function:Find-SetupInstaller}
    $realInvokeInstaller = ${function:Invoke-SetupInstaller}
    $realTestCommand = ${function:Test-SetupCommand}
    $realToolInstalled = ${function:Test-SetupToolInstalled}
    $fakeBin = Join-Path $tempRoot 'tools'
    New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
    foreach ($tool in @('claude', 'codex', 'copilot', 'claude1')) {
        $path = Join-Path $fakeBin $(if ($IsWindows) { "$tool.cmd" } else { $tool })
        $text = if ($IsWindows) { '@exit /b 99' } else { "#!/bin/sh`nexit 99`n" }
        [IO.File]::WriteAllText($path, $text)
        if (-not $IsWindows) { & chmod +x $path }
    }
    $systemBin = if ($IsWindows) { Join-Path $env:SystemRoot 'System32' } else { '/usr/bin' }
    $fixturePath = @($fakeBin, (Split-Path (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source), $systemBin) -join [IO.Path]::PathSeparator
    $env:PATH = $fixturePath
    $version = (Get-Content (Join-Path $root 'plugins/ps-ai/plugin.json') -Raw | ConvertFrom-Json).version

    # All machine, CLI and network seams are inert; account creation still runs the real add path.
    function Test-SetupCommand { param($Name) return ($Name -cnotin $script:missingTools) }
    function Test-SetupToolInstalled { param($Tool) return ($Tool -cnotin $script:missingTools) }
    function Get-SetupUserPath { return $script:userPath }
    function Get-SetupMachinePath { return '' }
    function Set-SetupUserPath { param($Value) $script:pathWrites.Add($Value); $script:userPath = $Value }
    function Find-SetupInstaller { return (Join-Path $tempRoot 'inert-installer.ps1') }
    function Save-SetupInstaller { param($Path) $script:downloads.Add($Path); [IO.File]::WriteAllText($Path, 'param([string]$HomeRoot) # inert') }
    function Invoke-SetupToolInstall {
        param($Tool)
        $script:toolInstalls.Add($Tool)
        if ($script:toolFailure) { return @{ Ok = $false; Message = "fixture failure`nsecond line" } }
        if (-not $script:needsTerminal) { $script:missingTools = @($script:missingTools | Where-Object { $_ -cne $Tool }) }
        return @{ Ok = $true; Message = 'installed' }
    }
    function Invoke-SetupInstaller {
        param($Installer, $Tool, $ConfigDir)
        $script:installs.Add(@{ Installer = $Installer; Tool = $Tool; ConfigDir = $ConfigDir })
        if ($script:failFolder -ceq $ConfigDir) { return 1 }
        $descriptor = Get-PsAiTool -Tool $Tool
        $manifest = Join-Path $ConfigDir "$($descriptor.plugin.installedRoot)/$version/plugin.json"
        New-Item -ItemType Directory -Path (Split-Path $manifest) -Force | Out-Null
        @{ name = 'ps-ai'; version = $version } | ConvertTo-Json | Set-Content -LiteralPath $manifest
        return 0
    }
    function Reset-SetupTest {
        param([string]$Name)
        $script:testHome = Join-Path $tempRoot $Name
        New-Item -ItemType Directory -Path $script:testHome -Force | Out-Null
        $script:settings = Join-Path $script:testHome '.legion/configuration/ps-ai-personalisation.json'
        $script:userPath = 'fixture-path'
        $script:pathWrites = [Collections.Generic.List[string]]::new()
        $script:toolInstalls = [Collections.Generic.List[string]]::new()
        $script:installs = [Collections.Generic.List[object]]::new()
        $script:downloads = [Collections.Generic.List[string]]::new()
        $script:missingTools = @()
        $script:toolFailure = $false
        $script:needsTerminal = $false
        $script:failFolder = ''
        $env:PATH = $fixturePath
    }

    $regressions = [ordered]@{
        R4B1 = {
            Reset-SetupTest 'broken-node'
            & {
                Set-Item function:Test-SetupToolInstalled $realToolInstalled
                . (Join-Path $root 'plugins/ps-ai/bin/ps-ai-install-tool.ps1') -NoRun
                $probe = @{ Node = $false; Codex = $false; Commands = [Collections.Generic.List[string]]::new() }
                function node { $global:LASTEXITCODE = if ($probe.Node) { 0 } else { 7 }; 'fixture node' }
                function codex { $global:LASTEXITCODE = if ($probe.Codex) { 0 } else { 7 }; 'fixture codex' }
                function Test-ToolCommandAvailable { param($Name) return $true }
                function Invoke-ToolCommand {
                    param($Command)
                    $probe.Commands.Add(($Command -join ' '))
                    if ($Command[0] -eq 'brew') { $probe.Node = $true } else { $probe.Codex = $true }
                    return 0
                }
                $hint = Get-SetupToolInstallHint -Tool (Get-PsAiTool codex) -Platform macos
                Assert-Equal 'brew install node; npm install -g @openai/codex' $hint 'R4 B1 consent includes repair of a broken Node command'
                Invoke-ToolInstall -Tool codex -Platform macos -Yes | Out-Null
                Assert-Equal $hint ($probe.Commands -join '; ') 'R4 B1 apply matches consent for broken Node'
            }
        }
        K5 = {
            Reset-SetupTest 'legacy-installer'
            $pluginRoot = $script:SetupPluginRoot
            try {
                $script:SetupPluginRoot = Join-Path $testHome 'cache/plugins/ps-ai'
                New-Item -ItemType Directory -Path $script:SetupPluginRoot -Force | Out-Null
                Copy-Item (Join-Path $pluginRoot 'plugin.json') $script:SetupPluginRoot
                $legacy = Join-Path $testHome '.claude/plugins/marketplaces/ps-ai-marketplace/install.ps1'
                New-Item -ItemType Directory -Path (Split-Path $legacy) -Force | Out-Null
                'param([switch]$Yes) throw "legacy installer must never run"' | Set-Content $legacy
                Assert-Equal $null (Find-SetupLocalInstaller -HomeRoot $testHome) 'K5 alternate home rejects an installer without HomeRoot'
                $plan = @(Invoke-Setup -HomeRoot $testHome -Add codex)
                Assert-SetupText $plan '  download ps-ai installer' 'K5 incompatible cached installer discloses download'
                $script:SetupHomeRoot = $testHome
                $download = & $realFindInstaller
                Assert-Equal 1 $downloads.Count 'K5 compatible installer fallback downloads once'
                Assert-True ($download.StartsWith($testHome)) 'K5 download stays under the selected home'
                'param([string]$HomeRoot, [switch]$Yes)' | Set-Content $legacy
                Assert-Equal $legacy (Find-SetupLocalInstaller -HomeRoot $testHome) 'K5 compatible cache is reused'
            } finally { $script:SetupPluginRoot = $pluginRoot }
        }
        K7 = {
            Reset-SetupTest 'prerequisite-plan'
            $script:missingTools = @('node', 'codex')
            $hint = Get-SetupToolInstallHint -Tool (Get-PsAiTool codex) -Platform macos
            Assert-Equal 'brew install node; npm install -g @openai/codex' $hint 'K7 macOS consent includes missing Node before npm'
            $script:missingTools = @('codex')
            $hint = Get-SetupToolInstallHint -Tool (Get-PsAiTool codex) -Platform macos
            Assert-Equal 'npm install -g @openai/codex' $hint 'K7 installed prerequisites are omitted'
            & {
                . (Join-Path $root 'plugins/ps-ai/bin/ps-ai-install-tool.ps1') -NoRun
                $installProbe = @{ Installed = @(); Commands = [Collections.Generic.List[string]]::new() }
                function Test-ToolInstalled { param($Tool) return @{ Installed = ($Tool -in $installProbe.Installed); Version = 'fixture' } }
                function Test-ToolCommandAvailable { param($Name) return $true }
                function Invoke-ToolCommand {
                    param($Command)
                    $installProbe.Commands.Add(($Command -join ' '))
                    if ($Command[0] -eq 'brew') { $installProbe.Installed += 'node' } else { $installProbe.Installed += 'codex' }
                    return 0
                }
                Invoke-ToolInstall -Tool codex -Platform macos -Yes | Out-Null
                Assert-Equal 'brew install node; npm install -g @openai/codex' ($installProbe.Commands -join '; ') 'K7 applied prerequisite commands match the consent recipe'
            }
        }
        K8 = {
            Reset-SetupTest 'custom-wrapper-repair'
            Initialize-SetupFiles -Plan (Get-SetupPlan -HomeRoot $testHome) | Out-Null
            $folder = Join-Path $testHome 'custom account'
            New-Item -ItemType Directory -Path $folder | Out-Null
            $custom = Join-Path $fakeBin "custom'100% command.ps1"
            '# inert custom command' | Set-Content $custom
            $data = Read-PsAiJson $settings
            Add-PsAiSubscriptionAccount -Id custom-a -Tool codex -Command $custom -ConfigDir $folder -HomeRoot $testHome -Data $data -Path $settings | Out-Null
            $sh = Join-Path $testHome '.legion/bin/custom-a'
            $cmd = "$sh.cmd"
            if ($IsWindows) {
                $original = [IO.File]::ReadAllText($cmd)
                Remove-Item $cmd
                Invoke-Setup -HomeRoot $testHome -Yes | Out-Null
                Assert-Equal $original ([IO.File]::ReadAllText($cmd)) 'K8 shell survivor restores custom Windows target'
                $original = [IO.File]::ReadAllText($sh)
                Remove-Item $sh
                Invoke-Setup -HomeRoot $testHome -Yes | Out-Null
                Assert-Equal $original ([IO.File]::ReadAllText($sh)) 'K8 batch survivor restores custom shell target'
                Remove-Item $cmd
                [IO.File]::AppendAllText($sh, '# owner customization' + "`n")
                $output = @(Invoke-Setup -HomeRoot $testHome -Yes)
                Assert-SetupText $output 'target needed' 'K8 edited survivor is ambiguous and never guessed'
                Assert-Equal $false (Test-Path $cmd) 'K8 edited survivor is kept without generating a replacement'
                [IO.File]::WriteAllText($sh, $original)
                Invoke-Setup -HomeRoot $testHome -Yes | Out-Null
                Remove-Item $cmd
            }
            Remove-Item $sh
            $plan = @(Invoke-Setup -HomeRoot $testHome)
            Assert-SetupText $plan 'target needed: custom-a' 'K8 absent wrappers ask for the target in the plan'
            $output = @(Invoke-Setup -HomeRoot $testHome -Yes)
            Assert-SetupText $output 'target needed' 'K8 ambiguous repair reports next step'
            Assert-Equal $false (Test-Path $sh) 'K8 ambiguous repair never substitutes the stock command'
        }
        G1 = {
            Reset-SetupTest 'interrupted-chmod'
            Invoke-Setup -HomeRoot $testHome -Add codex -Yes | Out-Null
            $account = Join-Path $testHome '.legion/bin/codex1'
            $command = Join-Path $testHome '.legion/bin/legion'
            $before = [IO.File]::ReadAllText($account)
            $realExecutable = ${function:Test-PsAiLauncherExecutable}
            $realWrite = ${function:Write-PsAiGeneratedFile}
            $repair = @{ Pending = @($account, $command); Fixed = [Collections.Generic.List[string]]::new() }
            function Test-PsAiLauncherExecutable {
                param($Path)
                if ($Path -in $repair.Pending) { return $false }
                return & $realExecutable -Path $Path
            }
            function Write-PsAiGeneratedFile {
                param($Path, $Content, $Changes, [switch]$Executable)
                if ($Path -in $repair.Pending -and $Executable) { $repair.Fixed.Add($Path); $repair.Pending = @($repair.Pending | Where-Object { $_ -ne $Path }) }
                & $realWrite @PSBoundParameters
            }
            if (-not $IsWindows) {
                foreach ($file in @($account, $command)) { [IO.File]::SetUnixFileMode($file, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite) }
            }
            try {
                $plan = @(Invoke-Setup -HomeRoot $testHome)
                Assert-SetupText $plan 'wrappers repair codex1' 'G1 plan notices account execute permission'
                Assert-SetupText $plan 'commands restore execute permission for legion' 'G1 plan notices owner command execute permission'
                Invoke-Setup -HomeRoot $testHome -Yes | Out-Null
                Assert-Equal 2 $repair.Fixed.Count 'G1 setup repairs both owned launchers'
                Assert-Equal $before ([IO.File]::ReadAllText($account)) 'G1 repair keeps the registered wrapper target'
                Assert-True (& $realExecutable -Path $account) 'G1 account is executable after repair'
                Assert-True (& $realExecutable -Path $command) 'G1 owner command is executable after repair'
            } finally {
                Set-Item function:Test-PsAiLauncherExecutable $realExecutable
                Set-Item function:Write-PsAiGeneratedFile $realWrite
            }
        }
        G6 = {
            Reset-SetupTest 'alternate home with spaces'
            $plan = @{ Bin = (Join-Path $testHome '.legion/bin') }
            $hint = Get-SetupPathHint -Plan $plan
            Assert-Equal ("add to your shell profile: export PATH='" + $plan.Bin + "'" + ':"$PATH"') $hint 'G6 shell hint quotes the selected bin folder'
            if (-not $IsWindows) {
                $export = $hint.Substring('add to your shell profile: '.Length)
                $actual = & /bin/sh -c ($export + '; printf "%s" "$PATH"')
                Assert-Equal ($plan.Bin + ':' + $fixturePath) $actual 'G6 following the hint adds the alternate bin with spaces'
            }
        }
        B1 = {
            Reset-SetupTest 'adopt-repeat'
            $folder = Join-Path $testHome 'existing'
            New-Item -ItemType Directory -Path $folder | Out-Null
            Invoke-Setup -HomeRoot $testHome -Add "codex:$folder" -Yes | Out-Null
            $before = Get-SetupTree $testHome
            $output = @(Invoke-Setup -HomeRoot $testHome -Add "codex:$folder" -Yes)
            Assert-Equal 1 (@((Read-PsAiJson $settings).agents).Count) 'B1 repeated adoption reuses the account'
            Assert-Equal $before (Get-SetupTree $testHome) 'B1 repeated adoption changes nothing'
            Assert-SetupText $output 'skip: account codex1 (already done)' 'B1 reused adoption reports skip'
            $plan = Get-SetupPlan -HomeRoot $testHome -Add @("codex:$folder", "codex:$folder")
            Assert-Equal 1 $plan.Accounts.Count 'B1 duplicate adoption in one plan reuses the account'
            $plan = Get-SetupPlan -HomeRoot $testHome -Add ("codex:" + $folder + [IO.Path]::DirectorySeparatorChar)
            Assert-Equal 'codex1' $plan.Accounts[0].Id 'B1 trailing directory separator still identifies the same folder'
            if ($IsWindows) {
                $plan = Get-SetupPlan -HomeRoot $testHome -Add ("codex:" + $folder.ToUpperInvariant())
                Assert-Equal 'codex1' $plan.Accounts[0].Id 'B1 folder identity follows Windows case rules'
            }
            Reset-SetupTest 'adopt-twice-in-one-run'
            $folder = Join-Path $testHome 'existing'
            New-Item -ItemType Directory -Path $folder | Out-Null
            $plan = Get-SetupPlan -HomeRoot $testHome -Add @("codex:$folder", "codex:$folder")
            Assert-True $plan.Accounts[0].New 'B1 duplicate new adoption stays visible as an add in the plan'
            Invoke-Setup -HomeRoot $testHome -Add @("codex:$folder", "codex:$folder") -Yes | Out-Null
            Assert-Equal 1 (@((Read-PsAiJson $settings).agents).Count) 'B1 duplicate new adoption is recorded once'
        }
        B2 = {
            Reset-SetupTest 'wrapper-repair'
            $realWrappers = ${function:New-PsAiWrappers}
            function New-PsAiWrappers {
                param($Id, $Tool, $HomeRoot, $RealCommand, $ConfigDir, [switch]$CheckOnly)
                if (-not $CheckOnly) { throw 'fixture interrupted wrapper write' }
                & $realWrappers @PSBoundParameters
            }
            try { Assert-Throws { Invoke-Setup -HomeRoot $testHome -Add codex -Yes } 'B2 interruption after settings is reproducible' }
            finally { Set-Item function:New-PsAiWrappers $realWrappers }
            Assert-Equal 1 (@((Read-PsAiJson $settings).agents).Count) 'B2 interruption leaves a recorded account'
            $plan = @(Invoke-Setup -HomeRoot $testHome)
            Assert-SetupText $plan 'target needed: codex1' 'B2 plan names missing account wrapper target'
            $wrapper = Get-PsAiWrapperCommand codex1 $testHome
            $output = @(Invoke-Setup -HomeRoot $testHome -Yes)
            Assert-SetupText $output 'target needed: codex1' 'B2 interruption before either wrapper leaves target recovery to the owner'
            $data = Read-PsAiJson $settings
            Add-PsAiSubscriptionAccount -Id codex1 -Tool codex -Command (Join-Path $fakeBin $(if ($IsWindows) { 'codex.cmd' } else { 'codex' })) -HomeRoot $testHome -Data $data -Path $settings | Out-Null
            Assert-True (Test-Path -LiteralPath $wrapper) 'B2 finish setup repairs interrupted account wrappers'
            Remove-Item -LiteralPath $wrapper
            if ($IsWindows) { Invoke-Setup -HomeRoot $testHome -Add codex -Id codex1 -Yes | Out-Null }
            else { Add-PsAiSubscriptionAccount -Id codex1 -Tool codex -Command (Join-Path $fakeBin 'codex') -HomeRoot $testHome -Data $data -Path $settings | Out-Null }
            Assert-True (Test-Path -LiteralPath $wrapper) 'B2 explicit repeat repairs a missing wrapper half'
            $before = Get-SetupTree $testHome
            Invoke-Setup -HomeRoot $testHome -Yes | Out-Null
            Assert-Equal $before (Get-SetupTree $testHome) 'B2 repaired repeat preserves files and timestamps'
        }
        B3 = {
            Reset-SetupTest 'probe-path'
            # Forbid PATH assignments before exercising the real probe with fixture path sources.
            $assignments = $realTestCommand.Ast.FindAll({ param($node)
                $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -ieq '$env:PATH'
            }, $true)
            Assert-Equal 0 $assignments.Count 'B3 command probing never assigns process PATH'
            function Get-SetupMachinePath { return '' }
            $script:userPath = $fakeBin
            $env:PATH = if ($IsWindows) { $systemBin } else { $fixturePath }
            $before = $env:PATH
            Assert-True (& $realTestCommand -Name codex) 'B3 probe finds a CLI on fixture PATH'
            Assert-Equal $before $env:PATH 'B3 real command probe leaves calling PATH unchanged'
            $fakeProbe = ${function:Test-SetupCommand}
            try {
                Set-Item function:Test-SetupCommand $realTestCommand
                Invoke-Setup -HomeRoot $testHome -Add codex | Out-Null
                Assert-Equal $before $env:PATH 'B3 real plan leaves calling PATH unchanged'
                Invoke-Setup -HomeRoot $testHome -Add codex -Yes | Out-Null
                Assert-Equal 1 (@((Read-PsAiJson $settings).agents).Count) 'B3 apply can use a CLI discovered on fixture user PATH'
                $probe = Join-Path $testHome 'probe.ps1'
                '$env:PATH' | Set-Content -LiteralPath $probe
                $env:PATH = $before
                $result = Invoke-SetupProcess -Arguments @('-NoProfile', '-File', $probe)
                Assert-True (Test-PsAiPathEntry -Path $result.Output.Trim() -Folder $fakeBin) 'B3 installer children can find freshly installed CLI folders'
                Assert-Equal $before $env:PATH 'B3 child PATH refresh leaves calling PATH unchanged'
            } finally { Set-Item function:Test-SetupCommand $fakeProbe }
        }
        B5 = {
            Reset-SetupTest 'install-hints'
            $script:missingTools = @('copilot')
            $plan = @(Invoke-Setup -HomeRoot $testHome -Add copilot)
            Assert-SetupText $plan 'npm install -g @github/copilot' 'B5 Copilot plan uses npm when node is available'
            foreach ($platform in @('linux', 'macos')) {
                $tool = Get-PsAiTool claude
                $hint = Get-SetupToolInstallHint -Tool $tool -Platform $platform
                Assert-Equal ($tool.install.$platform.commands[0] -join ' ') $hint 'B5 Claude hint uses the platform recipe'
            }
            $script:missingTools = @('node')
            $hint = Get-SetupToolInstallHint -Tool (Get-PsAiTool copilot) -Platform windows
            Assert-Equal 'winget install --id GitHub.Copilot -e' $hint 'B5 Copilot fallback uses the Windows recipe'
        }
        B6 = {
            Reset-SetupTest 'case-cache'
            # Exercise case-sensitive path semantics even on Windows; the installer is inert.
            function Get-PsAiPathComparer { return [StringComparer]::Ordinal }
            $tool = Get-PsAiTool codex
            $rows = @('account', 'ACCOUNT', 'account') | ForEach-Object {
                [pscustomobject]@{ Id = 'codex-a'; Tool = $tool; Folder = (Join-Path $testHome $_); Version = $null; Usable = $true; NextStep = 'ready' }
            }
            $plan = @{ Accounts = $rows; Version = $version; HomeRoot = $testHome }
            $script:SetupHomeRoot = $testHome
            Install-SetupPlugins -Plan $plan | Out-Null
            Assert-Equal 2 $installs.Count 'B6 case-sensitive folders install separately and exact duplicates install once'
        }
        B7 = {
            # Setup installs only where ps-ai is missing; a different version is the update flow's job.
            foreach ($delivered in @('0.5.0', '9.0.0')) {
                Reset-SetupTest ("version-" + $delivered)
                $currentVersion = $version
                $version = $delivered
                Invoke-Setup -HomeRoot $testHome -Add codex -Yes | Out-Null
                $version = $currentVersion
                $before = Get-SetupTree $testHome
                $output = @(Invoke-Setup -HomeRoot $testHome -Yes)
                Assert-Equal 1 $installs.Count "B7 folder with version $delivered is not installed again"
                Assert-SetupText $output 'skip: ps-ai in' "B7 repeat with version $delivered prints skip"
                Assert-Equal $before (Get-SetupTree $testHome) "B7 repeat with version $delivered changes nothing"
                $plan = @(Invoke-Setup -HomeRoot $testHome)
                Assert-True (-not (($plan -join "`n") -match 'install  ps-ai')) "B7 plan skips folder with version $delivered"
            }
        }
        B7Download = {
            Reset-SetupTest 'download-plan'
            $pluginRoot = $script:SetupPluginRoot
            try {
                $script:SetupPluginRoot = Join-Path $testHome 'cache/plugins/ps-ai'
                New-Item -ItemType Directory -Path $script:SetupPluginRoot -Force | Out-Null
                Copy-Item -LiteralPath (Join-Path $pluginRoot 'plugin.json') -Destination $script:SetupPluginRoot
                $plan = @(Invoke-Setup -HomeRoot $testHome -Add codex)
                Assert-SetupText $plan '  download ps-ai installer from https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1' 'B7 plan discloses remote installer download'
                Assert-Equal 0 $downloads.Count 'B7 planning never downloads the installer'
            } finally { $script:SetupPluginRoot = $pluginRoot }
        }
        B8 = {
            Reset-SetupTest 'terminal-retry'
            $script:missingTools = @('codex')
            $script:needsTerminal = $true
            $output = @(Invoke-Setup -HomeRoot $testHome -Add codex -Yes)
            Assert-SetupText $output 'open a new terminal, then repeat the add' 'B8 terminal hint retains the unrecorded add request'
        }
        B8Blocked = {
            Reset-SetupTest 'blocked-plan'
            Invoke-Setup -HomeRoot $testHome -Yes | Out-Null
            $bin = Join-Path $testHome '.legion/bin'
            $env:PATH += [IO.Path]::PathSeparator + $bin
            'owner command' | Set-Content -LiteralPath (Join-Path $bin 'legion')
            $output = @(Invoke-Setup -HomeRoot $testHome)
            Assert-SetupText $output 'blocked: command legion (another file is there)' 'B8 completed plan exposes blocked commands'
            Assert-Equal 'Nothing to do.' $output[-1] 'N2 a plan with only blocked commands ends with Nothing to do.'
        }
        N4Folder = {
            if (-not $IsWindows) { return }
            Reset-SetupTest 'folder-case'
            Invoke-Setup -HomeRoot $testHome -Yes | Out-Null
            $realAdd = ${function:Add-PsAiSubscriptionAccount}
            $script:addArguments = $null
            function Add-PsAiSubscriptionAccount {
                param($Id, $Tool, $HomeRoot, $Data, $Path, $ConfigDir, $Command)
                $script:addArguments = $PSBoundParameters
            }
            $managed = Get-PsAiNewAccountDir -Id 'codex1' -HomeRoot $testHome
            $row = [pscustomobject]@{ Id = 'codex1'; Tool = @{ id = 'codex'; command = 'codex' }; Folder = $managed.ToUpperInvariant()
                Requested = $true; New = $false; Adopted = $false; Usable = $true; MissingWrappers = $false; Provider = $null; NextStep = '' }
            try { Add-SetupAccounts -Plan ([pscustomobject]@{ HomeRoot = $testHome; Accounts = @($row) }) | Out-Null }
            finally { Set-Item -Path function:Add-PsAiSubscriptionAccount -Value $realAdd }
            Assert-True (-not $script:addArguments.ContainsKey('ConfigDir')) 'N4 a folder that differs only by case is the managed folder'
        }
    }
    foreach ($key in $regressions.Keys) {
        if (-not $Finding -or $Finding -eq $key) { & $regressions[$key] }
    }
    if ($Finding) { return }

    Reset-SetupTest 'empty'
    $before = Get-SetupTree $testHome
    $plan = @(Invoke-Setup -HomeRoot $testHome)
    foreach ($text in @('Plan (nothing changed yet):', '  create   settings and notes', '  commands write ps-ai-setup, ps-ai-status, ps-ai-overseer, legion', '  path     ', 'Run again with -Yes to apply.')) {
        Assert-SetupText $plan $text 'Fresh empty plan has the contract lines'
    }
    Assert-Equal $before (Get-SetupTree $testHome) 'Plan changes no home bytes or timestamps'
    $apply = @(Invoke-Setup -HomeRoot $testHome -Yes)
    Assert-Equal 0 (@(Invoke-PsAiValidation -Kind personalisation -Path $settings).Count) 'Empty settings are valid'
    Assert-Equal 0 (@((Read-PsAiJson $settings).agents).Count) 'Fresh setup supports no accounts'
    Assert-Equal ([IO.File]::ReadAllText((Join-Path $root 'plugins/ps-ai/skills/ps-ai-personalisation/references/notes-template.md'))) ([IO.File]::ReadAllText((Join-Path (Split-Path $settings) 'ps-ai-notes.md'))) 'Notes use the unchanged template'
    if (-not $IsWindows) { $env:PATH += [IO.Path]::PathSeparator + (Join-Path $testHome '.legion/bin') }
    $before = Get-SetupTree $testHome
    $repeat = @(Invoke-Setup -HomeRoot $testHome -Yes)
    Assert-Equal 0 (@($repeat | Where-Object { -not $_.StartsWith('skip:') }).Count) 'Empty repeat prints only skips'
    Assert-Equal $before (Get-SetupTree $testHome) 'Empty repeat changes nothing'
    Assert-Equal 'Nothing to do.' (@(Invoke-Setup -HomeRoot $testHome)[-1]) 'Finished plan ends in Nothing to do'

    Reset-SetupTest 'accounts'
    $adopt = Join-Path $testHome 'my codex'
    New-Item -ItemType Directory -Path $adopt -Force | Out-Null
    'keep login data' | Set-Content (Join-Path $adopt 'owner.txt')
    $before = Get-SetupTree $testHome
    $planWatch = [Diagnostics.Stopwatch]::StartNew()
    $plan = @(Invoke-Setup -HomeRoot $testHome -Add @('claude', "codex:$adopt"))
    $planWatch.Stop()
    Assert-SetupText $plan '  add      claude2 (claude) new folder' 'Auto id skips application claude1'
    Assert-SetupText $plan "  add      codex1 (codex) existing folder $adopt" 'Adoption keeps spaces and drive colon'
    Assert-SetupText $plan '  install  ps-ai into ' 'Plan groups plugin installs'
    Assert-Equal $before (Get-SetupTree $testHome) 'Account plan changes no bytes or timestamps'
    Remove-Item -LiteralPath (Join-Path $fakeBin $(if ($IsWindows) { 'claude1.cmd' } else { 'claude1' }))
    $realNewWrappers = ${function:New-PsAiWrappers}
    $script:wrapperCalls = [Collections.Generic.List[string]]::new()
    function New-PsAiWrappers {
        param($Id, $Tool, $HomeRoot, $RealCommand, $ConfigDir, [switch]$CheckOnly)
        $script:wrapperCalls.Add($Id)
        & $realNewWrappers @PSBoundParameters
    }
    $global:LASTEXITCODE = 7
    $applyWatch = [Diagnostics.Stopwatch]::StartNew()
    $apply = @(Invoke-Setup -HomeRoot $testHome -Add @('claude', "codex:$adopt") -Yes)
    $applyWatch.Stop()
    Set-Item -Path function:New-PsAiWrappers -Value $realNewWrappers
    Assert-Equal 'claude1|claude1|codex1|codex1' ($wrapperCalls -join '|') 'Each account validates and creates wrappers in this process'
    Assert-Equal 0 $LASTEXITCODE 'In-process adds ignore a stale native exit code'
    Assert-True (-not ($apply -join "`n").Contains("Run 'claude1' in a terminal and log in once.")) 'Setup keeps account add guidance out of its output'
    Assert-True (-not ($apply -join "`n").Contains('Existing account folder kept at')) 'Setup keeps adoption guidance out of its output'
    $agents = (Read-PsAiJson $settings).agents
    Assert-Equal 'claude1|codex1' ($agents.id -join '|') 'Fresh apply records both accounts'
    Assert-Equal 2 $installs.Count 'Installer runs once per account folder'
    Assert-Equal $adopt $installs[1].ConfigDir 'Installer receives the whole adopted path'
    Assert-Equal 'keep login data' (Get-Content (Join-Path $adopt 'owner.txt')) 'Adoption preserves existing data'
    Assert-SetupText $apply 'account  tool  folder  ps-ai  next step' 'Table has the contract columns'
    Assert-SetupText $apply 'log in: run claude1' 'New folder asks for login'
    Assert-SetupText $apply 'ready' 'Adopted folder is ready'
    $bin = Join-Path $testHome '.legion/bin'
    foreach ($entry in (Get-PsAiOwnerCommands).GetEnumerator()) {
        $target = Join-Path $root "plugins/ps-ai/bin/$($entry.Value)"
        Assert-Equal (Get-PsAiShimText -Script $target) ([IO.File]::ReadAllText((Join-Path $bin $entry.Key))) 'Unix command shim equals shared format'
        if ($IsWindows) {
            Assert-Equal (Get-PsAiShimText -Script $target -Windows) ([IO.File]::ReadAllText((Join-Path $bin "$($entry.Key).cmd"))) 'Windows command shim equals shared format'
        }
    }
    Assert-Equal $(if ($IsWindows) { 1 } else { 0 }) $pathWrites.Count 'Only Windows writes user PATH'
    if ($IsWindows) { Assert-Equal "fixture-path;$bin" $pathWrites[0] 'User PATH appends bin' }
    else {
        Assert-SetupText $apply 'add to your shell profile: export PATH="$HOME/.legion/bin:$PATH"' 'Unix prints the profile instruction'
        $env:PATH += [IO.Path]::PathSeparator + $bin
    }
    $before = Get-SetupTree $testHome
    $repeat = @(Invoke-Setup -HomeRoot $testHome -Yes)
    Assert-Equal $before (Get-SetupTree $testHome) 'Repeated apply preserves all bytes and timestamps'
    Assert-Equal 2 $installs.Count 'Repeat does not reinstall ps-ai'
    Assert-Equal 0 $toolInstalls.Count 'Repeat installs no CLI'
    Assert-Equal $(if ($IsWindows) { 1 } else { 0 }) $pathWrites.Count 'Repeat writes no PATH'
    Assert-SetupText $repeat 'skip: ps-ai in ' 'Repeat reports installed folders'
    Assert-SetupText $repeat 'account  tool  folder  ps-ai  next step' 'Repeat keeps the table'
    Assert-Equal ($apply | Where-Object { $_.StartsWith('claude1  ') }) ($repeat | Where-Object { $_.StartsWith('claude1  ') }) 'Repeat retains new-folder login guidance'
    Assert-Equal 'Nothing to do.' (@(Invoke-Setup -HomeRoot $testHome)[-1]) 'Finished account setup needs no changes'
    $next = @(Invoke-Setup -HomeRoot $testHome -Add claude)
    Assert-SetupText $next 'add      claude2' 'Recorded claude1 makes next id claude2'

    Reset-SetupTest 'rejections'
    $before = Get-SetupTree $testHome
    Assert-Throws { Invoke-Setup -HomeRoot $testHome -Add @('claude', 'codex') -Id chosen -Yes } 'Custom id needs exactly one add'
    foreach ($id in (Get-PsAiOwnerCommands).Keys) {
        Assert-Throws { Invoke-Setup -HomeRoot $testHome -Add claude -Id $id -Yes } 'Reserved id rejected'
    }
    Assert-Throws { Invoke-Setup -HomeRoot $testHome -Add @('claude', "codex:$(Join-Path $testHome 'missing')") -Yes } 'Missing adopted folder rejected'
    Assert-Equal $before (Get-SetupTree $testHome) 'All bad input is rejected before any change'
    Assert-Equal 0 $pathWrites.Count 'Bad input does not write PATH'
    Assert-Equal 0 $installs.Count 'Bad input does not install'

    Reset-SetupTest 'account-error'
    $script:wrapperCalls.Clear()
    function New-PsAiWrappers {
        param($Id, $Tool, $HomeRoot, $RealCommand, $ConfigDir, [switch]$CheckOnly)
        $script:wrapperCalls.Add($Id)
        throw "fixture add failure`r`nsecond line"
    }
    $addError = $null
    try { Invoke-Setup -HomeRoot $testHome -Add @('claude', 'codex') -Yes | Out-Null }
    catch { $addError = $_.Exception.Message }
    finally { Set-Item -Path function:New-PsAiWrappers -Value $realNewWrappers }
    Assert-Equal 'fixture add failure  second line' $addError 'Account add errors stop setup with the same one-line message'
    Assert-Equal 'claude1' ($wrapperCalls -join '|') 'Account add failure stops before the next account'
    Assert-Equal 0 (@((Read-PsAiJson $settings).agents).Count) 'Failed wrapper validation records no account'
    Assert-Equal 0 $installs.Count 'Account add failure stops before plugin installs'
    Assert-Equal 0 $pathWrites.Count 'Account add failure stops before PATH writes'
    Assert-True (-not (Test-Path (Join-Path $testHome '.legion/bin/ps-ai-setup'))) 'Account add failure stops before owner commands'

    Reset-SetupTest 'partial'
    Invoke-Setup -HomeRoot $testHome -Add claude -Id claude1 -Yes | Out-Null
    $folder = (Read-PsAiJson $settings).agents[0].configDir
    $cache = Join-Path $folder (Get-PsAiTool claude).plugin.installedRoot
    # This cache is a fixture folder created under this test's home.
    Assert-True ([IO.Path]::GetFullPath($cache).StartsWith([IO.Path]::GetFullPath($testHome))) 'Fixture cache stays under test home'
    Remove-Item -LiteralPath $cache -Recurse -Force
    if (-not $IsWindows) { $env:PATH += [IO.Path]::PathSeparator + (Join-Path $testHome '.legion/bin') }
    $plan = @(Invoke-Setup -HomeRoot $testHome)
    Assert-Equal 3 $plan.Count 'Partial earlier run plans only the install'
    Assert-SetupText $plan "  install  ps-ai into $folder" 'Partial setup installs into recorded folder'
    Invoke-Setup -HomeRoot $testHome -Yes | Out-Null
    Assert-Equal 2 $installs.Count 'Partial setup is resumed without Add'
    $repeat = @(Invoke-Setup -HomeRoot $testHome -Add claude -Id claude1 -Yes)
    Assert-SetupText $repeat 'skip: account claude1 (already done)' 'Explicit id repeat skips'
    Assert-Equal 2 $installs.Count 'Explicit repeat does not reinstall'
    $adoptedPlan = @(Invoke-Setup -HomeRoot $testHome -Add "claude:$folder" -Id adopted -Yes)
    Assert-SetupText $adoptedPlan "skip: ps-ai in $folder (already done)" 'Adopted current plugin is skipped'

    foreach ($scenario in @('success', 'failure', 'terminal')) {
        Reset-SetupTest "cli-$scenario"
        $c2 = Join-Path $testHome 'c2'
        New-Item -ItemType Directory -Path $c2 -Force | Out-Null
        $script:missingTools = @('codex')
        $script:toolFailure = $scenario -eq 'failure'
        $script:needsTerminal = $scenario -eq 'terminal'
        $plan = @(Invoke-Setup -HomeRoot $testHome -Add @('codex', "codex:$c2", 'claude'))
        Assert-SetupText $plan 'cli      install codex' 'Missing CLI appears in plan'
        Assert-Equal 0 $toolInstalls.Count 'Plan never installs a CLI'
        $global:LASTEXITCODE = 7
        $output = @(Invoke-Setup -HomeRoot $testHome -Add @('codex', "codex:$c2", 'claude') -Yes)
        Assert-Equal 0 $LASTEXITCODE 'Recoverable install result exits zero'
        Assert-Equal 'codex' ($toolInstalls -join '|') 'Missing CLI installs once for several accounts'
        $agents = (Read-PsAiJson $settings).agents
        if ($scenario -eq 'success') {
            Assert-Equal 'codex1|codex2|claude1' ($agents.id -join '|') 'Rechecked CLI permits both accounts'
            Assert-Equal 3 $installs.Count 'All usable accounts install ps-ai'
        } else {
            Assert-Equal 'claude1' ($agents.id -join '|') 'Unusable CLI records no accounts while independent tool completes'
            Assert-Equal 1 $installs.Count 'Only usable CLI gets plugin installation'
            $expected = if ($scenario -eq 'failure') { 'codex install failed: fixture failure second line' } else { 'codex installed: open a new terminal, then repeat the add' }
            Assert-SetupText $output $expected 'CLI failure or terminal row explains next step'
            Assert-True (-not (Test-Path (Join-Path $testHome '.legion/agents/codex1'))) 'Unusable CLI does not create an account folder'
        }
    }

    Reset-SetupTest 'plugin-failure'
    $script:failFolder = Join-Path $testHome '.legion/agents/claude1'
    $output = @(Invoke-Setup -HomeRoot $testHome -Add @('claude', 'codex') -Yes)
    Assert-SetupText $output 'install failed: log in with claude1, then finish setup' 'Plugin failure gives login fallback'
    Assert-Equal 2 $installs.Count 'Next folder installs after plugin failure'
    Assert-Equal 0 $LASTEXITCODE 'Plugin failure is a recoverable table row'

    Reset-SetupTest 'commands'
    $bin = Join-Path $testHome '.legion/bin'
    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    $owned = Join-Path $bin 'ps-ai-status'
    $liveScript = Join-Path $testHome 'cache/bin/ps-ai-status.ps1'
    New-Item -ItemType Directory -Path (Split-Path $liveScript) -Force | Out-Null
    '' | Set-Content -LiteralPath $liveScript
    $oldText = Get-PsAiShimText -Script $liveScript
    [IO.File]::WriteAllText($owned, $oldText)
    $staleText = (Get-PsAiShimText -Script '/gone/cache/bin/ps-ai-setup.ps1').Replace(' "$@"', ' --keep "$@"')
    [IO.File]::WriteAllText((Join-Path $bin 'ps-ai-setup'), $staleText)
    [IO.File]::WriteAllText((Join-Path $bin 'legion'), 'owner command')
    $plan = @(Invoke-Setup -HomeRoot $testHome)
    Assert-SetupText $plan 'commands rewrite ps-ai-setup' 'C-2: the plan names a stale command'
    $output = @(Invoke-Setup -HomeRoot $testHome -Yes)
    Assert-Equal $oldText ([IO.File]::ReadAllText($owned)) 'Existing owned command with a live script is kept for refresh'
    $rewritten = [IO.File]::ReadAllText((Join-Path $bin 'ps-ai-setup'))
    Assert-True ($rewritten.Contains((Join-Path $root 'plugins/ps-ai/bin/ps-ai-setup.ps1')) -and $rewritten.Contains('--keep')) 'C-2: a stale command is retargeted and keeps owner flags'
    Assert-Equal 'owner command' ([IO.File]::ReadAllText((Join-Path $bin 'legion'))) 'Unrelated command stays unchanged'
    Assert-SetupText $output 'skip: command ps-ai-status (already done)' 'Existing owned command reports skip'
    Assert-SetupText $output 'Blocked commands: legion' 'Blocked command is listed after table'
    Assert-Equal 1 @($output | Where-Object { $_ -like '*legion*another file*' -or $_ -like 'Blocked commands:*' }).Count 'N3 a blocked command is reported once on apply'
    Reset-SetupTest 'finder-failure'
    $script:findCalls = 0
    function Find-SetupInstaller { $script:findCalls++; throw 'fixture download failure' }
    $output = @(Invoke-Setup -HomeRoot $testHome -Add @('claude', 'codex') -Yes)
    Assert-Equal 1 $findCalls 'Installer discovery failure is attempted only once for the run'
    Assert-Equal 0 $installs.Count 'A missing installer is never invoked'
    Assert-SetupText $output 'install failed: log in with claude1, then finish setup' 'Discovery failure produces first fallback row'
    Assert-SetupText $output 'install failed: log in with codex1, then finish setup' 'Discovery failure still produces next fallback row'

    # Search only in fixture roots, and replace download even while testing the real finder.
    Reset-SetupTest 'search'
    $script:SetupHomeRoot = $testHome
    $script:SetupPluginRoot = Join-Path $testHome 'clone/plugins/ps-ai'
    New-Item -ItemType Directory -Path $script:SetupPluginRoot -Force | Out-Null
    $clone = Join-Path $testHome 'clone/install.ps1'
    $claudeCopy = Join-Path $testHome '.claude/plugins/marketplaces/ps-ai-marketplace/install.ps1'
    $codexCopy = Join-Path $testHome '.codex/.tmp/marketplaces/ps-ai-marketplace/install.ps1'
    foreach ($path in @($clone, $claudeCopy, $codexCopy)) {
        New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
        'param([string]$HomeRoot) # inert' | Set-Content -LiteralPath $path
    }
    foreach ($expected in @($clone, $claudeCopy, $codexCopy)) {
        Assert-Equal ([IO.Path]::GetFullPath($expected)) (& $realFindInstaller) 'Installer search prefers next existing local copy'
        Remove-Item -LiteralPath $expected
    }
    $fallback = Join-Path $testHome '.legion/temp/install.ps1'
    Assert-Equal $fallback (& $realFindInstaller) 'Finder falls back to download under chosen home'
    Assert-Equal $fallback (& $realFindInstaller) 'Finder reuses download during the run'
    Assert-Equal 1 $downloads.Count 'Fallback downloads once'
    $script:SetupDownloadedInstaller = $null
    & $realFindInstaller | Out-Null
    Assert-Equal 2 $downloads.Count 'A new run refreshes a previously downloaded installer'

    # Exercise the real process boundary against an inert script: flags, closed stdin and captured output.
    $standIn = Join-Path $testHome 'stand in.ps1'
    @'
param([string]$Tools, [string]$ConfigDir, [string]$HomeRoot, [switch]$Update, [switch]$Yes)
@{ Tools=$Tools; ConfigDir=$ConfigDir; HomeRoot=$HomeRoot; Update=[bool]$Update; Yes=[bool]$Yes; StdinClosed=([Console]::In.ReadToEnd() -eq '') } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ConfigDir 'args.json')
'inert installer output'
exit 3
'@ | Set-Content -LiteralPath $standIn
    $code = & $realInvokeInstaller -Installer $standIn -Tool codex -ConfigDir $testHome
    Assert-Equal 3 $code 'Installer seam returns child exit code'
    $bound = Read-PsAiJson (Join-Path $testHome 'args.json')
    Assert-Equal 'codex' $bound.Tools 'Installer receives -Tools'
    Assert-Equal $testHome $bound.ConfigDir 'Installer receives config folder intact'
    Assert-Equal $testHome $bound.HomeRoot 'K5 installer process receives the selected home'
    Assert-True ($bound.Update -and $bound.Yes -and $bound.StdinClosed) 'Installer receives update, consent and closed stdin'
    Assert-SetupText (Get-Content (Join-Path $testHome '.legion/temp/setup-install-codex.log')) 'inert installer output' 'Installer output goes to chosen-home log'
    Write-Output "Setup fake timings: plan $([math]::Round($planWatch.Elapsed.TotalSeconds, 3)) s; apply $([math]::Round($applyWatch.Elapsed.TotalSeconds, 3)) s"
} finally {
    $env:PATH = $savedPath
    # The generated absolute fixture root is inside the assigned worktree.
    if ([IO.Path]::GetFullPath($tempRoot).StartsWith([IO.Path]::GetFullPath((Join-Path $root '.agents/temp/')))) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
