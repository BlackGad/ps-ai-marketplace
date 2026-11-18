#Requires -Version 7
<#
.SYNOPSIS
    Read-only probe of one Azure Foundry endpoint for the ps-ai Foundry agent design.
.DESCRIPTION
    Never logs in, never prints or saves a token, changes no settings and installs nothing.
    CLI pings (-Ping) use a temporary CODEX_HOME / COPILOT_HOME that is deleted at the end;
    Claude runs with Foundry variables set only for its own child process.
    Run it three times: wrong or no az login; right account without permission; full permission.
.EXAMPLE
    pwsh -NoProfile -File foundry-probe.ps1 -Endpoint https://<resource>.cognitiveservices.azure.com -Ping
#>
param(
    [Parameter(Mandatory)][string]$Endpoint,
    [string]$GptDeployment,
    [string]$ClaudeDeployment,
    [switch]$Ping,
    [string]$ApiVersion = '2025-04-01-preview'
)

$ErrorActionPreference = 'Continue'
$script:Token = $null
$script:Summary = [ordered]@{}

function Hide-Secret([string]$Text) {
    if (-not $Text) { return '' }
    if ($script:Token) { $Text = $Text.Replace($script:Token, '<token>') }
    $Text = $Text -replace 'eyJ[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+', '<jwt>'
    return $Text
}

function Write-Step([string]$Name) { "`n=== $Name ===" }

function Get-Short([string]$Text, [int]$Max = 400) {
    $Text = (Hide-Secret $Text) -replace '\s+', ' '
    if ($Text.Length -gt $Max) { return $Text.Substring(0, $Max) + '...' }
    return $Text
}

function Invoke-Az([string[]]$Arguments) {
    $output = & az @Arguments 2>&1
    $text = ($output | ForEach-Object { "$_" }) -join "`n"
    return [pscustomobject]@{ Ok = ($LASTEXITCODE -eq 0); Text = $text }
}

function Invoke-Probe([string]$Method, [string]$Uri, [hashtable]$Headers, $Body) {
    try {
        $parameters = @{ Method = $Method; Uri = $Uri; Headers = $Headers; SkipHttpErrorCheck = $true; TimeoutSec = 60 }
        if ($null -ne $Body) { $parameters.Body = ($Body | ConvertTo-Json -Depth 10); $parameters.ContentType = 'application/json' }
        $response = Invoke-WebRequest @parameters
        return [pscustomobject]@{ Status = [int]$response.StatusCode; Content = "$($response.Content)" }
    } catch {
        return [pscustomobject]@{ Status = -1; Content = "$($_.Exception.Message)" }
    }
}

function Get-ErrorText([string]$Content) {
    try {
        $json = $Content | ConvertFrom-Json -ErrorAction Stop
        if ($json.error) { return Get-Short "$($json.error.code) $($json.error.type) $($json.error.message)" 300 }
    } catch { }
    return Get-Short $Content 300
}

function Invoke-Cli([string]$File, [string[]]$Arguments, [hashtable]$Environment, [string]$WorkDir, [int]$TimeoutSec = 180) {
    try {
        return Invoke-CliCore $File $Arguments $Environment $WorkDir $TimeoutSec
    } catch {
        return "failed to start: $(Get-Short $_.Exception.Message 300)"
    }
}

function Invoke-CliCore([string]$File, [string[]]$Arguments, [hashtable]$Environment, [string]$WorkDir, [int]$TimeoutSec) {
    # npm installs PowerShell (.ps1) and batch (.cmd) shims; neither can be started directly.
    if ($File -like '*.ps1') {
        $Arguments = @('-NoProfile', '-File', $File) + $Arguments
        $File = (Get-Process -Id $PID).Path
    } elseif ($File -like '*.cmd' -or $File -like '*.bat') {
        $Arguments = @('/d', '/c', $File) + $Arguments
        $File = $env:ComSpec
    }
    $start = [System.Diagnostics.ProcessStartInfo]::new($File)
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.UseShellExecute = $false
    $start.WorkingDirectory = $WorkDir
    foreach ($key in $Environment.Keys) { $start.Environment[$key] = $Environment[$key] }
    $process = [System.Diagnostics.Process]::Start($start)
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSec * 1000)) {
        $process.Kill($true)
        return "timeout after $TimeoutSec s"
    }
    return "exit $($process.ExitCode); stdout: $(Get-Short $stdout.Result 300); stderr: $(Get-Short $stderr.Result 300)"
}

