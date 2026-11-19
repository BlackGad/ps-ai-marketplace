param(
    [string]$Agent,
    [string]$HomeRoot = $HOME,
    [switch]$NoRun
)

$toolArguments = @($args)
. (Join-Path $PSScriptRoot 'lib/foundry.ps1')

function Get-FoundryLaunch {
    param($Agent, [string]$HomeRoot, $Token)
    $folder = [string]$Agent.configDir
    if ($folder.StartsWith('~/')) { $folder = Join-Path $HomeRoot $folder.Substring(2) }
    $launch = @{ Set = @{}; Clear = [string[]]@(); ProvidersFile = $null; ProvidersJson = $null; Notice = $null }
    switch ($Agent.tool) {
        claude {
            $launch.Set = @{
                CLAUDE_CONFIG_DIR = $folder
                CLAUDE_CODE_USE_FOUNDRY = '1'
                ANTHROPIC_FOUNDRY_BASE_URL = $Agent.provider.endpoint + '/anthropic'
                ANTHROPIC_MODEL = $Agent.provider.default
            }
            foreach ($deployment in $Agent.provider.deployments) {
                if ($deployment.alias) { $launch.Set['ANTHROPIC_DEFAULT_' + $deployment.alias.ToUpperInvariant() + '_MODEL'] = $deployment.name }
            }
            $launch.Clear = [string[]]@(
                'ANTHROPIC_FOUNDRY_RESOURCE', 'ANTHROPIC_FOUNDRY_API_KEY', 'ANTHROPIC_FOUNDRY_AUTH_TOKEN', 'ANTHROPIC_SMALL_FAST_MODEL',
                'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_ANTHROPIC_AWS',
                'CLAUDE_CODE_USE_ANTHROPIC_GOOGLE_CLOUD', 'CLAUDE_CODE_USE_MANTLE', 'CLAUDE_CODE_USE_GATEWAY'
            )
        }
        copilot {
            if (-not $Token) { $Token = Get-FoundryToken }
            $launch.ProvidersFile = Join-Path $HomeRoot ('.agents/temp/copilot-providers-' + [guid]::NewGuid() + '.json')
            $launch.Set = @{ COPILOT_HOME = $folder; COPILOT_PROVIDERS_CONFIG = $launch.ProvidersFile }
            $launch.ProvidersJson = @{
                providers = @(@{
                    name = 'ps-ai-foundry'; type = 'anthropic'; baseUrl = $Agent.provider.endpoint + '/anthropic'
                    bearerToken = $Token.Token; headers = @{ 'anthropic-version' = '2023-06-01' }
                })
                models = @($Agent.provider.deployments | ForEach-Object {
                    $model = if ($_.model) { $_.model } else { $_.name }
                    @{ id = $_.name; provider = 'ps-ai-foundry'; modelId = $model; wireModel = $_.name }
                })
            } | ConvertTo-Json -Depth 100
            $expiry = $Token.ExpiresOn.ToLocalTime().ToString('HH:mm')
            $launch.Notice = "token valid until $expiry; after that restart with: $($Agent.id) --resume"
        }
        codex { $launch.Set = @{ CODEX_HOME = $folder } }
        default { throw "unknown tool '$($Agent.tool)'" }
    }
    return $launch
}

function Get-FoundryToolCommand {
    param([string]$Tool, [string]$HomeRoot)
    $bin = [IO.Path]::GetFullPath((Join-Path $HomeRoot '.agents/bin'))
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    foreach ($command in @(Get-Command $Tool -CommandType Application,ExternalScript -All -ErrorAction SilentlyContinue)) {
        $folder = [IO.Path]::GetFullPath((Split-Path $command.Source -Parent))
        if (-not $folder.Equals($bin, $comparison)) { return $command.Source }
    }
    throw "$Tool is not installed; run ps-ai-install-tool.ps1 -Tool $Tool"
}

function Invoke-FoundryTool {
    param([string]$Command, [string[]]$Arguments, $Launch)
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.UseShellExecute = $false
    $extension = [IO.Path]::GetExtension($Command)
    if ($extension -ieq '.ps1') {
        $start.FileName = (Get-Process -Id $PID).Path
        foreach ($arg in @('-NoProfile', '-File', $Command) + $Arguments) { $start.ArgumentList.Add($arg) }
    } elseif ($IsWindows -and $extension -in @('.cmd', '.bat')) {
        # Let PowerShell invoke batch shims, quoting every value as a literal.
        $start.FileName = (Get-Process -Id $PID).Path
        $parts = @($Command) + $Arguments | ForEach-Object { "'" + $_.Replace("'", "''") + "'" }
        $script = '& ' + ($parts -join ' ') + '; exit $LASTEXITCODE'
        $start.ArgumentList.Add('-NoProfile')
        $start.ArgumentList.Add('-EncodedCommand')
        $start.ArgumentList.Add([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script)))
    } else {
        $start.FileName = $Command
        foreach ($arg in $Arguments) { $start.ArgumentList.Add($arg) }
    }
    foreach ($name in $Launch.Clear) { $null = $start.Environment.Remove($name) }
    foreach ($name in $Launch.Set.Keys) { $start.Environment[$name] = [string]$Launch.Set[$name] }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        $null = $process.Start()
        $process.WaitForExit()
        return $process.ExitCode
    } finally { $process.Dispose() }
}

if (-not $NoRun) {
    $launch = $null
    try {
        $file = Join-Path $HomeRoot '.agents/configuration/ps-ai-personalisation.json'
        $data = [IO.File]::ReadAllText($file).TrimStart([char]0xFEFF) | ConvertFrom-Json -Depth 100 -ErrorAction Stop
        $selected = @($data.agents | Where-Object { $_.id -ceq $Agent })[0]
        if (-not $selected) { throw "unknown account '$Agent'" }
        if ($selected.provider.kind -cne 'foundry') { throw "account '$Agent' is not a Foundry agent" }
        $command = Get-FoundryToolCommand -Tool $selected.tool -HomeRoot $HomeRoot
        $check = Test-FoundryToken -Login
        if (-not $check.Ok) { throw $check.Error }
        $launch = Get-FoundryLaunch -Agent $selected -HomeRoot $HomeRoot
        if ($launch.ProvidersFile) {
            New-Item -ItemType Directory -Path (Split-Path $launch.ProvidersFile -Parent) -Force | Out-Null
            [IO.File]::WriteAllText($launch.ProvidersFile, $launch.ProvidersJson, [Text.UTF8Encoding]::new($false))
        }
        if ($launch.Notice) { Write-Output $launch.Notice }
        $exitCode = Invoke-FoundryTool -Command $command -Arguments $toolArguments -Launch $launch
    } catch {
        [Console]::Error.WriteLine($_.Exception.Message)
        $exitCode = 1
    } finally {
        if ($launch.ProvidersFile -and (Test-Path -LiteralPath $launch.ProvidersFile)) {
            Remove-Item -LiteralPath $launch.ProvidersFile -Force
        }
    }
    exit $exitCode
}
