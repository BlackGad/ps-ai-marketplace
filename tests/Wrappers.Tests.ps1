$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$account = Join-Path $root 'plugins/ps-ai/bin/ps-ai-account.ps1'
$tempRoot = Join-Path $env:TEMP ('ps-ai-tests/' + [guid]::NewGuid())
$previousLog = $env:PS_AI_WRAPPER_LOG
$previousExpand = $env:PS_AI_WRAPPER_EXPAND
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $homeRoot = Join-Path $tempRoot 'owner $(printf expanded) & quoted '' fixture'
    $config = Join-Path $homeRoot '.agents/configuration'
    New-Item -ItemType Directory -Path $config -Force | Out-Null
    Copy-Item (Join-Path $PSScriptRoot 'fixtures/personalisation/valid-owner.json') (Join-Path $config 'ps-ai-personalisation.json')
    $fake = Join-Path $tempRoot 'fake command.ps1'
    @'
[IO.File]::WriteAllText($env:PS_AI_WRAPPER_LOG, (@{ Args=@($args); Home=$env:CODEX_HOME } | ConvertTo-Json))
exit 37
'@ | Set-Content -LiteralPath $fake
    $env:PS_AI_WRAPPER_LOG = Join-Path $tempRoot 'log.json'
    & $account -Action add -Id wrapper-test -Tool codex -HomeRoot $homeRoot -Command $fake | Out-Null
    $bin = Join-Path $homeRoot '.agents/bin'
    $owner = Get-Content (Join-Path $config 'ps-ai-personalisation.json') -Raw | ConvertFrom-Json
    $entry = $owner.agents | Where-Object id -eq wrapper-test
    $expected = if ($IsWindows) { '~/.agents/bin/wrapper-test.cmd' } else { '~/.agents/bin/wrapper-test' }
    Assert-Equal $expected $entry.command 'Stored wrapper selects the Windows batch sibling'
    if ($IsWindows) {
        $caller = Join-Path $tempRoot 'caller.cmd'
        $envLog = Join-Path $tempRoot 'env.txt'
        @"
@echo off
set "CODEX_HOME=caller-account"
call "$(Join-Path $bin 'wrapper-test.cmd')" first "two words" "semi;literal"
set "result=%errorlevel%"
> "$envLog" echo %CODEX_HOME%
exit /b %result%
"@ | Set-Content -LiteralPath $caller
        & $caller
        Assert-Equal 37 $LASTEXITCODE 'Batch forwards a PowerShell shim exit code'
        Assert-Equal 'caller-account' (Get-Content $envLog) 'Batch config does not leak into its caller'
        $seen = Get-Content $env:PS_AI_WRAPPER_LOG -Raw | ConvertFrom-Json
        Assert-Equal 'first|two words|semi;literal' ($seen.Args -join '|') 'Batch forwards literal arguments'
        Assert-Equal (Join-Path $homeRoot '.agents/accounts/wrapper-test') $seen.Home 'Batch selects account config'
        $fakeBatch = Join-Path $tempRoot 'fake command.cmd'
        '@pwsh -NoProfile -File "' + $fake + '" %*' | Set-Content $fakeBatch
        & $account -Action add -Id wrapper-batch -Tool codex -HomeRoot $homeRoot -Command $fakeBatch | Out-Null
        & (Join-Path $bin 'wrapper-batch.cmd') 'two words'
        Assert-Equal 37 $LASTEXITCODE 'Batch shim returns to the wrapper with its exit code'
        $seen = Get-Content $env:PS_AI_WRAPPER_LOG -Raw | ConvertFrom-Json
        Assert-Equal 'two words' ($seen.Args -join '|') 'Batch shim receives forwarded arguments'

        # Keep the wrapper outside the unusual path so this tests its literal runner argument.
        & {
        . $account -NoRun -HomeRoot $tempRoot
        $fakeFolder = Join-Path $tempRoot 'runtime %PS_AI_WRAPPER_EXPAND%'
        New-Item -ItemType Directory -Path $fakeFolder -Force | Out-Null
        $fakeRunner = Join-Path $fakeFolder 'ps-ai-foundry.ps1'
        Copy-Item $fake $fakeRunner
        function Sync-PsAiFoundryRuntime { param($Tool,$HomeRoot,$Changes) return $fakeRunner }
        $env:PS_AI_WRAPPER_EXPAND = 'expanded'
        New-FoundryWrappers -Id percent-test -Tool claude -HomeRoot $tempRoot
        & (Join-Path $tempRoot '.agents/bin/percent-test.cmd') 'literal'
        Assert-Equal 37 $LASTEXITCODE 'Foundry wrapper preserves literal percent sequences in runner paths'
        }
    }
    $shell = Get-Command sh -ErrorAction SilentlyContinue
    if ($shell) {
        & $shell.Source (Join-Path $bin 'wrapper-test') first 'two words' 'semi;literal'
        Assert-Equal 37 $LASTEXITCODE 'POSIX wrapper executes a PowerShell shim'
        $seen = Get-Content $env:PS_AI_WRAPPER_LOG -Raw | ConvertFrom-Json
        Assert-Equal 'first|two words|semi;literal' ($seen.Args -join '|') 'POSIX wrapper forwards literal arguments'
        Assert-Equal (Join-Path $homeRoot '.agents/accounts/wrapper-test') $seen.Home 'POSIX wrapper preserves shell-significant paths'
    }
} finally {
    $env:PS_AI_WRAPPER_LOG = $previousLog
    $env:PS_AI_WRAPPER_EXPAND = $previousExpand
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
