$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path $root ('.agents/temp/account-repair-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
$savedPath = $env:PATH
try {
    . (Join-Path $root 'plugins/legion/bin/lib/accounts.ps1')
    $env:PATH = if ($IsWindows) { Join-Path $env:SystemRoot 'System32' } else { '/bin:/usr/bin' }
    # Exercise interrupted chmod even on Windows; chmod itself is an inert seam.
    & {
        $originalWindows = $IsWindows
        try {
            Set-Variable IsWindows -Value $false -Force
            $state = @{ Calls = 0; Executable = $false }
            function Test-LegionLauncherExecutable { param($Path) return $state.Executable }
            function chmod { $state.Calls++; $state.Executable = $true; $global:LASTEXITCODE = 0 }
            $file = Join-Path $scratch 'launcher'
            [IO.File]::WriteAllText($file, 'owned content')
            $before = (Get-Item $file).LastWriteTimeUtc
            Write-LegionGeneratedFile -Path $file -Content 'owned content' -Executable
            Assert-Equal 1 $state.Calls 'G1 equal launcher content still repairs execute permission'
            Assert-Equal $before (Get-Item $file).LastWriteTimeUtc 'G1 permission repair preserves content timestamp'
            Write-LegionGeneratedFile -Path $file -Content 'owned content' -Executable
            Assert-Equal 1 $state.Calls 'G1 executable repeat makes no chmod call'
        } finally { Set-Variable IsWindows -Value $originalWindows -Force }
    }
    $custom = Join-Path $scratch 'custom target.ps1'
    '# inert' | Set-Content $custom
    $data = '{"schemaVersion":1,"agents":[],"channels":[]}' | ConvertFrom-Json
    $settings = Join-Path $scratch '.legion/configuration/personalisation.json'
    Add-LegionSubscriptionAccount -Id custom-a -Tool codex -Command $custom -HomeRoot $scratch -Data $data -Path $settings | Out-Null
    $folder = Get-LegionNewAccountDir custom-a $scratch
    Assert-Equal $custom (Get-LegionWrapperTarget -Id custom-a -Tool codex -HomeRoot $scratch -ConfigDir $folder) 'K8 direct account repair recovers its custom target'
    $wrapper = Join-Path $scratch '.legion/bin/custom-a'
    $before = [IO.File]::ReadAllText($settings)
    Remove-Item -LiteralPath $custom
    Assert-Equal $null (Get-LegionWrapperTarget -Id custom-a -Tool codex -HomeRoot $scratch -ConfigDir $folder) 'R5 B3 recovery rejects a missing custom executable'
    try {
        Add-LegionSubscriptionAccount -Id custom-a -Tool codex -HomeRoot $scratch -Data $data -Path $settings
        throw 'Expected target needed'
    } catch {
        Assert-True ($_.Exception.Message.StartsWith('target needed: custom-a')) 'R5 B3 direct repeat names the unavailable custom target'
    }
    Assert-Throws { New-LegionWrappers -Id missing-a -Tool codex -HomeRoot $scratch -RealCommand $custom } 'R5 B3 explicit missing target cannot create wrappers'
    Assert-Equal $false (Test-Path (Join-Path $scratch '.legion/bin/missing-a')) 'R5 B3 missing target creates no shell wrapper'
    Assert-Equal $false (Test-Path (Join-Path $scratch '.legion/bin/missing-a.cmd')) 'R5 B3 missing target creates no batch wrapper'
    Assert-Equal $before ([IO.File]::ReadAllText($settings)) 'R5 B3 missing target preserves settings'
    '# inert' | Set-Content $custom
    if ($IsWindows) {
        Remove-Item "$wrapper.cmd"
        $repair = @(Add-LegionSubscriptionAccount -Id custom-a -Tool codex -HomeRoot $scratch -Data $data -Path $settings)
        Assert-True ($repair -contains "wrote: launcher $wrapper.cmd") 'Repair reports the batch launcher it wrote'
        Assert-Equal 0 @($repair -match '^skip: account').Count 'Repair does not claim the account was unchanged'
        Assert-True ([IO.File]::ReadAllText("$wrapper.cmd").Contains($custom)) 'K8 direct add repairs the custom target without a stock CLI'
        Remove-Item "$wrapper.cmd"
    }
    Remove-Item $wrapper
    Assert-Throws { Add-LegionSubscriptionAccount -Id custom-a -Tool codex -HomeRoot $scratch -Data $data -Path $settings } 'K8 direct repair needs an explicit target when both wrappers are absent'
    Assert-Equal $false (Test-Path $wrapper) 'K8 ambiguous direct repair creates no stock wrapper'
    $repair = @(Add-LegionSubscriptionAccount -Id custom-a -Tool codex -Command $custom -HomeRoot $scratch -Data $data -Path $settings)
    Assert-True ($repair -contains "wrote: launcher $wrapper") 'Explicit repair reports the shell launcher it wrote'
    Assert-Equal 0 @($repair -match '^skip: account').Count 'Explicit repair does not report skip'
    $repeat = @(Add-LegionSubscriptionAccount -Id custom-a -Tool codex -HomeRoot $scratch -Data $data -Path $settings)
    Assert-Equal 'skip: account custom-a (already done)' ($repeat -join '') 'Unchanged account reports skip'
} finally {
    $env:PATH = $savedPath
    if (-not ([IO.Path]::GetFullPath($scratch).StartsWith([IO.Path]::GetFullPath((Join-Path $root '.agents/temp/'))))) { throw 'fixture cleanup escaped the worktree' }
    Remove-Item -LiteralPath $scratch -Recurse -Force
}
