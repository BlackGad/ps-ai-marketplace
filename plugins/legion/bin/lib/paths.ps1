function Get-LegionHomePath {
    param([string]$Path, [string]$HomeRoot = $HOME)
    return Join-Path (Join-Path $HomeRoot '.legion') $Path
}

# Owner-file names live here; standalone install.ps1 carries the same small helpers.
function Get-LegionOwnerPath {
    param([ValidateSet('Settings', 'Notes', 'Update', 'Runtime', 'Install')][string]$Name,
        [string]$HomeRoot = $HOME, [switch]$Existing, [switch]$Legacy)
    $names = @{
        Settings = @('configuration/personalisation.json', 'configuration/ps-ai-personalisation.json')
        Notes = @('configuration/notes.md', 'configuration/ps-ai-notes.md')
        Update = @('temp/update.json', 'temp/ps-ai-update.json')
        Runtime = @('bin/.runtime', 'bin/.ps-ai-runtime')
        Install = @('temp/install-', 'temp/ps-ai-install-')
    }
    $new = Get-LegionHomePath -HomeRoot $HomeRoot -Path $names[$Name][0]
    $old = Get-LegionHomePath -HomeRoot $HomeRoot -Path $names[$Name][1]
    if ($Legacy -or ($Existing -and -not (Test-Path -LiteralPath $new) -and (Test-Path -LiteralPath $old))) { return $old }
    return $new
}

function Set-LegionTextPreservingEncoding {
    param([string]$Path, [string]$Text)
    $reader = [IO.StreamReader]::new($Path, $true)
    try {
        $original = $reader.ReadToEnd()
        $encoding = $reader.CurrentEncoding
    } finally { $reader.Dispose() }
    if ($original -ceq $Text) { return }
    $bytes = [IO.File]::ReadAllBytes($Path)
    $preamble = $encoding.GetPreamble()
    $hasPreamble = $preamble.Length -gt 0 -and $bytes.Length -ge $preamble.Length
    for ($i = 0; $hasPreamble -and $i -lt $preamble.Length; $i++) { $hasPreamble = $bytes[$i] -eq $preamble[$i] }
    $updated = $encoding.GetBytes($Text)
    $roundTrip = $encoding.GetBytes($original)
    if ($hasPreamble) {
        $updated = [byte[]]($preamble + $updated)
        $roundTrip = [byte[]]($preamble + $roundTrip)
    }
    if ([Convert]::ToBase64String($bytes) -cne [Convert]::ToBase64String($roundTrip)) { throw 'File encoding is not lossless; resolve it manually before editing' }
    [IO.File]::WriteAllBytes($Path, $updated)
}

function Test-LegionOwnerPathSafe {
    param([string]$Path)
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if ((Test-Path -LiteralPath $current) -and ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
        $current = Split-Path $current -Parent
    }
    return $true
}

