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

function Test-PsAiOwnerCommandFile {
    param([string]$Path, [string]$Script)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $text = [IO.File]::ReadAllText($Path)
    foreach ($line in $text.Split("`n")) {
        # Only recognize a pwsh call, allowing the Unix exec and Windows @ prefixes.
        $call = $line.Trim()
        if ($call.StartsWith('exec ')) { $call = $call.Substring(5).TrimStart() }
        $words = $call.TrimStart('@').Split([char[]]" `t", [StringSplitOptions]::RemoveEmptyEntries)
        if ($words.Count -eq 0 -or $words[0] -cne 'pwsh') { continue }

        # Require a separate -File argument followed by a target.
        $fileIndex = [array]::IndexOf($words, '-File')
        if ($fileIndex -lt 1 -or $fileIndex -eq $words.Count - 1) { continue }

        # Ignore quoting and separator differences; the target must end in bin/<script>.
        foreach ($word in $words[($fileIndex + 1)..($words.Count - 1)]) {
            $target = $word.Replace('"', '').Replace("'", '').Replace('\', '/')
            if ($target.EndsWith("/bin/$Script", [StringComparison]::Ordinal)) { return $true }
        }
    }
    return $false
}
