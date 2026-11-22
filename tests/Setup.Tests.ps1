param([string]$Finding)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$setupScript = Join-Path $root 'plugins/legion/bin/legion-setup.ps1'
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
    $systemBin = if ($IsWindows) { Join-Path $env:SystemRoot 'System32' } else { '/bin:/usr/bin' }
    $fixturePath = @($fakeBin, (Split-Path (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source), $systemBin) -join [IO.Path]::PathSeparator
    $env:PATH = $fixturePath
    $version = (Get-Content (Join-Path $root 'plugins/legion/plugin.json') -Raw | ConvertFrom-Json).version

    # All machine, CLI and network seams are inert; account creation still runs the real add path.
    function Test-SetupCommand { param($Name) return ($Name -cnotin $script:missingTools) }
    function Test-SetupToolInstalled { param($Tool) return ($Tool -cnotin $script:missingTools) }
    function Get-InstallUserPath { return $script:userPath }
    function Get-InstallMachinePath { return '' }
    function Set-InstallUserPath { param($Path) $script:pathWrites.Add($Path); $script:userPath = $Path }
    function Find-SetupInstaller { return (Join-Path $tempRoot 'inert-installer.ps1') }
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
        $descriptor = Get-LegionTool -Tool $Tool
        $manifest = Join-Path $ConfigDir "$($descriptor.plugin.installedRoot)/$version/plugin.json"
        New-Item -ItemType Directory -Path (Split-Path $manifest) -Force | Out-Null
        @{ name = 'legion'; version = $version } | ConvertTo-Json | Set-Content -LiteralPath $manifest
        return 0
    }
    function Reset-SetupTest {
        param([string]$Name)
        $script:testHome = Join-Path $tempRoot $Name
        New-Item -ItemType Directory -Path $script:testHome -Force | Out-Null
        $script:settings = Join-Path $script:testHome '.legion/configuration/personalisation.json'
        $script:userPath = 'fixture-path'
        $script:pathWrites = [Collections.Generic.List[string]]::new()
        $script:toolInstalls = [Collections.Generic.List[string]]::new()
        $script:installs = [Collections.Generic.List[object]]::new()
        $script:missingTools = @()
        $script:toolFailure = $false
        $script:needsTerminal = $false
        $script:failFolder = ''
        $env:PATH = $fixturePath
    }

    $regressions = [ordered]@{
        AllowRule = {
            $rule = 'Bash(LEGION_ROLE=member *)'
            Reset-SetupTest 'allow-rule'
            $codexFolder = Join-Path $testHome '.legion/agents/codex1'
            $copilotFolder = Join-Path $testHome '.legion/agents/copilot1'
            # An adopted Claude folder keeps its other settings and allow entries.
            $adopted = Join-Path $testHome 'adopted-claude'
            New-Item -ItemType Directory -Path $adopted | Out-Null
            @{ model = 'opus'; permissions = @{ allow = @('Bash(git status)'); deny = @('Bash(rm *)') } } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $adopted 'settings.json')
            $plan = @(Invoke-Setup -HomeRoot $testHome -Add @('claude', "claude:$adopted", 'codex', 'copilot'))
            Assert-SetupText $plan 'permission' 'allow rule: plan shows the permission step'
            Assert-True (-not (Test-Path -LiteralPath $settings)) 'allow rule: plan writes nothing'
            Invoke-Setup -HomeRoot $testHome -Add @('claude', "claude:$adopted", 'codex', 'copilot') -Yes | Out-Null
            # The fake bin already has a claude1 command, so the new account gets another id; find it in the settings.
            $newClaude = @((Read-LegionJson $settings).agents | Where-Object { $_.tool -ceq 'claude' -and $_.configDir -notlike '*adopted-claude' })[0]
            $created = Read-LegionJson (Join-Path $newClaude.configDir 'settings.json')
            Assert-Equal $rule (@($created.permissions.allow) -join "|") 'allow rule: created settings hold the rule'
            $kept = Read-LegionJson (Join-Path $adopted 'settings.json')
            Assert-Equal "Bash(git status)|$rule" (@($kept.permissions.allow) -join '|') 'allow rule: existing allow entries stay and the rule is added'
            Assert-Equal 'opus' $kept.model 'allow rule: other settings stay'
            Assert-Equal 'Bash(rm *)' (@($kept.permissions.deny) -join '|') 'allow rule: other permission keys stay'
            foreach ($other in @($codexFolder, $copilotFolder)) {
                Assert-True (-not (Test-Path -LiteralPath (Join-Path $other 'settings.json'))) "allow rule: $(Split-Path $other -Leaf) gets no settings.json"
            }
            $before = Get-SetupTree $testHome
            $repeat = @(Invoke-Setup -HomeRoot $testHome -Yes)
            Assert-SetupText $repeat 'skip: permission' 'allow rule: repeat prints a skip'
            Assert-Equal $before (Get-SetupTree $testHome) 'allow rule: repeat changes nothing'
            Assert-Equal 1 @((Read-LegionJson (Join-Path $adopted 'settings.json')).permissions.allow | Where-Object { $_ -ceq $rule }).Count 'allow rule: never duplicated'
        }
        R5B4 = {
            Reset-SetupTest "unbound owner's home"
            Invoke-Setup -HomeRoot $testHome -Yes | Out-Null
            $originals = [ordered]@{}
            foreach ($entry in (Get-LegionOwnerCommands).GetEnumerator()) {
                $live = Join-Path $testHome "other cache/bin/$($entry.Value)"
                New-Item -ItemType Directory -Path (Split-Path $live) -Force | Out-Null
                '# inert live script' | Set-Content -LiteralPath $live
                foreach ($suffix in $(if ($IsWindows) { @('', '.cmd') } else { @('') })) {
                    $windows = $suffix -eq '.cmd'
                    $path = Join-Path $testHome ".legion/bin/$($entry.Key)$suffix"
                    $flags = if ($windows) { ' -Repo "\\server\team$\work folder" %*' } else { ' -Repo ''work folder'' "$@"' }
                    $forward = if ($windows) { ' %*' } else { ' "$@"' }
                    $text = (Get-LegionShimText -Script $live -Windows:$windows).Replace($forward, $flags)
                    [IO.File]::WriteAllText($path, $text)
                    $originals[$path] = @{ Text = $text; Windows = $windows; Flags = $flags }
                }
            }
            $before = Get-SetupTree $testHome
            $plan = @(Invoke-Setup -HomeRoot $testHome)
            Assert-Equal $before (Get-SetupTree $testHome) 'R5 B4 binding plan writes nothing'
            Invoke-Setup -HomeRoot $testHome -Yes | Out-Null
            foreach ($path in $originals.Keys) {
                $original = $originals[$path]
                $text = [IO.File]::ReadAllText($path)
                Assert-Equal (Get-LegionShimText -Script (Join-Path $root 'plugins/legion/bin/legion.ps1') -HomeRoot $testHome -Windows:$original.Windows) $text 'Setup rewrites the marked command whole'
            }
            $before = Get-SetupTree $testHome
            Invoke-Setup -HomeRoot $testHome -Yes | Out-Null
            Assert-Equal $before (Get-SetupTree $testHome) 'R5 B4 bound repeat preserves bytes and timestamps'
        }
        R5B3 = {
            foreach ($kind in @('stock', 'custom')) {
                Reset-SetupTest "missing-$kind-target"
                Initialize-SetupFiles -Plan (Get-SetupPlan -HomeRoot $testHome) | Out-Null
                $targetName = if ($kind -eq 'stock') { if ($IsWindows) { 'codex.cmd' } else { 'codex' } } else { 'custom command.ps1' }
                $target = Join-Path $testHome $targetName
                '# inert target' | Set-Content -LiteralPath $target
                $data = Read-LegionJson $settings
                Add-LegionSubscriptionAccount -Id recover-a -Tool codex -Command $target -HomeRoot $testHome -Data $data -Path $settings | Out-Null
                $wrapper = Join-Path $testHome '.legion/bin/recover-a'
                $repairPath = $wrapper
                if ($IsWindows) { $repairPath = "$wrapper.cmd"; Remove-Item -LiteralPath $repairPath }
                else { [IO.File]::SetUnixFileMode($wrapper, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite) }
                Remove-Item -LiteralPath $target
                $script:missingTools = @('codex')
                $before = Get-SetupTree $testHome
                $plan = @(Invoke-Setup -HomeRoot $testHome)
                Assert-SetupText $plan 'target needed: recover-a' "R5 B3 missing $kind target needs owner repair in the plan"
                Assert-Equal $before (Get-SetupTree $testHome) 'R5 B3 missing-target plan writes nothing'
                $output = @(Invoke-Setup -HomeRoot $testHome -Yes)
                Assert-SetupText $output 'target needed: recover-a' "R5 B3 missing $kind target needs owner repair on apply"
                Assert-Equal $false (Test-LegionLauncherExecutable $repairPath) 'R5 B3 setup never repairs a wrapper toward a missing executable'
                Assert-Equal 0 $installs.Count 'R5 B3 missing target never reaches plugin installation'
            }
        }
        R4B4 = {
            Reset-SetupTest "bound owner's home"
            Invoke-Setup -HomeRoot $testHome -Yes | Out-Null
            $bin = Join-Path $testHome '.legion/bin'
            $legion = Join-Path $bin $(if ($IsWindows) { 'legion.cmd' } else { 'legion' })
            Assert-True ([IO.File]::ReadAllText($legion).Contains('-HomeRoot ')) 'R4 B4 generated command binds its home before execution'
            $status = @(& $legion status)
            Assert-True ($status -notcontains 'no legion settings yet') 'R4 B4 generated legion reads the selected home settings'
            Assert-True ($status -contains 'commands: yes') 'R4 B4 generated legion inspects the selected commands'
            foreach ($entry in (Get-LegionOwnerCommands).GetEnumerator()) {
                $path = Join-Path $bin $entry.Key
                $text = [IO.File]::ReadAllText($path)
                Assert-True ($text.Contains('-HomeRoot ' + (ConvertTo-LegionShellLiteral $testHome))) 'R4 B4 every alternate-home shell command binds its home'
            }
            $runner = Join-Path $root 'plugins/legion/bin/legion.ps1'
            Assert-Equal (Get-LegionShimText -Script $runner) (Get-LegionShimText -Script $runner -HomeRoot $HOME) 'R4 B4 default-home shim stays unchanged'
        }
        R4B3 = {
            foreach ($addStockAccount in @($false, $true)) {
                Reset-SetupTest "independent-wrapper-$addStockAccount"
                Initialize-SetupFiles -Plan (Get-SetupPlan -HomeRoot $testHome) | Out-Null
                $custom = Join-Path $testHome 'custom command.ps1'
                '# inert custom command' | Set-Content $custom
                $data = Read-LegionJson $settings
                Add-LegionSubscriptionAccount -Id custom-a -Tool codex -Command $custom -HomeRoot $testHome -Data $data -Path $settings | Out-Null
                $wrapper = Join-Path $testHome '.legion/bin/custom-a'
                $repairPath = $wrapper
                if ($IsWindows) { $repairPath = "$wrapper.cmd"; Remove-Item $repairPath }
                else { [IO.File]::SetUnixFileMode($wrapper, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite) }
                $script:missingTools = @('codex')
                $script:toolFailure = $true
                $adds = if ($addStockAccount) { @('codex') } else { @() }
                Invoke-Setup -HomeRoot $testHome -Add $adds -Yes | Out-Null
                Assert-True (Test-LegionLauncherExecutable $repairPath) 'R4 B3 custom wrapper repairs independently of stock CLI failure'
                Assert-Equal ([int]$addStockAccount) $toolInstalls.Count 'R4 B3 stock install is needed only by the new stock account'
                Assert-Equal $custom (Get-LegionWrapperTarget -Id custom-a -Tool codex -HomeRoot $testHome -ConfigDir (Get-LegionNewAccountDir custom-a $testHome)) 'R4 B3 repair preserves the recovered custom executable'
            }
        }
        R4B1 = {
            Reset-SetupTest 'broken-node'
            & {
                function Test-SetupToolInstalled { param($Tool) & $realToolInstalled -Tool $Tool }
                . (Join-Path $root 'plugins/legion/bin/legion-install-tool.ps1') -NoRun
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
                $global:LASTEXITCODE = 0
                $hint = Get-SetupToolInstallHint -Tool (Get-LegionTool codex) -Platform macos
                Assert-Equal 0 $LASTEXITCODE 'R4 B1 prerequisite discovery preserves the caller exit code'
                Assert-Equal 'brew install node; npm install -g @openai/codex' $hint 'R4 B1 consent includes repair of a broken Node command'
                Invoke-ToolInstall -Tool codex -Platform macos -Yes | Out-Null
                Assert-Equal $hint ($probe.Commands -join '; ') 'R4 B1 apply matches consent for broken Node'
            }
        }

        K7 = {
            Reset-SetupTest 'prerequisite-plan'
            $script:missingTools = @('node', 'codex')
            $hint = Get-SetupToolInstallHint -Tool (Get-LegionTool codex) -Platform macos
            Assert-Equal 'brew install node; npm install -g @openai/codex' $hint 'K7 macOS consent includes missing Node before npm'
            $script:missingTools = @('codex')
            $hint = Get-SetupToolInstallHint -Tool (Get-LegionTool codex) -Platform macos
            Assert-Equal 'npm install -g @openai/codex' $hint 'K7 installed prerequisites are omitted'
            & {
                . (Join-Path $root 'plugins/legion/bin/legion-install-tool.ps1') -NoRun
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
            $data = Read-LegionJson $settings
            Add-LegionSubscriptionAccount -Id custom-a -Tool codex -Command $custom -ConfigDir $folder -HomeRoot $testHome -Data $data -Path $settings | Out-Null
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
            Assert-SetupText $plan 'wrappers repair custom-a' 'Absent wrappers use the stock CLI in the plan'
            $output = @(Invoke-Setup -HomeRoot $testHome -Yes)
            Assert-True (Test-Path $sh) 'Setup restores an account whose launchers are gone'
            Assert-SetupText $output "wrote: launcher $sh" 'Setup reports the launcher it repaired'
            Assert-True (-not ($output -contains 'skip: account custom-a (already done)')) 'Setup does not report a repaired account as unchanged'
            $stock = Join-Path $fakeBin $(if ($IsWindows) { 'codex.cmd' } else { 'codex' })
            Assert-Equal $stock (Get-LegionWrapperTarget -Id custom-a -Tool codex -HomeRoot $testHome -ConfigDir $folder) 'Absent launchers fall back to the stock CLI'
            Remove-Item $sh
            if ($IsWindows) { Remove-Item $cmd }
            $env:PATH = $systemBin
            $plan = @(Invoke-Setup -HomeRoot $testHome)
            Assert-SetupText $plan 'target needed: custom-a' 'Setup still asks for a target when the stock CLI is absent'
        }
        G1 = {
            Reset-SetupTest 'interrupted-chmod'
            Invoke-Setup -HomeRoot $testHome -Add codex -Yes | Out-Null
            $account = Join-Path $testHome '.legion/bin/codex1'
            $command = Join-Path $testHome '.legion/bin/legion'
            $before = [IO.File]::ReadAllText($account)
            $realExecutable = ${function:Test-LegionLauncherExecutable}
            $realWrite = ${function:Write-LegionGeneratedFile}
            $repair = @{ Pending = @($account, $command); Fixed = [Collections.Generic.List[string]]::new() }
            function Test-LegionLauncherExecutable {
                param($Path)
                if ($Path -in $repair.Pending) { return $false }
                return & $realExecutable -Path $Path
            }
            function Write-LegionGeneratedFile {
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
                Set-Item function:Test-LegionLauncherExecutable $realExecutable
                Set-Item function:Write-LegionGeneratedFile $realWrite
            }
        }
        G6 = {
            Reset-SetupTest 'alternate home with spaces'
            if (-not $IsWindows) {
                $plan = @{ Bin = (Join-Path $testHome '.legion/bin'); HomeRoot = $testHome }
                $profile = Get-LegionShellProfile -HomeRoot $testHome
                Assert-SetupText @(Get-SetupPathHint -Plan $plan) $profile.Path 'G6 shell plan names the selected home profile'
                Set-SetupPath -Plan $plan | Out-Null
                $command = 'HOME=' + (ConvertTo-LegionShellLiteral $testHome) + '; . ' + (ConvertTo-LegionShellLiteral $profile.Path) + '; printf "%s" "$PATH"'
                $actual = & /bin/sh -c $command
                Assert-Equal ($plan.Bin + ':' + $fixturePath) $actual 'G6 sourcing the profile adds the alternate home bin with spaces'
            }
        }
        B1 = {
            Reset-SetupTest 'adopt-repeat'
            $folder = Join-Path $testHome 'existing'
            New-Item -ItemType Directory -Path $folder | Out-Null
            Invoke-Setup -HomeRoot $testHome -Add "codex:$folder" -Yes | Out-Null
            $before = Get-SetupTree $testHome
            $output = @(Invoke-Setup -HomeRoot $testHome -Add "codex:$folder" -Yes)
            Assert-Equal 1 (@((Read-LegionJson $settings).agents).Count) 'B1 repeated adoption reuses the account'
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
            Assert-Equal 1 (@((Read-LegionJson $settings).agents).Count) 'B1 duplicate new adoption is recorded once'
        }
        B2 = {
            Reset-SetupTest 'wrapper-repair'
            $realWrappers = ${function:New-LegionWrappers}
            function New-LegionWrappers {
                param($Id, $Tool, $HomeRoot, $RealCommand, $ConfigDir, [switch]$CheckOnly)
                if (-not $CheckOnly) { throw 'fixture interrupted wrapper write' }
                & $realWrappers @PSBoundParameters
            }
            try { Assert-Throws { Invoke-Setup -HomeRoot $testHome -Add codex -Yes } 'B2 interruption after settings is reproducible' }
            finally { Set-Item function:New-LegionWrappers $realWrappers }
            Assert-Equal 1 (@((Read-LegionJson $settings).agents).Count) 'B2 interruption leaves a recorded account'
            $plan = @(Invoke-Setup -HomeRoot $testHome)
            Assert-SetupText $plan 'wrappers repair codex1' 'B2 plan repairs the account with the stock CLI'
            $wrapper = Get-LegionWrapperCommand codex1 $testHome
            $output = @(Invoke-Setup -HomeRoot $testHome -Yes)
            Assert-True (Test-Path -LiteralPath $wrapper) 'B2 setup recovers after interruption before either launcher was written'
            $data = Read-LegionJson $settings
            Add-LegionSubscriptionAccount -Id codex1 -Tool codex -Command (Join-Path $fakeBin $(if ($IsWindows) { 'codex.cmd' } else { 'codex' })) -HomeRoot $testHome -Data $data -Path $settings | Out-Null
            Assert-True (Test-Path -LiteralPath $wrapper) 'B2 finish setup repairs interrupted account wrappers'
            Remove-Item -LiteralPath $wrapper
            if ($IsWindows) { Invoke-Setup -HomeRoot $testHome -Add codex -Id codex1 -Yes | Out-Null }
            else {
                Add-LegionSubscriptionAccount -Id codex1 -Tool codex -Command (Join-Path $fakeBin 'codex') -HomeRoot $testHome -Data $data -Path $settings | Out-Null
                # The Windows run above also installs the plugin for the account; do it here once, so the repeat below has nothing left to do.
                Invoke-Setup -HomeRoot $testHome -Yes | Out-Null
            }
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
            function Get-InstallMachinePath { return '' }
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
                Assert-Equal 1 (@((Read-LegionJson $settings).agents).Count) 'B3 apply can use a CLI discovered on fixture user PATH'
                $probe = Join-Path $testHome 'probe.ps1'
                '$env:PATH' | Set-Content -LiteralPath $probe
                $env:PATH = $before
                $result = Invoke-SetupProcess -Arguments @('-NoProfile', '-File', $probe)
                Assert-True (Test-LegionPathEntry -Path $result.Output.Trim() -Folder $fakeBin) 'B3 installer children can find freshly installed CLI folders'
                Assert-Equal $before $env:PATH 'B3 child PATH refresh leaves calling PATH unchanged'
            } finally { Set-Item function:Test-SetupCommand $fakeProbe }
        }
        B5 = {
            Reset-SetupTest 'install-hints'
            $script:missingTools = @('copilot')
            $plan = @(Invoke-Setup -HomeRoot $testHome -Add copilot)
            Assert-SetupText $plan 'npm install -g @github/copilot' 'B5 Copilot plan uses npm when node is available'
            foreach ($platform in @('linux', 'macos')) {
                $tool = Get-LegionTool claude
                $hint = Get-SetupToolInstallHint -Tool $tool -Platform $platform
                Assert-Equal ($tool.install.$platform.commands[0] -join ' ') $hint 'B5 Claude hint uses the platform recipe'
            }
            $script:missingTools = @('node')
            $hint = Get-SetupToolInstallHint -Tool (Get-LegionTool copilot) -Platform windows
            Assert-Equal 'winget install --id GitHub.Copilot -e --source winget --accept-source-agreements --accept-package-agreements' $hint 'B5 Copilot fallback uses the Windows recipe'
        }
        B6 = {
            Reset-SetupTest 'case-cache'
            # Exercise case-sensitive path semantics even on Windows; the installer is inert.
            function Get-LegionPathComparer { return [StringComparer]::Ordinal }
            $tool = Get-LegionTool codex
            $rows = @('account', 'ACCOUNT', 'account') | ForEach-Object {
                [pscustomobject]@{ Id = 'codex-a'; Tool = $tool; Folder = (Join-Path $testHome $_); Version = $null; Usable = $true; NextStep = 'ready' }
            }
            $plan = @{ Accounts = $rows; Version = $version; HomeRoot = $testHome }
            $script:SetupHomeRoot = $testHome
            Install-SetupPlugins -Plan $plan | Out-Null
            Assert-Equal 2 $installs.Count 'B6 case-sensitive folders install separately and exact duplicates install once'
        }
        B7 = {
            # Setup installs only where legion is missing; a different version is the update flow's job.
            foreach ($delivered in @('0.5.0', '9.0.0')) {
                Reset-SetupTest ("version-" + $delivered)
                $currentVersion = $version
                $version = $delivered
                Invoke-Setup -HomeRoot $testHome -Add codex -Yes | Out-Null
                $version = $currentVersion
                $before = Get-SetupTree $testHome
                $output = @(Invoke-Setup -HomeRoot $testHome -Yes)
                Assert-Equal 1 $installs.Count "B7 folder with version $delivered is not installed again"
                Assert-SetupText $output 'skip: legion in' "B7 repeat with version $delivered prints skip"
                Assert-Equal $before (Get-SetupTree $testHome) "B7 repeat with version $delivered changes nothing"
                $plan = @(Invoke-Setup -HomeRoot $testHome)
                Assert-True (-not (($plan -join "`n") -match 'install  legion')) "B7 plan skips folder with version $delivered"
            }
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
            $realAdd = ${function:Add-LegionSubscriptionAccount}
            $script:addArguments = $null
            function Add-LegionSubscriptionAccount {
                param($Id, $Tool, $HomeRoot, $Data, $Path, $ConfigDir, $Command)
                $script:addArguments = $PSBoundParameters
            }
            $managed = Get-LegionNewAccountDir -Id 'codex1' -HomeRoot $testHome
            $row = [pscustomobject]@{ Id = 'codex1'; Tool = @{ id = 'codex'; command = 'codex' }; Folder = $managed.ToUpperInvariant()
                Requested = $true; New = $false; Adopted = $false; Usable = $true; MissingWrappers = $false; Provider = $null; NextStep = '' }
            try { Add-SetupAccounts -Plan ([pscustomobject]@{ HomeRoot = $testHome; Accounts = @($row) }) | Out-Null }
            finally { Set-Item -Path function:Add-LegionSubscriptionAccount -Value $realAdd }
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
    foreach ($text in @('Plan (nothing changed yet):', '  create   settings and notes', '  commands write legion', '  path     ', 'Run again with -Yes to apply.')) {
        Assert-SetupText $plan $text 'Fresh empty plan has the contract lines'
    }
    Assert-Equal $before (Get-SetupTree $testHome) 'Plan changes no home bytes or timestamps'
    $apply = @(Invoke-Setup -HomeRoot $testHome -Yes)
    Assert-Equal 0 (@(Invoke-LegionValidation -Kind personalisation -Path $settings).Count) 'Empty settings are valid'
    Assert-Equal 0 (@((Read-LegionJson $settings).agents).Count) 'Fresh setup supports no accounts'
    Assert-Equal ([IO.File]::ReadAllText((Join-Path $root 'plugins/legion/skills/legion-personalisation/references/notes-template.md'))) ([IO.File]::ReadAllText((Join-Path (Split-Path $settings) 'notes.md'))) 'Notes use the unchanged template'
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
    Assert-SetupText $plan '  install  legion into ' 'Plan groups plugin installs'
    Assert-Equal $before (Get-SetupTree $testHome) 'Account plan changes no bytes or timestamps'
    Remove-Item -LiteralPath (Join-Path $fakeBin $(if ($IsWindows) { 'claude1.cmd' } else { 'claude1' }))
    $realNewWrappers = ${function:New-LegionWrappers}
    $script:wrapperCalls = [Collections.Generic.List[string]]::new()
    function New-LegionWrappers {
        param($Id, $Tool, $HomeRoot, $RealCommand, $ConfigDir, [switch]$CheckOnly)
        $script:wrapperCalls.Add($Id)
        & $realNewWrappers @PSBoundParameters
    }
    $global:LASTEXITCODE = 7
    $applyWatch = [Diagnostics.Stopwatch]::StartNew()
    $apply = @(Invoke-Setup -HomeRoot $testHome -Add @('claude', "codex:$adopt") -Yes)
    $applyWatch.Stop()
    Set-Item -Path function:New-LegionWrappers -Value $realNewWrappers
    Assert-Equal 'claude1|claude1|codex1|codex1' ($wrapperCalls -join '|') 'Each account validates and creates wrappers in this process'
    Assert-Equal 0 $LASTEXITCODE 'In-process adds ignore a stale native exit code'
    Assert-True (-not ($apply -join "`n").Contains("Run 'claude1' in a terminal and log in once.")) 'Setup keeps account add guidance out of its output'
    Assert-True (-not ($apply -join "`n").Contains('Existing account folder kept at')) 'Setup keeps adoption guidance out of its output'
    $agents = (Read-LegionJson $settings).agents
    Assert-Equal 'claude1|codex1' ($agents.id -join '|') 'Fresh apply records both accounts'
    Assert-Equal 2 $installs.Count 'Installer runs once per account folder'
    Assert-Equal $adopt $installs[1].ConfigDir 'Installer receives the whole adopted path'
    Assert-Equal 'keep login data' (Get-Content (Join-Path $adopt 'owner.txt')) 'Adoption preserves existing data'
    Assert-SetupText $apply 'account  tool  folder  legion  next step' 'Table has the contract columns'
    Assert-SetupText $apply 'log in: run claude1' 'New folder asks for login'
    Assert-SetupText $apply 'ready' 'Adopted folder is ready'
    $bin = Join-Path $testHome '.legion/bin'
    foreach ($entry in (Get-LegionOwnerCommands).GetEnumerator()) {
        $target = Join-Path $root "plugins/legion/bin/$($entry.Value)"
        Assert-Equal (Get-LegionShimText -Script $target -HomeRoot $testHome) ([IO.File]::ReadAllText((Join-Path $bin $entry.Key))) 'Unix command shim equals shared format'
        if ($IsWindows) {
            Assert-Equal (Get-LegionShimText -Script $target -Windows -HomeRoot $testHome) ([IO.File]::ReadAllText((Join-Path $bin "$($entry.Key).cmd"))) 'Windows command shim equals shared format'
        }
    }
    Assert-Equal $(if ($IsWindows) { 1 } else { 0 }) $pathWrites.Count 'Only Windows writes user PATH'
    if ($IsWindows) { Assert-Equal "fixture-path;$bin" $pathWrites[0] 'User PATH appends bin' }
    else {
        Assert-True (Get-LegionShellProfile -HomeRoot $testHome).HasPath 'R4 B6 Unix apply writes the fixture profile'
    }
    $before = Get-SetupTree $testHome
    $repeat = @(Invoke-Setup -HomeRoot $testHome -Yes)
    Assert-Equal $before (Get-SetupTree $testHome) 'Repeated apply preserves all bytes and timestamps'
    Assert-Equal 2 $installs.Count 'Repeat does not reinstall legion'
    Assert-Equal 0 $toolInstalls.Count 'Repeat installs no CLI'
    Assert-Equal $(if ($IsWindows) { 1 } else { 0 }) $pathWrites.Count 'Repeat writes no PATH'
    Assert-SetupText $repeat 'skip: legion in ' 'Repeat reports installed folders'
    Assert-SetupText $repeat 'account  tool  folder  legion  next step' 'Repeat keeps the table'
    Assert-Equal ($apply | Where-Object { $_.StartsWith('claude1  ') }) ($repeat | Where-Object { $_.StartsWith('claude1  ') }) 'Repeat retains new-folder login guidance'
    Assert-Equal 'Nothing to do.' (@(Invoke-Setup -HomeRoot $testHome)[-1]) 'Finished account setup needs no changes'
    $next = @(Invoke-Setup -HomeRoot $testHome -Add claude)
    Assert-SetupText $next 'add      claude2' 'Recorded claude1 makes next id claude2'

    Reset-SetupTest 'rejections'
    $before = Get-SetupTree $testHome
    Assert-Throws { Invoke-Setup -HomeRoot $testHome -Add @('claude', 'codex') -Id chosen -Yes } 'Custom id needs exactly one add'
    foreach ($id in (Get-LegionOwnerCommands).Keys) {
        Assert-Throws { Invoke-Setup -HomeRoot $testHome -Add claude -Id $id -Yes } 'Reserved id rejected'
    }
    Assert-Throws { Invoke-Setup -HomeRoot $testHome -Add @('claude', "codex:$(Join-Path $testHome 'missing')") -Yes } 'Missing adopted folder rejected'
    Assert-Equal $before (Get-SetupTree $testHome) 'All bad input is rejected before any change'
    Assert-Equal 0 $pathWrites.Count 'Bad input does not write PATH'
    Assert-Equal 0 $installs.Count 'Bad input does not install'

    Reset-SetupTest 'account-error'
    $script:wrapperCalls.Clear()
    function New-LegionWrappers {
        param($Id, $Tool, $HomeRoot, $RealCommand, $ConfigDir, [switch]$CheckOnly)
        $script:wrapperCalls.Add($Id)
        throw "fixture add failure`r`nsecond line"
    }
    $addError = $null
    try { Invoke-Setup -HomeRoot $testHome -Add @('claude', 'codex') -Yes | Out-Null }
    catch { $addError = $_.Exception.Message }
    finally { Set-Item -Path function:New-LegionWrappers -Value $realNewWrappers }
    Assert-Equal 'fixture add failure  second line' $addError 'Account add errors stop setup with the same one-line message'
    Assert-Equal 'claude1' ($wrapperCalls -join '|') 'Account add failure stops before the next account'
    Assert-Equal 0 (@((Read-LegionJson $settings).agents).Count) 'Failed wrapper validation records no account'
    Assert-Equal 0 $installs.Count 'Account add failure stops before plugin installs'
    Assert-Equal 0 $pathWrites.Count 'Account add failure stops before PATH writes'

    Reset-SetupTest 'partial'
    Invoke-Setup -HomeRoot $testHome -Add claude -Id claude1 -Yes | Out-Null
    $folder = (Read-LegionJson $settings).agents[0].configDir
    $cache = Join-Path $folder (Get-LegionTool claude).plugin.installedRoot
    # This cache is a fixture folder created under this test's home.
    Assert-True ([IO.Path]::GetFullPath($cache).StartsWith([IO.Path]::GetFullPath($testHome))) 'Fixture cache stays under test home'
    Remove-Item -LiteralPath $cache -Recurse -Force
    if (-not $IsWindows) { $env:PATH += [IO.Path]::PathSeparator + (Join-Path $testHome '.legion/bin') }
    $plan = @(Invoke-Setup -HomeRoot $testHome)
    Assert-Equal 3 $plan.Count 'Partial earlier run plans only the install'
    Assert-SetupText $plan "  install  legion into $folder" 'Partial setup installs into recorded folder'
    Invoke-Setup -HomeRoot $testHome -Yes | Out-Null
    Assert-Equal 2 $installs.Count 'Partial setup is resumed without Add'
    $repeat = @(Invoke-Setup -HomeRoot $testHome -Add claude -Id claude1 -Yes)
    Assert-SetupText $repeat 'skip: account claude1 (already done)' 'Explicit id repeat skips'
    Assert-Equal 2 $installs.Count 'Explicit repeat does not reinstall'
    $adoptedPlan = @(Invoke-Setup -HomeRoot $testHome -Add "claude:$folder" -Id adopted -Yes)
    Assert-SetupText $adoptedPlan "skip: legion in $folder (already done)" 'Adopted current plugin is skipped'

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
        $agents = (Read-LegionJson $settings).agents
        if ($scenario -eq 'success') {
            Assert-Equal 'codex1|codex2|claude1' ($agents.id -join '|') 'Rechecked CLI permits both accounts'
            Assert-Equal 3 $installs.Count 'All usable accounts install legion'
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
    $owned = Join-Path $bin 'legion'
    $liveScript = Join-Path $testHome 'cache/bin/legion.ps1'
    New-Item -ItemType Directory -Path (Split-Path $liveScript) -Force | Out-Null
    '' | Set-Content -LiteralPath $liveScript
    $oldText = (Get-LegionShimText -Script $liveScript).Replace(' "$@"', ' --owner-flag "$@"')
    [IO.File]::WriteAllText($owned, $oldText)
    $output = @(Invoke-Setup -HomeRoot $testHome -Yes)
    Assert-Equal (Get-LegionShimText -Script (Join-Path $root 'plugins/legion/bin/legion.ps1') -HomeRoot $testHome) ([IO.File]::ReadAllText($owned)) 'Setup rewrites the whole marked command and binds its home'
    $repeat = @(Invoke-Setup -HomeRoot $testHome -Yes)
    Assert-SetupText $repeat 'skip: command legion (already done)' 'R5 B4 bound live command reports skip on repeat'

    Reset-SetupTest 'stale-command'
    $bin = Join-Path $testHome '.legion/bin'
    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    $staleText = (Get-LegionShimText -Script '/gone/cache/bin/legion.ps1').Replace(' "$@"', ' --keep "$@"')
    [IO.File]::WriteAllText((Join-Path $bin 'legion'), $staleText)
    $plan = @(Invoke-Setup -HomeRoot $testHome)
    $null = Invoke-Setup -HomeRoot $testHome -Yes
    $rewritten = [IO.File]::ReadAllText((Join-Path $bin 'legion'))
    Assert-True ($rewritten.Contains((Join-Path $root 'plugins/legion/bin/legion.ps1')) -and -not $rewritten.Contains('--keep')) 'A marked command is rewritten without hand-added flags'

    Reset-SetupTest 'blocked-command'
    $bin = Join-Path $testHome '.legion/bin'
    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $bin 'legion'), 'owner command')
    $output = @(Invoke-Setup -HomeRoot $testHome -Yes)
    Assert-Equal 'owner command' ([IO.File]::ReadAllText((Join-Path $bin 'legion'))) 'Unrelated command stays unchanged'
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

    # -Source reaches the installer call only when given; the plan output stays the same.
    $fakeInstaller = ${function:Invoke-SetupInstaller}
    $realProcess = ${function:Invoke-SetupProcess}
    try {
        Set-Item function:Invoke-SetupInstaller $realInvokeInstaller
        function Find-SetupInstaller { return (Join-Path $tempRoot 'inert-installer.ps1') }
        function Invoke-SetupProcess { param([string[]]$Arguments) $script:processCalls.Add($Arguments); return @{ Code = 0; Output = '' } }
        $sourceFolder = Join-Path $tempRoot 'work/my-project'
        $sourceCases = @(
            @{ Name = 'folder'; Source = $sourceFolder; Expected = $sourceFolder }
            @{ Name = 'repo'; Source = 'owner/repo'; Expected = 'owner/repo' }
            @{ Name = 'none'; Source = $null; Expected = $null }
        )
        foreach ($case in $sourceCases) {
            Reset-SetupTest "source-$($case.Name)"
            $script:processCalls = [Collections.Generic.List[object]]::new()
            $sourceArguments = @{ HomeRoot = $testHome; Add = 'claude'; Yes = $true }
            if ($case.Source) { $sourceArguments.Source = $case.Source }
            Invoke-Setup @sourceArguments | Out-Null
            Assert-Equal 1 $processCalls.Count "Source $($case.Name): installer runs once"
            $call = @($processCalls[0])
            $position = [array]::IndexOf($call, '-Source')
            if ($case.Expected) {
                Assert-True ($position -ge 0 -and $call[$position + 1] -ceq $case.Expected) "Source $($case.Name): installer receives -Source unchanged"
            } else {
                Assert-Equal -1 $position 'Without -Source the installer arguments have no -Source'
                Assert-Equal ('-NoProfile -File ' + (Join-Path $tempRoot 'inert-installer.ps1') + ' -Tools claude -ConfigDir ' + (Join-Path $testHome '.legion/agents/claude1') + ' -HomeRoot ' + $testHome + ' -Update -Yes') ($call -join ' ') 'Without -Source the installer arguments are unchanged'
            }
        }
        Reset-SetupTest 'source-plan'
        $planWithout = @(Invoke-Setup -HomeRoot $testHome -Add claude) -join "`n"
        $planWith = @(Invoke-Setup -HomeRoot $testHome -Add claude -Source 'owner/repo') -join "`n"
        Assert-Equal $planWithout $planWith 'The plan output does not change with -Source'
    } finally {
        Set-Item function:Invoke-SetupInstaller $fakeInstaller
        Set-Item function:Invoke-SetupProcess $realProcess
    }

    # Setup always uses the installer shipped beside its plugin manifest.
    Reset-SetupTest 'shipped-installer'
    $script:SetupHomeRoot = $testHome
    $script:SetupPluginRoot = Join-Path $testHome 'cache/plugins/legion'
    $shipped = Join-Path $script:SetupPluginRoot 'install.ps1'
    Assert-Equal $shipped (& $realFindInstaller) 'Setup uses its own shipped installer without searching or downloading'

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
    $bound = Read-LegionJson (Join-Path $testHome 'args.json')
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
