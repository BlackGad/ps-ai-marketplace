param(
    [string]$Repo = (Get-Location).Path,
    [ValidateSet('Private', 'Shared')][string]$Mode = 'Private'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/paths.ps1')

function Add-PsAiIgnoreLines {
    param([string]$Path, [string[]]$Lines)
    $content = if (Test-Path -LiteralPath $Path) { [IO.File]::ReadAllText($Path) } else { '' }
    $missing = @($Lines | Where-Object { $_ -cnotin ($content -split '\r?\n') })
    if (-not $missing.Count) { return $false }
    if ($content -and -not $content.EndsWith("`n")) { $content += "`n" }
    New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($Path, $content + ($missing -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
    return $true
}

$repoRoot = git -C $Repo rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) { throw 'Repository setup needs a Git working tree' }
$legion = Get-PsAiRepoPath -Repo $repoRoot -Path ''
$innerGit = Join-Path $legion '.git'

if ($Mode -eq 'Shared') {
    if (Test-Path -LiteralPath $innerGit -PathType Container) { throw 'This layout already has Private Git history' }
    $changed = Add-PsAiIgnoreLines -Path (Join-Path $repoRoot '.gitignore') -Lines @('.legion/temp/', '.legion/docs/')
} else {
    # Author and validate durable setup files before initializing their history.
    foreach ($folder in @('configuration', 'scripts', 'state')) {
        if (-not (Test-Path -LiteralPath (Join-Path $legion $folder) -PathType Container)) {
            throw "Create .legion/$folder before initializing Private history"
        }
    }
    $exclude = git -C $repoRoot rev-parse --path-format=absolute --git-path info/exclude
    if ($LASTEXITCODE -ne 0) { throw 'Cannot find the repository exclude file' }
    $changed = Add-PsAiIgnoreLines -Path $exclude -Lines @('.legion/')
    if (Add-PsAiIgnoreLines -Path (Join-Path $legion '.gitignore') -Lines @('temp/', 'docs/')) { $changed = $true }
    if (-not (Test-Path -LiteralPath $innerGit -PathType Container)) {
        git init --quiet $legion
        if ($LASTEXITCODE -ne 0) { throw 'Cannot initialize Private history' }
        $changed = $true
    }
    git -C $legion rev-parse --verify --quiet HEAD | Out-Null
    if ($LASTEXITCODE -ne 0) {
        git -C $legion add -- .gitignore configuration scripts state
        if ($LASTEXITCODE -ne 0) { throw 'Cannot stage Private setup files' }
        git -C $legion commit --quiet -m 'Set up orchestration'
        if ($LASTEXITCODE -ne 0) { throw 'Cannot commit Private setup files' }
        $changed = $true
    }
}

if ($changed) { "prepared: $Mode orchestration" }
else { "skip: $Mode orchestration (already done)" }
