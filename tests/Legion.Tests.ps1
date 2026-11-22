$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$legionScript = Join-Path $root 'plugins/legion/bin/legion.ps1'
Assert-True (Test-Path -LiteralPath $legionScript) 'Legion script exists'

$scratch = Join-Path $root ('.agents/temp/legion-' + [guid]::NewGuid().ToString('N'))
$standIns = Join-Path $scratch 'bin'
New-Item -ItemType Directory -Path $standIns -Force | Out-Null
$savedExit = $global:LASTEXITCODE
try {
    . $legionScript
    $cwd = (Get-Location).Path

    # --- Get-LegionCall ---
    $call = Get-LegionCall -Words @('add', 'codex', 'C:\work\a b', '--yes')
    Assert-Equal 'legion-setup.ps1' $call.Script 'add calls the setup script'
    Assert-Equal 1 @($call.Splat.Add).Count 'add passes one item'
    Assert-Equal 'codex:C:\work\a b' $call.Splat.Add[0] 'add joins tool and folder with the first colon'
    Assert-Equal $true $call.Splat.Yes 'add --yes sets Yes'
    Assert-Equal $false $call.AsksToApply 'add --yes does not ask'

    $call = Get-LegionCall -Words @('add', 'claude')
    Assert-Equal 'claude' $call.Splat.Add[0] 'add without folder passes the tool alone'
    Assert-Equal $true $call.AsksToApply 'add without --yes asks to apply'
    Assert-True (-not $call.Splat.ContainsKey('Yes')) 'add without --yes has no Yes'

    $call = Get-LegionCall -Words @('setup', '-Yes')
    Assert-Equal 'legion-setup.ps1' $call.Script 'setup calls the setup script'
    Assert-Equal $true $call.Splat.Yes 'setup -Yes sets Yes'
    Assert-Equal $true (Get-LegionCall -Words @('setup')).AsksToApply 'setup asks to apply'

    $call = Get-LegionCall -Words @('remove', 'claude1')
    Assert-Equal 'legion-account.ps1' $call.Script 'remove calls the account script'
    Assert-Equal 'remove' $call.Splat.Action 'remove action'
    Assert-Equal 'claude1' $call.Splat.Id 'remove id'
    Assert-True (-not $call.Splat.ContainsKey('Repo')) 'remove has no Repo'
    Assert-Equal $false $call.AsksToApply 'remove does not ask'

    $call = Get-LegionCall -Words @()
    Assert-Equal 'legion-overseer.ps1' $call.Script 'bare legion calls the overseer script'
    Assert-Equal $cwd $call.Splat.Repo 'bare legion repo is the current folder'
    Assert-Equal 1 $call.Splat.Count 'bare legion passes only the repository'
    $call = Get-LegionCall -Words @('--no-channel')
    Assert-Equal $true $call.Splat.NoChannel 'bare legion --no-channel'
    $call = Get-LegionCall -Words @('pick')
    Assert-Equal $true $call.Splat.Pick 'pick asks'
    Assert-True (-not $call.Splat.ContainsKey('NoChannel')) 'pick keeps the channel'
    $call = Get-LegionCall -Words @('pick', '--no-channel')
    Assert-True ($call.Splat.Pick -and $call.Splat.NoChannel) 'pick --no-channel'
    Assert-Throws { Get-LegionCall -Words @('--account', 'claude1') } 'bare legion takes no account flag'
    Assert-Throws { Get-LegionCall -Words @('pick', 'claude1') } 'pick takes no argument'
    foreach ($removed in @('start', 'repo')) {
        try { $null = Get-LegionCall -Words @($removed); throw 'Expected unknown command' }
        catch { Assert-Equal "legion: unknown command '$removed'" $_.Exception.Message "$removed is gone" }
    }

    $call = Get-LegionCall -Words @('update')
    Assert-Equal $true $call.Installer 'update runs the installer'
    Assert-Equal $true $call.Splat.Update 'update passes Update'
    Assert-True (-not $call.Splat.ContainsKey('Yes')) 'update asks in the installer'
    Assert-Equal $true (Get-LegionCall -Words @('update', '--yes')).Splat.Yes 'update --yes'
    Assert-Throws { Get-LegionCall -Words @('update', 'main') } 'there is no update main'
    $call = Get-LegionCall -Words @('uninstall')
    Assert-True ($call.Installer -and $call.Splat.Uninstall) 'uninstall runs the installer'

    $call = Get-LegionCall -Words @('status')
    Assert-Equal 'legion-status.ps1' $call.Script 'status script'
    Assert-Equal $cwd $call.Splat.Repo 'status repo'

    Assert-Equal $null (Get-LegionCall -Words @('help')) 'help gives no call'

    # --- Help text ---
    $expectedHelp = @'
legion - legion commands

  legion [--no-channel]                start the overseer here; it resumes the last conversation
  legion pick [--no-channel]           choose which account leads the overseer
  legion setup [--yes]                 finish setup: settings, commands, legion in every account
  legion add <tool> [<folder>] [--yes] add a claude, codex or copilot account (new or existing folder)
  legion remove <id>                   remove an account (its folder is kept)
  legion status                        show accounts, commands, channels and this repository
  legion update [--yes]                update legion to the newest version of the track it was installed from
  legion uninstall [--purge] [--yes]   remove legion; --purge also deletes settings, notes and legion-made logins
  legion help                          show this list

setup and add show the plan and ask before changing anything; --yes applies without asking.
'@
    Assert-Equal ($expectedHelp.Trim() -replace "`r`n", "`n") ((Get-LegionHelp) -join "`n") 'Help text is the planned block'

    # --- Stand-in scripts: record bound parameters, exit with a chosen code ---
    $record = Join-Path $scratch 'record.json'
    $exitFile = Join-Path $scratch 'exit.txt'
    $planFile = Join-Path $scratch 'plan.txt'
    $standInText = @'
param([string[]]$Add, [string]$Id, [string]$Action, [string]$Repo, [string]$Account, [string]$HomeRoot, [switch]$Yes, [switch]$NoChannel, [switch]$Pick)
$scratch = Split-Path $PSScriptRoot -Parent
$entry = @{ Add = @($Add); Id = $Id; Action = $Action; Repo = $Repo; Account = $Account; HomeRoot = $HomeRoot; Yes = [bool]$Yes; NoChannel = [bool]$NoChannel; Pick = [bool]$Pick }
Add-Content -LiteralPath (Join-Path $scratch 'record.json') -Value ($entry | ConvertTo-Json -Compress)
Get-Content -LiteralPath (Join-Path $scratch 'plan.txt')
$code = (Get-Content -LiteralPath (Join-Path $scratch 'exit.txt')).Trim()
if ($code -ne 'none') { exit [int]$code }
'@
    foreach ($name in 'legion-setup.ps1', 'legion-account.ps1', 'legion-status.ps1', 'legion-repository.ps1', 'legion-overseer.ps1') {
        Set-Content -LiteralPath (Join-Path $standIns $name) -Value $standInText
    }
    $script:LegionBin = $standIns
    function Reset-StandIns {
        param([string]$Exit = '0', [string[]]$Plan = @('Plan (nothing changed yet):', '  create   settings'))
        Remove-Item -LiteralPath $record -ErrorAction SilentlyContinue
        Set-Content -LiteralPath $exitFile -Value $Exit
        Set-Content -LiteralPath $planFile -Value $Plan
    }
    function Get-Records {
        if (-not (Test-Path -LiteralPath $record)) { return @() }
        return @(Get-Content -LiteralPath $record | ForEach-Object { $_ | ConvertFrom-Json })
    }
    function Invoke-Quiet {
        param([string[]]$Words)
        $script:Output = @(& { Invoke-Legion -Words $Words } 6>&1 | ForEach-Object { "$_" })
        $script:Exit = $script:LegionExit
        return $script:Exit
    }

    # --- Dispatch ---
    Copy-Item -LiteralPath $legionScript -Destination (Join-Path $standIns 'legion.ps1')
    $pwsh = Join-Path $PSHOME $(if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' })
    foreach ($words in @(@('setup', '--yes'), @('add', 'codex', '--yes'), @('--no-channel'), @('pick'))) {
        Reset-StandIns -Exit 'none'
        & $pwsh -NoProfile -File (Join-Path $standIns 'legion.ps1') -HomeRoot $scratch @words | Out-Null
        Assert-Equal 0 $LASTEXITCODE 'R4 B4 public legion entry accepts the bound home and verb flags'
        Assert-Equal $scratch (Get-Records)[0].HomeRoot 'R4 B4 public legion entry forwards the bound home'
    }
    & {
        . $legionScript -HomeRoot $scratch
        $script:LegionBin = $standIns
        foreach ($words in @(@('setup', '--yes'), @('add', 'codex', '--yes'), @('status'), @('remove', 'codex1'), @('--no-channel'))) {
            Reset-StandIns -Exit 'none'
            Invoke-Legion -Words $words | Out-Null
            Assert-Equal $scratch (Get-Records)[0].HomeRoot 'R4 B4 legion carries the bound home through dispatch'
        }
    }
    Reset-StandIns -Exit 'none'
    $global:LASTEXITCODE = 0
    $exit = Invoke-Quiet @('add', 'codex', 'C:\work\a b', '--yes')
    $records = Get-Records
    Assert-Equal 0 $exit 'Dispatch success exits zero'
    Assert-Equal 1 $records.Count 'Dispatch runs the script once'
    Assert-Equal 1 @($records[0].Add).Count 'Add arrives as a one-item array'
    Assert-Equal 'codex:C:\work\a b' $records[0].Add[0] 'Add item arrives intact'
    Assert-Equal $true $records[0].Yes 'Yes switch arrives bound'

    Reset-StandIns -Exit 'none'
    Invoke-Quiet @('pick', '--no-channel') | Out-Null
    $record1 = (Get-Records)[0]
    Assert-Equal $true $record1.Pick 'Pick switch arrives bound'
    Assert-Equal $true $record1.NoChannel 'NoChannel switch arrives bound'
    Assert-Equal $cwd $record1.Repo 'Repo arrives'

    Reset-StandIns -Exit 'none'
    Invoke-Quiet @('remove', 'claude1') | Out-Null
    $record1 = (Get-Records)[0]
    Assert-Equal 'remove' $record1.Action 'Remove action arrives'
    Assert-Equal 'claude1' $record1.Id 'Remove id arrives'
    Assert-Equal '' "$($record1.Repo)" 'Remove gets no Repo'

    Reset-StandIns -Exit '3'
    Assert-Equal 3 (Invoke-Quiet @('status')) 'A failing script gives its exit code'

    Reset-StandIns -Exit 'none'
    $global:LASTEXITCODE = 7
    Assert-Equal 0 (Invoke-Quiet @('status')) 'A stale exit code does not leak into a success'

    Remove-Item -LiteralPath (Join-Path $standIns 'legion-status.ps1')
    $global:LASTEXITCODE = 0
    Assert-Equal 1 (Invoke-Quiet @('status')) 'A script that cannot run gives exit 1'
    Assert-True ($script:Output.Count -gt 0) 'A script that cannot run prints a message'
    Set-Content -LiteralPath (Join-Path $standIns 'legion-status.ps1') -Value $standInText

    # --- Rejections: help text, exit 1, nothing runs ---
    foreach ($words in @(@('frobnicate'), @('remove'), @('add', 'claude', 'x', 'extra'), @('status', '--yes'), @('setup', '--no-channel'), @('remove', 'a', '--yes'), @('start'), @('repo'), @('pick', 'a'), @('update', 'main'), @('add'))) {
        Reset-StandIns
        $exit = Invoke-Quiet $words
        Assert-Equal 1 $exit ("Rejected: " + ($words -join ' '))
        Assert-Equal 0 (Get-Records).Count ("Nothing runs for: " + ($words -join ' '))
        Assert-True ($script:Output -contains 'legion - legion commands') ("Help shown for: " + ($words -join ' '))
    }
    Reset-StandIns
    Assert-Equal 0 (Invoke-Quiet @('help')) 'Help exits zero'
        Assert-Equal 0 (Get-Records).Count 'Help runs nothing'

    # --- update and uninstall: a private copy of the installer ---
    $installerText = @'
param([switch]$Update, [switch]$Uninstall, [switch]$Yes, [string]$HomeRoot)
$catalog = Join-Path $PSScriptRoot 'tools.json'
$entry = @{ Path = $PSCommandPath; Update = [bool]$Update; Uninstall = [bool]$Uninstall; Yes = [bool]$Yes; HomeRoot = $HomeRoot; Catalog = (Get-Content -LiteralPath $catalog -Raw).Trim() }
if ($Uninstall) {
    # The uninstall deletes the installed source folder, then reads the copied catalog.
    Remove-Item -LiteralPath (Join-Path $HomeRoot 'source') -Recurse -Force
    $entry.Catalog = (Get-Content -LiteralPath $catalog -Raw).Trim()
    . (Join-Path $PSScriptRoot 'bin/lib/paths.ps1')
    $entry.SharedPath = Get-LegionOwnerPath -Name Settings -HomeRoot $HomeRoot
}
$entry | ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $HomeRoot 'installer-record.json')
if ($Uninstall) { exit 4 }
'@
    $sourceFolder = Join-Path $scratch 'source'
    New-Item -ItemType Directory -Path (Join-Path $sourceFolder 'bin') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $sourceFolder 'install.ps1') -Value $installerText
    Set-Content -LiteralPath (Join-Path $sourceFolder 'tools.json') -Value 'catalog-text'
    New-Item -ItemType Directory -Path (Join-Path $sourceFolder 'bin/lib') -Force | Out-Null
    Copy-Item (Join-Path $root 'plugins/legion/bin/lib/paths.ps1') (Join-Path $sourceFolder 'bin/lib/paths.ps1')
    Copy-Item (Join-Path $root 'plugins/legion/bin/lib/footprints.ps1') (Join-Path $sourceFolder 'bin/lib/footprints.ps1')
    $script:LegionBin = Join-Path $sourceFolder 'bin'
    $installerRecord = Join-Path $scratch 'installer-record.json'
    $script:LegionHomeRoot = $scratch
    Invoke-Quiet @('update') | Out-Null
    $copied = Get-Content -LiteralPath $installerRecord -Raw | ConvertFrom-Json
    Assert-True ($copied.Path.StartsWith((Join-Path $scratch '.legion/temp/installer-'))) 'update runs the copy under the selected home'
    Assert-True ($copied.Update -and -not $copied.Uninstall -and -not $copied.Yes) 'update arrives as -Update'
    Assert-Equal $scratch $copied.HomeRoot 'update gets the selected home'
    Assert-Equal 'catalog-text' $copied.Catalog 'the copy has its own tools.json'
    Assert-True (-not (Test-Path -LiteralPath (Split-Path $copied.Path))) 'the copied installer folder is removed afterwards'

    Invoke-Quiet @('uninstall', '--yes') | Out-Null
    $copied = Get-Content -LiteralPath $installerRecord -Raw | ConvertFrom-Json
    Assert-True ($copied.Uninstall -and $copied.Yes) 'uninstall arrives as -Uninstall -Yes'
    Assert-Equal 'catalog-text' $copied.Catalog 'the catalog is read from the copy after the source is deleted'
    Assert-Equal (Join-Path $scratch '.legion/configuration/personalisation.json') $copied.SharedPath 'Copied library still runs after its source is deleted'
    Assert-Equal 4 $script:LegionExit 'the installer exit code comes out'
    Assert-True (-not (Test-Path -LiteralPath $sourceFolder)) 'the stand-in deleted its source folder'
    $script:LegionHomeRoot = $null
    $script:LegionBin = $standIns

    # --- Apply flow: replace the seams ---
    $script:Interactive = $true
    $script:Answers = @()
    $script:Asked = 0
    function Test-LegionInteractive { return $script:Interactive }
    function Read-LegionAnswer { $script:Asked++; return $script:Answers[0] }

    Reset-StandIns
    $script:Answers = @('')
    $exit = Invoke-Quiet @('add', 'claude')
    $records = Get-Records
    Assert-Equal 0 $exit 'Enter applies and exits zero'
    Assert-Equal 2 $records.Count 'Enter runs the script a second time'
    Assert-Equal $false $records[0].Yes 'The plan run has no Yes'
    Assert-Equal $true $records[1].Yes 'The apply run has Yes'
    Assert-Equal 'claude' $records[1].Add[0] 'The apply run keeps the same arguments'
    Assert-True ($script:Output -contains '  create   settings') 'The plan is printed'

    Reset-StandIns
    $script:Answers = @('YES')
    Invoke-Quiet @('setup') | Out-Null
    Assert-Equal 2 (Get-Records).Count 'Yes in any case applies'

    Reset-StandIns
    $script:Answers = @('n')
    $exit = Invoke-Quiet @('setup')
    Assert-Equal 0 $exit 'Declining exits zero'
    Assert-Equal 1 (Get-Records).Count 'Declining runs once'
    Assert-True ($script:Output -contains 'Nothing changed.') 'Declining says nothing changed'

    Reset-StandIns
    $script:Interactive = $false
    $script:Asked = 0
    $exit = Invoke-Quiet @('setup')
    Assert-Equal 0 $exit 'Non-interactive prints the plan and exits zero'
    Assert-Equal 1 (Get-Records).Count 'Non-interactive runs once'
    Assert-Equal 0 $script:Asked 'Non-interactive never prompts'
    $script:Interactive = $true

    Reset-StandIns -Plan @('Nothing to do.')
    $script:Asked = 0
    $exit = Invoke-Quiet @('setup')
    Assert-Equal 0 $exit 'Nothing to do exits zero'
    Assert-Equal 1 (Get-Records).Count 'Nothing to do runs once'
    Assert-Equal 0 $script:Asked 'Nothing to do never prompts'

    $hintPlan = @('Plan (nothing changed yet):', '  create   settings', 'Run again with -Yes to apply.')
    Reset-StandIns -Plan $hintPlan
    $script:Answers = @('n')
    Invoke-Quiet @('setup') | Out-Null
    Assert-True ($script:Output -contains '  create   settings') 'Interactive prompt still shows the plan'
    Assert-True ($script:Output -notcontains 'Run again with -Yes to apply.') 'Interactive prompt hides the -Yes hint'

    Reset-StandIns -Plan $hintPlan
    $script:Interactive = $false
    Invoke-Quiet @('setup') | Out-Null
    Assert-True ($script:Output -contains 'Run again with -Yes to apply.') 'Non-interactive keeps the -Yes hint'
    $script:Interactive = $true

    Reset-StandIns -Plan $hintPlan
    Invoke-Quiet @('setup', '--yes') | Out-Null
    Assert-True ($script:Output -contains 'Run again with -Yes to apply.') '--yes keeps the full output'

    Reset-StandIns -Exit '4'
    $script:Asked = 0
    $exit = Invoke-Quiet @('add', 'claude')
    Assert-Equal 4 $exit 'A failing plan stops with its code'
    Assert-Equal 0 $script:Asked 'A failing plan never prompts'

    Reset-StandIns
    $script:Asked = 0
    $exit = Invoke-Quiet @('setup', '--yes')
    $records = Get-Records
    Assert-Equal 0 $exit '--yes exits zero'
    Assert-Equal 1 $records.Count '--yes runs once'
    Assert-Equal $true $records[0].Yes '--yes passes Yes'
    Assert-Equal 0 $script:Asked '--yes never prompts'
} finally {
    $global:LASTEXITCODE = $savedExit
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}
