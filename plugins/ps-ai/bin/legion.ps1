$ErrorActionPreference = 'Stop'
# The folder that holds the scripts legion calls; tests point it at stand-in scripts.
$script:LegionBin = $PSScriptRoot
# Output lines of the last script legion ran, kept so the apply flow can read the plan's last line.
$script:LegionOutput = @()
# The exit code of the last command. Invoke-Legion sets it instead of returning it,
# because a returned value would capture the output of an interactive CLI.
$script:LegionExit = 0

function Get-LegionHelp {
    return @(
        'legion - ps-ai commands'
        ''
        '  legion setup [--yes]                 finish setup: settings, commands, ps-ai in every account'
        '  legion add <tool> [<folder>] [--yes] add a claude, codex or copilot account (new or existing folder)'
        '  legion remove <id>                   remove an account (its folder is kept)'
        '  legion status                        show accounts, commands, channels and this repository'
        '  legion repo                          set up ps-ai in this repository'
        '  legion start [<account>]             start the overseer here, with Telegram if bound'
        '  legion start --no-channel            start the overseer without a channel'
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

    if ($Words.Count -eq 0 -or $Words[0] -eq 'help') { return $null }
    $verb = $Words[0]
    $parts = Split-LegionWords -Words @($Words | Select-Object -Skip 1)
    $arguments = $parts.Arguments
    $yesFlags = @('--yes', '-Yes')
    $hasYes = ($parts.Flags | Where-Object { $yesFlags -contains $_ }).Count -gt 0
    $repo = (Get-Location).Path

    switch ($verb) {
        'setup' {
            Assert-LegionUsage -Verb $verb -Parts $parts -AllowedFlags $yesFlags -MinArguments 0 -MaxArguments 0
            $splat = @{}
            if ($hasYes) { $splat.Yes = $true }
            return @{ Script = 'ps-ai-setup.ps1'; Splat = $splat; AsksToApply = -not $hasYes }
        }
        'add' {
            Assert-LegionUsage -Verb $verb -Parts $parts -AllowedFlags $yesFlags -MinArguments 1 -MaxArguments 2
            # The setup script splits each item on the first colon only, so a folder may contain colons.
            $item = $arguments -join ':'
            $splat = @{ Add = @($item) }
            if ($hasYes) { $splat.Yes = $true }
            return @{ Script = 'ps-ai-setup.ps1'; Splat = $splat; AsksToApply = -not $hasYes }
        }
        'remove' {
            Assert-LegionUsage -Verb $verb -Parts $parts -AllowedFlags @() -MinArguments 1 -MaxArguments 1
            $splat = @{ Action = 'remove'; Id = $arguments[0] }
            return @{ Script = 'ps-ai-account.ps1'; Splat = $splat; AsksToApply = $false }
        }
        'status' {
            Assert-LegionUsage -Verb $verb -Parts $parts -AllowedFlags @() -MinArguments 0 -MaxArguments 0
            return @{ Script = 'ps-ai-status.ps1'; Splat = @{ Repo = $repo }; AsksToApply = $false }
        }
        'repo' {
            Assert-LegionUsage -Verb $verb -Parts $parts -AllowedFlags @() -MinArguments 0 -MaxArguments 0
            return @{ Script = 'ps-ai-repository.ps1'; Splat = @{ Repo = $repo }; AsksToApply = $false }
        }
        'start' {
            Assert-LegionUsage -Verb $verb -Parts $parts -AllowedFlags @('--no-channel', '-NoChannel') -MinArguments 0 -MaxArguments 1
            $splat = @{ Repo = $repo }
            if ($arguments.Count -eq 1) { $splat.Account = $arguments[0] }
            if ($parts.Flags.Count -gt 0) { $splat.NoChannel = $true }
            return @{ Script = 'ps-ai-overseer.ps1'; Splat = $splat; AsksToApply = $false }
        }
        default { throw "legion: unknown command '$verb'" }
    }
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
    $splat = $Call.Splat
    $scriptPath = Join-Path $script:LegionBin $Call.Script
    try {
        if ($Hold) {
            $script:LegionOutput = @(& $scriptPath @splat | ForEach-Object { "$_" })
        } else {
            & $scriptPath @splat
        }
        $script:LegionExit = $global:LASTEXITCODE
    } catch {
        Write-Host $_.Exception.Message
        $script:LegionExit = if ($_.Exception.Data.Contains('PsAiLaunchExitCode')) { [int]$_.Exception.Data['PsAiLaunchExitCode'] } else { 1 }
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
    Invoke-Legion -Words $args
    exit $script:LegionExit
}
