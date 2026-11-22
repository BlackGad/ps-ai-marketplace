$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'plugins/legion/bin/lib/settings.ps1')
$scratch = Join-Path $root ('.agents/temp/lean-validate-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $scratch -Force | Out-Null
function Check-Owner($Data) {
    $path = Join-Path $scratch 'owner.json'
    $Data | ConvertTo-Json -Depth 100 | Set-Content $path
    @(Invoke-LegionValidation personalisation $path)
}
# MinimalOwnerAndProject
Assert-Equal 0 @(Check-Owner @{schemaVersion=1;agents=@();channels=@()}).Count 'Empty lean owner validates'
foreach ($key in @('schemaVersion','agents','channels')) {
    $data = @{schemaVersion=1;agents=@();channels=@()}; $data.Remove($key)
    Assert-True (@(Check-Owner $data).Count -gt 0) "Missing $key fails"
}
$path = Join-Path $scratch 'project.json'
'{"schemaVersion":1}' | Set-Content $path
Assert-Equal 0 @(Invoke-LegionValidation project $path).Count 'Minimal project validates'
# NestedUnknownFieldDiagnostic
foreach ($extra in @(
    '{"extra":true,"schemaVersion":1,"agents":[],"channels":[]}',
    '{"schemaVersion":1,"agents":[{"id":"claude-a","tool":"claude","configDir":"~/account","extra":true}],"channels":[]}',
    '{"schemaVersion":1,"agents":[],"channels":[{"id":"main","kind":"telegram","target":"123","accounts":["claude-a"],"extra":true}]}',
    '{"schemaVersion":1,"agents":[{"id":"claude-a","tool":"claude","configDir":"~/account","provider":{"kind":"foundry","endpoint":"https://example.invalid","default":"a","deployments":[{"name":"a"}],"extra":true}}],"channels":[]}',
    '{"schemaVersion":1,"agents":[{"id":"claude-a","tool":"claude","configDir":"~/account","provider":{"kind":"foundry","endpoint":"https://example.invalid","default":"a","deployments":[{"name":"a","extra":true}]}}],"channels":[]}'
)) {
    Assert-True ((Check-Owner ($extra | ConvertFrom-Json)) -match 'run legion setup to update your settings') 'Unknown fields name setup remedy'
}
# ChannelBindingValidation
$data = @{schemaVersion=1;agents=@(@{id='claude-a';tool='claude';configDir='~/a'});channels=@(@{id='main';kind='telegram';target='123';accounts=@('claude-a')})}
Assert-Equal 0 @(Check-Owner $data).Count 'Supported binding validates'
foreach ($bindings in @(@(),@('missing'),@('claude-a','claude-a'))) {
    $data.channels[0].accounts = $bindings
    Assert-True (@(Check-Owner $data).Count -gt 0) 'Empty unknown duplicate bindings fail'
}
$data.channels[0].accounts=@('claude-a')
$data.agents[0].tool='codex'
Assert-True (@(Check-Owner $data).Count -gt 0) 'Unsupported bound tool fails'
$data.agents[0].tool='claude'
$data.channels[0].Remove('accounts')
Assert-True (@(Check-Owner $data).Count -gt 0) 'Missing bindings fail'
$data.channels[0].accounts=@('claude-a')
foreach ($change in @(
    { $data.channels[0].target='' },
    { $data.channels[0].kind='unknown-kind' },
    { $data.channels[0].id='Invalid' }
)) {
    & $change
    Assert-True (@(Check-Owner $data).Count -gt 0) 'Invalid channel identity or target fails'
}
