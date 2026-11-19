# SharedSkillsRouteWithoutToolKnowledge: tool instructions have one home, shared skills route.
& {
    $repo = Split-Path $PSScriptRoot -Parent
    $skills = Join-Path $repo 'plugins/ps-ai/skills'
    foreach ($name in @('personalisation','overseer','repository','knowledge','legion','update')) {
        $directory = Join-Path $skills "ps-ai-$name"
        $main = Get-Content (Join-Path $directory 'SKILL.md') -Raw
        $references = (Get-ChildItem (Join-Path $directory 'references') -File -Recurse | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"
        Assert-True ($references.Contains('skills/ps-ai-<agent.tool>/SKILL.md')) "$name reference routes dynamically"
        Assert-True (($main + $references) -match '(?i)stop[^\r\n]*(missing|does not exist)|missing[^\r\n]*stop') "$name stops for a missing tool skill"
        foreach ($file in Get-ChildItem $directory -File -Recurse) {
            $content = Get-Content $file.FullName -Raw
            Assert-True ($content -notmatch '(?i)claude|codex|copilot') "$($file.Name) contains no dedicated tool knowledge"
            Assert-True ($content -notmatch '--channels|--verbose|--resume|--model|--allow-all-tools|--deny-tool|--dangerously|config\.toml|rate_limit_event') "$($file.Name) has no anonymous CLI flags or formats"
        }
    }
    foreach ($file in Get-ChildItem $skills -Filter '*.md' -File -Recurse) {
        $content = Get-Content $file.FullName -Raw
        foreach ($match in [regex]::Matches($content, '\[[^\]]+\]\(([^)]+)\)')) {
            $target = $match.Groups[1].Value -split '#',2 | Select-Object -First 1
            if (-not $target -or $target -match '^https?://') { continue }
            Assert-True (Test-Path -LiteralPath (Join-Path $file.DirectoryName $target)) "Local link $target from $($file.Name) resolves"
        }
    }
    foreach ($tool in @('claude','codex','copilot')) {
        $directory = Join-Path $skills "ps-ai-$tool"
        $main = Get-Content (Join-Path $directory 'SKILL.md') -Raw
        foreach ($ref in @('accounts','install','run','limits','launcher')) {
            Assert-True ($main.Contains("references/$ref.md")) "$tool links $ref"
        }
        Assert-True ($main -match '(?m)^description: Use when') "$tool keeps trigger-focused description"
        Assert-True ($main -notmatch '--dangerously|exec resume|rate_limit_event|\.ps1|PS_AI_ROLE|PS_AI_TASK|CODEX_HOME|COPILOT_HOME') "$tool main file keeps details in references"
        $accounts = Get-Content (Join-Path $directory 'references/accounts.md') -Raw
        $run = Get-Content (Join-Path $directory 'references/run.md') -Raw
        $limits = Get-Content (Join-Path $directory 'references/limits.md') -Raw
        Assert-True ($accounts -match 'owner.*log in|owner.*login') "$tool keeps owner login approval"
        Assert-True ($run -match 'same account and folder|same account.*repository folder') "$tool keeps same-account resume"
        Assert-True ($limits -match 'ping') "$tool keeps account limit ping"
        $launcher = Get-Content (Join-Path $directory 'references/launcher.md') -Raw
        Assert-True ($launcher.Contains("-Tool $tool") -and $launcher.Contains('-Account')) "$tool launcher selects an account"
        Assert-True ($launcher.Contains('launch.args') -and $launcher.Contains('launch')) "$tool owns launch examples"
    }
    foreach ($tool in @('claude','codex')) {
        $directory = Join-Path $skills "ps-ai-$tool"
        $main = Get-Content (Join-Path $directory 'SKILL.md') -Raw
        Assert-True ($main.Contains('references/plugins.md')) "$tool links plugin reference"
        $plugins = Get-Content (Join-Path $directory 'references/plugins.md') -Raw
        Assert-True ($plugins.Contains("$tool plugin marketplace add nvk/llm-wiki")) "$tool owns optional wiki commands"
        $install = Get-Content (Join-Path $directory 'references/install.md') -Raw
        Assert-True ($install -match 'Windows[^\r\n]*no Node|Windows[^\r\n]*Node[^\r\n]*not required') "$tool documents native Windows without Node"
        Assert-True ($install.Contains('Hash = $null') -and $install.Contains('SHA-256')) "$tool retains vendor integrity boundary"
    }
    $copilot = Join-Path $skills 'ps-ai-copilot/references'
    Assert-True (-not (Test-Path (Join-Path $copilot 'plugins.md'))) 'No invented Copilot wiki recipe'
    $run = Get-Content (Join-Path $copilot 'run.md') -Raw
    Assert-True ($run.Contains('--deny-tool=write --deny-tool=shell')) 'Copilot retains exact reviewer denials'
    Assert-True ($run -match 'cannot enforce.*stop') 'Copilot stops when denials unavailable'
    $install = Get-Content (Join-Path $copilot 'install.md') -Raw
    Assert-True ($install -match 'Node.*already available' -and $install.Contains('npm install -g @github/copilot')) 'Copilot documents conditional npm precedence'
    Assert-True ($install.Contains('copilot-win32-x64.zip') -and $install.Contains('copilot-x64.msi')) 'Copilot retains native download names'
    $accounts = Get-Content (Join-Path $copilot 'accounts.md') -Raw
    Assert-True ($accounts.Contains('fixed bearer token') -and $accounts.Contains('does not refresh') -and $accounts.Contains('<id> --resume')) 'Copilot retains expiry/restart limits'
    $codex = Get-Content (Join-Path $skills 'ps-ai-codex/references/accounts.md') -Raw
    Assert-True ($codex.Contains('not yet proven against Foundry')) 'Codex retains verification limit'
    $sharedReviews = Get-Content (Join-Path $skills 'ps-ai-overseer/references/reviews.md') -Raw
    Assert-True ($sharedReviews -match 'tool-enforced read-only' -and $sharedReviews -match 'stop') 'Shared reviews stop without enforced read-only access'
    $knowledge = Get-Content (Join-Path $skills 'ps-ai-knowledge/references/llm-wiki-setup.md') -Raw
    Assert-True ($knowledge.Contains('never run') -and $knowledge.Contains('references/plugins.md') -and $knowledge.Contains('only when')) 'Knowledge offers optional tool-owned hints only on request or for owner action'
    $legion = Get-Content (Join-Path $skills 'ps-ai-legion/SKILL.md') -Raw
    $legionTask = Get-Content (Join-Path $skills 'ps-ai-legion/references/task.md') -Raw
    Assert-True ($legion.Contains('A summoned unit cannot summon') -and $legionTask.Contains('{REPORT_FILE}')) 'Legion keeps no-summoning and referenced report contract'
    $readme = Get-Content (Join-Path $repo 'README.md') -Raw
    Assert-True ($readme.Contains('-SourceRef <release-tag>')) 'Pinned script pins matching catalog ref'
    Assert-True ($readme -notmatch '(?i)(claude|codex|copilot) plugin|Copilot supports|any Claude') 'README links instead of duplicating commands/capabilities'
    foreach ($tool in @('claude','codex','copilot')) {
        foreach ($ref in @('install','accounts')) { Assert-True ($readme.Contains("ps-ai-$tool/references/$ref.md")) "README links $tool $ref" }
    }
}
