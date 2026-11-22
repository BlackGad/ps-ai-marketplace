# The shell bootstrap needs no PowerShell, JSON utility, package manager or sudo.
$repo = Split-Path $PSScriptRoot -Parent
$launcher = Join-Path $repo 'install.sh'
Assert-True (Test-Path -LiteralPath $launcher) 'POSIX bootstrap exists'
Assert-True (-not ([IO.File]::ReadAllText($launcher)).Contains("`r")) 'Shell bootstrap uses LF'
$bootstrap = Get-Content (Join-Path $repo 'tools/bootstrap.json') -Raw | ConvertFrom-Json
$catalog = Get-Content (Join-Path $repo 'plugins/legion/tools.json') -Raw | ConvertFrom-Json
Assert-Equal ($bootstrap.posix | ConvertTo-Json -Depth 10 -Compress) ($catalog.bootstrap.posix | ConvertTo-Json -Depth 10 -Compress) 'Catalog preserves the POSIX bootstrap recipe'
Assert-True ($null -ne $catalog.bootstrap.posix.assetNames.macos) 'Catalog has the macOS archive recipe'
Assert-True ($null -ne $catalog.bootstrap.posix.assetNames.linux) 'Catalog has the Linux archive recipe'
$shell = Get-Command sh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($shell) {
    & $shell.Source -n $launcher
    Assert-Equal 0 $LASTEXITCODE 'Shell bootstrap parses'
}
if ($IsWindows) { return } # macOS and Linux CI execute the fake-driven cases below.

& {
    $scratch = Join-Path $repo ('.agents/temp/install-shell-' + [guid]::NewGuid().ToString('N'))
    $saved = @{}
    $variables = @('HOME', 'PATH', 'FAKE_ROOT', 'FAKE_REAL_PWSH', 'FAKE_PWSH_PRESENT', 'FAKE_OS', 'FAKE_CPU', 'FAKE_EXIT')
    foreach ($name in $variables) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
    try {
        $bin = Join-Path $scratch 'bin'
        New-Item -ItemType Directory -Path $bin -Force | Out-Null
        Copy-Item -LiteralPath $launcher -Destination (Join-Path $scratch 'install.sh')
        $launcher = Join-Path $scratch 'install.sh'
        $env:FAKE_ROOT = $scratch
        $env:FAKE_REAL_PWSH = (Get-Process -Id $PID).Path
        $env:FAKE_OS = 'Linux'
        $env:FAKE_CPU = 'x86_64'
        $env:FAKE_EXIT = '0'
        $env:PATH = $bin + [IO.Path]::PathSeparator + $env:PATH
        $pwshFake = @'
#!/bin/sh
if [ "$2" = '-Command' ]; then
    [ "$FAKE_PWSH_PRESENT" = 1 ] || [ "$0" = "$HOME/.legion/tools/pwsh/pwsh" ]
    exit $?
fi
exec "$FAKE_REAL_PWSH" "$@"
'@
        $curlFake = @'
#!/bin/sh
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o) output=$2; shift 2 ;;
        -*) shift ;;
        *) url=$1; shift ;;
    esac
done
printf '%s\n' "$url" >> "$FAKE_ROOT/downloads"
case "$url" in
    */tools.json) cp "$FAKE_ROOT/catalog.json" "$output" ;;
    */install.ps1) cp "$FAKE_ROOT/stub.ps1" "$output" ;;
    */latest) cp "$FAKE_ROOT/release.json" "$output" ;;
    https://github.com/PowerShell/PowerShell/releases/download/*) cp "$FAKE_ROOT/pwsh.tar.gz" "$output" ;;
    *) echo "Unexpected download: $url" >&2; exit 1 ;;
esac
'@
        $unameFake = @'
#!/bin/sh
case "$1" in
    -s) printf '%s\n' "$FAKE_OS" ;;
    -m) printf '%s\n' "$FAKE_CPU" ;;
    *) exit 1 ;;
esac
'@
        $stub = @'
param([string[]]$Tools, [string]$ConfigDir, [string]$Ref, [switch]$Update,
    [switch]$Uninstall, [switch]$Purge, [switch]$DryRun, [switch]$Yes)
