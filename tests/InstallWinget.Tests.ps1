$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/bin/ps-ai-install-tool.ps1') -NoRun
    foreach ($tool in @('claude', 'codex', 'copilot')) {
        $expected = "winget install --id $((Get-ToolInstallData $tool).windows.wingetId) -e --source winget --accept-source-agreements --accept-package-agreements"
        $recipe = Get-ToolRecipe -Tool $tool -Platform windows
        Assert-Equal $expected ($recipe.Install[0] -join ' ') "$tool winget recipe is non-interactive"
        $hints = @(Get-ToolInstallHints -Tool $tool -Platform windows -CommandAvailable { $false } -ToolInstalled { $false })
        Assert-Equal $expected ($hints -join "`n") "$tool plan hint includes source and agreement flags"
    }
    function Test-ToolInstalled { @{ Installed=$false; Version='' } }
    function Get-ToolPortableCommand { $null }
    function Test-ToolCommandAvailable { $true }
    function Invoke-ToolCommand {
        param($Command)
        Assert-Equal 'winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements' ($Command -join ' ') 'Approved install executes the non-interactive recipe'
        42
    }
    $output = @(Invoke-ToolInstall -Tool git -Platform windows -Yes) -join "`n"
    Assert-True ($output.Contains('winget failed (exit 42)')) 'Present failing winget reports its exit code'
    Assert-True (-not $output.Contains('winget is not available')) 'Failed invocation is distinct from missing winget'
    Assert-True ($output.Contains('-Method msi') -and $output.Contains('-Method zip')) 'Failure retains explicit fallback choices'
    Assert-Equal 2 $LASTEXITCODE 'Winget failure requests method choice'
    function Invoke-ToolCommand { throw 'fixture launch denied' }
    $output = @(Invoke-ToolInstall -Tool git -Platform windows -Yes) -join "`n"
    Assert-True ($output.Contains('winget failed to start')) 'Broken winget launch has accurate diagnostic'
    function Test-ToolCommandAvailable { $false }
    $output = @(Invoke-ToolInstall -Tool git -Platform windows -Yes) -join "`n"
    Assert-True ($output.Contains('winget is not available')) 'Missing winget keeps availability diagnostic'
}
