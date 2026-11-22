$root = Split-Path $PSScriptRoot -Parent
$script = Join-Path $root 'plugins/legion/bin/legion-channel.ps1'
Assert-True (Test-Path $script) 'Channel script exists'

$homeRoot = Join-Path $root ('.agents/temp/channel-binding-' + [guid]::NewGuid().ToString('N'))
$file = Join-Path $homeRoot '.legion/configuration/personalisation.json'
New-Item -ItemType Directory (Split-Path $file) -Force | Out-Null
$claudeDir = Join-Path $homeRoot 'claude1-config'
New-Item -ItemType Directory $claudeDir -Force | Out-Null
$settings = @{
    schemaVersion = 1
    agents = @(
        @{ id = 'claude1'; tool = 'claude'; configDir = $claudeDir },
        @{ id = 'codex1'; tool = 'codex'; configDir = (Join-Path $homeRoot 'codex1-config') }
    )
    channels = @()
}
$settings | ConvertTo-Json -Depth 10 | Set-Content $file

function Invoke-Channel { & $script @args -HomeRoot $homeRoot }

# add, then repeat
Invoke-Channel -Action add -Id my-telegram -Kind telegram -Target 123 -Accounts claude1 | Out-Null
$saved = Get-Content $file -Raw | ConvertFrom-Json
Assert-Equal 'my-telegram' $saved.channels[0].id 'Channel saved'
Assert-Equal 'claude1' ($saved.channels[0].accounts -join ',') 'Account bound'
$before = Get-Content $file -Raw
Assert-Equal 'skip: channel my-telegram (already done)' (Invoke-Channel -Action add -Id my-telegram -Kind telegram -Target 123 -Accounts claude1) 'Repeat add skips'
Assert-Equal $before (Get-Content $file -Raw) 'Repeat add changes nothing'

# conflicting add
try { Invoke-Channel -Action add -Id my-telegram -Kind telegram -Target 999 -Accounts claude1; throw 'Expected conflict' }
catch { Assert-Equal 'channel my-telegram exists with other values; remove it first' $_.Exception.Message 'Conflict message' }
Assert-Equal $before (Get-Content $file -Raw) 'Conflict changes nothing'

# unknown account, unsupported tool
Assert-Throws { Invoke-Channel -Action add -Id other -Kind telegram -Target 1 -Accounts nobody } 'Unknown account'
Assert-Throws { Invoke-Channel -Action add -Id other -Kind telegram -Target 1 -Accounts codex1 } 'Unsupported tool'
Assert-Equal $before (Get-Content $file -Raw) 'Rejected adds change nothing'

# remove, then repeat
Invoke-Channel -Action remove -Id my-telegram | Out-Null
Assert-Equal 0 @((Get-Content $file -Raw | ConvertFrom-Json).channels).Count 'Channel removed'
Assert-Equal 'skip: channel remove my-telegram (already done)' (Invoke-Channel -Action remove -Id my-telegram) 'Repeat remove skips'

# check: bun and plugin folder, without starting any CLI
. $script -NoRun -HomeRoot $homeRoot
$savedPath = $env:PATH
$fakeBin = Join-Path $homeRoot 'bin'
New-Item -ItemType Directory -Path $fakeBin | Out-Null
$bun = Join-Path $fakeBin $(if ($IsWindows) { 'bun.cmd' } else { 'bun' })
[IO.File]::WriteAllText($bun, $(if ($IsWindows) { '@exit /b 99' } else { "#!/bin/sh`nexit 99`n" }))
if (-not $IsWindows) { [IO.File]::SetUnixFileMode($bun, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserExecute) }
try {
    $env:PATH = $fakeBin
    $lines = Get-ChannelCheck -Kind telegram -Accounts @('claude1', 'codex1') -HomeRoot $homeRoot
    Assert-Equal 'bun        found' $lines[0] 'bun found without executing it'
    Assert-Equal 'claude1    telegram plugin not found' $lines[1] 'Plugin folder missing'
    Assert-Equal 'codex1     not supported (telegram supports: claude)' $lines[2] 'Unsupported tool'
    New-Item -ItemType Directory (Join-Path $claudeDir 'plugins/cache/claude-plugins-official/telegram') -Force | Out-Null
    Remove-Item -LiteralPath $bun -Force
    $lines = Get-ChannelCheck -Kind telegram -Accounts @('claude1') -HomeRoot $homeRoot
    Assert-Equal 'bun        not found' $lines[0] 'bun missing'
    Assert-Equal 'claude1    telegram plugin found' $lines[1] 'Plugin folder present'
} finally { $env:PATH = $savedPath }
