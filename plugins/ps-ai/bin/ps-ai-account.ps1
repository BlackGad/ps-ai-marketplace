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
    [string]$HomeRoot = $HOME
)

. (Join-Path $PSScriptRoot 'ps-ai-validate.ps1') -NoRun
. (Join-Path $PSScriptRoot 'PsAi.Common.ps1')
. (Join-Path $PSScriptRoot 'PsAi.Foundry.ps1')
. (Join-Path $PSScriptRoot 'PsAi.Tools.ps1')

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

function New-PsAiWrappers {
    param([string]$Id, [string]$Tool, [string]$HomeRoot, [string]$RealCommand)
    $bin = Join-Path $HomeRoot '.agents/bin'
    $folder = Join-Path $HomeRoot ".agents/accounts/$Id"
    New-Item -ItemType Directory -Path $bin, $folder -Force | Out-Null
    $envName = Get-ConfigEnvName -Tool $Tool
    $sh = '#!/bin/sh' + "`n" + ('{0}="{1}" exec "{2}" "$@"' -f $envName, $folder, $RealCommand)
    [System.IO.File]::WriteAllText((Join-Path $bin $Id), $sh + "`n", [System.Text.UTF8Encoding]::new($false))
    if (-not $IsWindows) { & chmod +x (Join-Path $bin $Id) }
    if ($IsWindows) {
        $cmd = "@set `"$envName=$folder`"`r`n@`"$RealCommand`" %*`r`n"
        [System.IO.File]::WriteAllText((Join-Path $bin "$Id.cmd"), $cmd, [System.Text.UTF8Encoding]::new($false))
    }
}

function Write-FoundryToolConfig {
    param($Agent, [string]$HomeRoot)
    $tool = Get-PsAiTool -Tool $Agent.tool
    $script = Get-PsAiToolScript -Tool $tool -Name foundry-config
    if (-not $script) { return @{ Changed = $false; Path = $null } }
    return & $script -Agent $Agent -HomeRoot $HomeRoot
}

function New-FoundryWrappers {
    param([string]$Id, [string]$HomeRoot)
    $bin = Join-Path $HomeRoot '.agents/bin'
    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    foreach ($name in @('ps-ai-foundry.ps1', 'PsAi.Foundry.ps1')) {
        $source = Join-Path $PSScriptRoot $name
        $target = Join-Path $bin $name
        $content = [IO.File]::ReadAllText($source)
        if (-not (Test-Path -LiteralPath $target) -or [IO.File]::ReadAllText($target) -cne $content) {
            [IO.File]::WriteAllText($target, $content, [Text.UTF8Encoding]::new($false))
        }
    }
    $runner = Join-Path $bin 'ps-ai-foundry.ps1'
    $shPath = "'" + $runner.Replace("'", "'" + '"' + "'" + '"' + "'") + "'"
    $sh = '#!/bin/sh' + "`n" + ('exec pwsh -NoProfile -File {0} -Agent {1} "$@"' -f $shPath, $Id) + "`n"
    [IO.File]::WriteAllText((Join-Path $bin $Id), $sh, [Text.UTF8Encoding]::new($false))
    if (-not $IsWindows) { & chmod +x (Join-Path $bin $Id) }
    $cmd = "@pwsh -NoProfile -File `"$runner`" -Agent $Id %*`r`n"
    [IO.File]::WriteAllText((Join-Path $bin "$Id.cmd"), $cmd, [Text.UTF8Encoding]::new($false))
}

function Get-PsAiFoundryDiscovery {
    param([string]$Endpoint, [string]$Tool)
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
    if (-not $Deployments.Count -or -not $Default) { throw 'Foundry requires -Deployments and -Default' }
    if ($Default -cnotin $Deployments) { throw "default '$Default' is not one of -Deployments" }
    $aliasMap = @{}
    if ($null -eq $Aliases) {
        foreach ($item in $Existing) { if ($item.alias) { $aliasMap[$item.name] = $item.alias } }
    } else {
        foreach ($pair in $Aliases) {
            $parts = $pair -csplit '=', 2
            if ($parts.Count -ne 2 -or $parts[0] -cnotin $Deployments -or $parts[1] -cnotin @('opus','sonnet','haiku','fable')) { throw "invalid alias '$pair'; use name=alias for a selected deployment" }
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

$file = Join-Path $HomeRoot '.agents/configuration/ps-ai-personalisation.json'
$data = Read-PsAiJson -Path $file
switch ($Action) {
    add {
        $existing = @($data.agents | Where-Object { $_.id -ceq $Id })[0]
        if ($Provider -eq 'foundry') {
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
                id = $Id; tool = $Tool; command = "~/.agents/bin/$Id"; configDir = "~/.agents/accounts/$Id"; roles = @(); provider = $providerBlock
            }
            $null = Write-FoundryToolConfig -Agent $entry -HomeRoot $HomeRoot
            $data.agents = @($data.agents) + @($entry)
            Write-PsAiPersonalisation -Data $data -Path $file
            New-FoundryWrappers -Id $Id -HomeRoot $HomeRoot
            "Run '$Id' in a terminal; it signs in to Azure through az when needed."
            break
        }
        if ($null -ne $existing -and -not $existing.provider -and $existing.tool -ceq $Tool -and $existing.command -ceq "~/.agents/bin/$Id" -and $existing.configDir -ceq "~/.agents/accounts/$Id") {
            "skip: account $Id (already done)"
            break
        }
        Assert-PsAiNewId -Id $Id -Data $data
        $null = Get-ConfigEnvName -Tool $Tool
        $realCommand = if ($Command) { $Command } else { (Get-Command $Tool -ErrorAction Stop).Source }
        $entry = [pscustomobject]@{
            id = $Id; tool = $Tool; command = "~/.agents/bin/$Id"; configDir = "~/.agents/accounts/$Id"; roles = @()
        }
        $data.agents = @($data.agents) + @($entry)
        Write-PsAiPersonalisation -Data $data -Path $file
        New-PsAiWrappers -Id $Id -Tool $Tool -HomeRoot $HomeRoot -RealCommand $realCommand
        "Run '$Id' in a terminal and log in once."
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
        New-FoundryWrappers -Id $Id -HomeRoot $HomeRoot
    }
    register {
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
        $owned = @("~/.agents/bin/$Id", (Join-Path $HomeRoot ".agents/bin/$Id"))
        if ($oldCommand -in $owned) {
            $agent.command = $oldCommand.Substring(0, $oldCommand.Length - $Id.Length) + $NewId
        } else {
            "command kept at $oldCommand; rename the wrapper yourself if you want to"
        }
        Update-AllPsAiRouting -Data $data -OldId $Id -NewId $NewId
        Write-PsAiPersonalisation -Data $data -Path $file
        Move-PsAiWrappers -OldId $Id -NewId $NewId -HomeRoot $HomeRoot
        if ($agent.provider.kind -eq 'foundry' -and $oldCommand -in $owned) { New-FoundryWrappers -Id $NewId -HomeRoot $HomeRoot }
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
