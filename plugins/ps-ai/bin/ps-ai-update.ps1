param(
    [switch]$Check,
    [switch]$Force,
    [switch]$NoRun
)

function Get-PsAiUpdateHome {
    return [Environment]::GetFolderPath('UserProfile')
}

function Get-PsAiUpdateText {
    param([string]$Url, [Net.Http.HttpClient]$Client = [Net.Http.HttpClient]::new())
    try {
        $Client.Timeout = [TimeSpan]::FromSeconds(3)
        $request = $Client.GetStringAsync($Url)
        # Bound the entire request, including DNS, redirects and a stalled response body.
        if (-not $request.Wait(3000)) { throw 'Update request timed out' }
        return $request.GetAwaiter().GetResult()
    } finally { $Client.Dispose() }
}

function ConvertTo-PsAiUpdateSource {
    param([string]$Source)
    if ($Source -match '^(?:https://github\.com/|git@github\.com:|ssh://git@github\.com/)?(?<repo>[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*?)(?:\.git)?/?$') {
        return $Matches.repo
    }
}

function Get-PsAiUpdateSource {
    param([string]$PluginRoot)
    # Installed copies may live in a marketplace checkout or in its separate plugin cache.
    $folder = $PluginRoot
    while ($folder) {
        $registry = Join-Path $folder 'known_marketplaces.json'
        if (Test-Path -LiteralPath $registry -PathType Leaf) {
            try {
                $info = Get-Content -LiteralPath $registry -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                $source = ConvertTo-PsAiUpdateSource $info.'ps-ai-marketplace'.source.repo
                if ($source) { return $source }
            } catch { }
        }
        $config = Join-Path $folder 'config.toml'
        if (Test-Path -LiteralPath $config -PathType Leaf) {
            try {
                $text = Get-Content -LiteralPath $config -Raw -ErrorAction Stop
                $section = [regex]::Match($text, '(?ms)^\[marketplaces\.(?:ps-ai-marketplace|"ps-ai-marketplace"|''ps-ai-marketplace'')\]\s*\r?\n(.*?)(?=^\[|\z)').Groups[1].Value
                $url = [regex]::Match($section, '(?m)^source\s*=\s*(?<quote>["''])(?<url>.*?)\k<quote>').Groups['url'].Value
                $source = ConvertTo-PsAiUpdateSource $url
                if ($source) { return $source }
            } catch { }
        }
        foreach ($relative in @('.git/config', 'marketplaces/ps-ai-marketplace/.git/config')) {
            $config = Join-Path $folder $relative
            if (-not (Test-Path -LiteralPath $config -PathType Leaf)) { continue }
            try {
                $checkout = Split-Path (Split-Path $config -Parent) -Parent
                $catalog = Get-Content -LiteralPath (Join-Path $checkout '.claude-plugin/marketplace.json') -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                if ($catalog.name -cne 'ps-ai-marketplace') { continue }
                $owned = $false
                foreach ($plugin in $catalog.plugins) {
                    if ($plugin.name -cne 'ps-ai' -or $plugin.source -isnot [string]) { continue }
                    $candidate = [IO.Path]::GetFullPath((Join-Path $checkout $plugin.source))
                    if ($candidate -eq [IO.Path]::GetFullPath($PluginRoot)) { $owned = $true }
                }
                if (-not $owned) { continue }
                $text = Get-Content -LiteralPath $config -Raw -ErrorAction Stop
                $origin = [regex]::Match($text, '(?ms)^\[remote "origin"\]\s*\r?\n(.*?)(?=^\[|\z)').Groups[1].Value
                $url = [regex]::Match($origin, '(?m)^\s*url\s*=\s*(\S+)').Groups[1].Value
                $source = ConvertTo-PsAiUpdateSource $url
                if ($source) { return $source }
            } catch { }
        }
        $folder = Split-Path $folder -Parent
    }
    return 'BlackGad/ps-ai-marketplace'
}

function Get-PsAiUpdate {
    param([string]$PluginRoot = (Split-Path $PSScriptRoot -Parent), [switch]$Force)
    try {
        $manifest = Get-Content -LiteralPath (Join-Path $PluginRoot 'plugin.json') -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($manifest.name -ne 'ps-ai') { throw 'Invalid installed manifest' }
        $installed = [semver]::Parse([string]$manifest.version)
        $source = Get-PsAiUpdateSource -PluginRoot $PluginRoot
        $cachePath = Join-Path (Get-PsAiUpdateHome) '.agents/temp/ps-ai-update.json'
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
                $text = Get-PsAiUpdateText -Url "https://raw.githubusercontent.com/$source/main/plugins/ps-ai/plugin.json"
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
            Command = "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/$source/main/install.ps1))) -Source '$source' -Update"
        }
    } catch {
        if ($Force) { throw }
        # Session-start checks are best effort and never write an error to the hook stream.
    }
}

function Invoke-PsAiUpdateCheck {
    param([string]$PluginRoot = (Split-Path $PSScriptRoot -Parent), [switch]$Force)
    try {
        $result = Get-PsAiUpdate -PluginRoot $PluginRoot -Force:$Force
        if ($result) {
            "ps-ai installed: $($result.Installed)"
            "ps-ai available: $($result.Available)"
            $result.Command
        }
    } catch {
        'ps-ai: update check failed; could not read the installed or GitHub plugin manifest.'
    }
}

if (-not $NoRun) {
    if ($Check) { Invoke-PsAiUpdateCheck -Force:$Force }
    else { 'Usage: ps-ai-update.ps1 -Check [-Force]' }
}
