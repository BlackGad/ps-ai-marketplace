param(
    [string]$Tool,
    [string]$Account,
    [string[]]$Channel,
    [string[]]$Arguments,
    [string]$Repo = (Get-Location).Path,
    [string]$HomeRoot = $HOME,
    [switch]$NoChannel,
    [switch]$DryRun,
    [switch]$Pick,
    [switch]$NoRun
)

. (Join-Path $PSScriptRoot 'lib/settings.ps1')
. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/channels.ps1')

function Test-OverseerInteractive {
    return -not [Console]::IsInputRedirected
}

function Read-OverseerYes {
    param([string]$Question)
    return (Read-Host $Question) -match '^\s*(y|yes)?\s*$'
}

function Format-OverseerChoices {
    param($Accounts, $Channels, [string]$Last)
    $number = 0
    foreach ($account in $Accounts) {
        $number++
        $line = "$number) $($account.id) ($($account.tool))"
        $bound = @($Channels | Where-Object { $account.id -cin $_.accounts }).id
        if ($bound) { $line += ' channels: ' + ($bound -join ', ') }
        if ($account.id -ceq $Last) { $line += ' (last)' }
        $line
    }
}

# Returns the chosen account id.
function Read-OverseerChoice {
    param($Accounts, $Channels, [string]$Last)
    Format-OverseerChoices -Accounts $Accounts -Channels $Channels -Last $Last | ForEach-Object { Write-Host $_ }
    while ($true) {
        $number = 0
        if ([int]::TryParse((Read-Host 'Which account leads?'), [ref]$number) -and $number -ge 1 -and $number -le @($Accounts).Count) {
            return @($Accounts)[$number - 1].id
        }
    }
}

function Invoke-OverseerRepositorySetup {
    param([string]$Repo)
    & (Join-Path $PSScriptRoot 'legion-repository.ps1') -Repo $Repo
}

function Select-OverseerAccount {
    param($Personalisation, [string]$Account, [string]$Tool, [string[]]$Channel, [string]$Last)
    if (-not $Account) { return Select-OnlyOverseerAccount $Personalisation $Tool $Channel -Last $Last }
    $matches = @($Personalisation.agents | Where-Object id -CEQ $Account)
    if ($matches.Count -ne 1) { throw "unknown account '$Account'" }
    $selected = $matches[0]
    if ($Tool -and $selected.tool -cne $Tool) { throw "account '$Account' is a $($selected.tool) account, not $Tool" }
    return $selected
}

# Without -Account, the choice is automatic only when exactly one account is eligible.
# Several eligible accounts are asked about when someone can answer.
function Select-OnlyOverseerAccount {
    param($Personalisation, [string]$Tool, [string[]]$Channel, [string]$Last)
    $eligible = @($Personalisation.agents)
    if ($Tool) { $eligible = @($eligible | Where-Object tool -CEQ $Tool) }
    foreach ($id in $Channel) {
        $bound = @(@($Personalisation.channels | Where-Object id -CEQ $id).accounts)
        $eligible = @($eligible | Where-Object { $_.id -cin $bound })
    }
    if ($eligible.Count -eq 1) { return $eligible[0] }
    if (-not @($Personalisation.agents).Count) { throw 'No accounts yet. Add one: legion add claude' }
    if ($eligible.Count -eq 0) { throw 'no account fits; run legion setup first' }
    if (Test-OverseerInteractive) {
        $id = Read-OverseerChoice -Accounts $eligible -Channels $Personalisation.channels -Last $Last
        return $eligible | Where-Object id -CEQ $id
    }
    throw ('Choose an account: -Account ' + (@($eligible.id) -join ' | '))
}

# A binding fits when it is bound to the account and its kind can launch the tool.
# The default channel is used only when exactly one binding fits.
function Get-OverseerDefaultChannel {
    param($Personalisation, [string]$AccountId, [string]$Tool)
    $kinds = @(Get-LegionChannels | Where-Object { $Tool -cin $_.launch.PSObject.Properties.Name })
    $fitting = @($Personalisation.channels | Where-Object { $AccountId -cin $_.accounts -and $_.kind -cin $kinds.id })
    if ($fitting.Count -eq 1) { return $fitting[0].id }
    return $null
}

