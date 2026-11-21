function Get-FixtureMarketplaceListing {
    param([string]$Tool, [string]$Source)
    # Independent CLI response shapes, including empty listings.
    $items = @()
    if ($Source) {
        switch ($Tool) {
            fourth { $items += @{name='ps-legion-marketplace'; source=$Source} }
            fourth-cli { $items += @{name='ps-legion-marketplace'; source=$Source} }
            claude { $items += @{name='ps-legion-marketplace'; source='github'; repo=$Source} }
            codex { $items += @{name='ps-legion-marketplace'; root=$PSScriptRoot; marketplaceSource=@{sourceType='git'; source=$Source}} }
            copilot { $items += @{name='ps-legion-marketplace'; source="GitHub: $Source"; isDefault=$false} }
            default { throw "Unknown fixture tool $Tool" }
        }
    }
    if ($Tool -eq 'codex') { @{marketplaces=$items} | ConvertTo-Json -Depth 10 -Compress }
    else { ConvertTo-Json -InputObject $items -Depth 10 -Compress }
}
