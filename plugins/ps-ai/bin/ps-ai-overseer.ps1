param(
    [string]$Tool,
    [string]$Account,
    [string[]]$Channel,
    [string[]]$Arguments,
    [string]$Repo = (Get-Location).Path,
    [string]$HomeRoot = $HOME,
    [switch]$NoChannel,
    [switch]$DryRun,
    [switch]$NoRun
)

$launcherNoRun = $NoRun
. (Join-Path $PSScriptRoot 'ps-ai-validate.ps1') -NoRun

. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/channels.ps1')

function Select-OverseerAccount {
    param($Personalisation, [string]$Account, [string]$Tool, [string[]]$Channel)
    if (-not $Account) { return Select-OnlyOverseerAccount $Personalisation $Tool $Channel }
    $matches = @($Personalisation.agents | Where-Object id -CEQ $Account)
    if ($matches.Count -ne 1) { throw "unknown account '$Account'" }
    $selected = $matches[0]
    if ($Tool -and $selected.tool -cne $Tool) { throw "account '$Account' is a $($selected.tool) account, not $Tool" }
    return $selected
}

# Without -Account, the choice is automatic only when exactly one account is eligible.
function Select-OnlyOverseerAccount {
    param($Personalisation, [string]$Tool, [string[]]$Channel)
    $eligible = @($Personalisation.agents)
    if ($Tool) { $eligible = @($eligible | Where-Object tool -CEQ $Tool) }
    foreach ($id in $Channel) {
        $bound = @(@($Personalisation.channels | Where-Object id -CEQ $id).accounts)
        $eligible = @($eligible | Where-Object { $_.id -cin $bound })
    }
    if ($eligible.Count -eq 1) { return $eligible[0] }
    if ($eligible.Count -eq 0) { throw 'no account fits; run ps-ai-setup first' }
    throw ('Choose an account: -Account ' + (@($eligible.id) -join ' | '))
}

# A binding fits when it is bound to the account and its kind can launch the tool.
# The default channel is used only when exactly one binding fits.
function Get-OverseerDefaultChannel {
    param($Personalisation, [string]$AccountId, [string]$Tool)
    $kinds = @(Get-PsAiChannels | Where-Object { $Tool -cin $_.launch.PSObject.Properties.Name })
    $fitting = @($Personalisation.channels | Where-Object { $AccountId -cin $_.accounts -and $_.kind -cin $kinds.id })
    if ($fitting.Count -eq 1) { return $fitting[0].id }
    return $null
}

function Get-OverseerLaunch {
    param($Personalisation, [string]$AccountId, [string]$Tool, [string[]]$Channel, [string[]]$Arguments, [string]$HomeRoot = $HOME)
    $selected = Select-OverseerAccount $Personalisation $AccountId $Tool
    $Tool = $selected.tool
    $descriptor = Get-PsAiTool $Tool
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
        $destination = Resolve-PsAiChannel $Personalisation $id $Tool
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
    foreach ($arg in @($Arguments) + $channelArgs.ToArray() + @($descriptor.overseerArgs)) {
        if ($null -ne $arg) { $launchArgs.Add([string]$arg) }
    }
    if ($Tool -eq 'claude' -and $launchArgs.Contains('--channels')) {
        $launchArgs.Add('--')
    }
    $launchArgs.Add('continue as the overseer')
    return @{Command=(Get-PsAiWrapperCommand $AccountId $HomeRoot);Args=$launchArgs.ToArray()}
}

function Invoke-OverseerInRepo {
    param([string]$Repo, [string]$Command, [string[]]$Arguments)
    Push-Location -LiteralPath $Repo
    try { & $Command @Arguments }
    finally { Pop-Location }
}

function Start-OverseerLaunch {
    param([string]$Repo, $Launch, [switch]$DryRun)
    # Terminal parses semicolons as its own commands. Use the current terminal for literal ones.
    $terminal = $null
    if ($IsWindows -and -not (($Repo + $Launch.Command + ($Launch.Args -join '')) -match ';')) {
        $terminal = Get-Command wt -CommandType Application -ErrorAction SilentlyContinue
    }
    if ($terminal) {
        $literals = @($Launch.Command) + $Launch.Args | ForEach-Object { "'" + $_.Replace("'", "''") + "'" }
        # An agent shell that starts the tab sets NO_COLOR and TERM=dumb; the new interactive tab needs colors.
        $commandText = 'Remove-Item Env:NO_COLOR, Env:TERM -ErrorAction Ignore; & ' + ($literals -join ' ') + '; exit $LASTEXITCODE'
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
    param([string]$Repo, [string]$HomeRoot, [string]$Account, [string]$Tool, [string[]]$Channel, [string[]]$Arguments, [switch]$NoChannel, [switch]$DryRun)
    $projectFile = Get-PsAiRepoPath -Repo $Repo -Path 'configuration/project.json'
    if (-not (Test-Path -LiteralPath $projectFile)) {
        throw "no .legion/configuration/project.json in $Repo; run setup first"
    }
    $ownerFile = Get-PsAiHomePath -HomeRoot $HomeRoot -Path 'configuration/ps-ai-personalisation.json'
    foreach ($inputFile in @(@{Kind='personalisation';Path=$ownerFile},@{Kind='project';Path=$projectFile})) {
        $issues = @(Invoke-PsAiValidation $inputFile.Kind $inputFile.Path)
        if ($issues.Count) { throw ($issues -join '; ') }
    }
    $personalisation = Read-PsAiJson -Path $ownerFile
    $selected = Select-OverseerAccount -Personalisation $personalisation -Account $Account -Tool $Tool -Channel $Channel
    if (-not $Tool) { $Tool = $selected.tool }
    # An explicit -Channel wins; -NoChannel skips only the default.
    if (-not $Channel.Count -and -not $NoChannel) {
        $default = Get-OverseerDefaultChannel -Personalisation $personalisation -AccountId $selected.id -Tool $Tool
        if ($default) { $Channel = @($default) }
    }
    $launch = Get-OverseerLaunch -Personalisation $personalisation -AccountId $selected.id -Tool $Tool -Channel $Channel -Arguments $Arguments -HomeRoot $HomeRoot
    # Reset first: a stale code must not look like a failed launch.
    $global:LASTEXITCODE = 0
    Start-OverseerLaunch -Repo $Repo -Launch $launch -DryRun:$DryRun
    if (-not $DryRun -and $LASTEXITCODE -ne 0) { throw "the launch failed with exit code $LASTEXITCODE" }
    # Reached only when the launch did not fail.
    if (-not $DryRun) {
        $message = "launched $($selected.id) ($Tool) in $Repo"
        foreach ($id in $Channel) { $message += " channel $id" }
        $message
    }
}

if (-not $launcherNoRun) {
    Invoke-Overseer -Repo $Repo -HomeRoot $HomeRoot -Account $Account -Tool $Tool -Channel $Channel -Arguments $Arguments -NoChannel:$NoChannel -DryRun:$DryRun
}
