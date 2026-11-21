$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path $root ('.agents/temp/owner-migration-' + [guid]::NewGuid().ToString('N'))
$fixtureHome = Join-Path $scratch 'home'
$outside = Join-Path $scratch 'fake-real'
$saved = @{}
$catalog = Get-Content (Join-Path $root 'plugins/legion/tools.json') -Raw | ConvertFrom-Json
$variables = @('HOME', 'USERPROFILE', 'PATH') + @($catalog.tools.configEnv)
foreach ($name in $variables) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
New-Item -ItemType Directory -Path $fixtureHome, $outside -Force | Out-Null
'keep outside the selected home' | Set-Content (Join-Path $outside 'keep.txt')
$outsideHash = (Get-FileHash (Join-Path $outside 'keep.txt')).Hash
$env:HOME = $fixtureHome
$env:USERPROFILE = $fixtureHome
foreach ($entry in $catalog.tools) {
    [Environment]::SetEnvironmentVariable($entry.configEnv, (Join-Path $fixtureHome "config-$($entry.id)"), 'Process')
}

function Seed-OldOwner {
    param([string]$Folder, [string]$Newline = "`n", [switch]$Bom)
    $config = Join-Path $Folder '.legion/configuration'
    New-Item -ItemType Directory -Path $config -Force | Out-Null
    $json = '{' + $Newline + '  "$schema" : "https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/plugins/ps-ai/schemas/personalisation.schema.json",' + $Newline + '  "schemaVersion": 1, "agents": [], "channels": []' + $Newline + '}' + $Newline
    [IO.File]::WriteAllText((Join-Path $config 'ps-ai-personalisation.json'), $json, [Text.UTF8Encoding]::new([bool]$Bom))
    [IO.File]::WriteAllText((Join-Path $config 'ps-ai-notes.md'), "Owner's notes: café.$Newline", [Text.UTF8Encoding]::new([bool]$Bom))
    return $config
}

