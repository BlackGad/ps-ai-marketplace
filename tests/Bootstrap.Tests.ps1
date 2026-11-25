# Root bootstrap (install.ps1 and install.sh): it only obtains uv, then runs `legion install` through uv.
. (Join-Path $PSScriptRoot 'lib/installer.ps1')

$bootstrap = Join-Path $repo 'install.ps1'
$fixture = Join-Path $PSScriptRoot 'fixtures/install/Test-Bootstrap.ps1'

function New-BootstrapScratch {
    $scratch = New-InstallTestFolder 'bootstrap'
    $fakeSource = Join-Path $scratch 'fake-uv-source'
    New-Item -ItemType Directory -Path $fakeSource, (Join-Path $scratch 'bin') -Force | Out-Null
    # A fake uv logs one argument per line, then the project environment, and exits with FAKE_UV_EXIT.
    if ($env:OS -eq 'Windows_NT') {
        $lines = @('@echo off', 'del "%FAKE_UV_LOG%" 2>nul', ':loop', 'if "%~1"=="" goto done', '>> "%FAKE_UV_LOG%" echo %~1', 'shift', 'goto loop', ':done',
            '>> "%FAKE_UV_LOG%" echo env=%UV_PROJECT_ENVIRONMENT%', 'exit /b %FAKE_UV_EXIT%')
        $name = 'uv.cmd'
    } else {
        $lines = @('#!/bin/sh', ': > "$FAKE_UV_LOG"', 'for word in "$@"; do echo "$word" >> "$FAKE_UV_LOG"; done',
            'echo "env=$UV_PROJECT_ENVIRONMENT" >> "$FAKE_UV_LOG"', 'exit "$FAKE_UV_EXIT"')
        $name = 'uv'
    }
    Set-Content -LiteralPath (Join-Path $fakeSource $name) -Value $lines
    Set-TestExecutable (Join-Path $fakeSource $name)
    # Present on PATH for the runs that start with uv.
    Copy-Item -LiteralPath (Join-Path $fakeSource $name) -Destination (Join-Path $scratch "bin/$name")
    Set-TestExecutable (Join-Path $scratch "bin/$name")
    foreach ($project in @('checkout/plugins/legion', 'archive/ps-legion-marketplace-stable/plugins/legion')) {
        New-Item -ItemType Directory -Path (Join-Path $scratch $project) -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $scratch "$project/pyproject.toml") -Value '[project]'
    }
    Compress-Archive -Path (Join-Path $scratch 'archive/ps-legion-marketplace-stable') -DestinationPath (Join-Path $scratch 'plugin.zip')
    return $scratch
}

function Invoke-BootstrapFixture {
    param([string]$Runtime, [string]$Mode, [string]$Scratch, [bool]$UvOnPath = $true)
    $savedPath = $env:PATH
    if ($UvOnPath) { $env:PATH = (Join-Path $Scratch 'bin') + [IO.Path]::PathSeparator + $env:PATH }
    try {
        # Closed standard input: the bootstrap must never wait on it.
        $output = @('' | & $Runtime -NoProfile -File $fixture -Installer $bootstrap -Mode $Mode -Scratch $Scratch -Archive (Join-Path $Scratch 'plugin.zip') 2>&1)
        return @{ ExitCode = $LASTEXITCODE; Lines = @($output | ForEach-Object { "$_" }) }
    } finally { $env:PATH = $savedPath }
}

Invoke-InstallTestCase 'BootstrapParses' {
    $tokens = $null
    $errors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($bootstrap, [ref]$tokens, [ref]$errors)
    Assert-Equal 0 $errors.Count 'install.ps1 parses'
    $shell = Get-Content -LiteralPath (Join-Path $repo 'install.sh') -Raw
    Assert-True (-not ($shell -match 'pwsh|PowerShell')) 'install.sh never mentions PowerShell'
    $text = Get-Content -LiteralPath $bootstrap -Raw
    Assert-True (-not ($text -match 'pwsh')) 'install.ps1 never asks for pwsh'
    Assert-True (-not ($text -match '\?\?|\?\.|\s\?\s')) 'install.ps1 uses no PowerShell 7 syntax'
}

