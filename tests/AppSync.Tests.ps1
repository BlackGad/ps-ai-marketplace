. (Join-Path $PSScriptRoot 'lib/workspace.ps1')
$repo = Split-Path $PSScriptRoot -Parent
$plugin = Join-Path $repo 'plugins/legion'
. (Join-Path $plugin 'bin/lib/accounts.ps1')
. (Join-Path $plugin 'bin/lib/commands.ps1')
. (Join-Path $plugin 'bin/lib/footprints.ps1')

$version = Get-InstallPluginVersion -Root $plugin
$folder = Join-Path $HOME 'app sync'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$fake = Join-Path $folder 'fake-uv.ps1'
# The fake uv records each call with the environment it was given; a flag file makes the sync fail.
@'
Add-Content -LiteralPath $env:FAKE_UV_LOG -Value (($args -join ' ') + ' | ' + $env:UV_PROJECT_ENVIRONMENT)
if (Test-Path -LiteralPath $env:FAKE_UV_FAIL) { [Console]::Error.WriteLine('fixture sync failure'); exit 3 }
exit 0
'@ | Set-Content -LiteralPath $fake
$null = New-TestCommandStub -Folder (Join-Path $folder 'bin') -Name uv -Script $fake
$log = Join-Path $folder 'uv.log'
$failFlag = Join-Path $folder 'fail'
$savedPath = $env:PATH

function Get-UvCalls { if (Test-Path -LiteralPath $log) { @(Get-Content -LiteralPath $log) } else { @() } }

# An older ready version, as an earlier sync would have left it.
function New-OldApp {
    param([string]$HomeRoot, [string]$Version = '0.0.1')
    $path = Join-Path $HomeRoot ".legion/app/$Version"
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    @{ name = 'legion'; version = $Version } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $path 'plugin.json')
    $environment = Get-LegionPythonEnvironment -PluginRoot $path -HomeRoot $HomeRoot
    New-Item -ItemType Directory -Path $environment -Force | Out-Null
    'python' | Set-Content -LiteralPath (Join-Path $environment 'python.txt')
    return @{ Path = $path; Environment = $environment }
}

