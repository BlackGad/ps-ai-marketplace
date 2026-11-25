function Get-ToolInstallData {
    param([string]$Tool)
    $recipes = Get-LegionInstallRecipes
    if (-not $recipes.ContainsKey($Tool)) { throw "unknown tool '$Tool'" }
    return $recipes[$Tool]
}

function Test-ToolCommandAvailable {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-ToolInstalled {
    param([string]$Tool)
    $check = (Get-ToolInstallData -Tool $Tool).check
    $name = $check[0]
    $command = $null
    if (Test-ToolCommandAvailable -Name $name) { $command = $name }
    # Installers update the saved PATH, while the current shell keeps its old copy.
    elseif (Find-LegionPersistentCommand -Name $name) { return @{ Installed=$true; Version='persisted PATH' } }
    if (-not $command) { return @{ Installed=$false; Version='' } }
    try {
        $arguments = [string[]]@($check | Select-Object -Skip 1)
        $global:LASTEXITCODE = 0
        $versionLines = @(& $command @arguments 2>$null)
        if ($LASTEXITCODE -ne 0) { return @{ Installed=$false; Version='' } }
        $version = $versionLines | Select-Object -First 1
        return @{ Installed=$true; Version=([string]$version).Trim() }
    } catch { return @{ Installed=$false; Version='' } }
}

# The CLI installer's recipe. The descriptors own prerequisites and commands.
function Get-ToolRecipe {
    param([string]$Tool, [ValidateSet('windows','macos','linux')][string]$Platform, $Recipes = (Get-LegionInstallRecipes))
    $data = $Recipes[$Tool]
    if (-not $data) { throw "unknown tool '$Tool'" }
    if ($Platform -eq 'windows') {
        return [pscustomobject]@{ Install = @(,([string[]]@('winget', 'install', '--id', $data.windows.wingetId, '-e', '--source', 'winget', '--accept-source-agreements', '--accept-package-agreements'))); Needs = @(); Docs = '' }
    }
    return [pscustomobject]@{ Install = [object[]]@($data.$Platform.commands); Needs = [string[]]@($data.$Platform.needs); Docs = $data.$Platform.docs }
}
