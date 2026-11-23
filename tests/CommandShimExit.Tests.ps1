$repo = Split-Path $PSScriptRoot -Parent
# The generated .cmd command, run by cmd with a fake uv.exe: arguments arrive unchanged, stdin and output
# pass through, the exit code is exact, the caller's environment stays, and a command that is
# deleted while it runs (an update rewriting it) still ends cleanly.
if (-not $IsWindows) { return }
. (Join-Path $repo 'plugins/legion/bin/lib/commands.ps1')
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('shim-exit-' + [guid]::NewGuid().ToString('N'))
$savedPath = $env:PATH
$saved = @{}
foreach ($name in @('UV_PROJECT_ENVIRONMENT', 'FAKE_UV_LOG', 'FAKE_UV_EXIT', 'FAKE_UV_DELETE')) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }

# A real executable: a batch fake would never return to the command's (goto) tail.
function New-FakeUv {
    param([string]$Folder)
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    $source = Join-Path $Folder 'fake-uv.cs'
    @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
class FakeUv {
    static int Main(string[] args) {
        var lines = new List<string>();
        foreach (var arg in args) { lines.Add("arg:" + arg); }
        lines.Add("env:" + Environment.GetEnvironmentVariable("UV_PROJECT_ENVIRONMENT"));
        lines.Add("stdin:" + Console.In.ReadLine());
        File.WriteAllLines(Environment.GetEnvironmentVariable("FAKE_UV_LOG"), lines.ToArray(), new UTF8Encoding(false));
        Console.Out.WriteLine("live output");
        string delete = Environment.GetEnvironmentVariable("FAKE_UV_DELETE");
        if (!string.IsNullOrEmpty(delete)) { File.Delete(delete); }
        return int.Parse(Environment.GetEnvironmentVariable("FAKE_UV_EXIT"));
    }
}
'@ | Set-Content -LiteralPath $source
    $csc = Join-Path $env:SystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    $output = & $csc /nologo /target:exe ('/out:' + (Join-Path $Folder 'uv.exe')) $source 2>&1
    if ($LASTEXITCODE -ne 0) { throw "fake uv did not compile: $output" }
}

# cmd /s /c takes the line exactly as written, so the test controls every quote.
function Invoke-TestCmd {
    param([string]$Line, [string]$Text = '')
    $info = [Diagnostics.ProcessStartInfo]::new('cmd.exe', '/d /s /c "' + $Line + '"')
    $info.UseShellExecute = $false
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($info)
    $process.StandardInput.WriteLine($Text)
    $process.StandardInput.Close()
    $output = $process.StandardOutput.ReadToEnd()
    $errorText = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return @{ ExitCode = $process.ExitCode; Output = $output; Error = $errorText }
}

try {
    New-FakeUv -Folder (Join-Path $scratch 'fake')
    $selectedHome = Join-Path $scratch 'home 100%'
    $app = Join-Path $selectedHome '.legion/app/1.2.3'
    $shim = Join-Path $scratch 'legion.cmd'
    $log = Join-Path $scratch 'uv.log'
    $env:PATH = (Join-Path $scratch 'fake') + ';' + (Join-Path $env:SystemRoot 'System32')
    $env:FAKE_UV_LOG = $log
    $env:UV_PROJECT_ENVIRONMENT = 'caller value'
    $unicode = 'Привіт'

    foreach ($code in @(0, 3)) {
        [IO.File]::WriteAllText($shim, (Get-LegionShimText -App $app -HomeRoot $selectedHome -Windows))
        $env:FAKE_UV_EXIT = "$code"
        $env:FAKE_UV_DELETE = $shim
        $result = Invoke-TestCmd -Line ('"' + $shim + '" status "two words" "" 100% ' + $unicode) -Text 'typed input'
        Assert-Equal $code $result.ExitCode "A command that is deleted while it runs exits with uv's status $code"
        Assert-True (-not (Test-Path -LiteralPath $shim)) 'The fake uv deleted the command while it ran'
        Assert-True (-not ($result.Output + $result.Error).Contains('cannot find')) 'No batch file error after the command is deleted'
        Assert-Equal "live output`r`n" $result.Output 'uv output passes through'
        $expected = @('arg:run', 'arg:--project', "arg:$app", 'arg:--frozen', 'arg:--quiet', 'arg:legion', 'arg:--home', "arg:$selectedHome",
            'arg:status', 'arg:two words', 'arg:', 'arg:100%', "arg:$unicode", "env:$(Get-LegionPythonEnvironment -PluginRoot $app -HomeRoot $selectedHome)", 'stdin:typed input')
        Assert-Equal ($expected -join "`n") ([IO.File]::ReadAllLines($log, [Text.Encoding]::UTF8) -join "`n") 'uv receives the app, the home, each argument unchanged, its environment and stdin'
    }

    # An interactive console stays open after the command, with uv's exit code and its own environment.
    [IO.File]::WriteAllText($shim, (Get-LegionShimText -App $app -HomeRoot $selectedHome -Windows))
    $env:FAKE_UV_EXIT = '5'
    $env:FAKE_UV_DELETE = ''
    # The command reads nul, so the fake uv cannot take the console's next lines.
    $result = Invoke-TestCmd -Line 'cmd /d /q /k' -Text ('"' + $shim + '" status <nul' + "`r`necho after %errorlevel% %UV_PROJECT_ENVIRONMENT%`r`nexit")
    Assert-True ($result.Output.Contains('after 5 caller value')) "The console continues with uv's exit code and an unchanged environment"

    # Without uv: one line and exit 127.
    $env:PATH = Join-Path $env:SystemRoot 'System32'
    $result = Invoke-TestCmd -Line ('"' + $shim + '" status')
    Assert-Equal 127 $result.ExitCode 'Missing uv exits 127'
    Assert-Equal "uv is missing. Ask the owner before installing it, then run the legion installer again.`r`n" $result.Error 'Missing uv is one plain line'
} finally {
    $env:PATH = $savedPath
    foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}
