param([string]$Command, [string]$Folder, [int]$TimeoutSeconds)

# Claude Code prints a rate_limit_event in its stream; each unified window has a utilization (0 to 1) and a reset time.
$ping = Invoke-LegionProcess -Command $Command -Arguments @('-p', '--output-format', 'stream-json', '--verbose', 'ping') `
    -TimeoutSeconds $TimeoutSeconds
$info = $null
foreach ($line in ($ping.Output -split '\r?\n')) {
    try { $event = $line | ConvertFrom-Json -ErrorAction Stop } catch { continue }
    if ($event.type -ceq 'rate_limit_event') { $info = $event.rate_limit_info }
}
if ($info.unifiedWindows) {
    foreach ($window in $info.unifiedWindows.PSObject.Properties) {
        $used = if ($null -ne $window.Value.utilization) { Format-LegionUsedPercent -Percent ($window.Value.utilization * 100) } else { 'unknown' }
        $resets = if ($window.Value.resetsAt) { Format-LegionResetTime -UnixSeconds $window.Value.resetsAt } else { 'unknown' }
        $status = if ($window.Value.status) { $window.Value.status } else { 'unknown' }
        New-LegionLimitRow -Window $window.Name -Used $used -Resets $resets -Status $status
    }
    return
}
if ($info) {
    $resets = if ($info.resetsAt) { Format-LegionResetTime -UnixSeconds $info.resetsAt } else { 'unknown' }
    $window = if ($info.rateLimitType) { $info.rateLimitType } else { '-' }
    New-LegionLimitRow -Window $window -Resets $resets -Status $(if ($info.status) { $info.status } else { 'unknown' })
    return
}
if ($ping.ExitCode -eq 0) { New-LegionLimitRow -Status 'no limit readout'; return }
New-LegionLimitRow -Status (Get-LegionPingFailure -Ping $ping -QuotaPattern 'usage limit|rate limit')