try {
    $env:PATH = (Join-Path $folder 'bin') + [IO.Path]::PathSeparator + $env:PATH
    $env:FAKE_UV_LOG = $log
    $env:FAKE_UV_FAIL = $failFlag

    # Fresh copy: the whole plugin folder, synced once into the version's own environment.
    $homeA = Join-Path $folder 'home a'
    $output = @(Sync-LegionApp -HomeRoot $homeA)
    $target = Join-Path $homeA ".legion/app/$version"
    Assert-True ($output -contains "legion app $version ready") 'A fresh sync reports the version it made ready'
    foreach ($relative in @('plugin.json', 'pyproject.toml', 'uv.lock', 'bin/legion.ps1', 'bin/lib/paths.ps1', 'src/legion/_cli.py', 'src/legion/_forward.py', 'schemas/tool.schema.json')) {
        Assert-Equal ([IO.File]::ReadAllText((Join-Path $plugin $relative))) ([IO.File]::ReadAllText((Join-Path $target $relative))) "The app copy holds $relative"
    }
    $environment = Get-LegionPythonEnvironment -PluginRoot $target -HomeRoot $homeA
    Assert-Equal "sync --project $target --frozen --quiet | $environment" ((Get-UvCalls) -join "`n") 'uv sync runs once, in the version folder, with that version''s environment'
    Assert-Equal $version ((Get-ChildItem -LiteralPath (Join-Path $homeA '.legion/app') -Force).Name -join '|') 'Only the version folder is left; no staging folder'
    Assert-Equal $target (Get-LegionAppVersions -HomeRoot $homeA)[0].Path 'The new version is the ready one'

    # Same version: skip without another sync.
    $output = @(Sync-LegionApp -HomeRoot $homeA)
    Assert-Equal "skip: legion app $version (already done)" ($output -join "`n") 'A repeat sync reports skip'
    Assert-Equal 1 (Get-UvCalls).Count 'A repeat sync does not run uv again'

    # A failed sync keeps the old version and its command; the next sync retries.
    Remove-Item -LiteralPath $log
    $homeB = Join-Path $folder 'home b'
    $old = New-OldApp -HomeRoot $homeB
    Write-LegionOwnerCommands -HomeRoot $homeB | Out-Null
    $shim = Join-Path $homeB '.legion/bin/legion'
    $oldShim = [IO.File]::ReadAllText($shim)
    Assert-True ($oldShim.Contains($old.Path)) 'The command runs the old version before the update'
    New-Item -ItemType File -Path $failFlag | Out-Null
    $output = @(Sync-LegionApp -HomeRoot $homeB)
    Assert-True (($output -join "`n").Contains('fixture sync failure')) 'The sync error is shown'
    Assert-True ($output -contains "legion app $version not ready (uv sync exited 3); run legion setup again") 'A failed sync says the app is not ready'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $homeB ".legion/app/$version"))) 'A failed sync leaves no new version folder'
    Assert-True (Test-Path -LiteralPath $old.Path) 'A failed sync keeps the old version'
    Assert-Equal '0.0.1' ((Get-ChildItem -LiteralPath (Join-Path $homeB '.legion/app') -Force).Name -join '|') 'A failed sync leaves no staging folder'
    Write-LegionOwnerCommands -HomeRoot $homeB | Out-Null
    Assert-Equal $oldShim ([IO.File]::ReadAllText($shim)) 'A failed sync keeps the command on the old version'
    Remove-Item -LiteralPath $failFlag
    $output = @(Sync-LegionApp -HomeRoot $homeB)
    Assert-True ($output -contains "legion app $version ready") 'The next sync retries'
    Assert-Equal 2 (Get-UvCalls).Count 'The retry runs uv again'
    Assert-True ($output -contains 'removed legion app 0.0.1') 'The old version is pruned once the new one is ready'
    Assert-True (-not (Test-Path -LiteralPath $old.Path) -and -not (Test-Path -LiteralPath $old.Environment)) 'Pruning removes the old version and its environment'
    Write-LegionOwnerCommands -HomeRoot $homeB | Out-Null
    Assert-True ([IO.File]::ReadAllText($shim).Contains((Join-Path $homeB ".legion/app/$version"))) 'The command moves to the new version'

    # An older source never replaces a newer app.
    Remove-Item -LiteralPath $log
    $homeC = Join-Path $folder 'home c'
    $newer = New-OldApp -HomeRoot $homeC -Version '99.0.0'
    $output = @(Sync-LegionApp -HomeRoot $homeC)
    Assert-Equal "skip: legion app $version (newer 99.0.0 in place)" ($output -join "`n") 'An older source is refused'
    Assert-Equal 0 (Get-UvCalls).Count 'An older source runs no sync'
    Assert-True ((Test-Path -LiteralPath $newer.Path) -and -not (Test-Path -LiteralPath (Join-Path $homeC ".legion/app/$version"))) 'The newer app stays alone'

    # A version folder that is not legion's is left untouched.
    $homeD = Join-Path $folder 'home d'
    $foreign = Join-Path $homeD ".legion/app/$version"
    New-Item -ItemType Directory -Path $foreign -Force | Out-Null
    'mine' | Set-Content -LiteralPath (Join-Path $foreign 'note.txt')
    $output = @(Sync-LegionApp -HomeRoot $homeD)
    Assert-Equal "skip: $foreign (not legion's)" ($output -join "`n") 'An unrelated destination is refused'
    Assert-Equal 'note.txt' ((Get-ChildItem -LiteralPath $foreign -Force).Name -join '|') 'An unrelated destination is unchanged'

    # A linked app folder is refused before anything is written through it.
    $homeE = Join-Path $folder 'home e'
    $elsewhere = Join-Path $folder 'elsewhere'
    New-Item -ItemType Directory -Path (Join-Path $homeE '.legion'), $elsewhere -Force | Out-Null
    New-Item -ItemType $(if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }) -Path (Join-Path $homeE '.legion/app') -Target $elsewhere | Out-Null
    $refused = $null
    try { Sync-LegionApp -HomeRoot $homeE | Out-Null } catch { $refused = $_.Exception.Message }
    Assert-True ("$refused".Contains('link')) 'A linked app folder is refused'
    Assert-Equal 0 @(Get-ChildItem -LiteralPath $elsewhere -Force).Count 'Nothing is written through the link'
    (Get-Item -LiteralPath (Join-Path $homeE '.legion/app') -Force).Delete()

    # Missing uv: one plain line, nothing copied.
    $homeF = Join-Path $folder 'home f'
    $output = @(& {
        function Get-Command { param($Name, $CommandType, $ErrorAction) return $null }
        Sync-LegionApp -HomeRoot $homeF
    })
    Assert-Equal 'uv is missing. Ask the owner before installing it, then run the legion installer again.' ($output -join "`n") 'Missing uv is one plain line'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $homeF '.legion/app'))) 'Missing uv copies nothing'

    if ($IsWindows) {
        # A version a running legion holds stays until the next sync.
        $homeG = Join-Path $folder 'home g'
        $held = New-OldApp -HomeRoot $homeG
        $lock = [IO.File]::Open((Join-Path $held.Environment 'python.txt'), 'Open', 'Read', 'None')
        try {
            $output = @(Sync-LegionApp -HomeRoot $homeG)
            Assert-True ($output -contains 'skip: legion app 0.0.1 (in use; removed at the next sync)') 'A held version is skipped'
            Assert-True ((Test-Path -LiteralPath $held.Path) -and (Test-Path -LiteralPath (Join-Path $held.Environment 'python.txt'))) 'A held version and its environment stay whole'
        } finally { $lock.Dispose() }
        $output = @(Sync-LegionApp -HomeRoot $homeG)
        Assert-True ($output -contains 'removed legion app 0.0.1') 'The next sync prunes the released version'
        Assert-True (-not (Test-Path -LiteralPath $held.Path) -and -not (Test-Path -LiteralPath $held.Environment)) 'The released version and environment are gone'
    }

    # Footprints: the app goes with its last owner, every version and environment it can remove.
    $homeH = Join-Path $folder 'home h'
    Sync-LegionApp -HomeRoot $homeH | Out-Null
    $current = Join-Path $homeH ".legion/app/$version"
    $currentEnvironment = Get-LegionPythonEnvironment -PluginRoot $current -HomeRoot $homeH
    New-Item -ItemType Directory -Path $currentEnvironment -Force | Out-Null
    'python' | Set-Content -LiteralPath (Join-Path $currentEnvironment 'python.txt')
    $app = Get-LegionHomePath -Path 'app' -HomeRoot $homeH
    foreach ($owner in @('claude:one', 'codex:two', 'codex:two')) { Add-LegionFootprint -HomeRoot $homeH -Kind app -Path $app -Owner $owner }
    Assert-Equal 'claude:one|codex:two' (@(Get-LegionFootprints -HomeRoot $homeH -Kind app).owners -join '|') 'Each installing account is registered once'
    Remove-LegionFootprintOwner -HomeRoot $homeH -Owner 'claude:one' | Out-Null
    Assert-True (Test-Path -LiteralPath $current) 'The app stays while an owner remains'
    if ($IsWindows) {
        $lock = [IO.File]::Open((Join-Path $currentEnvironment 'python.txt'), 'Open', 'Read', 'None')
        try {
            $output = @(Remove-LegionFootprintOwner -HomeRoot $homeH -Owner 'codex:two' -RetryOrphans)
            Assert-True ($output -contains "Kept app folder in use: $current (close legion, then run uninstall again)") 'A running version is kept with one line'
            Assert-Equal 1 @(Get-LegionFootprints -HomeRoot $homeH -Kind app).Count 'The kept app stays recorded for a retry'
        } finally { $lock.Dispose() }
    }
    $output = @(Remove-LegionFootprintOwner -HomeRoot $homeH -Owner 'codex:two' -RetryOrphans)
    Assert-True ($output -contains "Remove app version: $current") 'Uninstall names each app version it removes'
    Assert-True (-not (Test-Path -LiteralPath $app) -and -not (Test-Path -LiteralPath $currentEnvironment)) 'The last owner removes the app and its environments'
    Assert-Equal 0 @(Get-LegionFootprints -HomeRoot $homeH -Kind app).Count 'The removed app is no longer recorded'
} finally {
    $env:PATH = $savedPath
    Remove-Item Env:FAKE_UV_LOG, Env:FAKE_UV_FAIL -ErrorAction SilentlyContinue
}
