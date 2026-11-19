$repo = Split-Path $PSScriptRoot -Parent
& {
    $sandbox = Join-Path $repo ('.agents/temp/adopt-account-' + [guid]::NewGuid().ToString('N'))
    $file = Join-Path $sandbox '.agents/configuration/ps-ai-personalisation.json'
    $folder = Join-Path $sandbox 'existing account'
    New-Item -ItemType Directory -Path (Split-Path $file -Parent), $folder -Force | Out-Null
    @{schemaVersion=1;agents=@();channels=@()} |
        ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $file
    $settings = Join-Path $folder 'settings.json'
    '{"theme":"dark","custom":true}' | Set-Content -LiteralPath $settings
    $before = [IO.File]::ReadAllText($settings)
    $fake = Join-Path $sandbox 'fake-cli.ps1'
    'throw "No CLI or login may run during adoption"' | Set-Content -LiteralPath $fake
    $account = Join-Path $repo 'plugins/ps-ai/bin/ps-ai-account.ps1'
    try {
        $output = @(& $account -Action add -Tool claude -Id claude-existing -ConfigDir '~/existing account' -Command $fake -HomeRoot $sandbox)
        $data = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
        Assert-Equal $folder $data.agents[0].configDir 'Adopt records the supplied folder'
        Assert-Equal $before ([IO.File]::ReadAllText($settings)) 'Adopt preserves existing settings bytes'
        Assert-True (-not (Test-Path (Join-Path $sandbox '.agents/accounts/claude-existing'))) 'Adopt does not create an unused account folder'
        $wrapper = Get-Content (Join-Path $sandbox '.agents/bin/claude-existing') -Raw
        Assert-True ($wrapper.Contains($folder)) 'Adopted wrapper selects existing folder'
        Assert-True (($output -join "`n") -notmatch 'log in once') 'Adopt does not request a new login'
        if ($IsWindows) {
            Assert-True ((Get-Content (Join-Path $sandbox '.agents/bin/claude-existing.cmd') -Raw).Contains($folder)) 'Windows wrapper selects existing folder'
        }
        $beforeFile = [IO.File]::ReadAllText($file)
        $beforeWrapper = [IO.File]::ReadAllText((Join-Path $sandbox '.agents/bin/claude-existing'))
        $repeat = @(& $account -Action add -Tool claude -Id claude-existing -ConfigDir '~/existing account' -HomeRoot $sandbox)
        Assert-True (($repeat -join "`n") -match '^skip: .*\(already done\)') 'Repeat adoption is safe'
        Assert-Equal $beforeFile ([IO.File]::ReadAllText($file)) 'Repeat adoption keeps settings record bytes'
        Assert-Equal $beforeWrapper ([IO.File]::ReadAllText((Join-Path $sandbox '.agents/bin/claude-existing'))) 'Repeat adoption keeps wrapper bytes'
        Push-Location -LiteralPath $sandbox
        try {
            $null = & $account -Action add -Tool codex -Id codex-existing -ConfigDir './existing account' -Command $fake -HomeRoot $sandbox
            $data = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
            $relative = $data.agents | Where-Object id -EQ codex-existing
            Assert-Equal $folder $relative.configDir 'Relative adoption records a stable absolute path from the PowerShell location'
            Assert-True ((Get-Content (Join-Path $sandbox '.agents/bin/codex-existing') -Raw).Contains($folder)) 'Relative adoption wrapper uses the supplied existing folder'
            $repeat = @(& $account -Action add -Tool codex -Id codex-existing -ConfigDir './existing account' -HomeRoot $sandbox)
            Assert-True (($repeat -join "`n") -match '^skip: .*\(already done\)') 'Relative adoption repeats safely'
        } finally { Pop-Location }
        $beforeFile = [IO.File]::ReadAllText($file)
        Assert-Throws { & $account -Action add -Tool claude -Id claude-missing -ConfigDir '~/missing' -Command $fake -HomeRoot $sandbox } 'Adoption rejects a missing folder'
        Assert-Equal $beforeFile ([IO.File]::ReadAllText($file)) 'Failed adoption leaves records unchanged'
        Assert-Throws { & $account -Action add -Tool claude -Id claude-existing -ConfigDir $sandbox -Command $fake -HomeRoot $sandbox } 'Existing id cannot be silently redirected'
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
