. (Join-Path $PSScriptRoot 'lib/paths.ps1')
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
# Retained for the old hook until task 3; moved from InstallFlow.Tests.ps1.
& {
    . (Join-Path $repo 'plugins/legion/bin/legion-update.ps1') -NoRun
    Assert-Equal $HOME (Get-LegionUpdateHome) 'The update check defaults to the fenced $HOME'
}
$sandbox = Join-Path $repo ('.agents/temp/restructure/update-hook-' + [guid]::NewGuid().ToString('N'))
$plugin = Join-Path $sandbox 'plugin'
$fixtureRepo = Join-Path $sandbox 'repo'
New-Item -ItemType Directory -Path (Join-Path $plugin 'hooks'), (Join-Path $plugin 'bin/lib'), (Join-Path $fixtureRepo '.legion/state') -Force | Out-Null
try {
    foreach ($file in @('hooks/detect-mode.ps1','bin/lib/common.ps1','bin/lib/tools.ps1','bin/lib/paths.ps1','bin/legion-update.ps1')) {
        Copy-Item (Join-Path $repo "plugins/legion/$file") (Join-Path $plugin $file)
    }
    '{"name":"legion","version":"0.3.0"}' | Set-Content (Join-Path $plugin 'plugin.json')
    # Replace only the download and home boundaries in the child-process copy.
    @'
function Get-LegionUpdateHome { Join-Path $PSScriptRoot '../../home' }
function Get-LegionUpdateText {
    param([string]$Url)
    Add-Content (Join-Path $PSScriptRoot '../downloads.txt') 'download'
    $text = Get-Content (Join-Path $PSScriptRoot '../response.txt') -Raw
    if ($text -eq 'fail') { throw 'offline fixture' }
    $text
}
'@ | Add-Content (Join-Path $plugin 'bin/legion-update.ps1')
    '{"name":"legion","version":"0.4.0"}' | Set-Content (Join-Path $plugin 'response.txt') -NoNewline
    $hook = Join-Path $plugin 'hooks/detect-mode.ps1'
    $savedRole = $env:LEGION_ROLE
    $savedTask = $env:LEGION_TASK
    try {
        $env:LEGION_ROLE = ''
        $env:LEGION_TASK = ''
        Assert-Equal '{}' (& pwsh -NoProfile -File $hook -Repo $fixtureRepo -Format context-json) 'Ad hoc mode has no notice'
        Assert-True (-not (Test-Path (Join-Path $plugin 'downloads.txt'))) 'Ad hoc never checks'
        "## Goal and milestone`nM1`n## Current task`ntask 1`n" | Set-Content (Join-Path $fixtureRepo '.legion/state/handoff.md')
        $env:LEGION_ROLE = 'member'
        $env:LEGION_TASK = 'task.md'
        $memberText = & pwsh -NoProfile -File $hook -Repo $fixtureRepo
        Assert-True ($memberText.Contains('you are a legion member') -and $memberText.Contains('LEGION_TASK')) 'Child hook reads member variables'
        $env:LEGION_TASK = ''
        Assert-Equal 'legion: LEGION_ROLE=member without LEGION_TASK; ignored.' (& pwsh -NoProfile -File $hook -Repo $fixtureRepo) 'Child hook warns about missing member task'
        Assert-True (-not (Test-Path (Join-Path $plugin 'downloads.txt'))) 'Member never checks even without task'
        $env:LEGION_ROLE = ''
        $notice = 'legion 0.4.0 is available (installed 0.3.0); say "update legion" to update.'
        $text = @(& pwsh -NoProfile -File $hook -Repo $fixtureRepo)
        Assert-Equal 0 $LASTEXITCODE 'Text hook exits zero'
        Assert-Equal 2 $text.Count 'Text hook adds exactly one notice line'
        Assert-Equal $notice $text[1] 'Notice matches owner wording'
        Assert-True ($text[1] -notmatch '(?i)\b(pwsh|irm)\b|\.ps1| -[A-Za-z]') 'Update notice uses plain words without a command'
        $json = & pwsh -NoProfile -File $hook -Repo $fixtureRepo -Format context-json | ConvertFrom-Json
        Assert-Equal ($text -join "`n") $json.additionalContext 'JSON includes same notice'
        Assert-Equal 1 @(Get-Content (Join-Path $plugin 'downloads.txt')).Count 'Hook uses daily cache'
        $env:LEGION_ROLE = 'legion'
        $env:LEGION_TASK = 'task.md'
        $oldRoleContext = (& pwsh -NoProfile -File $hook -Repo $fixtureRepo -Format context-json | ConvertFrom-Json).additionalContext
        Assert-Equal ($text -join "`n") $oldRoleContext 'Unknown role retains normal update behavior'
        $env:LEGION_ROLE = ''
        $env:LEGION_TASK = ''
        foreach ($version in @('0.3.0','0.2.0')) {
            Remove-Item (Join-Path $sandbox 'home/.legion/temp/update.json')
            "{`"name`":`"legion`",`"version`":`"$version`"}" | Set-Content (Join-Path $plugin 'response.txt') -NoNewline
            Assert-Equal 1 @(& pwsh -NoProfile -File $hook -Repo $fixtureRepo).Count 'Equal or older release adds no notice'
        }
        Remove-Item (Join-Path $sandbox 'home/.legion/temp/update.json')
        'fail' | Set-Content (Join-Path $plugin 'response.txt') -NoNewline
        $text = @(& pwsh -NoProfile -File $hook -Repo $fixtureRepo)
        Assert-Equal 1 $text.Count 'Failed check adds no output'
        Assert-True ($text[0].Contains('Say continue')) 'Failed check preserves overseer activation guidance'
        Assert-Equal 0 $LASTEXITCODE 'Failed update check exits zero'
        $json = & pwsh -NoProfile -File $hook -Repo $fixtureRepo -Format context-json | ConvertFrom-Json
        Assert-Equal $text[0] $json.additionalContext 'Failed check preserves JSON context'
    } finally {
        $env:LEGION_ROLE = $savedRole
        $env:LEGION_TASK = $savedTask
    }
} finally {
    Remove-TestFolder -Path $sandbox -AllowedParent (Join-Path $repo '.agents/temp/restructure')
}

# Retained for the old hook's HTTP implementation until task 3.
$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/legion/bin/legion-update.ps1') -NoRun
    # A handler that never completes proves the total deadline without using the network.
    if (-not ('LegionUpdateTest.StalledHandler' -as [type])) {
        Add-Type -TypeDefinition @'
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
namespace LegionUpdateTest {
    public class StalledHandler : HttpMessageHandler {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken token) {
            return new TaskCompletionSource<HttpResponseMessage>().Task;
        }
    }
}
'@
    }
    function Invoke-WebRequest { throw 'Network access is forbidden in this test' }
    $client = [Net.Http.HttpClient]::new([LegionUpdateTest.StalledHandler]::new())
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $failed = $false
    try { $null = Get-LegionUpdateText -Url 'https://example.invalid/plugin.json' -Client $client }
    catch { $failed = $true }
    finally { $timer.Stop(); $client.Dispose() }
    Assert-True $failed 'Stalled download fails'
    Assert-True ($timer.Elapsed.TotalSeconds -ge 2 -and $timer.Elapsed.TotalSeconds -lt 5) 'Download has a three-second total deadline'
}
