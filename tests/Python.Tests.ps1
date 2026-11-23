. (Join-Path $PSScriptRoot 'lib/workspace.ps1')
$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $repo 'plugins/legion/bin/lib/python.ps1')

$folder = Join-Path $HOME 'python bridge'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$fake = Join-Path $folder 'fake-uv.ps1'
@'
$args | ConvertTo-Json -Compress
$env:UV_PROJECT_ENVIRONMENT
[Console]::Error.WriteLine('fixture stderr')
exit 7
'@ | Set-Content -LiteralPath $fake
$null = New-TestCommandStub -Folder $folder -Name uv -Script $fake
$savedPath = $env:PATH
$savedEnvironment = $env:UV_PROJECT_ENVIRONMENT
try {
    $env:PATH = $folder + [IO.Path]::PathSeparator + $env:PATH
    $env:UV_PROJECT_ENVIRONMENT = 'caller environment'
    $selectedHome = Join-Path $folder 'selected home'
    $result = Invoke-LegionPython -Arguments @('--version', 'two words') -HomeRoot $selectedHome
    Assert-Equal 7 $result.ExitCode 'Python exit code returned'
    $output = $result.Output -split '\r?\n'
    $arguments = @($output[0] | ConvertFrom-Json)
    Assert-Equal 'run|--project' (($arguments | Select-Object -First 2) -join '|') 'uv project invocation'
    Assert-Equal (Resolve-LegionDirectoryPath (Join-Path $repo 'plugins/legion')) $arguments[2] 'Plugin project path'
    Assert-Equal '--frozen|legion-py|--version|two words' (($arguments | Select-Object -Skip 3) -join '|') 'Arguments stay separate'
    Assert-Equal (Get-LegionPythonEnvironment -PluginRoot $arguments[2] -HomeRoot $selectedHome) $output[1] 'Environment under selected legion home'
    Assert-True ($result.Error.Contains('fixture stderr')) 'stderr returned'
    Assert-Equal 'caller environment' $env:UV_PROJECT_ENVIRONMENT 'Caller environment restored'

    (Get-Content -LiteralPath $fake -Raw).Replace('exit 7', 'exit 0') | Set-Content -LiteralPath $fake
    Remove-Item Env:UV_PROJECT_ENVIRONMENT
    $result = Invoke-LegionPython -Arguments @('--version')
    Assert-Equal 0 $result.ExitCode 'Success exit code returned'
    Assert-Equal (Get-LegionPythonEnvironment -PluginRoot $arguments[2]) ($result.Output -split '\r?\n')[1] 'Default legion home'
    Assert-Equal $null $env:UV_PROJECT_ENVIRONMENT 'Absent environment restored'

    New-Item -ItemType Directory -Force -Path (Join-Path $folder 'copy-a'), (Join-Path $folder 'copy-b') | Out-Null
    $rootA = Get-LegionPythonEnvironment -PluginRoot (Join-Path $folder 'copy-a') -HomeRoot $selectedHome
    $rootB = Get-LegionPythonEnvironment -PluginRoot (Join-Path $folder 'copy-b') -HomeRoot $selectedHome
    Assert-Equal $rootA (Get-LegionPythonEnvironment -PluginRoot (Join-Path $folder 'copy-a') -HomeRoot $selectedHome) 'Same plugin root, same environment'
    $separator = [IO.Path]::DirectorySeparatorChar
    Assert-Equal $rootA (Get-LegionPythonEnvironment -PluginRoot ((Join-Path $folder 'copy-a') + $separator) -HomeRoot $selectedHome) 'Trailing separator, same environment'
    Push-Location $folder
    try { $relativeA = Get-LegionPythonEnvironment -PluginRoot 'copy-a' -HomeRoot $selectedHome } finally { Pop-Location }
    Assert-Equal $rootA $relativeA 'Relative path, same environment'
    Assert-True ($rootA -ne $rootB) 'Different plugin roots, different environments'
    Assert-True ((Split-Path $rootA -Leaf) -match '^env-[0-9a-f]{12}$') 'Environment folder name'

    & {
        function Get-Command { param($Name, $CommandType, $ErrorAction) return $null }
        $shown = @(Invoke-LegionPython -Arguments @('--version') -HomeRoot $HOME 6>&1 | Where-Object { $_ -isnot [hashtable] })
        Assert-Equal 0 $shown.Count 'Missing uv hint is returned once, not also written to the host'
        $result = Invoke-LegionPython -Arguments @('--version') -HomeRoot $HOME
        Assert-Equal 127 $result.ExitCode 'Missing uv exit code'
        Assert-True (($result.Output -join "`n").Contains('uv is missing')) 'Missing uv plain message'
        Assert-True (($result.Output -join "`n").Contains('legion-install-tool.ps1" -Tool uv -Yes')) 'Missing uv consent hint'
    }
} finally {
    $env:PATH = $savedPath
    $env:UV_PROJECT_ENVIRONMENT = $savedEnvironment
}

$utf8Text = 'Привіт 👋'
$child = Invoke-LegionProcess -Command (Get-Process -Id $PID).Path -Arguments @('-NoProfile', '-Command', "[Console]::OutputEncoding = [Text.UTF8Encoding]::new(`$false); [Console]::Out.Write('$utf8Text'); [Console]::Error.Write('$utf8Text')")
Assert-Equal $utf8Text $child.Output 'Child stdout is decoded as UTF-8'
Assert-Equal $utf8Text $child.Error 'Child stderr is decoded as UTF-8'
