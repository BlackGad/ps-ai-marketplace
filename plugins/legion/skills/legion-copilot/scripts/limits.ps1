param([string]$Command, [string]$ConfigEnv, [string]$Folder, [int]$TimeoutSeconds)

# Copilot CLI has no limit readout. A quota error means the account is out; a normal answer only shows it works now.
$ping = Invoke-LegionPing -Command $Command -Arguments @('-p', 'ping', '-s') -ConfigEnv $ConfigEnv -Folder $Folder -TimeoutSeconds $TimeoutSeconds
if ($ping.ExitCode -eq 0) { New-LegionLimitRow -Status 'answers; no limit readout'; return }
New-LegionLimitRow -Status (Get-LegionPingFailure -Ping $ping -QuotaPattern 'quota')
