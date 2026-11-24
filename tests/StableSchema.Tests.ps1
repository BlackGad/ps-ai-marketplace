$repo = Split-Path $PSScriptRoot -Parent
$template = Get-Content (Join-Path $repo 'plugins/legion/skills/legion-repository/references/project-template.json') -Raw | ConvertFrom-Json
Assert-Equal 'https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/plugins/legion/schemas/project.schema.json' $template.'$schema' 'Project template uses a stable schema reference'
foreach ($schemaFile in Get-ChildItem (Join-Path $repo 'plugins/legion/schemas') -Filter '*.schema.json') {
    Assert-Equal 'http://json-schema.org/draft-07/schema#' ((Get-Content $schemaFile.FullName -Raw | ConvertFrom-Json).'$schema') "$($schemaFile.Name) is draft 7"
}
