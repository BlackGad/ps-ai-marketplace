. (Join-Path $PSScriptRoot 'paths.ps1')

function Get-LegionTargetOwner {
    param($Tool, [string]$Folder, [string]$HomeRoot = $HOME)
    if (-not $Folder) { $Folder = $Tool.plugin.defaultConfigDir }
    $folderPath = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath((Resolve-LegionHomePath -Path $Folder -HomeRoot $HomeRoot)))
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

# One writer at a time: hold the returned lock while reading, changing and writing the index.
function Lock-LegionFootprints {
    param([string]$HomeRoot)
    $index = Get-LegionOwnerPath -Name Index -HomeRoot $HomeRoot
    if (-not (Test-LegionOwnerPathSafe -Path $index -StopRoot $HomeRoot)) { throw 'Footprint index contains a link; resolve it before writing' }
    New-Item -ItemType Directory -Path (Split-Path $index) -Force | Out-Null
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while ($true) {
        try { return [IO.File]::Open("$index.lock", 'OpenOrCreate', 'ReadWrite', 'None') }
        catch [IO.IOException] {
            if ([DateTime]::UtcNow -gt $deadline) { throw 'Footprint index is busy; another legion command is still running' }
            Start-Sleep -Milliseconds 100
        }
    }
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
    param([string]$HomeRoot = $HOME, [ValidateSet('file', 'folder', 'link', 'path-entry', 'edit')][string]$Kind,
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
        $kept = @(); $changed = $false
        foreach ($entry in @(Get-LegionFootprints -HomeRoot $HomeRoot)) {
            $remaining = @($entry.owners | Where-Object { $Owner -cnotcontains $_ })
            $ownersChanged = $remaining.Count -ne @($entry.owners).Count
            if (-not $ownersChanged -and -not ($RetryOrphans -and -not $remaining.Count)) { $kept += $entry; continue }
            $changed = $changed -or $ownersChanged
            $entry.owners = $remaining
            if ($remaining.Count) { $kept += $entry; continue }
            $path = Resolve-LegionHomePath -Path $entry.path -HomeRoot $HomeRoot
            if ($entry.kind -cin @('file', 'folder')) {
                if (-not (Test-LegionFootprintSafe -Entry $entry -HomeRoot $HomeRoot)) { "skip: $path (linked or not legion's)"; $kept += $entry; continue }
                if (Test-Path -LiteralPath $path) {
                    "Remove $($entry.kind): $path"
                    if (-not $WhatIf) { Remove-Item -LiteralPath ([IO.Path]::GetFullPath($path)) -Recurse -Force -ErrorAction Stop }
                }
                $changed = $true
            } elseif ($entry.kind -cne 'edit' -or -not $RemoveEdit -or -not (& $RemoveEdit -Entry $entry -HomeRoot $HomeRoot -WhatIf:$WhatIf)) { $kept += $entry }
            else { $changed = $true }
        }
        if ($changed -and -not $WhatIf) { Write-LegionFootprints -HomeRoot $HomeRoot -Entries $kept }
    } finally { if ($lock) { $lock.Dispose() } }
}
