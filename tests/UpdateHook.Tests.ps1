$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$sandbox = Join-Path $repo ('.agents/temp/restructure/update-hook-' + [guid]::NewGuid().ToString('N'))
$plugin = Join-Path $sandbox 'plugin'
$fixtureRepo = Join-Path $sandbox 'repo'
New-Item -ItemType Directory -Path (Join-Path $plugin 'hooks'), (Join-Path $plugin 'bin/lib'), (Join-Path $fixtureRepo '.agents/state') -Force | Out-Null
try {
    foreach ($file in @('hooks/detect-mode.ps1','bin/lib/common.ps1','bin/lib/tools.ps1','bin/ps-ai-update.ps1')) {
        Copy-Item (Join-Path $repo "plugins/ps-ai/$file") (Join-Path $plugin $file)
    }
    '{"name":"ps-ai","version":"0.3.0"}' | Set-Content (Join-Path $plugin 'plugin.json')
    # Replace only the download and home boundaries in the child-process copy.
    @'
function Get-PsAiUpdateHome { Join-Path $PSScriptRoot '../../home' }
function Get-PsAiUpdateText {
    param([string]$Url)
    Add-Content (Join-Path $PSScriptRoot '../downloads.txt') 'download'
    $text = Get-Content (Join-Path $PSScriptRoot '../response.txt') -Raw
    if ($text -eq 'fail') { throw 'offline fixture' }
    $text
}
'@ | Add-Content (Join-Path $plugin 'bin/ps-ai-update.ps1')
    '{"name":"ps-ai","version":"0.4.0"}' | Set-Content (Join-Path $plugin 'response.txt') -NoNewline
    $hook = Join-Path $plugin 'hooks/detect-mode.ps1'
    $savedRole = $env:PS_AI_ROLE
    $savedTask = $env:PS_AI_TASK
    try {
        $env:PS_AI_ROLE = ''
        $env:PS_AI_TASK = ''
        Assert-Equal '{}' (& pwsh -NoProfile -File $hook -Repo $fixtureRepo -Format context-json) 'Ad hoc mode has no notice'
        Assert-True (-not (Test-Path (Join-Path $plugin 'downloads.txt'))) 'Ad hoc never checks'
        "## Milestone`nM1`n## Current task`ntask 1`n" | Set-Content (Join-Path $fixtureRepo '.agents/state/handoff.md')
        $env:PS_AI_ROLE = 'legion'
        $env:PS_AI_TASK = 'task.md'
        $null = & pwsh -NoProfile -File $hook -Repo $fixtureRepo
        $env:PS_AI_TASK = ''
        $null = & pwsh -NoProfile -File $hook -Repo $fixtureRepo
        Assert-True (-not (Test-Path (Join-Path $plugin 'downloads.txt'))) 'Legion never checks even without task'
        $env:PS_AI_ROLE = ''
        $notice = 'ps-ai 0.4.0 is available (installed 0.3.0); say "update ps-ai" to update.'
        $text = @(& pwsh -NoProfile -File $hook -Repo $fixtureRepo)
        Assert-Equal 0 $LASTEXITCODE 'Text hook exits zero'
        Assert-Equal 2 $text.Count 'Text hook adds exactly one notice line'
        Assert-Equal $notice $text[1] 'Notice matches owner wording'
        Assert-True ($text[1] -notmatch '(?i)\b(pwsh|irm)\b|\.ps1| -[A-Za-z]') 'Update notice uses plain words without a command'
        $json = & pwsh -NoProfile -File $hook -Repo $fixtureRepo -Format context-json | ConvertFrom-Json
        Assert-Equal ($text -join "`n") $json.additionalContext 'JSON includes same notice'
        Assert-Equal 1 @(Get-Content (Join-Path $plugin 'downloads.txt')).Count 'Hook uses daily cache'
        foreach ($version in @('0.3.0','0.2.0')) {
            Remove-Item (Join-Path $sandbox 'home/.agents/temp/ps-ai-update.json')
            "{`"name`":`"ps-ai`",`"version`":`"$version`"}" | Set-Content (Join-Path $plugin 'response.txt') -NoNewline
            Assert-Equal 1 @(& pwsh -NoProfile -File $hook -Repo $fixtureRepo).Count 'Equal or older release adds no notice'
        }
        Remove-Item (Join-Path $sandbox 'home/.agents/temp/ps-ai-update.json')
        'fail' | Set-Content (Join-Path $plugin 'response.txt') -NoNewline
        $text = @(& pwsh -NoProfile -File $hook -Repo $fixtureRepo)
        Assert-Equal 1 $text.Count 'Failed check adds no output'
        Assert-True ($text[0].Contains('Say continue')) 'Failed check preserves overseer activation guidance'
        Assert-Equal 0 $LASTEXITCODE 'Failed update check exits zero'
        $json = & pwsh -NoProfile -File $hook -Repo $fixtureRepo -Format context-json | ConvertFrom-Json
        Assert-Equal $text[0] $json.additionalContext 'Failed check preserves JSON context'
    } finally {
        $env:PS_AI_ROLE = $savedRole
        $env:PS_AI_TASK = $savedTask
    }
} finally {
    $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp/restructure')) + [IO.Path]::DirectorySeparatorChar
    if (-not ([IO.Path]::GetFullPath($sandbox)).StartsWith($allowed)) { throw 'unsafe update hook cleanup' }
    Remove-Item -LiteralPath $sandbox -Recurse -Force
}
