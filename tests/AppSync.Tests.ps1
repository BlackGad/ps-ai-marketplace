. (Join-Path $PSScriptRoot 'lib/workspace.ps1')
$repo = Split-Path $PSScriptRoot -Parent
$plugin = Join-Path $repo 'plugins/legion'
. (Join-Path $plugin 'bin/lib/commands.ps1')
. (Join-Path $plugin 'bin/lib/footprints.ps1')

$version = Get-InstallPluginVersion -Root $plugin
$folder = Join-Path $HOME 'app sync'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$fake = Join-Path $folder 'fake-uv.ps1'
# The fake uv records each call with the environment it was given; a flag file makes the sync fail, and
# FAKE_UV_LINK makes it leave a link in the version folder.
@'
Add-Content -LiteralPath $env:FAKE_UV_LOG -Value (($args -join ' ') + ' | ' + $env:UV_PROJECT_ENVIRONMENT)
if (Test-Path -LiteralPath $env:FAKE_UV_FAIL) { [Console]::Error.WriteLine('fixture sync failure'); exit 3 }
if ($env:FAKE_UV_LINK) { New-Item -ItemType $(if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }) -Path (Join-Path $args[2] 'linked') -Target $env:FAKE_UV_LINK | Out-Null }
exit 0
'@ | Set-Content -LiteralPath $fake
$null = New-TestCommandStub -Folder (Join-Path $folder 'bin') -Name uv -Script $fake
$log = Join-Path $folder 'uv.log'
$failFlag = Join-Path $folder 'fail'
$savedPath = $env:PATH
$linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }

function Get-UvCalls { if (Test-Path -LiteralPath $log) { @(Get-Content -LiteralPath $log) } else { @() } }
function Get-Marker { param([string]$Path) Join-Path $Path '.legion-app-ready' }
function Get-Shim { param([string]$HomeRoot) [IO.File]::ReadAllText((Join-Path $HomeRoot '.legion/bin/legion')) }

# A ready version as an earlier sync leaves it: the copy, its marker, its environment and its record.
function New-OldApp {
    param([string]$HomeRoot, [string]$Version = '0.0.1', [switch]$NotRecorded)
    $path = Join-Path $HomeRoot ".legion/app/$Version"
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    @{ name = 'legion'; version = $Version } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $path 'plugin.json')
    New-Item -ItemType File -Path (Get-Marker $path) -Force | Out-Null
    $environment = Get-LegionPythonEnvironment -PluginRoot $path -HomeRoot $HomeRoot
    New-Item -ItemType Directory -Path $environment -Force | Out-Null
    'python' | Set-Content -LiteralPath (Join-Path $environment 'python.txt')
    if (-not $NotRecorded) { Add-LegionFootprint -HomeRoot $HomeRoot -Kind app-version -Path $path -Owner legion }
    return @{ Path = $path; Environment = $environment }
}

