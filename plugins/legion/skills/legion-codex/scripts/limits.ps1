param([string]$Command, [string]$ConfigEnv, [string]$Folder, [int]$TimeoutSeconds)

# The window name from its length in minutes: 300 is 5h, 10080 is 7d.
function Get-CodexWindowName {
    param($Minutes, [string]$Fallback)
    if (-not $Minutes) { return $Fallback }
    if ($Minutes % 1440 -eq 0) { return "$($Minutes / 1440)d" }
    if ($Minutes % 60 -eq 0) { return "$($Minutes / 60)h" }
    return "${Minutes}m"
}

# Codex needs a git folder to run; a fresh empty one keeps the ping away from every project.
$work = Join-Path ([IO.Path]::GetTempPath()) ('legion-limits-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    & git -C $work init -q
    $ping = Invoke-LegionPing -Command $Command -Arguments @('exec', 'ping') -ConfigEnv $ConfigEnv -Folder $Folder `
        -WorkingDirectory $work -TimeoutSeconds $TimeoutSeconds
} finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }

# A quota error names the time to try again.
$quota = @(($ping.Error + "`n" + $ping.Output) -split '\r?\n' | Where-Object { $_ -match 'hit your usage limit' })[0]
if ($quota) {
    $retry = if ($quota -match 'try again at (.+?)\.?\s*$') { $Matches[1] } else { 'unknown' }
    New-LegionLimitRow -Resets $retry -Status 'limit reached'
    return
}

# Otherwise the newest session file of this account holds the last rate_limits record.
$limits = $null
$sessions = Join-Path $Folder 'sessions'
$newest = if (Test-Path -LiteralPath $sessions) {
    Get-ChildItem -LiteralPath $sessions -Filter '*.jsonl' -File -Recurse | Sort-Object LastWriteTimeUtc | Select-Object -Last 1
}
if ($newest) {
    foreach ($line in (Get-Content -LiteralPath $newest.FullName | Where-Object { $_ -like '*"rate_limits"*' })) {
        try { $record = $line | ConvertFrom-Json -ErrorAction Stop } catch { continue }
        $found = if ($record.payload.rate_limits) { $record.payload.rate_limits } else { $record.rate_limits }
        if ($found) { $limits = $found }
    }
}
$rows = @()
foreach ($name in @('primary', 'secondary')) {
    $window = $limits.$name
    if ($null -eq $window) { continue }
    $used = if ($null -ne $window.used_percent) { Format-LegionUsedPercent -Percent $window.used_percent } else { 'unknown' }
    $resets = if ($window.resets_at) { Format-LegionResetTime -UnixSeconds $window.resets_at } else { 'unknown' }
    $rows += New-LegionLimitRow -Window (Get-CodexWindowName -Minutes $window.window_minutes -Fallback $name) -Used $used -Resets $resets -Status 'allowed'
}
if ($rows.Count) { return $rows }
if ($ping.ExitCode -eq 0) { New-LegionLimitRow -Status 'no limit readout'; return }
New-LegionLimitRow -Status (Get-LegionPingFailure -Ping $ping -QuotaPattern 'usage limit')
