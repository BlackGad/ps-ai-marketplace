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
. (Join-Path $PSScriptRoot 'lib/python.ps1')

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
    $result = Invoke-LegionPython -Arguments @('repository', 'setup', '--repo', $Repo) -HomeRoot $HomeRoot
    $result.Output | ForEach-Object { Write-Output $_ }
    $result.Error | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    if ($result.ExitCode -ne 0) { throw ($result.Error -join ' ') }
}

function Select-OverseerAccount {
    param($Personalisation, [string]$Account, [string]$Tool, [string[]]$Channel, [string]$Last)
    if (-not $Account) { return Select-OnlyOverseerAccount $Personalisation $Tool $Channel -Last $Last }
    $selected = Get-LegionAgent -Data $Personalisation -Id $Account
    if (-not $selected) { throw "unknown account '$Account'" }
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
    $kinds = @(Get-LegionChannels | Where-Object { Test-LegionChannelLaunchesTool $_ $Tool })
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
    $configDir = Resolve-LegionHomePath -Path $Selected.configDir -HomeRoot $HomeRoot
    $pattern = Join-Path ([WildcardPattern]::Escape($configDir)) "projects/*/$($Last.session).jsonl"
    if (Test-Path -Path $pattern) { return 'claude' }
    return $null
}

function Get-OverseerLaunch {
    param($Personalisation, [string]$AccountId, [string]$Tool, [string[]]$Channel, [string[]]$Arguments, [string]$HomeRoot = $HOME, [string]$Session, [string]$Resume, [string]$Repo)
    $selected = Select-OverseerAccount $Personalisation $AccountId $Tool
    $Tool = $selected.tool
    $descriptor = Get-LegionTool $Tool
    $resolved = @()
    $common = $null
    foreach ($id in $Channel) {
        $channelData = Get-LegionChannelBinding -Personalisation $Personalisation -Id $id
        if ($null -eq $common) { $common = @($channelData.accounts) }
        else { $common = @($common | Where-Object { $_ -cin $channelData.accounts }) }
    }
    if ($Channel.Count -and -not $common.Count) { throw 'selected channels cannot share one launch' }
    foreach ($id in $Channel) {
        $destination = Resolve-LegionChannel $Personalisation $id $Tool -HomeRoot $HomeRoot
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
    # One bot folder per session: a second channel with its own folder cannot share the launch.
    $stateful = @($resolved | Where-Object State)
    $statefulIds = @($stateful.Id | Select-Object -Unique)
    if ($statefulIds.Count -gt 1) { throw "A session can use only one $($stateful[0].Kind) channel (one bot folder per session); asked for: $($statefulIds -join ', ')" }
    $environment = [ordered]@{}
    $removed = @()
    foreach ($destination in $stateful) {
        if (-not (Test-Path -LiteralPath (Join-Path $destination.State.Folder $destination.State.TokenFile) -PathType Leaf)) {
            Write-Warning (Format-LegionBotFolderLine -Id $destination.Id -Ready $false -Setup $destination.State.Setup)
        }
        $environment[$destination.State.Variable] = $destination.State.Folder
        $removed += $destination.State.Remove
    }
    # Codex has no channel push: a bridge process carries the bot's messages into the repository inbox.
    $bridge = $null
    if ($Tool -ceq 'codex' -and $stateful.Count -and $stateful[0].Kind -ceq 'telegram') {
        $python = Get-LegionPythonCommand -Arguments @('telegram', 'bridge', '--channel', $stateful[0].Id, '--repo', $Repo) -HomeRoot $HomeRoot
        if ($python) {
            $folder = $stateful[0].State.Folder
            # Start-Process joins an argument array without quoting, so quote words with spaces here.
            $text = ($python.Arguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
            $bridge = @{Command=$python.Command;Arguments=$python.Arguments;ArgumentText=$text;Environment=$python.Environment;Folder=$folder}
        } else { Write-Warning 'uv is missing, so Telegram messages will not reach this Codex session. Ask the owner before installing uv.' }
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
    return @{Command=(Get-LegionWrapperCommand $AccountId $HomeRoot);Args=$launchArgs.ToArray();Environment=$environment;Remove=@($removed | Select-Object -Unique);Bridge=$bridge}
}

# Clear parent session markers and terminal overrides for a resumable interactive session.
function Get-OverseerParentVariables {
    return @('NO_COLOR', 'TERM', 'CLAUDECODE', 'CLAUDE_CODE_*')
}

function Invoke-OverseerInRepo {
    param([string]$Repo, [string]$Command, [string[]]$Arguments, [Collections.IDictionary]$Environment = @{}, [string[]]$Remove = @())
    $saved = @{}
    Push-Location -LiteralPath $Repo
    try {
        foreach ($pattern in @(Get-OverseerParentVariables) + $Remove) {
            foreach ($variable in Get-Item -Path "Env:$pattern" -ErrorAction Ignore) {
                $saved[$variable.Name] = $variable.Value
                [Environment]::SetEnvironmentVariable($variable.Name, $null)
            }
        }
        foreach ($name in $Environment.Keys) {
            if (-not $saved.ContainsKey($name)) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
            [Environment]::SetEnvironmentVariable($name, $Environment[$name])
        }
        & $Command @Arguments
    }
    finally {
        Pop-Location
        foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
    }
}

# Starts the Telegram bridge beside a Codex overseer; its output goes to a log in the bot folder.
function Start-OverseerBridge {
    param($Bridge, [string]$Repo)
    if (-not $Bridge) { return $null }
    $saved = $env:UV_PROJECT_ENVIRONMENT
    $env:UV_PROJECT_ENVIRONMENT = $Bridge.Environment.UV_PROJECT_ENVIRONMENT
    try {
        return Start-Process -FilePath $Bridge.Command -ArgumentList $Bridge.ArgumentText -WorkingDirectory $Repo -NoNewWindow -PassThru `
            -RedirectStandardOutput (Join-Path $Bridge.Folder 'bridge.log') -RedirectStandardError (Join-Path $Bridge.Folder 'bridge.err')
    }
    finally { $env:UV_PROJECT_ENVIRONMENT = $saved }
}

# The bridge is killed with the whole uv process tree, so it cannot remove its own pid file.
# Remove the file only when the process it names is gone: a refused second bridge must not delete the running one's marker.
function Stop-OverseerBridge {
    param($Process, $Bridge)
    if (-not $Process) { return }
    try { $Process.Kill($true); $null = $Process.WaitForExit(5000) } catch { Write-Verbose "bridge already stopped: $_" }
    $pidFile = Join-Path $Bridge.Folder 'bridge.pid'
    $named = Get-Content -LiteralPath $pidFile -ErrorAction Ignore
    if (-not $named -or -not (Get-Process -Id ([int]$named) -ErrorAction Ignore)) { Remove-Item -LiteralPath $pidFile -Force -ErrorAction Ignore }
}

function Start-OverseerLaunch {
    param([string]$Repo, $Launch, [switch]$DryRun, [switch]$InPlace)
    # Terminal parses semicolons as its own commands. Use the current terminal for literal ones.
    # An owner launch stays in the current terminal so its exit code is seen.
    $terminal = $null
    $environment = if ($Launch.Environment) { $Launch.Environment } else { @{} }
    $remove = @($Launch.Remove)
    $environmentText = @($environment.Keys | ForEach-Object { "env $_=$($environment[$_])" })
    $bridgeText = if ($Launch.Bridge) { @('bridge: ' + $Launch.Bridge.Command + ' ' + ($Launch.Bridge.Arguments -join ' ')) } else { @() }
    if ($IsWindows -and -not $InPlace -and -not (($Repo + $Launch.Command + ($Launch.Args -join '') + ($environment.Values -join '') + $Launch.Bridge.ArgumentText) -match ';')) {
        $terminal = Get-Command wt -CommandType Application -ErrorAction SilentlyContinue
    }
    if ($terminal) {
        $literals = @($Launch.Command) + $Launch.Args | ForEach-Object { "'" + $_.Replace("'", "''") + "'" }
        $cleared = (@(Get-OverseerParentVariables) + $remove | ForEach-Object { "Env:$_" }) -join ', '
        # A new terminal tab may not inherit this process's environment, so the command line sets it itself.
        $assignments = $environment.Keys | ForEach-Object { "`$env:$_ = '" + $environment[$_].Replace("'", "''") + "'; " }
        $commandText = "Remove-Item $cleared -ErrorAction Ignore; $($assignments -join '')& " + ($literals -join ' ') + '; exit $LASTEXITCODE'
        if ($Launch.Bridge) {
            # The tab starts and stops the bridge itself, around the session.
            $bridge = $Launch.Bridge
            $quote = { param($text) "'" + $text.Replace("'", "''") + "'" }
            $start = "`$env:UV_PROJECT_ENVIRONMENT = $(& $quote $bridge.Environment.UV_PROJECT_ENVIRONMENT); " +
                "`$bridge = Start-Process -FilePath $(& $quote $bridge.Command) -ArgumentList $(& $quote $bridge.ArgumentText) -NoNewWindow -PassThru " +
                "-RedirectStandardOutput $(& $quote (Join-Path $bridge.Folder 'bridge.log')) -RedirectStandardError $(& $quote (Join-Path $bridge.Folder 'bridge.err')); "
            $pidFile = & $quote (Join-Path $bridge.Folder 'bridge.pid')
            $stop = "`$bridge.Kill(`$true); `$null = `$bridge.WaitForExit(5000); `$named = Get-Content -LiteralPath $pidFile -ErrorAction Ignore; " +
                "if (-not `$named -or -not (Get-Process -Id ([int]`$named) -ErrorAction Ignore)) { Remove-Item -LiteralPath $pidFile -Force -ErrorAction Ignore }"
            $commandText = "Remove-Item $cleared -ErrorAction Ignore; $($assignments -join '')$start" +
                'try { & ' + ($literals -join ' ') + '; $code = $LASTEXITCODE } finally { ' + $stop + ' }; exit $code'
        }
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($commandText))
        $terminalArgs = @('new-tab', '-d', $Repo, (Get-Process -Id $PID).Path, '-NoProfile', '-EncodedCommand', $encoded)
        if ($DryRun) { $environmentText + $bridgeText + @('wt') + $terminalArgs }
        else { & $terminal.Source @terminalArgs }
    } elseif ($DryRun) {
        $environmentText + @($Repo, $Launch.Command) + $Launch.Args + $bridgeText
    } else {
        $process = Start-OverseerBridge -Bridge $Launch.Bridge -Repo $Repo
        try { Invoke-OverseerInRepo -Repo $Repo -Command $Launch.Command -Arguments $Launch.Args -Environment $environment -Remove $remove }
        finally { Stop-OverseerBridge -Process $process -Bridge $Launch.Bridge }
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
    $launch = Get-OverseerLaunch -Personalisation $personalisation -AccountId $selected.id -Tool $Tool -Channel $Channel -Arguments $Arguments -HomeRoot $HomeRoot -Session $session -Resume $resume -Repo $Repo
    $save = @{ Repo = $Repo; HomeRoot = $HomeRoot; Account = $selected.id; Channel = $Channel; Arguments = $Arguments }
    if (-not $DryRun) {
        Save-OverseerLastLaunch @save -Session $session
        foreach ($folder in $launch.Environment.Values) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
    }
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
