$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $failures = @()
    function Ensure-InstallPowerShell { $true }
    function Get-UpdateConfigDirs { ,@('') }
    function Invoke-ClosedInput {
        param($Command)
        if ($Command -contains 'list') { return @{ ExitCode=0; Output=@('[]') } }
        throw "Unexpected CLI call: $($Command -join ' ')"
    }
    foreach ($case in @(
        @{ Name='ReleaseAddsStable'; Ref='release'; Claude='BlackGad/ps-ai-marketplace#stable'; Codex='BlackGad/ps-ai-marketplace --ref stable' }
        @{ Name='MainAddsMain'; Ref='main'; Claude='BlackGad/ps-ai-marketplace#main'; Codex='BlackGad/ps-ai-marketplace --ref main' }
    )) {
        try {
            $options = @{ Tools=@('claude','codex','copilot'); Catalog=$script:installCatalog; DryRun=$true }
            if ($case.Ref -eq 'main') { $options.Ref = 'main' }
            $preview = @(Invoke-LegionInstaller @options)
            Assert-True ($preview -contains "claude plugin marketplace add $($case.Claude)") "$($case.Name): Claude pins the branch"
            Assert-True ($preview -contains "codex plugin marketplace add $($case.Codex)") "$($case.Name): Codex pins the branch"
            Assert-True ($preview -contains "copilot plugin marketplace add $($case.Claude)") "$($case.Name): Copilot pins the branch"
            "PASS $($case.Name)"
        } catch { $failures += "$($case.Name): $($_.Exception.Message)" }
    }
    try {
        foreach ($tool in @('claude','codex','copilot')) {
            Assert-Equal "$tool|plugin|marketplace|add|$repo" ((Get-InstallCommands -Tool $tool -Source $repo -Ref main)[0] -join '|') 'LocalSourceHasNoRef'
        }
        'PASS LocalSourceHasNoRef'
    } catch { $failures += $_.Exception.Message }
    try {
        function Invoke-ClosedInput {
            param($Command)
            Assert-Equal 'codex|plugin|marketplace|list|--json' ($Command -join '|') 'KindIsPassed: marketplace listing is selected explicitly'
            @{ ExitCode=0; Output=@('{"marketplaces":[{"name":"ps-ai-marketplace","root":"fixture"}]}') }
        }
        Assert-True (Test-InstallStepDone -Command @('codex','plugin','marketplace','add','example/market','--ref','stable') -Kind marketplace) 'KindIsPassed'
        'PASS KindIsPassed'
    } catch { $failures += $_.Exception.Message }
    try {
        foreach ($value in @($null, 'not an array', 42, @(1))) {
            $bad = Get-InstallCatalog -Source $repo
            $bad.tools[0].plugin | Add-Member -NotePropertyName marketplaceAddRef -NotePropertyValue $value -Force
            Assert-Throws { Get-InstallCatalog -Catalog $bad } 'CatalogRequiresRefArray'
        }
        'PASS CatalogRequiresRefArray'
    } catch { $failures += $_.Exception.Message }
    if ($failures.Count) { throw ($failures -join "`n") }
}
