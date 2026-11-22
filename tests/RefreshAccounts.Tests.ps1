$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path $root ('.agents/temp/refresh-accounts-' + [guid]::NewGuid().ToString('N'))
$savedPath = $env:PATH
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
try {
    . (Join-Path $root 'plugins/legion/bin/lib/accounts.ps1')
    $refresh = Join-Path $root 'plugins/legion/bin/legion-refresh.ps1'
    $fakeBin = Join-Path $scratch 'fake tools'
    New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
    $systemBin = if ($IsWindows) { Join-Path $env:SystemRoot 'System32' } else { '/bin:/usr/bin' }
    $env:PATH = @($fakeBin, $systemBin) -join [IO.Path]::PathSeparator
    $agents = @()
    foreach ($descriptor in Get-LegionTools) {
        $cli = Join-Path $fakeBin $(if ($IsWindows) { "$($descriptor.command).cmd" } else { $descriptor.command })
        $text = if ($IsWindows) { '@echo %' + $descriptor.configEnv + '%' + "`r`n@exit /b 0`r`n" }
            else { '#!/bin/sh' + "`n" + 'printenv ' + $descriptor.configEnv + "`n" }
        [IO.File]::WriteAllText($cli, $text)
        if (-not $IsWindows) { & chmod +x $cli }
        $agents += @{ id = "$($descriptor.id)-a"; tool = $descriptor.id; configDir = "~/.legion/agents/$($descriptor.id)-a" }
    }
    $settings = Join-Path $scratch '.legion/configuration/personalisation.json'
    Write-LegionPersonalisation -Data ([pscustomobject]@{ schemaVersion = 1; agents = $agents; channels = @() }) -Path $settings
    $original = [IO.File]::ReadAllText($settings)
    $first = @(& $refresh -HomeRoot $scratch)
    foreach ($agent in $agents) {
        $cli = Join-Path $fakeBin $(if ($IsWindows) { "$($agent.tool).cmd" } else { $agent.tool })
        $folder = Get-LegionNewAccountDir -Id $agent.id -HomeRoot $scratch
        $wrapper = Join-Path $scratch ".legion/bin/$($agent.id)"
        Assert-True (Test-Path $wrapper) 'Refresh recreates missing account launchers from settings'
        Assert-Equal $cli (Get-LegionWrapperTarget -Id $agent.id -Tool $agent.tool -HomeRoot $scratch -ConfigDir $folder) 'Refresh points the account at the fake stock CLI'
        Assert-True (Test-LegionLauncherExecutable $wrapper) 'Refreshed launcher is executable'
        if ($IsWindows) { $launched = & "$wrapper.cmd" }
        else { $launched = & $wrapper }
        Assert-Equal $folder $launched 'Recovered launcher runs the fake CLI with its account config folder'
    }
    Assert-Equal $original ([IO.File]::ReadAllText($settings)) 'Refresh leaves settings unchanged'
    $bin = Join-Path $scratch '.legion/bin'
    $before = @(Get-ChildItem $bin -File | Sort-Object Name | ForEach-Object { $_.LastWriteTimeUtc.Ticks }) -join '|'
    $repeat = @(& $refresh -HomeRoot $scratch)
    Assert-True ($repeat -contains 'skip: legion generated runtimes and launchers (already done)') 'Repeated refresh reports skip'
    Assert-Equal $before (@(Get-ChildItem $bin -File | Sort-Object Name | ForEach-Object { $_.LastWriteTimeUtc.Ticks }) -join '|') 'Repeated refresh changes no launcher timestamps'

    # An unavailable CLI blocks only its account; surviving launchers remain byte-for-byte intact.
    $env:PATH = $systemBin
    Remove-Item -LiteralPath (Join-Path $bin 'codex-a')
    if ($IsWindows) { Remove-Item -LiteralPath (Join-Path $bin 'codex-a.cmd') }
    $missing = @(& $refresh -HomeRoot $scratch)
    Assert-Equal 1 @($missing -match '^skip: account codex-a .*CLI.*not found').Count 'Missing CLI has one account-specific skip line'
    Assert-Equal $false (Test-Path (Join-Path $bin 'codex-a')) 'Missing CLI creates no launcher'
    Assert-True (Test-Path (Join-Path $bin 'claude-a')) 'Other account launchers are retained'
} finally {
    $env:PATH = $savedPath
    $allowed = [IO.Path]::GetFullPath((Join-Path $root '.agents/temp/'))
    if (-not ([IO.Path]::GetFullPath($scratch).StartsWith($allowed))) { throw 'Fixture cleanup escaped the worktree' }
    Remove-Item -LiteralPath $scratch -Recurse -Force
}