function Move-LegionOwnerFiles {
    param([string]$HomeRoot = $HOME)
    $messages = @()
    # Check both pairs before moving either; a conflict must leave the whole setup alone.
    foreach ($name in @('Settings', 'Notes')) {
        $old = Get-LegionOwnerPath -HomeRoot $HomeRoot -Name $name -Legacy
        $new = Get-LegionOwnerPath -HomeRoot $HomeRoot -Name $name
        foreach ($path in @($old, $new)) {
            if (-not (Test-LegionOwnerPathSafe -Path $path)) {
                return @{ Blocked = $true; Messages = @('Manual step: owner files contain linked paths; resolve them before migrating.') }
            }
        }
        if ((Test-Path -LiteralPath $old) -and (Test-Path -LiteralPath $new) -and
            (Get-FileHash -LiteralPath $old).Hash -cne (Get-FileHash -LiteralPath $new).Hash) {
            return @{ Blocked = $true; Messages = @('Manual step: old and new owner files differ; reconcile them before migrating. Nothing changed.') }
        }
    }
    foreach ($name in @('Settings', 'Notes')) {
        $old = Get-LegionOwnerPath -HomeRoot $HomeRoot -Name $name -Legacy
        $new = Get-LegionOwnerPath -HomeRoot $HomeRoot -Name $name
        if (-not (Test-Path -LiteralPath $old)) { continue }
        if (Test-Path -LiteralPath $new) { Remove-Item -LiteralPath $old -Force }
        else { Move-Item -LiteralPath $old -Destination $new }
        $messages += "migrated: owner $name"
        if ($name -eq 'Settings') {
            $text = [IO.File]::ReadAllText($new)
            $text = [regex]::Replace($text, '("\$schema"\s*:\s*")[^"]*(")', '${1}https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/plugins/legion/schemas/personalisation.schema.json${2}')
            Set-LegionTextPreservingEncoding -Path $new -Text $text
        }
    }
    $temp = Get-LegionHomePath -HomeRoot $HomeRoot -Path 'temp'
    $oldUpdate = Split-Path (Get-LegionOwnerPath -HomeRoot $HomeRoot -Name Update -Legacy) -Leaf
    $oldInstallPrefix = [regex]::Escape((Split-Path (Get-LegionOwnerPath -HomeRoot $HomeRoot -Name Install -Legacy) -Leaf))
    if (Test-Path -LiteralPath $temp -PathType Container) {
        foreach ($item in Get-ChildItem -LiteralPath $temp -Force) {
            if ($item.Name -cne $oldUpdate -and $item.Name -cnotmatch ('^' + $oldInstallPrefix + '[a-fA-F0-9]{32}$')) { continue }
            $current = $item.FullName
            $linked = $false
            while ($current) {
                if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { $linked = $true; break }
                $current = Split-Path $current -Parent
            }
            if ($linked -or ($item.PSIsContainer -and @(Get-ChildItem -LiteralPath $item.FullName -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count)) { continue }
            Remove-Item -LiteralPath $item.FullName -Recurse -Force
            $messages += 'removed: old installer temporary files'
        }
    }
    if (-not $messages.Count) { $messages = @('skip: owner file migration (already done)') }
    return @{ Blocked = $false; Messages = $messages }
}

function Get-LegionRepoPath {
    param([string]$Repo, [string]$Path)
    return Join-Path (Join-Path $Repo '.legion') $Path
}

# The code worktree root: the parent of a Private .legion repository, or $null outside Git.
function Get-LegionCodeRoot {
    param([string]$Path)
    $root = git -C $Path rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    if ((Split-Path $root -Leaf) -eq '.legion') {
        $root = git -C (Split-Path $root -Parent) rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
    }
    return [IO.Path]::GetFullPath($root)
}

function Get-LegionPathComparer {
    if ($IsWindows) { return [StringComparer]::OrdinalIgnoreCase }
    return [StringComparer]::Ordinal
}

function Test-LegionLauncherExecutable {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    if ($IsWindows) { return $true }
    return ([IO.File]::GetUnixFileMode($Path) -band [IO.UnixFileMode]::UserExecute) -ne 0
}

function Test-LegionPathEntry {
    param([string]$Path, [string]$Folder)
    $comparer = Get-LegionPathComparer
    foreach ($entry in $Path.Split([IO.Path]::PathSeparator)) {
        $expanded = if ($IsWindows) { [Environment]::ExpandEnvironmentVariables($entry) } else { $entry }
        $expanded = $expanded.TrimEnd('/', '\')
        if ($entry -and $comparer.Equals($expanded, $Folder.TrimEnd('/', '\'))) { return $true }
    }
    return $false
}

function Test-LegionSameStartTime {
    # Linux and macOS derive a process start time from the clock, so two reads can differ by a few milliseconds.
    param([datetime]$First, [datetime]$Second)
    return [math]::Abs(($First.ToUniversalTime() - $Second.ToUniversalTime()).TotalMilliseconds) -lt 500
}
