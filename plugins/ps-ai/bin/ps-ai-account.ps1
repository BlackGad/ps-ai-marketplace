param(
    [ValidateSet('add', 'rename', 'remove', 'register', 'models')][string]$Action,
    [string]$Id,
    [string]$Tool,
    [string]$NewId,
    [string]$Command,
    [string]$ConfigDir,
    [ValidateSet('foundry')][string]$Provider,
    [string]$Endpoint,
    [string[]]$Deployments,
    [string]$Default,
    [string[]]$Aliases,
    [switch]$List,
    [string]$HomeRoot = $HOME,
    [switch]$NoRun
)

$accountNoRun = $NoRun
. (Join-Path $PSScriptRoot 'ps-ai-validate.ps1') -NoRun
. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/foundry.ps1')
. (Join-Path $PSScriptRoot 'lib/tools.ps1')

function Assert-PsAiId {
    param([string]$Id)
    if ($Id -cnotmatch '^[a-z][a-z0-9-]*$') { throw "id '$Id' must match ^[a-z][a-z0-9-]*$" }
}

function Assert-PsAiNewId {
    param([string]$Id, $Data)
    Assert-PsAiId -Id $Id
    if (@($Data.agents | Where-Object { $_.id -ceq $Id }).Count) { throw "account '$Id' already exists" }
    if (Get-Command $Id -ErrorAction SilentlyContinue) { throw "'$Id' is already a command" }
}

function Update-PsAiRouting {
    param($Routing, [string]$OldId, [string]$NewId)
    if ($null -eq $Routing) { return }
    foreach ($key in @('implement', 'review', 'mechanical')) {
        $property = $Routing.PSObject.Properties[$key]
        if ($null -eq $property) { continue }
        $values = @($property.Value)
        if ($NewId) {
            for ($i = 0; $i -lt $values.Count; $i++) {
                if ($values[$i] -ceq $OldId) { $values[$i] = $NewId }
            }
        } else {
            $values = @($values | Where-Object { $_ -cne $OldId })
        }
        $property.Value = $values
    }
}

function Update-AllPsAiRouting {
    param($Data, [string]$OldId, [string]$NewId)
    Update-PsAiRouting -Routing $Data.routing -OldId $OldId -NewId $NewId
    foreach ($project in $Data.projects.PSObject.Properties) {
        Update-PsAiRouting -Routing $project.Value.routing -OldId $OldId -NewId $NewId
    }
}

function Write-PsAiPersonalisation {
    param($Data, [string]$Path)
    $original = [System.IO.File]::ReadAllText($Path)
    $json = $Data | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($Path, $json + "`n", [System.Text.UTF8Encoding]::new($false))
    $issues = @(Invoke-PsAiValidation -Kind personalisation -Path $Path)
    if ($issues.Count) {
        [System.IO.File]::WriteAllText($Path, $original, [System.Text.UTF8Encoding]::new($false))
        throw ($issues -join '; ')
    }
}

function ConvertTo-PsAiShellLiteral {
    param([string]$Value)
    return "'" + $Value.Replace("'", "'" + '"' + "'" + '"' + "'") + "'"
}

function Write-PsAiGeneratedFile {
    param([string]$Path, [string]$Content, [Collections.Generic.List[string]]$Changes, [switch]$Executable)
    if ((Test-Path -LiteralPath $Path) -and [IO.File]::ReadAllText($Path) -ceq $Content) { return }
    New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
    if ($Executable -and -not $IsWindows) {
        & chmod +x $Path
        if ($LASTEXITCODE -ne 0) { throw 'could not make the generated wrapper executable' }
    }
    if ($null -ne $Changes) { $Changes.Add($Path) }
}

