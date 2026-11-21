$repo = Split-Path $PSScriptRoot -Parent
$checker = Join-Path $repo 'plugins/ps-ai/bin/legion-update.ps1'
Assert-True (Test-Path -LiteralPath $checker) 'Shared update checker exists'

& {
    . $checker -NoRun
    $sandbox = Join-Path $repo ('.agents/temp/restructure/check-' + [guid]::NewGuid().ToString('N'))
    $plugin = Join-Path $sandbox 'marketplace/plugins/ps-ai'
    $cache = Join-Path $sandbox '.legion/temp/ps-ai-update.json'
    New-Item -ItemType Directory -Path $plugin, (Join-Path $sandbox 'marketplace/.git') -Force | Out-Null
    '{"name":"ps-ai","version":"0.2.0"}' | Set-Content (Join-Path $plugin 'plugin.json')
    function Get-LegionUpdateHome { $sandbox }
    $downloads = [Collections.Generic.List[string]]::new()
    $remote = @{ Text='{"name":"ps-ai","version":"0.3.0"}'; Fail=$false }
    function Get-LegionUpdateText {
        param([string]$Url)
        $downloads.Add($Url)
        if ($remote.Fail) { throw 'fixture download failed with private detail' }
        $remote.Text
    }
    try {
        $result = Get-LegionUpdate -PluginRoot $plugin
        Assert-Equal '0.2.0' $result.Installed 'Installed version comes from running copy'
        Assert-Equal '0.3.0' $result.Available 'Latest version is downloaded'
        Assert-True $result.Newer 'Newer release detected'
        Assert-Equal 'https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/stable/plugins/ps-ai/plugin.json' $downloads[0] 'Update check reads the stable manifest'
        Assert-Equal 'legion update' $result.Command 'Update command is legion update'
        $before = Get-Content $cache -Raw
        $null = Get-LegionUpdate -PluginRoot $plugin
        Assert-Equal 1 $downloads.Count 'Same day uses cache'
        Assert-Equal $before (Get-Content $cache -Raw) 'Cache hit changes nothing'
        '{"name":"ps-ai","version":"0.3.0"}' | Set-Content (Join-Path $plugin 'plugin.json')
        Assert-True (-not (Get-LegionUpdate -PluginRoot $plugin).Newer) 'Cache re-compares running version after upgrade'
        $remote.Text = '{"name":"ps-ai","version":"0.10.0"}'
        $result = Get-LegionUpdate -PluginRoot $plugin -Force
        Assert-Equal 2 $downloads.Count 'Force downloads despite fresh cache'
        Assert-True $result.Newer 'Version ordering is numeric'
        $remote.Text = '{"name":"ps-ai","version":"0.3.0-beta.1"}'
        Assert-True (-not (Get-LegionUpdate -PluginRoot $plugin -Force).Newer) 'Prerelease is older than stable'
        $old = Get-Content $cache -Raw | ConvertFrom-Json
        $old.CheckedAt = [DateTimeOffset]::UtcNow.AddDays(-2).ToString('o')
        $old | ConvertTo-Json | Set-Content $cache
        $null = Get-LegionUpdate -PluginRoot $plugin
        Assert-Equal 4 $downloads.Count 'Expired cache refreshes'
        '{invalid' | Set-Content $cache
        $null = Get-LegionUpdate -PluginRoot $plugin
        Assert-Equal 5 $downloads.Count 'Corrupt cache refreshes'

        # Update checks use the upstream marketplace even when an ancestor is a fork.
        New-Item -ItemType Directory -Path (Join-Path $sandbox 'marketplace/.claude-plugin') | Out-Null
        '{"name":"ps-ai-marketplace","plugins":[{"name":"ps-ai","source":"./plugins/ps-ai"}]}' | Set-Content (Join-Path $sandbox 'marketplace/.claude-plugin/marketplace.json')
        "[remote `"origin`"]`n url = https://github.com/example/marketplace.git`n" | Set-Content (Join-Path $sandbox 'marketplace/.git/config')
        Assert-Equal 'legion update' (Get-LegionUpdate -PluginRoot $plugin -Force).Command 'Checks keep the legion update command'

        Remove-Item -LiteralPath $cache
        $remote.Fail = $true
        Assert-Equal 0 @(Get-LegionUpdate -PluginRoot $plugin).Count 'Failed hook check emits nothing'
        $count = $downloads.Count
        Assert-Equal 0 @(Get-LegionUpdate -PluginRoot $plugin).Count 'Cached failure emits nothing'
        Assert-Equal $count $downloads.Count 'Failure is cached for the day'
        $errorLine = @(Invoke-LegionUpdateCheck -PluginRoot $plugin -Force)
        Assert-Equal 1 $errorLine.Count 'Forced failure prints one line'
        Assert-Equal 'ps-ai: update check failed; could not read the installed or GitHub plugin manifest.' $errorLine[0] 'Forced error is clear and excludes private exception details'
        $remote.Fail = $false
        foreach ($bad in @('{', '{"name":"other","version":"0.4.0"}', '{"name":"ps-ai","version":"invalid"}', '{"name":"ps-ai"}', '{"name":"ps-ai","version":null}')) {
            $remote.Text = $bad
            Assert-Equal 1 @(Invoke-LegionUpdateCheck -PluginRoot $plugin -Force).Count 'Invalid remote manifests fail clearly'
        }
        $remote.Text = '{"name":"ps-ai","version":"0.4.0"}'
        $lines = @(Invoke-LegionUpdateCheck -PluginRoot $plugin -Force)
        Assert-Equal 'ps-ai installed: 0.3.0' $lines[0] 'Explicit check prints installed'
        Assert-Equal 'ps-ai available: 0.4.0' $lines[1] 'Explicit check prints available'
        Assert-Equal 'legion update' $lines[2] 'Explicit check prints update command'
        $remote.Text = '{"name":"ps-ai","version":"0.3.0"}'
        $lines = @(Invoke-LegionUpdateCheck -PluginRoot $plugin -Force)
        Assert-Equal 'ps-ai 0.3.0 is up to date.' ($lines -join '|') 'Up-to-date check prints no update command'
        $remote.Text = '{"name":"ps-ai","version":"0.4.0"}'
        Remove-Item $cache
        New-Item -ItemType Directory -Path $cache | Out-Null
        Assert-Equal '0.4.0' (Get-LegionUpdate -PluginRoot $plugin -Force).Available 'Unwritable cache does not discard successful check'
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp/restructure')) + [IO.Path]::DirectorySeparatorChar
        if (-not ([IO.Path]::GetFullPath($sandbox)).StartsWith($allowed)) { throw 'unsafe check fixture cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
