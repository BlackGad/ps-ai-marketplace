param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'paths.ps1')

function Get-PsAiOwnerCommands {
    return [ordered]@{
        'ps-ai-setup' = 'ps-ai-setup.ps1'
        'ps-ai-status' = 'ps-ai-status.ps1'
        'ps-ai-overseer' = 'ps-ai-overseer.ps1'
        'legion' = 'legion.ps1'
    }
}

function Get-PsAiShimText {
    param([string]$Script, [switch]$Windows, [string]$HomeRoot)

    # Load the existing quoting helper only when generating a shim, so status stays read-only and lean.
    . (Join-Path $PSScriptRoot '../ps-ai-account.ps1') -NoRun -HomeRoot $HomeRoot
    $homeArgument = Get-PsAiShimHomeArgument -HomeRoot $HomeRoot -Windows:$Windows
    if ($Windows) { return '@pwsh -NoProfile -File "' + $Script.Replace('%', '%%') + '"' + $homeArgument + ' %* & (goto) 2>nul & exit /b' + "`r`n" }
    return "#!/bin/sh`n" + 'exec pwsh -NoProfile -File ' + (ConvertTo-PsAiShellLiteral $Script) + $homeArgument + ' "$@"' + "`n"
}

function Get-PsAiShimHomeArgument {
    param([string]$HomeRoot, [switch]$Windows)
    if (-not $HomeRoot) { return '' }
    $selectedHome = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($HomeRoot))
    $defaultHome = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($HOME))
    if ((Get-PsAiPathComparer).Equals($selectedHome, $defaultHome)) { return '' }
    $literal = if ($Windows) { '"' + $selectedHome.Replace('%', '%%') + '"' } else { ConvertTo-PsAiShellLiteral $selectedHome }
    return ' -HomeRoot ' + $literal
}

# The whole file is the generated launcher: an optional shebang, then one line
# [exec |@]pwsh <options> -File <script path> <owner flags>. Any other code makes it the owner's file.
# Owner flags are plain words, quoted words, "$@" and %*. install.ps1 keeps its own copy of this rule.
# The .cmd line ends with '& (goto) 2>nul & exit /b': uninstall deletes the .cmd, and (goto) ends the batch so cmd
# never reads the deleted file again; exit /b then returns the script's status (the line is parsed before it runs).

# -Batch: a .cmd file writes % as %%, so decode it before looking for the file.
function Get-PsAiOwnerCommandTarget {
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

function Read-PsAiOwnerCommandTarget {
    param([string]$Path, [string]$Script)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $batch = [IO.Path]::GetExtension($Path) -ieq '.cmd'
    return Get-PsAiOwnerCommandTarget -Text ([IO.File]::ReadAllText($Path)) -Script $Script -Batch:$batch
}

function Test-PsAiOwnerCommandFile {
    param([string]$Path, [string]$Script)

    return [bool](Read-PsAiOwnerCommandTarget -Path $Path -Script $Script)
}

# missing: no file; blocked: someone else's file; stale: ours, but its script is gone; owned: ours and working.
function Get-PsAiOwnerCommandState {
    param([string]$Path, [string]$Script)

    if (-not (Test-Path -LiteralPath $Path)) { return 'missing' }
    $target = Read-PsAiOwnerCommandTarget -Path $Path -Script $Script
    if (-not $target) { return 'blocked' }
    if (-not (Test-Path -LiteralPath $target.Path -PathType Leaf)) { return 'stale' }
    return 'owned'
}

# Point an owned command at a new script and keep the owner's own flags.
function Update-PsAiOwnerCommandText {
    param([string]$Text, [string]$Script, [string]$Runner, [switch]$Windows, [string]$HomeRoot)

    $target = Get-PsAiOwnerCommandTarget -Text $Text -Script $Script -Batch:$Windows
    $literal = if ($Windows) { '"' + $Runner.Replace('%', '%%') + '"' } else { ConvertTo-PsAiShellLiteral $Runner }
    if ($target.Arguments -inotcontains '-HomeRoot') {
        $literal += Get-PsAiShimHomeArgument -HomeRoot $HomeRoot -Windows:$Windows
    }
    return $Text.Substring(0, $target.Start) + $literal + $Text.Substring($target.Start + $target.Length)
}
