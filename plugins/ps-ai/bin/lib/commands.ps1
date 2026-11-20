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
    # Match refresh's quoted -File target, including shell-escaped apostrophes and extra owner flags.
    $target = '["''][^\r\n]*?[/\\]bin[/\\]' + [regex]::Escape($Script) + '["'']'
    $pattern = '(?m)^(?:exec\s+|@)?pwsh\s+[^\r\n]*?-File\s+' + $target
    return [regex]::IsMatch($text, $pattern)
}
