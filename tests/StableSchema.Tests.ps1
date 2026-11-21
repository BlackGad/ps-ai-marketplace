$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/bin/legion-account.ps1') -NoRun
    $sandbox = Join-Path $repo ('.agents/temp/stable-schema-' + [guid]::NewGuid().ToString('N'))
    $path = Join-Path $sandbox 'personalisation.json'
    $stable = 'https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/plugins/ps-ai/schemas/personalisation.schema.json'
    try {
        New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
        $data = Get-Content (Join-Path $PSScriptRoot 'fixtures/personalisation/valid-owner.json') -Raw | ConvertFrom-Json
        foreach ($old in @('C:/Users/example/.codex/plugins/cache/ps-ai-marketplace/ps-ai/0.4.1/schemas/personalisation.schema.json', '/home/example/.claude/plugins/cache/ps-ai-marketplace/ps-ai/0.4.1/schemas/personalisation.schema.json', $stable)) {
            $data.'$schema' = $old
            $data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path
            Write-LegionPersonalisation -Data $data -Path $path
            $saved = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            Assert-Equal $stable $saved.'$schema' 'Personalisation rewrite stores a stable schema reference'
        }
        $data.PSObject.Properties.Remove('$schema')
        Write-LegionPersonalisation -Data $data -Path $path
        Assert-Equal 0 @(Invoke-LegionValidation -Kind personalisation -Path $path).Count 'Schema metadata is optional'
        $data | Add-Member '$schema' 'https://invalid.example/never-fetch-this.json'
        $data.schemaVersion = 999
        $data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path
        Assert-True (@(Invoke-LegionValidation -Kind personalisation -Path $path).Count -gt 0) 'Validation uses bundled schema regardless of schema metadata'
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe fixture cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
$template = Get-Content (Join-Path $repo 'plugins/ps-ai/skills/legion-repository/references/project-template.json') -Raw | ConvertFrom-Json
Assert-Equal 'https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/plugins/ps-ai/schemas/project.schema.json' $template.'$schema' 'Project template uses a stable schema reference'
