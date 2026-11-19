$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$refresh = Join-Path $root 'plugins/ps-ai/bin/ps-ai-refresh.ps1'
$tempRoot = Join-Path $env:TEMP ('ps-ai-tests/' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $config = Join-Path $tempRoot '.agents/configuration'
    $bin = Join-Path $tempRoot '.agents/bin'
    $runtime = Join-Path $bin '.ps-ai-runtime/bin'
    New-Item -ItemType Directory -Path $config, $runtime -Force | Out-Null
    $file = Join-Path $config 'ps-ai-personalisation.json'
    @{
        agents=@(
            @{id='foundry-a';tool='claude';command='~/.agents/bin/foundry-a';configDir='~/.agents/accounts/foundry-a';provider=@{kind='foundry'}},
            @{id='external';tool='claude';command='~/custom/external';provider=@{kind='foundry'}}
        )
        projects=@{example=@{custom='keep'}}
    } | ConvertTo-Json -Depth 20 | Set-Content $file
    $ownerBytes = [IO.File]::ReadAllText($file)
    'stale runtime' | Set-Content (Join-Path $runtime 'ps-ai-foundry.ps1')
    'stale wrapper' | Set-Content (Join-Path $bin 'foundry-a')
    'custom wrapper' | Set-Content (Join-Path $bin 'external')
    $shim = Join-Path $bin 'ps-ai-overseer'
    @'
#!/bin/sh
exec pwsh -NoProfile -File '/old/owner'"'"'s/cache/bin/ps-ai-overseer.ps1' -Account chosen "$@"
'@ | Set-Content $shim
    $cmdShim = Join-Path $bin 'ps-ai-overseer.cmd'
    '@pwsh -NoProfile -File "C:\old\cache\bin\ps-ai-overseer.ps1" -Account chosen %*' | Set-Content $cmdShim
    & $refresh -HomeRoot $tempRoot | Out-Null
    Assert-Equal ([IO.File]::ReadAllText((Join-Path $root 'plugins/ps-ai/bin/ps-ai-foundry.ps1'))) ([IO.File]::ReadAllText((Join-Path $runtime 'ps-ai-foundry.ps1'))) 'Approved refresh updates copied runtime bytes'
    foreach ($name in @('foundry', 'tools')) {
        Assert-Equal ([IO.File]::ReadAllText((Join-Path $root "plugins/ps-ai/bin/lib/$name.ps1"))) ([IO.File]::ReadAllText((Join-Path $runtime "lib/$name.ps1"))) "Refresh installs the $name library in an existing runtime"
    }
    & {
        . (Join-Path $runtime 'ps-ai-foundry.ps1') -NoRun
        Assert-Equal 'claude' (@(Get-PsAiTools).id -join '|') 'Refreshed runner loads libraries and discovers its copied skill with the copied schema'
    }
    Assert-True ((Get-Content (Join-Path $bin 'foundry-a') -Raw).Contains('.ps-ai-runtime')) 'Refresh regenerates owned Foundry wrapper'
    foreach ($path in @($shim,$cmdShim)) {
        $text = Get-Content $path -Raw
        Assert-True ($text.Contains((Join-Path $root 'plugins/ps-ai/bin/ps-ai-overseer.ps1'))) 'Refresh retargets existing overseer shim'
        Assert-True ($text.Contains('-Account chosen')) 'Refresh preserves shim arguments'
    }
    Assert-Equal $ownerBytes ([IO.File]::ReadAllText($file)) 'Refresh preserves owner settings bytes'
    Assert-Equal 'custom wrapper' (Get-Content (Join-Path $bin 'external')) 'External command remains untouched'
    $before = @(Get-ChildItem $bin -File -Recurse | Sort-Object FullName | ForEach-Object { $_.LastWriteTimeUtc.Ticks }) -join '|'
    $repeat = @(& $refresh -HomeRoot $tempRoot)
    Assert-True ([bool]($repeat -match '^skip: .*\(already done\)$')) 'Repeated refresh reports skip'
    Assert-Equal $before (@(Get-ChildItem $bin -File -Recurse | Sort-Object FullName | ForEach-Object { $_.LastWriteTimeUtc.Ticks }) -join '|') 'Repeated refresh writes nothing'
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
