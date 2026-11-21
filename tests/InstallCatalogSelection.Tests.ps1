$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    $sandbox = Join-Path $repo ('.agents/temp/catalog-selection-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
    try {
        $catalog = Get-InstallCatalog -Source $repo
        $catalog.tools[0].hooks.hint = 'local catalog selected'
        $catalog | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $sandbox 'tools.json')
        $catalog.tools[0].hooks.hint = 'remote catalog selected'
        $catalog | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $sandbox 'remote.json')
        $overrides = @'
function Get-InstallHome { $PSScriptRoot }
function Get-InstallSourceText {
    param($Url)
    if ($Url -ne 'https://raw.githubusercontent.com/example/market/stable/plugins/ps-ai/tools.json') { throw "Unexpected URL: $Url" }
    Get-Content (Join-Path $PSScriptRoot 'remote.json') -Raw
}
function Ensure-InstallPowerShell { $true }
function Test-InstallStepDone { $false }
'@
        $text = [IO.File]::ReadAllText((Join-Path $repo 'plugins/ps-ai/install.ps1')).Replace('if (-not $NoRun) {', $overrides + "`nif (-not `$NoRun) {")
        $installer = Join-Path $sandbox 'install.ps1'
        [IO.File]::WriteAllText($installer, $text)
        foreach ($extra in @(@(), @('-Source', 'example/market'), @('-Ref', 'main'))) {
            $result = Invoke-ClosedInput -Command (@('pwsh', '-NoProfile', '-File', $installer, '-DryRun', '-Tools', 'claude') + $extra)
            Assert-Equal 0 $result.ExitCode 'Catalog preview succeeds with fake boundaries'
            $expected = if ($extra -contains '-Source') { 'remote catalog selected' } else { 'local catalog selected' }
            Assert-True ($result.Output -contains $expected) 'RefKeepsSiblingCatalog: only Source overrides the sibling catalog'
        }
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe catalog fixture cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