Invoke-InstallTestCase 'BootstrapArguments' {
    . $bootstrap -NoRun
    $all = @{ Tools = @('claude', 'codex'); Source = 'owner/repo'; ConfigDir = 'C:\some folder'; Ref = 'main'; HomeRoot = 'C:\h'; DryRun = [switch]$true; Yes = [switch]$true; Update = [switch]$true; Uninstall = [switch]$false; Purge = [switch]$true }
    $arguments = @(Get-InstallArguments -Parameters $all)
    Assert-Equal '--home|C:\h|install|--tool|claude,codex|--source|owner/repo|--config-dir|C:\some folder|--ref|main|--dry-run|--yes|--update|--purge' ($arguments -join '|') 'Every option reaches legion install'
    Assert-Equal 'install' (@(Get-InstallArguments -Parameters @{}) -join '|') 'No option adds nothing'
}

Invoke-InstallTestCase 'BootstrapHandsOverToUv' {
    $scratch = New-BootstrapScratch
    try {
        $runtimes = @(Get-InstallTestPwsh)
        $legacy = Get-Command powershell.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($legacy) { $runtimes += $legacy.Source }
        foreach ($runtime in $runtimes) {
            $result = Invoke-BootstrapFixture -Runtime $runtime -Mode 'checkout' -Scratch $scratch
            $text = $result.Lines -join "`n"
            Assert-Equal 0 $result.ExitCode "Checkout run in ${runtime}: $text"
            Assert-True ($result.Lines -contains 'skip: uv (already done)') 'Present uv is reused'
            Assert-True ($result.Lines -contains 'downloads=') "A checkout downloads nothing: $text"
            $project = Join-Path $scratch 'checkout/plugins/legion'
            Assert-True ($result.Lines -contains "uv:$project") "uv runs the checkout project: $text"
            foreach ($word in @('run', '--project', '--frozen', '--quiet', 'legion', 'install', '--tool', 'claude', '--yes', '--home', $scratch)) {
                Assert-True ($result.Lines -contains "uv:$word") "uv gets $word"
            }
            Assert-True (@($result.Lines | Where-Object { $_ -like 'uv:env=*temp*env' }).Count -eq 1) "uv gets its own project environment: $text"
            Assert-True ($result.Lines -contains 'tempLeft=0') 'The temporary folder is gone afterwards'
            Assert-True ($result.Lines -contains 'exit=0') 'Exit code is zero'

            $result = Invoke-BootstrapFixture -Runtime $runtime -Mode 'exit-code' -Scratch $scratch
            Assert-True ($result.Lines -contains 'exit=3') "uv's exit code is the bootstrap's: $($result.Lines -join ' ')"
        }
    } finally { Remove-InstallTestFolder $scratch }
}

Invoke-InstallTestCase 'BootstrapDownloadsTheRightBranch' {
    $scratch = New-BootstrapScratch
    try {
        foreach ($case in @(@('remote', 'stable'), @('remote-main', 'main'))) {
            $result = Invoke-BootstrapFixture -Runtime (Get-InstallTestPwsh) -Mode $case[0] -Scratch $scratch
            $text = $result.Lines -join "`n"
            Assert-Equal 0 $result.ExitCode "$($case[0]): $text"
            Assert-True ($result.Lines -contains "downloads=https://github.com/BlackGad/ps-legion-marketplace/archive/refs/heads/$($case[1]).zip") "$($case[0]) downloads the $($case[1]) code: $text"
            Assert-True ($result.Lines -contains 'tempLeft=0') "$($case[0]) removes its download"
            Assert-True (@($result.Lines | Where-Object { $_ -like 'uv:*expanded*legion' }).Count -eq 1) "$($case[0]) runs the downloaded project: $text"
        }
        $result = Invoke-BootstrapFixture -Runtime (Get-InstallTestPwsh) -Mode 'remote-main' -Scratch $scratch
        Assert-True ($result.Lines -contains 'uv:--ref') 'main reaches legion install as --ref main'
        $result = Invoke-BootstrapFixture -Runtime (Get-InstallTestPwsh) -Mode 'no-release' -Scratch $scratch
        Assert-True (($result.Lines -join ' ').Contains('could not find the latest release; try again or run with main')) 'The failure says what to do'
        Assert-True (-not ($result.Lines -contains 'uv:run')) 'uv never runs after a failed download'
    } finally { Remove-InstallTestFolder $scratch }
}