$uri = [Uri]$Endpoint
$base = "$($uri.Scheme)://$($uri.Host)"
$resourceName = $uri.Host.Split('.')[0]

Write-Step 'Environment'
"probe time (UTC): $([DateTime]::UtcNow.ToString('u'))"
"pwsh: $($PSVersionTable.PSVersion)"
"endpoint base: $base (resource name '$resourceName')"
foreach ($tool in 'az', 'claude', 'codex', 'copilot') {
    $command = Get-Command $tool -ErrorAction SilentlyContinue
    if (-not $command) { "${tool}: not found"; continue }
    $version = if ($tool -eq 'az') { (& az version --query '\"azure-cli\"' -o tsv 2>$null) } else { (& $tool --version 2>$null | Select-Object -First 1) }
    "${tool}: $version ($($command.Source))"
}

Write-Step 'Azure login'
$account = Invoke-Az @('account', 'show', '-o', 'json')
if ($account.Ok) {
    $data = $account.Text | ConvertFrom-Json
    "signed in: yes; user type: $($data.user.type); subscription: $($data.name); tenant: $($data.tenantId)"
    $script:Summary.login = 'yes'
} else {
    "signed in: no; $(Get-Short $account.Text 300)"
    $script:Summary.login = 'no'
}

Write-Step 'Data-plane token (value never shown)'
$tokenResult = Invoke-Az @('account', 'get-access-token', '--resource', 'https://cognitiveservices.azure.com', '-o', 'json')
if ($tokenResult.Ok) {
    $tokenData = $tokenResult.Text | ConvertFrom-Json
    $script:Token = $tokenData.accessToken
    $expires = [DateTimeOffset]::FromUnixTimeSeconds([long]$tokenData.expires_on)
    "token: ok; length $($script:Token.Length); expires in $([int]($expires - [DateTimeOffset]::UtcNow).TotalMinutes) min"
    $script:Summary.token = 'ok'
} else {
    "token: failed; $(Get-Short $tokenResult.Text 300)"
    $script:Summary.token = 'failed'
}

Write-Step 'Management read (az cognitiveservices)'
$found = $null
$accounts = Invoke-Az @('cognitiveservices', 'account', 'list', '-o', 'json')
if ($accounts.Ok) {
    $found = @($accounts.Text | ConvertFrom-Json) | Where-Object { $_.name -ieq $resourceName } | Select-Object -First 1
    if (-not $found) {
        "resource not in current subscription; searching other subscriptions (max 20)"
        $subscriptions = Invoke-Az @('account', 'list', '--query', '[].id', '-o', 'tsv')
        foreach ($subscription in @($subscriptions.Text -split "`n" | Where-Object { $_ } | Select-Object -First 20)) {
            $list = Invoke-Az @('cognitiveservices', 'account', 'list', '--subscription', $subscription.Trim(), '-o', 'json')
            if (-not $list.Ok) { continue }
            $found = @($list.Text | ConvertFrom-Json) | Where-Object { $_.name -ieq $resourceName } | Select-Object -First 1
            if ($found) { break }
        }
    }
} else {
    "account list: failed; $(Get-Short $accounts.Text 300)"
}
$managementNames = @()
if ($found) {
    "resource: found; kind $($found.kind); group $($found.resourceGroup)"
    $subscriptionId = ($found.id -split '/')[2]
    $deployments = Invoke-Az @('cognitiveservices', 'account', 'deployment', 'list', '-g', $found.resourceGroup, '-n', $found.name, '--subscription', $subscriptionId, '-o', 'json')
    if ($deployments.Ok) {
        foreach ($deployment in @($deployments.Text | ConvertFrom-Json)) {
            "  deployment '$($deployment.name)' -> model $($deployment.properties.model.name) $($deployment.properties.model.version) (sku $($deployment.sku.name), capacity $($deployment.sku.capacity))"
            $managementNames += $deployment.name
        }
        $script:Summary.management = "ok ($($managementNames.Count) deployments)"
    } else {
        "deployment list: failed; $(Get-Short $deployments.Text 300)"
        $script:Summary.management = 'deployment list failed'
    }
} else {
    "resource: not found"
    if (-not $script:Summary.Contains('management')) { $script:Summary.management = 'resource not visible' }
}

