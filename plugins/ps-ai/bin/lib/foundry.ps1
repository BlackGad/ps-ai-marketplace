. (Join-Path $PSScriptRoot 'tools.ps1')

function ConvertTo-FoundryEndpoint {
    param([string]$Url)
    $uri = $null
    if ($Url -notmatch '^https://' -or -not [uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri) -or -not $uri.Host -or $uri.UserInfo) {
        throw 'endpoint must start with https://'
    }
    return $uri.GetLeftPart([UriPartial]::Authority)
}

function Get-FoundryResourceName {
    param([string]$Endpoint)
    return ([uri](ConvertTo-FoundryEndpoint $Endpoint)).Host.Split('.')[0]
}

function Invoke-FoundryAz {
    param([string[]]$Arguments)
    $az = Get-Command az -CommandType Application,ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $az) { throw 'az is not installed; run ps-ai-install-tool.ps1 -Tool az' }
    $lines = @(& $az.Source @Arguments 2>&1)
    $code = $LASTEXITCODE
    $output = @($lines | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) -join "`n"
    $errorText = @($lines | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { $_.ToString() }) -join "`n"
    if (-not $errorText -and $code -ne 0) { $errorText = $output }
    return @{ ExitCode = $code; Output = $output; Error = $errorText }
}

function Get-FoundryToken {
    $result = Invoke-FoundryAz -Arguments @('account', 'get-access-token', '--resource', 'https://cognitiveservices.azure.com', '-o', 'json')
    if ($result.ExitCode -ne 0) { throw $result.Error }
    $data = $result.Output | ConvertFrom-Json -ErrorAction Stop
    if (-not $data.accessToken) { throw 'az returned no access token' }
    $expiry = if ($data.expires_on) { [DateTimeOffset]::FromUnixTimeSeconds([long]$data.expires_on) } else { [DateTimeOffset]$data.expiresOn }
    return @{ Token = [string]$data.accessToken; ExpiresOn = $expiry }
}

function Test-FoundryToken {
    param([switch]$Login)
    try { $null = Get-FoundryToken; return @{ Ok = $true; Error = '' } }
    catch { $message = $_.Exception.Message }
    if ($Login) {
        # az login is interactive: its browser or device-code prompt must reach the owner, never be captured.
        $az = Get-Command az -CommandType Application,ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($az) { & $az.Source login -o none | Out-Host }
        try { $null = Get-FoundryToken; return @{ Ok = $true; Error = '' } }
        catch { $message = $_.Exception.Message }
    }
    return @{ Ok = $false; Error = $message }
}

function Get-FoundryDeployments {
    param([string]$Endpoint, [string]$Tool)
    $descriptor = Get-PsAiTool -Tool $Tool
    if ($null -eq $descriptor.foundry) { throw "tool '$Tool' does not support Foundry" }
    $prefix = $descriptor.foundry.deploymentPrefix
    $resourceName = Get-FoundryResourceName -Endpoint $Endpoint
    $errors = [System.Collections.Generic.List[string]]::new()
    $subscriptions = [System.Collections.Generic.List[string]]::new()
    $subscriptions.Add('')
    for ($index = 0; $index -lt $subscriptions.Count; $index++) {
        $subscriptionArgs = if ($subscriptions[$index]) { @('--subscription', $subscriptions[$index]) } else { @() }
        $result = Invoke-FoundryAz -Arguments (@('cognitiveservices', 'account', 'list', '-o', 'json') + $subscriptionArgs)
        if ($result.ExitCode -ne 0) { $errors.Add($result.Error) }
        else {
            try {
                $accounts = @($result.Output | ConvertFrom-Json -ErrorAction Stop)
                $account = @($accounts | Where-Object { $_.name -eq $resourceName })[0]
                if ($account) {
                    $result = Invoke-FoundryAz -Arguments (@('cognitiveservices', 'account', 'deployment', 'list', '--name', $account.name, '--resource-group', $account.resourceGroup, '-o', 'json') + $subscriptionArgs)
                    if ($result.ExitCode -ne 0) { throw $result.Error }
                    $items = @($result.Output | ConvertFrom-Json -ErrorAction Stop)
                    $deployments = @($items | Where-Object { ([string]$_.properties.model.name).StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object {
                        @{ name = [string]$_.name; model = [string]$_.properties.model.name }
                    })
                    return @{ Source = 'management'; Error = ''; Deployments = $deployments }
                }
            } catch { $errors.Add($_.Exception.Message) }
        }
        if ($index -eq 0) {
            $result = Invoke-FoundryAz -Arguments @('account', 'list', '--query', '[].id', '-o', 'tsv')
            if ($result.ExitCode -ne 0) { $errors.Add($result.Error) }
            else {
                foreach ($id in ($result.Output -split '\r?\n')) { if ($id.Trim()) { $subscriptions.Add($id.Trim()) } }
            }
        }
    }
    $message = if ($errors.Count) { $errors -join "`n" } else { 'No deployments found; https://ai.azure.com → your project → Models + endpoints' }
    return @{ Source = 'none'; Error = $message; Deployments = @() }
}
