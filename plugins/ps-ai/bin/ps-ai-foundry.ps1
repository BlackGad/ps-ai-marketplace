param(
    [string]$Agent,
    [string]$HomeRoot = $HOME,
    [switch]$NoRun
)

$toolArguments = @($args)
. (Join-Path $PSScriptRoot 'lib/foundry.ps1')
. (Join-Path $PSScriptRoot 'lib/tools.ps1')

function Get-FoundryLaunch {
    param($Agent, [string]$HomeRoot, $Token)
    $tool = Get-PsAiTool -Tool $Agent.tool
    $script = Get-PsAiToolScript -Tool $tool -Name foundry-launch
    return & $script -Agent $Agent -HomeRoot $HomeRoot -Token $Token
}

function Get-FoundryToolCommand {
    param([string]$Tool, [string]$HomeRoot)
    $descriptor = Get-PsAiTool -Tool $Tool
    if ($null -eq $descriptor.foundry) { throw "tool '$Tool' does not support Foundry" }
    $bin = [IO.Path]::GetFullPath((Get-PsAiHomePath -HomeRoot $HomeRoot -Path 'bin'))
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    foreach ($command in @(Get-Command $descriptor.command -CommandType Application,ExternalScript -All -ErrorAction SilentlyContinue)) {
        $folder = [IO.Path]::GetFullPath((Split-Path $command.Source -Parent))
        if (-not $folder.Equals($bin, $comparison)) { return $command.Source }
    }
    throw "$Tool is not installed; run ps-ai-install-tool.ps1 -Tool $Tool"
}

function Invoke-FoundryTool {
    param([string]$Command, [string[]]$Arguments, $Launch)
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.UseShellExecute = $false
    $extension = [IO.Path]::GetExtension($Command)
    if ($extension -ieq '.ps1') {
        $start.FileName = (Get-Process -Id $PID).Path
        foreach ($arg in @('-NoProfile', '-File', $Command) + $Arguments) { $start.ArgumentList.Add($arg) }
    } elseif ($IsWindows -and $extension -in @('.cmd', '.bat')) {
        # Let PowerShell invoke batch shims, quoting every value as a literal.
        $start.FileName = (Get-Process -Id $PID).Path
        $parts = @($Command) + $Arguments | ForEach-Object { "'" + $_.Replace("'", "''") + "'" }
        $script = '& ' + ($parts -join ' ') + '; exit $LASTEXITCODE'
        $start.ArgumentList.Add('-NoProfile')
        $start.ArgumentList.Add('-EncodedCommand')
        $start.ArgumentList.Add([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script)))
    } else {
        $start.FileName = $Command
        foreach ($arg in $Arguments) { $start.ArgumentList.Add($arg) }
    }
    foreach ($name in $Launch.Clear) { $null = $start.Environment.Remove($name) }
    foreach ($name in $Launch.Set.Keys) { $start.Environment[$name] = [string]$Launch.Set[$name] }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        $null = $process.Start()
        $process.WaitForExit()
        return $process.ExitCode
    } finally { $process.Dispose() }
}

function Write-FoundryProviderFile {
    param([string]$Path, [string]$Json)
    New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
    if ($IsWindows) {
        $security = [Security.AccessControl.FileSecurity]::new()
        $security.SetAccessRuleProtection($true, $false)
        $owner = [Security.Principal.WindowsIdentity]::GetCurrent().User
        $security.SetOwner($owner)
        $security.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($owner, 'FullControl', 'Allow'))
        $stream = [IO.FileSystemAclExtensions]::Create([IO.FileInfo]::new($Path), [IO.FileMode]::CreateNew,
            [Security.AccessControl.FileSystemRights]::FullControl, [IO.FileShare]::None, 4096, [IO.FileOptions]::None, $security)
    } else {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    }
    $written = $false
    try {
        if (-not $IsWindows) {
            # Restrict the empty file before writing; chmod also overrides a restrictive umask.
            & chmod 600 -- $Path
            if ($LASTEXITCODE -ne 0) { throw 'could not restrict provider file permissions' }
        }
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Json)
        $stream.Write($bytes, 0, $bytes.Length)
        $written = $true
    } finally {
        $stream.Dispose()
        if (-not $written) { Remove-Item -LiteralPath $Path -Force -ErrorAction Stop }
    }
}

if (-not $NoRun) {
    $launch = $null
    try {
        $file = Get-PsAiHomePath -HomeRoot $HomeRoot -Path 'configuration/ps-ai-personalisation.json'
        $data = [IO.File]::ReadAllText($file).TrimStart([char]0xFEFF) | ConvertFrom-Json -Depth 100 -ErrorAction Stop
        $selected = @($data.agents | Where-Object { $_.id -ceq $Agent })[0]
        if (-not $selected) { throw "unknown account '$Agent'" }
        if ($selected.provider.kind -cne 'foundry') { throw "account '$Agent' is not a Foundry agent" }
        $command = Get-FoundryToolCommand -Tool $selected.tool -HomeRoot $HomeRoot
        $check = Test-FoundryToken -Login
        if (-not $check.Ok) { throw $check.Error }
        $launch = Get-FoundryLaunch -Agent $selected -HomeRoot $HomeRoot
        if ($launch.ProvidersFile) {
            Write-FoundryProviderFile -Path $launch.ProvidersFile -Json $launch.ProvidersJson
        }
        if ($launch.Notice) { Write-Output $launch.Notice }
        $exitCode = Invoke-FoundryTool -Command $command -Arguments $toolArguments -Launch $launch
    } catch {
        [Console]::Error.WriteLine($_.Exception.Message)
        $exitCode = 1
    } finally {
        if ($launch.ProvidersFile -and (Test-Path -LiteralPath $launch.ProvidersFile)) {
            Remove-Item -LiteralPath $launch.ProvidersFile -Force
        }
    }
    exit $exitCode
}
