$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $repo 'plugins/legion/bin/lib/commands.ps1')
. (Join-Path $repo 'plugins/legion/bin/legion-account.ps1') -NoRun
$scratch = Join-Path $repo ('.agents/temp/install-owner-commands-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
try {
    & {
        . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
        # C-1: install.ps1 is standalone and keeps its own copy of the rule; both copies must agree on every sample.
        $target = Join-Path $scratch "owner's plugin/bin/legion.ps1"
        $samples = @(
            (Get-LegionShimText -Script $target).Replace(' "$@"', ' -Repo "work folder" "$@"'),
            (Get-LegionShimText -Script 'C:\plugin folder\bin\legion.ps1' -Windows).Replace(' %*', ' -Repo "C:\work folder" %*'),
            (Get-LegionShimText -Script $target),
            (Get-LegionShimText -Script 'C:\plugin folder\bin\legion.ps1' -Windows),
            (Get-LegionShimText -Script $target).Replace(' "$@"', ' --extra "$@"'),
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
            foreach ($script in @('legion.ps1', 'legion-status.ps1')) {
                Assert-Equal (Test-LegionOwnerCommandFile -Path $path -Script $script) (Test-InstallOwnerCommandFile -Path $path -Script $script) "Both copies of the rule agree on: $text"
            }
        }
        [IO.File]::WriteAllText($path, $samples[7])
        Assert-Equal $false (Test-InstallOwnerCommandFile -Path $path -Script legion.ps1) 'A comment naming the script is not ours to delete'
        foreach ($text in $samples[0..1]) {
            $quotedPath = if ($text.StartsWith('@')) { "$path.cmd" } else { $path }
            [IO.File]::WriteAllText($quotedPath, $text)
            Assert-True (Test-InstallOwnerCommandFile -Path $quotedPath -Script legion.ps1) 'R4 B2 installer accepts literal quoted owner arguments'
        }
        $bound = Get-LegionShimText -Script $target -HomeRoot (Join-Path $scratch "owner's home")
        [IO.File]::WriteAllText($path, $bound)
        Assert-True (Test-InstallOwnerCommandFile -Path $path -Script legion.ps1) 'R4 B2 installer recognizes adjacent shell quotes in literal arguments'
        Assert-Equal (Test-LegionOwnerCommandFile -Path $path -Script legion.ps1) (Test-InstallOwnerCommandFile -Path $path -Script legion.ps1) 'R4 B2 bound-home matcher parity'

        # G2: the standalone copy decodes batch quoting too.
        $percentScript = Join-Path $scratch 'plugin 100%/bin/legion.ps1'
        New-Item -ItemType Directory -Path (Split-Path $percentScript) -Force | Out-Null
        '' | Set-Content -LiteralPath $percentScript
        $batchPath = Join-Path $scratch 'legion.cmd'
        $dollarText = (Get-LegionShimText -Script 'C:\old\bin\legion.ps1' -Windows).Replace(' %*', ' -Repo "\\server\team$\work folder" %*')
        [IO.File]::WriteAllText($batchPath, $dollarText)
        Assert-True (Test-InstallOwnerCommandFile -Path $batchPath -Script legion.ps1) 'R5 B2 installer accepts a quoted batch dollar path'
        Assert-Equal (Read-LegionOwnerCommandTarget -Path $batchPath -Script legion.ps1).Path (Get-InstallOwnerCommandTarget -Path $batchPath -Script legion.ps1).Path 'R5 B2 batch dollar path matcher parity'
        [IO.File]::WriteAllText($path, $dollarText)
        Assert-Equal $false (Test-InstallOwnerCommandFile -Path $path -Script legion.ps1) 'R5 B2 installer shell matcher rejects dollar expansion'
        Assert-Equal (Test-LegionOwnerCommandFile -Path $path -Script legion.ps1) (Test-InstallOwnerCommandFile -Path $path -Script legion.ps1) 'R5 B2 shell dollar path matcher parity'
        [IO.File]::WriteAllText($batchPath, (Get-LegionShimText -Script $percentScript -Windows))
        Assert-Equal $percentScript (Get-InstallOwnerCommandTarget -Path $batchPath -Script legion.ps1).Path 'The installer decodes batch quoting'

        # C-2: after an uninstall, commands whose script is gone move to a surviving install, or go away.
        $homeRoot = Join-Path $scratch 'home'
        $bin = Join-Path $homeRoot '.legion/bin'
        New-Item -ItemType Directory -Path $bin -Force | Out-Null
        function Get-InstallHome { $homeRoot }
        $live = Join-Path $scratch 'live/bin/legion-status.ps1'
        New-Item -ItemType Directory -Path (Split-Path $live) -Force | Out-Null
        '' | Set-Content -LiteralPath $live
        $script:installCatalog = Get-InstallCatalog -Source $repo
        function Write-RepairFixture {
            Get-LegionShimText -Script (Join-Path $scratch 'gone/bin/legion.ps1') | Set-Content -LiteralPath (Join-Path $bin 'legion')
            Get-LegionShimText -Script $live | Set-Content -LiteralPath (Join-Path $bin 'custom-status')
            'mine' | Set-Content -LiteralPath (Join-Path $bin 'custom-setup')
        }
        $refreshes = [Collections.Generic.List[string]]::new()
        function Invoke-InstallRefresh { param($Entry, [string]$ConfigDir) $refreshes.Add("$($Entry.id):$ConfigDir") }
        function Test-InstallCommandAvailable { param($Name) $true }

        # The survivors are found before anything is removed; repair only moves commands to one, or removes the planned ones.
        $deadLegion = Join-Path $bin 'legion'
        Write-RepairFixture
        $root = Join-Path $scratch "survivor's 100% copy"
        $runner = Join-Path $root 'bin/legion.ps1'
        New-Item -ItemType Directory -Path (Split-Path $runner) -Force | Out-Null
        '' | Set-Content -LiteralPath $runner
        $survivor = [pscustomobject]@{ Entry = (Get-InstallTool codex); Folder = 'survivor'; Root = $root }
        Repair-InstallOwnerCommands -Survivors @($survivor) -Planned @($deadLegion)
        Assert-Equal $runner (Get-InstallOwnerCommandTarget -Path $deadLegion -Script legion.ps1).Path 'Dead commands are retargeted to a provided script'
        Assert-Equal 0 $refreshes.Count 'Retargeting does not refresh siblings'
        Assert-True (Test-Path -LiteralPath $deadLegion) 'Dead command is kept while a survivor can fix it'

        foreach ($batch in @($false, $true)) {
            $commandPath = Join-Path $bin "legion$(if ($batch) { '.cmd' })"
            $original = (Get-LegionShimText -Script (Join-Path $scratch 'gone/bin/legion.ps1') -Windows:$batch).Replace(' %*', ' -NoChannel %*').Replace(' "$@"', ' -NoChannel "$@"')
            [IO.File]::WriteAllText($commandPath, $original)
            Set-InstallOwnerCommandTarget -Path $commandPath -Script legion.ps1 -Runner $runner
            Assert-Equal $runner (Read-LegionOwnerCommandTarget -Path $commandPath -Script legion.ps1).Path 'Retargeting round-trips apostrophes and percent signs'
            Assert-True ((Get-Content -LiteralPath $commandPath -Raw).Contains(' -NoChannel ')) 'Retargeting keeps literal owner flags'
            Remove-Item -LiteralPath $commandPath -Force
        }

        $refreshes.Clear()
        Write-RepairFixture
        Repair-InstallOwnerCommands -Planned @($deadLegion)
        Assert-Equal 0 $refreshes.Count 'No survivor means no refresh'
        Assert-Equal $false (Test-Path -LiteralPath $deadLegion) 'A planned dead command is removed when no install is left'
        Assert-True (Test-Path -LiteralPath (Join-Path $bin 'custom-status')) 'A working command stays'
        Assert-True (Test-Path -LiteralPath (Join-Path $bin 'custom-setup')) 'A foreign file stays'

        Write-RepairFixture
        $kept = @(Repair-InstallOwnerCommands)
        Assert-True (Test-Path -LiteralPath $deadLegion) 'A dead command outside the plan is kept'
        Assert-True (($kept -join "`n") -match 'Kept command: .*legion') 'A kept dead command is reported'
    }
} finally {
    $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
    if ([IO.Path]::GetFullPath($scratch).StartsWith($allowed)) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
