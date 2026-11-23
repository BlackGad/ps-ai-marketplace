. (Join-Path $PSScriptRoot 'paths.ps1')

function Get-LegionTargetOwner {
    param($Tool, [string]$Folder, [string]$HomeRoot = $HOME)
    if (-not $Folder) { $Folder = $Tool.plugin.defaultConfigDir }
    # A linked and a physical spelling of one folder are one target.
    $folderPath = [IO.Path]::TrimEndingDirectorySeparator((Resolve-LegionDirectoryPath (Resolve-LegionHomePath -Path $Folder -HomeRoot $HomeRoot)))
    $owner = "$($Tool.id):$folderPath"
    if ($IsWindows) { $owner = $owner.ToLowerInvariant() }
    return $owner
}

function Get-LegionFootprints {
    param([string]$HomeRoot = $HOME, [string]$Kind)
    $index = Get-LegionOwnerPath -Name Index -HomeRoot $HomeRoot
    if (-not (Test-Path -LiteralPath $index)) { return }
    $data = Get-Content -LiteralPath $index -Raw | ConvertFrom-Json -ErrorAction Stop
    return $data.entries | Where-Object { -not $Kind -or $_.kind -ceq $Kind }
}

# An exclusive lock file: the open stream, or $null while another process holds it.
function Open-LegionLockFile {
    param([string]$Path)
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    try { return [IO.File]::Open($Path, 'OpenOrCreate', 'ReadWrite', 'None') }
    catch [IO.IOException] { return $null }
}

# Waits up to $Seconds for the lock file: the open stream, or $null when another process still holds it.
function Wait-LegionLockFile {
    param([string]$Path, [int]$Seconds)
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    while (-not ($lock = Open-LegionLockFile -Path $Path)) {
        if ([DateTime]::UtcNow -gt $deadline) { return $null }
        Start-Sleep -Milliseconds 100
    }
    return $lock
}

# One writer at a time: hold the returned lock while reading, changing and writing the index.
function Lock-LegionFootprints {
    param([string]$HomeRoot)
    $index = Get-LegionOwnerPath -Name Index -HomeRoot $HomeRoot
    if (-not (Test-LegionOwnerPathSafe -Path $index -StopRoot $HomeRoot)) { throw 'Footprint index contains a link; resolve it before writing' }
    $lock = Wait-LegionLockFile -Path "$index.lock" -Seconds 30
    if (-not $lock) { throw 'Footprint index is busy; another legion command is still running' }
    return $lock
}

