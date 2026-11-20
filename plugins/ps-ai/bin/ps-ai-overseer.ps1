param(
    [string]$Tool,
    [string]$Account,
    [string[]]$Channel,
    [string[]]$Arguments,
    [string]$Repo = (Get-Location).Path,
    [string]$HomeRoot = $HOME,
    [switch]$DryRun,
    [switch]$NoRun
)

$launcherNoRun = $NoRun
. (Join-Path $PSScriptRoot 'ps-ai-validate.ps1') -NoRun

. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/channels.ps1')

function Select-OverseerAccount {
    param($Personalisation, [string]$Account, [string]$Tool)
    if (-not $Account) { throw 'an explicit account is required' }
    $matches = @($Personalisation.agents | Where-Object id -CEQ $Account)
    if ($matches.Count -ne 1) { throw "unknown account '$Account'" }
    $selected = $matches[0]
    if ($Tool -and $selected.tool -cne $Tool) { throw "account '$Account' is a $($selected.tool) account, not $Tool" }
    return $selected
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
        $commandText = '& ' + ($literals -join ' ') + '; exit $LASTEXITCODE'
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

if (-not $launcherNoRun) {
    if (-not $Account) { 'Usage: ps-ai-overseer -Account <id> [-Tool <tool>] [-Channel <id[]>] [-Arguments <string[]>] [-Repo <path>]'; return }
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
    $selected = Select-OverseerAccount -Personalisation $personalisation -Account $Account -Tool $Tool
    if (-not $Tool) { $Tool = $selected.tool }
    $launch = Get-OverseerLaunch -Personalisation $personalisation -AccountId $selected.id -Tool $Tool -Channel $Channel -Arguments $Arguments -HomeRoot $HomeRoot
    Start-OverseerLaunch -Repo $Repo -Launch $launch -DryRun:$DryRun
}
