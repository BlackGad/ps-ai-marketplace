param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Words,
    [string]$HomeRoot
)

$ErrorActionPreference = 'Stop'
$script:LegionHomeRoot = $HomeRoot
# The folder that holds the scripts legion calls; tests point it at stand-in scripts.
$script:LegionBin = $PSScriptRoot
# Output lines of the last script legion ran, kept so the apply flow can read the plan's last line.
$script:LegionOutput = @()
# The exit code of the last command. Invoke-Legion sets it instead of returning it,
# because a returned value would capture the output of an interactive CLI.
$script:LegionExit = 0

function Get-LegionHelp {
    return @(
        'legion - legion commands'
        ''
        '  legion [--no-channel]                start the overseer here; it resumes the last conversation'
        '  legion pick [--no-channel]           choose which account leads the overseer'
        '  legion setup [--yes]                 finish setup: settings, commands, legion in every account'
        '  legion add <tool> [<folder>] [--yes] add a claude, codex or copilot account (new or existing folder)'
        '  legion remove --id <id>              remove an account (its folder is kept)'
        '  legion status                        show accounts, commands, channels and this repository'
        '  legion limits [--id <id>]            show each account''s usage windows and reset times (or one account)'
        '  legion lease take|status|release     take, check or release this repository''s overseer lease'
        '  legion update [--yes]                update legion to the newest version of the track it was installed from'
        '  legion update --check [--force]      check for a newer version; --force bypasses the daily cache'
        '  legion uninstall [--purge] [--yes]   remove legion; --purge also deletes settings, notes and legion-made logins'
        '  legion help                          show this list'
        ''
        'setup and add show the plan and ask before changing anything; --yes applies without asking.'
    )
}

# Words starting with a dash are flags; every other word is an argument.
function Split-LegionWords {
    param([string[]]$Words)

    $flags = @()
    $arguments = @()
    foreach ($word in $Words) {
        if ($word.StartsWith('-')) { $flags += $word } else { $arguments += $word }
    }
    return @{ Flags = $flags; Arguments = $arguments }
}

# Each verb accepts only its own flags and a fixed number of arguments.
function Assert-LegionUsage {
    param(
        [string]$Verb,
        $Parts,
        [string[]]$AllowedFlags,
        [int]$MinArguments,
        [int]$MaxArguments
    )

    foreach ($flag in $Parts.Flags) {
        if ($AllowedFlags -notcontains $flag) { throw "legion $Verb does not take $flag" }
    }
    $count = $Parts.Arguments.Count
    if ($count -lt $MinArguments -or $count -gt $MaxArguments) { throw "legion ${Verb}: wrong number of arguments" }
}

# Returns @{ Script; Splat; AsksToApply }, or $null when the owner asked for help.
function Get-LegionCall {
    param([string[]]$Words)

    if ($Words.Count -gt 0 -and $Words[0] -eq 'help') { return $null }
    # A bare legion, or one with only flags, has the empty verb: it launches the overseer.
    $verb = if ($Words.Count -eq 0 -or $Words[0].StartsWith('-')) { '' } else { $Words[0] }
    $parts = Split-LegionWords -Words @($Words | Select-Object -Skip $(if ($verb) { 1 } else { 0 }))
    $arguments = $parts.Arguments
    $yesFlags = @('--yes', '-Yes')
    $hasYes = ($parts.Flags | Where-Object { $yesFlags -contains $_ }).Count -gt 0
    $repo = (Get-Location).Path

    switch ($verb) {
        'setup' {
            Assert-LegionUsage -Verb $verb -Parts $parts -AllowedFlags $yesFlags -MinArguments 0 -MaxArguments 0
            $splat = @{}
            if ($hasYes) { $splat.Yes = $true }
            return @{ Script = 'legion-setup.ps1'; Splat = $splat; AsksToApply = -not $hasYes }
        }
        'add' {
            Assert-LegionUsage -Verb $verb -Parts $parts -AllowedFlags $yesFlags -MinArguments 1 -MaxArguments 2
            # The setup script splits each item on the first colon only, so a folder may contain colons.
            $item = $arguments -join ':'
            $splat = @{ Add = @($item) }
            if ($hasYes) { $splat.Yes = $true }
            return @{ Script = 'legion-setup.ps1'; Splat = $splat; AsksToApply = -not $hasYes }
        }
        { $_ -in @('', 'pick') } {
            $noChannelFlags = @('--no-channel', '-NoChannel')
            Assert-LegionUsage -Verb $verb -Parts $parts -AllowedFlags $noChannelFlags -MinArguments 0 -MaxArguments 0
            $splat = @{ Repo = $repo }
            if ($verb -eq 'pick') { $splat.Pick = $true }
            if ($parts.Flags | Where-Object { $noChannelFlags -contains $_ }) { $splat.NoChannel = $true }
            return @{ Script = 'legion-overseer.ps1'; Splat = $splat; AsksToApply = $false }
        }
        { $_ -in @('update', 'uninstall') } {
            $allowedFlags = $yesFlags
            if ($verb -eq 'uninstall') { $allowedFlags += @('--purge', '-Purge') }
            Assert-LegionUsage -Verb $verb -Parts $parts -AllowedFlags $allowedFlags -MinArguments 0 -MaxArguments 0
            $splat = @{}
            if ($verb -eq 'update') { $splat.Update = $true } else { $splat.Uninstall = $true }
            if ($parts.Flags | Where-Object { $_ -in @('--purge', '-Purge') }) { $splat.Purge = $true }
            if ($hasYes) { $splat.Yes = $true }
            return @{ Installer = $true; Splat = $splat; AsksToApply = $false }
        }
        default { throw "legion: unknown command '$verb'" }
    }
}

