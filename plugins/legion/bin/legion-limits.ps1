param(
    [string]$Account,
    [int]$TimeoutSeconds = 120,
    [string]$HomeRoot = $HOME
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/settings.ps1')
. (Join-Path $PSScriptRoot 'lib/limits.ps1')

$file = Get-LegionOwnerPath -HomeRoot $HomeRoot -Name Settings
if (-not (Test-Path -LiteralPath $file)) { throw 'No legion settings yet; run legion setup.' }
$data = Read-LegionJson -Path $file
$agents = @($data.agents)
if ($Account) {
    $agents = @(Get-LegionAgent -Data $data -Id $Account | Where-Object { $null -ne $_ })
    if ($agents.Count -eq 0) { throw "unknown account '$Account'" }
}

$rows = foreach ($agent in $agents) {
    foreach ($row in @(Get-LegionAccountLimits -Agent $agent -HomeRoot $HomeRoot -TimeoutSeconds $TimeoutSeconds)) {
        [pscustomobject]@{
            Account = $agent.id; Tool = $agent.tool; Window = $row.Window
            Used = $row.Used; 'Resets at' = $row.Resets; Status = $row.Status
        }
    }
}
if (@($rows).Count -eq 0) { 'No accounts yet; run legion add.'; return }
($rows | Format-Table -AutoSize | Out-String -Width 200).TrimEnd() -split '\r?\n'