try {
    . (Join-Path $root 'plugins/legion/bin/lib/paths.ps1')
    # Exercise the actual setup and refresh entry points with no CLI/account work.
    foreach ($entryPoint in @('setup', 'refresh', 'install')) {
        foreach ($newline in @("`n", "`r`n")) {
            foreach ($bom in @($false, $true)) {
                $selectedHome = Join-Path $fixtureHome ([guid]::NewGuid().ToString('N'))
                $config = Seed-OldOwner $selectedHome $newline -Bom:$bom
                $old = Join-Path $config 'ps-ai-personalisation.json'
                $expected = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($old)).Replace('/plugins/ps-ai/schemas/', '/plugins/legion/schemas/')
                $notes = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $config 'ps-ai-notes.md')))
                $temp = Join-Path $selectedHome '.legion/temp'
                New-Item -ItemType Directory -Path $temp -Force | Out-Null
                'old check' | Set-Content (Join-Path $temp 'ps-ai-update.json')
                $oldInstall = Join-Path $temp ('ps-ai-install-' + [guid]::NewGuid().ToString('N'))
                New-Item -ItemType Directory -Path $oldInstall | Out-Null
                'leftover' | Set-Content (Join-Path $oldInstall 'release.json')
                function Invoke-FixtureMigration {
                    if ($entryPoint -eq 'setup') {
                        & {
                            . (Join-Path $root 'plugins/legion/bin/legion-setup.ps1') -NoRun
                            function Get-SetupUserPath { '' }
                            function Set-SetupUserPath { }
                            Invoke-Setup -HomeRoot $selectedHome -Yes
                        }
                    } elseif ($entryPoint -eq 'refresh') {
                        & (Join-Path $root 'plugins/legion/bin/legion-refresh.ps1') -HomeRoot $selectedHome
                    } else {
                        & {
                            . (Join-Path $root 'plugins/legion/install.ps1') -NoRun -HomeRoot $selectedHome
                            function Test-InstallCommandAvailable { $false }
                            function Get-InstallSourceText { throw 'Network forbidden' }
                            Invoke-LegionInstaller -Source $root -Catalog $catalog -Yes
                        }
                    }
                }
                Invoke-FixtureMigration | Out-Null
                $new = Join-Path $config 'personalisation.json'
                Assert-True (Test-Path $new) "$entryPoint moves old settings"
                Assert-Equal $expected ([Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($new))) "$entryPoint preserves settings bytes except schema"
                Assert-Equal $notes ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $config 'notes.md')))) "$entryPoint preserves notes bytes"
                Assert-True (-not (Test-Path $old)) "$entryPoint removes old settings name"
                Assert-True (-not (Test-Path $oldInstall)) "$entryPoint removes old install leftovers"
                Assert-True (-not (Test-Path (Join-Path $temp 'ps-ai-update.json'))) "$entryPoint removes old update cache"
                $stamp = [IO.File]::GetLastWriteTimeUtc($new).Ticks
                $repeat = @(Invoke-FixtureMigration)
                Assert-True ([bool]($repeat -match '^skip:')) "$entryPoint repeat reports skip"
                Assert-Equal $stamp ([IO.File]::GetLastWriteTimeUtc($new).Ticks) "$entryPoint repeat does not rewrite settings"
            }
        }
    }
    $conflictHome = Join-Path $fixtureHome 'conflict'
    $config = Seed-OldOwner $conflictHome
    'different notes' | Set-Content (Join-Path $config 'notes.md')
    $before = @(Get-ChildItem $config -File | Sort-Object Name | Get-FileHash).Hash -join '|'
    $result = Move-LegionOwnerFiles -HomeRoot $conflictHome
    Assert-True $result.Blocked 'Conflict blocks the whole owner-file migration'
    Assert-Equal 1 @($result.Messages -match '^Manual step:').Count 'Conflict reports one manual step'
    Assert-Equal $before (@(Get-ChildItem $config -File | Sort-Object Name | Get-FileHash).Hash -join '|') 'Conflict changes neither settings nor notes'
    foreach ($entryPoint in @('setup', 'refresh', 'install')) {
        $selectedHome = $conflictHome
        $output = @(Invoke-FixtureMigration)
        Assert-Equal 1 @($output -match '^Manual step:').Count "$entryPoint reports one conflict line"
        Assert-Equal $before (@(Get-ChildItem $config -File | Sort-Object Name | Get-FileHash).Hash -join '|') "$entryPoint conflict preserves both pairs"
    }
    # Also check the inverse conflict: the settings collide while notes could move.
    $settingsConflict = Join-Path $fixtureHome 'settings-conflict'
    $config = Seed-OldOwner $settingsConflict
    '{}' | Set-Content (Join-Path $config 'personalisation.json')
    $result = Move-LegionOwnerFiles -HomeRoot $settingsConflict
    Assert-True $result.Blocked 'Differing settings block migration'
    Assert-True (Test-Path (Join-Path $config 'ps-ai-notes.md')) 'Settings conflict leaves old notes in place'
    $identicalHome = Join-Path $fixtureHome 'identical'
    $config = Seed-OldOwner $identicalHome
    Copy-Item (Join-Path $config 'ps-ai-personalisation.json') (Join-Path $config 'personalisation.json')
    Copy-Item (Join-Path $config 'ps-ai-notes.md') (Join-Path $config 'notes.md')
    $null = Move-LegionOwnerFiles -HomeRoot $identicalHome
    Assert-True (-not (Test-Path (Join-Path $config 'ps-ai-personalisation.json'))) 'Identical old settings removed'
    Assert-True (-not (Test-Path (Join-Path $config 'ps-ai-notes.md'))) 'Identical old notes removed'

    $fallbackHome = Join-Path $fixtureHome 'fallback'
    $config = Seed-OldOwner $fallbackHome
    Assert-Equal (Join-Path $config 'ps-ai-personalisation.json') (Get-LegionOwnerPath -HomeRoot $fallbackHome -Name Settings -Existing) 'Early readers find old-only settings'
    Assert-Equal (Join-Path $config 'personalisation.json') (Get-LegionOwnerPath -HomeRoot $fallbackHome -Name Settings) 'Writers use new name'
    '{}' | Set-Content (Join-Path $config 'personalisation.json')
    Assert-Equal (Join-Path $config 'personalisation.json') (Get-LegionOwnerPath -HomeRoot $fallbackHome -Name Settings -Existing) 'New settings take precedence'
    & {
        . (Join-Path $root 'plugins/legion/bin/legion-account.ps1') -NoRun
        $bin = Join-Path $fallbackHome '.legion/bin'
        New-Item -ItemType Directory -Path $bin -Force | Out-Null
        foreach ($product in @('ps-ai', 'legion')) {
            foreach ($suffix in @('', '.cmd')) {
                $header = if ($suffix) { '@rem' } else { '#' }
                "$header Generated by ${product}: account example" | Set-Content (Join-Path $bin "example$suffix")
                Assert-True (Test-LegionOwnedWrapper (Join-Path $bin "example$suffix") example) "Accepts $product launcher header"
            }
        }
    }

    & {
        . (Join-Path $root 'plugins/legion/bin/legion-account.ps1') -NoRun
        $runtimeHome = Join-Path $fixtureHome 'runtime'
        $config = Seed-OldOwner $runtimeHome
        '{"agents":[{"id":"foundry-a","tool":"codex","provider":{"kind":"foundry"}}]}' | Set-Content (Join-Path $config 'ps-ai-personalisation.json')
        New-FoundryWrappers -Id foundry-a -Tool codex -HomeRoot $runtimeHome
        $runtime = Get-LegionOwnerPath -HomeRoot $runtimeHome -Name Runtime
        $legacy = Get-LegionOwnerPath -HomeRoot $runtimeHome -Name Runtime -Legacy
        Move-Item -LiteralPath $runtime -Destination $legacy
        'keep owner file' | Set-Content (Join-Path $legacy 'owner.txt')
        $wrapper = Join-Path $runtimeHome '.legion/bin/foundry-a'
        "#!/bin/sh`n# Generated by ps-ai: account foundry-a`nold launcher" | Set-Content $wrapper
        & (Join-Path $root 'plugins/legion/bin/legion-refresh.ps1') -HomeRoot $runtimeHome | Out-Null
        Assert-True ([IO.File]::ReadAllText($wrapper).Contains('Generated by legion: account foundry-a')) 'Old launcher regenerated with new header'
        Assert-True ([IO.File]::ReadAllText($wrapper).Contains((Join-Path $runtime 'bin/legion-foundry.ps1'))) 'Foundry launcher targets .runtime'
        Assert-True (-not (Test-Path (Join-Path $legacy 'bin/legion-foundry.ps1'))) 'Exact old runtime files removed'
        Assert-Equal 'keep owner file' (Get-Content (Join-Path $legacy 'owner.txt')) 'Unknown old runtime file preserved'
        Remove-Item -LiteralPath (Join-Path $legacy 'owner.txt')
        & (Join-Path $root 'plugins/legion/bin/legion-refresh.ps1') -HomeRoot $runtimeHome | Out-Null
        Assert-True (-not (Test-Path $legacy)) 'Empty old runtime folder removed'
    }

    # Configuration migration changes only syntactic provider names, preserving BOM,
    # comments, prompt strings, spacing, other providers and LF/CRLF bytes.
    $env:PATH = (Join-Path $PSScriptRoot 'fixtures/fake-az') + [IO.Path]::PathSeparator + $env:PATH
    foreach ($newline in @("`n", "`r`n")) {
        $folder = Join-Path $fixtureHome ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        $azPath = (Get-Command az -CommandType Application,ExternalScript | Select-Object -First 1).Source | ConvertTo-Json -Compress
        $text = @'
# ps-ai-foundry is mentioned in this comment.
MODEL = "keep-case-sensitive-owner-key"
model = "gpt-x"
model_provider = 'ps-ai-foundry' # selection
developer_instructions = '''
[model_providers.ps-ai-foundry]
Keep this prompt unchanged.
'''
[model_providers."ps-ai-foundry"] # provider
base_url = "https://example.cognitiveservices.azure.com/openai/v1"
wire_api = "responses"
[model_providers.'ps-ai-foundry'.auth]
command = AZ_PATH
args = ["account", "get-access-token", "--resource", "https://cognitiveservices.azure.com", "--query", "accessToken", "-o", "tsv"] # keep spacing
refresh_interval_ms = 1800000
[model_providers.owner]
name = "unchanged"
'@
        $text = $text.Replace("`r`n", "`n").Replace("`n", $newline).Replace('AZ_PATH', $azPath)
        $expected = $text.Replace("model_provider = 'ps-ai-foundry'", "model_provider = 'legion-foundry'").Replace('[model_providers."ps-ai-foundry"]', '[model_providers."legion-foundry"]').Replace("[model_providers.'ps-ai-foundry'.auth]", "[model_providers.'legion-foundry'.auth]")
        $path = Join-Path $folder 'config.toml'
        [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($true))
        $agent = @{ configDir = $folder; provider = @{ default = 'gpt-x'; endpoint = 'https://example.cognitiveservices.azure.com' } }
        $result = & (Join-Path $root 'plugins/legion/skills/legion-codex/scripts/foundry-config.ps1') -Agent $agent -HomeRoot $fixtureHome
        Assert-True $result.Changed 'Old provider renamed'
        Assert-Equal ([Convert]::ToBase64String([byte[]]([Text.Encoding]::UTF8.GetPreamble() + [Text.Encoding]::UTF8.GetBytes($expected)))) ([Convert]::ToBase64String([IO.File]::ReadAllBytes($path))) 'Provider migration preserves all unrelated bytes'
        $stamp = [IO.File]::GetLastWriteTimeUtc($path).Ticks
        $result = & (Join-Path $root 'plugins/legion/skills/legion-codex/scripts/foundry-config.ps1') -Agent $agent -HomeRoot $fixtureHome
        Assert-True (-not $result.Changed) 'Repeated provider configuration skips writing'
        Assert-Equal $stamp ([IO.File]::GetLastWriteTimeUtc($path).Ticks) 'Repeated provider configuration keeps timestamp'
    }

    $repo = Join-Path $fixtureHome 'repository'
    New-Item -ItemType Directory -Path (Join-Path $repo '.legion/configuration') -Force | Out-Null
    git init --quiet $repo
    $rules = "Owner preface: ps-ai remains here.`r`n## ps-ai orchestration`r`n`r`n- PS_AI_ROLE=legion; PS_AI_TASK marks a task.`r`n`r`n## Other`r`nKeep ps-ai here too.`r`n"
    $project = '{ "$schema": "https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/plugins/ps-ai/schemas/project.schema.json", "schemaVersion": 1 }'
    $rulesFile = Join-Path $repo 'AGENTS.md'
    $projectFile = Join-Path $repo '.legion/configuration/project.json'
    [IO.File]::WriteAllText($rulesFile, $rules, [Text.UTF8Encoding]::new($true))
    [IO.File]::WriteAllText($projectFile, $project)
    $repositoryScript = Join-Path $root 'plugins/legion/bin/legion-repository.ps1'
    & $repositoryScript -Repo $repo -Migrate | Out-Null
    Assert-Equal $rules ([IO.File]::ReadAllText($rulesFile)) 'Repository migration waits for yes'
    Assert-Equal $project ([IO.File]::ReadAllText($projectFile)) 'Project migration waits for yes'
    & $repositoryScript -Repo $repo -Migrate -Yes | Out-Null
    Assert-Equal ($rules.Replace('## ps-ai orchestration', '## legion orchestration').Replace('PS_AI_ROLE=legion', 'LEGION_ROLE=member').Replace('PS_AI_TASK', 'LEGION_TASK')) ([IO.File]::ReadAllText($rulesFile)) 'Only the old orchestration block is migrated'
    Assert-Equal ($project.Replace('/plugins/ps-ai/schemas/', '/plugins/legion/schemas/')) ([IO.File]::ReadAllText($projectFile)) 'Only the project schema value is migrated'
    Assert-True ([bool](@(& $repositoryScript -Repo $repo -Migrate -Yes) -match '^skip:')) 'Repository migration repeat skips'
} finally {
    Assert-Equal $outsideHash (Get-FileHash (Join-Path $outside 'keep.txt')).Hash 'Fake real folder remains unchanged'
    foreach ($name in $variables) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
    $allowed = [IO.Path]::GetFullPath((Join-Path $root '.agents/temp/'))
    if (-not [IO.Path]::GetFullPath($scratch).StartsWith($allowed)) { throw 'Unsafe cleanup' }
    Remove-Item -LiteralPath $scratch -Recurse -Force
}