# Launch history is per owner home and repository.
function Get-OverseerLastLaunchFile {
    param([string]$HomeRoot)
    return Get-LegionHomePath -HomeRoot $HomeRoot -Path 'state/overseer-launches.json'
}

function Get-OverseerRepoKey {
    param([string]$Repo)
    $key = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($Repo))
    if ($IsWindows) { $key = $key.ToLowerInvariant() }
    return $key
}

function Get-OverseerLastLaunch {
    param([string]$Repo, [string]$HomeRoot)
    $file = Get-OverseerLastLaunchFile -HomeRoot $HomeRoot
    if (-not (Test-Path -LiteralPath $file)) { return $null }
    $saved = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json -AsHashtable
    return $saved[(Get-OverseerRepoKey $Repo)]
}

function Save-OverseerLastLaunch {
    param([string]$Repo, [string]$HomeRoot, [string]$Account, [string[]]$Channel, [string[]]$Arguments, [string]$Session)
    $file = Get-OverseerLastLaunchFile -HomeRoot $HomeRoot
    $saved = if (Test-Path -LiteralPath $file) { Get-Content -LiteralPath $file -Raw | ConvertFrom-Json -AsHashtable } else { [hashtable]::new([StringComparer]::Ordinal) }
    $launch = [ordered]@{ account = $Account; channels = @($Channel | Where-Object { $_ }); arguments = @($Arguments | Where-Object { $null -ne $_ }); session = $Session }
    $saved[(Get-OverseerRepoKey $Repo)] = $launch
    New-Item -ItemType Directory -Path (Split-Path $file) -Force | Out-Null
    $saved | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $file -Encoding utf8NoBOM
}

function New-OverseerSessionId {
    return [guid]::NewGuid().ToString()
}

# Returns the tool to resume ('claude' or 'codex'), or $null to start fresh.
# Resume needs a saved session for the same account; Claude also needs its conversation file.
function Get-OverseerResume {
    param($Last, $Selected, [string]$HomeRoot)
    if (-not $Last -or -not $Last.session -or $Last.account -cne $Selected.id) { return $null }
    if ($Selected.tool -ceq 'codex') { return 'codex' }
    if ($Selected.tool -cne 'claude') { return $null }
    $configDir = if ($Selected.configDir -match '^~[/\\]') { Join-Path $HomeRoot $Selected.configDir.Substring(2) } else { $Selected.configDir }
    $pattern = Join-Path ([WildcardPattern]::Escape($configDir)) "projects/*/$($Last.session).jsonl"
    if (Test-Path -Path $pattern) { return 'claude' }
    return $null
}

function Get-OverseerLaunch {
    param($Personalisation, [string]$AccountId, [string]$Tool, [string[]]$Channel, [string[]]$Arguments, [string]$HomeRoot = $HOME, [string]$Session, [string]$Resume)
    $selected = Select-OverseerAccount $Personalisation $AccountId $Tool
    $Tool = $selected.tool
    $descriptor = Get-LegionTool $Tool
    $resolved = @()
    $common = $null
    foreach ($id in $Channel) {
        $channelData = @($Personalisation.channels | Where-Object id -CEQ $id)
        if ($channelData.Count -ne 1) { throw "unknown or duplicate channel '$id'" }
        if ($null -eq $common) { $common = @($channelData[0].accounts) }
        else { $common = @($common | Where-Object { $_ -cin $channelData[0].accounts }) }
    }
    if ($Channel.Count -and -not $common.Count) { throw 'selected channels cannot share one launch' }
    foreach ($id in $Channel) {
        $destination = Resolve-LegionChannel $Personalisation $id $Tool
        if ($AccountId -cnotin $destination.Accounts) { throw "account '$AccountId' is not bound to channel '$id'" }
        $resolved += $destination
    }
    $channelArgs = [Collections.Generic.List[string]]::new()
    $kinds = @()
    foreach ($destination in $resolved) {
        if ($destination.Kind -cin $kinds) { continue }
        $kinds += $destination.Kind
        foreach ($arg in $destination.LaunchArguments) { $channelArgs.Add($arg) }
    }
    $launchArgs = [Collections.Generic.List[string]]::new()
    if ($Resume -ceq 'claude') { $launchArgs.AddRange([string[]]@('--resume', $Session)) }
    elseif ($Resume -ceq 'codex') { $launchArgs.AddRange([string[]]@('resume', '--last')) }
    elseif ($Tool -ceq 'claude' -and $Session) { $launchArgs.AddRange([string[]]@('--session-id', $Session)) }
    foreach ($arg in @($Arguments) + $channelArgs.ToArray() + @($descriptor.overseerArgs)) {
        if ($null -ne $arg) { $launchArgs.Add([string]$arg) }
    }
    if ($Tool -eq 'claude' -and $launchArgs.Contains('--channels')) {
        $launchArgs.Add('--')
    }
    $launchArgs.Add('continue as the overseer')
    return @{Command=(Get-LegionWrapperCommand $AccountId $HomeRoot);Args=$launchArgs.ToArray()}
}

