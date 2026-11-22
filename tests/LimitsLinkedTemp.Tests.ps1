$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'plugins/legion/bin/lib/limits.ps1')
$scratch = Join-Path $root ('.agents/temp/limits-linked-' + [guid]::NewGuid().ToString('N'))
$physical = Join-Path $scratch 'physical'
$linked = Join-Path $scratch 'linked'
$folder = Join-Path $scratch 'codex'
$sessions = Join-Path $folder 'sessions'
$call = @{}
$savedTemp = @{}
foreach ($name in @('TMP', 'TEMP', 'TMPDIR')) { $savedTemp[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    New-Item -ItemType Directory -Path $physical, $sessions -Force | Out-Null
    $physical = Resolve-TestDirectory $physical
    $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path $linked -Target $physical | Out-Null
    function Invoke-LegionProcess {
        param($Command, $Arguments, $WorkingDirectory)
        $call.probe = $WorkingDirectory
        $cwd = if ($scenario -eq 'linked probe') { Resolve-TestDirectory $WorkingDirectory }
            else { Join-Path $linked (Split-Path $WorkingDirectory -Leaf) }
        $metadata = @{ type='session_meta'; payload=@{ cwd=$cwd } } | ConvertTo-Json -Compress
        $records = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixtures/limits/codex-session.jsonl') |
            Where-Object { $_ -notmatch '"session_meta"' }
        @($metadata) + $records | Set-Content -LiteralPath (Join-Path $sessions 'probe.jsonl')
        return @{ ExitCode=0; Output=''; Error=''; TimedOut=$false }
    }
    foreach ($scenario in @('linked probe', 'linked session')) {
        $tempRoot = if ($scenario -eq 'linked probe') { $linked } else { $physical }
        foreach ($name in $savedTemp.Keys) { [Environment]::SetEnvironmentVariable($name, $tempRoot, 'Process') }
        $rows = @(& (Join-Path $root 'plugins/legion/skills/legion-codex/scripts/limits.ps1') -Command 'unused' -Folder $folder -TimeoutSeconds 1)
        Assert-Equal $tempRoot (Split-Path $call.probe -Parent) "Codex $scenario uses the requested temp path"
        Assert-Equal '12%' $rows[0].Used "Codex $scenario matches the physical probe directory"
        Assert-Equal '40%' $rows[1].Used "Codex $scenario reads the secondary window"
        Assert-Equal 'unknown' $rows[0].Status "Codex $scenario does not invent a status"
        Assert-True (-not (Test-Path -LiteralPath $call.probe)) "Codex $scenario removes the disposable directory"
    }
} finally {
    foreach ($name in $savedTemp.Keys) { [Environment]::SetEnvironmentVariable($name, $savedTemp[$name], 'Process') }
    if (-not (Test-LegionPathUnder -Path $scratch -Root (Join-Path $root '.agents/temp'))) { throw 'Unsafe linked-temp cleanup' }
    if (Test-Path -LiteralPath $linked) { Remove-Item -LiteralPath $linked -Force }
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}
