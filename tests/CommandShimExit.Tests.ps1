$repo = Split-Path $PSScriptRoot -Parent
# A .cmd command that its own script deletes must still end cleanly, with the script's exit status.
if (-not $IsWindows) { return }
. (Join-Path $repo 'plugins/legion/bin/lib/commands.ps1')
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('shim-exit-' + [guid]::NewGuid().ToString('N'))
try {
    $bin = New-Item -ItemType Directory -Path (Join-Path $scratch 'plugin/bin') -Force
    foreach ($code in @(0, 3)) {
        $shim = Join-Path $scratch "legion$code.cmd"
        '$ErrorActionPreference = ''Stop''; Remove-Item -LiteralPath $args[0]; exit ' + $code | Set-Content -LiteralPath (Join-Path $bin 'legion.ps1')
        # The script receives the shim's own path as its first argument and deletes it.
        $text = (Get-LegionShimText -Script (Join-Path $bin 'legion.ps1') -Windows).Replace(' %*', ' "' + $shim + '" %*')
        [IO.File]::WriteAllText($shim, $text)
        $output = @(& cmd.exe /d /c ('"' + $shim + '" 2>&1'))
        $status = $LASTEXITCODE
        Assert-Equal $code $status "A shim that deletes itself exits with the script's status $code"
        Assert-Equal 0 @($output | Where-Object { "$_" -match 'cannot be found' }).Count 'No batch file error after the shim deletes itself'
    }
} finally { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue }
