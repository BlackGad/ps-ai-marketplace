$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Assert.ps1')
& {
    . (Join-Path $repo 'install.ps1') -NoRun
    $scratch = Join-Path $repo ('.agents/temp/stub-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $scratch -Force | Out-Null
    $savedPath = $env:PATH
    $savedOS = $env:OS
    try {
        $pwsh = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
        $archiveRoot = Join-Path $scratch 'archive/single-top/plugins/legion'
        New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
        Copy-Item (Join-Path $repo 'plugins/legion/tools.json') (Join-Path $archiveRoot 'tools.json')
        @'
param([string[]]$Tools, [string]$Source, [string]$ConfigDir, [switch]$DryRun, [switch]$Yes,
    [switch]$Update, [switch]$Uninstall, [switch]$Purge, [string]$Ref, [string]$HomeRoot)
if (-not $DryRun -and -not $Yes -and (Read-Host 'Install fixture plugin? [y/N]') -notmatch '^(y|yes)$') {
    'Nothing changed. Run again with -Yes to apply.'
    return
}
@{ Tools=$Tools; Source=$Source; ConfigDir=$ConfigDir; DryRun=[bool]$DryRun; Yes=[bool]$Yes;
    Update=[bool]$Update; Uninstall=[bool]$Uninstall; Purge=[bool]$Purge; Ref=$Ref;
    Major=$PSVersionTable.PSVersion.Major } | ConvertTo-Json | Set-Content (Join-Path $HomeRoot 'record.json')
if ($ConfigDir -eq 'exit 23') { exit 23 }
'fixture installer ran'
'@ | Set-Content (Join-Path $archiveRoot 'install.ps1')
        $zip = Join-Path $scratch 'fixture.zip'
        Compress-Archive -Path (Join-Path $scratch 'archive/single-top') -DestinationPath $zip
        $state = @{ Downloads=0; Url=''; Missing=$false; Answer='n'; Prompts=0 }
        function Get-InstallPowerShellCommand { if (-not $state.Missing) { @{Source=$pwsh} } }
        function Invoke-InstallArchiveDownload {
            param($Url, $OutFile)
            $state.Downloads++; $state.Url=$Url
            Assert-True ($OutFile.EndsWith('.zip')) 'Archive filename has zip extension'
            Copy-Item -LiteralPath $zip -Destination $OutFile
        }
        function Invoke-WebRequest { throw 'Network forbidden' }
        function Invoke-InstallWinget { throw 'Installing tools forbidden' }
        function Install-PowerShellZip { throw 'Installing tools forbidden' }
        function Read-Host { param($Prompt) $state.Prompts++; $state.Answer }
        function Set-InstallUserPath { throw 'Registry writes forbidden' }
        foreach ($branch in @('stable','main')) {
            $parameters = @{Tools=@('claude','codex');Source='example/market';ConfigDir='folder with spaces';
                DryRun=[switch]::new($true);Yes=$true;Update=$true;Uninstall=$true;Purge=$true;HomeRoot=$scratch}
            if ($branch -eq 'main') { $parameters.Ref='main' }
            $null = Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot ''
            $record = Get-Content (Join-Path $scratch 'record.json') -Raw | ConvertFrom-Json
            Assert-Equal 'claude|codex' ($record.Tools -join '|') 'Typed tools array survives pwsh'
            Assert-Equal 'folder with spaces' $record.ConfigDir 'ConfigDir with spaces survives pwsh'
            Assert-True ($record.DryRun -and $record.Yes -and $record.Update -and $record.Uninstall -and $record.Purge) 'Typed switches survive pwsh'
            Assert-Equal 'example/market' $record.Source 'Source is data only'
            Assert-True ($record.Major -ge 7) 'Plugin runs under PowerShell 7'
            Assert-Equal "https://github.com/BlackGad/ps-legion-marketplace/archive/refs/heads/$branch.zip" $state.Url 'Code archive comes from fixed repository'
            Assert-Equal 0 @(Get-ChildItem (Join-Path $scratch '.legion/temp') -Directory -Filter 'install-*').Count 'Expanded archive cleaned up'
        }
        Write-Output 'PASS stub archive, typed arguments and BootstrapSourceIsData'
        $parameters.Update=[switch]::new($false)
        $null=Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot ''
        Assert-True (-not (Get-Content (Join-Path $scratch 'record.json') -Raw | ConvertFrom-Json).Update) 'False switch stays false across pwsh'
        $parameters.ConfigDir='exit 23'
        $null = Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot ''
        Assert-Equal 23 $script:bootstrapExitCode 'Non-zero installer exit code survives pwsh'
        $runner=Join-Path $scratch 'exit-entry.ps1'
        @'
param($Stub,$Archive,$Fixture)
$ErrorActionPreference='Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { $env:PSModulePath=Join-Path $PSHOME 'Modules' }
$script:fixtureZip=$Archive
function Invoke-InstallArchiveDownload { param($Url,$OutFile) Copy-Item -LiteralPath $script:fixtureZip -Destination $OutFile }
function Invoke-WebRequest { throw 'Network forbidden' }
& ([scriptblock]::Create((Get-Content -LiteralPath $Stub -Raw))) -HomeRoot $Fixture -Tools @('claude','codex') -ConfigDir 'exit 23' -DryRun
'@ | Set-Content -LiteralPath $runner
        $runtime=(Get-Process -Id $PID).Path
        $exitOutput=@(& $runtime -NoProfile -File $runner -Stub (Join-Path $repo 'install.ps1') -Archive $zip -Fixture $scratch 2>&1)
        Assert-Equal 23 $LASTEXITCODE "Root entry point returns installer exit code ($($exitOutput -join ' '))"
        Write-Output 'PASS stub preserves installer exit code'
        $parameters.ConfigDir='local checkout'
        $downloads = $state.Downloads
        $null = Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot (Join-Path $scratch 'archive/single-top')
        Assert-Equal $downloads $state.Downloads 'Local checkout skips archive download'
        Assert-True ((Get-Content (Join-Path $scratch 'record.json') -Raw | ConvertFrom-Json).Major -ge 7) 'Local checkout goes through pwsh'
        Write-Output 'PASS local checkout runs through pwsh'
        Remove-Item -LiteralPath (Join-Path $scratch 'record.json')
        $state.Missing=$true
        $env:OS='Windows_NT'
        $parameters = @{ HomeRoot=$scratch; DryRun=$true }
        $preview = @(& { Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot '' } 6>&1) -join "`n"
        Assert-True ($preview.Contains('winget install --id Microsoft.PowerShell -e')) 'Missing pwsh offers bootstrap'
        Assert-Equal 0 $state.Prompts 'Dry run never prompts'
        Assert-True (-not (Test-Path (Join-Path $scratch 'record.json'))) 'Missing pwsh dry run never starts installer'
        $parameters.DryRun=$false
        $declined = @(& { Invoke-InstallBootstrap -Parameters $parameters -CheckoutRoot '' } 6>&1) -join "`n"
        Assert-True ($declined.Contains('Nothing changed')) 'Decline reports no changes'
        Assert-Equal 0 $script:bootstrapExitCode 'Decline exits zero'
        Assert-True (-not (Test-Path (Join-Path $scratch 'record.json'))) 'Decline never starts installer'
        Write-Output 'PASS missing pwsh offers bootstrap and decline runs nothing'
        # Compose the bootstrap and plugin questions at the process boundary, with no real installation.
        function Get-InstallPowerShellCommand { if (-not $state.Missing) { @{Source='Invoke-FixturePowerShell'} } }
        function Test-InstallCommandAvailable { param($Name) $Name -eq 'winget' }
        function Invoke-InstallWinget { $state.Calls++; if ($state.ZipFallback) { 5 } else { $state.Missing=$false; 0 } }
        function Install-PowerShellZip { $state.Zip++; $state.Missing=$false }
        function Read-Host {
            param($Prompt)
            $state.Prompts++
            if (-not $state.Answers.Count) { throw 'Unexpected prompt' }
            $answer=$state.Answers[0]
            $state.Answers=@($state.Answers | Select-Object -Skip 1)
            $answer
        }
        function Invoke-FixturePowerShell {
            param([switch]$NoProfile,[scriptblock]$Command,[Alias('args')][object[]]$InputArguments)
            $path=$InputArguments[0]; $forwarded=$InputArguments[1]
            & $path @forwarded
            $global:LASTEXITCODE=0
        }
        foreach ($fallback in @($false,$true)) {
            $state.ZipFallback=$fallback
            $state.Missing=$true; $state.Calls=0; $state.Zip=0; $state.Prompts=0; $state.Answers=@('y','n')
            $declined=@(Invoke-InstallBootstrap -Parameters @{HomeRoot=$scratch} -CheckoutRoot '') -join "`n"
            Assert-Equal 2 $state.Prompts 'Bootstrap yes still requires plugin consent'
            Assert-Equal 1 $state.Calls 'PowerShell consent permits one winget attempt'
            Assert-Equal ([int]$fallback) $state.Zip 'Failed winget uses ZIP under the PowerShell consent'
            Assert-True ($declined.Contains('Nothing changed')) 'Plugin decline reports no changes'
            Assert-True (-not (Test-Path (Join-Path $scratch 'record.json'))) 'Plugin decline never installs plugin'
            $state.Missing=$true; $state.Prompts=0; $state.Answers=@('y','y')
            $null=Invoke-InstallBootstrap -Parameters @{HomeRoot=$scratch} -CheckoutRoot ''
            Assert-Equal 2 $state.Prompts 'Both bootstrap and plugin ask before installing'
            Assert-True (Test-Path (Join-Path $scratch 'record.json')) 'Two yes answers permit plugin installation'
            Remove-Item -LiteralPath (Join-Path $scratch 'record.json')
            $state.Missing=$true; $state.Prompts=0; $state.Answers=@()
            $null=Invoke-InstallBootstrap -Parameters @{HomeRoot=$scratch;Yes=[switch]::new($true)} -CheckoutRoot ''
            Assert-Equal 0 $state.Prompts 'Yes skips both questions'
            Assert-True (Test-Path (Join-Path $scratch 'record.json')) 'Yes permits plugin installation after bootstrap'
            Remove-Item -LiteralPath (Join-Path $scratch 'record.json')
        }
        Write-Output 'PASS separate PowerShell and plugin consent, ZIP fallback and Yes'
        $goodCatalog=Get-Content (Join-Path $archiveRoot 'tools.json') -Raw
        foreach ($field in @('wingetId','portableCommand')) {
            $bad = $goodCatalog | ConvertFrom-Json
            $bad.bootstrap.windows.$field=$null
            Assert-Throws { Assert-InstallBootstrapCatalog -Catalog $bad } "Bad bootstrap metadata $field stops before action"
            $bad | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $archiveRoot 'tools.json')
            Compress-Archive -Path (Join-Path $scratch 'archive/single-top') -DestinationPath $zip -Force
            $state.Missing=$true; $state.Calls=0; $state.Prompts=0
            Assert-Throws { Invoke-InstallBootstrap -Parameters @{HomeRoot=$scratch;Yes=$true} -CheckoutRoot '' } 'Bad archive metadata stops the bootstrap entry point'
            Assert-Equal 0 $state.Calls 'Bad archive metadata never invokes winget'
            Assert-Equal 0 $state.Prompts 'Bad archive metadata never prompts'
            Assert-True (-not (Test-Path (Join-Path $scratch 'record.json'))) 'Bad archive metadata never starts plugin'
        }
        Write-Output 'PASS invalid archive bootstrap metadata stops before action'
        function Invoke-InstallArchiveDownload { throw 'Fixture release unavailable' }
        $message=''
        try { Invoke-InstallBootstrap -Parameters @{HomeRoot=$scratch} -CheckoutRoot '' } catch { $message=$_.Exception.Message }
        Assert-True ($message.Contains('could not find the latest release')) 'Missing release keeps useful error'
        Assert-Equal 0 @(Get-ChildItem (Join-Path $scratch '.legion/temp') -Directory -Filter 'install-*').Count 'Failed archive cleaned up'
        Write-Output 'PASS stub release error and cleanup'
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            $message=''
            try { & (Join-Path $repo 'plugins/legion/install.ps1') -NoRun } catch { $message=$_.Exception.Message }
            Assert-True ($message.Contains('PowerShell 7')) 'Plugin refusal names required runtime'
            Write-Output 'PASS installer refuses 5.1'
        }
    } finally {
        $env:PATH=$savedPath
        $env:OS=$savedOS
        $allowed=[IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($scratch).StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe stub test cleanup' }
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}
