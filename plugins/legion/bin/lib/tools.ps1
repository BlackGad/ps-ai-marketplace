function ConvertFrom-LegionJsonElement {
    param([System.Text.Json.JsonElement]$Element)

    switch ($Element.ValueKind) {
        Object {
            $values = [ordered]@{}
            foreach ($property in $Element.EnumerateObject()) {
                $values[$property.Name] = ConvertFrom-LegionJsonElement -Element $property.Value
            }
            return [pscustomobject]$values
        }
        Array {
            $items = [System.Collections.Generic.List[object]]::new()
            foreach ($item in $Element.EnumerateArray()) { $items.Add((ConvertFrom-LegionJsonElement -Element $item)) }
            return ,$items.ToArray()
        }
        String { return $Element.GetString() }
        Number {
            $integer = 0L
            if ($Element.TryGetInt64([ref]$integer)) { return $integer }
            return $Element.GetDouble()
        }
        True { return $true }
        False { return $false }
        Null { return $null }
    }
}

function ConvertFrom-LegionToolJson {
    param([string]$Json)

    # Keep argv strings intact on all PowerShell 7 versions, including date-like text.
    $document = [System.Text.Json.JsonDocument]::Parse($Json)
    try { return ConvertFrom-LegionJsonElement -Element $document.RootElement }
    finally { $document.Dispose() }
}

# Descriptors are validated by tools/update-tools-index.ps1 before shipping.
function Get-LegionTools {
    param([string]$SkillsRoot = (Join-Path $PSScriptRoot '../../skills'))

    $tools = [System.Collections.Generic.List[object]]::new()
    foreach ($folder in (Get-ChildItem -LiteralPath $SkillsRoot -Directory -Filter 'legion-*' -ErrorAction Stop)) {
        $path = Join-Path $folder.FullName 'tool.json'
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $tool = ConvertFrom-LegionToolJson -Json ([IO.File]::ReadAllText($path))
        $tool | Add-Member -NotePropertyName SkillRoot -NotePropertyValue $folder.FullName
        $tools.Add($tool)
    }
    $tools.Sort([Comparison[object]]{ param($left, $right) [StringComparer]::Ordinal.Compare($left.id, $right.id) })
    $tools
}

function Get-LegionTool {
    param([string]$Tool, [string]$SkillsRoot = (Join-Path $PSScriptRoot '../../skills'))

    $tools = @(Get-LegionTools -SkillsRoot $SkillsRoot)
    $selected = $tools | Where-Object { $_.id -ceq $Tool }
    if ($null -eq $selected) { throw "unknown tool '$Tool'" }
    return $selected
}

function Get-LegionInstallRecipes {
    param(
        [string]$SkillsRoot = (Join-Path $PSScriptRoot '../../skills'),
        [string]$HelpersPath = (Join-Path $PSScriptRoot '../install-tool/helpers.json')
    )

    $tools = @(Get-LegionTools -SkillsRoot $SkillsRoot)
    # Helpers are read only for installation; the private launch runtime omits them.
    $resolvedHelpersPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($HelpersPath)
    $json = [IO.File]::ReadAllText($resolvedHelpersPath)
    $helpers = ConvertFrom-LegionToolJson -Json $json
    $recipes = @{}
    foreach ($helper in $helpers.PSObject.Properties) {
        $recipes[$helper.Name] = $helper.Value
    }
    foreach ($tool in $tools) {
        $recipes[$tool.id] = $tool.install
    }
    return $recipes
}