# Replace the index whole, so an interrupted write never leaves half a file.
function Write-LegionFootprints {
    param([string]$HomeRoot, [array]$Entries)
    $index = Get-LegionOwnerPath -Name Index -HomeRoot $HomeRoot
    $temporary = "$index.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temporary, ([ordered]@{ schemaVersion = 1; entries = @($Entries) } | ConvertTo-Json -Depth 10) + "`n")
        [IO.File]::Move($temporary, $index, $true)
    } finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
}

function Add-LegionFootprint {
    param([string]$HomeRoot = $HOME, [ValidateSet('file', 'folder', 'link', 'path-entry', 'edit', 'app', 'app-version')][string]$Kind,
        [string]$Path, [string]$Key = '', [string]$Value = '', [string]$Owner)
    if ($Path -cne 'user PATH') {
        $Path = [IO.Path]::GetFullPath((Resolve-LegionHomePath -Path $Path -HomeRoot $HomeRoot))
        if (Test-LegionPathUnder -Path $Path -Root $HomeRoot -PreserveLinks) { $Path = '~/' + [IO.Path]::GetRelativePath($HomeRoot, $Path).Replace('\', '/') }
    }
    $lock = Lock-LegionFootprints -HomeRoot $HomeRoot
    try {
        $entries = @(Get-LegionFootprints -HomeRoot $HomeRoot)
        $entry = $entries | Where-Object { $_.kind -ceq $Kind -and (Get-LegionPathComparer).Equals($_.path, $Path) -and $_.key -ceq $Key -and $_.value -ceq $Value }
        if ($entry) {
            if ($entry.owners -ccontains $Owner) { return }
            $entry.owners = @($entry.owners) + $Owner
        } else { $entries += [pscustomobject]@{ kind = $Kind; path = $Path; key = $Key; value = $Value; owners = @($Owner) } }
        Write-LegionFootprints -HomeRoot $HomeRoot -Entries $entries
    } finally { $lock.Dispose() }
}

# Drops the entries of one kind recorded at one path.
function Remove-LegionFootprintEntry {
    param([string]$HomeRoot, [string]$Kind, [string]$Path)
    $lock = Lock-LegionFootprints -HomeRoot $HomeRoot
    try {
        $entries = @(Get-LegionFootprints -HomeRoot $HomeRoot)
        $kept = @($entries | Where-Object { $_.kind -cne $Kind -or -not (Get-LegionPathComparer).Equals([IO.Path]::GetFullPath((Resolve-LegionHomePath -Path $_.path -HomeRoot $HomeRoot)), [IO.Path]::GetFullPath($Path)) })
        if ($kept.Count -ne $entries.Count) { Write-LegionFootprints -HomeRoot $HomeRoot -Entries $kept }
    } finally { $lock.Dispose() }
}

function Test-LegionFootprintSafe {
    param($Entry, [string]$HomeRoot)
    if ($Entry.path -match '(^|[/\\])\.\.([/\\]|$)|[*?]') { return $false }
    $path = [IO.Path]::GetFullPath((Resolve-LegionHomePath -Path $Entry.path -HomeRoot $HomeRoot))
    if (-not (Test-LegionPathUnder -Path $path -Root (Get-LegionHomePath -Path '' -HomeRoot $HomeRoot) -PreserveLinks)) { return $false }
    # A link is itself a reparse point; it is ours while it still points at the recorded target.
    $walked = if ($Entry.kind -ceq 'link') { Split-Path $path } else { $path }
    if (-not (Test-LegionOwnerPathSafe -Path $walked -StopRoot $HomeRoot)) { return $false }
    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $true }
    switch ($Entry.kind) {
        link { return $item.LinkTarget -ceq $Entry.value }
        file { return Test-LegionOwnerCommandFile -Path $path }
    }
    return $item.PSIsContainer -and -not @(Get-ChildItem -LiteralPath $path -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count
}

# Removes the owners from their entries and undoes each entry left without an owner.
# Only the installer passes RemoveEdit, its settings editor, and RetryOrphans for entries an earlier run had to keep.
function Remove-LegionFootprintOwner {
    param([string]$HomeRoot = $HOME, [string[]]$Owner, [scriptblock]$RemoveEdit, [switch]$RetryOrphans, [switch]$WhatIf)
    if (-not (Test-Path -LiteralPath (Get-LegionOwnerPath -Name Index -HomeRoot $HomeRoot))) { return }
    $lock = if (-not $WhatIf) { Lock-LegionFootprints -HomeRoot $HomeRoot }
    try {
        $kept = @(); $changed = $false; $app = $null
        foreach ($entry in @(Get-LegionFootprints -HomeRoot $HomeRoot)) {
            $remaining = @($entry.owners | Where-Object { $Owner -cnotcontains $_ })
            $ownersChanged = $remaining.Count -ne @($entry.owners).Count
            if (-not $ownersChanged -and -not ($RetryOrphans -and -not $remaining.Count)) { $kept += $entry; continue }
            $changed = $changed -or $ownersChanged
            $entry.owners = $remaining
            if ($remaining.Count) { $kept += $entry; continue }
            $path = Resolve-LegionHomePath -Path $entry.path -HomeRoot $HomeRoot
            if ($entry.kind -ceq 'app') {
                Remove-LegionApp -HomeRoot $HomeRoot -WhatIf:$WhatIf
                $app = $entry
                $changed = $true
            } elseif ($entry.kind -cin @('file', 'folder')) {
                if (-not (Test-LegionFootprintSafe -Entry $entry -HomeRoot $HomeRoot)) { "skip: $path (linked or not legion's)"; $kept += $entry; continue }
                if (Test-Path -LiteralPath $path) {
                    "Remove $($entry.kind): $path"
                    if (-not $WhatIf) { Remove-Item -LiteralPath ([IO.Path]::GetFullPath($path)) -Recurse -Force -ErrorAction Stop }
                }
                $changed = $true
            } elseif ($entry.kind -cne 'edit' -or -not $RemoveEdit -or -not (& $RemoveEdit -Entry $entry -HomeRoot $HomeRoot -WhatIf:$WhatIf)) { $kept += $entry }
            else { $changed = $true }
        }
        if ($app) {
            # A version still in use keeps its record, and the app entry, for the next run.
            $kept = @($kept | Where-Object { $_.kind -cne 'app-version' -or (Test-LegionAppVersionLeft -Entry $_ -HomeRoot $HomeRoot) })
            if (@($kept | Where-Object kind -CEQ 'app-version').Count) { $kept += $app }
        }
        if ($changed -and -not $WhatIf) { Write-LegionFootprints -HomeRoot $HomeRoot -Entries $kept }
    } finally { if ($lock) { $lock.Dispose() } }
}

# Legion records each app version folder it creates (kind app-version), so only those are ever used or
# removed. A recorded version is safe when it sits directly in the app folder, has no link on the way to it
# or to its environment and holds no link inside. Only a safe version with the ready marker runs; an
# unfinished one, without the marker, is still legion's to remove. Removal deletes the marker last.
function Get-LegionAppMarker {
    param([string]$Path)
    return Join-Path $Path '.legion-app-ready'
}

function Get-LegionAppVersionPath {
    param($Entry, [string]$HomeRoot)
    return [IO.Path]::GetFullPath((Resolve-LegionHomePath -Path $Entry.path -HomeRoot $HomeRoot))
}

function Test-LegionAppVersionSafe {
    param([string]$Path, [string]$HomeRoot)
    $app = [IO.Path]::GetFullPath((Get-LegionHomePath -Path 'app' -HomeRoot $HomeRoot))
    if (-not (Get-LegionPathComparer).Equals((Split-Path $Path -Parent), $app)) { return $false }
    $environment = Get-LegionPythonEnvironment -PluginRoot $Path -HomeRoot $HomeRoot
    if (-not (Test-LegionOwnerPathSafe -Path $Path -StopRoot $HomeRoot) -or -not (Test-LegionOwnerPathSafe -Path $environment -StopRoot $HomeRoot)) { return $false }
    if (-not (Test-Path -LiteralPath $Path)) { return $true }
    return -not @(Get-ChildItem -LiteralPath $Path -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count
}

# True while a recorded version still has its folder or its environment.
function Test-LegionAppVersionLeft {
    param($Entry, [string]$HomeRoot)
    $path = Get-LegionAppVersionPath -Entry $Entry -HomeRoot $HomeRoot
    return (Test-Path -LiteralPath $path) -or (Test-Path -LiteralPath (Get-LegionPythonEnvironment -PluginRoot $path -HomeRoot $HomeRoot))
}

# One safe recorded version: its folder (marker last), then its environment, so an app never stays without
# its environment. A delete that fails, such as on a Windows lock, keeps the rest for a later run: false.
function Remove-LegionAppVersion {
    param([string]$Path, [string]$HomeRoot)
    $environment = Get-LegionPythonEnvironment -PluginRoot $Path -HomeRoot $HomeRoot
    try {
        if (Test-Path -LiteralPath $Path) {
            Get-ChildItem -LiteralPath $Path -Force | Where-Object Name -CNE (Split-Path (Get-LegionAppMarker $Path) -Leaf) | Remove-Item -Recurse -Force -ErrorAction Stop
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        }
        if (Test-Path -LiteralPath $environment) { Remove-Item -LiteralPath $environment -Recurse -Force -ErrorAction Stop }
        return $true
    } catch { return $false }
}

# Uninstall: every recorded app version legion can remove; one line for each version still in use.
# The caller holds the footprint lock and drops the records of removed versions.
function Remove-LegionApp {
    param([string]$HomeRoot, [switch]$WhatIf)
    foreach ($entry in @(Get-LegionFootprints -HomeRoot $HomeRoot -Kind app-version)) {
        if (-not (Test-LegionAppVersionLeft -Entry $entry -HomeRoot $HomeRoot)) { continue }
        $path = Get-LegionAppVersionPath -Entry $entry -HomeRoot $HomeRoot
        if (-not (Test-LegionAppVersionSafe -Path $path -HomeRoot $HomeRoot)) { "skip: $path (linked or not legion's)"; continue }
        "Remove app version: $path"
        if (-not $WhatIf -and -not (Remove-LegionAppVersion -Path $path -HomeRoot $HomeRoot)) { "Kept app version in use: $path (close legion, then run uninstall again)" }
    }
    # The app folder goes once only the sync lock is left in it.
    $app = Get-LegionHomePath -Path 'app' -HomeRoot $HomeRoot
    if ($WhatIf -or -not (Test-Path -LiteralPath $app) -or -not (Test-LegionOwnerPathSafe -Path $app -StopRoot $HomeRoot)) { return }
    if (@(Get-ChildItem -LiteralPath $app -Force | Where-Object Name -CNE '.sync.lock').Count) { return }
    Remove-Item -LiteralPath (Join-Path $app '.sync.lock') -Force -ErrorAction SilentlyContinue
    if (-not @(Get-ChildItem -LiteralPath $app -Force).Count) { Remove-Item -LiteralPath $app -Force }
}
