param(
    [string]$Repo = (Get-Location).Path,
    [ValidateSet('Private', 'Shared')][string]$Mode = 'Private',
    [string]$Gate,
    [string]$RulesFile
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/paths.ps1')
. (Join-Path $PSScriptRoot 'ps-ai-validate.ps1') -NoRun

$references = Join-Path $PSScriptRoot '../skills/ps-ai-repository/references'
$rulesHeading = '## ps-ai orchestration'
$commitMessage = 'Set up ps-ai orchestration'

function Read-Text {
    param([string]$Path)
    return [IO.File]::ReadAllText($Path)
}

function Write-Text {
    param([string]$Path, [string]$Text)
    New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Read-Reference {
    param([string]$Name)
    return Read-Text (Join-Path $references $Name)
}

function Get-MissingIgnoreLines {
    param([string]$Path, [string[]]$Lines)
    $content = if (Test-Path -LiteralPath $Path) { Read-Text $Path } else { '' }
    return @($Lines | Where-Object { $_ -cnotin ($content -split '\r?\n') })
}

function Add-PsAiIgnoreLines {
    param([string]$Path, [string[]]$Lines)
    $missing = Get-MissingIgnoreLines -Path $Path -Lines $Lines
    if (-not $missing.Count) { return $false }
    $content = if (Test-Path -LiteralPath $Path) { Read-Text $Path } else { '' }
    if ($content -and -not $content.EndsWith("`n")) { $content += "`n" }
    Write-Text -Path $Path -Text ($content + ($missing -join "`n") + "`n")
    return $true
}

function Resolve-RulesFileName {
    param([string]$RepoRoot, [string]$Requested)
    if ($Requested) { return $Requested }
    $present = @('AGENTS.md', 'CLAUDE.md') | Where-Object { Test-Path -LiteralPath (Join-Path $RepoRoot $_) }
    if ($present.Count -lt 2) { return [string]($present | Select-Object -First 1) }
    # Two files: the one the other imports holds the rules.
    if ((Read-Text (Join-Path $RepoRoot 'CLAUDE.md')).Contains('@AGENTS.md')) { return 'AGENTS.md' }
    if ((Read-Text (Join-Path $RepoRoot 'AGENTS.md')).Contains('@CLAUDE.md')) { return 'CLAUDE.md' }
    throw 'choose -RulesFile: AGENTS.md, CLAUDE.md'
}

function Test-RulesBlock {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    return (Read-Text $Path) -split '\r?\n' -ccontains $rulesHeading
}

function Assert-NoUncommittedEdits {
    param([string]$GitRoot, [string[]]$Paths)
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        if (git -C $GitRoot status --porcelain -- $path) {
            $name = [IO.Path]::GetRelativePath($GitRoot, $path)
            throw "$name has uncommitted edits; commit or stash them before setup"
        }
    }
}

function New-SetupFile {
    param([string]$Path, [string]$Text, [string]$Note = '')
    $fullPath = Join-Path $legion $Path
    if (Test-Path -LiteralPath $fullPath) { return }
    Write-Text -Path $fullPath -Text $Text
    $script:changedPaths += $fullPath
    "created .legion/$Path$Note"
}

function Get-WorkflowText {
    param([string]$RulesName, [bool]$HasGate)
    $choices = @(
        ('- Rules file: ' + $(if ($RulesName) { '`' + $RulesName + '`' } else { 'none' })),
        '- Specs: `.legion/docs/specs`; plans: `.legion/docs/plans`',
        '- Delivery: `merge-request`'
    )
    if ($HasGate) { $choices += '- Gate: `check-task.ps1`' }
    $text = (Read-Reference 'workflow-template.md').TrimEnd() + "`n`n" + ($choices -join "`n") + "`n"
    # Private has no outer rules file to hold the block, so the workflow carries it.
    if ($Mode -eq 'Private') { $text += "`n" + (Read-Reference 'rules-file-lines.md').TrimEnd() + "`n" }
    return $text
}

function Get-IndexText {
    param([string]$GateCommand)
    $text = Read-Reference 'scripts-index-template.md'
    if (-not $GateCommand) { return $text }
    $example = ($text -split '\r?\n') | Where-Object { $_.StartsWith('| `check-task.ps1` |') } | Select-Object -First 1
    $row = '| `check-task.ps1` | after each task | Runs `' + $GateCommand + '` | none | exit code of the command |'
    return $text.Replace($example, $row)
}

function Get-GateScriptText {
    param([string]$GateCommand)
    return "# Gate for this repository: one command, run after each task.`n$GateCommand`nexit `$LASTEXITCODE`n"
}

function New-OrchestrationFiles {
    param([string]$RulesName)
    # The gate shows up in the index and workflow only when this run wrote the gate script.
    $gatePath = Join-Path $legion 'scripts/check-task.ps1'
    if ($Gate) { New-SetupFile 'scripts/check-task.ps1' (Get-GateScriptText $Gate) " (gate: $Gate)" }
    $wroteGate = $Gate -and ($changedPaths -contains $gatePath)
    New-SetupFile 'configuration/project.json' (Read-Reference 'project-template.json')
    New-SetupFile 'configuration/workflow.md' (Get-WorkflowText $RulesName $wroteGate)
    New-SetupFile 'scripts/index.md' (Get-IndexText $(if ($wroteGate) { $Gate } else { '' }))
    New-SetupFile 'state/handoff.md' (Read-Reference 'handoff-template.md')
    New-SetupFile 'state/history/.gitkeep' ''
    foreach ($folder in @('docs/specs', 'docs/plans', 'temp')) {
        New-Item -ItemType Directory -Path (Join-Path $legion $folder) -Force | Out-Null
    }
}

function Add-RulesBlock {
    param([string]$Path)
    $content = if (Test-Path -LiteralPath $Path) { Read-Text $Path } else { '' }
    if ($content -and -not $content.EndsWith("`n")) { $content += "`n" }
    if ($content) { $content += "`n" }
    Write-Text -Path $Path -Text ($content + (Read-Reference 'rules-file-lines.md').TrimEnd() + "`n")
    $script:changedPaths += $Path
    "updated $([IO.Path]::GetFileName($Path))"
}

function Assert-ValidProject {
    $path = Join-Path $legion 'configuration/project.json'
    $issues = @(Invoke-PsAiValidation -Kind project -Path $path)
    if ($issues.Count) { throw "project.json is not valid: $($issues -join '; ')" }
}

function Save-SetupCommit {
    param([string]$GitRoot, [string]$IdentityRepo, [string[]]$Paths)
    git -C $GitRoot add -- $Paths
    if ($LASTEXITCODE -ne 0) { throw 'Cannot stage setup files' }
    $identity = @()
    foreach ($key in @('user.name', 'user.email')) {
        $value = git -C $IdentityRepo config $key
        if ($LASTEXITCODE -eq 0 -and $value) { $identity += @('-c', "$key=$value") }
    }
    # A path-limited commit keeps anything else already staged out of this commit.
    git -C $GitRoot @identity commit --quiet -m $commitMessage -- $Paths
    if ($LASTEXITCODE -ne 0) { throw 'Cannot commit setup files' }
}

$repoRoot = git -C $Repo rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) { throw 'Repository setup needs a Git working tree' }
if ((Split-Path $repoRoot -Leaf) -eq '.legion') {
    $repoRoot = git -C (Split-Path $repoRoot -Parent) rev-parse --show-toplevel
    if ($LASTEXITCODE -ne 0) { throw 'Repository setup needs a parent code repository' }
}
$legion = Get-PsAiRepoPath -Repo $repoRoot -Path ''
$innerGit = Join-Path $legion '.git'
$changedPaths = @()
$prepared = $false

