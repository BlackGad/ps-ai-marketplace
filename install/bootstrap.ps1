# This entry point deliberately uses only Windows PowerShell 5.1 syntax.
$pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwshCommand) {
    Write-Output 'skip: PowerShell 7 (already done)'
} else {
    Write-Output 'PowerShell 7 is missing.'
    Write-Output 'winget install --id Microsoft.PowerShell -e'
    $answer = Read-Host 'Install PowerShell 7 now? [y/N]'
    if ($answer -notmatch '^(?i:y|yes)$') { exit 0 }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error 'winget is missing; see https://learn.microsoft.com/windows/package-manager/winget/'
        exit 1
    }
    & winget install --id Microsoft.PowerShell -e
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwshCommand) {
        $candidate = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
        if (Test-Path -LiteralPath $candidate) { $pwshCommand = @{ Source = $candidate } }
    }
    if (-not $pwshCommand) {
        Write-Error 'PowerShell 7 was installed but is not on PATH. Open a new terminal, then run this again.'
        exit 1
    }
}

& $pwshCommand.Source -NoProfile -File (Join-Path $PSScriptRoot 'install.ps1') @args
exit $LASTEXITCODE