# Clear parent session markers and terminal overrides for a resumable interactive session.
function Get-OverseerParentVariables {
    return @('NO_COLOR', 'TERM', 'CLAUDECODE', 'CLAUDE_CODE_*')
}

function Invoke-OverseerInRepo {
    param([string]$Repo, [string]$Command, [string[]]$Arguments)
    $saved = @{}
    Push-Location -LiteralPath $Repo
    try {
        foreach ($pattern in Get-OverseerParentVariables) {
            foreach ($variable in Get-Item -Path "Env:$pattern" -ErrorAction Ignore) {
                $saved[$variable.Name] = $variable.Value
                [Environment]::SetEnvironmentVariable($variable.Name, $null)
            }
        }
        & $Command @Arguments
    }
    finally {
        Pop-Location
        foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
    }
}

function Start-OverseerLaunch {
    param([string]$Repo, $Launch, [switch]$DryRun, [switch]$InPlace)
    # Terminal parses semicolons as its own commands. Use the current terminal for literal ones.
    # An owner launch stays in the current terminal so its exit code is seen.
    $terminal = $null
    if ($IsWindows -and -not $InPlace -and -not (($Repo + $Launch.Command + ($Launch.Args -join '')) -match ';')) {
        $terminal = Get-Command wt -CommandType Application -ErrorAction SilentlyContinue
    }
    if ($terminal) {
        $literals = @($Launch.Command) + $Launch.Args | ForEach-Object { "'" + $_.Replace("'", "''") + "'" }
        $cleared = (Get-OverseerParentVariables | ForEach-Object { "Env:$_" }) -join ', '
        $commandText = "Remove-Item $cleared -ErrorAction Ignore; & " + ($literals -join ' ') + '; exit $LASTEXITCODE'
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($commandText))
        $terminalArgs = @('new-tab', '-d', $Repo, (Get-Process -Id $PID).Path, '-NoProfile', '-EncodedCommand', $encoded)
        if ($DryRun) { @('wt') + $terminalArgs }
        else { & $terminal.Source @terminalArgs }
    } elseif ($DryRun) {
        @($Repo, $Launch.Command) + $Launch.Args
    } else {
        Invoke-OverseerInRepo -Repo $Repo -Command $Launch.Command -Arguments $Launch.Args
    }
}

