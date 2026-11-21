# Shared by setup consent and the CLI installer. The descriptors own prerequisites and commands.
function Get-ToolRecipe {
    param([string]$Tool, [ValidateSet('windows','macos','linux')][string]$Platform, $Recipes = (Get-LegionInstallRecipes))
    $data = $Recipes[$Tool]
    if (-not $data) { throw "unknown tool '$Tool'" }
    if ($Platform -eq 'windows') {
        return [pscustomobject]@{ Install = @(,([string[]]@('winget', 'install', '--id', $data.windows.wingetId, '-e', '--source', 'winget', '--accept-source-agreements', '--accept-package-agreements'))); Needs = @(); Docs = '' }
    }
    return [pscustomobject]@{ Install = [object[]]@($data.$Platform.commands); Needs = [string[]]@($data.$Platform.needs); Docs = $data.$Platform.docs }
}

function Get-ToolInstallHints {
    param([string]$Tool, [string]$Platform, [scriptblock]$CommandAvailable, [scriptblock]$ToolInstalled, $Recipes = (Get-LegionInstallRecipes))
    $recipe = Get-ToolRecipe -Tool $Tool -Platform $Platform -Recipes $Recipes
    foreach ($need in $recipe.Needs) {
        if (-not (& $ToolInstalled $need)) {
            Get-ToolInstallHints -Tool $need -Platform $Platform -CommandAvailable $CommandAvailable -ToolInstalled $ToolInstalled -Recipes $Recipes
        }
    }
    $npm = $Recipes[$Tool].windows.npmWhenAvailable
    if ($Platform -eq 'windows' -and $npm -and (& $CommandAvailable $npm.check)) { $npm.command -join ' '; return }
    if (-not $recipe.Install.Count) { $recipe.Docs; return }
    foreach ($command in $recipe.Install) { $command -join ' ' }
}