try {
    $env:PATH = (Join-Path $folder 'bin') + [IO.Path]::PathSeparator + $env:PATH
    $env:FAKE_UV_LOG = $log
    $env:FAKE_UV_FAIL = $failFlag

    # Fresh copy: the whole plugin folder, synced once into the version's own environment, then marked and recorded.
    $homeA = Join-Path $folder 'home a'
    $output = @(Publish-LegionApp -HomeRoot $homeA)
    $target = Join-Path $homeA ".legion/app/$version"
    Assert-True ($output -contains "legion app $version ready") 'A fresh sync reports the version it made ready'
    foreach ($relative in @('plugin.json', 'pyproject.toml', 'uv.lock', 'bin/legion.ps1', 'bin/lib/paths.ps1', 'src/legion/_cli.py', 'src/legion/_forward.py', 'schemas/tool.schema.json')) {
        Assert-Equal ([IO.File]::ReadAllText((Join-Path $plugin $relative))) ([IO.File]::ReadAllText((Join-Path $target $relative))) "The app copy holds $relative"
    }
    $environment = Get-LegionPythonEnvironment -PluginRoot $target -HomeRoot $homeA
    Assert-Equal "sync --project $target --frozen --quiet | $environment" ((Get-UvCalls) -join "`n") 'uv sync runs once, in the version folder, with that version''s environment'
    Assert-True (Test-Path -LiteralPath (Get-Marker $target) -PathType Leaf) 'A synced version gets the ready marker'
    Assert-Equal "~/.legion/app/$version" (@(Get-LegionFootprints -HomeRoot $homeA -Kind app-version).path -join '|') 'The version legion made is recorded on its own'
    Assert-Equal $version (@(Get-ChildItem -LiteralPath (Join-Path $homeA '.legion/app') -Directory -Force).Name -join '|') 'Only the version folder is left; no staging folder'
    Assert-Equal $target (Get-LegionAppVersions -HomeRoot $homeA)[0].Path 'The new version is the ready one'
    Assert-True ((Get-Shim $homeA).Contains($target)) 'The command runs the version sync made ready'

    # Same version: skip without another sync.
    $output = @(Publish-LegionApp -HomeRoot $homeA)
    Assert-True ($output -contains "skip: legion app $version (already done)") 'A repeat sync reports skip'
    Assert-Equal 1 (Get-UvCalls).Count 'A repeat sync does not run uv again'

    # A folder without the marker is unfinished: never chosen, and the next sync repairs it in place.
    Remove-Item -LiteralPath (Get-Marker $target) -Force
    Assert-Equal 0 @(Get-LegionAppVersions -HomeRoot $homeA).Count 'A version without the marker is not ready'
    $output = @(Publish-LegionApp -HomeRoot $homeA)
    Assert-True ($output -contains "legion app $version ready") 'An unfinished version is synced again'
    Assert-Equal "sync --project $target --frozen --quiet | $environment" (Get-UvCalls)[-1] 'The repair syncs at the final path'
    Assert-True (Test-Path -LiteralPath (Get-Marker $target) -PathType Leaf) 'The repair marks the version ready'

    # One sync at a time: a second one waits for the first to end, then compares versions again.
    Remove-Item -LiteralPath (Get-Marker $target) -Force
    $calls = (Get-UvCalls).Count
    $held = Join-Path $folder 'lock held'
    $holdLock = "`$lock = [IO.File]::Open('$(Join-Path $homeA '.legion/app/.sync.lock')', 'OpenOrCreate', 'ReadWrite', 'None'); " +
        "New-Item -ItemType File -Path '$held' | Out-Null; Start-Sleep -Seconds 2; `$lock.Dispose()"
    $holder = Start-Process (Get-Process -Id $PID).Path -PassThru -NoNewWindow -ArgumentList '-NoProfile', '-EncodedCommand', ([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($holdLock)))
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not (Test-Path -LiteralPath $held) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
    $output = @(Publish-LegionApp -HomeRoot $homeA)
    Assert-True $holder.HasExited 'The second sync waits until the first one ends'
    Assert-True ($output -contains "legion app $version ready") 'The waiting sync then makes the version ready'
    Assert-Equal ($calls + 1) (Get-UvCalls).Count 'The waiting sync runs uv once'

    # A failed sync keeps the old version and its command; the next sync retries.
    Remove-Item -LiteralPath $log
    $homeB = Join-Path $folder 'home b'
    $old = New-OldApp -HomeRoot $homeB
    $newB = Join-Path $homeB ".legion/app/$version"
    Write-LegionOwnerCommands -App $old.Path -HomeRoot $homeB | Out-Null
    $oldShim = Get-Shim $homeB
    New-Item -ItemType File -Path $failFlag | Out-Null
    $output = @(Publish-LegionApp -HomeRoot $homeB)
    Assert-True (($output -join "`n").Contains('fixture sync failure')) 'The sync error is shown'
    Assert-True ($output -contains "legion app $version not ready (uv sync exited 3); run legion setup again") 'A failed sync says the app is not ready'
    Assert-True (-not (Test-Path -LiteralPath (Get-Marker $newB))) 'A failed sync leaves no ready marker'
    Assert-True (Test-Path -LiteralPath $old.Path) 'A failed sync keeps the old version'
    Assert-Equal $oldShim (Get-Shim $homeB) 'A failed sync keeps the command on the old version'
    Remove-Item -LiteralPath $failFlag
    $output = @(Publish-LegionApp -HomeRoot $homeB)
    Assert-True ($output -contains "legion app $version ready") 'The next sync retries'
    Assert-Equal 2 (Get-UvCalls).Count 'The retry runs uv again'
    Assert-True ((Get-Shim $homeB).Contains($newB)) 'The command moves to the new version'

    # Publish before prune: every command points at the new version before an old one goes; the previous
    # ready version stays for a running legion, only older ones are removed.
    $homeP = Join-Path $folder 'home p'
    $oldest = New-OldApp -HomeRoot $homeP -Version '0.0.1'
    $previous = New-OldApp -HomeRoot $homeP -Version '0.0.2'
    $newP = Join-Path $homeP ".legion/app/$version"
    $script:pruned = @()
    $output = @(& {
        function Remove-LegionAppVersion {
            param([string]$Path, [string]$HomeRoot)
            $script:pruned += [pscustomobject]@{ Path = $Path; ShimReady = (Get-Shim $homeP).Contains($newP) }
            Remove-Item -LiteralPath $Path, (Get-LegionPythonEnvironment -PluginRoot $Path -HomeRoot $HomeRoot) -Recurse -Force
            return $true
        }
        Publish-LegionApp -HomeRoot $homeP
    })
    Assert-Equal $oldest.Path ($script:pruned.Path -join '|') 'Only versions older than the previous ready one are pruned'
    Assert-True ($script:pruned[0].ShimReady) 'The command points at the new version before anything is pruned'
    Assert-True ($output -contains 'removed legion app 0.0.1') 'The prune names the removed version'
    Assert-True (-not (Test-Path -LiteralPath $oldest.Path) -and -not (Test-Path -LiteralPath $oldest.Environment)) 'Pruning removes the old version and its environment'
    Assert-True ((Test-Path -LiteralPath $previous.Path) -and (Test-Path -LiteralPath $previous.Environment)) 'The previous ready version stays whole'
    Assert-Equal "~/.legion/app/0.0.2|~/.legion/app/$version" (@(Get-LegionFootprints -HomeRoot $homeP -Kind app-version).path -join '|') 'The removed version is no longer recorded'

    # An older source never replaces a newer app; the command stays on the newer one.
    Remove-Item -LiteralPath $log
    $homeC = Join-Path $folder 'home c'
    $newer = New-OldApp -HomeRoot $homeC -Version '99.0.0'
    $output = @(Publish-LegionApp -HomeRoot $homeC)
    Assert-True ($output -contains "skip: legion app $version (newer 99.0.0 in place)") 'An older source is refused'
    Assert-Equal 0 (Get-UvCalls).Count 'An older source runs no sync'
    Assert-True ((Test-Path -LiteralPath $newer.Path) -and -not (Test-Path -LiteralPath (Join-Path $homeC ".legion/app/$version"))) 'The newer app stays alone'
    Assert-True ((Get-Shim $homeC).Contains($newer.Path)) 'The command runs the newer app'

    # A version folder that is not legion's is left untouched.
    $homeD = Join-Path $folder 'home d'
    $foreign = Join-Path $homeD ".legion/app/$version"
    New-Item -ItemType Directory -Path $foreign -Force | Out-Null
    'mine' | Set-Content -LiteralPath (Join-Path $foreign 'note.txt')
    $output = @(Publish-LegionApp -HomeRoot $homeD)
    Assert-True ($output -contains "skip: $foreign (not legion's)") 'An unrelated destination is refused'
    Assert-Equal 'note.txt' ((Get-ChildItem -LiteralPath $foreign -Force).Name -join '|') 'An unrelated destination is unchanged'

    # Ownership: an unrecorded folder, even with a marker, and a linked recorded one are never chosen or removed.
    $homeO = Join-Path $folder 'home o'
    $stranger = New-OldApp -HomeRoot $homeO -Version '98.0.0' -NotRecorded
    $elsewhereO = Join-Path $folder 'elsewhere o'
    $linkedTarget = New-OldApp -HomeRoot $elsewhereO -Version '97.0.0' -NotRecorded
    $linked = Join-Path $homeO '.legion/app/97.0.0'
    New-Item -ItemType $linkType -Path $linked -Target $linkedTarget.Path | Out-Null
    Add-LegionFootprint -HomeRoot $homeO -Kind app-version -Path $linked -Owner legion
    Publish-LegionApp -HomeRoot $homeO | Out-Null
    Assert-Equal (Join-Path $homeO ".legion/app/$version") (@(Get-LegionAppVersions -HomeRoot $homeO).Path -join '|') 'Only the version legion recorded and left unlinked is ready'
    Assert-True ((Get-Shim $homeO).Contains((Join-Path $homeO ".legion/app/$version"))) 'The command never runs an unrecorded or linked folder'
    Add-LegionFootprint -HomeRoot $homeO -Kind app -Path (Get-LegionHomePath -Path 'app' -HomeRoot $homeO) -Owner 'codex:one'
    $output = @(Remove-LegionFootprintOwner -HomeRoot $homeO -Owner 'codex:one' -RetryOrphans)
    Assert-True ($output -contains "skip: $linked (linked or not legion's)") 'Uninstall refuses a linked version'
    Assert-True ((Test-Path -LiteralPath $stranger.Path) -and (Test-Path -LiteralPath $stranger.Environment)) 'Uninstall never removes an unrecorded folder'
    Assert-True ((Test-Path -LiteralPath $linkedTarget.Path) -and (Test-Path -LiteralPath (Get-Marker $linkedTarget.Path))) 'Uninstall never removes through a link'
    (Get-Item -LiteralPath $linked -Force).Delete()

    # A linked environment parent makes the version unsafe too.
    $homeL = Join-Path $folder 'home l'
    $linkedEnv = New-OldApp -HomeRoot $homeL -Version '96.0.0'
    $elsewhereL = Join-Path $folder 'elsewhere l'
    Move-Item -LiteralPath (Join-Path $homeL '.legion/python') -Destination $elsewhereL
    New-Item -ItemType $linkType -Path (Join-Path $homeL '.legion/python') -Target $elsewhereL | Out-Null
    Assert-Equal 0 @(Get-LegionAppVersions -HomeRoot $homeL).Count 'A version whose environment folder is linked is never chosen'
    Add-LegionFootprint -HomeRoot $homeL -Kind app -Path (Get-LegionHomePath -Path 'app' -HomeRoot $homeL) -Owner 'codex:one'
    Remove-LegionFootprintOwner -HomeRoot $homeL -Owner 'codex:one' -RetryOrphans | Out-Null
    Assert-True ((Test-Path -LiteralPath $linkedEnv.Path) -and @(Get-ChildItem -LiteralPath $elsewhereL -Recurse -File).Count) 'A version whose environment folder is linked is never removed'
    (Get-Item -LiteralPath (Join-Path $homeL '.legion/python') -Force).Delete()

    # A fresh sync refuses a linked environment folder too: uv never writes through it.
    $homeK = Join-Path $folder 'home k'
    $elsewhereK = Join-Path $folder 'elsewhere k'
    New-Item -ItemType Directory -Path (Join-Path $homeK '.legion'), $elsewhereK -Force | Out-Null
    New-Item -ItemType $linkType -Path (Join-Path $homeK '.legion/python') -Target $elsewhereK | Out-Null
    $calls = (Get-UvCalls).Count
    $output = @(Publish-LegionApp -HomeRoot $homeK)
    Assert-True (@($output | Where-Object { $_ -like '*(linked version or environment)' }).Count -eq 1) 'A fresh sync with a linked environment folder is refused'
    Assert-Equal $calls (Get-UvCalls).Count 'A linked environment folder gets no uv sync'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $homeK '.legion/bin/legion'))) 'A linked environment folder gets no command'
    (Get-Item -LiteralPath (Join-Path $homeK '.legion/python') -Force).Delete()

    # A link that appears in the version during the sync stops it before the version is marked or run.
    $homeJ = Join-Path $folder 'home j'
    $env:FAKE_UV_LINK = $elsewhereK
    try { $output = @(Publish-LegionApp -HomeRoot $homeJ) } finally { Remove-Item Env:FAKE_UV_LINK }
    $linkedJ = Join-Path $homeJ ".legion/app/$version"
    Assert-True (@($output | Where-Object { $_ -like '*(linked)' }).Count -eq 1) 'A version that holds a link after the sync is refused'
    Assert-True (-not (Test-Path -LiteralPath (Get-Marker $linkedJ))) 'A version that holds a link is not marked ready'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $homeJ '.legion/bin/legion'))) 'A version that holds a link gets no command'
    (Get-Item -LiteralPath (Join-Path $linkedJ 'linked') -Force).Delete()

    # A recorded version a failed sync left without the marker is legion's but never run: prune and
    # uninstall remove it.
    $homeU = Join-Path $folder 'home u'
    $unfinished = New-OldApp -HomeRoot $homeU -Version '0.0.1'
    Remove-Item -LiteralPath (Get-Marker $unfinished.Path) -Force
    $output = @(Publish-LegionApp -HomeRoot $homeU)
    Assert-True ($output -contains 'removed legion app 0.0.1') 'Prune removes an unfinished older version'
    Assert-True (-not (Test-Path -LiteralPath $unfinished.Path) -and -not (Test-Path -LiteralPath $unfinished.Environment)) 'Prune removes the unfinished version and its environment'
    $homeW = Join-Path $folder 'home w'
    $unfinished = New-OldApp -HomeRoot $homeW -Version '0.0.1'
    Remove-Item -LiteralPath (Get-Marker $unfinished.Path) -Force
    Add-LegionFootprint -HomeRoot $homeW -Kind app -Path (Get-LegionHomePath -Path 'app' -HomeRoot $homeW) -Owner 'codex:one'
    $output = @(Remove-LegionFootprintOwner -HomeRoot $homeW -Owner 'codex:one' -RetryOrphans)
    Assert-True ($output -contains "Remove app version: $($unfinished.Path)") 'Uninstall removes an unfinished version'
    Assert-True (-not (Test-Path -LiteralPath $unfinished.Path) -and -not (Test-Path -LiteralPath $unfinished.Environment)) 'Uninstall removes the unfinished version and its environment'

    # A linked app folder is refused before anything is written through it.
    $homeE = Join-Path $folder 'home e'
    $elsewhere = Join-Path $folder 'elsewhere'
    New-Item -ItemType Directory -Path (Join-Path $homeE '.legion'), $elsewhere -Force | Out-Null
    New-Item -ItemType $linkType -Path (Join-Path $homeE '.legion/app') -Target $elsewhere | Out-Null
    $refused = $null
    try { Publish-LegionApp -HomeRoot $homeE | Out-Null } catch { $refused = $_.Exception.Message }
    Assert-True ("$refused".Contains('link')) 'A linked app folder is refused'
    Assert-Equal 0 @(Get-ChildItem -LiteralPath $elsewhere -Force).Count 'Nothing is written through the link'
    (Get-Item -LiteralPath (Join-Path $homeE '.legion/app') -Force).Delete()

    # Missing uv: one plain line, nothing copied.
    $homeF = Join-Path $folder 'home f'
    $output = @(& {
        function Get-Command { param($Name, $CommandType, $ErrorAction) return $null }
        Publish-LegionApp -HomeRoot $homeF
    })
    Assert-True ($output -contains 'uv is missing. Ask the owner before installing it, then run the legion installer again.') 'Missing uv is one plain line'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $homeF ".legion/app/$version"))) 'Missing uv copies nothing'

    if ($IsWindows) {
        # An old version a running legion holds stays until the next sync.
        $homeG = Join-Path $folder 'home g'
        $held = New-OldApp -HomeRoot $homeG -Version '0.0.1'
        $null = New-OldApp -HomeRoot $homeG -Version '0.0.2'
        $lock = [IO.File]::Open((Join-Path $held.Environment 'python.txt'), 'Open', 'Read', 'None')
        try {
            $output = @(Publish-LegionApp -HomeRoot $homeG)
            Assert-True ($output -contains 'skip: legion app 0.0.1 (in use; removed at the next sync)') 'A held version is skipped'
            Assert-True (Test-Path -LiteralPath (Join-Path $held.Environment 'python.txt')) 'A held environment stays'
        } finally { $lock.Dispose() }
        $output = @(Publish-LegionApp -HomeRoot $homeG)
        Assert-True ($output -contains 'removed legion app 0.0.1') 'The next sync prunes the released version'
        Assert-True (-not (Test-Path -LiteralPath $held.Path) -and -not (Test-Path -LiteralPath $held.Environment)) 'The released version and environment are gone'
    }

    # Footprints: the app goes with its last owner, every version and environment it can remove.
    $homeH = Join-Path $folder 'home h'
    Publish-LegionApp -HomeRoot $homeH | Out-Null
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
            Assert-True ($output -contains "Kept app version in use: $current (close legion, then run uninstall again)") 'A running version is kept with one line'
            Assert-Equal 1 @(Get-LegionFootprints -HomeRoot $homeH -Kind app).Count 'The kept app stays recorded for a retry'
            Assert-Equal 1 @(Get-LegionFootprints -HomeRoot $homeH -Kind app-version).Count 'The kept version stays recorded for a retry'
            Assert-True (-not (Test-Path -LiteralPath $current) -or (Test-Path -LiteralPath $currentEnvironment)) 'An app never stays without its environment'
        } finally { $lock.Dispose() }
    }
    $output = @(Remove-LegionFootprintOwner -HomeRoot $homeH -Owner 'codex:two' -RetryOrphans)
    Assert-True ($output -contains "Remove app version: $current") 'Uninstall names each app version it removes'
    Assert-True (-not (Test-Path -LiteralPath $app) -and -not (Test-Path -LiteralPath $currentEnvironment)) 'The last owner removes the app and its environments'
    Assert-Equal 0 @(Get-LegionFootprints -HomeRoot $homeH | Where-Object { $_.kind -cin @('app', 'app-version') }).Count 'The removed app is no longer recorded'
} finally {
    $env:PATH = $savedPath
    Remove-Item Env:FAKE_UV_LOG, Env:FAKE_UV_FAIL -ErrorAction SilentlyContinue
}