Write-Step 'Endpoint read (data plane)'
$endpointNames = @()
if ($script:Token) {
    $bearer = @{ Authorization = "Bearer $($script:Token)" }
    $legacy = Invoke-Probe GET "$base/openai/deployments?api-version=2022-12-01" $bearer $null
    "GET /openai/deployments (2022-12-01): $($legacy.Status)"
    if ($legacy.Status -eq 200) {
        foreach ($item in @(($legacy.Content | ConvertFrom-Json).data)) {
            "  deployment '$($item.id)' -> model $($item.model)"
            $endpointNames += $item.id
        }
    } else { "  $(Get-ErrorText $legacy.Content)" }
    $models = Invoke-Probe GET "$base/openai/v1/models" $bearer $null
    "GET /openai/v1/models: $($models.Status)"
    if ($models.Status -eq 200) {
        $ids = @(($models.Content | ConvertFrom-Json).data | ForEach-Object { $_.id })
        "  $($ids.Count) model ids; first 15: $(($ids | Select-Object -First 15) -join ', ')"
    } else { "  $(Get-ErrorText $models.Content)" }
    $script:Summary.endpoint = if ($endpointNames.Count) { "ok ($($endpointNames.Count) deployments)" } else { "failed ($($legacy.Status))" }
} else {
    'skipped: no token'
    $script:Summary.endpoint = 'skipped'
}

$allNames = @($managementNames + $endpointNames | Select-Object -Unique)
if (-not $GptDeployment) { $GptDeployment = $allNames | Where-Object { $_ -match '^gpt' } | Select-Object -First 1 }
if (-not $ClaudeDeployment) { $ClaudeDeployment = $allNames | Where-Object { $_ -match '^claude' } | Select-Object -First 1 }

Write-Step 'Inference auth styles (tiny requests)'
"gpt deployment: $(if ($GptDeployment) { $GptDeployment } else { 'none (pass -GptDeployment)' })"
"claude deployment: $(if ($ClaudeDeployment) { $ClaudeDeployment } else { 'none (pass -ClaudeDeployment)' })"
if ($script:Token) {
    if ($GptDeployment) {
        $body = @{ model = $GptDeployment; input = 'Reply with OK'; max_output_tokens = 16 }
        $result = Invoke-Probe POST "$base/openai/v1/responses" @{ Authorization = "Bearer $($script:Token)" } $body
        "v1 responses, Authorization Bearer (codex auth command, copilot type openai): $($result.Status) $(if ($result.Status -ne 200) { Get-ErrorText $result.Content })"
        $result = Invoke-Probe POST "$base/openai/v1/responses" @{ 'api-key' = $script:Token } $body
        "v1 responses, api-key header (copilot type azure + key command): $($result.Status) $(if ($result.Status -ne 200) { Get-ErrorText $result.Content })"
        $result = Invoke-Probe POST "$base/openai/responses?api-version=$ApiVersion" @{ Authorization = "Bearer $($script:Token)" } $body
        "responses api-version $ApiVersion, Bearer (your current copilot script): $($result.Status) $(if ($result.Status -ne 200) { Get-ErrorText $result.Content })"
    }
    if ($ClaudeDeployment) {
        $body = @{ model = $ClaudeDeployment; max_tokens = 8; messages = @(@{ role = 'user'; content = 'Reply with OK' }) }
        $result = Invoke-Probe POST "$base/anthropic/v1/messages" @{ Authorization = "Bearer $($script:Token)"; 'anthropic-version' = '2023-06-01' } $body
        "anthropic messages, Authorization Bearer: $($result.Status) $(if ($result.Status -ne 200) { Get-ErrorText $result.Content })"
        $result = Invoke-Probe POST "$base/anthropic/v1/messages" @{ 'x-api-key' = $script:Token; 'anthropic-version' = '2023-06-01' } $body
        "anthropic messages, x-api-key header (copilot type anthropic + key command): $($result.Status) $(if ($result.Status -ne 200) { Get-ErrorText $result.Content })"
    }
} else {
    'skipped: no token'
}