# update and uninstall run a private copy of the installer, so uninstalling the plugin
# cannot delete the script that is running. Returns the copy's folder.
function Copy-LegionInstaller {
    . (Join-Path $PSScriptRoot 'lib/paths.ps1')
    $homeRoot = if ($script:LegionHomeRoot) { $script:LegionHomeRoot } else { $HOME }
    $folder = Get-LegionHomePath -Path ('temp/installer-' + [guid]::NewGuid().ToString('N')) -HomeRoot $homeRoot
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $script:LegionBin '../install.ps1'), (Join-Path $script:LegionBin '../tools.json') -Destination $folder
    $libraryFolder = Join-Path $folder 'bin/lib'
    New-Item -ItemType Directory -Path $libraryFolder -Force | Out-Null
    foreach ($name in @('paths.ps1', 'footprints.ps1')) {
        Copy-Item -LiteralPath (Join-Path $script:LegionBin "lib/$name") -Destination $libraryFolder
    }
    return $folder
}

# Runs one script in this process and sets $script:LegionExit to its exit code.
# With -Hold the output is kept in $script:LegionOutput and not printed yet.
# Without it the output is not piped or captured: it streams as the script writes it,
# and an interactive CLI started by the script keeps the console.
function Invoke-LegionScript {
    param($Call, [switch]$Hold)

    # Reset first: a script that ends without `exit` must not report an older failure.
    $global:LASTEXITCODE = 0
    $script:LegionOutput = @()
    $splat = $Call.Splat.Clone()
    if ($script:LegionHomeRoot) { $splat.HomeRoot = $script:LegionHomeRoot }
    $installerFolder = if ($Call.Installer) { Copy-LegionInstaller }
    $scriptPath = if ($Call.Installer) { Join-Path $installerFolder 'install.ps1' } else { Join-Path $script:LegionBin $Call.Script }
    try {
        if ($Hold) {
            $script:LegionOutput = @(& $scriptPath @splat | ForEach-Object { "$_" })
        } else {
            & $scriptPath @splat
        }
        $script:LegionExit = $global:LASTEXITCODE
    } catch {
        Write-Host $_.Exception.Message
        $script:LegionExit = if ($_.Exception.Data.Contains('LegionLaunchExitCode')) { [int]$_.Exception.Data['LegionLaunchExitCode'] } else { 1 }
    } finally {
        if ($installerFolder -and (Test-Path -LiteralPath $installerFolder)) { Remove-Item -LiteralPath $installerFolder -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Test-LegionInteractive {
    return -not [Console]::IsInputRedirected
}

function Read-LegionAnswer {
    return Read-Host 'Apply? [Y/n]'
}

# setup and add: show the plan first, then change things only after a yes.
function Invoke-LegionWithApply {
    param($Call)

    Invoke-LegionScript -Call $Call -Hold
    $exit = $script:LegionExit
    $plan = $script:LegionOutput
    $nothingToDo = $plan.Count -gt 0 -and $plan[-1] -eq 'Nothing to do.'
    if ($exit -ne 0 -or $nothingToDo -or -not (Test-LegionInteractive)) {
        $plan | ForEach-Object { Write-Host $_ }
        return
    }

    # The prompt replaces the plan's own hint to run again with -Yes.
    $plan | Where-Object { $_ -ne 'Run again with -Yes to apply.' } | ForEach-Object { Write-Host $_ }

    $answer = (Read-LegionAnswer).Trim()
    if ($answer -eq '' -or $answer -eq 'y' -or $answer -eq 'yes') {
        $applied = @{ Script = $Call.Script; Splat = $Call.Splat.Clone(); AsksToApply = $false }
        $applied.Splat.Yes = $true
        Invoke-LegionScript -Call $applied
        return
    }
    Write-Host 'Nothing changed.'
    $script:LegionExit = 0
}

# Runs the given words and sets $script:LegionExit.
function Invoke-Legion {
    param([string[]]$Words)

    try {
        $call = Get-LegionCall -Words $Words
    } catch {
        Write-Host $_.Exception.Message
        Get-LegionHelp | ForEach-Object { Write-Host $_ }
        $script:LegionExit = 1
        return
    }
    if ($null -eq $call) {
        Get-LegionHelp | ForEach-Object { Write-Host $_ }
        $script:LegionExit = 0
        return
    }
    if ($call.AsksToApply) { Invoke-LegionWithApply -Call $call }
    else { Invoke-LegionScript -Call $call }
}

# Dot-sourcing (tests) loads the functions only.
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Legion -Words $Words
    exit $script:LegionExit
}
