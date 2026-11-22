$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/workspace.ps1')
. (Join-Path $PSScriptRoot 'lib/installer.ps1')
$scratch = Join-Path (Get-TestTempPath) 'fixtures'
$allowed = Join-Path $scratch 'allowed'
$outside = Join-Path $scratch 'allowed-sibling'
New-Item -ItemType Directory -Path $allowed, $outside -Force | Out-Null
try {
    $child = Join-Path $allowed 'child'
    New-Item -ItemType Directory -Path $child -Force | Out-Null
    Assert-Throws { Remove-TestFolder -Path $allowed -AllowedParent $allowed } 'Cleanup refuses the allowed parent itself'
    Assert-Throws { Remove-TestFolder -Path $outside -AllowedParent $allowed } 'Cleanup refuses a sibling sharing the prefix'
    Remove-TestFolder -Path $child -AllowedParent $allowed
    Remove-TestFolder -Path $child -AllowedParent $allowed
    Assert-True (-not (Test-Path $child)) 'Cleanup removes a child and tolerates a repeat'
    $link = Join-Path $allowed 'outside-link'
    New-Item -ItemType $(if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }) -Path $link -Target (Resolve-LegionDirectoryPath $outside) | Out-Null
    try { Assert-Throws { Remove-TestFolder -Path $link -AllowedParent $allowed } 'Cleanup refuses links outside the allowed parent' }
    finally { Remove-Item -LiteralPath $link -Force }

    $target = Join-Path $scratch 'command with quote'' and space.ps1'
    '$args -join "|"; exit 23' | Set-Content -LiteralPath $target
    $command = New-TestCommandStub -Folder $allowed -Name fixture -Script $target
    $lines = @(& $command 'two words' 'semi;literal')
    Assert-Equal 23 $LASTEXITCODE 'Shared command stub forwards the exit code'
    Assert-Equal 'two words|semi;literal' ($lines -join '') 'Shared command stub forwards literal arguments'
    $settings = Write-TestPersonalisation -HomeRoot $allowed -Agents @(@{ id = 'fixture'; tool = 'codex'; configDir = '~/.codex' })
    $data = Get-Content $settings -Raw | ConvertFrom-Json
    Assert-Equal 1 $data.schemaVersion 'Shared settings include the schema version'
    Assert-Equal 'fixture' $data.agents[0].id 'Shared settings preserve agents'
    Assert-Equal 0 $data.channels.Count 'Shared settings default to no channels'
    $installFolder = New-InstallTestFolder 'fixture-home'
    try { Assert-True (Test-LegionPathUnder -Path $installFolder -Root (Get-TestTempPath)) 'Installer fixture homes live under the runner temp' }
    finally { Remove-InstallTestFolder $installFolder }
    Assert-True (-not (Test-Path $installFolder)) 'The installer fixture home is removed'
} finally {
    Remove-TestFolder -Path $scratch -AllowedParent (Get-TestTempPath)
}
