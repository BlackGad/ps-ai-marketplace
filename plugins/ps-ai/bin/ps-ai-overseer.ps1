param(
    [string]$Tool,
    [string]$Account,
    [string]$Repo = (Get-Location).Path,
    [string]$HomeRoot = $HOME,
    [switch]$DryRun,
    [switch]$NoRun
)

$launcherNoRun = $NoRun
. (Join-Path $PSScriptRoot 'ps-ai-validate.ps1') -NoRun

function Get-OverseerLaunch {
    param($Personalisation, $Project, [string]$AccountId, [string]$Tool, [string]$HomeRoot = $HOME)
    $agent = @($Personalisation.agents | Where-Object { $_.id -ceq $AccountId })[0]
    if ($null -eq $agent) { throw "unknown account '$AccountId'" }
    if (-not $Tool) { $Tool = $agent.tool }
    $descriptor = Get-PsAiTool -Tool $Tool
    $command = [string]$agent.command
    if ($command.StartsWith('~/')) { $command = Join-Path $HomeRoot $command.Substring(2) }
    $arguments = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    foreach ($arg in @($agent.launch.args)) { if ($null -ne $arg) { $arguments.Add([string]$arg) } }
    $settings = $Personalisation.projects.PSObject.Properties[$Project.id].Value
    $channels = if ($null -eq $settings) { @($Personalisation.default.notify) } else { @($settings.notify) }
    foreach ($channelName in $channels) {
        if ($null -eq $channelName) { continue }
        $channel = $Personalisation.communication.channels.PSObject.Properties[$channelName].Value
        $flags = $channel.launch.PSObject.Properties[$Tool].Value
        if ($null -eq $flags) {
            $warnings.Add("channel '$channelName' has no launch flags for $Tool; updates go to the terminal only.")
        } else {
            foreach ($arg in $flags) { $arguments.Add([string]$arg) }
        }
    }
    if ($null -ne $settings) {
        $flags = $settings.launch.PSObject.Properties[$Tool].Value
        foreach ($arg in @($flags)) { if ($null -ne $arg) { $arguments.Add([string]$arg) } }
    }
    foreach ($arg in $descriptor.overseerArgs) { $arguments.Add($arg) }
    $arguments.Add('continue as the overseer')
    return @{ Command = $command; Args = $arguments.ToArray(); Warnings = $warnings.ToArray() }
}

function Select-OverseerAccount {
    param($Personalisation, [string]$Account, [string]$Tool)
    if ($Account) {
        $match = @($Personalisation.agents | Where-Object { $_.id -ceq $Account })[0]
        if ($null -eq $match) { throw "unknown account '$Account'" }
        if ($Tool -and $match.tool -ne $Tool) { throw "account '$Account' is a $($match.tool) account, not $Tool" }
        return $match
    }
    $candidates = @($Personalisation.agents | Where-Object { $_.roles -contains 'overseer' })
    if ($Tool) {
        $candidates = @($candidates | Where-Object { $_.tool -eq $Tool })
        if ($candidates.Count -eq 0) { throw "no $Tool account has the overseer role; add it to one or pass -Account" }
    }
    if ($candidates.Count -eq 0) { throw 'no overseer account configured' }
    return $candidates[0]
}

function Invoke-OverseerInRepo {
    param([string]$Repo, [string]$Command, [string[]]$Arguments)
    Push-Location -LiteralPath $Repo
    try { & $Command @Arguments }
    finally { Pop-Location }
}

if (-not $launcherNoRun) {
    $projectFile = Join-Path $Repo '.agents/configuration/project.json'
    if (-not (Test-Path -LiteralPath $projectFile)) {
        throw "no .agents/configuration/project.json in $Repo; run setup first"
    }
    $ownerFile = Join-Path $HomeRoot '.agents/configuration/ps-ai-personalisation.json'
    $personalisation = Read-PsAiJson -Path $ownerFile
    $project = Read-PsAiJson -Path $projectFile
    $selected = Select-OverseerAccount -Personalisation $personalisation -Account $Account -Tool $Tool
    if (-not $Tool) { $Tool = $selected.tool }
    $launch = Get-OverseerLaunch -Personalisation $personalisation -Project $project -AccountId $selected.id -Tool $Tool -HomeRoot $HomeRoot
    foreach ($warning in $launch.Warnings) { Write-Warning $warning }
    if ($IsWindows) {
        $parts = @('wt', 'new-tab', '-d', $Repo, $launch.Command) + $launch.Args
    } else {
        $parts = @($launch.Command) + $launch.Args
    }
    if ($DryRun) { $parts | Write-Output }
    elseif ($IsWindows) { & wt new-tab -d $Repo $launch.Command @($launch.Args) }
    else { Invoke-OverseerInRepo -Repo $Repo -Command $launch.Command -Arguments $launch.Args }
}