Invoke-InstallTestCase 'BootstrapObtainsUvFirst' {
    $scratch = New-BootstrapScratch
    try {
        $runtime = Get-InstallTestPwsh
        $result = Invoke-BootstrapFixture -Runtime $runtime -Mode 'uv-missing-dry' -Scratch $scratch -UvOnPath $false
        $text = $result.Lines -join "`n"
        Assert-True ($result.Lines -contains 'uv is missing.') "Missing uv is reported: $text"
        Assert-True ($result.Lines -contains 'downloads=') 'A dry run downloads nothing'
        Assert-True ($result.Lines -contains 'uvInstalled=False') 'A dry run installs no uv'
        Assert-True ($result.Lines -contains 'prompts=0') 'A dry run never asks'
        Assert-True (-not ($result.Lines -contains 'uv:run')) 'A dry run never reaches legion'

        $result = Invoke-BootstrapFixture -Runtime $runtime -Mode 'uv-missing-declined' -Scratch $scratch -UvOnPath $false
        Assert-True ($result.Lines -contains 'prompts=1') 'Without -Yes it asks once'
        Assert-True ($result.Lines -contains 'downloads=') 'A no downloads nothing'
        Assert-True (($result.Lines -join ' ').Contains('Nothing changed. Run again with -Yes to apply.')) 'A no says how to apply'

        $result = Invoke-BootstrapFixture -Runtime $runtime -Mode 'uv-missing-yes' -Scratch $scratch -UvOnPath $false
        $text = $result.Lines -join "`n"
        Assert-Equal 0 $result.ExitCode "uv-missing-yes: $text"
        Assert-True ($result.Lines -contains 'prompts=0') '-Yes never asks'
        Assert-True ($result.Lines -contains 'uvInstalled=True') 'The verified uv release is extracted to the legion tools folder'
        Assert-True ($result.Lines -contains 'downloads=https://api.github.com/repos/astral-sh/uv/releases/latest,https://example.invalid/uv.zip') "Only the uv release is downloaded for a checkout: $text"
        Assert-True ($result.Lines -contains 'uv:install') 'Then legion install runs through the new uv'
        Assert-True ($result.Lines -contains 'tempLeft=0') 'The temporary folder is gone afterwards'

        Remove-Item -LiteralPath (Join-Path $scratch '.legion/tools/uv') -Recurse -Force
        foreach ($mode in @('uv-bad-digest', 'uv-no-digest')) {
            $result = Invoke-BootstrapFixture -Runtime $runtime -Mode $mode -Scratch $scratch -UvOnPath $false
            $text = $result.Lines -join "`n"
            Assert-True ($result.ExitCode -ne 0) "$mode fails: $text"
            Assert-True ($text.Contains('digest')) "$mode says why: $text"
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $scratch '.legion/tools/uv'))) "$mode extracts nothing"
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $scratch '.legion/temp')) -or @(Get-ChildItem -LiteralPath (Join-Path $scratch '.legion/temp') -Force).Count -eq 0) "$mode deletes the download"
            Assert-True (-not ($result.Lines -contains 'uv:run')) "$mode never reaches legion"
        }

        $result = Invoke-BootstrapFixture -Runtime $runtime -Mode 'find-folder' -Scratch $scratch -UvOnPath $false
        Assert-True (@($result.Lines | Where-Object { $_ -like 'found=*uv*' }).Count -eq 1) "uv is found in its own folder: $($result.Lines -join ' ')"
    } finally { Remove-InstallTestFolder $scratch }
}

