param(
    [switch]$Check,
    [switch]$Force,
    [switch]$NoRun
)

. (Join-Path $PSScriptRoot 'lib/paths.ps1')

function Get-LegionUpdateHome {
    return [Environment]::GetFolderPath('UserProfile')
}

function Get-LegionUpdateText {
    param([string]$Url, [Net.Http.HttpClient]$Client = [Net.Http.HttpClient]::new())
    try {
        $Client.Timeout = [TimeSpan]::FromSeconds(3)
        $request = $Client.GetStringAsync($Url)
        # Bound the entire request, including DNS, redirects and a stalled response body.
        if (-not $request.Wait(3000)) { throw 'Update request timed out' }
        return $request.GetAwaiter().GetResult()
    } finally { $Client.Dispose() }
}

function Get-LegionUpdate {
    param([string]$PluginRoot = (Split-Path $PSScriptRoot -Parent), [switch]$Force)
    try {
        $manifest = Get-Content -LiteralPath (Join-Path $PluginRoot 'plugin.json') -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($manifest.name -ne 'ps-ai') { throw 'Invalid installed manifest' }
        $installed = [semver]::Parse([string]$manifest.version)
        $source = 'BlackGad/ps-ai-marketplace'
        $cachePath = Get-LegionOwnerPath -HomeRoot (Get-LegionUpdateHome) -Name Update
        $cached = $null
        if (-not $Force -and (Test-Path -LiteralPath $cachePath -PathType Leaf)) {
            try {
                $saved = Get-Content -LiteralPath $cachePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                $age = [DateTimeOffset]::UtcNow - [DateTimeOffset]$saved.CheckedAt
                if ($saved.Source -ceq $source -and $age.TotalDays -ge 0 -and $age.TotalDays -lt 1) {
                    if ($saved.Failed -eq $true) { return }
                    $null = [semver]::Parse([string]$saved.Available)
                    $cached = $saved
                }
            } catch { }
        }
        if (-not $cached) {
            $cached = [pscustomobject]@{ Source=$source; CheckedAt=[DateTimeOffset]::UtcNow.ToString('o'); Available=$null; Failed=$false }
            try {
                $text = Get-LegionUpdateText -Url "https://raw.githubusercontent.com/$source/stable/plugins/ps-ai/plugin.json"
                $latest = $text | ConvertFrom-Json -ErrorAction Stop
                if ($latest.name -ne 'ps-ai') { throw 'Invalid marketplace manifest' }
                $null = [semver]::Parse([string]$latest.version)
                $cached.Available = $latest.version
            } catch {
                $cached.Failed = $true
            }
            try {
                New-Item -ItemType Directory -Path (Split-Path $cachePath -Parent) -Force -ErrorAction Stop | Out-Null
                $cached | ConvertTo-Json | Set-Content -LiteralPath $cachePath -ErrorAction Stop
            } catch { } # A read-only cache must not prevent a check or a session from starting.
        }
        if ($cached.Failed) { throw 'Marketplace check failed' }
        return [pscustomobject]@{
            Installed = $manifest.version
            Available = $cached.Available
            Newer = ([semver]$cached.Available -gt $installed)
            Command = "legion update"
        }
    } catch {
        if ($Force) { throw }
        # Session-start checks are best effort and never write an error to the hook stream.
    }
}

function Invoke-LegionUpdateCheck {
    param([string]$PluginRoot = (Split-Path $PSScriptRoot -Parent), [switch]$Force)
    try {
        $result = Get-LegionUpdate -PluginRoot $PluginRoot -Force:$Force
        if ($result -and -not $result.Newer) {
            "ps-ai $($result.Installed) is up to date."
        } elseif ($result) {
            "ps-ai installed: $($result.Installed)"
            "ps-ai available: $($result.Available)"
            $result.Command
        }
    } catch {
        'ps-ai: update check failed; could not read the installed or GitHub plugin manifest.'
    }
}

if (-not $NoRun) {
    if ($Check) { Invoke-LegionUpdateCheck -Force:$Force }
    else { 'Usage: legion-update.ps1 -Check [-Force]' }
}
