$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $repo 'plugins/ps-ai/bin/lib/commands.ps1')
. (Join-Path $repo 'plugins/ps-ai/bin/ps-ai-account.ps1') -NoRun
$scratch = Join-Path $repo ('.agents/temp/install-owner-commands-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
try {
    & {
        . (Join-Path $repo 'install.ps1') -NoRun
        # C-1: install.ps1 is standalone and keeps its own copy of the rule; both copies must agree on every sample.
        $target = Join-Path $scratch "owner's plugin/bin/legion.ps1"
        $samples = @(
            (Get-PsAiShimText -Script $target),
            (Get-PsAiShimText -Script 'C:\plugin folder\bin\legion.ps1' -Windows),
            (Get-PsAiShimText -Script $target).Replace(' "$@"', ' --extra "$@"'),
            'pwsh -NoProfile -File /plugin/bin/legion.ps1',
            '@pwsh -NoProfile -File C:\plugin\bin\legion.ps1',
            "#!/bin/sh`n# exec pwsh -NoProfile -File '/plugin/bin/legion.ps1' `"`$@`"`necho mine",
            "@rem pwsh -NoProfile -File `"C:\plugin\bin\legion.ps1`" %*",
            'pwsh -NoProfile -File /mine/custom.ps1 /plugin/bin/legion.ps1',
            'echo ok # pwsh -NoProfile -File /plugin/bin/legion.ps1',
            'pwsh -NoProfile -File "/plugin/legion.ps1"',
            'unrelated command',
            "#!/bin/sh`necho before`nexec pwsh -NoProfile -File '/plugin/bin/legion.ps1' `"`$@`"",
            "#!/bin/sh`nexec pwsh -NoProfile -File '/plugin/bin/legion.ps1' `"`$@`"; echo after")
        $path = Join-Path $scratch 'sample'
        foreach ($text in $samples) {
            [IO.File]::WriteAllText($path, $text)
            foreach ($script in @('legion.ps1', 'ps-ai-status.ps1')) {
                Assert-Equal (Test-PsAiOwnerCommandFile -Path $path -Script $script) (Test-InstallOwnerCommandFile -Path $path -Script $script) "Both copies of the rule agree on: $text"
            }
        }
        [IO.File]::WriteAllText($path, $samples[5])
        Assert-Equal $false (Test-InstallOwnerCommandFile -Path $path -Script legion.ps1) 'A comment naming the script is not ours to delete'

        # G2: the standalone copy decodes batch quoting too.
        $percentScript = Join-Path $scratch 'plugin 100%/bin/legion.ps1'
        New-Item -ItemType Directory -Path (Split-Path $percentScript) -Force | Out-Null
        '' | Set-Content -LiteralPath $percentScript
        $batchPath = Join-Path $scratch 'legion.cmd'
        [IO.File]::WriteAllText($batchPath, (Get-PsAiShimText -Script $percentScript -Windows))
        Assert-Equal $percentScript (Get-InstallOwnerCommandTarget -Path $batchPath -Script legion.ps1) 'The installer decodes batch quoting'

        # C-2: after an uninstall, commands whose script is gone move to a surviving install, or go away.
        $homeRoot = Join-Path $scratch 'home'
        $bin = Join-Path $homeRoot '.legion/bin'
        New-Item -ItemType Directory -Path $bin -Force | Out-Null
        function Get-InstallHome { $homeRoot }
        $live = Join-Path $scratch 'live/bin/ps-ai-status.ps1'
        New-Item -ItemType Directory -Path (Split-Path $live) -Force | Out-Null
        '' | Set-Content -LiteralPath $live
        $script:installCatalog = Get-InstallCatalog -Source $repo
        function Write-RepairFixture {
            Get-PsAiShimText -Script (Join-Path $scratch 'gone/bin/legion.ps1') | Set-Content -LiteralPath (Join-Path $bin 'legion')
            Get-PsAiShimText -Script $live | Set-Content -LiteralPath (Join-Path $bin 'ps-ai-status')
            'mine' | Set-Content -LiteralPath (Join-Path $bin 'ps-ai-setup')
        }
        $refreshes = [Collections.Generic.List[string]]::new()
        function Invoke-InstallRefresh { param($Entry, [string]$ConfigDir) $refreshes.Add("$($Entry.id):$ConfigDir") }
        function Test-InstallCommandAvailable { param($Name) $true }

        # The survivors are found before anything is removed; repair only moves commands to one, or removes the planned ones.
        $deadLegion = Join-Path $bin 'legion'
        Write-RepairFixture
        $survivor = [pscustomobject]@{ Entry = (Get-InstallTool codex); Folder = 'survivor' }
        Repair-InstallOwnerCommands -Survivors @($survivor) -Planned @($deadLegion)
        Assert-Equal 'codex:survivor' ($refreshes -join '|') 'Dead commands are retargeted through a surviving install'
        Assert-True (Test-Path -LiteralPath $deadLegion) 'Dead command is kept while a survivor can fix it'

        $refreshes.Clear()
        Repair-InstallOwnerCommands -Planned @($deadLegion)
        Assert-Equal 0 $refreshes.Count 'No survivor means no refresh'
        Assert-Equal $false (Test-Path -LiteralPath $deadLegion) 'A planned dead command is removed when no install is left'
        Assert-True (Test-Path -LiteralPath (Join-Path $bin 'ps-ai-status')) 'A working command stays'
        Assert-True (Test-Path -LiteralPath (Join-Path $bin 'ps-ai-setup')) 'A foreign file stays'

        Write-RepairFixture
        $kept = @(Repair-InstallOwnerCommands)
        Assert-True (Test-Path -LiteralPath $deadLegion) 'A dead command outside the plan is kept'
        Assert-True (($kept -join "`n") -match 'Kept command: .*legion') 'A kept dead command is reported'
    }
} finally {
    $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
    if ([IO.Path]::GetFullPath($scratch).StartsWith($allowed)) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
