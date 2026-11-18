$script:fakeAzRoot = $null

function Use-FakeAz {
    param([hashtable]$Answers)
    if (-not $script:fakeAzRoot) {
        $script:fakeAzRoot = Join-Path $env:TEMP ('ps-ai-tests/' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:fakeAzRoot -Force | Out-Null
    }
    $env:PS_AI_FAKE_AZ = Join-Path $script:fakeAzRoot 'answers.json'
    $env:PS_AI_FAKE_AZ_LOG = Join-Path $script:fakeAzRoot 'calls.log'
    $Answers | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $env:PS_AI_FAKE_AZ
    [System.IO.File]::WriteAllText($env:PS_AI_FAKE_AZ_LOG, '')
    $fakeFolder = Join-Path $PSScriptRoot 'fixtures/fake-az'
    $env:PATH = $fakeFolder + [System.IO.Path]::PathSeparator + $env:PATH
}

function Get-FakeAzCalls {
    if (Test-Path -LiteralPath $env:PS_AI_FAKE_AZ_LOG) { Get-Content -LiteralPath $env:PS_AI_FAKE_AZ_LOG }
}
