$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $sandbox = Join-Path $repo ('.agents/temp/fresh-codex-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $sandbox | Out-Null
    $folder = Join-Path $sandbox 'config'
    $state = @{ Installed = $false; Mutations = 0; FailListing = $false }
    function Invoke-ClosedInput {
        param($Command)
        Assert-Equal $folder $env:CODEX_HOME 'Fresh Codex uses the selected home'
        if ($Command -contains 'list') {
            if (-not (Test-Path -LiteralPath $folder)) {
                return @{ ExitCode=1; Output=@(); ErrorOutput=@('Error: failed to resolve CODEX_HOME', "CODEX_HOME points to `"$folder`", but that path does not exist") }
            }
            if ($state.FailListing) { return @{ ExitCode=1; Output=@(); ErrorOutput=@('fixture permission denied') } }
            if ($Command -contains 'marketplace') {
                $listing = @{ marketplaces=@(@{ name='ps-legion-marketplace'; root=$folder }) } | ConvertTo-Json -Depth 4 -Compress
                return @{ ExitCode=0; Output=@($listing) }
            }
            $output = if ($state.Installed) { 'legion@ps-legion-marketplace enabled' } else { 'No marketplace plugins found.' }
            return @{ ExitCode=0; Output=@($output) }
        }
        Assert-True (Test-Path -LiteralPath $folder -PathType Container) 'Codex home exists before a mutating command'
        $state.Mutations++
        if ($Command -notcontains 'marketplace') { $state.Installed = $true }
        return @{ ExitCode=0; Output=@() }
    }
    try {
        $preview = @(Invoke-LegionInstallSteps -Tool codex -Source $repo -ConfigEnv CODEX_HOME -ConfigDir $folder -DryRun)
        Assert-True (($preview -join "`n") -like '*plugin marketplace add*') 'Missing Codex home previews a fresh install'
        Assert-True (-not (Test-Path -LiteralPath $folder)) 'Preview leaves the missing home untouched'
        Assert-Equal 0 $state.Mutations 'Preview never runs a mutating CLI command'
        $null = Invoke-LegionInstallSteps -Tool codex -Source $repo -ConfigEnv CODEX_HOME -ConfigDir $folder
        Assert-True $state.Installed 'Fresh logged-out Codex home installs legion'
        $mutations = $state.Mutations
        $repeat = @(Invoke-LegionInstallSteps -Tool codex -Source $repo -ConfigEnv CODEX_HOME -ConfigDir $folder)
        Assert-Equal $mutations $state.Mutations 'Repeat install makes no changes'
        Assert-True (($repeat -join "`n") -like '*skip:*') 'Repeat install reports already done'
        $state.FailListing = $true
        Assert-Throws { Invoke-LegionInstallSteps -Tool codex -Source $repo -ConfigEnv CODEX_HOME -ConfigDir $folder } 'Other Codex listing errors still fail'
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
