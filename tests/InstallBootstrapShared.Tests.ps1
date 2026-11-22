$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
    function Get-LegionOwnerPath { param($Name,$HomeRoot) "shared:$Name" }
    Assert-Equal 'shared:Settings' (Get-InstallOwnerPath -Name Settings) 'Installer calls shared owner paths'
    $files = @(Get-LegionRuntimeFiles)
    foreach ($relative in @('bin/lib/tools.ps1','bin/lib/foundry.ps1','bin/lib/paths.ps1')) {
        Assert-True ($files -contains $relative) 'Runtime includes its libraries'
        $tokens=$null; $errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $repo "plugins/legion/$relative"),[ref]$tokens,[ref]$errors)
        $loads=@($ast.FindAll({param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.InvocationOperator -eq 'Dot'},$true))
        foreach ($load in $loads) {
            $names=@($load.FindAll({param($node) $node -is [Management.Automation.Language.StringConstantExpressionAst]},$true) | ForEach-Object Value)
            Assert-True ($files -contains ('bin/lib/' + $names[-1])) 'Every runtime dot-source is in the runtime list'
        }
    }
    Assert-True ($files -contains 'bin/legion-foundry.ps1') 'Runtime includes Foundry runner'
    $message=''
    try { & ([scriptblock]::Create((Get-Content (Join-Path $repo 'plugins/legion/install.ps1') -Raw))) -NoRun } catch { $message=$_.Exception.Message }
    Assert-True ($message.Contains('expanded archive')) 'Installer clearly refuses script text without PSScriptRoot'
    $scratch=Join-Path $repo ('.agents/temp/missing-lib-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $scratch -Force | Out-Null
    try {
        $copy=Join-Path $scratch 'install.ps1'
        Copy-Item (Join-Path $repo 'plugins/legion/install.ps1') $copy
        $message=''
        try { & $copy -NoRun } catch { $message=$_.Exception.Message }
        Assert-True ($message.Contains('bin/lib/paths.ps1')) 'Installer clearly refuses missing library'
        $physical=Join-Path $scratch 'physical'
        $linked=Join-Path $scratch 'linked'
        $fixtureHome=Join-Path $linked 'home'
        New-Item -ItemType Directory -Path (Join-Path $physical 'home'),(Join-Path $scratch 'outside') -Force | Out-Null
        $linkType=if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
        New-Item -ItemType $linkType -Path $linked -Target $physical | Out-Null
        Assert-True (Test-LegionOwnerPathSafe -Path (Join-Path $fixtureHome 'future-file') -StopRoot $fixtureHome) 'Link walk stops at home before a linked ancestor'
        $inner=Join-Path $fixtureHome 'linked-child'
        New-Item -ItemType $linkType -Path $inner -Target (Join-Path $scratch 'outside') | Out-Null
        Assert-True (-not (Test-LegionOwnerPathSafe -Path (Join-Path $inner 'future-file') -StopRoot $fixtureHome)) 'Link inside home is rejected'
        Assert-Throws { Test-LegionOwnerPathSafe -Path (Join-Path $scratch 'outside') -StopRoot $fixtureHome } 'Link walk rejects a path outside its stop root'
    } finally {
        $allowed=[IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($scratch).StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe missing-library cleanup' }
        if ($inner -and (Test-Path -LiteralPath $inner)) { [IO.Directory]::Delete($inner) }
        if ($linked -and (Test-Path -LiteralPath $linked)) { [IO.Directory]::Delete($linked) }
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}
# Keep the 7.0 baseline visible while CI runs the latest PowerShell 7.
foreach ($file in Get-ChildItem (Join-Path $repo 'plugins/legion') -Recurse -File -Filter '*.ps1') {
    $text=Get-Content -LiteralPath $file.FullName -Raw
    Assert-True ($text -notmatch '\$PSStyle\b|\[(System\.)?Environment\]::ProcessPath\b') "7.0 baseline: $($file.Name)"
    if ($text -match '-DateKind\b') {
        $tokens=$null; $errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
        foreach ($command in $ast.FindAll({param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.Extent.Text -match '-DateKind\b'},$true)) {
            $parent=$command.Parent
            while ($parent -and $parent -isnot [Management.Automation.Language.IfStatementAst]) { $parent=$parent.Parent }
            Assert-True ($parent -and $parent.Clauses[0].Item1.Extent.Text -match "Parameters.ContainsKey\('DateKind'\)") 'DateKind requires parameter-exists check'
        }
    }
}