function Invoke-Overseer {
    param([string]$Repo, [string]$HomeRoot, [string]$Account, [string]$Tool, [string[]]$Channel, [string[]]$Arguments, [switch]$NoChannel, [switch]$DryRun, [switch]$Pick)
    $Repo = Get-LegionCodeRoot -Path $Repo
    if (-not $Repo) { throw 'not a git repository; run legion inside one' }
    $projectFile = Get-LegionRepoPath -Repo $Repo -Path 'configuration/project.json'
    $ownerFile = Get-LegionOwnerPath -HomeRoot $HomeRoot -Name Settings
    # No accounts yet: stop before any question, writing nothing.
    if (-not (Test-Path -LiteralPath $ownerFile)) { throw 'No accounts yet. Add one: legion add claude' }
    if (-not (Test-Path -LiteralPath $projectFile)) {
        $question = 'This repository is not set up. Set it up (private)? [Y/n]'
        if ($DryRun) { return $question }
        # A question nobody can answer is a stop.
        if (-not (Test-OverseerInteractive)) { throw $question }
        if (-not (Read-OverseerYes -Question $question)) { return 'Nothing changed.' }
        Invoke-OverseerRepositorySetup -Repo $Repo
    }
    foreach ($inputFile in @(@{Kind='personalisation';Path=$ownerFile},@{Kind='project';Path=$projectFile})) {
        $issues = @(Invoke-LegionValidation $inputFile.Kind $inputFile.Path)
        if ($issues.Count) { throw ($issues -join '; ') }
    }
    $personalisation = Read-LegionJson -Path $ownerFile
    # Bare start reuses the saved account, then the lease account; -Pick asks instead.
    # Saved channels and arguments apply only when the saved account leads.
    $ownerLaunch = -not $Account
    # -NoChannel alone still counts as a bare start: it restores the saved launch, then clears the channel.
    $bare = -not ($Account -or $Tool -or $Channel.Count -or $Arguments.Count)
    $known = @($personalisation.agents.id)
    $last = Get-OverseerLastLaunch -Repo $Repo -HomeRoot $HomeRoot
    $savedAccount = if ($last -and $last.account -cin $known) { $last.account }
    if ($bare -and -not $Pick) {
        $Account = $savedAccount
        if (-not $Account) {
            $leaseAccount = (Get-LegionLease -Repo $Repo).Data.account
            if ($leaseAccount -cin $known) { $Account = $leaseAccount }
        }
    }
    $selected = Select-OverseerAccount -Personalisation $personalisation -Account $Account -Tool $Tool -Channel $Channel -Last $savedAccount
    if ($bare -and $selected.id -ceq $savedAccount) {
        $Channel = if ($NoChannel) { @() } else { @($last.channels) }
        $Arguments = @($last.arguments)
        $NoChannel = -not $Channel.Count
    }
    if (-not $Tool) { $Tool = $selected.tool }
    # An explicit -Channel wins; -NoChannel skips only the default.
    if (-not $Channel.Count -and -not $NoChannel) {
        $default = Get-OverseerDefaultChannel -Personalisation $personalisation -AccountId $selected.id -Tool $Tool
        if ($default) { $Channel = @($default) }
    }
    # Resume the saved conversation when the tool can; Codex's session is always 'last', Copilot has none.
    $resume = Get-OverseerResume -Last $last -Selected $selected -HomeRoot $HomeRoot
    $session = switch ($Tool) {
        'claude' { if ($resume) { $last.session } else { New-OverseerSessionId } }
        'codex' { 'last' }
        default { '' }
    }
    $launch = Get-OverseerLaunch -Personalisation $personalisation -AccountId $selected.id -Tool $Tool -Channel $Channel -Arguments $Arguments -HomeRoot $HomeRoot -Session $session -Resume $resume
    $save = @{ Repo = $Repo; HomeRoot = $HomeRoot; Account = $selected.id; Channel = $Channel; Arguments = $Arguments }
    if (-not $DryRun) { Save-OverseerLastLaunch @save -Session $session }
    $channelText = if ($Channel.Count) { $Channel -join ', ' } else { 'none' }
    Write-Host ($(if ($resume) { 'resuming' } else { 'starting' }) + " overseer: $($selected.id), channel $channelText")
    # Reset first: a stale code must not look like a failed launch.
    $global:LASTEXITCODE = 0
    # Without -Account the owner typed the command; a scripted relaunch always names the account.
    Start-OverseerLaunch -Repo $Repo -Launch $launch -DryRun:$DryRun -InPlace:$ownerLaunch
    if (-not $DryRun -and $LASTEXITCODE -ne 0) {
        # A failed launch must not be resumed next time.
        Save-OverseerLastLaunch @save -Session ''
        $failure = [Exception]::new("the launch failed with exit code $LASTEXITCODE")
        $failure.Data['LegionLaunchExitCode'] = [int]$LASTEXITCODE
        throw $failure
    }
    # Reached only when the launch did not fail.
    if (-not $DryRun) {
        $message = "launched $($selected.id) ($Tool) in $Repo"
        foreach ($id in $Channel) { $message += " channel $id" }
        $message
    }
}

if (-not $NoRun) {
    try { Invoke-Overseer -Repo $Repo -HomeRoot $HomeRoot -Account $Account -Tool $Tool -Channel $Channel -Arguments $Arguments -NoChannel:$NoChannel -DryRun:$DryRun -Pick:$Pick }
    catch {
        if (-not $_.Exception.Data.Contains('LegionLaunchExitCode')) { throw }
        Write-Host $_.Exception.Message
        exit ([int]$_.Exception.Data['LegionLaunchExitCode'])
    }
}
