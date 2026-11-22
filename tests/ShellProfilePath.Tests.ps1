. (Join-Path $PSScriptRoot 'lib/paths.ps1')
$repo = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path $repo ('.agents/temp/shell-path-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
$savedShell = $env:SHELL; $savedOS = $env:OS
$savedIsWindows = $IsWindows
try {
    & {
        # Exercise the Unix branch on every host, without touching a real profile or registry.
        Set-Variable IsWindows $false -Force
        $env:OS = 'Unix'
        . (Join-Path $repo 'plugins/legion/bin/legion-setup.ps1') -NoRun
        function Write-SetupCommands { }
        function Get-LegionUserPath { throw 'Unix must not read the registry' }
        function Set-LegionUserPath { throw 'Unix must not write the registry' }
        foreach ($shell in @('zsh', 'bash', 'fish')) {
            $env:SHELL = '/bin/' + $shell
            $fixtureHome = Join-Path $scratch $shell
            New-Item -ItemType Directory -Path $fixtureHome -Force | Out-Null
            $name = switch ($shell) { zsh { '.zshrc' } bash { '.bashrc' } default { '.profile' } }
            $profilePath = Join-Path $fixtureHome $name
            $bin = Join-Path $fixtureHome '.legion/bin'
            $plan = @(Invoke-Setup -HomeRoot $fixtureHome)
            Assert-True (($plan -join "`n").Contains($profilePath)) "$shell preview names the selected profile"
            Assert-True (-not (Test-Path $profilePath)) "$shell no consent leaves the profile absent"
            $preview = @(Add-LegionUserPath -Folder $bin -HomeRoot $fixtureHome -DryRun)
            Assert-True (($preview -join "`n").Contains('export PATH="$HOME/.legion/bin:$PATH"')) "$shell dry run shows the export"
            Assert-True (-not (Test-Path (Join-Path $fixtureHome '.legion'))) "$shell dry run records nothing"
            $null = Invoke-Setup -HomeRoot $fixtureHome -Yes
            Assert-Equal ("# Added by legion`n" + 'export PATH="$HOME/.legion/bin:$PATH"' + "`n") ([IO.File]::ReadAllText($profilePath)) "$shell yes writes the two lines"
            $entry = Get-LegionFootprints -HomeRoot $fixtureHome -Kind path-entry
            Assert-Equal "~/$name" $entry.path "$shell footprint names the profile"
            Assert-Equal 'legion' ($entry.owners -join '|') "$shell footprint is purge only"
            $stamp = (Get-Item -Force $profilePath).LastWriteTimeUtc.Ticks
            $index = [IO.File]::ReadAllText((Get-LegionOwnerPath -HomeRoot $fixtureHome -Name Index))
            $repeat = @(Invoke-Setup -HomeRoot $fixtureHome -Yes)
            Assert-True ($repeat -contains 'skip: shell profile PATH (already done)') "$shell repeat reports the skip"
            Assert-Equal $stamp (Get-Item -Force $profilePath).LastWriteTimeUtc.Ticks "$shell repeat does not rewrite the profile"
            Assert-Equal $index ([IO.File]::ReadAllText((Get-LegionOwnerPath -HomeRoot $fixtureHome -Name Index))) "$shell repeat keeps the index bytes"
            Assert-Equal $false (Get-SetupPlan -HomeRoot $fixtureHome).NeedsPath "$shell plan reads the profile before a new terminal"
            Remove-Item -LiteralPath (Get-LegionOwnerPath -HomeRoot $fixtureHome -Name Index)
            $null = Add-LegionUserPath -Folder $bin -HomeRoot $fixtureHome
            Assert-Equal 'legion' ((Get-LegionFootprints -HomeRoot $fixtureHome -Kind path-entry).owners -join '|') "$shell repair re-records an existing line"
        }

        . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
        $script:installCatalog = Get-InstallCatalog -Source $repo
        foreach ($encoding in @([Text.UTF8Encoding]::new($false), [Text.UTF8Encoding]::new($true), [Text.UnicodeEncoding]::new($false, $true), [Text.UnicodeEncoding]::new($true, $true))) {
            foreach ($ending in @("`n", "`r`n", '')) {
                $fixtureHome = Join-Path $scratch ([guid]::NewGuid().ToString('N'))
                New-Item -ItemType Directory -Path $fixtureHome -Force | Out-Null
                function Get-InstallHome { $fixtureHome }
                $env:SHELL = '/bin/zsh'
                $profilePath = Join-Path $fixtureHome '.zshrc'
                $original = '# owner café $PATH' + "`r`n" + 'export KEEP=yes' + $ending
                [IO.File]::WriteAllText($profilePath, $original, $encoding)
                $null = Add-LegionUserPath -Folder (Join-Path $fixtureHome '.legion/bin') -HomeRoot $fixtureHome
                $null = Add-LegionUserPath -Folder (Join-Path $fixtureHome '.legion/bin') -HomeRoot $fixtureHome
                # Unrecorded and similar exports elsewhere must survive.
                $tail = 'export PATH="$HOME/.legion/bin:$PATH" # owner' + "`n"
                Set-LegionTextPreservingEncoding -Path $profilePath -Text ([IO.File]::ReadAllText($profilePath) + $tail)
                $preview = @(Invoke-LegionPurge -DryRun) -join "`n"
                Assert-True ($preview.Contains($profilePath)) 'Purge previews the recorded profile entry'
                $null = Invoke-LegionPurge -Yes
                $expected = $encoding.GetBytes($original + $tail)
                if ($encoding.GetPreamble().Length) { $expected = [byte[]]($encoding.GetPreamble() + $expected) }
                Assert-Equal ([Convert]::ToBase64String($expected)) ([Convert]::ToBase64String([IO.File]::ReadAllBytes($profilePath))) 'Purge preserves every other byte, BOM and newline'
            }
        }
        $fixtureHome = Join-Path $scratch 'unrecorded'
        New-Item -ItemType Directory -Path $fixtureHome -Force | Out-Null
        $profilePath = Join-Path $fixtureHome '.zshrc'
        $original = "# Added by legion`n" + 'export PATH="$HOME/.legion/bin:$PATH"' + "`n"
        [IO.File]::WriteAllText($profilePath, $original)
        $null = Invoke-LegionPurge -Yes
        Assert-Equal $original ([IO.File]::ReadAllText($profilePath)) 'Purge leaves an unrecorded marked block untouched'
        # B-b: the owner's own line without the marker stays theirs.
        $fixtureHome = Join-Path $scratch 'owner-line'
        New-Item -ItemType Directory -Path $fixtureHome -Force | Out-Null
        $profilePath = Join-Path $fixtureHome '.zshrc'
        $original = 'export PATH="$HOME/.legion/bin:$PATH"' + "`n"
        [IO.File]::WriteAllText($profilePath, $original)
        $output = @(Add-LegionUserPath -Folder (Join-Path $fixtureHome '.legion/bin') -HomeRoot $fixtureHome)
        Assert-True ($output -contains 'skip: shell profile PATH (already done)') 'B-b: an owner line is a skip'
        Assert-Equal 0 @(Get-LegionFootprints -HomeRoot $fixtureHome).Count 'B-b: an owner line is not recorded'
        Add-LegionFootprint -HomeRoot $fixtureHome -Kind path-entry -Path $profilePath -Value 'export PATH="$HOME/.legion/bin:$PATH"' -Owner legion
        $null = Invoke-LegionPurge -Yes
        Assert-Equal $original ([IO.File]::ReadAllText($profilePath)) 'B-b: purge removes a recorded line only under the legion marker'
        # The index is written before the profile writer can fail.
        $fixtureHome = Join-Path $scratch 'write-ahead'
        New-Item -ItemType Directory -Path $fixtureHome -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $fixtureHome '.zshrc'), '# owner')
        function Set-LegionTextPreservingEncoding { throw 'fixture write failed' }
        Assert-Throws { Add-LegionUserPath -Folder (Join-Path $fixtureHome '.legion/bin') -HomeRoot $fixtureHome } 'Profile write failure propagates'
        Assert-Equal 'legion' ((Get-LegionFootprints -HomeRoot $fixtureHome -Kind path-entry).owners -join '|') 'The footprint exists before the failed write'
    }
} finally {
    Set-Variable IsWindows $savedIsWindows -Force
    $env:SHELL = $savedShell; $env:OS = $savedOS
    Remove-TestFolder -Path $scratch -AllowedParent (Join-Path $repo '.agents/temp')
}
