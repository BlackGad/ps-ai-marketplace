param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'paths.ps1')

function Get-LegionOwnerCommands {
    return [ordered]@{
        'legion' = 'legion.ps1'
    }
}

# The three commands that `legion setup`, `legion status` and bare `legion` replace.
function Get-LegionRetiredCommands {
    return [ordered]@{
        'ps-ai-setup' = 'ps-ai-setup.ps1'
        'ps-ai-status' = 'ps-ai-status.ps1'
        'ps-ai-overseer' = 'ps-ai-overseer.ps1'
    }
}

# Retired command files in bin; Generated is false when the owner edited the file.
function Get-LegionRetiredCommandFiles {
    param([string]$HomeRoot)

    foreach ($entry in (Get-LegionRetiredCommands).GetEnumerator()) {
        foreach ($suffix in @('', '.cmd')) {
            $path = Get-LegionHomePath -HomeRoot $HomeRoot -Path "bin/$($entry.Key)$suffix"
            if (-not (Test-Path -LiteralPath $path)) { continue }
            # Owner flags (anything but "$@", %* and -HomeRoot <folder>) mean the owner changed the launcher.
            $target = Read-LegionOwnerCommandTarget -Path $path -Script $entry.Value
            $generated = $false
            if ($target) {
                $extra = @($target.Arguments | Where-Object { $_ -notin @('"$@"', '%*', '-HomeRoot') })
                $generated = $extra.Count -le $(if ($target.Arguments -contains '-HomeRoot') { 1 } else { 0 })
            }
            [pscustomobject]@{ Name = $entry.Key + $suffix; Path = $path; Generated = $generated }
        }
    }
}

# Delete generated copies of the retired commands; an edited copy stays and is named as a manual step.
function Remove-LegionRetiredCommands {
    param([string]$HomeRoot)

    $files = @(Get-LegionRetiredCommandFiles -HomeRoot $HomeRoot)
    foreach ($file in $files) {
        if ($file.Generated) {
            Remove-Item -LiteralPath $file.Path -Force
            "removed: old command $($file.Name) (use legion instead)"
        } else { "manual step: delete $($file.Path) yourself; you edited it, so it was kept (use legion instead)" }
    }
    if (-not $files.Count) { 'skip: old commands (already done)' }
}

function Get-LegionShimText {
    param([string]$Script, [switch]$Windows, [string]$HomeRoot)

    # Load the existing quoting helper only when generating a shim, so status stays read-only and lean.
    . (Join-Path $PSScriptRoot '../ps-ai-account.ps1') -NoRun -HomeRoot $HomeRoot
    $homeArgument = Get-LegionShimHomeArgument -HomeRoot $HomeRoot -Windows:$Windows
    if ($Windows) { return '@pwsh -NoProfile -File "' + $Script.Replace('%', '%%') + '"' + $homeArgument + ' %* & (goto) 2>nul & exit /b' + "`r`n" }
    return "#!/bin/sh`n" + 'exec pwsh -NoProfile -File ' + (ConvertTo-LegionShellLiteral $Script) + $homeArgument + ' "$@"' + "`n"
}

function Get-LegionShimHomeArgument {
    param([string]$HomeRoot, [switch]$Windows)
    if (-not $HomeRoot) { return '' }
    $selectedHome = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($HomeRoot))
    $defaultHome = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($HOME))
    if ((Get-LegionPathComparer).Equals($selectedHome, $defaultHome)) { return '' }
    $literal = if ($Windows) { '"' + $selectedHome.Replace('%', '%%') + '"' } else { ConvertTo-LegionShellLiteral $selectedHome }
    return ' -HomeRoot ' + $literal
}

# The whole file is the generated launcher: an optional shebang, then one line
# [exec |@]pwsh <options> -File <script path> <owner flags>. Any other code makes it the owner's file.
# Owner flags are plain words, quoted words, "$@" and %*. install.ps1 keeps its own copy of this rule.
# The .cmd line ends with '& (goto) 2>nul & exit /b': uninstall deletes the .cmd, and (goto) ends the batch so cmd
# never reads the deleted file again; exit /b then returns the script's status (the line is parsed before it runs).

