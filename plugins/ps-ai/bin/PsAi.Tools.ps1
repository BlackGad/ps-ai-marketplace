function ConvertFrom-PsAiJsonElement {
    param([System.Text.Json.JsonElement]$Element)

    switch ($Element.ValueKind) {
        Object {
            $values = [ordered]@{}
            foreach ($property in $Element.EnumerateObject()) {
                $values[$property.Name] = ConvertFrom-PsAiJsonElement -Element $property.Value
            }
            return [pscustomobject]$values
        }
        Array {
            $items = [System.Collections.Generic.List[object]]::new()
            foreach ($item in $Element.EnumerateArray()) { $items.Add((ConvertFrom-PsAiJsonElement -Element $item)) }
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

function ConvertFrom-PsAiToolJson {
    param([string]$Json)

    # Keep argv strings intact on all PowerShell 7 versions, including date-like text.
    $document = [System.Text.Json.JsonDocument]::Parse($Json)
    try { return ConvertFrom-PsAiJsonElement -Element $document.RootElement }
    finally { $document.Dispose() }
}

function Assert-PsAiRegex {
    param([string]$Pattern, [string]$Field)

    try { $null = [regex]::new($Pattern) }
    catch { throw "invalid regex in $Field" }
}

function Assert-PsAiInstallPatterns {
    param($Install)

    foreach ($method in @('msi', 'zip')) {
        $download = $Install.windows.download.$method
        foreach ($field in @('assetPattern', 'tagPattern')) {
            if ($null -ne $download.$field) { Assert-PsAiRegex -Pattern $download.$field -Field "install.windows.download.$method.$field" }
        }
    }
}

function Get-PsAiTools {
    param([string]$SkillsRoot = (Join-Path $PSScriptRoot '../skills'))

    $schemaPath = Join-Path $PSScriptRoot '../schemas/tool.schema.json'
    $tools = [System.Collections.Generic.List[object]]::new()
    $folders = [string[]]@(Get-ChildItem -LiteralPath $SkillsRoot -Directory -Filter 'ps-ai-*' -ErrorAction Stop | ForEach-Object FullName)
    [Array]::Sort($folders, [StringComparer]::Ordinal)
    foreach ($folder in $folders) {
        $path = Join-Path $folder 'tool.json'
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        try {
            $json = [IO.File]::ReadAllText($path)
            $tool = ConvertFrom-PsAiToolJson -Json $json
        } catch { throw "invalid tool descriptor '$path': malformed JSON" }
        if ($tool.schemaVersion -ne 1) { throw "invalid tool descriptor '$path': unsupported schemaVersion" }
        if (-not (Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction SilentlyContinue)) {
            throw "invalid tool descriptor '$path': schema validation failed"
        }
        if ($tool.plugin.listing.format -eq 'lines') {
            Assert-PsAiRegex -Pattern $tool.plugin.listing.rejectPattern -Field 'plugin.listing.rejectPattern'
        }
        Assert-PsAiInstallPatterns -Install $tool.install
        $tool | Add-Member -NotePropertyName SkillRoot -NotePropertyValue $folder
        $tools.Add($tool)
    }

    # Check duplicate ids first, so a mismatched folder cannot hide the collision.
    $ids = @()
    foreach ($tool in $tools) {
        if ($tool.id -cin $ids) { throw "duplicate tool id '$($tool.id)'" }
        $ids += $tool.id
    }
    foreach ($tool in $tools) {
        if ((Split-Path $tool.SkillRoot -Leaf) -cne "ps-ai-$($tool.id)") {
            throw "tool id '$($tool.id)' does not match its skill directory"
        }
        if (-not (Test-Path -LiteralPath (Join-Path $tool.SkillRoot 'SKILL.md') -PathType Leaf)) {
            throw "tool '$($tool.id)' requires SKILL.md"
        }
        if ($null -ne $tool.foundry) { $null = Get-PsAiToolScript -Tool $tool -Name foundry-launch }
    }
    $tools.Sort([Comparison[object]]{ param($left, $right) [StringComparer]::Ordinal.Compare($left.id, $right.id) })
    $tools
}

function Get-PsAiTool {
    param([string]$Tool, [string]$SkillsRoot = (Join-Path $PSScriptRoot '../skills'))

    if ($Tool -cnotmatch '^[a-z][a-z0-9-]*$') { throw "unknown tool '$Tool'" }
    $tools = @(Get-PsAiTools -SkillsRoot $SkillsRoot)
    $selected = $tools | Where-Object { $_.id -ceq $Tool }
    if ($null -eq $selected) { throw "unknown tool '$Tool'" }
    return $selected
}

function Get-PsAiToolScript {
    param($Tool, [ValidateSet('foundry-launch', 'foundry-config')][string]$Name)

    if ($null -eq $Tool.foundry) { throw "tool '$($Tool.id)' does not support Foundry" }
    $path = Join-Path $Tool.SkillRoot "scripts/$Name.ps1"
    if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    if ($Name -eq 'foundry-launch') { throw "tool '$($Tool.id)' requires scripts/foundry-launch.ps1" }
    return $null
}

function Get-PsAiInstallRecipes {
    param(
        [string]$SkillsRoot = (Join-Path $PSScriptRoot '../skills'),
        [string]$HelpersPath = (Join-Path $PSScriptRoot 'install-tool/helpers.json')
    )

    $tools = @(Get-PsAiTools -SkillsRoot $SkillsRoot)
    # Helpers are read only for installation; the private launch runtime omits them.
    $resolvedHelpersPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($HelpersPath)
    $json = [IO.File]::ReadAllText($resolvedHelpersPath)
    $schema = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../schemas/tool.schema.json') -Raw | ConvertFrom-Json -AsHashtable
    $helpersSchema = @{
        '$schema' = $schema.'$schema'
        '$defs' = $schema.'$defs'
        type = 'object'
        propertyNames = @{ pattern = '^[a-z][a-z0-9-]*$' }
        additionalProperties = @{ '$ref' = '#/$defs/install' }
    } | ConvertTo-Json -Depth 100
    if (-not (Test-Json -Json $json -Schema $helpersSchema -ErrorAction SilentlyContinue)) {
        throw "invalid helper recipes '$HelpersPath': schema validation failed"
    }
    $helpers = ConvertFrom-PsAiToolJson -Json $json
    $recipes = @{}
    foreach ($helper in $helpers.PSObject.Properties) {
        Assert-PsAiInstallPatterns -Install $helper.Value
        $recipes[$helper.Name] = $helper.Value
    }
    foreach ($tool in $tools) {
        if ($recipes.ContainsKey($tool.id)) { throw "helper/tool id collision '$($tool.id)'" }
        $recipes[$tool.id] = $tool.install
    }
    return $recipes
}
