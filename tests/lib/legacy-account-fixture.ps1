# Fixture only: these pre-migration helpers seed and inspect legacy account state in setup tests.
# They are copied from the previous implementation, never called by shipped scripts.
. (Join-Path $PSScriptRoot '../../plugins/legion/bin/lib/accounts.ps1')
. (Join-Path $PSScriptRoot '../../plugins/legion/bin/lib/commands.ps1')
. (Join-Path $PSScriptRoot 'legacy-app-fixture.ps1')
. (Join-Path $PSScriptRoot '../../plugins/legion/bin/lib/footprints.ps1')

function Get-LegionLauncherHeader {
    param([string]$Id, [switch]$Windows)
    return Get-LegionHeader -Name "account $Id" -Windows:$Windows
}

# task 5 removes this

function Get-LegionLauncherText {
    param([string]$Id, [string[]]$Body, [switch]$Windows)
    $header = Get-LegionLauncherHeader -Id $Id -Windows:$Windows
    $lines = if ($Windows) { @($header) + $Body } else { @('#!/bin/sh', $header) + $Body }
    $newline = if ($Windows) { "`r`n" } else { "`n" }
    return ($lines -join $newline) + $newline
}

# True when any launcher file of the account is missing or cannot run (setup and refresh repair these).
# milestone 4 removes this

function Test-LegionOwnedWrapper {
    param([string]$Path, [string]$Id)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force
    $expectedName = if ($item.Extension -ceq '.cmd') { "$Id.cmd" } else { $Id }
    if ($item.Name -cne $expectedName -or (Split-Path $item.DirectoryName -Leaf) -cne 'bin' -or (Split-Path (Split-Path $item.DirectoryName) -Leaf) -cne '.legion') { return $false }
    if (-not (Test-LegionOwnerPathSafe $item.FullName -StopRoot (Split-Path (Split-Path $item.DirectoryName)))) { return $false }
    return Test-LegionHeader -Path $item.FullName -Name "account $Id"
}

# task 5 removes this

function Assert-LegionWrapperPath {
    param([string]$Path, [string]$Id)
    # A wrapper lives at <home>/.legion/bin/<name>; the link walk stops at <home>.
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-LegionOwnerPathSafe $full -StopRoot (Split-Path (Split-Path (Split-Path $full))))) { throw "linked wrapper path '$Path'" }
    if ((Test-Path -LiteralPath $Path) -and -not (Test-LegionOwnedWrapper $Path $Id)) { throw "wrapper collision '$Path'" }
}

# task 5 removes this

function Write-LegionPersonalisation {
    param($Data, [string]$Path)
    if ($Data.PSObject.Properties['$schema']) {
        $Data.'$schema' = 'https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/plugins/legion/schemas/personalisation.schema.json'
    }
    $json = $Data | ConvertTo-Json -Depth 100
    New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $json + "`n", [System.Text.UTF8Encoding]::new($false))
}

# task 5 removes this

# task 5 removes this

function Get-LegionShellWrapperTarget {
    param([string]$Path, [string]$Tool, [string]$ConfigDir)
    $prefix = (Get-LegionTool $Tool).configEnv + '=' + (ConvertTo-LegionShellLiteral $ConfigDir) + ' exec '
    $line = [IO.File]::ReadAllLines($Path) | Select-Object -Last 1
    if (-not $line.StartsWith($prefix) -or -not $line.EndsWith(' "$@"')) { return $null }
    $literal = $line.Substring($prefix.Length, $line.Length - $prefix.Length - ' "$@"'.Length)
    if ($literal.StartsWith('pwsh -NoProfile -File ')) { $literal = $literal.Substring('pwsh -NoProfile -File '.Length) }
    if (-not $literal.StartsWith("'") -or -not $literal.EndsWith("'")) { return $null }
    $escape = "'" + '"' + "'" + '"' + "'"
    $target = $literal.Substring(1, $literal.Length - 2).Replace($escape, "'")
    if ((ConvertTo-LegionShellLiteral $target) -ceq $literal) { return $target }
    return $null
}

# task 5 removes this

