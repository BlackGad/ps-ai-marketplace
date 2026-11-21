param(
    [string]$Repo = (Get-Location).Path,
    [ValidateSet('Private', 'Shared')][string]$Mode = 'Private',
    [string]$Gate,
    [string]$RulesFile
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/paths.ps1')
. (Join-Path $PSScriptRoot 'legion-validate.ps1') -NoRun

$references = Join-Path $PSScriptRoot '../skills/legion-repository/references'
$rulesHeading = '## legion orchestration'
$commitMessage = 'Set up legion orchestration'
# Every file and folder setup writes inside .legion, relative to it.
$generatedFiles = @(
    'configuration/project.json', 'configuration/workflow.md', 'scripts/index.md',
    'scripts/check-task.ps1', 'state/handoff.md', 'state/history/.gitkeep'
)
$scaffoldFolders = @('docs/specs', 'docs/plans', 'temp')

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

function Add-LegionIgnoreLines {
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
    if ($Requested) {
        $relative = [IO.Path]::GetRelativePath($RepoRoot, [IO.Path]::Combine($RepoRoot, $Requested))
        if ([IO.Path]::IsPathRooted($relative) -or $relative -eq '..' -or $relative.StartsWith('..' + [IO.Path]::DirectorySeparatorChar)) {
            throw '-RulesFile must be inside the repository'
        }
        return $Requested
    }
    $present = @('AGENTS.md', 'CLAUDE.md') | Where-Object { Test-Path -LiteralPath (Join-Path $RepoRoot $_) }
    if ($present.Count -lt 2) { return [string]($present | Select-Object -First 1) }
    # Two files: the one the other imports holds the rules.
    if ((Read-Text (Join-Path $RepoRoot 'CLAUDE.md')).Contains('@AGENTS.md')) { return 'AGENTS.md' }
    if ((Read-Text (Join-Path $RepoRoot 'AGENTS.md')).Contains('@CLAUDE.md')) { return 'CLAUDE.md' }
    throw 'choose -RulesFile: AGENTS.md, CLAUDE.md'
}

# A link in a write path would send the write outside the repository.
function Assert-NoLinkInPath {
    param([string]$RepoRoot, [string]$Path)
    for ($current = $Path; $current.Length -gt $RepoRoot.Length; $current = Split-Path $current -Parent) {
        if ([IO.FileInfo]::new($current).LinkTarget) {
            throw "$([IO.Path]::GetRelativePath($RepoRoot, $current)) is a link; setup does not write through links"
        }
    }
}

# The two status letters of one path (staged, then unstaged); empty when the path is clean.
# One literal path needs no parsing of file names, so quoted or non-ASCII names are safe.
function Get-GitPathStatus {
    param([string]$GitRoot, [string]$Path)
    # A path in a folder that does not exist yet makes git warn on stderr; only the exit code matters.
    # Untracked files are requested because the owner's Git setting may hide them.
    $entry = git --literal-pathspecs -C $GitRoot status --porcelain -z --untracked-files=all -- $Path 2>$null | Select-Object -First 1
    if ($LASTEXITCODE -ne 0) { throw "Cannot read the Git status of $Path" }
    if (-not $entry) { return '' }
    return $entry.Substring(0, 2)
}

function Test-RulesBlock {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    return (Read-Text $Path) -split '\r?\n' -ccontains $rulesHeading
}

function Assert-NoUncommittedEdits {
    param([string]$GitRoot, [string[]]$Paths)
    foreach ($path in $Paths) {
        # A missing path counts too: a tracked file the owner deleted is an edit.
        if (Get-GitPathStatus -GitRoot $GitRoot -Path $path) {
            $name = [IO.Path]::GetRelativePath($GitRoot, $path)
            throw "$name has uncommitted edits; commit or stash them before setup"
        }
    }
}

# Recreating a tracked setup file the owner deleted or renamed away would hide the pending change.
function Assert-NoDeletedSetupFiles {
    param([string]$GitRoot, [string[]]$Paths)
    foreach ($path in $Paths) {
        if ((Get-GitPathStatus -GitRoot $GitRoot -Path $path) -match '^(D.|.D|R.)') {
            $name = [IO.Path]::GetRelativePath($GitRoot, $path)
            throw "$name was deleted and the deletion is not committed; commit or restore it before setup"
        }
    }
}

function New-SetupFile {
    param([string]$Path, [string]$Text, [string]$Note = '')
    $fullPath = Join-Path $legion $Path
    if (Test-Path -LiteralPath $fullPath) {
        $script:keptPaths += $Path
        return
    }
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
    param([bool]$HasGate, [string]$GateCommand)
    $text = Read-Reference 'scripts-index-template.md'
    $example = ($text -split '\r?\n') | Where-Object { $_.StartsWith('| `check-task.ps1` |') } | Select-Object -First 1
    # Without a gate the example row would advertise a script that does not exist.
    if (-not $HasGate) { return (($text -split '\r?\n') | Where-Object { $_ -ne $example }) -join "`n" }
    # An edited gate script has no command to quote.
    $runs = if ($GateCommand) { 'Runs `' + $GateCommand + '`' } else { 'Runs the gate script' }
    $row = '| `check-task.ps1` | after each task | ' + $runs + ' | none | exit code of the command |'
    return $text.Replace($example, $row)
}

function Get-GateScriptText {
    param([string]$GateCommand)
    # Stop makes a failing cmdlet end the script with a nonzero code; a native command sets $LASTEXITCODE.
    return "# Gate for this repository: one command, run after each task.`n`$ErrorActionPreference = 'Stop'`n$GateCommand`nexit `$LASTEXITCODE`n"
}

# The command inside a gate script written by this tool; empty when there is no such script.
function Get-ExistingGateCommand {
    param([string]$GatePath)
    if (-not (Test-Path -LiteralPath $GatePath)) { return '' }
    $lines = (Read-Text $GatePath) -split '\r?\n'
    if ($lines.Count -ge 4 -and $lines[1] -ceq '$ErrorActionPreference = ''Stop''' -and $lines[3] -ceq 'exit $LASTEXITCODE') { return $lines[2] }
    return ''
}

function New-OrchestrationFiles {
    param([string]$RulesName)
    # The gate shows up in the index and workflow when its script exists, whichever run wrote it.
    $gatePath = Join-Path $legion 'scripts/check-task.ps1'
    if ($Gate -and (Test-Path -LiteralPath $gatePath) -and (Read-Text $gatePath) -cne (Get-GateScriptText $Gate)) {
        'skip: .legion/scripts/check-task.ps1 (exists; -Gate not applied, edit the script to change the gate)'
    } elseif ($Gate) {
        New-SetupFile 'scripts/check-task.ps1' (Get-GateScriptText $Gate) " (gate: $Gate)"
    } elseif (Test-Path -LiteralPath $gatePath) {
        $script:keptPaths += 'scripts/check-task.ps1'
    }
    $hasGate = Test-Path -LiteralPath $gatePath
    $gateCommand = Get-ExistingGateCommand $gatePath
    New-SetupFile 'configuration/project.json' (Read-Reference 'project-template.json')
    New-SetupFile 'configuration/workflow.md' (Get-WorkflowText $RulesName $hasGate)
    New-SetupFile 'scripts/index.md' (Get-IndexText -HasGate $hasGate -GateCommand $gateCommand)
    New-SetupFile 'state/handoff.md' (Read-Reference 'handoff-template.md')
    New-SetupFile 'state/history/.gitkeep' ''
    foreach ($folder in $scaffoldFolders) {
        New-Item -ItemType Directory -Path (Join-Path $legion $folder) -Force | Out-Null
    }
    # Only a partial setup names the kept files; a full repeat prints its one line at the end.
    if ($changedPaths.Count) {
        foreach ($kept in $keptPaths) { "skip: .legion/$kept (already done)" }
    }
}

function Add-RulesBlock {
    param([string]$Path)
    $content = if (Test-Path -LiteralPath $Path) { Read-Text $Path } else { '' }
    if ($content -and -not $content.EndsWith("`n")) { $content += "`n" }
    if ($content) { $content += "`n" }
    Write-Text -Path $Path -Text ($content + (Read-Reference 'rules-file-lines.md').TrimEnd() + "`n")
    "updated $([IO.Path]::GetFileName($Path))"
}

function Assert-ValidProject {
    $path = Join-Path $legion 'configuration/project.json'
    $issues = @(Invoke-LegionValidation -Kind project -Path $path)
    if ($issues.Count) { throw "project.json is not valid: $($issues -join '; ')" }
}

# Setup files to commit: the exact paths in $Paths, never the owner's other files.
# A path is committed when it is
#   - untracked (new, or left by an earlier failed run)
#   - staged (left by an earlier failed commit)
#   - in $WrittenPaths (written by this run)
# A modified tracked file that is none of these is the owner's work and stays out.
# A path with both staged and unstaged changes is refused: the commit would take both.
function Get-SetupCommitPaths {
    param([string]$GitRoot, [string[]]$Paths, [string[]]$WrittenPaths)
    $commitPaths = @()
    foreach ($path in $Paths) {
        $status = Get-GitPathStatus -GitRoot $GitRoot -Path $path
        if (-not $status) { continue }
        $isUntracked = $status -ceq '??'
        $isStaged = -not $isUntracked -and $status[0] -ne ' '
        $isChanged = -not $isUntracked -and $status[1] -ne ' '
        if ($isStaged -and $isChanged) {
            $name = [IO.Path]::GetRelativePath($GitRoot, $path)
            throw "$name has staged and unstaged changes; stage all of it or none before setup"
        }
        if ($isUntracked -or $isStaged -or $WrittenPaths -contains $path) { $commitPaths += $path }
    }
    return $commitPaths
}

function Save-SetupCommit {
    param([string]$GitRoot, [string]$IdentityRepo, [string[]]$Paths)
    git --literal-pathspecs -C $GitRoot add -- $Paths
    if ($LASTEXITCODE -ne 0) { throw 'Cannot stage setup files' }
    $identity = @()
    foreach ($key in @('user.name', 'user.email')) {
        $value = git -C $IdentityRepo config $key
        if ($LASTEXITCODE -eq 0 -and $value) { $identity += @('-c', "$key=$value") }
    }
    # A path-limited commit keeps anything else already staged out of this commit.
    git --literal-pathspecs -C $GitRoot @identity commit --quiet -m $commitMessage -- $Paths
    if ($LASTEXITCODE -ne 0) { throw 'Cannot commit setup files' }
}

$repoRoot = Get-LegionCodeRoot -Path $Repo
if (-not $repoRoot) { throw 'Repository setup needs a Git working tree' }
$legion = Get-LegionRepoPath -Repo $repoRoot -Path ''
$innerGit = Join-Path $legion '.git'
$changedPaths = @()   # setup files written by this run
$keptPaths = @()      # setup files that already existed, relative to .legion
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
$ignorePath = if ($Mode -eq 'Shared') { Join-Path $repoRoot '.gitignore' } else { Join-Path $legion '.gitignore' }
$generatedPaths = @($generatedFiles | ForEach-Object { Join-Path $legion $_ })

# Private setup also writes the outer repository's exclude file, wherever Git keeps it.
$excludePath = ''
if ($Mode -eq 'Private') {
    $excludePath = @(git -C $repoRoot rev-parse --git-path info/exclude)[0]
    if ($LASTEXITCODE -ne 0) { throw 'Cannot find the repository exclude file' }
    $excludePath = [IO.Path]::GetFullPath([IO.Path]::Combine($repoRoot, $excludePath))
}

# Check every write destination, and each folder above it, before the first write.
$destinations = @($legion, $ignorePath, $rulesPath) + $generatedPaths + @($scaffoldFolders | ForEach-Object { Join-Path $legion $_ })
foreach ($destination in $destinations | Where-Object { $_ }) {
    Assert-NoLinkInPath -RepoRoot $repoRoot -Path $destination
}
# The exclude file may sit outside the working tree (linked worktree); check only inside the Git folder.
if ($excludePath) {
    $gitFolder = Split-Path (Split-Path $excludePath -Parent) -Parent
    Assert-NoLinkInPath -RepoRoot $gitFolder -Path $excludePath
}

# Refuse before any change when a file this run would edit has uncommitted work.
if ($Mode -eq 'Shared') {
    if (Get-MissingIgnoreLines -Path $ignorePath -Lines @('.legion/temp/', '.legion/docs/')) {
        Assert-NoUncommittedEdits -GitRoot $repoRoot -Paths @($ignorePath)
    }
    if (-not (Test-RulesBlock $rulesPath)) { Assert-NoUncommittedEdits -GitRoot $repoRoot -Paths @($rulesPath) }
    Assert-NoDeletedSetupFiles -GitRoot $repoRoot -Paths $generatedPaths
} elseif (Test-Path -LiteralPath $innerGit) {
    if (Get-MissingIgnoreLines -Path $ignorePath -Lines @('temp/', 'docs/')) {
        Assert-NoUncommittedEdits -GitRoot $legion -Paths @($ignorePath)
    }
    Assert-NoDeletedSetupFiles -GitRoot $legion -Paths $generatedPaths
}

New-OrchestrationFiles -RulesName $rulesName
Assert-ValidProject

if ($Mode -eq 'Shared') {
    if (Add-LegionIgnoreLines -Path $ignorePath -Lines @('.legion/temp/', '.legion/docs/')) { $changedPaths += $ignorePath }
    if (-not (Test-RulesBlock $rulesPath)) {
        Add-RulesBlock $rulesPath
        $changedPaths += $rulesPath
    }
    $setupPaths = @($generatedPaths + $ignorePath + $rulesPath) | Where-Object { $_ }
    $pending = Get-SetupCommitPaths -GitRoot $repoRoot -Paths $setupPaths -WrittenPaths $changedPaths
    if ($pending.Count) {
        Save-SetupCommit -GitRoot $repoRoot -IdentityRepo $repoRoot -Paths $pending
        $prepared = $true
    }
} else {
    if (Add-LegionIgnoreLines -Path $excludePath -Lines @('.legion/')) { $prepared = $true }
    if (Add-LegionIgnoreLines -Path $ignorePath -Lines @('temp/', 'docs/')) { $changedPaths += $ignorePath }
    if (-not (Test-Path -LiteralPath $innerGit)) {
        git init --quiet $legion
        if ($LASTEXITCODE -ne 0) { throw 'Cannot initialize Private history' }
        $prepared = $true
    }
    # The first commit also takes setup files that already existed: they are untracked.
    $pending = Get-SetupCommitPaths -GitRoot $legion -Paths @($generatedPaths + $ignorePath) -WrittenPaths $changedPaths
    if ($pending.Count) {
        Save-SetupCommit -GitRoot $legion -IdentityRepo $repoRoot -Paths $pending
        $prepared = $true
    }
}

if ($prepared) { "prepared: $Mode orchestration" }
else { "skip: $Mode orchestration (already done)" }
