$ErrorActionPreference='Stop'
$Repo=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Assert.ps1')
& {
. (Join-Path $Repo 'install.ps1') -NoRun
$script:installCatalog = Get-Content (Join-Path $Repo 'tests/fixtures/install/catalog.json') -Raw | ConvertFrom-Json
# RootBootstrapUsesLatestZipRecipe: change id, source, pattern and layout together.
$script:installCatalog.bootstrap.windows.wingetId = 'Example.PowerShell'
$script:installCatalog.bootstrap.windows.portableCommand = 'bin/shell.exe'
$script:installCatalog.bootstrap.windows.download.zip.metadataUrl = 'https://fixture.test/latest'
$script:installCatalog.bootstrap.windows.download.zip.assetPattern = '^Shell-[\d.]+-x64\.zip$'
$script:installCatalog.bootstrap.windows.download.zip.pathFolder = 'bin'
& {
    $state = @{ Command='' }
    function winget { $state.Command=(@('winget') + $args) -join '|'; $global:LASTEXITCODE=0 }
    Assert-Equal 0 (Invoke-InstallWinget) 'Catalog winget command succeeds'
    Assert-Equal 'winget|install|--id|Example.PowerShell|-e' $state.Command 'Winget id is catalog data'
}
$sandbox = Join-Path $Repo ('.agents/temp/restructure/remote-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
$savedPath = $env:PATH
$fixturePwshExe = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
$windowsPowerShell = Get-Command powershell.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$state = @{ Present=$false; Winget=$false; WingetExit=5; Calls=0; Downloads=0; Digest=('0' * 64); UserPath='fixture-existing'; Writes=0; Prompts=0; Answer='n' }
$downloaded = [Collections.Generic.List[string]]::new()
function Get-InstallHome { $sandbox }
function Get-InstallPowerShellCommand {
    if ($state.Present) { return @{ Source='fixture-pwsh' } }
    $portable = Join-Path $sandbox '.legion/tools/pwsh/bin/shell.exe'
    if (Test-Path -LiteralPath $portable) { return @{ Source=$portable } }
}
function Test-InstallCommandAvailable { param($Name) $Name -eq 'winget' -and $state.Winget }
function Invoke-InstallWinget { $state.Calls++; return $state.WingetExit }
function Get-InstallUserPath { $state.UserPath }
function Set-InstallUserPath { param($Path) $state.Writes++; $state.UserPath = $Path }
function Read-Host { param($Prompt) $state.Prompts++; return $state.Answer }
function Invoke-InstallDownload {
    param($Url, $OutFile)
    $state.Downloads++
    $downloaded.Add($OutFile)
    if ($Url -eq 'https://fixture.test/latest') {
        @{ tag_name='v7.7.0'; assets=@(@{ name='Shell-7.7.0-x64.zip'; browser_download_url='https://fixture.test/pwsh.zip'; digest=$state.Digest }) } |
            ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutFile
    } elseif ($Url -eq 'https://fixture.test/pwsh.zip') { Copy-Item -LiteralPath $fixtureArchive -Destination $OutFile }
    else { throw "unexpected test download: $Url" }
}
try {
    $preview = @(& { $script:ready = Ensure-InstallPowerShell -OnWindows $true -DryRun } 6>&1) -join "`n"
    Assert-True ($preview.Contains('winget install --id Example.PowerShell -e')) 'Missing pwsh dry run shows winget'
    Assert-True ($preview.Contains('SHA-256')) 'Missing pwsh dry run shows ZIP option'
    Assert-Equal 0 $state.Downloads 'Dry run has no network'
    Assert-Equal 0 $state.Calls 'Dry run never runs winget'
    Assert-Equal 0 $state.Prompts 'Dry run never prompts'
    Assert-Equal 0 $state.Writes 'Dry run never writes user PATH'
    Assert-Equal $savedPath $env:PATH 'Dry run preserves process PATH'
    $state.Present = $true
    $skip = @(& { $script:ready = Ensure-InstallPowerShell -OnWindows $true } 6>&1) -join "`n"
    Assert-True $script:ready 'Present pwsh is ready'
    Assert-True ($skip.Contains('skip: PowerShell 7 (already done)')) 'Present pwsh skips'
    Assert-Equal 0 $state.Downloads 'Present pwsh never downloads'
    $state.Present = $false
    $null = & { $script:ready = Ensure-InstallPowerShell -OnWindows $true } 6>&1
    Assert-True (-not $script:ready) 'Declined install stops'
    Assert-Equal 0 $state.Downloads 'Declined install never downloads'
    $docs = @(& { $script:ready = Ensure-InstallPowerShell -OnWindows $false -Yes } 6>&1) -join "`n"
    Assert-True (-not $script:ready) 'Non-Windows missing pwsh stops'
    Assert-True ($docs.Contains('https://learn.microsoft.com/powershell/scripting/install/')) 'Non-Windows gives official install link'
    Assert-Equal 0 $state.Downloads 'Non-Windows never downloads'

    $archiveFolder = Join-Path $sandbox 'archive'
    New-Item -ItemType Directory -Path (Join-Path $archiveFolder 'bin') -Force | Out-Null
    'inert fixture, never execute' | Set-Content -LiteralPath (Join-Path $archiveFolder 'bin/shell.exe')
    $fixtureArchive = Join-Path $sandbox 'fixture.zip'
    Compress-Archive -Path (Join-Path $archiveFolder '*') -DestinationPath $fixtureArchive
    $state.Digest = 'sha256:' + ('0' * 64)
    $failure = ''
    try { $null = Ensure-InstallPowerShell -OnWindows $true -Yes } catch { $failure = $_.Exception.Message }
    Assert-True ($failure -match 'SHA-256.*mismatch') 'Digest mismatch stops installation'
    Assert-True (-not (Test-Path -LiteralPath $downloaded[$downloaded.Count - 1])) 'Digest mismatch deletes download'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $sandbox '.legion/tools/pwsh'))) 'Digest mismatch never unpacks'
    Assert-Equal 0 $state.Writes 'Digest mismatch never writes PATH'
    Assert-Equal $savedPath $env:PATH 'Digest mismatch preserves process PATH'
    $state.Digest = ''
    Assert-Throws { Ensure-InstallPowerShell -OnWindows $true -Yes | Out-Null } 'Missing digest stops installation'
    $state.Digest = 'sha256:' + (Get-FileHash -LiteralPath $fixtureArchive -Algorithm SHA256).Hash.ToLowerInvariant()
    $state.Winget = $true
    $null = & { $script:ready = Ensure-InstallPowerShell -OnWindows $true -Yes } 6>&1
    Assert-True $script:ready 'Failed winget falls back to verified ZIP'
    Assert-Equal 1 $state.Calls 'Winget tried once before ZIP'
    $portableFolder = Join-Path $sandbox '.legion/tools/pwsh/bin'
    Assert-True (Test-Path -LiteralPath (Join-Path $portableFolder 'shell.exe')) 'Verified ZIP unpacks per user'
    Assert-True ($state.UserPath.Contains($portableFolder)) 'ZIP adds user PATH'
    Assert-True ($env:PATH.Contains($portableFolder)) 'ZIP adds process PATH'
    Assert-Equal 1 $state.Writes 'ZIP writes user PATH once'
    $downloadCount = $state.Downloads
    $null = & { Ensure-InstallPowerShell -OnWindows $true -Yes } 6>&1
    Add-InstallPowerShellPath -Path $portableFolder
    Assert-Equal $downloadCount $state.Downloads 'Repeat ZIP installation never downloads'
    Assert-Equal 1 $state.Writes 'Repeat ZIP installation never duplicates user PATH'
    Assert-Equal 1 @($env:PATH -split [regex]::Escape([IO.Path]::PathSeparator) | Where-Object { $_ -eq $portableFolder }).Count 'Process PATH contains folder once'

    # Portable PATH repair retains explicit consent, including repeats and dry runs.
    $state.Answer='n'
    $beforeWrites=$state.Writes
    $state.UserPath='fixture-existing'
    $env:PATH=$savedPath
    $null=Ensure-InstallPowerShell -OnWindows $true
    Assert-Equal $beforeWrites $state.Writes 'Portable PATH stays unchanged after no'
    $state.Answer='y'
    $null=Ensure-InstallPowerShell -OnWindows $true
    Assert-Equal ($beforeWrites + 1) $state.Writes 'User PATH repaired only after yes'
    Assert-True ($env:PATH.Contains($portableFolder)) 'Portable PATH restored in this process after yes'
    $env:PATH=$savedPath
    $state.UserPath='fixture-existing'
    $null=Ensure-InstallPowerShell -OnWindows $true -DryRun
    Assert-Equal ($beforeWrites + 1) $state.Writes 'Dry run never repairs user PATH'
    Assert-Equal $savedPath $env:PATH 'Dry run never repairs portable PATH'
    $null=Ensure-InstallPowerShell -OnWindows $true -Yes
    Assert-Equal ($beforeWrites + 2) $state.Writes 'Yes repairs portable user PATH'
    Assert-True ($env:PATH.Contains($portableFolder)) 'Yes repairs portable process PATH'
    Write-Output 'PASS stub verified ZIP, fallback, repeats and portable PATH consent'
} finally {
    $env:PATH=$savedPath
    $allowed=[IO.Path]::GetFullPath((Join-Path $Repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
    if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe bootstrap fixture cleanup' }
    Remove-Item -LiteralPath $sandbox -Recurse -Force
}
}
