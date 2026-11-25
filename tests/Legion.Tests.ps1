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

    # --- Get-LegionCall ---
    # setup and add run in Python; this entry point no longer knows them.
    Assert-Throws { Get-LegionCall -Words @('setup') } 'setup is not a script verb'
    Assert-Throws { Get-LegionCall -Words @('add', 'codex') } 'add is not a script verb'
    Assert-Throws { Get-LegionCall -Words @() } 'bare legion runs in Python'
    Assert-Throws { Get-LegionCall -Words @('--no-channel') } 'flags-only launch runs in Python'
    Assert-Throws { Get-LegionCall -Words @('pick') } 'pick runs in Python'
    Assert-Throws { Get-LegionCall -Words @('update') } 'update runs in Python'
    Assert-Throws { Get-LegionCall -Words @('uninstall') } 'uninstall runs in Python'

    foreach ($removed in @('start', 'repo', 'remove')) {
        try { $null = Get-LegionCall -Words @($removed); throw 'Expected unknown command' }
        catch { Assert-Equal "legion: unknown command '$removed'" $_.Exception.Message "$removed is gone" }
    }

    Assert-Throws { Get-LegionCall -Words @('status') } 'status is served by Python'
    Assert-Throws { Get-LegionCall -Words @('limits') } 'limits is served by Python'

    Assert-Equal $null (Get-LegionCall -Words @('help')) 'help gives no call'

    # --- Help text ---
    $expectedHelp = @'
legion - legion commands

  legion [--no-channel]                start the overseer here; it resumes the last conversation
  legion pick [--no-channel]           choose which account leads the overseer
  legion setup [--yes]                 finish setup: settings, commands, legion in every account
  legion add <tool> [<folder>] [--yes] add a claude, codex or copilot account (new or existing folder)
  legion remove --id <id>              remove an account (its folder is kept)
  legion status                        show accounts, commands, channels and this repository
  legion limits [--id <id>]            show each account's usage windows and reset times (or one account)
  legion lease take|status|release     take, check or release this repository's overseer lease
  legion update [--yes]                update legion to the newest version of the track it was installed from
  legion update --check [--force]      check for a newer version; --force bypasses the daily cache
  legion uninstall [--purge] [--yes]   remove legion; --purge also deletes settings, notes and legion-made logins
  legion help                          show this list

setup and add show the plan and ask before changing anything; --yes applies without asking.
'@
    Assert-Equal ($expectedHelp.Trim() -replace "`r`n", "`n") ((Get-LegionHelp) -join "`n") 'Help text is the planned block'

    # --- Rejections: help text, exit 1 ---
    function Invoke-Quiet {
        param([string[]]$Words)
        $script:Output = @(& { Invoke-Legion -Words $Words } 6>&1 | ForEach-Object { "$_" })
        $script:Exit = $script:LegionExit
        return $script:Exit
    }
    foreach ($words in @(@('frobnicate'), @('remove'), @('add', 'claude', 'x', 'extra'), @('status', '--yes'), @('setup', '--no-channel'), @('remove', 'a', '--yes'), @('start'), @('repo'), @('pick', 'a'), @('update'), @('update', 'main'), @('uninstall'), @('uninstall', '--purge', '--yes'), @('add'), @('pick'), @('--no-channel'), @())) {
        $exit = Invoke-Quiet $words
        Assert-Equal 1 $exit ("Rejected: " + ($words -join ' '))
        Assert-True ($script:Output -contains 'legion - legion commands') ("Help shown for: " + ($words -join ' '))
    }
    Assert-Equal 0 (Invoke-Quiet @('help')) 'Help exits zero'

} finally {
    $global:LASTEXITCODE = $savedExit
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}
