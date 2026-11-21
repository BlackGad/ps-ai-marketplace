$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'plugins/legion/bin/legion-foundry.ps1') -NoRun
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('legion-tests/' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$saved = @{}
$aliases = @('OPUS', 'SONNET', 'HAIKU', 'FABLE')
$names = @('LEGION_FAKE_TOOL_LOG', 'LEGION_FAKE_TOOL_EXIT') + @($aliases | ForEach-Object { 'ANTHROPIC_DEFAULT_' + $_ + '_MODEL' })
foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
try {
    $env:LEGION_FAKE_TOOL_LOG = Join-Path $tempRoot 'child.json'
    $env:LEGION_FAKE_TOOL_EXIT = '0'
    foreach ($alias in $aliases) { [Environment]::SetEnvironmentVariable('ANTHROPIC_DEFAULT_' + $alias + '_MODEL', 'parent-' + $alias) }
    $claudeAgent = @{ tool = 'claude'; configDir = '~/.legion/agents/claude-dev'; provider = @{
        endpoint = 'https://res-a.cognitiveservices.azure.com'; default = 'claude-opus-x'
        deployments = @(@{ name = 'claude-opus-x'; alias = 'opus' })
    } }
    $launch = Get-FoundryLaunch -Agent $claudeAgent -HomeRoot $tempRoot
    $code = Invoke-FoundryTool -Command (Join-Path $PSScriptRoot 'fixtures/fake-tools/claude.ps1') -Arguments @() -Launch $launch
    Assert-Equal 0 $code 'Claude fake child succeeds'
    $child = Get-Content -LiteralPath $env:LEGION_FAKE_TOOL_LOG -Raw | ConvertFrom-Json
    Assert-Equal 'claude-opus-x' $child.environment.ANTHROPIC_DEFAULT_OPUS_MODEL 'Selected alias replaces inherited mapping'
    foreach ($alias in @('SONNET', 'HAIKU', 'FABLE')) {
        $name = 'ANTHROPIC_DEFAULT_' + $alias + '_MODEL'
        Assert-Equal $null $child.environment.$name "Unmapped $alias alias is absent in child"
        Assert-Equal ('parent-' + $alias) ([Environment]::GetEnvironmentVariable($name)) "Parent $alias alias remains unchanged"
    }
} finally {
    foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}

