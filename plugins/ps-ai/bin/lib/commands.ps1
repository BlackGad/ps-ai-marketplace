param()

$ErrorActionPreference = 'Stop'

function Get-PsAiOwnerCommands {
    return [ordered]@{
        'ps-ai-setup' = 'ps-ai-setup.ps1'
        'ps-ai-status' = 'ps-ai-status.ps1'
        'ps-ai-overseer' = 'ps-ai-overseer.ps1'
        'legion' = 'legion.ps1'
    }
}

function Get-PsAiShimText {
    param([string]$Script, [switch]$Windows)

    if ($Windows) { return '@pwsh -NoProfile -File "' + $Script.Replace('%', '%%') + '" %*' + "`r`n" }
    # Load the existing quoting helper only when generating a shim, so status stays read-only and lean.
    . (Join-Path $PSScriptRoot '../ps-ai-account.ps1') -NoRun
    return "#!/bin/sh`n" + 'exec pwsh -NoProfile -File ' + (ConvertTo-PsAiShellLiteral $Script) + ' "$@"' + "`n"
}

# One launcher line: [exec |@]pwsh <options> -File <script path> <owner flags>. install.ps1 keeps its own copy of this rule.
$script:OwnerLauncherPattern = '(?m)^[ \t]*(?:exec[ \t]+|@)?pwsh[ \t]+(?:-\S+[ \t]+)*?-File[ \t]+(?<target>(?:''[^'']*''|"[^"]*"|[^\s''"]+)+)(?=\s|$)'

function Get-PsAiOwnerCommandTarget {
    param([string]$Text, [string]$Script)

    foreach ($match in [regex]::Matches($Text, $script:OwnerLauncherPattern)) {
        $word = $match.Groups['target']
        # Drop the shell quotes; the generated form joins quoted pieces such as 'a'"'"'b'.
        $path = [regex]::Replace($word.Value, '''([^'']*)''|"([^"]*)"', { param($piece) $piece.Groups[1].Value + $piece.Groups[2].Value })
        if ($path.Replace('\', '/').EndsWith("/bin/$Script", [StringComparison]::Ordinal)) {
            return [pscustomobject]@{ Start = $word.Index; Length = $word.Length; Path = $path }
        }
    }
    return $null
}

function Test-PsAiOwnerCommandFile {
    param([string]$Path, [string]$Script)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    return [bool](Get-PsAiOwnerCommandTarget -Text ([IO.File]::ReadAllText($Path)) -Script $Script)
}

# missing: no file; blocked: someone else's file; stale: ours, but its script is gone; owned: ours and working.
function Get-PsAiOwnerCommandState {
    param([string]$Path, [string]$Script)

    if (-not (Test-Path -LiteralPath $Path)) { return 'missing' }
    if (-not (Test-PsAiOwnerCommandFile -Path $Path -Script $Script)) { return 'blocked' }
    $target = Get-PsAiOwnerCommandTarget -Text ([IO.File]::ReadAllText($Path)) -Script $Script
    if (-not (Test-Path -LiteralPath $target.Path -PathType Leaf)) { return 'stale' }
    return 'owned'
}

# Point an owned command at a new script and keep the owner's own flags.
function Update-PsAiOwnerCommandText {
    param([string]$Text, [string]$Script, [string]$Runner, [switch]$Windows)

    $target = Get-PsAiOwnerCommandTarget -Text $Text -Script $Script
    $literal = if ($Windows) { '"' + $Runner.Replace('%', '%%') + '"' } else { ConvertTo-PsAiShellLiteral $Runner }
    return $Text.Substring(0, $target.Start) + $literal + $Text.Substring($target.Start + $target.Length)
}
