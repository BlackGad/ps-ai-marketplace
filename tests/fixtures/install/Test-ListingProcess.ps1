param([string]$Installer, [string]$ChildRuntime)
$ErrorActionPreference = 'Stop'
. $Installer -NoRun
$command = @'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding -ArgumentList $false
$marker = [char]0x2022
$inputLength = [Console]::In.ReadToEnd().Length
[Console]::Out.Write('[{"id":"ps-ai@ps-ai-marketplace","enabled":true,"installPath":"C:/fixture/' + $marker + '"}]')
[Console]::Error.Write('fixture ' + $marker + ' warning; stdin=' + $inputLength + '; env=' + $env:FIXTURE_LISTING_FLAG)
'@
$result = Invoke-ClosedInput -Command @($ChildRuntime, '-NoProfile', '-Command', $command) -Environment @{FIXTURE_LISTING_FLAG='fixture'}
if ($result.ExitCode -ne 0) { throw 'Fake listing process failed' }
$plugin = ($result.Output -join "`n") | ConvertFrom-Json -ErrorAction Stop
if ($plugin.installPath -cne ('C:/fixture/' + [char]0x2022)) { throw 'Listing stdout lost UTF-8 characters' }
if (($result.ErrorOutput -join "`n") -cne ('fixture ' + [char]0x2022 + ' warning; stdin=0; env=fixture')) { throw 'Stderr lost UTF-8 characters, stdin was not closed, or child environment was lost' }
'listing process passed'