$captured = @{}
foreach ($key in $PSBoundParameters.Keys) {
    $value = $PSBoundParameters[$key]
    $captured[$key] = if ($value -is [Management.Automation.SwitchParameter]) { [bool]$value } else { $value }
}
$captured | ConvertTo-Json | Set-Content (Join-Path $env:FAKE_ROOT 'handoff.json')
exit ([int]$env:FAKE_EXIT)
'@
        foreach ($file in @{ pwsh=$pwshFake; curl=$curlFake; uname=$unameFake }.GetEnumerator()) {
            [IO.File]::WriteAllText((Join-Path $bin $file.Key), $file.Value.Replace("`r", '') + "`n")
            & chmod +x (Join-Path $bin $file.Key)
            Assert-Equal 0 $LASTEXITCODE 'Fake executable is ready'
        }
        [IO.File]::WriteAllText((Join-Path $scratch 'stub.ps1'), $stub)
        # A compact catalog also works; the launcher must not rely on JSON layout.
        [IO.File]::WriteAllText((Join-Path $scratch 'catalog.json'), ($catalog | ConvertTo-Json -Depth 100 -Compress))
        & tar -czf (Join-Path $scratch 'pwsh.tar.gz') -C $bin pwsh
        Assert-Equal 0 $LASTEXITCODE 'Fixture archive is ready'
        $digest = (Get-FileHash (Join-Path $scratch 'pwsh.tar.gz') -Algorithm SHA256).Hash.ToLowerInvariant()

        function Set-ShellRelease {
            param([string]$Name, [string]$Hash = $digest)
            # Minified metadata, extra objects, escaped quotes, and reordered asset fields.
            $release = @{ body='Ignore "name" and escaped \ text'; tag_name='v7.9.0'; assets=@(
                @{ name='unrelated.tar.gz'; digest="sha256:$digest"; browser_download_url='https://invalid.example/unrelated' },
                @{ browser_download_url="https://github.com/PowerShell/PowerShell/releases/download/v7.9.0/$Name"; uploader=@{name='nested'}; digest="sha256:$Hash"; name=$Name }
            ) }
            [IO.File]::WriteAllText((Join-Path $scratch 'release.json'), ($release | ConvertTo-Json -Depth 10 -Compress))
        }
        function Invoke-ShellCase {
            param([string[]]$Options = @(), [switch]$Stream)
            $env:HOME = Join-Path $scratch ('home-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $env:HOME | Out-Null
            Remove-Item (Join-Path $scratch 'handoff.json'), (Join-Path $scratch 'downloads') -ErrorAction SilentlyContinue
            if ($Stream) { $output = @((Get-Content $launcher -Raw) | & $shell.Source -s -- @Options 2>&1) -join "`n" }
            else { $output = @('' | & $shell.Source $launcher @Options 2>&1) -join "`n" }
            return @{ Code=$LASTEXITCODE; Output=$output; Home=$env:HOME }
        }
        $env:FAKE_PWSH_PRESENT = '1'
        $result = Invoke-ShellCase -Options @('--main', '--update', '--uninstall', '--purge', '--dry-run', '--yes', '--tools', 'codex,claude', '--config-dir', (Join-Path $scratch 'account with spaces'))
        Assert-Equal 0 $result.Code "Existing PowerShell hands over successfully: $($result.Output)"
        $handoff = Get-Content (Join-Path $scratch 'handoff.json') -Raw | ConvertFrom-Json
        Assert-Equal 'codex|claude' ($handoff.Tools -join '|') 'Tools are a typed array'
        Assert-Equal (Join-Path $scratch 'account with spaces') $handoff.ConfigDir 'Config folder is one literal argument'
        Assert-Equal 'main' $handoff.Ref 'Main selects the main track'
        foreach ($option in @('Update', 'Uninstall', 'Purge', 'DryRun', 'Yes')) { Assert-Equal $true $handoff.$option "$option is mapped" }
        Assert-True (-not ((Get-Content (Join-Path $scratch 'downloads') -Raw).Contains('/latest'))) 'Existing PowerShell needs no runtime download'
        $env:FAKE_EXIT = '23'
        Assert-Equal 23 (Invoke-ShellCase).Code 'Child exit status is preserved'
        $env:FAKE_EXIT = '0'
        $result = Invoke-ShellCase -Stream -Options @('--main', '--dry-run')
        Assert-Equal 0 $result.Code 'Piped script hands over successfully'
        $handoff = Get-Content (Join-Path $scratch 'handoff.json') -Raw | ConvertFrom-Json
        Assert-Equal 'main' $handoff.Ref 'Piped script maps options after sh -s --'
        Assert-Equal $true $handoff.DryRun 'Piped script preserves dry run'

        $checkout = Join-Path $scratch 'checkout'
        New-Item -ItemType Directory -Path (Join-Path $checkout 'plugins/legion') -Force | Out-Null
        Copy-Item $launcher (Join-Path $checkout 'install.sh')
        Copy-Item (Join-Path $scratch 'stub.ps1') (Join-Path $checkout 'install.ps1')
        Copy-Item (Join-Path $scratch 'catalog.json') (Join-Path $checkout 'plugins/legion/tools.json')
        $launcher = Join-Path $checkout 'install.sh'
        Assert-Equal 0 (Invoke-ShellCase).Code 'Checkout runs its sibling stub'
        Assert-True (-not (Test-Path (Join-Path $scratch 'downloads'))) 'Checkout handoff downloads nothing'
        $launcher = Join-Path $scratch 'install.sh'

        $env:FAKE_PWSH_PRESENT = '0'
        foreach ($options in @(@(), @('--dry-run', '--yes'))) {
            $result = Invoke-ShellCase -Options $options
            Assert-Equal 0 $result.Code 'Missing PowerShell without approval succeeds without changes'
            Assert-True ($result.Output.Contains('PowerShell 7 is missing')) 'Missing PowerShell shows a hint'
            Assert-True (-not (Test-Path (Join-Path $scratch 'downloads'))) 'Decline and dry run download nothing'
            Assert-True (-not (Test-Path (Join-Path $result.Home '.legion'))) 'Decline and dry run create nothing'
        }
        foreach ($platform in @(
            @{ OS='Linux'; CPU='x86_64'; Asset='linux-x64' },
            @{ OS='Linux'; CPU='aarch64'; Asset='linux-arm64' },
            @{ OS='Darwin'; CPU='x86_64'; Asset='osx-x64' },
            @{ OS='Darwin'; CPU='arm64'; Asset='osx-arm64' }
        )) {
            $env:FAKE_OS = $platform.OS
            $env:FAKE_CPU = $platform.CPU
            Set-ShellRelease -Name "powershell-7.9.0-$($platform.Asset).tar.gz"
            $result = Invoke-ShellCase -Options @('-y')
            Assert-Equal 0 $result.Code "Verified $($platform.Asset) archive hands over: $($result.Output)"
            Assert-True (Test-Path (Join-Path $result.Home '.legion/tools/pwsh/pwsh')) 'Portable runtime uses the agreed folder'
            Assert-True (Test-Path (Join-Path $scratch 'handoff.json')) 'Installer ran after verification'
            $downloads = Get-Content (Join-Path $scratch 'downloads') -Raw
            Assert-True ($downloads.Contains("powershell-7.9.0-$($platform.Asset).tar.gz")) 'Platform and CPU choose the official asset'
            Assert-True ($downloads.Contains('/stable/install.ps1')) 'Default track downloads the stable stub'
            Remove-Item (Join-Path $scratch 'downloads')
            $output = @('' | & $shell.Source $launcher 2>&1) -join "`n"
            Assert-Equal 0 $LASTEXITCODE 'Repeat reuses the portable runtime'
            Assert-True ($output.Contains('skip: PowerShell 7 (already done)')) 'Repeat reports a skip'
            Assert-True (-not ((Get-Content (Join-Path $scratch 'downloads') -Raw).Contains('/latest'))) 'Repeat does not download PowerShell'
            Assert-Equal 0 @(Get-ChildItem (Join-Path $result.Home '.legion/temp') -Force).Count 'Scratch is removed after handoff'
        }
        Set-ShellRelease -Name 'powershell-7.9.0-osx-arm64.tar.gz' -Hash ('0' * 64)
        $result = Invoke-ShellCase -Options @('--yes')
        Assert-True ($result.Code -ne 0) 'Hash mismatch fails'
        Assert-True ($result.Output.Contains('SHA-256 digest mismatch')) 'Hash mismatch explains the failure'
        Assert-True (-not (Test-Path (Join-Path $scratch 'handoff.json'))) 'Hash mismatch never runs the installer'
        Assert-True (-not (Test-Path (Join-Path $result.Home '.legion/tools/pwsh/pwsh'))) 'Hash mismatch never extracts PowerShell'
        Assert-Equal 0 @(Get-ChildItem (Join-Path $result.Home '.legion/temp') -Force).Count 'Failed download scratch is removed'
        foreach ($badHash in @('', 'not-a-digest', ('a' * 63))) {
            Set-ShellRelease -Name 'powershell-7.9.0-osx-arm64.tar.gz' -Hash $badHash
            $result = Invoke-ShellCase -Options @('--yes')
            Assert-True ($result.Code -ne 0) 'Missing or invalid SHA-256 metadata fails'
            Assert-True (-not (Test-Path (Join-Path $scratch 'handoff.json'))) 'Invalid digest never runs the installer'
            Assert-True (-not ((Get-Content (Join-Path $scratch 'downloads') -Raw).Contains('/releases/download/'))) 'Invalid digest never downloads an archive'
        }
        $env:FAKE_CPU = 'unsupported'
        $result = Invoke-ShellCase -Options @('--yes')
        Assert-True ($result.Code -ne 0) 'Unsupported CPU stops'
        Assert-True (-not (Test-Path (Join-Path $scratch 'downloads'))) 'Unsupported CPU downloads nothing'
        foreach ($options in @(@('--unknown'), @('--tools'), @('--config-dir'))) {
            Assert-True ((Invoke-ShellCase -Options $options).Code -ne 0) 'Invalid options fail before any download'
            Assert-True (-not (Test-Path (Join-Path $scratch 'downloads'))) 'Invalid options download nothing'
        }
    } finally {
        foreach ($name in $variables) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not ([IO.Path]::GetFullPath($scratch)).StartsWith($allowed)) { throw 'Unsafe shell fixture cleanup' }
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}
