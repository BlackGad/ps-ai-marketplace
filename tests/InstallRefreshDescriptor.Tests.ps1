$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $entry = Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth/tool.json') -Raw | ConvertFrom-Json
    $entry.plugin | Add-Member defaultConfigDir '~/.fixture-agent-data'
    $entry.plugin | Add-Member installedRoot 'actual-installed-files'
    $script:installCatalog.tools += $entry
    $sandbox = Join-Path $repo ('.agents/temp/refresh-descriptor-' + [guid]::NewGuid().ToString('N'))
    $plugin = Join-Path $sandbox '.fixture-agent-data/actual-installed-files/arbitrary-plugin-folder'
    $calls = [Collections.Generic.List[object]]::new()
    . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome ($sandbox)
    function Invoke-ClosedInput {
        param($Command)
        if ($Command[0] -eq 'fourth-cli') { return @{ExitCode=0; Output=@('ps-ai@ps-ai-marketplace (v0.3.0) (enabled)')} }
        $calls.Add($Command)
        @{ExitCode=0; Output=@()}
    }
    try {
        New-Item -ItemType Directory -Path (Join-Path $plugin 'bin') -Force | Out-Null
        '{"name":"ps-ai","version":"0.3.0"}' | Set-Content (Join-Path $plugin 'plugin.json')
        '# inert refresh fixture' | Set-Content (Join-Path $plugin 'bin/legion-refresh.ps1')
        $null = Invoke-InstallRefresh -Entry $entry
        Assert-Equal 1 $calls.Count 'Fourth tool refresh uses descriptor config root and installed-files path'
        Assert-Equal (Join-Path $plugin 'bin/legion-refresh.ps1') $calls[0][3] 'Shared installer does not guess fourth tool directory layout'
        $entry.plugin.PSObject.Properties.Remove('defaultConfigDir')
        $errorMessage = ''
        try { Invoke-InstallRefresh -Entry $entry } catch { $errorMessage = $_.Exception.Message }
        Assert-True ($errorMessage.Contains('defaultConfigDir')) 'Missing default-root metadata names the descriptor field'
        $entry.plugin.PSObject.Properties.Remove('installedRoot')
        $errorMessage = ''
        try { Invoke-InstallRefresh -Entry $entry -ConfigDir $sandbox } catch { $errorMessage = $_.Exception.Message }
        Assert-True ($errorMessage.Contains('installedRoot')) 'Missing installed-root metadata is reported without guessing'
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe descriptor fixture cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}

& {
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    $descriptor = Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth/tool.json') -Raw | ConvertFrom-Json
    $descriptor.plugin | Add-Member defaultConfigDir '~/.fixture-agent-data'
    $descriptor.plugin | Add-Member installedRoot 'actual-installed-files'
    foreach ($field in @('installedRoot','defaultConfigDir')) {
        foreach ($badValue in @('../outside','/absolute','C:/absolute','~/../outside',42,'')) {
            $bad = $descriptor | ConvertTo-Json -Depth 100 | ConvertFrom-Json
            $bad.plugin.$field = $badValue
            $catalog = Get-InstallCatalog -Source $repo
            $catalog.tools[0].plugin = $bad.plugin
            Assert-Throws { Get-InstallCatalog -Catalog $catalog } "Standalone loader rejects unsafe plugin.$field"
        }
    }
}
