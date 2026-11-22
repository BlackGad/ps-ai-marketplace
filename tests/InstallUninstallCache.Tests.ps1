$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $PSScriptRoot 'fixtures/install/UninstallSandbox.ps1')
    try {
        Assert-True ([bool](Get-Command Get-InstallSafePath -ErrorAction SilentlyContinue)) 'One safe-path helper serves cache cleanup and purge'
        $safeRoot = Join-Path $sandbox 'safe-paths'
        New-FixtureCache (Join-Path $safeRoot 'cache')
        $safeFile = Join-Path $safeRoot 'cache/fixture.txt'
        Assert-Equal (Join-Path $safeRoot 'cache') (Get-InstallSafePath -Root $safeRoot -Relative 'cache') 'Safe folder resolves under its root'
        Assert-Equal $safeFile (Get-InstallSafePath -Root $safeRoot -Relative 'cache/fixture.txt' -AllowFile) 'Safe file resolves when allowed'
        Assert-True (-not (Get-InstallSafePath -Root $safeRoot -Relative 'cache/fixture.txt')) 'Folder-only cleanup skips files'
        Assert-True (-not (Get-InstallSafePath -Root $safeRoot -Relative 'missing')) 'Missing safe path has nothing to remove'
        foreach ($unsafe in @('', '../outside', '..\outside', '/outside', '\outside', 'C:/outside', 'C:outside', '.', 'cache/../outside', '~/outside', 'cache/*', 'cache/?', 'cache/./child', 'cache//child', 'cache/')) {
            Assert-Throws { Get-InstallSafePath -Root $safeRoot -Relative $unsafe -AllowFile } "Safe-path helper rejects '$unsafe' before looking at the filesystem"
        }
        foreach ($tool in @('claude','codex','copilot')) {
            $relative = if ($tool -eq 'copilot') { 'installed-plugins/legion-marketplace' } else { 'plugins/cache/ps-legion-marketplace' }
            $entry = $catalog.tools | Where-Object id -CEQ $tool
            Assert-Equal $relative $entry.plugin.cacheDir 'Cache cleanup path lives in tool data'
            foreach ($custom in @($false, $true)) {
                $folder = if ($custom) { Join-Path $sandbox "$tool-account" } else { Join-Path $sandbox ".$tool" }
                $config = if ($custom) { $folder } else { '' }
                $cache = Join-Path $folder $relative
                $other = Join-Path (Split-Path $cache) 'other-marketplace'
                $unselected = Join-Path $sandbox "$tool-unselected/$relative"
                foreach ($version in @('0.1.0','0.3.0','0.3.2','0.4.0')) { New-FixtureCache (Join-Path $cache "legion/$version") }
                New-FixtureCache $other
                New-FixtureCache $unselected
                $state.Plugin=$true; $state.Marketplace=$true
                $null = Invoke-LegionInstaller -Catalog $catalog -Tools $tool -ConfigDir $config -Uninstall -DryRun
                Assert-True (Test-Path -LiteralPath $cache) 'Preview preserves cache'
                $null = Invoke-LegionInstaller -Catalog $catalog -Tools $tool -ConfigDir $config -Uninstall -Yes
                Assert-True (-not (Test-Path -LiteralPath $cache)) 'Successful uninstall removes every cached version and marketplace cache folder'
                Assert-True (Test-Path -LiteralPath $other) 'Other marketplace cache remains'
                Assert-True (Test-Path -LiteralPath $unselected) 'Other config cache remains'
                $repeat = @(Invoke-LegionInstaller -Catalog $catalog -Tools $tool -ConfigDir $config -Uninstall)
                Assert-True ($repeat -contains 'Nothing to uninstall.') 'Clean repeat has no work'
            }
        }
        $folder = Join-Path $sandbox 'safety'
        $cache = Join-Path $folder 'plugins/cache/ps-legion-marketplace'
        New-FixtureCache $cache
        foreach ($failure in @('FailRemove','KeepListed','FailVerify')) {
            $state.Plugin=$true; $state.Marketplace=$true; $state[$failure]=$true
            $writes.Clear()
            Assert-Throws { Invoke-LegionInstaller -Catalog $catalog -Tools codex -ConfigDir $folder -Uninstall -Yes } "$failure refuses cleanup"
            Assert-True (Test-Path -LiteralPath $cache) "$failure preserves cache"
            $state[$failure]=$false
        }
        $state.Plugin=$false; $state.Marketplace=$false
        $state.Answer='n'
        $preview = @(Invoke-LegionInstaller -Catalog $catalog -Tools codex -ConfigDir $folder -Uninstall)
        Assert-True (($preview -join "`n").Contains("Remove cache folder: $cache")) 'Leftover cache alone is planned'
        Assert-True (Test-Path -LiteralPath $cache) 'Declining keeps leftover cache'
        $null = Invoke-LegionInstaller -Catalog $catalog -Tools codex -ConfigDir $folder -Uninstall -Yes
        Assert-True (-not (Test-Path -LiteralPath $cache)) 'Already uninstalled plugin leftovers can be cleaned'
        New-Item -ItemType Directory -Path $cache -Force | Out-Null
        $null = Invoke-LegionInstaller -Catalog $catalog -Tools codex -ConfigDir $folder -Uninstall -Yes
        Assert-True (-not (Test-Path -LiteralPath $cache)) 'Empty cache folder is cleaned'

        $entry = $catalog.tools | Where-Object id -CEQ codex
        $original = $entry.plugin.cacheDir
        foreach ($unsafe in @('../other-marketplace', '/outside', 'C:/outside', '.', 'plugins/../other', '~/outside', 'plugins/*', 'plugins/./cache')) {
            $entry.plugin.cacheDir=$unsafe
            Assert-Throws { Get-UninstallCachePath -Entry $entry -ConfigDir $folder } 'Unsafe catalog cache path rejected at the cleanup boundary'
            $writes.Clear()
            Assert-Throws { Invoke-LegionInstaller -Catalog $catalog -Tools codex -ConfigDir $folder -Uninstall -Yes } 'Bad relative path in a catalog stops uninstall'
            Assert-Equal 0 $writes.Count 'Unsafe catalog path never reaches a CLI write or cache deletion'
            $descriptor = Get-Content (Join-Path $repo 'plugins/legion/skills/legion-codex/tool.json') -Raw | ConvertFrom-Json
            $descriptor.plugin.cacheDir=$unsafe
            Assert-True (-not (Test-Json -Json ($descriptor | ConvertTo-Json -Depth 100) -SchemaFile (Join-Path $repo 'plugins/legion/schemas/tool.schema.json') -ErrorAction SilentlyContinue)) 'Schema rejects unsafe cache path'
        }
        $entry.plugin.cacheDir=$original
        $outside = Join-Path $sandbox 'linked-owner-data'
        New-FixtureCache $outside
        $linkType = if ($env:OS -eq 'Windows_NT') { 'Junction' } else { 'SymbolicLink' }
        foreach ($nested in @($false, $true)) {
            if ($nested) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }
            $link = if ($nested) { Join-Path $cache 'linked-version' } else { $cache }
            New-Item -ItemType $linkType -Path $link -Target $outside -ErrorAction Stop | Out-Null
            $null = Invoke-LegionInstaller -Catalog $catalog -Tools codex -ConfigDir $folder -Uninstall -Yes
            Assert-True (Test-Path -LiteralPath (Join-Path $outside 'fixture.txt')) 'Linked owner data remains'
            Assert-True (Test-Path -LiteralPath $link) 'Linked cache is skipped'
            Remove-Item -LiteralPath $link -Force
        }

        $fourth = Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth/tool.json') -Raw | ConvertFrom-Json
        $fourth.plugin | Add-Member cacheDir 'private/cache/legion-store'
        $catalog.tools += [pscustomobject]@{id=$fourth.id;command=$fourth.command;configEnv=$fourth.configEnv;plugin=$fourth.plugin;hooks=$fourth.hooks;installHint='fixture'}
        $futureCache = Join-Path $folder 'private/cache/legion-store'
        New-FixtureCache $futureCache
        $state.Plugin=$true; $state.Marketplace=$true
        $null = Invoke-LegionInstaller -Catalog $catalog -Tools fourth -ConfigDir $folder -Uninstall -Yes
        Assert-True (-not (Test-Path -LiteralPath $futureCache)) 'Future tools use their exact declared cache path'
    } finally { Remove-UninstallSandbox }
}
