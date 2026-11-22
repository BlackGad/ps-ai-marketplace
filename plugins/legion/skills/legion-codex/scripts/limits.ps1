param([string]$Command, [string]$Folder, [int]$TimeoutSeconds)

# The window name from its length in minutes: 300 is 5h, 10080 is 7d.
function Get-CodexWindowName {
    param($Minutes, [string]$Fallback)
    if (-not $Minutes) { return $Fallback }
    if ($Minutes % 1440 -eq 0) { return "$($Minutes / 1440)d" }
    if ($Minutes % 60 -eq 0) { return "$($Minutes / 60)h" }
    return "${Minutes}m"
}

# Codex needs a git folder to run.
$ping = Invoke-LegionLimitPing -Command $Command -Arguments @('exec', 'ping') -TimeoutSeconds $TimeoutSeconds -Git

if ($ping.TimedOut) { New-LegionLimitRow -Status 'ping timed out'; return }

# A quota error names the time to try again.
$quota = @(($ping.Error + "`n" + $ping.Output) -split '\r?\n' | Where-Object { $_ -match 'hit your usage limit' })[0]
if ($quota) {
    $retry = if ($quota -match 'try again at (.+?)\.?\s*$') { $Matches[1] } else { 'unknown' }
    New-LegionLimitRow -Resets $retry -Status 'limit reached'
    return
}

if ($ping.ExitCode -ne 0) { New-LegionLimitRow -Status (Get-LegionPingFailure -Ping $ping -QuotaPattern 'usage limit'); return }

# Only the ping's disposable working folder can identify its session; timestamps cannot.
$limits = $null
$sessions = Join-Path $Folder 'sessions'
if (Test-Path -LiteralPath $sessions) {
    foreach ($file in (Get-ChildItem -LiteralPath $sessions -Filter '*.jsonl' -File -Recurse)) {
        $lines = [IO.File]::ReadLines($file.FullName).GetEnumerator()
        try {
            if (-not $lines.MoveNext()) { continue }
            try { $metadata = $lines.Current | ConvertFrom-Json -ErrorAction Stop } catch { continue }
            if ($metadata.type -cne 'session_meta' -or -not $metadata.payload.cwd) { continue }
            if (-not (Get-LegionPathComparer).Equals((Resolve-LegionDirectoryPath $metadata.payload.cwd), $ping.Folder)) { continue }
            while ($lines.MoveNext()) {
                if ($lines.Current -notlike '*"rate_limits"*') { continue }
                try { $record = $lines.Current | ConvertFrom-Json -ErrorAction Stop } catch { continue }
                $found = if ($record.payload.rate_limits) { $record.payload.rate_limits } else { $record.rate_limits }
                if ($found) { $limits = $found }
            }
            break
        } finally { $lines.Dispose() }
    }
}
$rows = @()
foreach ($name in @('primary', 'secondary')) {
    $window = $limits.$name
    if ($null -eq $window) { continue }
    $used = if ($null -ne $window.used_percent) { Format-LegionUsedPercent -Percent $window.used_percent } else { 'unknown' }
    $resets = if ($window.resets_at) { Format-LegionResetTime -UnixSeconds $window.resets_at } else { 'unknown' }
    $rows += New-LegionLimitRow -Window (Get-CodexWindowName -Minutes $window.window_minutes -Fallback $name) -Used $used -Resets $resets -Status 'unknown'
}
if ($rows.Count) { return $rows }
New-LegionLimitRow -Status 'no limit readout'