function New-PsAiWrappers {
    param([string]$Id, [string]$Tool, [string]$HomeRoot, [string]$RealCommand, [string]$ConfigDir)
    $bin = Join-Path $HomeRoot '.agents/bin'
    $folder = if ($ConfigDir) { $ConfigDir } else { Join-Path $HomeRoot ".agents/accounts/$Id" }
    if ($folder -match '^~[/\\]') { $folder = Join-Path $HomeRoot $folder.Substring(2) }
    $folder = [IO.Path]::GetFullPath($folder)
    New-Item -ItemType Directory -Path $bin, $folder -Force | Out-Null
    $envName = Get-ConfigEnvName -Tool $Tool
    $target = ConvertTo-PsAiShellLiteral $RealCommand
    if ([IO.Path]::GetExtension($RealCommand) -ieq '.ps1') { $target = 'pwsh -NoProfile -File ' + $target }
    $sh = '#!/bin/sh' + "`n" + ('{0}={1} exec {2} "$@"' -f $envName, (ConvertTo-PsAiShellLiteral $folder), $target)
    [System.IO.File]::WriteAllText((Join-Path $bin $Id), $sh + "`n", [System.Text.UTF8Encoding]::new($false))
    if (-not $IsWindows) { & chmod +x (Join-Path $bin $Id) }
    if ($IsWindows) {
        $target = $RealCommand.Replace('%', '%%')
        $invoke = if ([IO.Path]::GetExtension($RealCommand) -ieq '.ps1') {
            '@pwsh -NoProfile -File "' + $target + '" %*'
        } elseif ([IO.Path]::GetExtension($RealCommand) -in @('.cmd', '.bat')) {
            '@call "' + $target + '" %*'
        } else { '@"' + $target + '" %*' }
        $cmd = "@setlocal`r`n@set `"$envName=$($folder.Replace('%', '%%'))`"`r`n$invoke`r`n@exit /b %errorlevel%`r`n"
        [System.IO.File]::WriteAllText((Join-Path $bin "$Id.cmd"), $cmd, [System.Text.UTF8Encoding]::new($false))
    }
}

function Get-PsAiWrapperCommand {
    param([string]$Id)
    if ($IsWindows) { return "~/.agents/bin/$Id.cmd" }
    return "~/.agents/bin/$Id"
}

function Write-FoundryToolConfig {
    param($Agent, [string]$HomeRoot)
    $tool = Get-PsAiTool -Tool $Agent.tool
    $script = Get-PsAiToolScript -Tool $tool -Name foundry-config
    if (-not $script) { return @{ Changed = $false; Path = $null } }
    return & $script -Agent $Agent -HomeRoot $HomeRoot
}

function Sync-PsAiFoundryRuntime {
    param([string]$Tool, [string]$HomeRoot, [Collections.Generic.List[string]]$Changes)
    $descriptor = Get-PsAiTool -Tool $Tool
    $null = Get-PsAiToolScript -Tool $descriptor -Name foundry-launch
    $runtime = [IO.Path]::GetFullPath((Join-Path $HomeRoot '.agents/bin/.ps-ai-runtime'))
    $pluginRoot = Split-Path $PSScriptRoot -Parent
    $files = [ordered]@{}
    foreach ($name in @('lib/tools.ps1', 'lib/foundry.ps1')) {
        $files["bin/$name"] = Join-Path $PSScriptRoot $name
    }
    $files['schemas/tool.schema.json'] = Join-Path $pluginRoot 'schemas/tool.schema.json'
    foreach ($name in @('SKILL.md', 'tool.json')) {
        $files["skills/ps-ai-$Tool/$name"] = Join-Path $descriptor.SkillRoot $name
    }
    foreach ($script in Get-ChildItem -LiteralPath (Join-Path $descriptor.SkillRoot 'scripts') -File -Filter 'foundry-*.ps1') {
        $files["skills/ps-ai-$Tool/scripts/$($script.Name)"] = $script.FullName
    }
    # Publish the runner only after its dependencies exist.
    $files['bin/ps-ai-foundry.ps1'] = Join-Path $PSScriptRoot 'ps-ai-foundry.ps1'
    foreach ($relativePath in $files.Keys) {
        $target = Join-Path $runtime $relativePath
        $bytes = [IO.File]::ReadAllBytes($files[$relativePath])
        if ((Test-Path -LiteralPath $target) -and [Convert]::ToBase64String([IO.File]::ReadAllBytes($target)) -ceq [Convert]::ToBase64String($bytes)) { continue }
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        [IO.File]::WriteAllBytes($target, $bytes)
        if ($null -ne $Changes) { $Changes.Add($target) }
    }
    return Join-Path $runtime 'bin/ps-ai-foundry.ps1'
}

function New-FoundryWrappers {
    param([string]$Id, [string]$HomeRoot, [string]$Tool, [Collections.Generic.List[string]]$Changes)
    $runner = Sync-PsAiFoundryRuntime -Tool $Tool -HomeRoot $HomeRoot -Changes $Changes
    $bin = Join-Path $HomeRoot '.agents/bin'
    $shPath = ConvertTo-PsAiShellLiteral $runner
    $sh = '#!/bin/sh' + "`n" + ('exec pwsh -NoProfile -File {0} -Agent {1} "$@"' -f $shPath, $Id) + "`n"
    Write-PsAiGeneratedFile -Path (Join-Path $bin $Id) -Content $sh -Changes $Changes -Executable
    $cmd = "@pwsh -NoProfile -File `"$($runner.Replace('%', '%%'))`" -Agent $Id %*`r`n"
    Write-PsAiGeneratedFile -Path (Join-Path $bin "$Id.cmd") -Content $cmd -Changes $Changes
}

function Get-PsAiFoundryDiscovery {
    param([string]$Endpoint, [string]$Tool)
    $descriptor = Get-PsAiTool -Tool $Tool
    $null = Get-PsAiToolScript -Tool $descriptor -Name foundry-launch
    $check = Test-FoundryToken -Login
    if (-not $check.Ok) { throw $check.Error }
    Get-FoundryDeployments -Endpoint $Endpoint -Tool $Tool
}

function Write-PsAiFoundryList {
    param($Discovery, $Existing)
    $rows = @($Discovery.Deployments | ForEach-Object {
        $state = if ($_.name -cin @($Existing.name)) { 'kept' } else { 'new' }
        @{ name = $_.name; model = $_.model; state = $state }
    })
    foreach ($deployment in $Existing) {
        if ($deployment.name -cnotin @($Discovery.Deployments.name)) {
            $state = if ($Discovery.Source -eq 'management') { 'gone' } else { 'kept' }
            $rows += @{ name = $deployment.name; model = $deployment.model; state = $state }
        }
    }
    @{ source = $Discovery.Source; error = $Discovery.Error; deployments = @($rows) } | ConvertTo-Json -Depth 100
}

function New-PsAiFoundryProvider {
    param([string]$Endpoint, [string]$Tool, [string[]]$Deployments, [string]$Default, [string[]]$Aliases, $Discovery, $Existing)
    $descriptor = Get-PsAiTool -Tool $Tool
    $null = Get-PsAiToolScript -Tool $descriptor -Name foundry-launch
    if (-not $Deployments.Count -or -not $Default) { throw 'Foundry requires -Deployments and -Default' }
    if ($Default -cnotin $Deployments) { throw "default '$Default' is not one of -Deployments" }
    $aliasMap = @{}
    if ($null -eq $Aliases) {
        foreach ($item in $Existing) { if ($item.alias) { $aliasMap[$item.name] = $item.alias } }
    } else {
        foreach ($pair in $Aliases) {
            $parts = $pair -csplit '=', 2
            if ($parts.Count -ne 2 -or $parts[0] -cnotin $Deployments -or $parts[1] -cnotin @($descriptor.foundry.aliases)) { throw "invalid alias '$pair'; use name=alias for a selected deployment" }
            if ($aliasMap.ContainsKey($parts[0])) { throw "duplicate alias mapping for '$($parts[0])'" }
            $aliasMap[$parts[0]] = $parts[1]
        }
    }
    $items = @($Deployments | ForEach-Object {
        $name = $_
        $item = [ordered]@{ name = $name }
        $known = @($Discovery.Deployments | Where-Object { $_.name -ceq $name })[0]
        if (-not $known) { $known = @($Existing | Where-Object { $_.name -ceq $name })[0] }
        if ($known.model) { $item.model = $known.model }
        if ($aliasMap.ContainsKey($name)) { $item.alias = $aliasMap[$name] }
        [pscustomobject]$item
    })
    $provider = [pscustomobject]@{ kind = 'foundry'; endpoint = $Endpoint; default = $Default; deployments = $items }
    $issues = @(Get-PsAiProviderIssues -Data ([pscustomobject]@{ agents = @([pscustomobject]@{ tool = $Tool; provider = $provider }) }))
    if ($issues.Count) { throw ($issues -join '; ') }
    return $provider
}

function Move-PsAiWrappers {
    param([string]$OldId, [string]$NewId, [string]$HomeRoot)
    $bin = Join-Path $HomeRoot '.agents/bin'
    foreach ($suffix in @('', '.cmd')) {
        $old = Join-Path $bin "$OldId$suffix"
        if (Test-Path -LiteralPath $old) { Move-Item -LiteralPath $old -Destination (Join-Path $bin "$NewId$suffix") }
    }
}

function Remove-PsAiWrappers {
    param([string]$Id, [string]$HomeRoot)
    $bin = Join-Path $HomeRoot '.agents/bin'
    foreach ($suffix in @('', '.cmd')) {
        $path = Join-Path $bin "$Id$suffix"
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
}

if ($accountNoRun) { return }

$file = Join-Path $HomeRoot '.agents/configuration/ps-ai-personalisation.json'
$data = Read-PsAiJson -Path $file
switch ($Action) {
    add {
        $descriptor = Get-PsAiTool -Tool $Tool
        $existing = @($data.agents | Where-Object { $_.id -ceq $Id })[0]
        if ($Provider -eq 'foundry') {
            if ($ConfigDir) { throw '-ConfigDir is for existing subscription accounts; omit it for Foundry.' }
            $null = Get-PsAiToolScript -Tool $descriptor -Name foundry-launch
            Assert-PsAiId -Id $Id
            $null = Get-ConfigEnvName -Tool $Tool
            $Endpoint = ConvertTo-FoundryEndpoint -Url $Endpoint
            if (-not $List -and $existing -and $existing.tool -ceq $Tool -and $existing.provider.kind -ceq $Provider -and $existing.provider.endpoint -ceq $Endpoint) {
                "skip: account $Id (already done)"
                break
            }
            $discovery = Get-PsAiFoundryDiscovery -Endpoint $Endpoint -Tool $Tool
            if ($List) { Write-PsAiFoundryList -Discovery $discovery -Existing @(); break }
            Assert-PsAiNewId -Id $Id -Data $data
            $providerBlock = New-PsAiFoundryProvider -Endpoint $Endpoint -Tool $Tool -Deployments $Deployments -Default $Default -Aliases $Aliases -Discovery $discovery
            $entry = [pscustomobject]@{
                id = $Id; tool = $Tool; command = (Get-PsAiWrapperCommand $Id); configDir = "~/.agents/accounts/$Id"; roles = @(); provider = $providerBlock
            }
            $null = Write-FoundryToolConfig -Agent $entry -HomeRoot $HomeRoot
            $data.agents = @($data.agents) + @($entry)
            Write-PsAiPersonalisation -Data $data -Path $file
            New-FoundryWrappers -Id $Id -HomeRoot $HomeRoot -Tool $Tool
            "Run '$Id' in a terminal; it signs in to Azure through az when needed."
            break
        }
        $accountDir = if ($ConfigDir) { $ConfigDir } else { "~/.agents/accounts/$Id" }
        if ($ConfigDir) {
            $folder = $ConfigDir
            if ($folder -match '^~[/\\]') { $folder = Join-Path $HomeRoot $folder.Substring(2) }
            if (-not (Test-Path -LiteralPath $folder -PathType Container)) { throw 'Existing account config folder does not exist.' }
            $folder = (Resolve-Path -LiteralPath $folder -ErrorAction Stop).ProviderPath
            if ($ConfigDir -notmatch '^~[/\\]') { $accountDir = $folder }
        }
        if ($null -ne $existing -and -not $existing.provider -and $existing.tool -ceq $Tool -and $existing.command -ceq (Get-PsAiWrapperCommand $Id) -and $existing.configDir -ceq $accountDir) {
            "skip: account $Id (already done)"
            break
        }
        Assert-PsAiNewId -Id $Id -Data $data
        $null = Get-ConfigEnvName -Tool $Tool
        $realCommand = if ($Command) { $Command } else { (Get-Command (Get-PsAiTool -Tool $Tool).command -ErrorAction Stop).Source }
        $entry = [pscustomobject]@{
            id = $Id; tool = $Tool; command = (Get-PsAiWrapperCommand $Id); configDir = $accountDir; roles = @()
        }
        $data.agents = @($data.agents) + @($entry)
        Write-PsAiPersonalisation -Data $data -Path $file
        New-PsAiWrappers -Id $Id -Tool $Tool -HomeRoot $HomeRoot -RealCommand $realCommand -ConfigDir $accountDir
        if ($ConfigDir) { "Existing account folder kept at $ConfigDir; use '$Id' to open it." }
        else { "Run '$Id' in a terminal and log in once." }
    }
    models {
        $agent = @($data.agents | Where-Object { $_.id -ceq $Id })[0]
        if (-not $agent) { throw "unknown account '$Id'" }
        if ($agent.provider.kind -cne 'foundry') { throw "account '$Id' is not a Foundry agent" }
        $discovery = Get-PsAiFoundryDiscovery -Endpoint $agent.provider.endpoint -Tool $agent.tool
        if ($List) { Write-PsAiFoundryList -Discovery $discovery -Existing $agent.provider.deployments; break }
        $providerBlock = New-PsAiFoundryProvider -Endpoint $agent.provider.endpoint -Tool $agent.tool -Deployments $Deployments -Default $Default -Aliases $Aliases -Discovery $discovery -Existing $agent.provider.deployments
        if (($providerBlock | ConvertTo-Json -Depth 100 -Compress) -ceq ($agent.provider | ConvertTo-Json -Depth 100 -Compress)) {
            "skip: models $Id (no changes)"
            break
        }
        $agent.provider = $providerBlock
        $null = Write-FoundryToolConfig -Agent $agent -HomeRoot $HomeRoot
        Write-PsAiPersonalisation -Data $data -Path $file
        New-FoundryWrappers -Id $Id -HomeRoot $HomeRoot -Tool $agent.tool
    }
    register {
        $null = Get-PsAiTool -Tool $Tool
        Assert-PsAiId -Id $Id
        $existing = @($data.agents | Where-Object { $_.id -ceq $Id })[0]
        if ($null -ne $existing -and $existing.tool -ceq $Tool -and $existing.command -ceq $Command -and $existing.configDir -ceq $ConfigDir) {
            "skip: account $Id (already done)"
            break
        }
        if (@($data.agents | Where-Object { $_.id -ceq $Id }).Count) { throw "account '$Id' already exists" }
        $null = Get-ConfigEnvName -Tool $Tool
        if (-not $Command -or -not $ConfigDir) { throw 'register requires -Command and -ConfigDir' }
        $entry = [pscustomobject]@{ id = $Id; tool = $Tool; command = $Command; configDir = $ConfigDir; roles = @() }
        $data.agents = @($data.agents) + @($entry)
        Write-PsAiPersonalisation -Data $data -Path $file
    }
    rename {
        $old = @($data.agents | Where-Object { $_.id -ceq $Id })[0]
        $new = @($data.agents | Where-Object { $_.id -ceq $NewId })[0]
        if ($null -eq $old -and $null -ne $new) {
            "skip: account rename $Id to $NewId (already done)"
            break
        }
        Assert-PsAiNewId -Id $NewId -Data $data
        $agent = @($data.agents | Where-Object { $_.id -ceq $Id })[0]
        if ($null -eq $agent) { throw "unknown account '$Id'" }
        $oldCommand = $agent.command
        $agent.id = $NewId
        $wrapper = Get-PsAiWrapperCommand $Id
        $owned = @($wrapper, (Join-Path $HomeRoot $wrapper.Substring(2)))
        if ($oldCommand -in $owned) {
            $agent.command = Get-PsAiWrapperCommand $NewId
        } else {
            "command kept at $oldCommand; rename the wrapper yourself if you want to"
        }
        Update-AllPsAiRouting -Data $data -OldId $Id -NewId $NewId
        Write-PsAiPersonalisation -Data $data -Path $file
        Move-PsAiWrappers -OldId $Id -NewId $NewId -HomeRoot $HomeRoot
        if ($agent.provider.kind -eq 'foundry' -and $oldCommand -in $owned) { New-FoundryWrappers -Id $NewId -HomeRoot $HomeRoot -Tool $agent.tool }
        "Config folder kept at $($agent.configDir); rename it yourself only if you want to."
    }
    remove {
        $agent = @($data.agents | Where-Object { $_.id -ceq $Id })[0]
        if ($null -eq $agent) { "skip: account remove $Id (already done)"; break }
        $data.agents = @($data.agents | Where-Object { $_.id -cne $Id })
        Update-AllPsAiRouting -Data $data -OldId $Id -NewId ''
        Write-PsAiPersonalisation -Data $data -Path $file
        Remove-PsAiWrappers -Id $Id -HomeRoot $HomeRoot
        "Config folder kept at $($agent.configDir)."
    }
}