function Get-LegionWrapperTarget {
    param([string]$Id, [string]$Tool, [string]$HomeRoot, [string]$ConfigDir)
    $bin = Get-LegionHomePath -HomeRoot $HomeRoot -Path 'bin'
    $candidates = [Collections.Generic.List[string]]::new()
    $sh = Join-Path $bin $Id
    if (Test-LegionOwnedWrapper $sh $Id) {
        $target = Get-LegionShellWrapperTarget -Path $sh -Tool $Tool -ConfigDir $ConfigDir
        if ($target) { $candidates.Add($target) }
    }
    $cmd = Join-Path $bin "$Id.cmd"
    if ($IsWindows -and (Test-LegionOwnedWrapper $cmd $Id)) {
        # Interim parser: Python's marked batch launcher stores the target in an assignment; task 5 replaces refresh.
        foreach ($line in [IO.File]::ReadAllLines($cmd)) {
            if ($line -cmatch '^@set "LEGION_ACCOUNT_TARGET=(.*)"$') { $candidates.Add($Matches[1].Replace('%%', '%')); break }
            if ($line -cmatch '^@(?:pwsh -NoProfile -File |call )?"([^"]+)" %\*$') { $candidates.Add($Matches[1].Replace('%%', '%')); break }
        }
    }
    if (-not $candidates.Count) {
        # With no launcher left, recover from the same stock command used for a new account.
        if ((Test-Path -LiteralPath $sh) -or (Test-Path -LiteralPath $cmd)) { return $null }
        $stock = Get-Command (Get-LegionTool $Tool).command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $stock) { return $null }
        $candidates.Add($stock.Source)
    }
    $target = $candidates[0]
    foreach ($candidate in $candidates) { if (-not (Get-LegionPathComparer).Equals($target, $candidate)) { return $null } }
    # Check the executable and reject edited or conflicting surviving wrappers before recovery.
    try { New-LegionWrappers -Id $Id -Tool $Tool -HomeRoot $HomeRoot -ConfigDir $ConfigDir -RealCommand $target -CheckOnly }
    catch { return $null }
    return $target
}

# milestone 4 removes this

function New-LegionWrappers {
    param([string]$Id, [string]$Tool, [string]$HomeRoot, [string]$RealCommand, [string]$ConfigDir, [switch]$CheckOnly, [Collections.Generic.List[string]]$Changes)
    Assert-LegionId $Id
    if (-not (Test-Path -LiteralPath $RealCommand -PathType Leaf)) { throw "target needed: $Id; ask the owner for an existing executable" }
    $bin = Get-LegionHomePath -HomeRoot $HomeRoot -Path 'bin'
    $folder = if ($ConfigDir) { $ConfigDir } else { Get-LegionNewAccountDir -Id $Id -HomeRoot $HomeRoot }
    $folder = [IO.Path]::GetFullPath((Resolve-LegionHomePath -Path $folder -HomeRoot $HomeRoot))
    foreach ($suffix in @('', '.cmd')) { Assert-LegionWrapperPath (Join-Path $bin "$Id$suffix") $Id }
    $canonical = Get-LegionWrapperCommand $Id $HomeRoot
    if ([IO.Path]::IsPathRooted($RealCommand) -and [IO.Path]::GetFullPath($RealCommand) -eq $canonical) { throw 'wrapper target would recurse' }
    $envName = (Get-LegionTool -Tool $Tool).configEnv
    $target = ConvertTo-LegionShellLiteral $RealCommand
    if ([IO.Path]::GetExtension($RealCommand) -ieq '.ps1') { $target = 'pwsh -NoProfile -File ' + $target }
    $sh = Get-LegionLauncherText -Id $Id -Body ('{0}={1} exec {2} "$@"' -f $envName, (ConvertTo-LegionShellLiteral $folder), $target)
    $shFile = Join-Path $bin $Id
    if ($IsWindows) {
        $target = $RealCommand.Replace('%', '%%')
        $invoke = if ([IO.Path]::GetExtension($RealCommand) -ieq '.ps1') {
            '@pwsh -NoProfile -File "' + $target + '" %*'
        } elseif ([IO.Path]::GetExtension($RealCommand) -in @('.cmd', '.bat')) {
            '@call "' + $target + '" %*'
        } else { '@"' + $target + '" %*' }
        $cmd = Get-LegionLauncherText -Id $Id -Windows -Body '@setlocal', "@set `"$envName=$($folder.Replace('%', '%%'))`"", $invoke, '@exit /b %errorlevel%'
        $cmdFile = Join-Path $bin "$Id.cmd"
    }
    if ($CheckOnly) { return }
    New-Item -ItemType Directory -Path $bin, $folder -Force | Out-Null
    if (-not (Test-LegionLauncherExecutable -Path $shFile)) { Write-LegionGeneratedFile -Path $shFile -Content $sh -Executable -Changes $Changes }
    if ($IsWindows -and -not (Test-LegionLauncherExecutable -Path $cmdFile)) { Write-LegionGeneratedFile -Path $cmdFile -Content $cmd -Changes $Changes }
}

# task 5 removes this
