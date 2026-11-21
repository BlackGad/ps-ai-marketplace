$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $calls = [Collections.Generic.List[string]]::new()
    $state = @{ Added=$false; Refreshed=$false; FailRefresh=$false }
    function Invoke-ClosedInput {
        param($Command)
        Assert-Equal 'selected account' $env:CLAUDE_CONFIG_DIR 'Fresh install uses selected config'
        $line = $Command -join '|'
        $calls.Add($line)
        switch ($line) {
            'claude|plugin|marketplace|list|--json' { return @{ExitCode=0; Output=@('[]')} }
            'claude|plugin|list|--json' { return @{ExitCode=0; Output=@('[]')} }
            'claude|plugin|marketplace|add|BlackGad/ps-ai-marketplace' { $state.Added=$true }
            'claude|plugin|marketplace|update|ps-ai-marketplace' {
                Assert-True $state.Added 'Refresh follows marketplace add'
                if ($state.FailRefresh) { return @{ExitCode=2; Output=@('fixture refresh failed')} }
                $state.Refreshed=$true
            }
            'claude|plugin|install|ps-ai@ps-ai-marketplace' {
                if (-not $state.Refreshed) { return @{ExitCode=1; Output=@('Plugin "ps-ai" not found in marketplace "ps-ai-marketplace". Your local copy may be out of date — try claude plugin marketplace update ps-ai-marketplace')} }
            }
            default { throw "Unexpected fake command: $line" }
        }
        return @{ExitCode=0; Output=@()}
    }
    $null = Invoke-PsAiInstallSteps -Tool claude -Source 'BlackGad/ps-ai-marketplace' -ConfigEnv CLAUDE_CONFIG_DIR -ConfigDir 'selected account'
    Assert-True $state.Refreshed 'Fresh GitHub marketplace is refreshed before plugin install'
    Assert-Equal 'claude|plugin|install|ps-ai@ps-ai-marketplace' $calls[-1] 'Plugin install follows refresh'
    $calls.Clear()
    $state.FailRefresh=$true
    Assert-Throws { Invoke-PsAiInstallSteps -Tool claude -Source 'BlackGad/ps-ai-marketplace' -ConfigEnv CLAUDE_CONFIG_DIR -ConfigDir 'selected account' } 'Failed marketplace refresh stops plugin install'
    Assert-True (-not ($calls -contains 'claude|plugin|install|ps-ai@ps-ai-marketplace')) 'Plugin never installs from a failed refresh'
}
