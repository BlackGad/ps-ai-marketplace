$repo = Split-Path $PSScriptRoot -Parent
$skills = Join-Path $repo 'plugins/ps-ai/skills'
$files = @(Get-ChildItem $skills -Filter '*.md' -File -Recurse) + @(Get-Item (Join-Path $repo 'README.md'), (Join-Path $repo 'docs/reference.md'))
foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    foreach ($match in [regex]::Matches($content, '\[[^\]]+\]\(([^)]+)\)')) {
        $target = $match.Groups[1].Value -split '#',2 | Select-Object -First 1
        if (-not $target -or $target -match '^https?://') { continue }
        Assert-True (Test-Path -LiteralPath (Join-Path $file.DirectoryName $target)) "Local link $target from $($file.Name) resolves"
    }
}
foreach ($name in @('personalisation','overseer','repository','knowledge','member','update')) {
    $directory = Join-Path $skills "legion-$name"
    $text = (Get-ChildItem $directory -Filter '*.md' -File -Recurse | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"
    Assert-True ($text -match '(?i)stop[^\r\n]*(missing|does not exist)|missing[^\r\n]*stop') "$name stops for a missing skill"
}
foreach ($tool in @('claude','codex','copilot')) {
    $folder = Join-Path $skills "legion-$tool/references"
    $accounts = Get-Content (Join-Path $folder 'accounts.md') -Raw
    $run = Get-Content (Join-Path $folder 'run.md') -Raw
    $install = Get-Content (Join-Path $folder 'install.md') -Raw
    Assert-True ($accounts -match 'owner.*log in|owner.*login') "$tool keeps owner login approval"
    Assert-True ($run -match 'same account and folder|same account.*repository folder') "$tool keeps same-account resume"
    Assert-True ($install.Contains('-Yes')) "$tool requires install approval"
    if ($tool -ne 'copilot') {
        Assert-True ($install.Contains('SHA-256') -and $install -match '(?i)vendor|checksum|integrity') "$tool keeps vendor integrity"
        Assert-True ($run -match 'Stop before launching a reviewer') "$tool stops without enforced read-only access"
    }
}
$run = Get-Content (Join-Path $skills 'legion-copilot/references/run.md') -Raw
Assert-True ($run.Contains('--deny-tool=write --deny-tool=shell')) 'Copilot keeps exact reviewer denials'
Assert-True ($run -match 'cannot enforce.*stop') 'Copilot stops when denials are unavailable'
$accounts = Get-Content (Join-Path $skills 'legion-copilot/references/accounts.md') -Raw
Assert-True ($accounts.Contains('fixed bearer token') -and $accounts.Contains('does not refresh') -and $accounts.Contains('<id> --resume')) 'Copilot keeps expiry and restart limits'
$codex = Get-Content (Join-Path $skills 'legion-codex/references/accounts.md') -Raw
Assert-True ($codex.Contains('not yet proven against Foundry')) 'Codex keeps verification limit'
$reviews = Get-Content (Join-Path $skills 'legion-overseer/references/reviews.md') -Raw
Assert-True ($reviews -match 'tool-enforced read-only' -and $reviews -match 'stop') 'Reviews stop without enforced read-only access'
$knowledge = Get-Content (Join-Path $skills 'legion-knowledge/references/llm-wiki-setup.md') -Raw
Assert-True ($knowledge.Contains('never run') -and $knowledge.Contains('only when')) 'Knowledge installation remains optional'
$legion = Get-Content (Join-Path $skills 'legion-member/SKILL.md') -Raw
Assert-True ($legion.Contains('A summoned unit cannot summon')) 'Legion cannot summon other agents'
$update = Get-Content (Join-Path $skills 'legion-update/SKILL.md') -Raw
Assert-True ($update -match "owner.s yes" -and $update -match 'run .legion. in the repository') 'Updates require approval and a legion run in the repository'
