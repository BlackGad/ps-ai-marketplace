. (Join-Path $PSScriptRoot 'accounts.ps1')
. (Join-Path $PSScriptRoot 'process.ps1')
. (Join-Path $PSScriptRoot 'tools.ps1')
. (Join-Path $PSScriptRoot 'foundry.ps1')

# One row of the limits table; every field a tool does not expose stays 'unknown'.
function New-LegionLimitRow {
    param([string]$Window = '-', [string]$Used = 'unknown', [string]$Resets = 'unknown', [string]$Status = 'unknown')
    return [pscustomobject]@{ Window = $Window; Used = $Used; Resets = $Resets; Status = $Status }
}

function Format-LegionResetTime {
    param([long]$UnixSeconds)
    return [DateTimeOffset]::FromUnixTimeSeconds($UnixSeconds).ToLocalTime().ToString('yyyy-MM-dd HH:mm')
}

function Format-LegionUsedPercent {
    param([double]$Percent)
    return "$([math]::Round($Percent))%"
}

function Get-LegionFirstLine {
    param([string]$Text)
    return (@($Text -split '\r?\n' | Where-Object { $_.Trim() }) + '')[0].Trim()
}

# The status of a ping that gave no readout. Only the tool's own quota wording counts as 'limit reached'.
function Get-LegionPingFailure {
    param($Ping, [string]$QuotaPattern)
    if ($Ping.TimedOut) { return 'ping timed out' }
    $text = $Ping.Error + "`n" + $Ping.Output
    if (@($text -split '\r?\n' | Where-Object { $_ -match $QuotaPattern }).Count) { return 'limit reached' }
    return 'ping failed: ' + (Get-LegionFirstLine -Text $Ping.Error)
}

# The rows of one account. Foundry accounts have no window: they report the Azure token check.
function Get-LegionAccountLimits {
    param($Agent, [string]$HomeRoot, [int]$TimeoutSeconds)

    try {
        if ($Agent.provider.kind -ceq 'foundry') {
            $check = Test-FoundryToken
            $status = if ($check.Ok) { 'token ok' } else { Get-LegionFirstLine -Text $check.Error }
            return New-LegionLimitRow -Used '-' -Resets '-' -Status $status
        }
        $tool = Get-LegionTool -Tool $Agent.tool
        $script = Join-Path $tool.SkillRoot 'scripts/limits.ps1'
        if (-not (Test-Path -LiteralPath $script -PathType Leaf)) { return New-LegionLimitRow -Status "no limits script for $($Agent.tool)" }
        $command = Get-LegionWrapperCommand $Agent.id $HomeRoot
        if (-not (Test-LegionLauncherExecutable -Path $command)) { return New-LegionLimitRow -Status 'launcher missing; run legion setup' }
        $folder = Resolve-LegionHomePath -Path $Agent.configDir -HomeRoot $HomeRoot
        return & $script -Command $command -Folder $folder -TimeoutSeconds $TimeoutSeconds
    } catch {
        return New-LegionLimitRow -Status ('error: ' + (Get-LegionFirstLine -Text $_.Exception.Message))
    }
}
