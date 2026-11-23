# Run once with stdin closed and drain both streams concurrently. A timeout kills the process tree.
function Invoke-LegionProcess {
    param([string]$Command, [string[]]$Arguments, [hashtable]$Environment = @{},
        [string]$WorkingDirectory, [int]$TimeoutSeconds = -1)

    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    # Children (legion, uv) write UTF-8; the default would be the console code page.
    $start.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $start.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    if ($WorkingDirectory) { $start.WorkingDirectory = $WorkingDirectory }
    foreach ($name in $Environment.Keys) {
        if ($null -eq $Environment[$name]) { $null = $start.Environment.Remove($name) }
        else { $start.Environment[$name] = [string]$Environment[$name] }
    }
    if ($IsWindows -and [IO.Path]::GetExtension($Command) -in @('.cmd', '.bat')) {
        $start.FileName = $env:ComSpec
        $line = (@($Command) + $Arguments | ForEach-Object { '"' + $_.Replace('"', '""') + '"' }) -join ' '
        $start.Arguments = '/d /s /c "' + $line + '"'
    } else {
        $start.FileName = $Command
        if ([IO.Path]::GetExtension($Command) -ieq '.ps1') {
            $start.FileName = (Get-Process -Id $PID).Path
            foreach ($argument in @('-NoProfile', '-File', $Command)) { $start.ArgumentList.Add($argument) }
        }
        foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        $null = $process.Start()
        $process.StandardInput.Close()
        $output = $process.StandardOutput.ReadToEndAsync()
        $errors = $process.StandardError.ReadToEndAsync()
        $finished = $true
        if ($TimeoutSeconds -ge 0) { $finished = $process.WaitForExit($TimeoutSeconds * 1000) }
        else { $process.WaitForExit() }
        if (-not $finished) { $process.Kill($true); $process.WaitForExit() }
        return @{
            ExitCode = if ($finished) { $process.ExitCode } else { -1 }
            Output = $output.GetAwaiter().GetResult()
            Error = $errors.GetAwaiter().GetResult()
            TimedOut = -not $finished
        }
    } finally { $process.Dispose() }
}
