$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/bin/ps-ai-update.ps1') -NoRun
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