# -Batch: a .cmd file writes % as %%, so decode it before looking for the file.
function Get-LegionOwnerCommandTarget {
    param([string]$Text, [string]$Script, [switch]$Batch)

    $launcher = '\A(?:#![^\r\n]*\r?\n)?(?:[ \t]*\r?\n)*[ \t]*(?:exec[ \t]+|@)?pwsh[ \t]+(?:-\S+[ \t]+)*?-File[ \t]+'
    $scriptWord = '(?<target>(?:''[^''\r\n]*''|"[^"\r\n]*"|[^\s''"]+)+)'
    $match = [regex]::Match($Text, $launcher + $scriptWord)
    if (-not $match.Success) { return $null }
    # Batch double quotes keep dollar signs literal; shell double quotes expand them.
    $argument = '(?<argument>(?:''[^''\r\n]*''|"[^"$`\r\n]*")+|"\$@"|\$@|%\*|[\w.=:/\\-]+)'
    $batchExit = ''
    if ($Batch) { $argument = '(?<argument>"[^"\r\n]*"|%\*|[\w.=:/\\-]+)'; $batchExit = '(?:[ \t]+&[ \t]+\(goto\)[ \t]+2>nul[ \t]+&[ \t]+exit[ \t]+/b)?' }
    $tail = $Text.Substring($match.Length)
    $tailMatch = [regex]::Match($tail, '\A(?:[ \t]+' + $argument + ')*' + $batchExit + '\s*\z')
    if (-not $tailMatch.Success) { return $null }
    $word = $match.Groups['target']
    # Drop the shell quotes; the generated form joins quoted pieces such as 'a'"'"'b'.
    $path = [regex]::Replace($word.Value, '''([^'']*)''|"([^"]*)"', { param($piece) $piece.Groups[1].Value + $piece.Groups[2].Value })
    if ($Batch) { $path = $path.Replace('%%', '%') }
    if (-not $path.Replace('\', '/').EndsWith("/bin/$Script", [StringComparison]::Ordinal)) { return $null }
    return [pscustomobject]@{ Start = $word.Index; Length = $word.Length; Path = $path; Arguments = @($tailMatch.Groups['argument'].Captures.Value) }
}

function Read-LegionOwnerCommandTarget {
    param([string]$Path, [string]$Script)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $batch = [IO.Path]::GetExtension($Path) -ieq '.cmd'
    return Get-LegionOwnerCommandTarget -Text ([IO.File]::ReadAllText($Path)) -Script $Script -Batch:$batch
}

function Test-LegionOwnerCommandFile {
    param([string]$Path, [string]$Script)

    return [bool](Read-LegionOwnerCommandTarget -Path $Path -Script $Script)
}

# missing: no file; blocked: someone else's file; stale: ours, but its script is gone; owned: ours and working.
function Get-LegionOwnerCommandState {
    param([string]$Path, [string]$Script)

    if (-not (Test-Path -LiteralPath $Path)) { return 'missing' }
    $target = Read-LegionOwnerCommandTarget -Path $Path -Script $Script
    if (-not $target) { return 'blocked' }
    if (-not (Test-Path -LiteralPath $target.Path -PathType Leaf)) { return 'stale' }
    return 'owned'
}

# Point an owned command at a new script and keep the owner's own flags.
function Update-LegionOwnerCommandText {
    param([string]$Text, [string]$Script, [string]$Runner, [switch]$Windows, [string]$HomeRoot)

    $target = Get-LegionOwnerCommandTarget -Text $Text -Script $Script -Batch:$Windows
    $literal = if ($Windows) { '"' + $Runner.Replace('%', '%%') + '"' } else { ConvertTo-LegionShellLiteral $Runner }
    if ($target.Arguments -inotcontains '-HomeRoot') {
        $literal += Get-LegionShimHomeArgument -HomeRoot $HomeRoot -Windows:$Windows
    }
    return $Text.Substring(0, $target.Start) + $literal + $Text.Substring($target.Start + $target.Length)
}