Invoke-InstallTestCase 'ShellBootstrap' {
    if ($IsWindows) { return }
    $scratch = New-InstallTestFolder 'shell-bootstrap'
    try {
        $fakeHome = Join-Path $scratch 'home'
        $fakeBin = Join-Path $scratch 'bin'
        New-Item -ItemType Directory -Path (Join-Path $fakeHome 'checkout/plugins/legion'), $fakeBin -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $fakeHome 'checkout/plugins/legion/pyproject.toml') -Value '[project]'
        $log = Join-Path $scratch 'uv-log.txt'
        $uvLines = @('#!/bin/sh', ': > "$FAKE_UV_LOG"', 'for word in "$@"; do echo "$word" >> "$FAKE_UV_LOG"; done', 'echo "env=$UV_PROJECT_ENVIRONMENT" >> "$FAKE_UV_LOG"', 'exit "${FAKE_UV_EXIT:-0}"')
        Set-Content -LiteralPath (Join-Path $fakeBin 'uv') -Value $uvLines
        # A fake curl serves a source archive and a uv installer stand-in, and logs the URLs.
        $archiveSource = Join-Path $scratch 'archive/legion-stable/plugins/legion'
        New-Item -ItemType Directory -Path $archiveSource -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $archiveSource 'pyproject.toml') -Value '[project]'
        & tar -czf (Join-Path $scratch 'plugin.tar.gz') -C (Join-Path $scratch 'archive') legion-stable
        $curlLines = @(
            '#!/bin/sh'
            'out=; url='
            'while [ $# -gt 0 ]; do case "$1" in -o) out=$2; shift ;; -*) ;; *) url=$1 ;; esac; shift; done'
            'echo "$url" >> "$FAKE_CURL_LOG"'
            'case "$url" in'
            ('  */archive/*) [ -z "$FAKE_CURL_FAIL" ] || exit 22; cp "' + $scratch + '/plugin.tar.gz" "$out" ;;')
            '  */releases/latest) printf ''{
  "assets": [
    {
      "name": "%s",
      "digest": "sha256:%s"
    }
  ]
}
'' "$FAKE_UV_ASSET" "$FAKE_UV_DIGEST" > "$out" ;;'
            ('  */releases/latest/download/*) cp "' + $scratch + '/uv-release.tar.gz" "$out" ;;')
            'esac'
        )
        Set-Content -LiteralPath (Join-Path $fakeBin 'curl') -Value $curlLines
        # The fake uv release: a tar.gz with one top folder holding the fake uv, as the real ones do.
        $releaseFolder = Join-Path $scratch 'uv-release/uv-triple'
        New-Item -ItemType Directory -Path $releaseFolder -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $fakeBin 'uv') -Destination (Join-Path $releaseFolder 'uv')
        Set-TestExecutable (Join-Path $releaseFolder 'uv')
        & tar -czf (Join-Path $scratch 'uv-release.tar.gz') -C (Join-Path $scratch 'uv-release') uv-triple
        $platform = (& uname -s) + '-' + (& uname -m)
        $triples = @{ 'Linux-x86_64' = 'x86_64-unknown-linux-gnu'; 'Linux-aarch64' = 'aarch64-unknown-linux-gnu'; 'Darwin-x86_64' = 'x86_64-apple-darwin'; 'Darwin-arm64' = 'aarch64-apple-darwin' }
        $env:FAKE_UV_ASSET = 'uv-' + $triples[$platform] + '.tar.gz'
        $env:FAKE_UV_DIGEST = (Get-FileHash -LiteralPath (Join-Path $scratch 'uv-release.tar.gz') -Algorithm SHA256).Hash
        foreach ($tool in @('uv', 'curl')) { Set-TestExecutable (Join-Path $fakeBin $tool) }
        $shell = (Get-Command sh -CommandType Application | Select-Object -First 1).Source
        $env:FAKE_UV_LOG = $log
        $env:FAKE_CURL_LOG = Join-Path $scratch 'curl-log.txt'
        $env:FAKE_UV_SOURCE = Join-Path $fakeBin 'uv'
        $savedPath = $env:PATH
        $savedHome = $env:HOME
        $env:HOME = $fakeHome
        try {
            # A checkout run with uv on PATH downloads nothing and passes the options through.
            Copy-Item -LiteralPath (Join-Path $repo 'install.sh') -Destination (Join-Path $fakeHome 'checkout/install.sh')
            $env:PATH = $fakeBin + [IO.Path]::PathSeparator + $savedPath
            $text = @('' | & $shell (Join-Path $fakeHome 'checkout/install.sh') --yes --tools claude --config-dir '/some folder' --main --dry-run 2>&1) -join "`n"
            Assert-Equal 0 $LASTEXITCODE "Shell checkout run: $text"
            $logged = (Get-Content -LiteralPath $log) -join '|'
            Assert-True ($logged.StartsWith('run|--project|' + (Join-Path $fakeHome 'checkout/plugins/legion') + '|--frozen|--quiet|legion|install|--yes|--tool|claude|--config-dir|/some folder|--ref|main|--dry-run|env=')) "Shell hand-over: $logged"
            Assert-True (-not (Test-Path $env:FAKE_CURL_LOG)) 'A checkout run downloads nothing'
            Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $fakeHome '.legion/temp') -Force).Count -eq 0) 'The shell run removes its temporary folder'

            # Piped from curl (no file on disk): the stable archive is downloaded and used.
            $script = Get-Content -LiteralPath (Join-Path $repo 'install.sh') -Raw
            $text = @($script | & $shell -s -- --yes 2>&1) -join "`n"
            Assert-Equal 0 $LASTEXITCODE "Shell remote run: $text"
            Assert-True ((Get-Content -LiteralPath $env:FAKE_CURL_LOG) -contains 'https://github.com/BlackGad/ps-legion-marketplace/archive/refs/heads/stable.tar.gz') 'The stable archive is downloaded'
            Assert-True (((Get-Content -LiteralPath $log) -join '|') -like 'run|--project|*/source/plugins/legion|*') 'uv runs the downloaded project'
            Remove-Item $env:FAKE_CURL_LOG
            $null = @($script | & $shell -s -- --yes --main 2>&1)
            Assert-True ((Get-Content -LiteralPath $env:FAKE_CURL_LOG) -contains 'https://github.com/BlackGad/ps-legion-marketplace/archive/refs/heads/main.tar.gz') '--main downloads the main archive'

            # A failed release download says what to do and never runs uv.
            Remove-Item $log
            $env:FAKE_CURL_FAIL = '1'
            $text = @($script | & $shell -s -- --yes 2>&1) -join "`n"
            Assert-True ($LASTEXITCODE -ne 0) 'A failed download stops'
            Assert-True ($text.Contains('could not find the latest release; try again or run with --main')) 'The failure says what to do'
            Assert-True (-not (Test-Path $log)) 'uv never runs after a failed download'
            Remove-Item Env:FAKE_CURL_FAIL

            # uv exit code is the bootstrap's.
            $env:FAKE_UV_EXIT = '3'
            $null = @($script | & $shell -s -- --yes 2>&1)
            Assert-Equal 3 $LASTEXITCODE "uv's exit code is the bootstrap's"
            Remove-Item Env:FAKE_UV_EXIT

            # Without uv: a dry run changes nothing; --yes installs it with uv's own script, then hands over.
            $noUv = Join-Path $scratch 'nouv'
            New-Item -ItemType Directory -Path $noUv -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $fakeBin 'curl') -Destination (Join-Path $noUv 'curl')
            Set-TestExecutable (Join-Path $noUv 'curl')
            $env:PATH = $noUv + [IO.Path]::PathSeparator + '/usr/bin' + [IO.Path]::PathSeparator + '/bin'
            Remove-Item $env:FAKE_CURL_LOG -ErrorAction SilentlyContinue
            $text = @('' | & $shell (Join-Path $fakeHome 'checkout/install.sh') --dry-run 2>&1) -join "`n"
            Assert-True ($text.Contains('uv is missing.')) 'A missing uv is reported'
            Assert-True (-not (Test-Path $env:FAKE_CURL_LOG)) 'A dry run downloads nothing'
            $text = @('' | & $shell (Join-Path $fakeHome 'checkout/install.sh') 2>&1) -join "`n"
            Assert-True ($text.Contains('Nothing changed. Run again with --yes to apply.')) 'Without a terminal and without --yes nothing changes'
            $text = @('' | & $shell (Join-Path $fakeHome 'checkout/install.sh') --yes 2>&1) -join "`n"
            Assert-Equal 0 $LASTEXITCODE "Shell uv install: $text"
            Assert-True ((Get-Content -LiteralPath $env:FAKE_CURL_LOG) -contains 'https://api.github.com/repos/astral-sh/uv/releases/latest') 'The uv release is looked up'
            Assert-True (Test-Path -LiteralPath (Join-Path $fakeHome '.legion/tools/uv/uv')) 'The verified uv is extracted to the legion tools folder'
            Assert-True ((Get-Content -LiteralPath $log) -contains 'install') 'Then legion install runs'

            # A digest mismatch deletes the download, extracts nothing and never runs uv.
            Remove-Item -LiteralPath (Join-Path $fakeHome '.legion/tools/uv') -Recurse -Force
            Remove-Item $log
            $env:FAKE_UV_DIGEST = '0' * 64
            $text = @('' | & $shell (Join-Path $fakeHome 'checkout/install.sh') --yes 2>&1) -join "`n"
            Assert-True ($LASTEXITCODE -ne 0 -and $text.Contains('uv SHA-256 digest mismatch; download deleted.')) "A digest mismatch fails: $text"
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $fakeHome '.legion/tools/uv'))) 'A digest mismatch extracts nothing'
            Assert-True (-not (Test-Path $log)) 'uv never runs after a digest mismatch'
            Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $fakeHome '.legion/temp') -Force).Count -eq 0) 'A digest mismatch leaves no download'

            $text = @('' | & $shell (Join-Path $fakeHome 'checkout/install.sh') --bogus 2>&1) -join "`n"
            Assert-True ($LASTEXITCODE -ne 0 -and $text.Contains('Unknown option: --bogus')) 'An unknown option is refused'
        } finally {
            $env:PATH = $savedPath
            $env:HOME = $savedHome
            foreach ($name in @('FAKE_UV_LOG', 'FAKE_CURL_LOG', 'FAKE_UV_SOURCE', 'FAKE_UV_ASSET', 'FAKE_UV_DIGEST', 'FAKE_CURL_FAIL', 'FAKE_UV_EXIT')) { Remove-Item "Env:$name" -ErrorAction SilentlyContinue }
        }
    } finally { Remove-InstallTestFolder $scratch }
}
