function Get-FixtureMarketplaceListing {
    param([string]$Tool, [string]$Source)
    # Independent CLI response shapes, including empty listings.
    if ($Tool -in @('fourth', 'fourth-cli')) {
        if ($Source) { "ps-ai-marketplace $Source" }
        return
    }
    $items = @()
    if ($Source) {
        switch ($Tool) {
            claude { $items += @{name='ps-ai-marketplace'; source='github'; repo=$Source} }
            codex { $items += @{name='ps-ai-marketplace'; root=$PSScriptRoot; marketplaceSource=@{sourceType='git'; source=$Source}} }
            copilot { $items += @{name='ps-ai-marketplace'; source="GitHub: $Source"; isDefault=$false} }
            default { throw "Unknown fixture tool $Tool" }
        }
    }
    if ($Tool -eq 'codex') { @{marketplaces=$items} | ConvertTo-Json -Depth 10 -Compress }
    else { ConvertTo-Json -InputObject $items -Depth 10 -Compress }
}