if ($Ping) {
    Write-Step 'CLI pings (temporary homes, deleted afterwards)'
    $work = Join-Path ([System.IO.Path]::GetTempPath()) ('ps-ai-probe-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    try {
        $azPath = (Get-Command az -ErrorAction SilentlyContinue).Source
        $tokenCommand = 'az account get-access-token --resource https://cognitiveservices.azure.com --query accessToken -o tsv'
        if ((Get-Command claude -ErrorAction SilentlyContinue) -and $ClaudeDeployment) {
            $environment = @{ CLAUDE_CODE_USE_FOUNDRY = '1'; ANTHROPIC_FOUNDRY_BASE_URL = "$base/anthropic"; ANTHROPIC_MODEL = $ClaudeDeployment }
            "claude (Foundry env, own Azure auth): $(Invoke-Cli (Get-Command claude).Source @('-p', 'Reply with OK', '--model', $ClaudeDeployment) $environment $work)"
            $environment.ANTHROPIC_DEFAULT_SONNET_MODEL = $ClaudeDeployment
            "claude (alias sonnet -> $ClaudeDeployment): $(Invoke-Cli (Get-Command claude).Source @('-p', 'Reply with OK', '--model', 'sonnet') $environment $work)"
        } else { 'claude: skipped' }
        if ((Get-Command codex -ErrorAction SilentlyContinue) -and $GptDeployment -and $azPath) {
            $codexHome = Join-Path $work 'codex-home'
            New-Item -ItemType Directory -Path $codexHome -Force | Out-Null
            $toml = @(
                "model = `"$GptDeployment`"",
                'model_provider = "foundry"',
                '[model_providers.foundry]',
                'name = "Foundry"',
                "base_url = `"$base/openai/v1`"",
                'wire_api = "responses"',
                '[model_providers.foundry.auth]',
                "command = '$azPath'",
                'args = ["account", "get-access-token", "--resource", "https://cognitiveservices.azure.com", "--query", "accessToken", "-o", "tsv"]',
                'timeout_ms = 30000',
                'refresh_interval_ms = 1800000'
            ) -join "`n"
            [System.IO.File]::WriteAllText((Join-Path $codexHome 'config.toml'), $toml + "`n")
            "codex (auth command): $(Invoke-Cli (Get-Command codex).Source @('exec', '--skip-git-repo-check', 'Reply with OK') @{ CODEX_HOME = $codexHome } $work)"
        } else { 'codex: skipped' }
        if (Get-Command copilot -ErrorAction SilentlyContinue) {
            $copilotHome = Join-Path $work 'copilot-home'
            New-Item -ItemType Directory -Path $copilotHome -Force | Out-Null
            if ($GptDeployment) {
                $environment = @{ COPILOT_HOME = $copilotHome; COPILOT_PROVIDER_TYPE = 'openai'; COPILOT_PROVIDER_BASE_URL = "$base/openai/v1";
                    COPILOT_PROVIDER_API_KEY_COMMAND = $tokenCommand; COPILOT_PROVIDER_WIRE_API = 'responses'; COPILOT_MODEL = $GptDeployment }
                "copilot gpt (type openai + key command): $(Invoke-Cli (Get-Command copilot).Source @('-p', 'Reply with OK') $environment $work)"
            }
            if ($ClaudeDeployment) {
                $environment = @{ COPILOT_HOME = $copilotHome; COPILOT_PROVIDER_TYPE = 'anthropic'; COPILOT_PROVIDER_BASE_URL = "$base/anthropic";
                    COPILOT_PROVIDER_API_KEY_COMMAND = $tokenCommand; COPILOT_MODEL = $ClaudeDeployment }
                "copilot claude (type anthropic + key command): $(Invoke-Cli (Get-Command copilot).Source @('-p', 'Reply with OK') $environment $work)"
                if ($script:Token) {
                    $environment.Remove('COPILOT_PROVIDER_API_KEY_COMMAND')
                    $environment.COPILOT_PROVIDER_BEARER_TOKEN = $script:Token
                    "copilot claude (type anthropic + fixed bearer token): $(Invoke-Cli (Get-Command copilot).Source @('-p', 'Reply with OK') $environment $work)"
                }
            }
        } else { 'copilot: skipped' }
    } finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Step 'Summary'
foreach ($key in $script:Summary.Keys) { "${key}: $($script:Summary[$key])" }
$script:Token = $null
