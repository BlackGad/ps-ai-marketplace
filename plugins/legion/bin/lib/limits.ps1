. (Join-Path $PSScriptRoot 'paths.ps1')
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

# Runs the tool command once with stdin closed. The account's folder goes in the tool's config variable.
# Returns @{ ExitCode; Output; Error; TimedOut }; a timeout kills the process.
function Invoke-LegionPing {
    param([string]$Command, [string[]]$Arguments, [string]$ConfigEnv, [string]$Folder, [string]$WorkingDirectory, [int]$TimeoutSeconds)

    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    if ($WorkingDirectory) { $start.WorkingDirectory = $WorkingDirectory }
    $start.Environment[$ConfigEnv] = $Folder
    if ([IO.Path]::GetExtension($Command) -ieq '.ps1') {
        $start.FileName = (Get-Process -Id $PID).Path
        foreach ($argument in @('-NoProfile', '-File', $Command)) { $start.ArgumentList.Add($argument) }
    } else {
        $start.FileName = $Command
    }
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        $null = $process.Start()
        $process.StandardInput.Close()
        $output = $process.StandardOutput.ReadToEndAsync()
        $errors = $process.StandardError.ReadToEndAsync()
        $finished = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $finished) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        return @{
            ExitCode = if ($finished) { $process.ExitCode } else { -1 }
            Output = $output.GetAwaiter().GetResult()
            Error = $errors.GetAwaiter().GetResult()
            TimedOut = -not $finished
        }
    } finally { $process.Dispose() }
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
        $command = Get-Command $tool.command -CommandType Application,ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $command) { return New-LegionLimitRow -Status "$($tool.command) is not installed" }
        $folder = Resolve-LegionHomePath -Path $Agent.configDir -HomeRoot $HomeRoot
        return & $script -Command $command.Source -ConfigEnv $tool.configEnv -Folder $folder -TimeoutSeconds $TimeoutSeconds
    } catch {
        return New-LegionLimitRow -Status ('error: ' + (Get-LegionFirstLine -Text $_.Exception.Message))
    }
}