if ($Mode -eq 'Shared') {
    if (Test-Path -LiteralPath $innerGit) { throw 'This layout already has Private Git history' }
} else {
    $tracked = @(git -C $repoRoot ls-files -- .legion)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot check tracked orchestration files' }
    if ($tracked.Count) { throw 'The code repo already shares .legion (Shared)' }
}

$rulesName = Resolve-RulesFileName -RepoRoot $repoRoot -Requested $RulesFile
if ($Mode -eq 'Shared' -and -not $rulesName) { throw 'Shared needs a rules file: choose -RulesFile <file>' }
$rulesPath = if ($rulesName) { Join-Path $repoRoot $rulesName } else { '' }

# Refuse before any change when a file this run would edit has uncommitted work.
if ($Mode -eq 'Shared') {
    $outerIgnore = Join-Path $repoRoot '.gitignore'
    if (Get-MissingIgnoreLines -Path $outerIgnore -Lines @('.legion/temp/', '.legion/docs/')) {
        Assert-NoUncommittedEdits -GitRoot $repoRoot -Paths @($outerIgnore)
    }
    if (-not (Test-RulesBlock $rulesPath)) { Assert-NoUncommittedEdits -GitRoot $repoRoot -Paths @($rulesPath) }
} elseif (Test-Path -LiteralPath $innerGit) {
    $innerIgnore = Join-Path $legion '.gitignore'
    if (Get-MissingIgnoreLines -Path $innerIgnore -Lines @('temp/', 'docs/')) {
        Assert-NoUncommittedEdits -GitRoot $legion -Paths @($innerIgnore)
    }
}

New-OrchestrationFiles -RulesName $rulesName
Assert-ValidProject

if ($Mode -eq 'Shared') {
    if (Add-PsAiIgnoreLines -Path $outerIgnore -Lines @('.legion/temp/', '.legion/docs/')) { $changedPaths += $outerIgnore }
    if (-not (Test-RulesBlock $rulesPath)) { Add-RulesBlock $rulesPath }
    if ($changedPaths.Count) {
        Save-SetupCommit -GitRoot $repoRoot -IdentityRepo $repoRoot -Paths $changedPaths
        $prepared = $true
    }
} else {
    $exclude = @(git -C $repoRoot rev-parse --git-path info/exclude)[0]
    if ($LASTEXITCODE -ne 0) { throw 'Cannot find the repository exclude file' }
    $exclude = [IO.Path]::GetFullPath([IO.Path]::Combine($repoRoot, $exclude))
    if (Add-PsAiIgnoreLines -Path $exclude -Lines @('.legion/')) { $prepared = $true }
    if (Add-PsAiIgnoreLines -Path (Join-Path $legion '.gitignore') -Lines @('temp/', 'docs/')) {
        $changedPaths += Join-Path $legion '.gitignore'
    }
    if (-not (Test-Path -LiteralPath $innerGit)) {
        git init --quiet $legion
        if ($LASTEXITCODE -ne 0) { throw 'Cannot initialize Private history' }
        $prepared = $true
    }
    git -C $legion rev-parse --verify --quiet HEAD | Out-Null
    if ($LASTEXITCODE -ne 0) {
        # The first commit takes every durable setup file, including ones that already existed.
        $changedPaths = @('.gitignore', 'configuration', 'scripts', 'state')
    }
    if ($changedPaths.Count) {
        Save-SetupCommit -GitRoot $legion -IdentityRepo $repoRoot -Paths $changedPaths
        $prepared = $true
    }
}

if ($prepared) { "prepared: $Mode orchestration" }
else { "skip: $Mode orchestration (already done)" }
