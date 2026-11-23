. (Join-Path $PSScriptRoot 'lib/installer.ps1')
. (Join-Path $PSScriptRoot 'lib/user-path.ps1')
Assert-True ([bool]$env:LEGION_TEST_USER_PATH_FILE) 'The runner sets an inherited user PATH file'
Assert-True (Test-LegionPathUnder -Path $env:LEGION_TEST_USER_PATH_FILE -Root $env:LEGION_TEST_GUARD) 'The store is inside the guarded home'
$scratch = New-InstallTestFolder 'user-path-fence'
try {
    # An empty store is valid; raw variable references and empty entries must survive too.
    foreach ($seed in @('', 'keep-first;%LEGION_PATH_FENCE%/bin;;keep-last;')) {
        [IO.File]::WriteAllText($env:LEGION_TEST_USER_PATH_FILE, $seed)
        $output = @(& (Get-InstallTestPwsh) -NoProfile -File (Join-Path $PSScriptRoot 'fixtures/install/Test-UserPathFence.ps1') -Repo $repo -FixtureHome $scratch 2>&1)
        Assert-Equal 0 $LASTEXITCODE ('Fenced child succeeds: ' + ($output -join "`n"))
        Assert-True ($output -contains 'child PATH fence passed') 'The child completes real add and purge helpers'
        Assert-Equal $seed.TrimEnd(';') ([IO.File]::ReadAllText($env:LEGION_TEST_USER_PATH_FILE)) 'Purge preserves the remaining raw fake PATH'
    }
    Assert-True (-not (Test-Path -LiteralPath ($env:LEGION_TEST_USER_PATH_FILE + '.writes.jsonl'))) 'Fake PATH writes create no debug sidecar'

    # Exercise the guard without touching HKCU, including a kind-only change.
    foreach ($change in @('value', 'kind')) {
        & {
            function Get-TestUserPathSnapshot {
                if ($change -eq 'value') { return [pscustomobject]@{ Value='changed'; Kind=1 } }
                return [pscustomobject]@{ Value='before'; Kind=2 }
            }
            $message = ''
            try { Assert-TestUserPathUnchanged -Before ([pscustomobject]@{ Value='before'; Kind=1 }) }
            catch { $message = $_.Exception.Message }
            Assert-Equal 'Tests changed the real user PATH value or registry value kind.' $message 'The guard detects raw value and kind changes privately'
        }
    }
} finally { Remove-InstallTestFolder $scratch }
