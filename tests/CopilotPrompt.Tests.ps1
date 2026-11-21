$root = Split-Path $PSScriptRoot -Parent
$recipe = Get-Content -LiteralPath (Join-Path $root 'plugins/legion/skills/legion-copilot/references/run.md') -Raw

if ($IsWindows) {
    $tempRoot = Join-Path $root ('.agents/temp/copilot-prompt-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    try {
        $accountScript = Join-Path $root 'plugins/legion/bin/legion-account.ps1'
        $fakeTool = Join-Path $tempRoot 'fake-copilot.ps1'
        @'
ConvertTo-Json -InputObject @($args) | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'arguments.json')
'@ | Set-Content -LiteralPath $fakeTool
        & $accountScript -Action add -Id copilot-prompt -Tool copilot -Command $fakeTool -HomeRoot $tempRoot | Out-Null

        $promptPath = Join-Path $tempRoot 'task prompt.md'
        $promptContents = "First task line.`nSecond task line.`nThird task line.`n"
        [IO.File]::WriteAllText($promptPath, $promptContents)
        $promptText = "Read and follow the task in $promptPath; the report goes to stdout."
        $wrapper = Join-Path $tempRoot '.legion/bin/copilot-prompt.cmd'
        & $wrapper -p $promptText -s --allow-all-tools '--deny-tool=shell(git push)'
        Assert-Equal 0 $LASTEXITCODE 'Copilot prompt wrapper exits successfully'
        $received = Get-Content -LiteralPath (Join-Path $tempRoot 'arguments.json') -Raw | ConvertFrom-Json
        Assert-Equal 5 $received.Count 'Wrapper preserves the argument count'
        Assert-Equal '-p' $received[0] 'Wrapper keeps the prompt flag'
        Assert-Equal $promptText $received[1] 'One-line prompt with a spaced file path arrives whole'
        Assert-Equal '-s|--allow-all-tools|--deny-tool=shell(git push)' ($received[2..4] -join '|') 'Wrapper preserves the worker flags'
        Assert-Equal $promptContents ([IO.File]::ReadAllText($promptPath)) 'Named prompt file keeps every line'
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $root '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not ([IO.Path]::GetFullPath($tempRoot)).StartsWith($allowed)) { throw 'unsafe Copilot prompt fixture cleanup' }
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

Assert-True (-not $recipe.Contains('Get-Content -Raw')) 'Copilot recipe does not pass multiline prompt file contents as an argument'
