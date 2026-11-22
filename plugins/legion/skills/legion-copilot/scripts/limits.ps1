param([string]$Command, [string]$Folder, [int]$TimeoutSeconds)

# Copilot CLI has no limit readout. A quota error means the account is out; a normal answer only shows it works now.
$ping = Invoke-LegionLimitPing -Command $Command -Arguments @('-p', 'ping', '-s') -TimeoutSeconds $TimeoutSeconds
if ($ping.ExitCode -eq 0) { New-LegionLimitRow -Status 'answers; no limit readout'; return }
New-LegionLimitRow -Status (Get-LegionPingFailure -Ping $ping -QuotaPattern 'quota')
